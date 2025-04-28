#!/bin/bash

# cbs.sh

# CBS - Coach Bash Server
# This script implements the server-side functionality for the Coach Bash project.
# It uses a named pipe for communication with the client.

# Include the common library functions
# step 3b
. "./cbl.sh"

# Step 1: Named Pipe Management

# Default values
# step 1
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server (step 1)
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client (step 3)
QUESTION_FILE="./questions.txt"   # Default question file (step 3)
VERBOSE=false                     # Verbose output flag (step 1)
SEND_DELAY=0.05                   # Delay for sending (step 3a)
SEND_STOP="send_stop"             # Stop sending command (step 3a)
LINE_SEPARATOR="|"                # Line separator for questions (step 3a)
QUESTION_SEPARATOR="/"            # Question separator (step 3a)

# Error codes
ERR_NO=0
ERR_OPTION=1
ERR_UNKNOWN=6

# Function: Display help
# step 1
show_help() {
    ui_print "Usage: ./cbs.sh [options]"
    ui_print "Options:"
    ui_print "  -h, --help      Show this help message and exit"
    ui_print "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -q, --questions Specify the question file to use (default: ./questions.txt)"  # step 3
    ui_print "  -v, --verbose   Enable verbose output"
}

# Function: Parse command-line arguments
# step 3a
parse_arguments() {   # step 3a
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
# step 3
load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        ui_print "Error: Question file not found: $QUESTION_FILE"   # step 3b
        exit_program $ERR_FILE
    fi
    verbose_print "Loading questions from file: $QUESTION_FILE"  # step 3a,3b
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function: Send a question to the client
# step 3
send_question() {
    local question_number="$1"
    local question_line="${QUESTIONS[$((question_number - 1))]}"
    if [[ -z "$question_line" ]]; then
        ui_print "> Error: Question $question_number not found."    # step 3b
        echo "> Error: Question $question_number not found." > "$PIPE_CLIENT"
    else
      verbose_print "Sending question $question_number to client..."    # step 3b
      IFS="$LINE_SEPARATOR" read -t 1 -r number question type options correct <<< "$question_line" # step 3,3a
      ui_print "> Question: $question ($type)"   # step 3b
      echo "> Question: $question ($type)" > "$PIPE_CLIENT"
      if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
          local option
          echo "$options" | while read -d "$QUESTION_SEPARATOR" -r option; do   # step 3,3a
              ui_print "> $option"  # step 3b
              echo "> $option" > "$PIPE_CLIENT"
              sleep $SEND_DELAY   # step 3 
          done
      fi
    fi
    sleep $SEND_DELAY   # step 3 - critical for timing
    echo "$SEND_STOP" > "$PIPE_CLIENT"
    verbose_print "Sending complete." # step 3b
}

# Function: List all questions
# step 3
list_questions() {
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        IFS="$LINE_SEPARATOR" read -r number question _ <<< "${QUESTIONS[$i]}"  # step 3,3a
        ui_print "> Question $((i + 1)): $question"
        echo "> Question $((i + 1)): $question" > "$PIPE_CLIENT"
    done
    sleep $SEND_DELAY   # step 3 - critical for timing
    echo "$SEND_STOP" > "$PIPE_CLIENT"
    verbose_print "Sending complete."   # step 3b
}

# Function: Process client commands
# step 2
process_command() {
    local command="$1"

    verbose_print "Received command: $command"
    case "$command" in
        q)  ui_print "Quit command received. Ending session..."     # step 3b
            exit_program $ERR_NO ;;
        s)  ui_print "Start command received. Starting question-answer session..." ;;   # step 3b
            # TODO: Logic to start the session (to be implemented)
        t)  ui_print "Time command received. Sending remaining time..." ;;  # step 3b
            # TODO: Logic to send remaining time (to be implemented)
        l)  ui_print "List command received. Sending question list..."  # step 3b
            list_questions ;;    # step 3
        [0-9]*)  echo "Question number $command received."  # step 3b
            send_question "$command" ;;  # step 3
        a)  ui_print "Answer command received. Processing answer..." ;; # step 3b
            # TODO: Logic to process the answer (to be implemented)
        f)  ui_print "Finish command received. Calculating final result..." ;;  # step 3b
            # TODO: Logic to calculate and send the final result (to be implemented)
        *)  ui_print "Invalid command received: $command" ;;    # step 3b
    esac
}

# step 1
trap "cleanup $PIPE_SERVER" EXIT          # Set trap to clean up on exit, step 3b

# Function: Main script logic
# step 1
function main() {          # step 3a
    parse_arguments "$@"   # step 3a
    create_pipe "$PIPE_SERVER" "$0"    # step 3b      
    load_questions         # step 3
    verbose_print "Server is running. Waiting for client input..."  # step 3b

    local main_count=1
    local client_command
    while true; do
        ui_print "Iteration: $((main_count++))"     # step 3b
        read -r client_command < "$PIPE_SERVER"
        process_command "$client_command"
    done
}

main $@
