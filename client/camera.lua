-- camera.lua
local camera = {
    x = 0,
    y = 0,
    speed = 1000,
    edgeThreshold = 50,
    worldWidth = 0,
    worldHeight = 0,
    windowWidth = 0,
    windowHeight = 0
}

function camera:load(worldWidth, worldHeight, windowWidth, windowHeight)
    self.worldWidth = worldWidth
    self.worldHeight = worldHeight
    self.windowWidth = windowWidth
    self.windowHeight = windowHeight
end

function camera:update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    local moveX, moveY = 0, 0
    
    -- Edge scrolling
    if mouseX < self.edgeThreshold then
        moveX = -1
    elseif mouseX > self.windowWidth - self.edgeThreshold then
        moveX = 1
    end
    
    if mouseY < self.edgeThreshold then
        moveY = -1
    elseif mouseY > self.windowHeight - self.edgeThreshold then
        moveY = 1
    end
    
    -- Normalize diagonal movement
    if moveX ~= 0 and moveY ~= 0 then
        moveX = moveX * 0.707
        moveY = moveY * 0.707
    end
    
    -- Apply movement
    self.x = self.x + moveX * self.speed * dt
    self.y = self.y + moveY * self.speed * dt
    
    -- Clamp camera position to world bounds
    self.x = math.max(0, math.min(self.x, self.worldWidth - self.windowWidth))
    self.y = math.max(0, math.min(self.y, self.worldHeight - self.windowHeight))
end

function camera:getWorldCoords(screenX, screenY)
    return screenX + self.x, screenY + self.y
end

function camera:getScreenCoords(worldX, worldY)
    return worldX - self.x, worldY - self.y
end

return camera