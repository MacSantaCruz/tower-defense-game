local ServerEnemyFactory = require 'enemyFactory'
local SpatialGrid = require "utils.spatialGrid"

local ServerEnemyManager = {
    enemies = {},
}

function ServerEnemyManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.zones = config.zones
    manager.spawnZones = config.spawnZones
    manager.enemies = {}
    manager.tileSize = config.tileSize
    manager.grid = SpatialGrid.getInstance()
    manager.baseManager = config.baseManager
    manager.factory = ServerEnemyFactory
    manager.onEnemyDeath = config.onEnemyDeath
    print("Enemymanager spawnZone: ", manager.spawnZones)
    return manager
end

function ServerEnemyManager:getRandomPointInZone(zone)
    return {
        x = zone.x + math.random() * zone.width,
        y = zone.y + math.random() * zone.height
    }
end

function clampToZone(x, y, zone)
    -- Clamp position to stay within zone boundaries
    local clampedX = math.max(zone.x, math.min(x, zone.x + zone.width))
    local clampedY = math.max(zone.y, math.min(y, zone.y + zone.height))
    return clampedX, clampedY
end

 function getZoneIntersectionPoint(currentZone, nextZone)
    -- Find which edges of the zones intersect
    local intersectX, intersectY
    local isHorizontalTransition = math.abs((currentZone.y + currentZone.height/2) - (nextZone.y + nextZone.height/2)) < 
       math.abs((currentZone.x + currentZone.width/2) - (nextZone.x + nextZone.width/2))
    
    if isHorizontalTransition then
        -- For horizontal paths, vary the Y position
        local baseY = currentZone.y
        local pathHeight = currentZone.height
        -- Random position within the path, leaving a small margin from edges
        local margin = pathHeight * 0.1 -- 10% margin from edges
        intersectY = baseY + margin + math.random() * (pathHeight - margin * 2)
        
        if currentZone.x < nextZone.x then
            -- Current zone is to the left
            intersectX = currentZone.x + currentZone.width
        else
            -- Current zone is to the right
            intersectX = currentZone.x
        end
    else
        -- For vertical paths, vary the X position
        local baseX = currentZone.x
        local pathWidth = currentZone.width
        -- Random position within the path, leaving a small margin from edges
        local margin = pathWidth * 0.1 -- 10% margin from edges
        intersectX = baseX + margin + math.random() * (pathWidth - margin * 2)
        
        if currentZone.y < nextZone.y then
            -- Current zone is above
            intersectY = currentZone.y + currentZone.height
        else
            -- Current zone is below
            intersectY = currentZone.y
        end
    end
    
    return {
        x = intersectX, 
        y = intersectY,
        isHorizontalTransition = isHorizontalTransition -- Save this for smooth transitions
    }
end

local function moveAlongPath(enemy, targetX, targetY, dt, speed)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 1 then
        return 0, 0
    end
    
    -- Calculate desired movement
    local moveX = (dx / distance) * speed * dt
    local moveY = (dy / distance) * speed * dt
    
    -- Calculate next position
    local nextX = enemy.x + moveX
    local nextY = enemy.y + moveY
    
    -- Clamp to current zone
    local clampedX, clampedY = clampToZone(nextX, nextY, enemy.currentZone)
    
    -- If we're near a zone transition and next zone exists, also check if position is valid in next zone
    if enemy.currentZone.nextZone then
        local intersectPoint = getZoneIntersectionPoint(enemy.currentZone, enemy.currentZone.nextZone)
        local distToIntersect = math.sqrt((enemy.x - intersectPoint.x)^2 + (enemy.y - intersectPoint.y)^2)
        
        if distToIntersect < speed * dt * 2 then
            -- Check if position is valid in next zone
            local nextZoneX, nextZoneY = clampToZone(nextX, nextY, enemy.currentZone.nextZone)
            -- If position is valid in next zone, allow it
            if nextZoneX == nextX and nextZoneY == nextY then
                clampedX, clampedY = nextX, nextY
            end
        end
    end
    
    return clampedX - enemy.x, clampedY - enemy.y
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
                if enemy.targetPoint then
                    -- Move towards target point
                    local moveX, moveY = moveAlongPath(
                        enemy, 
                        enemy.targetPoint.x, 
                        enemy.targetPoint.y, 
                        dt, 
                        enemy.speed
                    )
                    
                    -- Update position
                    enemy.x = enemy.x + moveX
                    enemy.y = enemy.y + moveY
                    
                    -- Only update direction if we're actually moving
                    if math.abs(moveX) > 0.01 or math.abs(moveY) > 0.01 then
                        enemy.direction = math.atan2(moveY, moveX)
                    end
                    
                    self.grid:updateEntity(enemy)
                    
                    -- Check if we've reached the target point
                    local distToTarget = math.sqrt(
                        (enemy.x - enemy.targetPoint.x)^2 + 
                        (enemy.y - enemy.targetPoint.y)^2
                    )
                    
                    -- Check for base attacks
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
                        -- Only send movement updates if we're actually moving
                        if math.abs(moveX) > 0.01 or math.abs(moveY) > 0.01 then
                            table.insert(updates, {
                                id = enemy.id,
                                x = enemy.x,
                                y = enemy.y,
                                direction = enemy.direction,
                                health = enemy.health,
                                targetX = enemy.targetPoint.x,
                                targetY = enemy.targetPoint.y,
                                type = "movement"
                            })
                        end
                    end

                    -- Check if we've reached the current target point
                    if distToTarget < 5 then  -- Changed from > to <
                        -- Reached current target point, get next zone
                        if enemy.currentZone.nextZone then
                            enemy.currentZone = enemy.currentZone.nextZone
                            -- If there's another zone after this one, set the intersection point
                            if enemy.currentZone.nextZone then
                                enemy.targetPoint = getZoneIntersectionPoint(
                                    enemy.currentZone,
                                    enemy.currentZone.nextZone
                                )
                            else
                                -- This is the final zone, move to its center
                                enemy.targetPoint = {
                                    x = enemy.currentZone.x + enemy.currentZone.width/2,
                                    y = enemy.currentZone.y + enemy.currentZone.height/2
                                }
                            end
                        else
                            -- Reached the end of the path
                            enemy.targetPoint = nil
                        end
                    end
                end
            else
                -- Attack logic remains the same
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
        end
    end
    
    return updates
end

function ServerEnemyManager:spawnEnemy(data)
    local spawnZone = self.spawnZones[data.side][data.zoneSpawnIndex]
    if not spawnZone then return nil end
    
    -- Random position within the spawn zone's path width
    local margin = spawnZone.height * 0.1
    local spawnPoint = {
        x = spawnZone.x + spawnZone.width/2,
        y = spawnZone.y + margin + math.random() * (spawnZone.height - margin * 2)
    }
    
    local enemy = ServerEnemyFactory:spawnEnemy(
        data.enemyType,
        data.side,
        spawnPoint.x,
        spawnPoint.y,
        data.id
    )
    
    enemy.currentZone = spawnZone
    if spawnZone.nextZone then
        enemy.targetPoint = getZoneIntersectionPoint(spawnZone, spawnZone.nextZone)
    end
    
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