#!/bin/bash

# cbc.sh

# CBC - Coach Bash Client
# This script implements the client-side functionality for the Coach Bash project.
# It communicates with the server using a named pipe.

# Include the common library functions
. "./cbl.sh"

# Default values
PIPE_SERVER="/tmp/cbs_pipe"       # Default named pipe for server
PIPE_CLIENT="/tmp/cbc_pipe"       # Default named pipe for client
VERBOSE=false                     # Verbose output flag

# State variables
TEST_START_TIME=""                # Test start date-time

# Error codes
ERR_NO=0                          # No error
ERR_OPTION=1                      # Invalid command-line option
ERR_UNKNOWN=6                     # Unknown error

# Function: Display help
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
function send_command() {
    local command="$1"
    if [[ -n "$command" ]]; then
      verbose_print "Sending command to server: $command"
      echo "$command" > "$PIPE_SERVER"
    fi
}

# Function: Handle server responses
function get_response() {
    local response
    while true; do
        verbose_print "Waiting for server response..."
        read -r response < "$PIPE_CLIENT" 
        if [[ "$response" =~ "$SEND_STOP" ]]; then
            verbose_print "The server has stopped sending."
            break
        fi
        ui_print "$response"
    done
}

# Function: Start the test session
# step 3c
start_test_session() {
    verbose_print "Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        send_command "s"                    # Send start command to server
        TEST_START_TIME=$(get_response)     # Capture the test start date-time
        ui_print "Test session started at: $TEST_START_TIME"
    else
        ui_print "Test session already started..."
    fi
}

# Function: Display test start date-time
# step 3c
display_test_start_time() {
    if [[ -n "$TEST_START_TIME" ]]; then
        ui_print "Test session started at: $TEST_START_TIME"
    fi
}

# Function to process client commands
process_command() {
    local command="$1"

    display_test_start_time  # step 3c
    verbose_print "Entered: $command"
    case "$command" in
        s)  start_test_session ;;
        l)  ui_print "Listing available questions..."
            send_command "$command"
            get_response ;;
        [0-9]*) ui_print "Requesting question number $command ..."
            send_command "$command"
            get_response ;;
        q)  ui_print "Quitting the session..."
            exit_program $ERR_NO ;;
        h)  ui_print "Displaying help..."
            show_help ;;
        *)  ui_print "Unknown command: $command" ;;
    esac
}

trap "cleanup $PIPE_CLIENT" EXIT          # Set trap to clean up on exit

# Function: Main script logic
function main() {
    parse_arguments "$@"
    create_pipe "$PIPE_CLIENT" "$0"
    verbose_print "Client is running. Waiting for user input..."

    local main_count=1
    local user_input
    while true; do
        ui_print "Iteration: $((main_count++))"
        read -p "Enter command: " user_input
        process_command "$user_input"
    done
}

main "$@"
