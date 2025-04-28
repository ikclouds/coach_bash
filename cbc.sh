#!/bin/bash

# cbc.sh

# CBC - Coach Bash Client
# This script implements the client-side functionality for the Coach Bash project.
# It communicates with the server using a named pipe.

# Include the common library functions
# step 3b
. "./cbl.sh"

# Default values
# step 3
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client
VERBOSE=false                     # Verbose output flag
SEND_DELAY=0.05                   # Delay for sending (step 3a)
SEND_STOP="send_stop"             # Stop sending command (step 3a)

# Error codes
ERR_NO=0
ERR_OPTION=1
ERR_UNKNOWN=6

# Function: Display help
# step 3
show_help() {
    ui_print "Usage: ./cbc.sh [options] [command]"
    ui_print "Options:"
    ui_print "  -h, --help      Show this help message and exit"
    ui_print "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -v, --verbose   Enable verbose output"
    ui_print "Commands:"
    ui_print "  s               Start the question-answer session"
    ui_print "  l               List available questions"
    ui_print "  [number]        Request a specific question by number"
    ui_print "  q               Quit the session"
}

# Function: Parse command-line arguments
# step 3a
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit_program $ERR_NO ;;
            -p|--pipe) PIPE_CLIENT="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) COMMAND="$1" ;;
        esac
        shift
    done
}

# Function: Send a command to the server
# step 3
function send_command() {
    local command="$1"
    if [[ -n "$command" ]]; then
      verbose_print "Sending command to server: $command"   # step 3b
      echo "$command" > "$PIPE_SERVER"
    fi
}

# Function: Handle server responses
# step 3
function get_response() {
    local response
    while true; do
        verbose_print "Waiting for server response..."   # step 3a,3b
        read -r response < "$PIPE_CLIENT" 
        if [[ "$response" =~ "$SEND_STOP" ]]; then
            verbose_print "The server has stopped sending."  # step 3a,3b
            break
        fi
        ui_print "$response"    # step 3b
    done
}

# Function to process client commands
# step 3
process_command() {
    local command="$1"

    verbose_print "Entered: $command"  # step 3b
    case "$command" in
        s)  ui_print "Starting question-answer session..." ;;   # step 3b
        l)  ui_print "Listing available questions..."   # step 3b
            send_command "$command"
            get_response ;;
        [0-9]*) ui_print "Requesting question number $command ..."  # step 3b
            send_command "$command"
            get_response ;;
        q)  ui_print "Quitting the session..."  # step 3b
            exit_program $ERR_NO ;;
        h)  ui_print "Displaying help..."   # step 3b
            show_help ;;
        *)  ui_print "Unknown command: $command" ;;     # step 3b
    esac
}

# step 3
trap "cleanup $PIPE_CLIENT" EXIT          # Set trap to clean up on exit, step 3b

# Function: Main script logic
# step 3
function main() {          # step 3a
    parse_arguments "$@"   # step 3a
    create_pipe "$PIPE_CLIENT" "$0"     # step 3b
    verbose_print "Client is running. Waiting for user input..."    # step 3b

    local main_count=1
    local user_input
    while true; do
        ui_print "Iteration: $((main_count++))"     # step 3b
        read -p "Enter command: " user_input
        process_command "$user_input"
    done
}

main "$@"
