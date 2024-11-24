local Enemy = require("enemies/clientEnemy")

local PeonEnemy = Enemy:new()

-- Override default values
PeonEnemy.health = 600
PeonEnemy.maxHealth = 600
PeonEnemy.speed = 60
PeonEnemy.spriteWidth = 48  -- Make sure these match your actual sprite dimensions
PeonEnemy.spriteHeight = 48
PeonEnemy.color = {1, 0.8, 0.8, 1}
PeonEnemy.frameDelay = 0.15

PeonEnemy.spritePaths = {
    up = "images/enemies/peonEnemy/U_Walk.png",     
    down = "images/enemies/peonEnemy/D_Walk.png",  
    side = "images/enemies/peonEnemy/S_Walk.png",    
    deathUp = "images/enemies/peonEnemy/U_Death.png",  
    deathDown = "images/enemies/peonEnemy/D_Death.png",
    deathSide = "images/enemies/peonEnemy/S_Death.png"
}

PeonEnemy.frameCount = 6

-- Function to initialize the enemy (call this after creating new instance)
function PeonEnemy:init()
    self.facing = "down"
    self.currentFrame = 1
end

-- Override the new function to call init
function PeonEnemy:new(x, y, properties)
    local enemy = Enemy.new(self, x, y, properties)
    if enemy then
        enemy:init()  -- Initialize after creation
    end
    return enemy
end

return PeonEnemy