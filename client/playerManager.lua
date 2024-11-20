local ClientBaseManager = require "baseManager"
local PlayerManager = {}
PlayerManager.__index = PlayerManager

function PlayerManager:new()
    local instance = setmetatable({}, self)
    instance.players = {}
    instance.baseManager = ClientBaseManager:new()
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

function PlayerManager:setBasePositions(positions)
    self.basePositions = positions
end

function PlayerManager:drawBases()
    if not self.basePositions then return end
    
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)  -- Gray color for placeholder
    local baseSize = 64  -- 2x2 tiles
    
    -- Draw left base in world coordinates
    if self.basePositions.left then
        love.graphics.rectangle("fill", 
            self.basePositions.left.x - baseSize/2,
            self.basePositions.left.y - baseSize/2,
            baseSize, baseSize)
    end
    
    -- Draw right base in world coordinates
    if self.basePositions.right then
        love.graphics.rectangle("fill",
            self.basePositions.right.x - baseSize/2,
            self.basePositions.right.y - baseSize/2,
            baseSize, baseSize)
    end
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

return PlayerManager