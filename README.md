# Tower Defense Game

A multiplayer tower defense game built with LÖVE framework and Lua.

## Setup

### Server Setup

1. Install dependencies:

```bash
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luasocket
```

2. Deploy the server:

```bash
# Copy server files
./deploy.sh

# Start the server
sudo systemctl start luagame
```

### Client Setup

1. Install LÖVE framework from https://love2d.org/
2. Run the client:

```bash
# Development
love client/

# Or use the packaged version
# Download and run YourGame.exe from the releases page
```

## Development

### Building the Client

```bash
./package-windows.bat
```

### Deploying Server Updates

```bash
./deploy.sh
```
