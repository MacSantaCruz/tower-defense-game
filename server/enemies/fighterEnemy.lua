-- fastEnemy.lua
local Enemy = require("enemies.serverEnemy")

local Fighter = Enemy:new()

-- Override default values
Fighter.health = 200
Fighter.maxHealth = 200
Fighter.speed = 100
Fighter.armor = 5

return Fighter