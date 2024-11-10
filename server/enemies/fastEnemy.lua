-- fastEnemy.lua
local Enemy = require("enemies.serverEnemy")

local FastEnemy = Enemy:new()

-- Override default values
FastEnemy.health = 300
FastEnemy.maxHealth = 300
FastEnemy.speed = 80
FastEnemy.armor = 5

return FastEnemy