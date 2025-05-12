#!/bin/bash

# cbl.sh

# (c) 2025 Yakiv Koliada. Coach Ba software. All rights reserved.
# This program is free software: you can redistribute it and/or modify
# it under the terms version 3.0 of the GNU General Public License as published by
# the Free Software Foundation. This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY. See the GNU General Public License for more details.

# CBS - Coach Ba Library
# This script implements the library functionality for the Coach Ba software.
# It provides common functions and constants used by both the server and client scripts.
# It is not intended to be run directly.

# Default values
APP_NAME="cbl"                      # Application name
LOG_FOLDER="./logs"                 # Folder to store courses
SEND_DELAY=0.00                     # Delay for sending
SEND_STOP="send_stop"               # Stop sending command
REQUIRED_LOGGING=0                  # Required logging level (MUST)

# Logging levels
EMERG=0                             # Mandatory logging
CRIT=2                              # Log all critical messages
ERR=3                               # Log all error messages 
WARNING=4                           # Log all warning messages  
INFO=6                              # Log all informational messages
DEBUG=7                             # Log all debug-level messages
LOGGING_LEVEL=$EMERG                # Default logging level

# Error codes
ERR_NO=0                            # No error
ERR_OPTION=1                        # Invalid command-line option
ERR_FILE=2                          # Invalid file name
ERR_PIPE=3                          # Invalid named pipe
ERR_INTERRUPTED=5                   # Interrupted by user
ERR_UNKNOWN=6                       # Unknown error

# Function: Log a message
function log_message() {
    local required_logging="$1"
    local log_level="$2"
    local message="$3"
    local username="${USERNAME:=${CB_USERNAME}}"
    local topic="${TOPIC:=${CB_TOPIC}}"

    if [[ -z "$username" || -z "$topic" ]]; then
        error_print "Error: Username and topic are required. Use the -u and -t options or set CB_USERNAME and CB_TOPIC env variables."
        exit_program $ERR_OPTION
    fi

    local log_file="${LOG_FOLDER}/${USERNAME}_${TOPIC}_${APP_NAME}.log"

    # Ensure the logs directory exists
    [[ ! -d "${LOG_FOLDER}" ]] &&  mkdir -p "$LOG_FOLDER"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$EMERG" -eq "$required_logging" ]]; then
        echo "$timestamp | $log_level | $username | $topic | $message" >> "$log_file"
    elif [[ "$LOGGING_LEVEL" -ge "$required_logging" ]]; then
        echo "$timestamp | $log_level | $username | $topic | $message" >> "$log_file"
    fi
}

# Function: Print mandatory output
function ui_print() {
    echo -e "$1"
}

# Function: Print warning output
function warning_print() {
    local message="$1"

    echo -e "\e[33m${message}\e[0m"  # Yellow
    log_message $WARNING "WARN" "$message"
}

# Function: Print error output
function error_print() {
    local message="$1"

    echo -e "\e[31m${message}\e[0m"  # Red
    log_message $ERR "ERR" "$1"
}

# Function: Print critical error output
function critical_print() {
    local message="$1"

    echo -e "\e[41m${message}\e[0m"  # Red background
    log_message $CRIT "CRIT" "$message"
}

# Function: Print verbose output
function info_print() {
    log_message $INFO "INFO" "$1"
}

# Function: Print verbose output
function debug_print() {
    log_message $DEBUG "DEBUG" "$1"
}

# Function: Exit the program
function exit_program() {
    local message="Exiting program..."
    ui_print "$message"
    log_message $EMERG "INFO" "$message"
    exit "$1"
}

# Function: Quit the program
function quit_program() {
    ui_print "Quit command received. Ending session..."
    exit_program $ERR_NO
}

# Function: Cleanup resources on exit
function cleanup() {
    local pipe_name="$1"

    [[ -p "$pipe_name" ]] && rm -f "$pipe_name"
    info_print "Cleaned up named pipe: $pipe_name"
    
    local message="Exited successfully!"
    ui_print "$message"
    log_message $EMERG "INFO" "$message"
}

# Function: Handle unexpected crashes
function handle_crash() {
    local pipe_name="$1"
    
    error_print "Server crashed unexpectedly. Cleaning up resources..."
    exit_program $ERR_UNKNOWN
}

# Function: Handle application errors
function error_handler() {
    local function_name="${FUNCNAME[*]}"
    function_name="${function_name% main}"
    function_name="${function_name// / > }"
    local lineno="${BASH_LINENO[*]}"
    lineno="${lineno% 0}"
    lineno="${lineno// / > }"
    
    error_print "Error: '$function_name' at line ${lineno}."
}

# Function: Create the named pipe
function create_pipe() {
    local pipe_name="$1"
    local pipe_app="$2"

    if [[ -p "$pipe_name" ]]; then
        warning_print "Named pipe for $pipe_app already exists. Deleting and recreating: $pipe_name"
        rm -f "$pipe_name"
    fi

    mkfifo "$pipe_name"
    chmod 660 "$pipe_name"  # Readable and writable only by owner and group
    info_print "Created named pipe for $pipe_app: $pipe_name"
}

# Function: Validate named pipe
function validate_pipe() {
    local pipe_name="$1"
    local app_name="$2"

    if [[ ! -p "$pipe_name" ]]; then
        error_print "Error: Named pipe $pipe_name is missing or inaccessible for the '$app_name' application."
        exit_program $ERR_PIPE
    fi
}

# Function: Send stop command to the server
function send_stop() {
    local pipe_name="$1"

    validate_pipe "$pipe_name" "$APP_NAME"

    sleep $SEND_DELAY   # critical for timing
    echo "$SEND_STOP" > "$pipe_name"
    info_print "Sending complete."
}
