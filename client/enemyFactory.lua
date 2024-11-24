local BlobEnemy = require './enemies/blobEnemy'
local PeonEnemy = require './enemies/peonEnemy'
local BatchManager = require 'batchManager'

local EnemyFactory = {
    enemyTypes = {
        blobEnemy = BlobEnemy,
        peonEnemy = PeonEnemy
    },
    batchManager = nil
}

function EnemyFactory:init()
    self.batchManager = BatchManager:new()
    
    -- Initialize blob enemy batches using paths from BlobEnemy class
    self.batchManager:initializeType(
        "blobEnemy", 
        BlobEnemy.spritePaths,
        BlobEnemy.frameCount
    )
    
    -- Do the same for other enemy types
    self.batchManager:initializeType(
        "peonEnemy", 
        PeonEnemy.spritePaths,
        PeonEnemy.frameCount
    )
    LOGGER.info('INIT EnemyFactory')
end

function EnemyFactory:spawnEnemy(enemyType, side, x, y, id)
    local EnemyClass = self.enemyTypes[enemyType]
    if not EnemyClass then return nil end

    local enemy = EnemyClass:new(x,y)
    enemy.id = id
    enemy.type = enemyType
    enemy.side = side
    enemy.frames = self.batchManager:getQuads(enemyType)

    return enemy
end

function EnemyFactory:getBatchManager()
    if not self.batchManager then
        LOGGER.error("BatchManager not initialized! Make sure EnemyFactory:init() was called.")
    end
    return self.batchManager
end

return EnemyFactory

    