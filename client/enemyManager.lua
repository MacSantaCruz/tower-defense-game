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
    local enemiestoRemove = {}
    
    for id, enemy in pairs(self.enemies) do
        -- Check if enemy exists and handle death state
        if enemy then
            if enemy.deathAnimationComplete then
                -- Mark for removal instead of removing directly
                table.insert(enemiestoRemove, id)
            else
                -- Only process movement if enemy is not dying
                if enemy.targetX and not enemy.isDying then
                    -- Only calculate movement if we haven't cached it or position changed
                    local cacheKey = enemy.id .. "_" .. enemy.targetX .. "_" .. enemy.targetY
                    local moveData = self.moveCache[cacheKey]
                    
                    if not moveData then
                        -- Calculate once and cache
                        local dx = enemy.targetX - enemy.x
                        local dy = enemy.targetY - enemy.y
                        local distSq = dx * dx + dy * dy
                        
                        if distSq > 0.01 then
                            moveData = {
                                dx = dx,
                                dy = dy,
                                distSq = distSq,
                                velocityX = dx / self.serverUpdateRate,
                                velocityY = dy / self.serverUpdateRate
                            }
                            self.moveCache[cacheKey] = moveData
                            
                            if enemy.lastCacheKey and enemy.lastCacheKey ~= cacheKey then
                                self.moveCache[enemy.lastCacheKey] = nil
                            end
                            enemy.lastCacheKey = cacheKey
                        end
                    end
                    
                    if moveData then
                        local progress = dt / self.interpolationBuffer
                        progress = math.min(progress, 1.0)
                        
                        enemy.x = enemy.x + moveData.velocityX * dt * progress
                        enemy.y = enemy.y + moveData.velocityY * dt * progress
                    end
                end
                
                -- Update facing based on server-provided direction if not dying
                if enemy.direction and not enemy.isDying then
                    enemy:updateFacing(enemy.direction)
                end
                
                -- Always update animation
                if enemy.update then
                    enemy:update(dt)
                end
            end
        end
    end
    
    -- Remove dead enemies after the loop
    for _, id in ipairs(enemiestoRemove) do
        if self.enemies[id] and self.enemies[id].lastCacheKey then
            self.moveCache[self.enemies[id].lastCacheKey] = nil
        end
        self.enemies[id] = nil
    end
end


function ClientEnemyManager:updateEnemy(id, data)
    local enemy = self.enemies[id]
    LOGGER.info("Updating enemy:", id, "Update type:", data.type)
    if enemy then
        if data.type == 'enemyDied' then
            LOGGER.info("Enemy died, starting death animation")
            enemy:startDeathAnimation()
            return
        end
        
        if not enemy.isDying then -- Only update if not dying
            if data.health and data.health ~= enemy.health then
                enemy.health = data.health
                self:onEnemyDamaged(enemy)
            end
            
            if data.isAttacking ~= nil then
                enemy.isAttacking = data.isAttacking
                enemy.targetSide = data.targetSide
            end
            
            if not enemy.isAttacking and data.x and data.y then
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
end

function ClientEnemyManager:onEnemyDamaged(enemy)
    -- Add visual feedback when enemy takes damage
    -- For example, flash the enemy red briefly
    enemy.damageFlashTimer = 0.1  -- Duration of flash effect
    enemy.isFlashing = true
end

function ClientEnemyManager:spawnEnemy(enemyData)
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

        -- Draw attack indicator if attacking
        if enemy.isAttacking then
            -- Draw attack waves/rings that pulse
            local attackScale = math.sin(1.5 * math.pi * 4) * 0.5 + 0.5
            love.graphics.setColor(1, 0, 0, attackScale * 0.5)
            
            -- Draw concentric circles
            for i = 1, 3 do
                local radius = (20 + i * 10) * attackScale
                love.graphics.circle("line", enemy.x, enemy.y, radius)
            end
            
            -- Draw small lightning bolts or attack symbols
            local boltLength = 15
            local angles = {0, math.pi/2, math.pi, 3*math.pi/2}
            love.graphics.setColor(1, 0, 0, attackScale)
            for _, angle in ipairs(angles) do
                local x1 = enemy.x + math.cos(angle) * boltLength
                local y1 = enemy.y + math.sin(angle) * boltLength
                local x2 = enemy.x + math.cos(angle) * (boltLength * 1.5)
                local y2 = enemy.y + math.sin(angle) * (boltLength * 1.5)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
        
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