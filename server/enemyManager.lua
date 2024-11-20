local ServerEnemyFactory = require 'enemyFactory'
local SpatialGrid = require "utils.spatialGrid"

local ServerEnemyManager = {
    enemies = {},
    spawnPoints = {}, -- x, y, path, name
}

function ServerEnemyManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.spawnPoints = config.spawnPoints
    manager.enemies = {}
    manager.tileSize = config.tileSize
    manager.grid = SpatialGrid.getInstance()
    manager.baseManager = config.baseManager
    manager.factory = ServerEnemyFactory
    manager.onEnemyDeath = config.onEnemyDeath

    return manager
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
            -- Find the client who should receive the reward (the one being attacked)
            -- TODO: idk about this having access to the self.server
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
                        
                        -- Send enemy attack animation update
                        table.insert(updates, {
                            id = enemy.id,
                            type = 'enemyAttack',
                            targetSide = targetBase.side,
                            damage = enemy.damage or 10
                        })
                        
                        -- Handle base damage updates
                        local damageUpdates = self.baseManager:takeDamage(targetBase.side, enemy.damage or 10)
                        if damageUpdates then
                            for _, update in ipairs(damageUpdates) do
                                print("in enemy manager adding updates")
                                table.insert(updates, update)
                            end
                        end
                    end
                end
            end
            
            if not enemy.isAttacking then
                local currentPoint = enemy.pathPoints[enemy.currentPathIndex]
                if currentPoint then
                    local dx = currentPoint.x - enemy.x
                    local dy = currentPoint.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance > 5 then
                        local moveX = (dx / distance) * enemy.speed * dt
                        local moveY = (dy / distance) * enemy.speed * dt
                        
                        enemy.x = enemy.x + moveX
                        enemy.y = enemy.y + moveY
                        enemy.direction = math.atan2(dy, dx)
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
                        else
                            table.insert(updates, {
                                id = enemy.id,
                                x = enemy.x,
                                y = enemy.y,
                                direction = enemy.direction,
                                health = enemy.health,
                                targetX = currentPoint.x,
                                targetY = currentPoint.y,
                                type = "movement"
                            })
                        end
                    else
                        if enemy.currentPathIndex < #enemy.pathPoints then
                            enemy.currentPathIndex = enemy.currentPathIndex + 1
                        end
                    end
                end
            end
        end
    end
    
    return updates
end

function ServerEnemyManager:spawnEnemy(data)
    local spawnPoint = self.spawnPoints[data.side][data.spawnPointIndex]
    if not spawnPoint then return nil end
    
    local enemy = ServerEnemyFactory:spawnEnemy(
        data.enemyType,
        data.side,
        spawnPoint.x,
        spawnPoint.y,
        data.id
    )
    print('Spawned enemy using server factory')
    print("Enemy Id: ", enemy.id)
    enemy.pathPoints = spawnPoint.path
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