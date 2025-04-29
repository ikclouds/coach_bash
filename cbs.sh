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
LINE_SEPARATOR="|"                # Line separator for questions
QUESTION_SEPARATOR="/"            # Question separator

# State variables
TEST_START_TIME=""                # Test start date-time

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
    ui_print "  -v, --verbose   Enable verbose output"
}

# Function: Parse command-line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit_program $ERR_NO ;;
            -p|--pipe) PIPE_SERVER="$2"; shift ;;
            -q|--questions) QUESTION_FILE="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) ui_print "Unknown option: $1"; show_help; exit_program $ERR_OPTION ;;
        esac
        shift
    done
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

    echo "Send question number $question_number command received. Sending question..."   # step 3c
    if [[ -z "$question_line" ]]; then
        ui_print "> Error: Question $question_number not found."
        echo "> Error: Question $question_number not found." > "$PIPE_CLIENT"
    else
      verbose_print "Sending question $question_number to client..."
      IFS="$LINE_SEPARATOR" read -t 1 -r number question type options correct <<< "$question_line"
      ui_print "> Question: $question ($type)"
      echo "> Question: $question ($type)" > "$PIPE_CLIENT"
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
    ui_print "List command received. Sending question list..."  # step 3c
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        IFS="$LINE_SEPARATOR" read -r number question _ <<< "${QUESTIONS[$i]}"
        ui_print "> Question $((i + 1)): $question"
        echo "> Question $((i + 1)): $question" > "$PIPE_CLIENT"
    done
    send_stop "$PIPE_CLIENT"
}

# Function: Start the test session
# Step 3c
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

# Function: Process client commands
process_command() {
    local command="$1"

    verbose_print "Received command: $command"
    case "$command" in
        q)  ui_print "Quit command received. Ending session..."
            exit_program $ERR_NO ;;
        s)  start_test_session ;;   # step 3c
        t)  ui_print "Time command received. Sending remaining time..." ;;
            # TODO: Logic to send remaining time (to be implemented)
        l)  list_questions ;;       # step 3c
            # TODO: Implement feature to mark questions as answered
        [0-9]*)  send_question "$command" ;;
        a)  ui_print "Answer command received. Processing answer..." ;;
            # TODO: Logic to process the answer (to be implemented)
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
        ui_print "Iteration: $((main_count++))"
        read -r client_command < "$PIPE_SERVER"
        process_command "$client_command"
    done
}

main $@
