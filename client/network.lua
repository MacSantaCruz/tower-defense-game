-- network.lua (client version)
local socket = require "socket"
local Serialization = require "serialization"
local logger = require "logger"

local Network = {
    connected = false,
    socket = nil,
    gameState = {
        towers = {},
        enemies = {},
    },
    playerSide = nil
}

function Network:init()
    return true
end

function Network:connect(host, port)
    local client, err = socket.connect(host, port)
    if not client then
        LOGGER.error("Failed to connect:", err)
        return false
    end
    
    client:settimeout(0)
    self.socket = client
    self.connected = true
    LOGGER.info("Connected to server")
    return true
end

function Network:update(dt)
    if not self.connected then return end
    
    -- Receive updates from server
    local data, err = self.socket:receive()
    if data then
        self:handleServerMessage(data)
    elseif err == "closed" then
        self.connected = false
        LOGGER.info("Disconnected from server")
    end
end

function Network:handleServerMessage(message)
    local success, data = pcall(function()
        return Serialization.deserialize(message)
    end)

    if not success or not data then return end

    if data.type == "initialization" then
        LOGGER.info("Received initialization data:")
        LOGGER.info("Assigned side:", data.side)
        LOGGER.info("Game state received:", data.gameState ~= nil)
        
        self.playerSide = data.side
        self.gameState = data.gameState
        _G.LOGGER = logger.getLogger(Network.playerSide)
        -- Create any existing towers from gameState
        if playerManager then
            LOGGER.info("PlayerManager exists, creating towers")
            for towerId, tower in pairs(self.gameState.towers or {}) do
                LOGGER.info("Processing tower", towerId)
                local player = playerManager.players[tower.side]
                if player then
                    LOGGER.info("Found player for side", tower.side, "creating tower")
                    local created = player.towerManager:createTower(tower)
                    LOGGER.info("Tower creation Tower:", created.id)
                else
                    LOGGER.info("No player found for side:", tower.side)
                end
            end
            if playerManager and data.gameState.enemies then
                for enemyId, enemyData in pairs(data.gameState.enemies) do
                    local player = playerManager.players[enemyData.targetSide]
                    if player then
                        player.enemyManager:spawnEnemy(enemyData)
                    end
                end
            end
        else
            LOGGER.error("PlayerManager not available during initialization")
        end
    elseif data.type == "towerPlaced" then
        LOGGER.info("Received tower placement:", data.tower.id, data.tower.side, data.tower.x, data.tower.y)
        self.gameState.towers[data.tower.id] = data.tower
        
        if playerManager then
            local player = playerManager.players[data.tower.side]
            if player then
                LOGGER.info("Creating tower for player:", data.tower.side)
                player.towerManager:createTower(data.tower)
            else
                LOGGER.error("No player found for side:", data.tower.side)
            end
        end
    elseif data.type == "enemySpawned" then
        LOGGER.info("Enemy spawned:", data.enemy.id, data.enemy.type)
        -- Store in network gameState
        
        -- Create in appropriate player's enemyManager
        if playerManager then
            LOGGER.info("Checking player for side: ", data.enemy.targetSide)
            local player = playerManager.players[data.enemy.targetSide]
            if player then
                LOGGER.info('Spawning enemy for: ', data.enemy.targetSide)
                local enemy = player.enemyManager:spawnEnemy(data.enemy)
                self.gameState.enemies[data.enemy.id] = enemy
            else
                LOGGER.error('Player doesnt exist for enemy to spawn')
            end
        end
    elseif data.type == "enemyDied" then
        local deadEnemy = self.gameState.enemies[data.enemyId]
        if deadEnemy then
            local player = playerManager.players[deadEnemy.targetSide]
            if player then
                player.enemyManager:removeEnemy(data.enemyId)
            end
            self.gameState.enemies[data.enemyId] = nil
        end
    elseif data.type == "gameUpdates" then
        if data.towerUpdates then
            for _, update in ipairs(data.towerUpdates) do
                if update.type == "attack" then
                    LOGGER.info("[Network] Processing attack - Tower:", update.id, "Target:", update.targetId)
                    local tower = self.gameState.towers[update.id]
                    if tower then
                        local player = playerManager.players[tower.side]
                        if player then
                            player.towerManager:handleAttack(update.id, update.targetId, update.damage)
                        end
                    end
                elseif update.type == "damage" then
                    -- Handle enemy damage/update
                    LOGGER.info("[Network] Recieved Damage for Enemy:", update.id)
                    local enemy = self.gameState.enemies[update.id]
                    if enemy then
                        -- Update network state
                        enemy.health = update.health
                        
                        -- Update visual state
                        local player = playerManager.players[enemy.targetSide]
                        if player then
                            player.enemyManager:updateEnemy(update.id, {
                                health = update.health,
                                x = update.x,
                                y = update.y
                            })
                            
                            -- If enemy died
                            if update.health <= 0 then
                                player.enemyManager:removeEnemy(update.id)
                                self.gameState.enemies[update.id] = nil
                            end
                        end
                    end
                end
            end
        end

        if data.enemyUpdates then
            for _, update in ipairs(data.enemyUpdates) do
                local enemy = self.gameState.enemies[update.id]
                if enemy then
                    if update.type == "enemyDied" then
                        LOGGER.info("[Network] Received death update for Enemy:", update.id)
                        local deadEnemy = self.gameState.enemies[update.id]
                        if deadEnemy then
                            -- Remove from network state
                            LOGGER.info("[Network] Removing from gameState Enemy: ", update.id)
                            self.gameState.enemies[update.id] = nil
                            
                            -- Remove from player manager
                            local player = playerManager.players[deadEnemy.side]
                            if player then
                                LOGGER.info("[Network] Removing from Enemy: ", update.id, " From player: ", player.side)
                                player.enemyManager:removeEnemy(update.id)
                            end
                        end
                    else
                        -- LOGGER.info("[Network] Recieved movement update for enemy: " update.enemyId)
                        -- Handle regular enemy position updates
                        local enemy = self.gameState.enemies[update.id]
                        if enemy and update then
                            -- Update network state
                            enemy.x = update.x
                            enemy.y = update.y
                            enemy.direction = update.direction
                            enemy.health = update.health
                            
                            -- Update visual state
                            local player = playerManager.players[enemy.targetSide]
                            if player then
                                player.enemyManager:updateEnemyPosition(
                                    update.id,
                                    update.x,
                                    update.y,
                                    update.direction,
                                    update.health,
                                    update.targetx,
                                    update.targety
                                )
                            end
                        end
                    end
                end
            end
        end
    end
end

function Network:sendTowerPlacement(x, y, towerType)
    if not self.connected then return end
    
    local message = {
        type = "placeTower",
        x = x,
        y = y,
        towerType = towerType
    }
    LOGGER.info("Sending Tower Placement to Server")
    self:sendToServer(message)
end

function Network:sendEnemySpawn(spawnIndex, enemyType, targetSide)
    if not self.connected then return end
    
    local message = {
        type = "spawnEnemy",
        spawnPointIndex = spawnIndex,
        enemyType = enemyType,
        targetSide = targetSide
    }
    
    LOGGER.info(string.format(
        "Sending spawn request: pointIndex=%d, type=%s, target=%s",
        spawnIndex, enemyType, targetSide
    ))
    
    self:sendToServer(message)
end

function Network:sendToServer(message)
    if not self.connected then return end
    
    local serialized = "return " .. Serialization.serialize(message)
    self.socket:send(serialized .. "\n")
end

return Network