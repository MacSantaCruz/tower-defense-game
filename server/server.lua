local socket = require "socket"
-- Get the directory of the server script for local files

local Serialization = require "./serialization"
local ServerEnemyManager = require "./enemyManager"
local ServerTowerManager = require "./towerManager"
local logger = require "logger"

io.stdout:setvbuf('no')  -- Disable output buffering
io.stderr:setvbuf('no')  -- Disable error buffering

local GameServer = {
    port = 12345,
    clients = {},
    gameState = {
        towers = {},
        enemies = {},
        nextEntityId = 1
    },
    players = {
        left = nil,
        right = nil
    }
}

function GameServer:new()
    local server = setmetatable({}, { __index = self })
    -- Add game configuration
    local mapData = require("maps/kek_3")  
    
    -- Add game configuration
    server.tileSize = 32  -- Same as client
    server.mapConfig = {
        width = 75 * 2,      -- Number of tiles wide
        height = 56,      -- Number of tiles high
        pathTiles = {},    -- Will store path tile positions
        spawnPoints = {
            left = {},
            right = {}
        },
        paths = {}
    }

    -- Find the object Paths layer
    local pathsLayer
    for _, layer in ipairs(mapData.layers) do
        if layer.type == "objectgroup" and layer.name == "Paths" then
            pathsLayer = layer
            break
        end
    end

    -- Find the TilePath layer
    local tilePathLayer
    for _, layer in ipairs(mapData.layers) do
        if layer.name == "TilePath" then
            tilePathLayer = layer
            break
        end
    end
    
    -- Process path tiles for both sides
    if tilePathLayer then
        for y = 1, server.mapConfig.height do
            server.mapConfig.pathTiles[y] = {}
            
            -- Original (left) side
            for x = 1, 75 do  -- Original map width
                -- Lua arrays start at 1, adjust index calculation
                local index = ((y-1) * 75) + x
                if tilePathLayer.data[index] and tilePathLayer.data[index] ~= 0 then
                    server.mapConfig.pathTiles[y][x] = true
                    
                    -- Mirror the path tile to the right side
                    local mirroredX = (75 * 2) - x + 1  -- Mirror position
                    server.mapConfig.pathTiles[y][mirroredX] = true
                end
            end
        end
    end

    -- Figure out all the paths for enemies 
    if pathsLayer then
        local pathsById = {}
        
        -- First pass: collect polylines/paths
        for _, object in ipairs(pathsLayer.objects) do
            if object.shape == "polyline" then
                local path = {}
                -- Convert polyline points to absolute coordinates
                for _, point in ipairs(object.polyline) do
                    table.insert(path, {
                        x = object.x + point.x,
                        y = object.y + point.y
                    })
                end
                path.name = object.name
                pathsById[object.id] = path
            end
        end
        
        -- Second pass: process spawn points
        for _, object in ipairs(pathsLayer.objects) do
            if object.shape == "point" and object.name:match("^spawn_") then
                local pathRef = object.properties.pathName
                local pathId = pathRef and pathRef.id
                local linkedPath = pathsById[pathId]
                
                if linkedPath then
                    -- Create original spawn point
                    table.insert(server.mapConfig.spawnPoints.left, {
                        x = object.x,
                        y = object.y,
                        path = linkedPath,
                        name = object.name
                    })
                    
                    -- Create mirrored spawn point (flipping across center)
                    local mirroredPath = server:createMirroredPath(linkedPath)
                    table.insert(server.mapConfig.spawnPoints.right, {
                        x = server.mapConfig.width * server.tileSize - object.x,
                        y = object.y,
                        path = mirroredPath,
                        name = object.name .. "_mirrored"
                    })
                end
            end
        end
    end

    -- Initialize enemy manager with paths and spawn points
    server.enemyManager = ServerEnemyManager:new({
        spawnPoints = server.mapConfig.spawnPoints,
        tileSize = server.tileSize
    })

    server.towerManager = ServerTowerManager:new({
        tileSize = server.tileSize
    })

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

function GameServer:sendDebugMessage(client, message)
    return self:sendToClient(client, {
        type = "debug",
        message = message
    })
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

    -- Update gameState
    if enemyUpdates then
        for _, update in ipairs(enemyUpdates) do
            if update.type == "damage" and self.gameState.enemies[update.id] then
                self.gameState.enemies[update.id].health = update.health
                self.enemyManager.enemies[update.id].health = update.health
            elseif update.type == "enemyDied" and self.gameState.enemies[update.id] then
                self.gameState.enemies[update.id] = nil
            end
        end
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
    logger.info("Handling Message:", message)
    
    -- Remove any 'return' prefix if it exists
    if message:sub(1,6) == "return" then
        message = message:sub(7)
    end
    
    local fn, err = loadstring("return " .. message)
    if not fn then
        logger.error("Load failed:", err)
        return
    end
    
    local success, data = pcall(fn)
    if not success then
        logger.error("Failed to execute:", data)
        return
    end
    
    if not data then 
        logger.info("No data returned")
        return 
    end

    logger.info("Parsed data:", type(data))
    for k,v in pairs(data) do
        logger.info(k,v)
    end
    
    if data.type == "placeTower" then
        logger.info("Received placeTower")
        -- Add the client's side to the data for validation
        data.side = self.clients[client].side
        logger.info("Creating Tower for side: ",self.clients[client].side)
        -- Validate tower placement
        if self:isValidTowerPlacement(data) then
            local towerId = self:getNextId()
            local newTowerData = {
                towerType = data.towerType,
                x = data.x,
                y = data.y,
                side = self.clients[client].side,
                towerId = towerId
            }
            local newTower = self.towerManager:createTower(newTowerData)
            logger.info("Created Tower for side: ", newTower.side)
            
            if newTower then
                -- Store in server game state
                self.gameState.towers[towerId] = newTower
                
                -- Broadcast to all clients
                self:broadcast({
                    type = "towerPlaced",
                    tower = {
                        id = newTower.id,
                        type = data.towerType,
                        x = data.x,
                        y = data.y,
                        side = self.clients[client].side
                    }
                })
            end
        else
            -- Optionally notify client of invalid placement
            self:sendToClient(client, {
                type = "placementFailed",
                reason = "Invalid tower placement"
            })
        end
    elseif data.type == "spawnEnemy" then
        logger.info('Got Spawn Enemy in Server')
        local side = data.targetSide
        logger.info('Got spawn for side: ', side)
        -- Get next available ID
        local enemyId = self:getNextId()
        
        -- Create enemy in manager
        local enemy = self.enemyManager:spawnEnemy({
            id = enemyId,
            enemyType = data.enemyType,
            spawnPointIndex = data.spawnPointIndex,
            side = side
        })
        
        if enemy then
            
            -- Store in server game state
            self.gameState.enemies[enemyId] = enemy
            
            -- Broadcast to all clients
            self:broadcast({
                type = "enemySpawned",
                enemy = {
                    id = enemy.id,
                    type = data.enemyType,
                    x = enemy.x,
                    y = enemy.y,
                    targetSide = side,
                    side = side, 
                    health = enemy.health,
                    maxHealth = enemy.maxHealth
                }
            })

            logger.info(string.format("Enemy spawned: id=%d, type=%s, side=%s, pos=(%.1f, %.1f)", 
                enemy.id, data.enemyType, side, enemy.x, enemy.y))
        else
            logger.error("Failed to create enemy of type: " .. data.enemyType)
        end
    end
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
    local tileX = math.floor(data.x / self.tileSize) + 1
    local tileY = math.floor(data.y / self.tileSize) + 1
    
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
    for _, tower in pairs(self.gameState.towers) do
        local dx = tower.x - data.x
        local dy = tower.y - data.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.tileSize * 2 then
            return false
        end
    end
    
    -- Check if player is placing on their side
    local isLeftSide = data.x < (self.mapConfig.width * self.tileSize / 2)
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
        

        -- Debug print the game state before sending
        logger.info("Sending initialization with game state:")
        logger.info("Number of towers:", #self.gameState.towers)
        for id, tower in pairs(self.gameState.towers) do
            logger.info(string.format("Tower %d: type=%s, side=%s, x=%d, y=%d",
                id, tower.type, tower.side, tower.x, tower.y))
        end

        -- Send initialization data to the new client
        self:sendToClient(client, {
            type = "initialization",
            side = side,
            gameState = self.gameState
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

function GameServer:createMirroredPath(originalPath)
    if not originalPath then return nil end
    
    local mirroredPath = {}
    local centerX = self.mapConfig.width * self.tileSize / 2
    
    for _, point in ipairs(originalPath) do
        -- Mirror across the center line
        table.insert(mirroredPath, {
            x = (2 * centerX) - point.x,
            y = point.y
        })
    end
    
    return mirroredPath
end

-- Start the server
local server = GameServer:new()
server:start()

-- Main loop
while true do
    server:update()
    socket.sleep(1/60)  -- 60 FPS update rate
end