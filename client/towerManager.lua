-- towerManager.lua
local FastTower = require "./towers/fastTower"
local MechTower = require "./towers/mechTower"
local TowerFactory = require "./towers/towerFactory"

local TowerManager = {
    towers = {},
    tileSize = nil,
    selectedTowerType = nil,
    placementGhost = nil,
    canPlaceTower = false,
    targetEnemies = nil
}

function TowerManager:new(tileSize, walkwayPaths, gameMap, side, originalMapWidth)
    local manager = setmetatable({}, { __index = self })
    manager.tileSize = tileSize
    manager.gameMap = gameMap
    manager.side = side
    manager.originalMapWidth = originalMapWidth
    manager.towers = {}  -- Change to a table with tower IDs as keys
    manager.towersList = {}  -- Keep array for iteration if needed
    manager.targetEnemies = {}  -- Initialize empty table
    manager.selectedTowerType = nil
    manager.canPlaceTower = true
    manager.placementGhost = nil
    return manager
end

function TowerManager:update(dt, camera, targetEnemies)
    self.targetEnemies = targetEnemies or {}
    
    -- Update existing towers
    for _, tower in pairs(self.towers) do
        if tower then
            tower:update(dt)
        end
    end
    
    -- Update placement ghost
    if self.selectedTowerType and self.placementGhost then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = camera:getWorldCoords(mouseX, mouseY)
        
        -- Snap to grid center
        local tileX = math.floor(worldX / self.tileSize)
        local tileY = math.floor(worldY / self.tileSize)
        
        -- Center on tile
        self.placementGhost.x = tileX * self.tileSize + self.tileSize
        self.placementGhost.y = tileY * self.tileSize + self.tileSize
        
        self.canPlaceTower = self:isValidPlacement(self.placementGhost.x, self.placementGhost.y)
    end
end


function TowerManager:draw()
    -- Draw all towers
    for _, tower in pairs(self.towers) do
        tower:draw()
    end

    -- Draw placement ghost with 2x2 tile highlight
    if self.placementGhost and self.selectedTowerType then
        if self.canPlaceTower then
            love.graphics.setColor(0.5, 1, 0.5, 0.3)
        else
            love.graphics.setColor(1, 0.5, 0.5, 0.3)
        end
        
        -- Draw tile highlight first
        love.graphics.rectangle("fill",
            self.placementGhost.x - self.tileSize,
            self.placementGhost.y - self.tileSize,
            self.tileSize * 2,
            self.tileSize * 2
        )
        
        -- Draw ghost tower
        local ghost = self:towerTypeToTowerClass(self.selectedTowerType):new(
            self.placementGhost.x,
            self.placementGhost.y
        )
        ghost.color = {love.graphics.getColor()}
        ghost:draw()
        
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function TowerManager:towerTypeToTowerClass(towerType)
    if towerType == "fastTower" then
        return FastTower
    elseif towerType == "mechTower" then
        return MechTower
    else
        LOGGER.error("ERROR: Passed unavailable towerType name to TowerManager")
    end
end

function TowerManager:createTower(towerData)
    -- Create client-side tower instance
    local tower = TowerFactory:createTower(towerData)
    if tower then
        self.towers[tower.id] = tower  
        table.insert(self.towersList, tower)  
        self:clearTowerSelection()
        return tower
    end
    return nil
end

function TowerManager:selectTowerType(towerType)
    self.selectedTowerType = towerType
    self.placementGhost = {}  -- Initialize ghost when selecting tower type
end

function TowerManager:clearTowerSelection()
    self.selectedTowerType = nil
    self.placementGhost = nil
end


function TowerManager:isValidPlacement(x, y)
    -- Convert the world x coordinate to the original map space for the right side
    local checkX = x
    if self.side == "right" then
        -- Calculate the relative position from the right edge of the original map
        checkX = x - self.originalMapWidth
        
        -- Mirror the x coordinate back to the original map space
        checkX = self.originalMapWidth - checkX
    end
    
    -- Convert world coordinates to tile coordinates for all four corners of the 2x2 area
    local tileX = math.floor(checkX / self.tileSize)
    local tileY = math.floor(y / self.tileSize)
    
    -- Check a 2x2 area centered on the placement point
    for offsetY = -1, 0 do
        for offsetX = -1, 0 do
            local currentX = tileX + offsetX
            local currentY = tileY + offsetY
            
            -- Ensure we're within map bounds
            if currentX < 0 or currentY < 0 or 
               currentX >= self.gameMap.width or 
               currentY >= self.gameMap.height then
                LOGGER.info('Failed Map Bounds')
                return false
            end
            
            -- Check path tiles
            if self.gameMap.layers["TilePath"] then
                local pathsLayer = self.gameMap.layers["TilePath"]
                if currentY >= 0 and currentY < pathsLayer.height and
                   currentX >= 0 and currentX < pathsLayer.width then
                    local tile = pathsLayer.data[currentY + 1][currentX + 1]
                    if tile and tile.gid and tile.gid > 0 then
                        LOGGER.info('Failed Tilepath')
                        return false
                    end
                end
            end
        end
    end
    
    -- Check tower overlap with minimal spacing
    for _, tower in pairs(self.towers) do
        local towerCheckX = tower.x
        if self.side == "right" then
            -- Apply the same transformation to existing tower positions
            towerCheckX = tower.x - self.originalMapWidth
            towerCheckX = self.originalMapWidth - towerCheckX
        end
        
        local dx = towerCheckX - checkX
        local dy = tower.y - y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.tileSize * 1.5 then
            LOGGER.info('Failed tower overlap')
            return false
        end
    end

    return true
end

function TowerManager:handleAttack(towerId, targetId, damage)
    
    local tower = self.towers[towerId]
    if tower then
        local targetEnemy = self.targetEnemies[targetId]
        if targetEnemy then
            tower:onServerFire(targetEnemy)
        end
    else
        LOGGER.error("[TowerManager] Tower not found:", towerId)
        LOGGER.info("Available towers:")
        for id, _ in pairs(self.towers) do
            LOGGER.info("  -", id)
        end
    end
end


return TowerManager