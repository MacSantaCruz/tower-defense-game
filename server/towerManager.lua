local TowerManager = {}
local TowerFactory = require "./towerFactory"
local SpatialGrid = require "utils.spatialGrid"
local socket = require "socket"

function TowerManager:new(config)
    local instance = {
        towers = {},
        config = config or {},
        tileSize = config.tileSize or 32,
        updateInterval = 0.05,
        grid = SpatialGrid.getInstance(),
        lastAttackTimes = {},
        factory = TowerFactory
    }
    setmetatable(instance, { __index = self })
    return instance
end

function TowerManager:createTower(towerData)
     local newTower = TowerFactory:createTower(
                towerData.towerType,
                towerData.x,
                towerData.y,
                towerData.side,
                towerData.towerId
            )
    -- Initialize attack timer for this tower
    self.lastAttackTimes[towerData.towerId] = socket.gettime()
    self.towers[towerData.towerId] = newTower
    self.grid:insert(newTower)
    return newTower
end

function TowerManager:removeTower(towerId)
    local tower = self.towers[towerId]
    if tower then
        -- Remove from spatial grid first
        self.grid:remove(tower)
        -- Then remove from towers table
        self.towers[towerId] = nil
        self.lastAttackTimes[towerId] = nil
    end
end

function TowerManager:getTower(towerId)
    return self.towers[towerId]
end

function TowerManager:update(dt, enemies)
    local updates = {}
    local currentTime = socket.gettime()
    
    for towerId, tower in pairs(self.towers) do
        local lastAttackTime = self.lastAttackTimes[towerId] or currentTime

        if currentTime - lastAttackTime >= tower.fireRate then
            local target = self:findTarget(tower, enemies)
            if target then
                -- Record the attack time BEFORE processing
                self.lastAttackTimes[towerId] = currentTime
                
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

            end
        end
    end
    
    return updates
end



function TowerManager:findTarget(tower)
    -- Get all potential targets within range using spatial grid
    local nearbyEntities = self.grid:getNearbyEntities(tower.x, tower.y, tower.range)
    
    if self.debugMode then
        print(string.format("Tower %d checking %d nearby entities", tower.id, #nearbyEntities))
    end
    
    local bestTarget = nil
    local bestPriority = -1
    local closestDistance = tower.range + 1  -- Initialize beyond range
    
    for _, entity in ipairs(nearbyEntities) do
        -- Check if entity is an enemy (has health property)
        if entity.health and entity.type ~= "base" and self:isValidTarget(tower, entity)  then
            local distance = self:calculateDistance(tower, entity)
            if distance <= tower.range then
                local priority = self:calculateTargetPriority(tower, entity, distance)
                
                -- Update best target if this enemy has higher priority
                -- or same priority but closer
                if priority > bestPriority or 
                   (priority == bestPriority and distance < closestDistance) then
                    bestTarget = entity
                    bestPriority = priority
                    closestDistance = distance
                end
            end
        end
    end
    
    return bestTarget
end


function TowerManager:isValidTarget(tower, enemy)
        
    -- A tower should attack enemies that are on its side
    -- (i.e. enemies targeting this side)
    if tower.side == "left" then
        return enemy.targetSide == "left"
    else
        return enemy.targetSide == "right"
    end
end

function TowerManager:calculateTargetPriority(tower, enemy, distance)
    -- Base priority on enemy health percentage and distance
    local healthPercent = enemy.health / enemy.maxHealth
    local distancePercent = distance / tower.range
    
    -- Priority factors (adjust these based on your game balance)
    local healthWeight = 0.4    -- Prefer targeting low health enemies
    local distanceWeight = 0.6  -- Prefer targeting closer enemies
    
    -- Calculate priority (higher is better)
    local priority = (healthWeight * (1 - healthPercent)) + 
                    (distanceWeight * (1 - distancePercent))
    
    if self.debugMode then
        print(string.format("Enemy %d priority: %.2f (health: %.2f%%, distance: %.2f%%)",
            enemy.id, priority, healthPercent * 100, distancePercent * 100))
    end
    
    return priority
end

function TowerManager:calculateDistance(point1, point2)
    local dx = point1.x - point2.x
    local dy = point1.y - point2.y
    return math.sqrt(dx * dx + dy * dy)
end

function TowerManager:cleanup()
    -- Remove all towers from the spatial grid
    for id, tower in pairs(self.towers) do
        self.grid:remove(tower)
    end
    -- Clear the towers table
    self.towers = {}
end

return TowerManager