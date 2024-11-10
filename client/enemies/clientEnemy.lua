local Enemy = {
    -- Default properties
    health = 100,
    maxHealth = 100,
    speed = 50,

    -- Movement properties
    x = 0,
    y = 0,
    direction = 0,
    
    -- Visual properties
    sprite = nil,
    color = {1, 1, 1, 1},
    tileSize = 32,
    scale = 2,  -- Adjust size as needed
    
    -- Animation properties
    currentFrame = 1,
    animTimer = 0,
    frameDelay = 0.2,
    frames = {},

    -- Collission related
    radius = 16,  -- Half of the 32px sprite size
    dead = false  -- Track if enemy is destroyed
}

function Enemy:new(x, y, properties)
    local enemy = properties or {}
    setmetatable(enemy, self)
    self.__index = self
    
    enemy.x = x or 0
    enemy.y = y or 0
    enemy.health = enemy.maxHealth
    
    -- Copy the sprite and frames from the prototype
    if self.sprite then
        enemy.sprite = self.sprite
        enemy.frames = self.frames
    end
    
    return enemy
end

function Enemy:setupAnimation(numFrames)
    self.frames = {}
    for i = 0, numFrames - 1 do
        local quad = love.graphics.newQuad(
            i * 32,     -- X position in sprite sheet
            0,          -- Y position in sprite sheet
            32,         -- Frame width
            32,         -- Frame height
            self.sprite:getDimensions()
        )
        table.insert(self.frames, quad)
    end
end

function Enemy:update(dt)
    -- Existing animation update code
    self.animTimer = self.animTimer + dt
    if self.animTimer >= self.frameDelay then
        self.animTimer = self.animTimer - self.frameDelay
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.frames then
            self.currentFrame = 1
        end
    end
    
    -- Add damage flash update
    if self.damageFlashTimer then
        self.damageFlashTimer = self.damageFlashTimer - dt
        if self.damageFlashTimer <= 0 then
            self.damageFlashTimer = nil
            self.isFlashing = false
        end
    end
end

function Enemy:draw()
    if self.sprite and #self.frames > 0 then
        -- Apply damage flash effect
        if self.isFlashing then
            love.graphics.setColor(1, 0.3, 0.3, 1)  -- Red tint
        else
            love.graphics.setColor(unpack(self.color))
        end

        -- Existing draw code
        love.graphics.draw(
            self.sprite,
            self.frames[self.currentFrame],
            self.x,
            self.y,
            self.direction,
            self.scale,
            self.scale,
            16,
            16
        )
        
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Enemy:takeDamage()
    -- Flash effect
    self.damageFlashTimer = 0.15  -- Duration of flash
    self.isFlashing = true
    
    -- Optional: Add particle effect
    -- self:createDamageParticles()
end

return Enemy