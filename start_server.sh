#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W 2>/dev/null || pwd)
LOG_DIR="$SCRIPT_DIR/server/logs"
LOG_FILE="$LOG_DIR/server_$(date +%Y%m%d_%H%M%S).log"

LUA_EXE="/c/Program Files (x86)/Lua/5.1/lua.exe"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to convert Windows path to DOS path
winpath() {
    echo "$1" | sed 's|/|\\|g'
}

# Change to server directory before starting
cd "$SCRIPT_DIR/server" || exit 1

echo "Starting dedicated server..."
echo "Logs will be written to: $(winpath "$LOG_FILE")"

# Force output buffering off for Lua
export LUA_EXECUTABLE="$LUA_EXE"

# Run with explicit output handling
"$LUA_EXE" -e "io.stdout:setvbuf('no')" server.lua 2>&1 | tee "$(winpath "$LOG_FILE")"