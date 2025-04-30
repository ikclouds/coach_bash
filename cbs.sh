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
QUESTION_FILE="./questions.txt"   # Default question file
VERBOSE=false                     # Verbose output flag
RESPONSE=false                    # Response output flag
LINE_SEPARATOR=$'|\n'             # Line separator for questions
QUESTION_SEPARATOR="/"            # Question separator

# State variables
TEST_START_TIME=""                # Test start date-time
ANSWERED_QUESTIONS=()             # Array to track answered questions

# Error codes
ERR_NO=0                          # No error
ERR_OPTION=1                      # Invalid command-line option
ERR_UNKNOWN=6                     # Unknown error

# Function: Display help
show_help() {
    ui_print "Usage: ./cbs.sh [options]"
    ui_print "Options:"
    ui_print "  -h, --help      Show this help message and exit"
    ui_print "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -q, --questions Specify the question file to use (default: ./questions.txt)"
    ui_print "  -r, --response  Enable response to client about the correctness of the answer"
    ui_print "  -v, --verbose   Enable verbose output"
}

# Function: Parse command-line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit_program $ERR_NO ;;
            -p|--pipe) PIPE_SERVER="$2"; shift ;;
            -q|--questions) QUESTION_FILE="$2"; shift ;;
            -r|--response) RESPONSE=true ;;
            -v|--verbose) VERBOSE=true ;;
            *) ui_print "Unknown option: $1"; show_help; exit_program $ERR_OPTION ;;
        esac
        shift
    done
    verbose_print "Response: $RESPONSE"
    verbose_print "Verbose: $VERBOSE"
}

# Function: Load questions from the file
load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        ui_print "Error: Question file not found: $QUESTION_FILE"
        exit_program $ERR_FILE
    fi
    verbose_print "Loading questions from file: $QUESTION_FILE"
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function: Send a question to the client
send_question() {
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
list_questions() {
    ui_print "List command received. Sending question list..."
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        IFS="$LINE_SEPARATOR" read -r number question _ <<< "${QUESTIONS[$i]}"
        ui_print "> Question $((i + 1))| $question"
        echo "> Question $((i + 1))| $question" > "$PIPE_CLIENT"
    done
    send_stop "$PIPE_CLIENT"
}

# Function: Start the test session
start_test_session() {
    ui_print "Start command received. Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        verbose_print "Test session started at: $TEST_START_TIME"
    else
        ui_print "Test session already started at: $TEST_START_TIME"
    fi
    echo "$TEST_START_TIME" > "$PIPE_CLIENT"
    send_stop "$PIPE_CLIENT"
    # Additional logic for initializing the session can be added here
}

# Function: Process an answer
# step 3d
process_answer() {
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
        # Normalize answer for comparison
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

# Function: Quit the program
function quit_program() {
    ui_print "Quit command received. Ending session..."
    exit_program $ERR_NO
}

# Function: Process client commands
process_command() {
    local command="$1"

    verbose_print "Received command: $command"
    case "$command" in
        q)  quit_program ;;         # step 3d
        s)  start_test_session ;;
        t)  ui_print "Time command received. Sending remaining time..." ;;
            # TODO: Logic to send remaining time (to be implemented)
        l)  list_questions ;;
            # TODO: Implement feature to mark questions as answered
        [0-9]*)  send_question "$command" ;;
        a|*)  process_answer "${command#*|}" ;;
        f)  ui_print "Finish command received. Calculating final result..." ;;
            # TODO: Logic to calculate and send the final result (to be implemented)
        *)  ui_print "Invalid command received: $command" ;;
    esac
}

# Set trap to clean up on exit
trap "cleanup $PIPE_SERVER" EXIT

# Function: Main script logic
function main() {
    parse_arguments "$@"
    create_pipe "$PIPE_SERVER" "$0"
    load_questions
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
