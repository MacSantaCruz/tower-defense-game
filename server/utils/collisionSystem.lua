local logger = require "logger"

local CollisionSystem = {
    instance = nil
}

function CollisionSystem.getInstance()
    if not CollisionSystem.instance then
        CollisionSystem.instance = {
            spatialGrid = nil,
            tileSize = 32,
            mapWidth = 75, -- Original map width in tiles
            initialized = false
        }

        CollisionSystem.instance.initialize = function(self, mapConfig, spatialGrid)
            self.spatialGrid = spatialGrid
            self.tileSize = mapConfig.tileSize
            self.mapWidth = mapConfig.originalWidth
            
            -- Insert all trees into spatial grid
            for side, trees in pairs(mapConfig.trees) do
                for _, tree in ipairs(trees) do
                    -- Normalize tree coordinates based on side
                    local normalizedX = tree.x
                    if side == "right" then
                        normalizedX = tree.x - (self.mapWidth * self.tileSize)
                    end
                    
                    -- Convert bottom-left to top-left for tree
                    local topY = tree.y - tree.height
                    
                    local treeEntity = {
                        id = "tree_" .. tree.id,
                        x = normalizedX,
                        y = topY,  -- Store top-left Y
                        width = tree.width,
                        height = tree.height,
                        type = "tree",
                        side = side
                    }
                    self.spatialGrid:insert(treeEntity)
                    
                    if self.debugMode then
                        logger.info(string.format("Tree added to grid - Side: %s, ID: %s", side, treeEntity.id))
                        logger.info(string.format("  Original Bottom-Left: (%d, %d)", tree.x, tree.y))
                        logger.info(string.format("  Normalized Top-Left: (%d, %d)", treeEntity.x, treeEntity.y))
                        logger.info(string.format("  Size: %dx%d", treeEntity.width, treeEntity.height))
                    end
                end
            end
            
            self.initialized = true
            logger.info("Collision system initialized")
        end

        CollisionSystem.instance.isValidTowerPlacement = function(self, data)
            if not self.initialized then return false end
            
            -- Convert center coordinates to top-left for tower
            local towerSize = self.tileSize * 2 -- assuming 2x2 tower
            local centerX = data.x
            local centerY = data.y
            
            -- Normalize coordinates for the side
            if data.side == "right" then
                centerX = centerX - (self.mapWidth * self.tileSize)
            end
            
            -- Calculate tower hitbox from center point
            local towerHitbox = {
                left = centerX - (towerSize / 2),
                right = centerX + (towerSize / 2),
                top = centerY - (towerSize / 2),
                bottom = centerY + (towerSize / 2)
            }
            
            -- Convert to tile coordinates for bounds checking
            local tileX = math.floor(towerHitbox.left / self.tileSize)
            local tileY = math.floor(towerHitbox.top / self.tileSize)
            
            if self.debugMode then
                logger.info(string.format("\nChecking tower placement:"))
                logger.info(string.format("  Center: (%d, %d)", centerX, centerY))
                logger.info(string.format("  Tower Hitbox: L=%d, R=%d, T=%d, B=%d",
                    towerHitbox.left, towerHitbox.right, towerHitbox.top, towerHitbox.bottom))
                logger.info(string.format("  Tile Position: (%d, %d)", tileX, tileY))
            end
            
            -- Get nearby entities using center point
            local searchRadius = self.tileSize * 4
            local nearbyEntities = self.spatialGrid:getNearbyEntities(centerX, centerY, searchRadius)
            
            if self.debugMode then
                logger.info(string.format("Found %d nearby entities within radius %d", 
                    #nearbyEntities, searchRadius))
            end
            
            -- Check collisions
            for _, entity in ipairs(nearbyEntities) do
                if entity.type == "tree" and entity.side == data.side then
                    -- The stored tree position is top-left, need to create hitbox
                    local treeHitbox = {
                        left = entity.x,
                        right = entity.x + entity.width,
                        top = entity.y,
                        bottom = entity.y + entity.height
                    }
                    
                    if self.debugMode then
                        logger.info(string.format("\nChecking tree collision:"))
                        logger.info(string.format("  Tree Stored Top-Left: (%d, %d)", entity.x, entity.y))
                        logger.info(string.format("  Tree Hitbox: L=%d, R=%d, T=%d, B=%d",
                            treeHitbox.left, treeHitbox.right, treeHitbox.top, treeHitbox.bottom))
                    end
                    
                    -- Check overlap with minimal buffer
                    local bufferSize = self.tileSize / 16  -- Increased buffer slightly
                    if not (towerHitbox.right < treeHitbox.left - bufferSize or
                           towerHitbox.left > treeHitbox.right + bufferSize or
                           towerHitbox.bottom < treeHitbox.top - bufferSize or
                           towerHitbox.top > treeHitbox.bottom + bufferSize) then
                        logger.info("Collision detected with tree")
                        logger.info(string.format("  Overlap: Tower(%d,%d,%d,%d) with Tree(%d,%d,%d,%d)",
                            towerHitbox.left, towerHitbox.top, towerHitbox.right, towerHitbox.bottom,
                            treeHitbox.left, treeHitbox.top, treeHitbox.right, treeHitbox.bottom))
                        return false
                    end
                end
            end
            
            return true
        end
    end
    
    return CollisionSystem.instance
end

return CollisionSystem