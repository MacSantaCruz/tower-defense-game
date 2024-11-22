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

-- Function to initialize the enemy (call this after creating new instance)
function PeonEnemy:init()
    LOGGER.info("Initializing PeonEnemy")
    
    -- Load directional sprites
    self:loadDirectionalSprites({
        up = "images/enemies/peonEnemy/U_WALK.png",
        down = "images/enemies/peonEnemy/D_WALK.png",
        side = "images/enemies/peonEnemy/S_WALK.png",
        deathUp = "images/enemies/peonEnemy/U_DEATH.png",
        deathDown = "images/enemies/peonEnemy/D_DEATH.png",
        deathSide = "images/enemies/peonEnemy/S_DEATH.png"
    })

    -- Set up walk animations
    self:setupAnimation(6, "up")
    self:setupAnimation(6, "down")
    self:setupAnimation(6, "side")
    
    -- Set up death animations (adjust the number of frames based on your death sprite sheets)
    self:setupAnimation(6, "deathUp")
    self:setupAnimation(6, "deathDown")
    self:setupAnimation(6, "deathSide")
    
    -- Set initial facing direction
    self.facing = "down"
    self.currentSprite = self.sprites["down"]
    self.currentFrame = 1
    
    LOGGER.info("PeonEnemy initialization complete")
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