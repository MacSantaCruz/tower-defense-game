local Enemy = require("enemies.serverEnemy")

local BlobEnemy = Enemy:new()

-- Override default values
BlobEnemy.health = 300
BlobEnemy.maxHealth = 300
BlobEnemy.speed = 50
BlobEnemy.armor = 5
BlobEnemy.incomeChange = 1

return BlobEnemy