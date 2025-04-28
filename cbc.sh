#!/bin/bash

# cbc.sh

# CBC - Coach Bash Client
# This script implements the client-side functionality for the Coach Bash project.
# It communicates with the server using a named pipe.

# Default values
# step 3
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client
VERBOSE=false                     # Verbose output flag
SEND_DELAY=0.05                   # Delay for sending (step 3a)
SEND_STOP="send_stop"             # Stop sending command (step 3a)

# Function: Display help
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

# Function: Parse command-line arguments
# step 3a
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -p|--pipe) PIPE_CLIENT="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) COMMAND="$1" ;;
        esac
        shift
    done
}

# Function: Create the client named pipe
# step 3
create_pipe() {
    if [[ ! -p "$PIPE_CLIENT" ]]; then
        $VERBOSE && echo "Creating client named pipe: $PIPE_CLIENT"     # step 3a
        mkfifo "$PIPE_CLIENT"
    else
        $VERBOSE && echo "Client named pipe already exists: $PIPE_CLIENT"   # step 3a
    fi
}

# Function: Cleanup resources on exit
# step 3
cleanup() {
    [[ -p "$PIPE_CLIENT" ]] && rm -f "$PIPE_CLIENT"
    $VERBOSE && echo "Cleaned up client named pipe: $PIPE_CLIENT"   # step 3a
}

# Function: Send a command to the server
# step 3
function send_command() {
    local command="$1"
    if [[ -n "$command" ]]; then
      $VERBOSE && echo "Sending command to server: $command"
      echo "$command" > "$PIPE_SERVER"
    fi
}

# Function: Handle server responses
# step 3
function get_response() {
    local response
    while true; do
        $VERBOSE && echo "Waiting for server response..."   # step 3a
        read -r response < "$PIPE_CLIENT" 
        if [[ "$response" =~ "$SEND_STOP" ]]; then
            $VERBOSE && echo "The server has stopped sending."  # step 3a
            break
        fi
        echo "$response"
    done
}

# Function to process client commands
# step 3
process_command() {
    local command="$1"

    $VERBOSE && echo "Entered: $line"
    case "$command" in
        s)  echo "Starting question-answer session..." ;;
        l)  echo "Listing available questions..." 
            send_command "$command"
            get_response ;;
        [0-9]*) echo "Requesting question number $command ..."
            send_command "$command"
            get_response ;;
        q)  echo "Quitting the session..." 
            exit 0 ;;
        h)  echo "Displaying help..."
            show_help ;;
        *)  echo "Unknown command: $command" ;;
    esac
}

# step 3
trap cleanup EXIT          # Set trap to clean up on exit

# Function: Main script logic
# step 3
function main() {          # step 3a
    parse_arguments "$@"   # step 3a
    create_pipe
    $VERBOSE && echo "Client is running. Waiting for user input..."

    local main_count=1
    local user_input
    while true; do
        echo "Iteration: $((main_count++))"
        read -p "Enter command: " user_input
        process_command "$user_input"
    done
}

main "$@"
