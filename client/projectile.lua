local Projectile = {
    x = 0,
    y = 0,
    speed = 200,
    damage = 10,
    radius = 4,
    dead = false,
    color = {1, 1, 0, 1},  -- Yellow by default
    lifetime = 2,          -- Maximum lifetime in seconds
    timeAlive = 0,        -- Track how long projectile has existed
    hasHit = false       -- Track if we've already registered a hit
}

function Projectile:new(properties)
    local projectile = properties or {}
    setmetatable(projectile, self)
    self.__index = self
    return projectile
end

function Projectile:update(dt)
    -- Update lifetime
    self.timeAlive = self.timeAlive + dt
    if self.timeAlive >= self.lifetime then
        self.dead = true
        return
    end

    -- Check if target is gone or dead
    if not self.target or (self.target.dead and self.target.dead == true) then
        self.dead = true
        return
    end
    
    -- Calculate direction to target's current position
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Only hit if we're very close to the target and haven't registered a hit yet
    if distance < 5 and not self.hasHit then
        -- Mark that we've hit to prevent multiple hits
        self.hasHit = true
        self.dead = true
        
        -- Visual effect on hit (optional)
        if self.onHit then
            self:onHit()
        end
    else
        -- Move towards target at specified speed
        local moveX = (dx / distance) * self.speed * dt
        local moveY = (dy / distance) * self.speed * dt
        self.x = self.x + moveX
        self.y = self.y + moveY
    end
end

function Projectile:draw()
    -- Only draw if not dead
    if not self.dead then
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(unpack(self.color))
        love.graphics.circle("fill", self.x, self.y, self.radius)
        love.graphics.setColor(r, g, b, a)
    end
end

-- Optional: Add hit effect
function Projectile:onHit()
    -- You can add visual effects here like particles
    -- or play a sound effect when the projectile hits
end

return Projectile