#!/bin/bash

# cbs.sh

# (c) 2025 Yakiv Koliada. Coach Ba software. All rights reserved.
# This program is free software: you can redistribute it and/or modify
# it under the terms version 3.0 of the GNU General Public License as published by
# the Free Software Foundation. This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. See the GNU General Public License for more details.

# CBS - Coach Ba Server
# This script implements the server-side functionality for the Coach Ba software.
# It uses a named pipe for communication with the client.

# Usage:
#   cbs.sh [-u <username>] [-t <topic>] [options]

# Disable exit on error to allow for custom error handling
set +e 

# Import externals
. .env       # Environment variables
. cbl.sh     # Common Bash Library for logging and utilities

# Default values
APP_NAME="cbs"                          # Application name
PIPE_FOLDER="/opt/cb"                   # Default folder for named pipes
PIPE_SERVER="$PIPE_FOLDER/cbs_pipe"     # Default named pipe for server
PIPE_CLIENT="/$PIPE_FOLDER/cbc_pipe"    # Default named pipe for client
RESULTS_FOLDER="./results"              # Folder to store results
COURSES_FOLDER="./courses"              # Folder to store courses
QUESTION_FILE="$COURSES_FOLDER/course.txt"      # Default question file for the course
DESCRIPTION_FILE="$COURSES_FOLDER/course.des"   # Default description file for the course
RESPONSE=false                          # Response output flag
LINE_SEPARATOR=$';\n'                   # Line separator for questions
COLUMN_SEPARATOR=$';'                   # Column separator for questions
ANSWER_SEPARATOR=$'!'                   # Answer separator
SEND_DELAY=0                            # Delay between sending answers to the client

# State variables
USERNAME=""                             # Username of the client
TOPIC=""                                # Topic (course code)
COURSE_NAME=""                          # Course name
DIFFICULTY_NAME=""                      # Difficulty name
TEST_START_TIME=                        # Test start date-time
TEST_DURATION=0                         # Test duration in minutes (0 means no time limit)
QUESTIONS=()                            # Array to store questions
ANSWERED_QUESTIONS=()                   # Array to track answered questions
REPEAT_QUESTIONS=()                     # Array to track questions marked for later
LAST_QUESTION=""                        # Last question number

# Function: Display help
function show_help() {
    ui_print "Usage: ./cbs.sh [-u <username>] [-t <topic>] [options]"
    ui_print "Options:"
    ui_print "  -d file, --description file  Specify the description file to use (default: ./course_des.txt)"
    ui_print "  -h, --help                   Show this help message and exit"
    ui_print "  -l n, --limit-time n         Enable time-limited mode for answering questions (n minutes)"
    ui_print "  -p file, --pipe file         Specify the name of the named pipe to use (default: /opt/cb/cbs_pipe)"
    ui_print "  -q file, --questions file    Specify the question file to use (default: ./course.txt)"
    ui_print "  -r, --response               Enable response to client about the correctness of the answer (coach mode)"
    ui_print "  -t topic, --topic topic      Specify the topic (course code) to use (required or set CB_TOPIC env variable)"
    ui_print "  -u user, --username user     Specify username (required or set CB_USERNAME env variable)"
    ui_print "  -v                           Logging level for CRIT messages and above"
    ui_print "  -vv                          Logging level for ERR messages and above"
    ui_print "  -vvv                         Logging level for WARNING messages and above"
    ui_print "  -vvvv                        Logging level for INFO messages and above"
    ui_print "  -vvvvv                       Logging level for DEBUG messages and above"
}

# Function: Parse command-line arguments
function parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -d|--description) DESCRIPTION_FILE="$2"; shift ;;
            -h|--help) show_help; exit_program $ERR_NO ;;
            -p|--pipe) PIPE_SERVER="$2"; shift ;;
            -q|--questions) QUESTION_FILE="$2"; shift ;;
            -r|--response) RESPONSE=true ;;
            -t|--topic) TOPIC="$2"; shift ;;
            -l|--limit-time) TEST_DURATION="$2"; shift ;;
            -u|--username) USERNAME="$2"; shift ;;
            -v) LOGGING_LEVEL=$CRIT ;;
            -vv) LOGGING_LEVEL=$ERR ;;
            -vvv) LOGGING_LEVEL=$WARN ;;
            -vvvv) LOGGING_LEVEL=$INFO ;;
            -vvvvv) LOGGING_LEVEL=$DEBUG ;;
            *) show_help
               error_print "Error: Unknown option: $1"
               exit_program $ERR_OPTION ;;
        esac
        shift
    done

    # Use environment variables if command-line options are not provided
    USERNAME="${USERNAME:-$CB_USERNAME}"
    TOPIC="${TOPIC:-$CB_TOPIC}"

    # Validate username and topic
    if [[ -z "$USERNAME" || -z "$TOPIC" ]]; then
        error_print "Error: Username and topic are required. Use the -u and -t options or set CB_USERNAME and CB_TOPIC env variables."
        exit_program $ERR_OPTION
    fi

    log_message $EMERG "INFO" "Logging level: $LOGGING_LEVEL"
    log_message $EMERG "INFO" "Username: $USERNAME"
    info_print "Response: $RESPONSE"
    info_print "Logging level: $LOGGING_LEVEL"
    info_print "Test duration: $TEST_DURATION minutes"
}

# Function: Load course description
function load_course_description() {
    # Ensure the course directories exist
    [[ ! -d "${COURSES_FOLDER}" ]] &&  mkdir -p "$COURSES_FOLDER"
    [[ ! -d "${RESULTS_FOLDER}" ]] &&  mkdir -p "$RESULTS_FOLDER"

    if [[ ! -f "$DESCRIPTION_FILE" ]]; then
        error_print "Error: Course description file not found: $DESCRIPTION_FILE"
        exit_program $ERR_FILE
    fi

    info_print "Loading course description from file: $DESCRIPTION_FILE"
    local course_line
    course_line=$(grep -E "^$TOPIC|" "$DESCRIPTION_FILE")
    if [[ -z "$course_line" ]]; then
        error_print "Error: Topic '$TOPIC' not found in course description file."
        exit_program $ERR_FILE
    fi

    IFS='|' read -r TOPIC COURSE_NAME DIFFICULTY_NAME <<< "$course_line"

    # Use environment variables if command-line options are not provided
    TOPIC="${TOPIC:-$CB_TOPIC}"

    # Validate topic
    if [[ -z "$TOPIC" ]]; then
        error_print "Error: Topic is required. Use the $DESCRIPTION_FILE file or CB_TOPIC env variable."
        exit_program $ERR_FILE
    fi

    log_message $EMERG "INFO" "Topic: $TOPIC"
    log_message $EMERG "INFO" "Course: $COURSE_NAME"
    info_print "Difficulty: $DIFFICULTY_NAME"
}

# Function: Load questions from the file
function load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        error_print "Error: Question file not found: $QUESTION_FILE"
        exit_program $ERR_FILE
    fi
    info_print "Loading questions from file: $QUESTION_FILE"
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function: Send a command to the client
function send_answer() {
    local answer="$1"

    validate_pipe "$PIPE_CLIENT" "$APP_NAME"

    if [[ -n "$answer" ]]; then
        debug_print "$answer"
        ui_print "$answer" | tee "$PIPE_CLIENT"
    fi
}

# Function: Send a question to the client
function send_question() {
    local question_number="$1"
    local question_line=""
    
    if [[ "$question_number" != "0" ]]; then
        question_line="${QUESTIONS[$((question_number - 1))]}"
    fi
    
    ui_print "Send question number $question_number command received. Sending question..."
    if [[ -z "$question_line" ]]; then
        send_answer "> Error: Question $question_number not found."
    else
      info_print "Sending question $question_number to client..."
      IFS="$LINE_SEPARATOR" read -t 1 -r number question type options correct <<< "$question_line"
      if [[ "$type" == "text" ]]; then
        send_answer "> Question $question_number: $question $options ($type)"
      else
        send_answer "> Question $question_number: $question ($type)"
      fi
      if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
          echo "$options" | while read -d "$ANSWER_SEPARATOR" -r option; do
              send_answer "> $option"
              sleep $SEND_DELAY
          done
      fi
    fi
    send_stop "$PIPE_CLIENT"
}

# Function: List all questions
function list_questions() {
    ui_print "List command received. Sending question list..."
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        IFS="$LINE_SEPARATOR" read -r number question _ <<< "${QUESTIONS[$i]}"
        send_answer "> Question $((i + 1)): $question"
        sleep $SEND_DELAY
    done
    send_stop "$PIPE_CLIENT"
}

# Function: Display progress of answers
function display_progress() {
    ui_print "Progress command received. Sending progress list..."
    local progress_list=""
    local repeat_list=""

    for i in "${!QUESTIONS[@]}"; do
        local question_number=$((i + 1))
        if [[ " ${!ANSWERED_QUESTIONS[@]} " == *" $question_number "* ]]; then
            if [[ "${RESPONSE,,}" == false ]]; then
                progress_list+="$question_number* "
            else
                if [[ "${ANSWERED_QUESTIONS[$question_number]}" == "1" ]]; then
                    progress_list+="$question_number+ "
                else
                    progress_list+="$question_number! "
                fi
            fi
        else
            progress_list+="$question_number "
        fi
        if [[ " ${!REPEAT_QUESTIONS[@]} " == *" $question_number "* ]]; then
            repeat_list+="$question_number+ "
        fi
    done
    progress_list=${progress_list% }    # Remove trailing space
    repeat_list=${repeat_list% }
    send_answer "Progress: $progress_list"
    send_answer "Repeat: $repeat_list"
    send_stop "$PIPE_CLIENT"
}

# Function: List all questions
function send_session_info() {
    ui_print "Get session information. Sending session info..."
    echo -e "Username: ${USERNAME}\nCourse ($TOPIC): ${COURSE_NAME}\nDifficulty: ${DIFFICULTY_NAME}" | \
    while read -r session; do
        send_answer "$session"
        sleep $SEND_DELAY
    done
    send_stop "$PIPE_CLIENT"
}

# Function: Mark a question for answering later
function mark_question_for_later() {
    local question_number="$1"

    if [[ " ${!REPEAT_QUESTIONS[@]} " != *" $question_number "* ]]; then
        REPEAT_QUESTIONS+=([$question_number]="1")
        send_answer "Question $question_number marked for answering later."
    else
        unset REPEAT_QUESTIONS[$(($question_number))]
        send_answer "Question $question_number is not marked for answering later."
    fi
    info_print "$(declare -p REPEAT_QUESTIONS | sed 's/^declare -a //')"
    send_stop "$PIPE_CLIENT"
}

# Function: Start the test session
function start_test_session() {
    ui_print "Start command received. Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        info_print "Test session started at: $TEST_START_TIME"
    else
        warning_print "Test session already started at: $TEST_START_TIME"
    fi

    send_answer "$TEST_START_TIME"
    send_stop "$PIPE_CLIENT"
}

# Function: Process an answer
function process_answer() {
    local answer_data="$1"
    local question_number="${answer_data%%|*}"  # Extract question number
    local user_answer="${answer_data#*|}"       # Extract user answer

    ui_print "Answer command received. Processing answer..."
    info_print "Question number: $question_number"

    # Check if the question has already been answered
    if [[ " ${!ANSWERED_QUESTIONS[@]} " == *" $question_number "* ]]; then
        info_print "Question $question_number has already been answered. Overwriting previous answer."
    fi

    # Validate the answer
    local question_line="${QUESTIONS[$((question_number - 1))]}"
    local correct=""                            # Correct answer
    IFS="$LINE_SEPARATOR" read -r number question type options correct <<< "$question_line"

    local response="Incorrect"                  # Default response
    ANSWERED_QUESTIONS["$question_number"]="0"  # Initialize as incorrect

    if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
        # Normalize answer for comparison, no space is allowed
        user_answer=$(echo "$user_answer" | sed 's/ //g' | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
        correct=$(echo "$correct" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
        debug_print "Correct answers: ${correct}"
         # Check if the user answer matches the correct answer
        if [[ "${user_answer,,}" == "${correct,,}" ]]; then
            ANSWERED_QUESTIONS["$question_number"]="1"
            response="Correct (${correct})"
        else
            response="Incorrect (Correct: ${correct})"
        fi
    elif [[ "$type" == "text" ]]; then
        # Normalize answer for comparison, one space is allowed
        user_answer=$(echo "$user_answer" | sed 's/  / /g')
        # Check if the user answer matches any of the correct answers
        IFS="$ANSWER_SEPARATOR" read -ra correct_answers <<< "${correct}"
        debug_print "Correct answers: ${correct_answers[*]}"
        for correct in "${correct_answers[@]}"; do
            if [[ "${user_answer,,}" == "${correct,,}" ]]; then
                ANSWERED_QUESTIONS["$question_number"]="1"
                response="Correct (${correct})"
                break
            else
                response="Incorrect (Correct: ${correct})"            
            fi
        done
    else
        response="Invalid question type"
    fi

    # Log the answer
    info_print "Normalized user answer: ${user_answer,,}"
    info_print "Normalized correct answer: ${correct,,}"
    info_print "$(declare -p ANSWERED_QUESTIONS | sed 's/^declare -a //')"

    # Send response to the client
    local message="Server response: $response"
    info_print "$message"
    ui_print "$message"
    $RESPONSE && echo "Server response: $response" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: Calculate remaining time
function calculate_remaining_time() {
    if [[ "$TEST_DURATION" -gt 0 ]]; then
        local current_time=$(date '+%s')
        local start_time=$(date -d "${TEST_START_TIME:=$(date -d@$current_time)}" '+%s')
        local elapsed_time=$((current_time - start_time))
        (( elapsed_time <= 60 )) && elapsed_time=0  # Ensure at least 1 minute for elapsed time
        if (( elapsed_time > (TEST_DURATION * 60) )); then
            local remaining_time=0
        else
            local remaining_time=$((((TEST_DURATION) * 60 - elapsed_time) / 60))
        fi
        echo "$remaining_time"
    else
        echo "-1"  # No time limit
    fi
}

# Function: Check if time is remaining
function is_time_remaining() {
    if [[ "$TEST_DURATION" -gt 0 ]]; then
        local remaining_time=$(calculate_remaining_time)
        info_print "Remaining time: $remaining_time minutes"
        if [[ "$remaining_time" -gt 0 ]]; then
            echo "True"  # Time is remaining
        else 
            echo "False" # Time is up
        fi        
    else
        echo "True"  # No time limit
    fi
}

# Function: Check if session is started
function is_session_started() {
    if [[ -z "$TEST_START_TIME" ]]; then
        echo "False" # Session is not started
    else
        echo "True"  # Session is started
    fi
}

# Function: Handle the `t` (time) command
function handle_time_command() {
    ui_print "Time command received. Sending remaining time..."
    local remaining_time=$(calculate_remaining_time)

    if [[ -z "$TEST_START_TIME" ]]; then
        send_answer "Quiz hasn't started yet, run 's' command to start the session."
    else
        if [[ "$remaining_time" -lt 0 ]]; then
            send_answer "Quiz started at: $TEST_START_TIME, $(calculate_time_taken) minute(s) ago (No time limit)."
        else
            send_answer "Quiz started at: $TEST_START_TIME, $(calculate_time_taken) minute(s) ago."
            send_answer "Remaining time: $remaining_time minute(s)"
        fi
    fi
    send_stop "$PIPE_CLIENT"
}

# Function: Time is up
function time_is_up() {
    local remaining_time=$(calculate_remaining_time)
    
    if [[ "$remaining_time" -le 0 ]]; then
        send_answer "Time is up. No further commands are allowed."
        send_stop "$PIPE_CLIENT"
    fi
}

# Function: Calculate time taken
function calculate_time_taken() {
    local current_time=$(date '+%s')
    local start_time=$(date -d "$TEST_START_TIME" '+%s')

    if [[ -z "$TEST_START_TIME" ]]; then
        echo "0"  # No time taken
    else
        time_taken=$((current_time - start_time))
        (( time_taken <= 60 )) && time_taken=60
        echo $((time_taken / 60))
    fi
}

# Function: Calculate the final result
function calculate_final_result() {
    ui_print "Finish command received. Calculating final result..."
    local total_questions=${#QUESTIONS[@]}
    local correct_answers=0

    # Calculate the percentage of correct answers
    for question_number in "${!ANSWERED_QUESTIONS[@]}"; do
        if [[ "${ANSWERED_QUESTIONS[$question_number]}" == "1" ]]; then
            ((correct_answers++))
        fi
    done
    local percentage=$((correct_answers * 100 / total_questions))

    # Generate the user's results file
    local timestamp=$(date -d "$TEST_START_TIME" '+%Y%m%d_%H%M')
    local result_file="${USERNAME}_${TOPIC}_${timestamp}.txt"
    info_print "Generating user's results file: $result_file"

    {
        echo "Username: $USERNAME"
        echo "Course: $COURSE_NAME"
        echo "Course ID: $TOPIC"
        echo "Difficulty: $DIFFICULTY_NAME"
        echo "Coach mode: $RESPONSE"
        echo "Test Start Time: $TEST_START_TIME"
        echo "Total Questions: $total_questions"
        echo "Correct Answers: $correct_answers"
        echo "Final Result: $percentage%"
        echo "Time Taken: $(calculate_time_taken) minutes"
        echo ""
        echo "Questions and Statuses:"
        for i in "${!QUESTIONS[@]}"; do
            local question_number=$((i + 1))
            local status="Unanswered"
            if [[ -n "${ANSWERED_QUESTIONS[$question_number]}" ]]; then
                status=$([[ "${ANSWERED_QUESTIONS[$question_number]}" == "1" ]] && echo "Correct" || echo "Incorrect")
            fi
            local question="$(echo ${QUESTIONS[$i]} | cut -d"$COLUMN_SEPARATOR" -f2)"
            echo "Question $question_number: $status: $question"
        done
    } > "$RESULTS_FOLDER/$result_file"

    # Send the final result to the client
    local message="Final Result: $percentage%"
    log_message $EMERG "INFO" "$message"
    ui_print "$message" | tee "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"

    quit_program
}

# Function: Session is not started
function session_is_not_started() {
    send_answer "Session not started. Please start the session first."
    send_stop "$PIPE_CLIENT"
}

function init_application() {
    # Set trap to handle errors
    trap "error_handler" ERR

    local message="Server is starting..."
    ui_print "$message"

    parse_arguments "$@"

    log_message $EMERG "INFO" "$message"

    # Create the named pipe for server-client communication
    local pipe_server="/$PIPE_FOLDER/${USERNAME}_${TOPIC}_cbs_pipe"
    PIPE_SERVER="${pipe_server:-${PIPE_SERVER}}"
    create_pipe "$PIPE_SERVER" "$0"
    local pipe_client="/$PIPE_FOLDER/${USERNAME}_${TOPIC}_cbc_pipe"
    PIPE_CLIENT="${pipe_client:-${PIPE_CLIENT}}"

    # Set trap to handle crashes
    trap "handle_crash $PIPE_SERVER" INT TERM
    # Set trap to clean up on exit
    trap "cleanup $PIPE_SERVER" EXIT

    # Load the course description and questions
    load_course_description
    load_questions
    
    info_print "Server is running. Waiting for client input..."
}

# Function: Process client commands
function process_command() {
    local command="$1"

    info_print "Received command: $command"
    case "$command" in
        i)  send_session_info ;;
        s)  start_test_session ;;
        l|a|a\|*|[0-9]*|r|r\|*)
            if [[ $(is_session_started) == "False" ]]; then
                session_is_not_started
                return
            elif [[ $(is_time_remaining) == "True" ]]; then
                case "$command" in
                    l)  list_questions ;;
                    a\|*)  process_answer "${command#*|}" ;;
                    [0-9]*)  send_question "$command" ;;
                    r\|*)  mark_question_for_later "${command#*|}" ;;
                esac
            else
                time_is_up
            fi ;;
        p)  display_progress ;;
        t)  handle_time_command ;;
        f)  calculate_final_result ;;
        q)  quit_program ;;
        *)  warning_print "Invalid command received: $command" ;;
    esac
}

# Function: Main script logic
function main() {
    init_application "$@"

    local iteration=1
    local client_command
    while true; do
        ui_print "---\nIteration: $((iteration++))"
        read -r client_command < "$PIPE_SERVER"
        process_command "$client_command"
    done
}

main $@
