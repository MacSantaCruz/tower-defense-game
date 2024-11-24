local ServerEnemyFactory = require 'enemyFactory'
local SpatialGrid = require "utils.spatialGrid"
local logger = require "logger"
local PathManager = require "utils.pathManager" 

local ServerEnemyManager = {
    enemies = {},
}

function ServerEnemyManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.pathManager = config.pathManager
    manager.enemies = {}
    manager.tileSize = config.tileSize
    manager.grid = SpatialGrid.getInstance()
    manager.baseManager = config.baseManager
    manager.factory = ServerEnemyFactory
    manager.onEnemyDeath = config.onEnemyDeath

    return manager
end


function ServerEnemyManager:calculatePathPosition(enemy, dt)
    local moveX, moveY = self.pathManager:updateEnemyMovement(enemy, dt)
    local newX = enemy.x + moveX
    local newY = enemy.y + moveY
    
    -- Only update position if we actually moved
    if math.abs(moveX) > 0.001 or math.abs(moveY) > 0.001 then
        return newX, newY, moveX, moveY
    end
    
    return enemy.x, enemy.y, 0, 0
end

function ServerEnemyManager:checkBaseInRange(enemy)
    -- Get nearby entities from the spatial grid within attack range
    local nearbyEntities = self.grid:getNearbyEntities(enemy.x, enemy.y, enemy.attackRange)
    
    -- Look for a base of the opposite side
    for _, entity in ipairs(nearbyEntities) do
        if entity.type == "base" and entity.side == enemy.side then
            -- Found an enemy base in range
            return entity
        end
    end
    
    return nil
end

function ServerEnemyManager:update(dt)
    local updates = {}
    
    for id, enemy in pairs(self.enemies) do
        if enemy.health <= 0 then
            if self.onEnemyDeath then
                self.onEnemyDeath(enemy)
            end
            
            self.grid:remove(enemy)
            self.enemies[id] = nil
            table.insert(updates, {
                id = enemy.id,
                type = 'enemyDied',
                targetSide = enemy.targetSide
            })
        else
            if enemy.isAttacking then
                local targetBase = self:checkBaseInRange(enemy)
                if not targetBase then
                    enemy.isAttacking = false
                else
                    enemy.attackTimer = (enemy.attackTimer or 0) - dt
                    if enemy.attackTimer <= 0 then
                        enemy.attackTimer = 1 / enemy.attackRate
                        
                        table.insert(updates, {
                            id = enemy.id,
                            type = 'enemyAttack',
                            targetSide = targetBase.side,
                            damage = enemy.damage or 10
                        })
                        
                        local damageUpdates = self.baseManager:takeDamage(targetBase.side, enemy.damage or 10)
                        if damageUpdates then
                            for _, update in ipairs(damageUpdates) do
                                table.insert(updates, update)
                            end
                        end
                    end
                end
            end
            
            if not enemy.isAttacking then
                local newX, newY, moveX, moveY = self:calculatePathPosition(enemy, dt)
                enemy.x = newX 
                enemy.y = newY

                if math.abs(moveX) > 0.01 or math.abs(moveY) > 0.01 then
                    enemy.direction = math.atan2(moveY, moveX)
                    table.insert(updates, {
                        id = enemy.id,
                        x = enemy.x,
                        y = enemy.y,
                        moveX = moveX,
                        moveY = moveY,
                        targetSide = enemy.targetSide,
                        direction = enemy.direction,
                        health = enemy.health,
                        type = "movement"
                    })
                end
                
                self.grid:updateEntity(enemy)
                
                local targetBase = self:checkBaseInRange(enemy)
                if targetBase then
                    enemy.isAttacking = true
                    enemy.attackTimer = 0
                    table.insert(updates, {
                        id = enemy.id,
                        type = 'enemyStartAttack',
                        targetSide = targetBase.side,
                        x = enemy.x,
                        y = enemy.y
                    })
                end
            end
        end
    end
    
    return updates
end

function ServerEnemyManager:spawnEnemy(data)
    local path = self.pathManager.paths[data.side][data.pathId]
    if not path or #path == 0 then
        logger.error(string.format("No path found for side: %s, pathId: %d", data.side, data.pathId))
        return nil
    end
    
    -- Get the starting point (first point) of the path
    local spawnPoint = path[1]
    if not spawnPoint then
        logger.error("No spawn point found in path")
        return nil
    end
    
    -- Create the enemy at the path's starting point
    local enemy = ServerEnemyFactory:spawnEnemy(
        data.enemyType,
        data.side,
        spawnPoint.x,
        spawnPoint.y,
        data.id
    )
    
    -- Initialize path following properties
    enemy.pathId = data.pathId
    enemy.currentPathIndex = 1
    
    self.enemies[enemy.id] = enemy
    self.grid:insert(enemy)
    
    return enemy
end

-- Add cleanup when the manager is destroyed or reset
function ServerEnemyManager:cleanup()
    -- Remove all enemies from the spatial grid
    for id, enemy in pairs(self.enemies) do
        self.grid:remove(enemy)
    end
    -- Clear the enemies table
    self.enemies = {}
end

return ServerEnemyManager