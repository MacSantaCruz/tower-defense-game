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
    self.targetEnemies = targetEnemies or {}  -- Use empty table if nil
    -- Just update existing towers
    for _, tower in pairs(self.towers) do
        if tower then
            tower:update(dt)
        end
    end
    
    -- Update placement ghost
    if self.selectedTowerType and self.placementGhost then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = camera:getWorldCoords(mouseX, mouseY)
        
        -- Snap to grid
        local gridX = math.floor(worldX / self.tileSize) * self.tileSize + self.tileSize/2
        local gridY = math.floor(worldY / self.tileSize) * self.tileSize + self.tileSize/2
        
        -- Update ghost position
        self.placementGhost.x = gridX
        self.placementGhost.y = gridY
        self.canPlaceTower = self:isValidPlacement(gridX, gridY)
    end
end


function TowerManager:draw()
    -- Draw all towers
    for _, tower in pairs(self.towers) do
        tower:draw()
    end

    -- Draw placement ghost
    if self.placementGhost and self.selectedTowerType then
        if self.canPlaceTower then
            love.graphics.setColor(0.5, 1, 0.5, 0.5)
        else
            love.graphics.setColor(1, 0.5, 0.5, 0.5)
        end
        
        local ghost = self:towerTypeToTowerClass(self.selectedTowerType):new(self.placementGhost.x, self.placementGhost.y)
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
        self.towers[tower.id] = tower  -- Store by ID
        table.insert(self.towersList, tower)  -- Keep array for iteration
        return tower
    end
    return nil
end

function TowerManager:selectTowerType(towerType)
    self.selectedTowerType = towerType
    self.placementGhost = {}  -- Initialize ghost when selecting tower type
end

function TowerManager:isValidPlacement(x, y)
    -- Convert world coordinates to tile coordinates
    local tileX = math.floor(x / self.tileSize) + 1
    local tileY = math.floor(y / self.tileSize) + 1
    
    -- Check if position is on a path tile
    if self.gameMap and self.gameMap.layers["TilePath"] then
        local pathsLayer = self.gameMap.layers["TilePath"]
        
        -- Check if the tile position is within bounds
        if tileY >= 1 and tileY <= pathsLayer.height and
           tileX >= 1 and tileX <= pathsLayer.width then
            
            -- Check if there's a tile with a gid at this position
            local tile = pathsLayer.data[tileY][tileX]
            if tile and tile.gid and tile.gid > 0 then
                return false  -- Can't place on paths
            end
        end
    end
    
    -- Check if position overlaps with other towers
    for _, tower in ipairs(self.towers) do
        local dx = tower.x - x
        local dy = tower.y - y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.tileSize * 2 then
            return false
        end
    end

    return true
end

function TowerManager:handleAttack(towerId, targetId, damage)
    LOGGER.debug(string.format("[TowerManager] Handling attack - Tower: %d, Target: %d", towerId, targetId))
    
    local tower = self.towers[towerId]
    if tower then
        LOGGER.debug("[TowerManager] Found tower")
        local targetEnemy = self.targetEnemies[targetId]
        if targetEnemy then
            LOGGER.debug(string.format("[TowerManager] Found target at (%.1f, %.1f)", 
                targetEnemy.x, targetEnemy.y))
            tower:onServerFire(targetEnemy)
        else
            LOGGER.debug("[TowerManager] Target enemy not found:", targetId)
            LOGGER.debug("Available enemies:")
            for id, _ in pairs(self.targetEnemies) do
                LOGGER.debug("  -", id)
            end
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