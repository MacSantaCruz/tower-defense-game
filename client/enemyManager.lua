local EnemyFactory = require "enemyFactory"

local ClientEnemyManager = {
    enemies = {},
    side = nil,
    serverUpdateRate = 0.05,
    interpolationBuffer = .1
}

function ClientEnemyManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.side = config.side
    manager.enemies = {}
    manager.moveCache = {}
    manager.lastUpdateTime = love.timer.getTime()  -- Initialize time right away
    return manager
end

function ClientEnemyManager:update(dt)
    local currentTime = love.timer.getTime()
    
    for _, enemy in pairs(self.enemies) do
        if enemy.targetX then
            -- Only calculate movement if we haven't cached it or position changed
            local cacheKey = enemy.id .. "_" .. enemy.targetX .. "_" .. enemy.targetY
            local moveData = self.moveCache[cacheKey]
            
            if not moveData then
                -- Calculate once and cache
                local dx = enemy.targetX - enemy.x
                local dy = enemy.targetY - enemy.y
                local distSq = dx * dx + dy * dy  -- Avoid square root when possible
                
                -- Only create new movement data if actually moving
                if distSq > 0.01 then  -- Small threshold for movement
                    moveData = {
                        dx = dx,
                        dy = dy,
                        distSq = distSq,
                        velocityX = dx / self.serverUpdateRate,
                        velocityY = dy / self.serverUpdateRate,
                        direction = math.atan2(dy, dx)
                    }
                    self.moveCache[cacheKey] = moveData
                    
                    -- Cleanup old cache entries
                    if enemy.lastCacheKey and enemy.lastCacheKey ~= cacheKey then
                        self.moveCache[enemy.lastCacheKey] = nil
                    end
                    enemy.lastCacheKey = cacheKey
                end
            end
            
            if moveData then
                -- Simple linear interpolation instead of complex prediction
                local progress = dt / self.interpolationBuffer
                progress = math.min(progress, 1.0)  -- Clamp to avoid overshooting
                
                enemy.x = enemy.x + moveData.velocityX * dt * progress
                enemy.y = enemy.y + moveData.velocityY * dt * progress
                enemy.direction = moveData.direction
            end
        end
        
        -- Minimal enemy update
        if enemy.update then
            enemy:update(dt)
        end
    end
end


function ClientEnemyManager:updateEnemy(id, data)
    local enemy = self.enemies[id]
    if enemy then
        if data.health and data.health ~= enemy.health then
            enemy.health = data.health
            self:onEnemyDamaged(enemy)
        end
        
        if data.x and data.y then
            -- Clear movement cache when receiving new position
            if enemy.lastCacheKey then
                self.moveCache[enemy.lastCacheKey] = nil
            end
            
            enemy.targetX = data.x
            enemy.targetY = data.y
        end
        
        if data.direction then
            enemy.direction = data.direction
        end
    end
end

function ClientEnemyManager:removeEnemy(id)
    local enemy = self.enemies[id]
    if enemy and enemy.lastCacheKey then
        self.moveCache[enemy.lastCacheKey] = nil
    end
    self.enemies[id] = nil
end

function ClientEnemyManager:onEnemyDamaged(enemy)
    -- Add visual feedback when enemy takes damage
    -- For example, flash the enemy red briefly
    enemy.damageFlashTimer = 0.1  -- Duration of flash effect
    enemy.isFlashing = true
end

function ClientEnemyManager:spawnEnemy(enemyData)
    -- Remove any existing enemy with same ID to prevent duplicates
    if self.enemies[enemyData.id] then
        self:removeEnemy(enemyData.id)
    end
    -- Create enemy using factory
    local enemy = EnemyFactory:spawnEnemy(
        enemyData.type,
        enemyData.side,
        enemyData.x,
        enemyData.y,
        enemyData.id
    )

    if enemy then
        -- Set additional properties from server data
        enemy.health = enemyData.health
        enemy.maxHealth = enemyData.maxHealth
        enemy.direction = enemyData.direction or 0
        
        self.enemies[enemy.id] = enemy
    end
    
    return enemy
end

function ClientEnemyManager:removeEnemy(id)
    self.enemies[id] = nil
end

function ClientEnemyManager:updateEnemyPosition(id, x, y, direction, health, targetx, targety)
    local enemy = self.enemies[id]
    if enemy then
        -- Calculate velocity from previous target
        if targetx then
            local dx = x - targetx
            local dy = y - targety
            enemy.velocityX = dx / self.serverUpdateRate
            enemy.velocityY = dy / self.serverUpdateRate
        end
        
        -- Update target position
        enemy.targetX = x
        enemy.targetY = y
        enemy.direction = direction
        enemy.health = health
        
        -- Reset update timer
        self.lastUpdateTime = love.timer.getTime()
    end
end

function ClientEnemyManager:draw()
    love.graphics.setColor(1, 1, 1, 1)
    
    for _, enemy in pairs(self.enemies) do
        enemy:draw()
        
        -- Optional: Draw health bar
        local healthPercentage = enemy.health / enemy.maxHealth
        love.graphics.setColor(1 - healthPercentage, healthPercentage, 0, 0.8)
        love.graphics.rectangle("fill", 
            enemy.x - 16, enemy.y - 24,
            32 * healthPercentage, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return ClientEnemyManager