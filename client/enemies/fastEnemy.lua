-- fastEnemy.lua
local Enemy = require("enemies.clientEnemy")

local FastEnemy = Enemy:new()

-- Override default values
FastEnemy.health = 300
FastEnemy.maxHealth = 300
FastEnemy.speed = 80
FastEnemy.sprite = love.graphics.newImage("images/enemies/fast_enemy.png")
FastEnemy.color = {1, 0.8, 0.8, 1}  -- Slight red tint
FastEnemy.frameDelay = 0.15  -- Faster animation

-- Set up the animation
FastEnemy:setupAnimation(4)  -- Adjust number based on your sprite sheet

return FastEnemy