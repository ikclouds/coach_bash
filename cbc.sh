#!/bin/bash

# CBS - Coach Bash Client
# This script implements the client-side functionality for the Coach Bash project.
# It uses a named pipe for communication with the server.
# Usage: ./cbs.sh [options] command
# Options:
#   -h, --help      Show this help message and exit

# Default values
# step 2
PIPE_NAME="/tmp/cbs_pipe"

# Function to test Step 2
# step 2
echo "$1" > "$PIPE_NAME"
