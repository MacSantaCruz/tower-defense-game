local FastEnemy = require "./enemies/fastEnemy"

local EnemyFactory = {
    enemyTypes = {
        fastEnemy = FastEnemy
    }
}

function EnemyFactory:spawnEnemy(enemyType, side, x, y, id)
    local EnemyClass = self.enemyTypes[enemyType]
    if not EnemyClass then return nil end

    local enemy = EnemyClass:new(x,y)
    enemy.id = id
    enemy.type = enemyType
    --TODO: fix this 
    enemy.side = side
    enemy.targetSide = side

    return enemy
end

return EnemyFactory

    