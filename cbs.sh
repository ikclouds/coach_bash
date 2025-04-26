#!/bin/bash

# CBS - Coach Bash Server
# This script implements the server-side functionality for the Coach Bash project.
# It uses a named pipe for communication with the client.
# Usage: ./cbs.sh [options]
# Options:
#   -h, --help      Show this help message and exit
#   -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)
#   -v, --verbose   Enable verbose output
#   -d, --debug     Enable debug output
#   -q, --quit      Quit the script

# Step 1: Named Pipe Management

# Default values
# step 1
PIPE_NAME="/tmp/cbs_pipe"
VERBOSE=false

# Function to display help
# step 1
show_help() {
    echo "Usage: ./cbs.sh [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    echo "  -v, --verbose   Enable verbose output"
    echo "  -q, --quit      Quit the script"
}

# Parse command-line arguments
# step 1
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -p|--pipe) PIPE_NAME="$2"; shift ;;
        -v|--verbose) VERBOSE=true ;;
        -q|--quit) echo "Exiting..."; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Function to create the named pipe
# step 1
create_pipe() {
    if [[ ! -p "$PIPE_NAME" ]]; then
        if $VERBOSE; then echo "Creating named pipe: $PIPE_NAME"; fi
        mkfifo "$PIPE_NAME"
    else
        if $VERBOSE; then echo "Named pipe already exists: $PIPE_NAME"; fi
    fi
}

# Cleanup function to remove the named pipe on exit
# step 1
cleanup() {
    if [[ -p "$PIPE_NAME" ]]; then
        if $VERBOSE; then echo "Removing named pipe: $PIPE_NAME"; fi
        rm -f "$PIPE_NAME"
    fi
}

# Set trap to clean up on exit
# step 1
trap cleanup EXIT

# Function to process client commands
# step 2
process_command() {
    local command="$1"
    case "$command" in
        q) 
            echo "Quit command received. Ending session."
            exit 0
            ;;
        s)
            echo "Start command received. Starting question-answer session."
            # Logic to start the session (to be implemented)
            ;;
        t)
            echo "Time command received. Sending remaining time."
            # Logic to send remaining time (to be implemented)
            ;;
        l)
            echo "List command received. Sending question list."
            # Logic to send question list (to be implemented)
            ;;
        [0-9] | [0-9][0-9] )
            echo "Question number $command received. Sending question and answers."
            # Logic to send question and answers (to be implemented)
            ;;
        a)
            echo "Answer command received. Processing answer."
            # Logic to process the answer (to be implemented)
            ;;
        f)
            echo "Finish command received. Calculating final result."
            # Logic to calculate and send the final result (to be implemented)
            ;;
        *)
            echo "Invalid command received: $command"
            ;;
    esac
}

# Main script logic
# step 1
create_pipe
if $VERBOSE; then echo "Server is running. Waiting for client input..."; fi

# Read and process commands from the named pipe
# step 1
while true; do
    if read -r line < "$PIPE_NAME"; then
        if $VERBOSE; then echo "Received: $line"; fi
        process_command "$line"   # step 2
    fi
done
