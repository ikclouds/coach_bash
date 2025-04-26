#!/bin/bash

# CBC - Coach Bash Client
# This script implements the client-side functionality for the Coach Bash project.
# It communicates with the server using a named pipe.

# Default values
# step 3
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client
VERBOSE=false                     # Verbose output flag

# Function to display help
# step 3
show_help() {
    echo "Usage: ./cbc.sh [options] [command]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    echo "  -v, --verbose   Enable verbose output"
    echo "Commands:"
    echo "  s               Start the question-answer session"
    echo "  l               List available questions"
    echo "  [number]        Request a specific question by number"
    echo "  q               Quit the session"
}

# Parse command-line arguments
# step 3
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -p|--pipe) PIPE_CLIENT="$2"; shift ;;
        -v|--verbose) VERBOSE=true ;;
        *) COMMAND="$1" ;;
    esac
    shift
done

# Ensure the named pipe exists
# step 3
if [[ ! -p "$PIPE_SERVER" ]]; then
    echo "Error: Server named pipe not found: $PIPE_SERVER"
    exit 1
fi

# Function to create the client named pipe
# step 3
create_pipe() {
    if [[ ! -p "$PIPE_CLIENT" ]]; then
        if $VERBOSE; then echo "Creating named pipe: $PIPE_CLIENT"; fi
        mkfifo "$PIPE_CLIENT"
    else
        if $VERBOSE; then echo "Named pipe already exists: $PIPE_CLIENT"; fi
    fi
}

# Cleanup function to remove the named pipe on exit
# step 3
cleanup() {
    if [[ -p "$PIPE_CLIENT" ]]; then
        if $VERBOSE; then echo "Removing named pipe: $PIPE_CLIENT"; fi
        rm -f "$PIPE_CLIENT"
    fi
}

# Set trap to clean up on exit
# step 3
trap cleanup EXIT

# Function for sending a command to the server
# step 3
function send_command() {
    local command="$1"
    if [[ -n "$command" ]]; then
      if $VERBOSE; then echo "Sending command to server: $command"; fi
      echo "$command" > "$PIPE_SERVER" &
    fi
}

# Function to handle server responses
# step 3
function get_response() {
    local response
    while true; do
        if $VERBOSE; then echo "Waiting for server response..."; fi
        read -r response < "$PIPE_CLIENT" 
        if [[ "$response" =~ "send_stop" ]]; then
            if $VERBOSE; then echo "The server has stopped sending."; fi
            break
        fi
        [[ -n "$response" ]] && echo "$response"
    done
}

# Function to process client commands
# step 3
process_command() {
    local command="$1"
    case "$command" in
        s) 
          echo "Starting question-answer session..." 
          ;;
        l) 
          echo "Listing available questions..." 
          send_command "$command"
          get_response
          ;;
        [0-9]*) 
          local question_number="$command"
          echo "Requesting question number $question_number ..."
          send_command "$command"
          get_response
          ;;
        q) 
          echo "Quitting the session..." 
          exit 0
          ;;
        h)
          echo "Displaying help..."
          show_help
          send_command "$command"
          ;;        
        *) 
          echo "Unknown command: $command"
          ;;
    esac
}

# Main script logic
# step 3
create_pipe
if $VERBOSE; then echo "Client is running. Waiting for user input..."; fi

# Read user's commands and process server-side answers
# step 3
main_count=1
while true; do
    echo "Iteration: $((main_count++))"
    if read -p "Enter command: " -r line; then
        if $VERBOSE; then echo "Received: $line"; fi
        process_command "$line"
    fi    
done
