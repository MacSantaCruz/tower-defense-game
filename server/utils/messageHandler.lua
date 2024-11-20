local logger = require "logger"

local MessageHandler = {}

function MessageHandler:new(server)
    local handler = setmetatable({}, { __index = self })
    handler.server = server
    return handler
end

function MessageHandler:handleMessage(client, message)
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
        self:handlePlaceTower(client, data)
    elseif data.type == "spawnEnemy" then
        self:handleSpawnEnemy(client, data)
    end
end

function MessageHandler:handlePlaceTower(client, data)
    logger.info("Received placeTower")
    -- Add the client's side to the data for validation
    data.side = self.server.clients[client].side
    logger.info("Creating Tower for side: ", self.server.clients[client].side)
    
    local towerCost = self.server.towerManager.factory:getTowerCost(data.towerType)

    -- Check if player has enough gold
    if self.server.clients[client].gold < towerCost then
        self.server:sendToClient(client, {
            type = "placementFailed",
            reason = "Insufficient gold"
        })
        return
    end

    -- Validate tower placement
    if self.server:isValidTowerPlacement(data) then
        self.server:modifyGold(client, -towerCost)
        local towerId = self.server:getNextId()
        local newTowerData = {
            towerType = data.towerType,
            x = data.x,
            y = data.y,
            side = self.server.clients[client].side,
            towerId = towerId
        }
        local newTower = self.server.towerManager:createTower(newTowerData)
        logger.info("Created Tower for side: ", newTower.side)
        
        if newTower then
            -- Broadcast to all clients
            self.server:broadcast({
                type = "towerPlaced",
                tower = {
                    id = newTower.id,
                    type = data.towerType,
                    x = data.x,
                    y = data.y,
                    side = self.server.clients[client].side
                }
            })
        end
    else
        -- Optionally notify client of invalid placement
        self.server:sendToClient(client, {
            type = "placementFailed",
            reason = "Invalid tower placement"
        })
    end
end

function MessageHandler:handleSpawnEnemy(client, data)
    logger.info('Got Spawn Enemy in Server')
    local side = data.targetSide
    logger.info('Got spawn for side: ', side)
    -- Get next available ID
    local enemyId = self.server:getNextId()
    
    -- Create enemy in manager
    local enemy = self.server.enemyManager:spawnEnemy({
        id = enemyId,
        enemyType = data.enemyType,
        spawnPointIndex = data.spawnPointIndex,
        side = side
    })
    
    if enemy then
        -- Broadcast to all clients
        self.server:broadcast({
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

return MessageHandler