local Enemy = require("enemies.clientEnemy")

local FighterEnemy = Enemy:new()

-- Override default values
FighterEnemy.health = 200
FighterEnemy.maxHealth = 200
FighterEnemy.speed = 100
FighterEnemy.spriteWidth = 128
FighterEnemy.spriteHeight = 128
FighterEnemy.scale = 1
FighterEnemy.radius = 64  -- Half of the 64px sprite size
FighterEnemy.sprite = love.graphics.newImage("images/enemies/fighter_run.png")

FighterEnemy:setupAnimation(8)


return FighterEnemy