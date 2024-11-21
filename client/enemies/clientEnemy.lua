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
    LOGGER.info("Loading directional sprites...")
    self.sprites = {}
    self.frames = {}
    
    for direction, path in pairs(spritePaths) do
        LOGGER.info("Loading sprite for direction:", direction, "path:", path)
        local success, result = pcall(function()
            return love.graphics.newImage(path)
        end)
        
        if success then
            self.sprites[direction] = result
            self.frames[direction] = {}
            LOGGER.info("Successfully loaded sprite for", direction)
        else
            LOGGER.info("Failed to load sprite for", direction, "Error:", result)
        end
    end
    
    -- Set default sprite and verify it loaded
    self.currentSprite = self.sprites["down"]
    LOGGER.info("Current sprite set to:", self.currentSprite and "loaded" or "nil")
end


function Enemy:setupAnimation(numFrames, direction)
    LOGGER.info("Setting up animation for direction:", direction, "frames:", numFrames)
    if not self.sprites[direction] then 
        LOGGER.info("No sprite found for direction:", direction)
        return 
    end
    
    -- Create frames for specific direction
    self.frames[direction] = {}
    local frameWidth = self.spriteWidth
    local frameHeight = self.spriteHeight
    
    local spriteWidth, spriteHeight = self.sprites[direction]:getDimensions()
    LOGGER.info("Sprite dimensions:", spriteWidth, spriteHeight)
    LOGGER.info("Frame dimensions:", frameWidth, frameHeight)
    
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
    LOGGER.info("Created", #self.frames[direction], "frames for", direction)
end

function Enemy:updateFacing(dx, dy)
    -- Determine facing direction based on movement
    if math.abs(dx) > math.abs(dy) then
        self.facing = "side"
        self.flipX = dx > 0 and 1 or -1  -- Flip based on horizontal direction
    else
        if dy > 0 then
            self.facing = "down"
        else
            self.facing = "up"
        end
        self.flipX = 1  -- Reset flip for up/down
    end
    
    -- Update current sprite based on facing direction
    self.currentSprite = self.sprites[self.facing]
end

function Enemy:update(dt)
    -- Update facing direction based on movement if we have target coordinates
    if self.targetX and self.targetY then
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        self:updateFacing(dx, dy)
    end
    
    -- Animation update
    self.animTimer = self.animTimer + dt
    if self.animTimer >= self.frameDelay then
        self.animTimer = self.animTimer - self.frameDelay
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #(self.frames[self.facing] or {}) then
            self.currentFrame = 1
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
    if self.currentSprite and self.frames[self.facing] and #self.frames[self.facing] > 0 then
        LOGGER.info("Drawing enemy at:", self.x, self.y)
        LOGGER.info("Current facing:", self.facing)
        LOGGER.info("Current frame:", self.currentFrame)
        LOGGER.info("Flip value:", self.flipX)
        
        -- Apply damage flash effect
        if self.isFlashing then
            love.graphics.setColor(1, 0.3, 0.3, 1)
        else
            love.graphics.setColor(unpack(self.color))
        end
        
        -- Draw sprite with debug rectangle to show bounds
        love.graphics.draw(
            self.currentSprite,
            self.frames[self.facing][self.currentFrame],
            self.x,
            self.y,
            0,
            self.scale * self.flipX,
            self.scale,
            self.spriteWidth / 2,
            self.spriteHeight / 2
        )
        
        -- Draw debug rectangle around sprite bounds
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle(
            "line",
            self.x - (self.spriteWidth * self.scale) / 2,
            self.y - (self.spriteHeight * self.scale) / 2,
            self.spriteWidth * self.scale,
            self.spriteHeight * self.scale
        )
        
        love.graphics.setColor(1, 1, 1, 1)
    else
        LOGGER.info("Cannot draw enemy:")
        LOGGER.info("currentSprite:", self.currentSprite and "exists" or "nil")
        LOGGER.info("frames table:", self.frames[self.facing] and "exists" or "nil")
        if self.frames[self.facing] then
            LOGGER.info("number of frames:", #self.frames[self.facing])
        end
    end
end

return Enemy