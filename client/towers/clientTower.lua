local Projectile = require("projectile")

local ClientTower = {
    sprite = nil,
    color = {1, 1, 1, 1},
    tileSize = 32,
    tilesWide = 3,
    currentFrame = 1,
    animTimer = 0,
    frameDelay = 0.2,
    frames = {},
    
    range = 500,
    fireRate = 1,
    projectileSpeed = 200,
    lastShot = 0
}

function ClientTower:new(x, y)
    local tower = {}
    setmetatable(tower, self)
    self.__index = self
    
    tower.x = x
    tower.y = y
    tower.projectiles = {}
    tower.isFiring = false
    tower.currentFrame = 1
    tower.animTimer = 0
    tower.animationQueue = 0  -- Track number of pending animations
    tower.lastAnimationTime = 0  -- Track when we last started an animation

    if self.sprite then
        tower.sprite = self.sprite
        tower.frames = self.frames
    end
    
    return tower
end

function ClientTower:setupAnimation(numFrames)
    self.frames = {}
    for i = 0, numFrames - 1 do
        local quad = love.graphics.newQuad(
            i * 32,
            0,
            32,
            32,
            self.sprite:getDimensions()
        )
        table.insert(self.frames, quad)
    end
end

function ClientTower:update(dt)
    -- Update projectiles first
    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]
        proj:update(dt)
        if proj.dead then
            table.remove(self.projectiles, i)
        end
    end
    
    -- Update animation
    if self.isFiring then
        self.animTimer = self.animTimer + dt
        if self.animTimer >= self.frameDelay then
            self.animTimer = self.animTimer - self.frameDelay
            self.currentFrame = self.currentFrame + 1
            
            -- Complete one animation cycle
            if self.currentFrame > #self.frames then
                self.currentFrame = 1
                self.isFiring = false
                self.animTimer = 0
            end
        end
    end
end

function ClientTower:draw()
    local r, g, b, a = love.graphics.getColor()
    
    if self.sprite then
        local width = 32
        local height = 32
        local scaleX = (self.tileSize * self.tilesWide) / width
        local scaleY = (self.tileSize * self.tilesWide) / height
        
        love.graphics.setColor(unpack(self.color))
        love.graphics.draw(
            self.sprite,
            self.frames[self.currentFrame],
            self.x, 
            self.y, 
            0,
            scaleX,
            scaleY,
            width/2,
            height/2
        )
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.circle("fill", self.x, self.y, 15)
    end

    -- Draw projectiles
    for _, proj in ipairs(self.projectiles) do
        proj:draw()
    end

    love.graphics.setColor(r, g, b, a)
end

function ClientTower:onServerFire(target)
    local currentTime = love.timer.getTime()
    
    -- Only start a new animation if enough time has passed since the last one
    if currentTime - self.lastAnimationTime >= self.frameDelay * #self.frames then
        self.isFiring = true
        self.currentFrame = 1
        self.animTimer = 0
        self.lastAnimationTime = currentTime
        
        -- Create projectile
        local projectile = Projectile:new({
            x = self.x,
            y = self.y,
            speed = self.projectileSpeed,
            target = target,
            lifetime = 2,
            color = self.color,
            side = self.side
        })
        table.insert(self.projectiles, projectile)
        
        print(string.format("[Tower %d] Started new attack animation", self.id))
    else
        print(string.format("[Tower %d] Skipped animation - too soon since last attack", self.id))
    end
end

-- Keep attack method for local testing/preview
function ClientTower:attack(target)
    self:onServerFire(target)
end

return ClientTower