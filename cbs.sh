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
PIPE_NAME="/tmp/cbs_pipe"
VERBOSE=false

# Function to display help
show_help() {
    echo "Usage: ./cbs.sh [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -p, --pipe      Specify the name of the named pipe to use (default: /tmp/cbs_pipe)"
    echo "  -v, --verbose   Enable verbose output"
    echo "  -q, --quit      Quit the script"
}

# Parse command-line arguments
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
create_pipe() {
    if [[ ! -p "$PIPE_NAME" ]]; then
        if $VERBOSE; then echo "Creating named pipe: $PIPE_NAME"; fi
        mkfifo "$PIPE_NAME"
    else
        if $VERBOSE; then echo "Named pipe already exists: $PIPE_NAME"; fi
    fi
}

# Cleanup function to remove the named pipe on exit
cleanup() {
    if [[ -p "$PIPE_NAME" ]]; then
        if $VERBOSE; then echo "Removing named pipe: $PIPE_NAME"; fi
        rm -f "$PIPE_NAME"
    fi
}

# Set trap to clean up on exit
trap cleanup EXIT

# Main script logic
create_pipe
if $VERBOSE; then echo "Server is running. Waiting for client input..."; fi

# Example: Read from the pipe (this will block until input is received)
while true; do
    if read -r line < "$PIPE_NAME"; then
        if $VERBOSE; then echo "Received: $line"; fi
        # Process the input (to be implemented in later steps)
    fi
done

