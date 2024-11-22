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

-- Function to initialize the enemy (call this after creating new instance)
function BlobEnemy:init()
    LOGGER.info("Initializing BlobEnemy")
    
    -- Load directional sprites
    self:loadDirectionalSprites({
        up = "images/enemies/blobEnemy/U_WALK.png",     -- Adjust these paths to match your actual file structure
        down = "images/enemies/blobEnemy/D_WALK.png",
        side = "images/enemies/blobEnemy/S_WALK.png",
        deathUp = "images/enemies/blobEnemy/U_DEATH.png",
        deathDown = "images/enemies/blobEnemy/D_DEATH.png",
        deathSide = "images/enemies/blobEnemy/S_DEATH.png"
    })

    -- Set up animations for each direction
    self:setupAnimation(6, "up")
    self:setupAnimation(6, "down")
    self:setupAnimation(6, "side")
    

    self:setupAnimation(6, "deathUp")
    self:setupAnimation(6, "deathDown")
    self:setupAnimation(6, "deathSide")

    -- Set initial facing direction
    self.facing = "down"
    self.currentSprite = self.sprites["down"]
    self.currentFrame = 1
    
    LOGGER.info("BlobEnemy initialization complete")
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