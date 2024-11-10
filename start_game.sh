#!/bin/bash

# Convert Windows paths to bash-compatible paths
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W 2>/dev/null || pwd)
LOVE_EXE="/c/Program Files/LOVE/love.exe"

echo "$SCRIPT_DIR"

# Function to convert Windows path to DOS path
winpath() {
    echo "$1" | sed 's|/|\\|g'
}

# Check if LÖVE exists
if [ ! -f "$LOVE_EXE" ]; then
    echo "Error: LÖVE not found at $LOVE_EXE"
    echo "Please install LÖVE or adjust the LOVE_EXE path in this script"
    exit 1
fi

# Start in client directory to run main.lua
cd "$(winpath "$SCRIPT_DIR/client")"

# Check if running as host or client
if [ "$1" == "host" ]; then
    echo "Starting game as host..."
    "$LOVE_EXE" "." host
else
    echo "Starting game as client..."
    "$LOVE_EXE" "."
fi