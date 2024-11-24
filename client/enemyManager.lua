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
    manager.lastUpdateTime = love.timer.getTime()
    manager.batchManager = EnemyFactory:getBatchManager()
    if not manager.batchManager then
        LOGGER.error("BatchManager not initialized!")
    end
    return manager
end

function ClientEnemyManager:update(dt)
    local currentTime = love.timer.getTime()
    local enemiestoRemove = {}
    
    for id, enemy in pairs(self.enemies) do
        LOGGER.info('HAVE ENEMY: ', id)
        -- Check if enemy exists and handle death state
        if enemy then
            if enemy.deathAnimationComplete then
                -- Mark for removal instead of removing directly
                table.insert(enemiestoRemove, id)
            else
                -- Only process movement if enemy is not dying
                if enemy.targetX and not enemy.isDying then
                    local currentTime = love.timer.getTime()
                    local progress = math.min((currentTime - (enemy.moveStartTime or 0)) / (enemy.interpolationTime or self.interpolationBuffer), 1.0)
                    
                    enemy.x = enemy.startX + (enemy.targetX - enemy.startX) * progress
                    enemy.y = enemy.startY + (enemy.targetY - enemy.startY) * progress
                    LOGGER.info('Updating with x: ', enemy.x)
                    LOGGER.info('Updating with y: ', enemy.y)
                    enemy:update(dt)
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
                enemy.startX = enemy.x or data.x
                enemy.startY = enemy.y or data.y
                enemy.targetX = data.x
                enemy.targetY = data.y
                enemy.moveStartTime = love.timer.getTime()
                
                -- Store the movement vector from server
                if data.moveX and data.moveY then
                    enemy.moveX = data.moveX
                    enemy.moveY = data.moveY
                else
                    enemy.moveX = nil
                    enemy.moveY = nil
                end
                
                -- Use precise interpolation time based on actual movement
                local dist = math.sqrt((data.x - enemy.startX)^2 + (data.y - enemy.startY)^2)
                enemy.interpolationTime = math.min(dist / (enemy.speed or 50), self.interpolationBuffer)
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
    -- Clear all sprite batches
    self.batchManager:clear()
    
    -- First pass: Add all enemies to sprite batches
    for _, enemy in pairs(self.enemies) do
        if not enemy.deathAnimationComplete then
            local direction = enemy.isDying and enemy.deathDirection or enemy.facing
            local batchKey = enemy.type .. "_" .. direction
            local batch = self.batchManager.batches[batchKey]
            local frame = enemy.frames[direction][enemy.currentFrame]
            
            if batch and frame then
                batch:add(
                    frame,
                    enemy.x,
                    enemy.y,
                    0,
                    enemy.scale * enemy.flipX,
                    enemy.scale,
                    enemy.spriteWidth / 2,
                    enemy.spriteHeight / 2
                )
            end
        end
    end
    
    -- Second pass: Draw all batches
    for _, batch in pairs(self.batchManager.batches) do
        love.graphics.draw(batch)
    end
    
    -- Draw health bars (can't be batched)
    for _, enemy in pairs(self.enemies) do
        if not enemy.deathAnimationComplete then
            local healthPercentage = enemy.health / enemy.maxHealth
            love.graphics.setColor(1 - healthPercentage, healthPercentage, 0, 0.8)
            love.graphics.rectangle("fill", 
                enemy.x - 16, enemy.y - 24,
                32 * healthPercentage, 4)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return ClientEnemyManager