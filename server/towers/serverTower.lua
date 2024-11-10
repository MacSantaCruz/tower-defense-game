local ServerTower = {
    -- Core gameplay properties
    range = 500,
    cost = 100,
    fireRate = 1,
    damage = 10,
    projectileSpeed = 200,
    lastShot = 0,
    
    -- No rendering properties here
    tileSize = 32
}

function ServerTower:new(x, y)
    local tower = {}
    setmetatable(tower, self)
    self.__index = self
    
    tower.x = x
    tower.y = y
    tower.targets = {}
    tower.id = nil  -- Will be set by server
    tower.side = nil -- Will be set by server
    
    return tower
end

function ServerTower:findTarget(enemies)
    local closest = nil
    local minDist = self.range
    
    -- Get base x position for tower based on side
    local towerX = self.x
    
    for _, enemy in ipairs(enemies) do
        if not enemy.dead then
            -- Use the adjusted tower position for distance calculation
            local dx = enemy.x - towerX
            local dy = enemy.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < minDist then
                closest = enemy
                minDist = dist
            end
        end
    end
    
    return closest
end

function ServerTower:update(dt, enemies)
    -- Server-side update logic only
    -- No projectile rendering, just hit detection
    self.lastShot = self.lastShot + dt
    if self.lastShot >= self.fireRate then
        local target = self:findTarget(enemies)
        if target then
            -- Instead of creating visual projectiles, just handle the hit
            target:takeDamage(self.damage)
            self.lastShot = 0
            return true  -- Signal that tower fired (for network sync)
        end
    end
    return false
end

function ServerTower:toNetworkObject()
    return {
        id = self.id,
        type = self.type,
        x = self.x,
        y = self.y,
        side = self.side,
        lastShot = self.lastShot
    }
end

return ServerTower