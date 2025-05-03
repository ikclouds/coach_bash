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
RESPONSE=false                    # Response output flag

# State variables
USERNAME=""                       # Username of the client
SESSION=""                        # Session info from the server
TEST_START_TIME=""                # Test start date-time
LAST_QUESTION=""                  # Last question number

# Error codes
ERR_NO=0                          # No error
ERR_OPTION=1                      # Invalid command-line option
ERR_UNKNOWN=6                     # Unknown error

# Function: Display help
function show_help() {
    ui_print "Usage: ./cbc.sh [options] [command]"
    ui_print "Options:"
    ui_print "  -h, --help      Show this help message and exit"
    ui_print "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -u, --username  Specify username (required)"
    ui_print "  -v, --verbose   Enable verbose output"
    show_commands

    exit_program $ERR_NO
} 

# Function: Display commands
function show_commands() {
    ui_print "Commands:"
    ui_print "  [number]        Request a specific question by number 0-99"
    ui_print "  a               Submit an answer"
    ui_print "  f               Finish the question-answer session"
    ui_print "  i               Show course information"
    ui_print "  l               List available questions"
    ui_print "  p               List progress of answered questions"
    ui_print "  q               Quit the program"
    ui_print "  r               Set/Unset (repeat) question for answering later"
    ui_print "  s               Start the question-answer session"
    ui_print "  t               Show remaining time"
}

# Function: Parse command-line arguments
function parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help ;;
            -p|--pipe) PIPE_CLIENT="$2"; shift ;;
            -u|--username) USERNAME="$2"; shift ;;
            -v|--verbose) VERBOSE=true ;;
            *) COMMAND="$1" ;;
        esac
        shift
    done

    # Validate username
    if [[ -z "$USERNAME" ]]; then
        ui_print "Error: Username is required. Use the -u option to specify it."
        exit_program $ERR_OPTION
    fi

    verbose_print "Username: $USERNAME"
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
        elif [[ "$response" =~ "Error: Question" ]]; then
            LAST_QUESTION=""
        fi
        ui_print "$response"
    done
}

# Function: Start the test session
function start_test_session() {
    verbose_print "Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        send_command "s"                    # Send start command to server
        TEST_START_TIME=$(get_response)     # Capture the test start date-time
        ui_print "Test session started at: $TEST_START_TIME"
    else
        ui_print "Test session already started..."
    fi
}

# Function: Get the list of questions
function list_questions() {
    local command="$1"

    verbose_print "Listing available questions..."
    send_command "$command"
    get_response
}

# Function: Get a specific question from the server
function get_question () {
    LAST_QUESTION="$1"
    
    verbose_print "Requesting question number $LAST_QUESTION ..."
    send_command "$LAST_QUESTION"
    get_response
}

# Function: Submit an answer
function submit_answer() {
    if [[ -z "$TEST_START_TIME" ]]; then
        ui_print "Error: No session started. Please start a session first."
        return 1
    fi
    ui_print "Last question: $LAST_QUESTION"
    ui_print "Examples of answers: 1|3 (one-choice); 2|1,3 (multiple-choice); 3|my answer (text)."
    ui_print "Enter your answer (question|answer):" | tr '\n' ' '
    read -e -i "${LAST_QUESTION}|" -r user_answer
    send_command "a|$user_answer"
    local response=$(get_response)
    [[ "$response" =~ "Server response:" ]] && RESPONSE=true
    $RESPONSE && ui_print "$response"
}

# Function: Display progress of answers
function display_progress() {
    verbose_print "Requesting progress list from server..."
    send_command "p"
    local progress_list=$(get_response)
    ui_print "$progress_list"
}

# Function: Mark a question for answering later
function mark_question_for_later() {
    local question_number="$1"

    if [[ -z "$question_number" ]]; then
        ui_print "Please select question by number."
        return
    fi
    ui_print "Marking question $question_number for answering later..."
    send_command "r|$question_number"
    local response=$(get_response)
    ui_print "$response"
}

# Function: Display remaining time
function display_remaining_time() {
    verbose_print "Requesting remaining time from server..."
    send_command "t"
    local time_info=$(get_response)
    ui_print "$time_info"
}

# Function: Display course information
function display_session_info() {
    verbose_print "Requesting session info from server..."
    send_command "i"
    local session_info=$(get_response)
    if [[ -z "$session_info" ]]; then
        ui_print "Error: Unable to retrieve session info."
        return
    fi
    SESSION="$session_info"
    ui_print "$SESSION"
}

# Function: Finish the session
finish_session() {
    ui_print "Ending the session and requesting final result..."
    send_command "f"
    local final_result=$(get_response)
    ui_print "$final_result"
    quit_program
}

# Function to process client commands
function process_command() {
    local command="$1"

    [[ ! "ts" =~ "${command}" ]] && display_remaining_time
    [[ ! "i" =~ "${command}" ]] && display_session_info
    verbose_print "Entered: $command"
    case "$command" in
        h)  show_commands ;;
        s)  start_test_session ;;
        l)  list_questions "$command" ;;
        i)  display_session_info ;;
        p)  display_progress ;;
        r)  mark_question_for_later "$LAST_QUESTION" ;;
        t)  display_remaining_time ;;
        [0-9]|[0-9][0-9]) get_question "$command" ;;
        a)  submit_answer ;;
        f)  finish_session ;;
        q)  quit_program ;;
        *)  ui_print "Unknown command: $command" ;;
    esac
}

trap "cleanup $PIPE_CLIENT" EXIT  # Set trap to clean up on exit

# Function: Main script logic
function main() {
    ui_print "Client is starting..."
    parse_arguments "$@"
    create_pipe "$PIPE_CLIENT" "$0"
    verbose_print "Client is running. Waiting for user input..."

    local main_count=1
    local user_input
    while true; do
        ui_print "---\nIteration: $((main_count++))"
        read -p "Enter command: " user_input
        process_command "$user_input"
    done
}

main "$@"
