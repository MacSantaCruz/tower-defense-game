local NetworkConstants = require "network.networkConstants"
local LOGGER = require "logger"

local MessageHandlers = {
    [NetworkConstants.SERVER.INITIALIZATION] = function(network, data)
        LOGGER.info("Received initialization data:")
        LOGGER.info("Assigned side:", data.side)
        LOGGER.info("Game state received:", data.gameState ~= nil)
        
        network.playerSide = data.side
        network.gameState = data.gameState
        playerManager.baseManager:initializeBases(data.gameState.basePositions)
        _G.LOGGER = LOGGER.getLogger(network.playerSide)
        
        if playerManager then
            LOGGER.info("PlayerManager exists, creating towers")
            -- Create existing towers
            for towerId, tower in pairs(network.gameState.towers or {}) do
                LOGGER.info("Processing tower", towerId)
                local player = playerManager.players[tower.side]
                if player then
                    LOGGER.info("Found player for side", tower.side, "creating tower")
                    local created = player.towerManager:createTower(tower)
                    LOGGER.info("Tower creation Tower:", created.id)
                else
                    LOGGER.info("No player found for side:", tower.side)
                end
            end
            -- Create existing enemies
            if data.gameState.enemies then
                for enemyId, enemyData in pairs(data.gameState.enemies) do
                    local player = playerManager.players[enemyData.targetSide]
                    if player then
                        player.enemyManager:spawnEnemy(enemyData)
                    end
                end
            end
        else
            LOGGER.error("PlayerManager not available during initialization")
        end
    end,

    [NetworkConstants.SERVER.TOWER_PLACED] = function(network, data)
        LOGGER.info("Received tower placement:", data.tower.id, data.tower.side, data.tower.x, data.tower.y)
        network.gameState.towers[data.tower.id] = data.tower
        
        if playerManager then
            local player = playerManager.players[data.tower.side]
            if player then
                LOGGER.info("Creating tower for player:", data.tower.side)
                player.towerManager:createTower(data.tower)
            else
                LOGGER.error("No player found for side:", data.tower.side)
            end
        end
    end,

    [NetworkConstants.SERVER.ENEMY_SPAWNED] = function(network, data)
        LOGGER.info("Enemy spawned:", data.enemy.id, data.enemy.type)
        
        if playerManager then
            LOGGER.info("Checking player for side: ", data.enemy.targetSide)
            local player = playerManager.players[data.enemy.targetSide]
            if player then
                LOGGER.info('Spawning enemy for: ', data.enemy.targetSide)
                local enemy = player.enemyManager:spawnEnemy(data.enemy)
                network.gameState.enemies[data.enemy.id] = enemy
            else
                LOGGER.error('Player doesnt exist for enemy to spawn')
            end
        end
    end,

    [NetworkConstants.SERVER.ENEMY_DIED] = function(network, data)
        local deadEnemy = network.gameState.enemies[data.enemyId]
        if deadEnemy then
            local player = playerManager.players[deadEnemy.targetSide]
            if player then
                player.enemyManager:removeEnemy(data.enemyId)
            end
            network.gameState.enemies[data.enemyId] = nil
        end
    end,

    [NetworkConstants.SERVER.GAME_UPDATES] = function(network, data)
        -- Handle tower updates
        if data.towerUpdates then
            for _, update in ipairs(data.towerUpdates) do
                if update.type == NetworkConstants.UPDATE.TOWER_ATTACK then
                    LOGGER.info("[Network] Processing attack - Tower:", update.id, "Target:", update.targetId)
                    local tower = network.gameState.towers[update.id]
                    if tower then
                        local player = playerManager.players[tower.side]
                        if player then
                            player.towerManager:handleAttack(update.id, update.targetId, update.damage)
                        end
                    end
                elseif update.type == NetworkConstants.UPDATE.ENEMY_DAMAGE then
                    LOGGER.info("[Network] Received Damage for Enemy:", update.id)
                    local enemy = network.gameState.enemies[update.id]
                    if enemy then
                        -- Update network state
                        enemy.health = update.health
                        
                        -- Update visual state
                        local player = playerManager.players[enemy.targetSide]
                        if player then
                            player.enemyManager:updateEnemy(update.id, {
                                health = update.health,
                                x = update.x,
                                y = update.y
                            })
                            
                            if update.health <= 0 then
                                player.enemyManager:removeEnemy(update.id)
                                network.gameState.enemies[update.id] = nil
                            end
                        end
                    end
                end
            end
        end

        -- Handle enemy updates
        if data.enemyUpdates then
            for _, update in ipairs(data.enemyUpdates) do
                local enemy = network.gameState.enemies[update.id]
                if enemy then
                    if update.type == NetworkConstants.UPDATE.ENEMY_DEATH then
                        LOGGER.info("[Network] Received death update for Enemy:", update.id)
                        local deadEnemy = network.gameState.enemies[update.id]
                        if deadEnemy then
                            network.gameState.enemies[update.id] = nil
                            local player = playerManager.players[deadEnemy.side]
                            if player then
                                LOGGER.info("[Network] Removing Enemy:", update.id, " From player:", player.side)
                                player.enemyManager:removeEnemy(update.id)
                            end
                        end
                    else
                        -- Handle movement updates
                        if enemy and update then
                            -- Update network state
                            enemy.x = update.x
                            enemy.y = update.y
                            enemy.direction = update.direction
                            enemy.health = update.health
                            
                            -- Update visual state
                            local player = playerManager.players[enemy.targetSide]
                            if player then
                                player.enemyManager:updateEnemyPosition(
                                    update.id,
                                    update.x,
                                    update.y,
                                    update.direction,
                                    update.health,
                                    update.targetx,
                                    update.targety
                                )
                            end
                        end
                    end
                end
            end
        end
    end
}

return MessageHandlers