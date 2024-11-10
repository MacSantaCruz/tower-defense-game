-- playerManager.lua
local PlayerManager = {}
PlayerManager.__index = PlayerManager

function PlayerManager:new()
    local instance = setmetatable({}, self)
    instance.players = {}
    return instance
end

function PlayerManager:createPlayer(side, options)
    self.players[side] = {
        side = side,
        towerManager = options.TowerManager:new(
            options.tileSize, 
            options.paths, 
            options.gameMap, 
            side, 
            options.mapWidth
        ),
        enemyManager = options.EnemyManager:new(
            {
                side
            }
        )
    }
    return self.players[side]
end

-- Add this new method for handling mouse movement
function PlayerManager:updateMouseHover(worldX, worldY)
    -- Update hover for both players
    for side, player in pairs(self.players) do
        local adjustedX = worldX
        if side == "right" then
            adjustedX = worldX - player.towerManager.originalMapWidth
        end
        
        -- Update tower manager's ghost position
        if player.towerManager.selectedTowerType then
            local gridX = math.floor(adjustedX / player.towerManager.tileSize) * player.towerManager.tileSize + player.towerManager.tileSize/2
            local gridY = math.floor(worldY / player.towerManager.tileSize) * player.towerManager.tileSize + player.towerManager.tileSize/2
            
            player.towerManager.canPlaceTower = player.towerManager:checkValidPlacement(gridX, gridY)
            player.towerManager.placementGhost = {
                x = gridX,
                y = gridY,
                valid = player.towerManager.canPlaceTower
            }
        end
    end
end

return PlayerManager