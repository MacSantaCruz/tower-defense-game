local Enemy = {
    -- Existing properties
    health = 100,
    maxHealth = 100,
    speed = 50,
    x = 0,
    y = 0,
    direction = 0,
    
    -- Modified visual properties
    sprites = {}, -- Will hold up, down, and side sprites
    currentSprite = nil,
    color = {1, 1, 1, 1},
    tileSize = 32,
    spriteWidth = 32,
    spriteHeight = 32,
    scale = 2,
    
    -- Animation properties
    currentFrame = 1,
    animTimer = 0,
    frameDelay = 0.2,
    deathFrameDelay = .15,
    frames = {}, -- Table for up, down, and side frames
    
    -- Direction properties
    facing = "down", -- Current facing direction
    flipX = 1, -- 1 for normal, -1 for flipped horizontally
    
    -- Collision related
    radius = 16,
    dead = false
}

function Enemy:new(x, y, properties)
    local enemy = properties or {}
    setmetatable(enemy, self)
    self.__index = self
    
    enemy.x = x or 0
    enemy.y = y or 0
    enemy.health = enemy.maxHealth
    enemy.frames = {} -- Initialize frames table for each direction
    
    -- Copy sprites if they exist in prototype
    if self.sprites then
        enemy.sprites = self.sprites
        enemy.currentSprite = enemy.sprites["down"] -- Default direction
    end
    
    -- Set collision radius based on sprite size if not explicitly defined
    if not enemy.radius then
        enemy.radius = (enemy.spriteWidth * enemy.scale) / 2
    end
    
    return enemy
end

function Enemy:loadDirectionalSprites(spritePaths)
    self.sprites = {}
    self.frames = {}
    
    -- Load movement sprites
    for direction, path in pairs(spritePaths) do
        local success, result = pcall(function()
            return love.graphics.newImage(path)
        end)
        
        if success then
            self.sprites[direction] = result
            self.frames[direction] = {}
        else
            LOGGER.info("Failed to load sprite for", direction, "Error:", result)
        end
    end
    
    -- Load death sprites if provided
    if spritePaths.deathUp then
        self.sprites.deathUp = love.graphics.newImage(spritePaths.deathUp)
        self.frames.deathUp = {}
    end
    if spritePaths.deathDown then
        self.sprites.deathDown = love.graphics.newImage(spritePaths.deathDown)
        self.frames.deathDown = {}
    end
    if spritePaths.deathSide then
        self.sprites.deathSide = love.graphics.newImage(spritePaths.deathSide)
        self.frames.deathSide = {}
    end
    
    -- Set default sprite and verify it loaded
    self.currentSprite = self.sprites["down"]
end


function Enemy:setupAnimation(numFrames, direction)
    if not self.sprites[direction] then 
        LOGGER.info("No sprite found for direction:", direction)
        return 
    end
    
    -- Create frames for specific direction
    self.frames[direction] = {}
    local frameWidth = self.spriteWidth
    local frameHeight = self.spriteHeight
    
    local spriteWidth, spriteHeight = self.sprites[direction]:getDimensions()
    
    for i = 0, numFrames - 1 do
        local quad = love.graphics.newQuad(
            i * frameWidth,
            0,
            frameWidth,
            frameHeight,
            spriteWidth,
            spriteHeight
        )
        table.insert(self.frames[direction], quad)
    end
end


function Enemy:startDeathAnimation()
    
    self.isDying = true
    self.currentFrame = 1
    self.animTimer = 0
    

    
    -- Choose death animation based on current facing direction
    if self.facing == "up" and self.sprites.deathUp then
        self.currentSprite = self.sprites.deathUp
        self.deathDirection = "deathUp"
    elseif self.facing == "down" and self.sprites.deathDown then
        self.currentSprite = self.sprites.deathDown
        self.deathDirection = "deathDown"
    else -- Default to side death animation
        self.currentSprite = self.sprites.deathSide
        self.deathDirection = "deathSide"
    end
    
end

function Enemy:updateFacing(direction)
    -- Convert radian direction to facing state
    -- normalize direction to range -PI to PI
    local normalizedDir = direction
    while normalizedDir > math.pi do
        normalizedDir = normalizedDir - 2 * math.pi
    end
    while normalizedDir < -math.pi do
        normalizedDir = normalizedDir + 2 * math.pi
    end
    
    -- Right: -0.785 to 0.785 (45° either side of 0)
    -- Left: 2.356 to -2.356 (45° either side of PI)
    -- Down: 0.785 to 2.356 (45° either side of PI/2)
    -- Up: -2.356 to -0.785 (45° either side of -PI/2)
    
    if normalizedDir >= -0.785 and normalizedDir <= 0.785 then
        self.facing = "side"
        self.flipX = -1  -- facing right (flipped because sprite faces left by default)
    elseif normalizedDir >= 2.356 or normalizedDir <= -2.356 then
        self.facing = "side"
        self.flipX = 1   -- facing left (unflipped because sprite faces left by default)
    elseif normalizedDir > 0.785 and normalizedDir < 2.356 then
        self.facing = "down"
        self.flipX = 1
    else
        self.facing = "up"
        self.flipX = 1
    end
    
    -- Update current sprite based on facing direction
    self.currentSprite = self.sprites[self.facing]
end


function Enemy:update(dt)
    if self.isDying then
        
        -- Update death animation
        self.animTimer = self.animTimer + dt
        if self.animTimer >= self.deathFrameDelay then
            self.animTimer = self.animTimer - self.deathFrameDelay
            self.currentFrame = self.currentFrame + 1
            
            -- Check if death animation is complete
            if self.frames[self.deathDirection] and self.currentFrame > #self.frames[self.deathDirection] then
                self.deathAnimationComplete = true
                self.currentFrame = #self.frames[self.deathDirection]
            end
        end
    else
        -- Normal animation update
        self.animTimer = self.animTimer + dt
        if self.animTimer >= self.frameDelay then
            self.animTimer = self.animTimer - self.frameDelay
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > #(self.frames[self.facing] or {}) then
                self.currentFrame = 1
            end
        end
    end
    
    -- Damage flash update
    if self.damageFlashTimer then
        self.damageFlashTimer = self.damageFlashTimer - dt
        if self.damageFlashTimer <= 0 then
            self.damageFlashTimer = nil
            self.isFlashing = false
        end
    end
end

function Enemy:draw()
    if self.deathAnimationComplete then
        LOGGER.info("Not drawing completed death animation")
        return
    end

    if self.currentSprite then
        -- Determine which frame array to use
        local frames = self.isDying and self.frames[self.deathDirection] or self.frames[self.facing]
        
        if frames and #frames > 0 then
            if self.isDying then
                LOGGER.info("Drawing death animation frame:", self.currentFrame, "of", #frames)
            end
            
            -- Apply damage flash effect
            if self.isFlashing then
                love.graphics.setColor(1, 0.3, 0.3, 1)
            else
                love.graphics.setColor(unpack(self.color))
            end
            
            love.graphics.draw(
                self.currentSprite,
                frames[self.currentFrame],
                self.x,
                self.y,
                0,
                self.scale * self.flipX,
                self.scale,
                self.spriteWidth / 2,
                self.spriteHeight / 2
            )
            
            love.graphics.setColor(1, 1, 1, 1)
        else
            LOGGER.error("No frames available for", self.isDying and "death animation" or "normal animation")
            LOGGER.error("Current direction:", self.isDying and self.deathDirection or self.facing)
        end
    else
        LOGGER.error("No sprite available for drawing")
    end
end

return Enemy