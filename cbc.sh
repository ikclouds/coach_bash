#!/bin/bash

# cbc.sh

# (c) 2025 Yakiv Koliada. Coach Ba software. All rights reserved.
# This program is free software: you can redistribute it and/or modify
# it under the terms version 3.0 of the GNU General Public License as published by
# the Free Software Foundation. This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. See the GNU General Public License for more details.

# CBC - Coach Ba Client
# This script implements the client-side functionality for the Coach Ba software.
# It communicates with the server using a named pipe.

# Usage:
#   cbc.sh [-u <username>] [-t <topic>] [options]

# Disable exit on error to allow for custom error handling
set +e 

# Import externals
. .env       # Environment variables
. cbl.sh     # Common Bash Library for logging and utilities

# Default values
APP_NAME="cbc"                          # Application name
PIPE_FOLDER="/opt/cb"                   # Default folder for named pipes
PIPE_SERVER="/$PIPE_FOLDER/cbs_pipe"    # Default named pipe for server
PIPE_CLIENT="/$PIPE_FOLDER/cbc_pipe"    # Default named pipe for client
RESPONSE=false                          # Response output flag
EXTENDED=false                          # Extended information flag

# State variables
USERNAME=""                             # Username of the client
TOPIC=""                                # Topic (course code)
SESSION=""                              # Session info from the server
TEST_START_TIME=""                      # Test start date-time
LAST_QUESTION=""                        # Last question number
LAST_COMMAND=""                         # Last command entered by the user

# Function: Display help
function show_help() {
    ui_print "cbc.sh [-u <username>] [-t <topic>] [options]"
    ui_print "Options:"
    ui_print "  -h, --help                   Show this help message and exit"
    ui_print "  -e, --extended               Show extended information (time, course)"
    ui_print "  -p file, --pipe file         Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    ui_print "  -t topic, --topic topic      Specify the topic (course code) to use (required or set CB_TOPIC env variable)"
    ui_print "  -u user, --username user     Specify username (required or set CB_USERNAME env variable)"
    ui_print "  -v                           Logging level for CRIT messages and above"
    ui_print "  -vv                          Logging level for ERR messages and above"
    ui_print "  -vvv                         Logging level for WARNING messages and above"
    ui_print "  -vvvv                        Logging level for INFO messages and above"
    ui_print "  -vvvvv                       Logging level for DEBUG messages and above"
    show_commands
} 

# Function: Display commands
function show_commands() {
    ui_print "Commands:"
    ui_print "  [number]        Request a specific question by number 1-99"
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
            -h|--help) show_help; exit_program $ERR_NO ;;
            -e|--extended) EXTENDED=true ;;
            -p|--pipe) PIPE_CLIENT="$2"; shift ;;
            -t|--topic) TOPIC="$2"; shift ;;
            -u|--username) USERNAME="$2"; shift ;;
            -v) LOGGING_LEVEL=$CRIT ;;
            -vv) LOGGING_LEVEL=$ERR ;;
            -vvv) LOGGING_LEVEL=$WARN ;;
            -vvvv) LOGGING_LEVEL=$INFO ;;
            -vvvvv) LOGGING_LEVEL=$DEBUG ;;
            *) show_help
               error_print "Error: Unknown option: $1"
               exit_program $ERR_OPTION ;;
        esac
        shift
    done

    # Use environment variables if command-line options are not provided
    USERNAME="${USERNAME:-$CB_USERNAME}"
    TOPIC="${TOPIC:-$CB_TOPIC}"

    # Validate username and topic
    if [[ -z "$USERNAME" || -z "$TOPIC" ]]; then
        error_print "Error: Username and topic are required. Use the -u and -t options or set CB_USERNAME and CB_TOPIC env variables."
        exit_program $ERR_OPTION
    fi

    log_message $EMERG "INFO" "Logging level: $LOGGING_LEVEL"
    log_message $EMERG "INFO" "Username: $USERNAME"    
}

# Function: Send a command to the server
function send_command() {
    local command="$1"

    validate_pipe "$PIPE_SERVER" "$APP_NAME"

    if [[ -n "$command" ]]; then
      info_print "Sending command to server: $command"
      echo "$command" > "$PIPE_SERVER"
    fi
}

# Function: Handle server responses
function get_response() {
    local response
    local error=false

    while true; do
        debug_print "Waiting for server response..."
        read -r response < "$PIPE_CLIENT"
        if [[ "$response" =~ "$SEND_STOP" ]]; then
            info_print "The server has stopped sending."
            break
        elif [[ "$response" =~ "Error: Question" ]]; then
            LAST_QUESTION=""
            error=true
        fi
        if [[ $error == true ]]; then
            warning_print "$response"
        else
            ui_print "$response"
            [[ "$LAST_COMMAND" != "f" ]] && log_message $DEBUG - "$response"
        fi
    done
}

# Function: Start the test session
function start_test_session() {
    info_print "Starting question-answer session..."
    if [[ -z "$TEST_START_TIME" ]]; then
        send_command "s"                    # Send start command to server
        TEST_START_TIME=$(get_response)     # Capture the test start date-time
        
        local message="Test session started at: $TEST_START_TIME"
        ui_print "$message"
        log_message $INFO - "$message"
    else
        warning_print "Test session already started..."
    fi
}

# Function: Get the list of questions
function list_questions() {
    local command="$1"

    info_print "Listing available questions..."
    send_command "$command"
    get_response
}

# Function: Get a specific question from the server
function get_question () {
    LAST_QUESTION="$1"

    info_print "Requesting question number $LAST_QUESTION ..."
    send_command "$LAST_QUESTION"
    get_response
}

# Function: Submit an answer
function submit_answer() {
    if [[ -z "$TEST_START_TIME" ]]; then
        error_print "Error: No session started. Please start a session first."
        return
    fi
    local remaining_time=$(get_remaining_time)
    if [[ "$remaining_time" =~ "Time is up" ]]; then
        ui_print "Time is up. No further commands are allowed."
        return
    fi
    message="Last question: $LAST_QUESTION"
    ui_print "$message"
    log_message $INFO - "$message"
    ui_print "Examples of answers: 1|3 (one-choice); 2|1,3 (multiple-choice); 3|my answer (text)."
    ui_print "Enter your answer (question|answer):" | tr '\n' ' '
    read -e -i "${LAST_QUESTION}|" -r user_answer
    send_command "a|$user_answer"
    log_message $INFO - "Answer: $user_answer"
    local response=$(get_response)
    [[ "$response" =~ "Server response:" ]] && RESPONSE=true
    if $RESPONSE; then
        ui_print "$response"
    fi
}

# Function: Display progress of answers
function display_progress() {
    info_print "Requesting progress list from server..."
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
    info_print "Requesting remaining time from server..."
    send_command "t"
    local time_info=$(get_response)
    ui_print "$time_info"
}

# Function: Get remaining time
function get_remaining_time() {
    send_command "t"
    local time_info=$(get_response)
    echo "$time_info"
}

# Function: Display course information
function display_session_info() {
    info_print "Requesting session info from server..."
    send_command "i"
    local session_info=$(get_response)
    if [[ -z "$session_info" ]]; then
        error_print "Error: Unable to retrieve session info."
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
    log_message $EMERG "INFO" "$final_result"
    quit_program
}

function init_application() {
    # Set trap to handle errors
    trap "error_handler" ERR
    
    local message="Client is starting..."
    ui_print "$message"

    parse_arguments "$@"
    log_message $EMERG "INFO" "$message"
    log_message $EMERG "INFO" "Topic: $TOPIC"

    # Create the named pipe for server-client communication
    local pipe_client="/$PIPE_FOLDER/${USERNAME}_${TOPIC}_cbc_pipe"
    PIPE_CLIENT="${pipe_client:-${PIPE_CLIENT}}"
    create_pipe "$PIPE_CLIENT" "$0"
    local pipe_server="/$PIPE_FOLDER/${USERNAME}_${TOPIC}_cbs_pipe"
    PIPE_SERVER="${pipe_server:-${PIPE_SERVER}}"

    # Set trap to handle crashes
    trap "handle_crash $PIPE_CLIENT" INT TERM
    # Set trap to clean up on exit
    trap "cleanup $PIPE_CLIENT" EXIT
    
    info_print "Client is running. Waiting for user input..."
}

# Function to process client commands
function process_command() {
    local command="$1"
    LAST_COMMAND="$command"

    if $EXTENDED; then
        [[ ! "i" =~ "${command}" ]] && display_session_info
        [[ ! "tsi" =~ "${command}" ]] && display_remaining_time
    fi
    info_print "Entered: $command"
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
        *)  warning_print "Unknown command: $command" 
            LAST_COMMAND="" ;;
    esac
}

# Function: Main script logic
function main() {
    init_application "$@"

    local iteration=1
    local user_input
    while true; do
        ui_print "---\nIteration: $((iteration++))"
        read -p "Enter command (h - help): " user_input
        process_command "$user_input"
    done
}

main "$@"
