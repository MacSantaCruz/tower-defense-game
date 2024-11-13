local socket = require "socket"
-- Get the directory of the server script for local files

local Serialization = require "./serialization"
local ServerEnemyManager = require "./enemyManager"
local ServerTowerManager = require "./towerManager"
local logger = require "logger"
local MapConfig = require "utils.mapConfig"
local MessageHandler = require "utils.messageHandler"

io.stdout:setvbuf('no')  -- Disable output buffering
io.stderr:setvbuf('no')  -- Disable error buffering

local GameServer = {
    port = 12345,
    clients = {},
    gameState = {
        nextEntityId = 1
    },
    players = {
        left = nil,
        right = nil
    }
}

function GameServer:new()
    local server = setmetatable({}, { __index = self })

    server.mapConfig = MapConfig
    server.mapConfig:SetupMap()
    server.messageHandler = MessageHandler:new(server)

    -- Initialize enemy manager with paths and spawn points
    server.enemyManager = ServerEnemyManager:new({
        spawnPoints = server.mapConfig.spawnPoints,
        tileSize = server.mapConfig.tileSize
    })

    server.towerManager = ServerTowerManager:new({
        tileSize = server.mapConfig.tileSize
    })

    function server:getEnemies()
        return self.enemyManager.enemies
    end

    function server:getTowers()
        return self.towerManager.towers
    end

    server.pendingEnemyUpdates = {}
    server.pendingTowerUpdates = {}

    return server
end

function GameServer:sendToClient(client, message)
    if not client then 
        logger.error("ERROR: No client to send to!")
        return false 
    end
    
    -- Use more robust serialization
    local serialized = "return " .. Serialization.serialize(message)
    
    local success, err = client:send(serialized .. "\n")
    if not success then
        logger.error("Failed to send message to client:", err)
        return false
    end
    return true
end

function GameServer:broadcast(message)
    for client, _ in pairs(self.clients) do
        self:sendToClient(client, message)
    end
end

function GameServer:start()
    local server, err = socket.bind('*', self.port)
    if not server then
        logger.error("Failed to start server:", err)
        return false
    end
    
    server:settimeout(0)
    self.server = server
    logger.info("Server started on port", self.port)
    return true
end

function GameServer:update()
    -- Accept new connections
    local client, err = self.server:accept()
    if client then
        self:handleNewConnection(client)
    end
    
    local currentTime = socket.gettime()
    local dt = currentTime - (self.lastUpdateTime or currentTime)
    
    -- Get enemy updates from manager
    local enemyUpdates = self.enemyManager:update(dt)
    local towerUpdates = self.towerManager:update(dt, self.enemyManager.enemies)

    -- Accumulate updates as arrays
    if enemyUpdates then
        for _, update in ipairs(enemyUpdates) do
            -- Include the ID in the update itself
            table.insert(self.pendingEnemyUpdates, update)
        end
    end
    
    if towerUpdates then
        for _, update in ipairs(towerUpdates) do
            -- Include the ID in the update itself
            table.insert(self.pendingTowerUpdates, update)
        end
    end

    -- Send periodic updates
    if currentTime - (self.lastUpdateTime or 0) > 0.05 then
        -- Create a combined update message with separate lists
        local updateMessage = {
            type = "gameUpdates",
            enemyUpdates = self.pendingEnemyUpdates,
            towerUpdates = self.pendingTowerUpdates
        }

        -- Only broadcast if we have accumulated updates
        if #self.pendingEnemyUpdates > 0 or #self.pendingTowerUpdates > 0 then
            logger.info("Sending updates:")
            if #self.pendingTowerUpdates > 0 then
                logger.info("Tower updates:")
                for _, update in ipairs(self.pendingTowerUpdates) do
                    logger.info("  -", update.id, update.type)
                end
            end
            if #self.pendingEnemyUpdates > 0 then
                logger.info("Enemy updates:")
                for _, update in ipairs(self.pendingEnemyUpdates) do
                    logger.info("  -", update.id, update.type)
                end
            end
            
            self:broadcast(updateMessage)
            
            -- Clear accumulated updates after sending
            self.pendingEnemyUpdates = {}
            self.pendingTowerUpdates = {}
        end
        
        self.lastUpdateTime = currentTime
    end

    -- Handle client messages
    for client, data in pairs(self.clients) do
        local message, err = client:receive()
        if message then
            self:handleMessage(client, message)
        elseif err ~= "timeout" then
            logger.error("Receive error:", err)
            if err == "closed" then
                self:removeClient(client)
            end
        end
    end
end


function GameServer:assignPlayerSide()
    if not self.players.left then 
        self.players.left = true
        return "left"
    elseif not self.players.right then 
        self.players.right = true
        return "right"
    else 
        return nil  -- No available sides
    end
end

function GameServer:handleMessage(client, message)
    self.messageHandler:handleMessage(client, message)
end

function GameServer:removeClient(client)
    local side = self.clients[client].side
    self.players[side] = nil  -- Free up the side
    self.clients[client] = nil
    client:close()
    
    -- Notify other clients
    self:broadcast({
        type = "playerLeft",
        side = side
    })
    
    logger.info("Client disconnected:", side)
end


function GameServer:isValidTowerPlacement(data)
    
    -- Check basic data validity
    if not data.x or not data.y or not data.towerType then
        logger.error("Missing basic data")
        return false
    end
    
    -- Convert to tile coordinates
    local tileX = math.floor(data.x / self.mapConfig.tileSize) + 1
    local tileY = math.floor(data.y / self.mapConfig.tileSize) + 1
    
    -- Check map bounds
    if tileX < 1 or tileX > self.mapConfig.width or
       tileY < 1 or tileY > self.mapConfig.height then
        return false
    end
    
    -- Check if on path using mapConfig.pathTiles
    if self.mapConfig.pathTiles[tileY] and 
       self.mapConfig.pathTiles[tileY][tileX] then
        return false
    end
    
    -- Check collision with other towers
    for _, tower in pairs(self:getTowers()) do
        local dx = tower.x - data.x
        local dy = tower.y - data.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.mapConfig.tileSize * 2 then
            return false
        end
    end
    
    -- Check if player is placing on their side
    local isLeftSide = data.x < (self.mapConfig.width * self.mapConfig.tileSize / 2)
    if (data.side == "left" and not isLeftSide) or
       (data.side == "right" and isLeftSide) then
        return false
    end
    
    return true
end

function GameServer:handleNewConnection(client)
    client:settimeout(0)
    local side = self:assignPlayerSide()
    
    if side then
        self.clients[client] = {
            side = side
        }

        -- Send initialization data to the new client
        self:sendToClient(client, {
            type = "initialization",
            side = side,
            gameState = {
                enemies = self:getEnemies(),
                towers = self:getTowers(),
                nextEntityId = self.gameState.nextEntityId
            }
        })
        
        logger.info("New client connected as", side)
        
        -- Notify other clients of new player
        self:broadcast({
            type = "playerJoined",
            side = side
        })
    else
        -- Game is full
        self:sendToClient(client, {
            type = "connectionRejected",
            reason = "Game is full"
        })
        client:close()
    end
end

function GameServer:getNextId()
    local id = self.gameState.nextEntityId
    self.gameState.nextEntityId = self.gameState.nextEntityId + 1
    return id
end

-- Start the server
local server = GameServer:new()
server:start()

-- Main loop
while true do
    server:update()
    socket.sleep(1/60)  -- 60 FPS update rate
end