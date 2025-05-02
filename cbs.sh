#!/bin/bash

# cbs.sh

# CBS - Coach Bash Server
# This script implements the server-side functionality for the Coach Bash project.
# It uses a named pipe for communication with the client.

# Include the common library functions
. "./cbl.sh"

# Default values
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client
RESULTS_FOLDER="./results"        # Folder to store results (step 5a)
COURSES_FOLDER="./courses"        # Folder to store courses (step 5a)
QUESTION_FILE="./$COURSES_FOLDER/course.txt"      # Default question file for the course
DESCRIPTION_FILE="./$COURSES_FOLDER/course.des"   # Default description file for the course
VERBOSE=false                     # Verbose output flag
RESPONSE=false                    # Response output flag
NUM_SEPARATOR=$'|'                # Number separator for questions (step 5a)
LINE_SEPARATOR=$'|\n'             # Line separator for questions
QUESTION_SEPARATOR="/"            # Question separator

# State variables
USERNAME=""                       # Username of the client  (step 5a)
TOPIC=""                          # Topic (course code)  (step 5a)
COURSE_NAME=""                    # Course name  (step 5a)
DIFFICULTY_NAME=""                # Difficulty name  (step 5a)
TEST_START_TIME=                  # Test start date-time
TEST_DURATION=0                   # Test duration in minutes (0 means no time limit)
ANSWERED_QUESTIONS=()             # Array to track answered questions
REPEAT_QUESTIONS=()               # Array to track questions marked for later
LAST_QUESTION=""                  # Last question number

# Error codes
ERR_NO=0                          # No error
ERR_OPTION=1                      # Invalid command-line option
ERR_FILE=2                        # Invalid file name
ERR_UNKNOWN=6                     # Unknown error

# Function: Display help
function show_help() {
    ui_print "Usage: ./cbs.sh [options]"
    ui_print "Options:"
    ui_print "  -h, --help                   Show this help message and exit"
    ui_print "  -p file, --pipe file         Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -q file, --questions file    Specify the question file to use (default: ./course.txt)"
    ui_print "  -d file, --description file  Specify the description file to use (default: ./course_des.txt)"
    ui_print "  -r, --response               Enable response to client about the correctness of the answer"
    ui_print "  -t n, --time n               Enable time-limited mode for answering questions (n minutes)"
    ui_print "  -u, --username               Specify username (required)"
    ui_print "  -v, --verbose                Enable verbose output"
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
            -t|--time) TEST_DURATION="$2"; shift ;;
            -u|--username) USERNAME="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) ui_print "Unknown option: $1"; show_help; exit_program $ERR_OPTION ;;
        esac
        shift
    done

    # Validate username
    if [[ -z "$USERNAME" ]]; then
        ui_print "Error: Username is required. Use the -u option to specify it."
        exit_program $ERR_OPTION
    fi

    verbose_print "Username: $USERNAME"
    verbose_print "Response: $RESPONSE"
    verbose_print "Verbose: $VERBOSE"
    verbose_print "Test duration: $TEST_DURATION minutes"
}

# Function: Load course description
function load_course_description() {
    if [[ ! -f "$DESCRIPTION_FILE" ]]; then
        ui_print "Error: Course description file not found: $DESCRIPTION_FILE"
        exit_program $ERR_FILE
    fi

    verbose_print "Loading course description from file: $DESCRIPTION_FILE"
    local course_line
    course_line=$(grep -E "^$TOPIC|" "$DESCRIPTION_FILE")
    if [[ -z "$course_line" ]]; then
        ui_print "Error: Topic '$TOPIC' not found in course description file."
        exit_program $ERR_FILE
    fi

    IFS='|' read -r TOPIC COURSE_NAME DIFFICULTY_NAME <<< "$course_line"
    verbose_print "$TOPIC"
    verbose_print "$COURSE_NAME"
    verbose_print "$DIFFICULTY_NAME"
}

# Function: Load questions from the file
function load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        ui_print "Error: Question file not found: $QUESTION_FILE"
        exit_program $ERR_FILE
    fi
    verbose_print "Loading questions from file: $QUESTION_FILE"
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function: Send a question to the client
function send_question() {
    local question_number="$1"
    local question_line="${QUESTIONS[$((question_number - 1))]}"

    ui_print "Send question number $question_number command received. Sending question..."
    if [[ -z "$question_line" ]]; then
        ui_print "> Error: Question $question_number not found."
        echo "> Error: Question $question_number not found." > "$PIPE_CLIENT"
    else
      verbose_print "Sending question $question_number to client..."
      IFS="$LINE_SEPARATOR" read -t 1 -r number question type options correct <<< "$question_line"
      if [[ "$type" == "text" ]]; then
        ui_print "> Question $question_number| $question $options ($type)"
        echo "> Question $question_number| $question $options ($type)" > "$PIPE_CLIENT"
      else
        ui_print "> Question $question_number| $question ($type)"
        echo "> Question $question_number| $question ($type)" > "$PIPE_CLIENT"
      fi
      if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
          local option
          echo "$options" | while read -d "$QUESTION_SEPARATOR" -r option; do
              ui_print "> $option"
              echo "> $option" > "$PIPE_CLIENT"
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
        ui_print "> Question $((i + 1))| $question"
        echo "> Question $((i + 1))| $question" > "$PIPE_CLIENT"
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
            progress_list+="$question_number+ "
        else
            progress_list+="$question_number "
        fi
        if [[ " ${!REPEAT_QUESTIONS[@]} " == *" $question_number "* ]]; then
            repeat_list+="$question_number+ "
        fi
    done
    progress_list=${progress_list% }    # Remove trailing space
    repeat_list=${repeat_list% }
    echo "Progress: $progress_list" > "$PIPE_CLIENT"
    sleep $SEND_DELAY
    echo "Repeat: $repeat_list" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: List all questions
function send_session_info() {
    ui_print "Get session information. Sending session info..."
    echo -e "Username: ${USERNAME}\nCourse: ${COURSE_NAME} (Difficulty: ${DIFFICULTY_NAME})" | \
    while read -r session; do
        ui_print "$session"
        echo "$session" > "$PIPE_CLIENT"
    done
    send_stop "$PIPE_CLIENT"
}

# Function: Mark a question for answering later
function mark_question_for_later() {
    local question_number="$1"
    local message=""

    if [[ " ${!REPEAT_QUESTIONS[@]} " != *" $question_number "* ]]; then
        REPEAT_QUESTIONS+=([$question_number]="1")
        message="Question $question_number marked for answering later."
    else
        unset REPEAT_QUESTIONS[$(($question_number))]
        message="Question $question_number is not marked for answering later."
    fi
    verbose_print "$(declare -p REPEAT_QUESTIONS | sed 's/^declare -a //')"
    echo "$message" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: Start the test session
function start_test_session() {
    ui_print "Start command received. Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        verbose_print "Test session started at: $TEST_START_TIME"
    else
        ui_print "Test session already started at: $TEST_START_TIME"
    fi

    local course
    echo "$TEST_START_TIME" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
    # Additional logic for initializing the session can be added here
}

# Function: Process an answer
function process_answer() {
    local answer_data="$1"
    local question_number="${answer_data%%|*}"  # Extract question number
    local user_answer="${answer_data#*|}"       # Extract user answer

    ui_print "Answer command received. Processing answer..."
    verbose_print "Question number: $question_number"

    # Check if the question has already been answered
    if [[ " ${!ANSWERED_QUESTIONS[@]} " == *" $question_number "* ]]; then
        ui_print "Question $question_number has already been answered. Overwriting previous answer."
    else
        ANSWERED_QUESTIONS["$question_number"]="0"  # Initialize as incorrect
    fi

    # Validate the answer
    local question_line="${QUESTIONS[$((question_number - 1))]}"
    local correct=""    # Correct answer
    IFS="$LINE_SEPARATOR" read -r number question type options correct <<< "$question_line"

    local response="Incorrect"                  # Default response
    ANSWERED_QUESTIONS["$question_number"]="0"  # Initialize as incorrect

    if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
        # Normalize answer for comparison, no space is allowed
        user_answer=$(echo "$user_answer" | sed 's/ //g' | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
        correct=$(echo "$correct" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
        if [[ "${user_answer,,}" == "${correct,,}" ]]; then
            ANSWERED_QUESTIONS["$question_number"]="1"
            response="Correct"
        fi
    elif [[ "$type" == "text" ]]; then
        # Normalize answer for comparison, one space is allowed
        user_answer=$(echo "$user_answer" | sed 's/  / /g')
        # Check if the user answer matches any of the correct answers
        IFS="$QUESTION_SEPARATOR" read -ra correct_answers <<< "${correct}"
        for correct in "${correct_answers[@]}"; do
            if [[ "${user_answer,,}" == "${correct,,}" ]]; then
                ANSWERED_QUESTIONS["$question_number"]="1"
                response="Correct"
                break
            fi
        done
    else
        response="Invalid question type"
    fi

    # Debugging
    verbose_print "Normalized user answer: ${user_answer,,}"
    verbose_print "Normalized correct answer: ${correct,,}"
    verbose_print "$(declare -p ANSWERED_QUESTIONS | sed 's/^declare -a //')"

    # Send response to the client
    ui_print "Server response: $response"
    $RESPONSE && echo "Server response: $response" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: Calculate remaining time
function calculate_remaining_time() {
    if [[ "$TEST_DURATION" -gt 0 ]]; then
        local current_time=$(date '+%s')
        local start_time=$(date -d "${TEST_START_TIME:=$(date -d@$current_time)}" '+%s')
        local elapsed_time=$((current_time - start_time))
        local remaining_time=$((((TEST_DURATION) * 60 - elapsed_time) / 60))
        [[ -n $TEST_START_TIME ]] && ((remaining_time++)) # Add 1 minute for the first minute
        echo "$remaining_time"
    else
        echo "-1"  # No time limit
    fi
}

# Function: Check if time is remaining
function is_time_remaining() {
    if [[ "$TEST_DURATION" -gt 0 ]]; then
        local remaining_time=$(calculate_remaining_time)
        verbose_print "Remaining time: $remaining_time minutes"
        [[ "$remaining_time" -gt 0 ]]
    else
        return 0  # No time limit, always allow
    fi
}

# Function: Check if session is started
# step 5a
function is_session_started() {
    if [[ -z "$TEST_START_TIME" ]]; then
        return 1
    else
        return 0
    fi
    
}

# Function: Handle the `t` (time) command
function handle_time_command() {
    ui_print "Time command received. Sending remaining time..."
    local remaining_time=$(calculate_remaining_time)
    if [[ "$remaining_time" -lt 0 ]]; then
        echo "Test started at: $TEST_START_TIME (No time limit)" > "$PIPE_CLIENT"
    else
        echo "Test started at: $TEST_START_TIME" > "$PIPE_CLIENT"
        sleep $SEND_DELAY
        echo "Remaining time: $remaining_time minutes" > "$PIPE_CLIENT"
    fi
    send_stop "$PIPE_CLIENT"
}

# Function: Time is up
function time_is_up() {
    local remaining_time=$(calculate_remaining_time)
    ui_print "Time is up. No further commands are allowed."
    if [[ "$remaining_time" -le 0 ]]; then
        echo "Time is up. No further commands are allowed." > "$PIPE_CLIENT"
        send_stop "$PIPE_CLIENT"
        return 1
    fi
    return 0
}

# Function: Calculate time taken
# step 5a
calculate_time_taken() {
    local current_time=$(date '+%s')
    local start_time=$(date -d "$TEST_START_TIME" '+%s')
    echo $(((current_time - start_time) / 60 + 1))
}

# Function: Calculate the final result
# step 5a
calculate_final_result() {
    ui_print "Finish command received. Calculating final result..."

    # Calculate the percentage of correct answers
    local total_questions=${#QUESTIONS[@]}
    local correct_answers=0
    for question_number in "${!ANSWERED_QUESTIONS[@]}"; do
        if [[ "${ANSWERED_QUESTIONS[$question_number]}" == "1" ]]; then
            ((correct_answers++))
        fi
    done
    local percentage=$((correct_answers * 100 / total_questions))

    # Generate the user's results file
    local timestamp=$(date -d "$TEST_START_TIME" '+%Y%m%d_%H%M')
    local result_file="${USERNAME}_${TOPIC}_${timestamp}.txt"
    verbose_print "Generating user's results file: $result_file"

    {
        echo "Username: $USERNAME"
        echo "Course: $COURSE_NAME"
        echo "Difficulty: $DIFFICULTY_NAME"
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
            local question="$(echo ${QUESTIONS[$i]} | cut -d'|' -f2)"
            echo "Question $question_number: $status: $question"
        done
    } > "./$RESULTS_FOLDER/$result_file"

    # Send the final result to the client
    echo "Final Result: $percentage%" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: Session is not started
# step 5a
function session_is_not_started() {
    ui_print "Session not started. Please start the session first."
    echo "Session not started. Please start the session first." > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
}

# Function: Quit the program
function quit_program() {
    ui_print "Quit command received. Ending session..."
    exit_program $ERR_NO
}

# Function: Process client commands
function process_command() {
    local command="$1"

    verbose_print "Received command: $command"
    case "$command" in
        q)  quit_program ;;
        i)  send_session_info ;;
        s)  start_test_session ;;
        t)  handle_time_command ;;
        l|a|a\|*|[0-9]*|r|r\|*)
            if ! is_session_started; then  # step 5a
                session_is_not_started
                return 1
            elif is_time_remaining; then
                case "$command" in
                    l)  list_questions ;;
                    a\|*)  process_answer "${command#*|}" ;;
                    [0-9]*)  send_question "$command" ;;
                    r\|*)  mark_question_for_later "${command#*|}" ;;
                esac
            else
                time_is_up
            fi
            ;;
        p)  display_progress ;;
        f)  calculate_final_result  # step 5a
            quit_program 
            ;;
        *)  ui_print "Invalid command received: $command" ;;
    esac
}

# Set trap to clean up on exit
trap "cleanup $PIPE_SERVER" EXIT

# Function: Main script logic
function main() {
    parse_arguments "$@"
    load_course_description
    load_questions
    create_pipe "$PIPE_SERVER" "$0"
    verbose_print "Server is running. Waiting for client input..."

    local main_count=1
    local client_command
    while true; do
        ui_print "---\nIteration: $((main_count++))"
        read -r client_command < "$PIPE_SERVER"
        process_command "$client_command"
    done
}

main $@
