#!/bin/bash

# cbs.sh

# CBS - Coach Bash Server
# This script implements the server-side functionality for the Coach Bash project.
# It uses a named pipe for communication with the client.

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

# Function: Display help
# step 1
show_help() {
    echo "Usage: ./cbs.sh [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    echo "  -q, --questions Specify the question file to use (default: ./questions.txt)"  # step 3
    echo "  -v, --verbose   Enable verbose output"
}

# Function: Parse command-line arguments
# step 3a
parse_arguments() {   # step 3a
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -p|--pipe) PIPE_SERVER="$2"; shift ;;
            -q|--questions) QUESTION_FILE="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
        shift
    done
}

# Function: Create the server named pipe
# step 1
create_pipe() {
    if [[ ! -p "$PIPE_SERVER" ]]; then
        $VERBOSE && echo "Creating named pipe: $PIPE_SERVER"  # step 3a
        mkfifo "$PIPE_SERVER"
    else
        $VERBOSE && echo "Named pipe already exists: $PIPE_SERVER"  # step 3a
    fi
}

# Function: Cleanup resources on exit
# step 1
cleanup() {
    [[ -p "$PIPE_SERVER" ]] && rm -f "$PIPE_SERVER"
    $VERBOSE && echo "Cleaned up server named pipe: $PIPE_SERVER"   # step 3a
}

# Function: Load questions from the file
# step 3
load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        echo "Error: Question file not found: $QUESTION_FILE"
        exit 1
    fi
    $VERBOSE && echo "Loading questions from file: $QUESTION_FILE"  # step 3a
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function: Send a question to the client
# step 3
send_question() {
    local question_number="$1"
    local question_line="${QUESTIONS[$((question_number - 1))]}"
    if [[ -z "$question_line" ]]; then
        echo "> Error: Question $question_number not found."
        echo "> Error: Question $question_number not found." > "$PIPE_CLIENT"
    else
      echo "Sending question $question_number to client..."
      IFS="$LINE_SEPARATOR" read -t 1 -r number question type options correct <<< "$question_line" # step 3,3a
      echo "> Question: $question ($type)"
      echo "> Question: $question ($type)" > "$PIPE_CLIENT"
      if [[ "$type" == "multiple-choice" || "$type" == "one-choice" ]]; then
          local option
          echo "$options" | while read -d "$QUESTION_SEPARATOR" -r option; do   # step 3,3a
              echo "> $option"
              echo "> $option" > "$PIPE_CLIENT"
              sleep $SEND_DELAY   # step 3 
          done
      fi
    fi
    sleep $SEND_DELAY   # step 3 - critical for timing
    echo "$SEND_STOP" > "$PIPE_CLIENT"
    $VERBOSE && echo "Sending complete."
}

# Function: List all questions
# step 3
list_questions() {
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        IFS="$LINE_SEPARATOR" read -r number question _ <<< "${QUESTIONS[$i]}"  # step 3,3a
        echo "> Question $((i + 1)): $question"
        echo "> Question $((i + 1)): $question" > "$PIPE_CLIENT"
    done
    sleep $SEND_DELAY   # step 3 - critical for timing
    echo "$SEND_STOP" > "$PIPE_CLIENT"
    $VERBOSE echo "Sending complete."
}

# Function: Process client commands
# step 2
process_command() {
    local command="$1"

    $VERBOSE && "Received command: $command"
    case "$command" in
        q)  echo "Quit command received. Ending session..."
            exit 0 ;;
        s)  echo "Start command received. Starting question-answer session..." ;;
            # TODO: Logic to start the session (to be implemented)
        t)  echo "Time command received. Sending remaining time..." ;;
            # TODO: Logic to send remaining time (to be implemented)
        l)  echo "List command received. Sending question list..."
            list_questions ;;    # step 3
        [0-9]*)  echo "Question number $command received."
            send_question "$command" ;;  # step 3
        a)  echo "Answer command received. Processing answer..." ;;
            # TODO: Logic to process the answer (to be implemented)
        f)  echo "Finish command received. Calculating final result..." ;;
            # TODO: Logic to calculate and send the final result (to be implemented)
        *)  echo "Invalid command received: $command" ;;
    esac
}

# step 1
trap cleanup EXIT          # Set trap to clean up on exit

# Function: Main script logic
# step 1
function main() {          # step 3a
    parse_arguments "$@"   # step 3a
    create_pipe               
    load_questions         # step 3
    $VERBOSE && echo "Server is running. Waiting for client input..."

    local main_count=1
    local client_command
    while true; do
        echo "Iteration: $((main_count++))"
        read -r client_command < "$PIPE_SERVER"
        process_command "$client_command"
    done
}

main $@
