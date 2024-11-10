local EnemyFactory = require "enemyFactory"

local ClientEnemyManager = {
    enemies = {},
    side = nil,
    serverUpdateRate = 0.05
}

function ClientEnemyManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.side = config.side
    manager.enemies = {}
    manager.lastUpdateTime = love.timer.getTime()  -- Initialize time right away
    return manager
end

function ClientEnemyManager:update(dt)
    local currentTime = love.timer.getTime()
    local timeSinceUpdate = currentTime - self.lastUpdateTime
    
    for _, enemy in pairs(self.enemies) do
        if enemy.targetX then
            -- Calculate velocity if we have a previous position
            if not enemy.velocityX then
                enemy.velocityX = 0
                enemy.velocityY = 0
                enemy.prevX = enemy.x
                enemy.prevY = enemy.y
            end
            
            -- Update velocity based on target position
            local dx = enemy.targetX - enemy.x
            local dy = enemy.targetY - enemy.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Only update velocity if we're moving significantly
            if distance > 0.1 then
                -- Calculate time-adjusted velocity
                enemy.velocityX = dx / self.serverUpdateRate
                enemy.velocityY = dy / self.serverUpdateRate
                
                -- Store previous position for next frame
                enemy.prevX = enemy.x
                enemy.prevY = enemy.y
                
                -- Predict next position using velocity
                local predictedX = enemy.x + enemy.velocityX * dt
                local predictedY = enemy.y + enemy.velocityY * dt
                
                -- Smoothly interpolate towards predicted position
                local lerpFactor = 0.2  -- Adjust this for desired smoothness
                enemy.x = enemy.x + (predictedX - enemy.x) * lerpFactor
                enemy.y = enemy.y + (predictedY - enemy.y) * lerpFactor
                
                -- Update direction based on actual movement
                if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then
                    enemy.direction = math.atan2(dy, dx)
                end
            end
        end
        
        enemy:update(dt)
    end
end

function ClientEnemyManager:updateEnemy(id, data)
    local enemy = self.enemies[id]
    if enemy then
        -- Update health
        if data.health then
            enemy.health = data.health
            
            -- Optionally trigger damage animation/effect
            if enemy.health < enemy.maxHealth then
                self:onEnemyDamaged(enemy)
            end
        end
        
        -- Update position if provided
        if data.x and data.y then
            enemy.targetX = data.x
            enemy.targetY = data.y
        end
        
        -- Update any other properties
        if data.direction then
            enemy.direction = data.direction
        end
    end
end


function ClientEnemyManager:onEnemyDamaged(enemy)
    -- Add visual feedback when enemy takes damage
    -- For example, flash the enemy red briefly
    enemy.damageFlashTimer = 0.1  -- Duration of flash effect
    enemy.isFlashing = true
end

function ClientEnemyManager:spawnEnemy(enemyData)
    print('Spawning Enemy on client')
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