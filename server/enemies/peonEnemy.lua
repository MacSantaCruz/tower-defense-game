local Enemy = require("enemies.serverEnemy")

local PeonEnemy = Enemy:new()

-- Override default values
PeonEnemy.health = 600
PeonEnemy.maxHealth = 600
PeonEnemy.speed = 60
PeonEnemy.armor = 10
PeonEnemy.cost = 150
PeonEnemy.killValue = 200

return PeonEnemy