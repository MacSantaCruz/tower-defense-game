local NetworkConstants = require "network.networkConstants"

local MessageConstructors = {
    -- Tower-related messages
    [NetworkConstants.CLIENT.PLACE_TOWER] = function(x, y, towerType)
        return {
            type = NetworkConstants.CLIENT.PLACE_TOWER,
            x = x,
            y = y,
            towerType = towerType,
            timestamp = os.time()
        }
    end,

    -- Enemy-related messages
    [NetworkConstants.CLIENT.SPAWN_ENEMY] = function(zoneSpawnIndex, enemyType, targetSide)
        return {
            type = NetworkConstants.CLIENT.SPAWN_ENEMY,
            zoneSpawnIndex = zoneSpawnIndex,
            enemyType = enemyType,
            targetSide = targetSide,
            timestamp = os.time()
        }
    end
}

return MessageConstructors