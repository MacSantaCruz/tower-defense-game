#!/bin/bash

SERVER_IP="24.199.101.226"
SERVER_USER="gameadmin"

echo "Deploying to game server..."

# Stop the server
echo "Stopping server..."
ssh ${SERVER_USER}@${SERVER_IP} "sudo systemctl stop luagame"

# Copy files
echo "Copying files..."
scp -r ./server/* ${SERVER_USER}@${SERVER_IP}:~/luagame/server/

# Start the server
echo "Starting server..."
ssh ${SERVER_USER}@${SERVER_IP} "sudo systemctl start luagame"

echo "Deployment complete!"
echo "Showing logs (Ctrl+C to exit)..."
ssh ${SERVER_USER}@${SERVER_IP} "tail -f ~/luagame/server/logs/server.log"