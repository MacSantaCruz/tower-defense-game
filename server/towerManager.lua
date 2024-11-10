local TowerManager = {}
local TowerFactory = require "./towerFactory"
local socket = require "socket"

function TowerManager:new(config)
    local instance = {
        towers = {},
        config = config or {},
        tileSize = config.tileSize or 32,
        updateInterval = 0.05  -- 50ms, matching your server update rate
    }
    setmetatable(instance, { __index = self })
    return instance
end

function TowerManager:createTower(towerData)
    print(towerData.towerType)
     local newTower = TowerFactory:createTower(
                towerData.towerType,
                towerData.x,
                towerData.y,
                towerData.side,
                towerData.towerId
            )
    self.towers[towerData.towerId] = newTower
    return newTower
end

function TowerManager:removeTower(towerId)
    self.towers[towerId] = nil
end

function TowerManager:getTower(towerId)
    return self.towers[towerId]
end

function TowerManager:update(dt, enemies)
    local updates = {}
    
    for towerId, tower in pairs(self.towers) do
        tower.lastAttackTime = tower.lastAttackTime or socket.gettime()
        local currentTime = socket.gettime()


        if currentTime - tower.lastAttackTime >= tower.fireRate then
            local target = self:findTarget(tower, enemies)
            if target then
                print(string.format("[Server] Tower %d attacking enemy %d", towerId, target.id))
                
                -- Record the attack time BEFORE processing
                tower.lastAttackTime = currentTime
                
                -- Add attack update
                table.insert(updates, {
                    id = towerId,
                    type = "attack",
                    targetId = target.id,
                    damage = tower.damage
                })
                
                -- Update enemy health
                target.health = target.health - tower.damage
                
                -- Add damage update
                table.insert(updates, {
                    id = target.id,
                    type = "damage",
                    health = target.health,
                    x = target.x,
                    y = target.y
                })

                print(string.format("[Server] Created updates for tower %d: attack and damage to enemy %d", 
                    towerId, target.id))
            end
        end
    end
    
    -- Debug output for updates being sent
    if next(updates) then
        print("[Server] Sending updates:")
        for id, update in pairs(updates) do
            print(string.format("  - %s update for ID %s", update.type, id))
        end
    end
    
    return updates
end


function TowerManager:findTarget(tower, enemies)
    
    local closestEnemy = nil
    local closestDistance = tower.range
    local foundEnemies = 0
    local validTargets = 0

    for _, enemy in pairs(enemies) do
        foundEnemies = foundEnemies + 1
        if self:isValidTarget(tower, enemy) then
            validTargets = validTargets + 1
            local distance = self:calculateDistance(tower, enemy)
            if distance <= tower.range and 
               (not closestEnemy or distance < closestDistance) then
                closestEnemy = enemy
                closestDistance = distance
            end
        end
    end

    return closestEnemy
end


function TowerManager:isValidTarget(tower, enemy)
    print(string.format("[Server] Checking target validity - Tower side: %s, Enemy side: %s, Enemy target: %s",
        tower.side, enemy.side, enemy.targetSide))
        
    -- A tower should attack enemies that are on its side
    -- (i.e. enemies targeting this side)
    if tower.side == "left" then
        return enemy.targetSide == "left"
    else
        return enemy.targetSide == "right"
    end
end

function TowerManager:calculateDistance(point1, point2)
    local dx = point1.x - point2.x
    local dy = point1.y - point2.y
    return math.sqrt(dx * dx + dy * dy)
end

return TowerManager