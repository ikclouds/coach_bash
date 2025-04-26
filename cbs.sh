#!/bin/bash

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

# Function to display help
# step 1
show_help() {
    echo "Usage: ./cbs.sh [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    echo "  -q, --questions Specify the question file to use (default: ./questions.txt)"  # step 3
    echo "  -v, --verbose   Enable verbose output"
}

# Parse command-line arguments
# step 1
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -p|--pipe) PIPE_SERVER="$2"; shift ;;
        -q|--questions) QUESTION_FILE="$2"; shift ;;  # step 3
        -v|--verbose) VERBOSE=true ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Function to create the named pipe
# step 1
create_pipe() {
    if [[ ! -p "$PIPE_SERVER" ]]; then
        if $VERBOSE; then echo "Creating named pipe: $PIPE_SERVER"; fi
        mkfifo "$PIPE_SERVER"
    else
        if $VERBOSE; then echo "Named pipe already exists: $PIPE_SERVER"; fi
    fi
}

# Cleanup function to remove the named pipe on exit
# step 1
cleanup() {
    if [[ -p "$PIPE_SERVER" ]]; then
        if $VERBOSE; then echo "Removing named pipe: $PIPE_SERVER"; fi
        rm -f "$PIPE_SERVER"
    fi
}

# Set trap to clean up on exit
# step 1
trap cleanup EXIT

# Function to load questions from the file
# step 3
load_questions() {
    if [[ ! -f "$QUESTION_FILE" ]]; then
        echo "Error: Question file not found: $QUESTION_FILE"
        exit 1
    fi

    if $VERBOSE; then echo "Loading questions from file: $QUESTION_FILE"; fi
    mapfile -t QUESTIONS < "$QUESTION_FILE"
}

# Function to send a question to the client
# step 3
send_question() {
    local question_number="$1"
    local question_line="${QUESTIONS[$((question_number - 1))]}"
    if [[ -z "$question_line" ]]; then
        echo "> Error: Question $question_number not found."
        echo "> Error: Question $question_number not found." > "$PIPE_CLIENT" &
    else
      echo "Sending question $question_number to client..."
      IFS='|'; read -t 1 -r number question type options correct <<< "$question_line"
      echo "> Question: $question"
      echo -n "> Question: $question" > "$PIPE_CLIENT" &
      if [[ "$type" == "multiple-choice" ]]; then
          local option
          echo "$options" | while read -d '/' -r option; do
              echo "> $option"
              echo -n "> $option" >> "$PIPE_CLIENT" &
          done
      fi
      if [[ "$type" == "text" ]]; then
          echo "> $options"
          echo -n "> $options" >> "$PIPE_CLIENT" &
      fi
    fi
    echo "send_stop" >> "$PIPE_CLIENT" &
    if $VERBOSE; then echo "Sending complete."; fi
}

# Function to list questions and send them to the client
# step 3
list_questions() {
    local question_line=""

    IFS='|'
    for i in "${!QUESTIONS[@]}"; do
        question_line="${QUESTIONS[$i]}"
        read -r number question type options correct <<< "$question_line"
        echo "> Question $((i + 1)): $question"
        echo -n "> Question $((i + 1)): $question" >> "$PIPE_CLIENT"
    done
    echo "send_stop" >> "$PIPE_CLIENT" &
    if $VERBOSE; then echo "Sending complete."; fi
}

# Function to process client commands
# step 2
process_command() {
    local command="$1"
    case "$command" in
        q) 
            echo "Quit command received. Ending session..."
            exit 0
            ;;
        s)
            echo "Start command received. Starting question-answer session..."
            # Logic to start the session (to be implemented)
            ;;
        t)
            echo "Time command received. Sending remaining time..."
            # Logic to send remaining time (to be implemented)
            ;;
        l)
            # Logic to list questions
            # step 3
            echo "List command received. Sending question list..."
            list_questions    # step 3
            ;;
        [0-9] | [0-9][0-9] )
            echo "Question number $command received. Sending question and answers..."
            send_question "$command"
            ;;
        a)
            echo "Answer command received. Processing answer..."
            # Logic to process the answer (to be implemented)
            ;;
        f)
            echo "Finish command received. Calculating final result..."
            # Logic to calculate and send the final result (to be implemented)
            ;;
        h)
            echo "Displaying help..."   # step 3
            show_help
            ;;
        *)
            echo "Invalid command received: $command"
            ;;
    esac
}

# Main script logic
# step 1
create_pipe     # step 1
load_questions  # step 3
if $VERBOSE; then echo "Server is running. Waiting for client input..."; fi

# Read and process commands from the named pipe
# step 1
main_count=1
while true; do
    echo "Iteration: $((main_count++))"
    if read -r line < "$PIPE_SERVER"; then
        if $VERBOSE; then echo "Received: $line"; fi
        process_command "$line"   # step 2
    fi
done
