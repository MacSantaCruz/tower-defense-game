local FastEnemy = require "./enemies/fastEnemy"
local FighterEnemy = require "./enemies/fighterEnemy"


local EnemyFactory = {
    enemyTypes = {
        fastEnemy = FastEnemy,
        fighterEnemy = FighterEnemy
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

function EnemyFactory:getEnemyCost(enemyType)
    local EnemyClass = self.enemyTypes[enemyType]
    return EnemyClass.cost
end

return EnemyFactory

    