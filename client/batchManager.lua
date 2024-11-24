-- batchManager.lua
local BatchManager = {
    batches = {},
    spritesheets = {},
    sharedQuads = {}
}

function BatchManager:new()
    local manager = setmetatable({}, { __index = self })
    manager.batches = {}
    manager.spritesheets = {}
    manager.sharedQuads = {}
    return manager
end

function BatchManager:initializeType(enemyType, spritePaths, numFrames)
    -- Load spritesheets
    self.spritesheets[enemyType] = {}
    self.sharedQuads[enemyType] = {}
    
    -- Load each direction's spritesheet and create batch
    for direction, path in pairs(spritePaths) do
        local spritesheet = love.graphics.newImage(path)
        self.spritesheets[enemyType][direction] = spritesheet
        self.batches[enemyType .. "_" .. direction] = love.graphics.newSpriteBatch(spritesheet, 100)
        
        -- Create shared quads for this direction
        self.sharedQuads[enemyType][direction] = {}
        local frameWidth = 48  -- Use your actual frame width
        local frameHeight = 48 -- Use your actual frame height
        
        for i = 0, numFrames - 1 do
            local quad = love.graphics.newQuad(
                i * frameWidth,
                0,
                frameWidth,
                frameHeight,
                spritesheet:getDimensions()
            )
            table.insert(self.sharedQuads[enemyType][direction], quad)
        end
    end
end

function BatchManager:getQuads(enemyType)
    return self.sharedQuads[enemyType]
end

function BatchManager:clear()
    for _, batch in pairs(self.batches) do
        batch:clear()
    end
end

return BatchManager