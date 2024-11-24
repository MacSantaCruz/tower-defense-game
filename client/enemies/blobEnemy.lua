local Enemy = require("enemies/clientEnemy")

local BlobEnemy = Enemy:new()

-- Override default values
BlobEnemy.health = 300
BlobEnemy.maxHealth = 300
BlobEnemy.speed = 50
BlobEnemy.spriteWidth = 48  -- Make sure these match your actual sprite dimensions
BlobEnemy.spriteHeight = 48
BlobEnemy.color = {1, 0.8, 0.8, 1}
BlobEnemy.frameDelay = 0.15

-- Static sprite paths that can be used by BatchManager
BlobEnemy.spritePaths = {
    up = "images/enemies/blobEnemy/U_Walk.png",
    down = "images/enemies/blobEnemy/D_Walk.png",
    side = "images/enemies/blobEnemy/S_Walk.png",
    deathUp = "images/enemies/blobEnemy/U_Death.png",
    deathDown = "images/enemies/blobEnemy/D_Death.png",
    deathSide = "images/enemies/blobEnemy/S_Death.png"
}

-- Define number of frames for each animation type
BlobEnemy.frameCount = 6

-- Function to initialize the enemy (call this after creating new instance)
function BlobEnemy:init()
    self.facing = "down"
    self.currentFrame = 1    
end

-- Override the new function to call init
function BlobEnemy:new(x, y, properties)
    local enemy = Enemy.new(self, x, y, properties)
    if enemy then
        enemy:init()  -- Initialize after creation
    end
    return enemy
end

return BlobEnemy