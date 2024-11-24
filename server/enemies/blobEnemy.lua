local Enemy = require("enemies.serverEnemy")

local BlobEnemy = Enemy:new()

-- Override default values
BlobEnemy.health = 300
BlobEnemy.maxHealth = 300
BlobEnemy.speed = 50
BlobEnemy.armor = 5
BlobEnemy.incomeChange = 20
BlobEnemy.cost = 100
BlobEnemy.killValue = 40

return BlobEnemy