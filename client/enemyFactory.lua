local BlobEnemy = require './enemies/blobEnemy'
local PeonEnemy = require './enemies/peonEnemy'

local EnemyFactory = {
    enemyTypes = {
        blobEnemy = BlobEnemy,
        peonEnemy = PeonEnemy
    }
}

function EnemyFactory:spawnEnemy(enemyType, side, x, y, id)
    local EnemyClass = self.enemyTypes[enemyType]
    if not EnemyClass then return nil end

    local enemy = EnemyClass:new(x,y)
    enemy.id = id
    enemy.type = enemyType
    enemy.side = side

    return enemy
end

return EnemyFactory

    