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
    return manager
end

function ServerEnemyManager:update(dt)
    local updates = {}
    
    for id, enemy in pairs(self.enemies) do
        if enemy.health <= 0 then
            self.grid:remove(enemy)
            self.enemies[id] = nil
            table.insert(updates,{
                id = enemy.id,
                type = 'enemyDied'
            })
        else
            -- Update enemy position
            local currentPoint = enemy.pathPoints[enemy.currentPathIndex]
            if currentPoint then
                local dx = currentPoint.x - enemy.x
                local dy = currentPoint.y - enemy.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance > 5 then
                    -- Move enemy
                    local moveX = (dx / distance) * enemy.speed * dt
                    local moveY = (dy / distance) * enemy.speed * dt
                    
                    enemy.x = enemy.x + moveX
                    enemy.y = enemy.y + moveY
                    enemy.direction = math.atan2(dy, dx)
                    self.grid:updateEntity(enemy)
                    print("Creating a movement update for: ", enemy.id)
                    -- Add to updates
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
                else
                    -- Move to next point
                    enemy.currentPathIndex = enemy.currentPathIndex + 1
                    if enemy.currentPathIndex > #enemy.pathPoints then
                        -- Enemy reached end
                        -- TODO: May need to clean up array but can't index like this anymore 
                        -- updates[id] = nil
                        self.grid:remove(enemy)
                        self.enemies[id] = nil
                        table.insert(updates,{
                            id = enemy.id,
                            type = 'enemyDied'
                        })
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