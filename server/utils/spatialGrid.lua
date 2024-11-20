local SpatialGrid = {
    instance = nil  -- Singleton instance
}

function SpatialGrid.getInstance()
    if not SpatialGrid.instance then
        -- For 500 range towers, use cell size of 375-400
        local CELL_SIZE = 375

        SpatialGrid.instance = {
            cellSize = CELL_SIZE,
            grid = {},
            entityPositions = {},  -- Track current cell of each entity
            stats = {
                totalEntities = 0,
                totalCells = 0
            }
        }
        
        -- Add methods to the instance
        SpatialGrid.instance.getCellKey = function(self, x, y)
            local cellX = math.floor(x / self.cellSize)
            local cellY = math.floor(y / self.cellSize)
            return cellX .. "," .. cellY
        end
        
        SpatialGrid.instance.getCell = function(self, x, y)
            local key = self:getCellKey(x, y)
            if not self.grid[key] then
                self.grid[key] = {}
                self.stats.totalCells = self.stats.totalCells + 1
            end
            return self.grid[key]
        end
        
        SpatialGrid.instance.insert = function(self, entity)
            -- Remove from old position if exists
            self:remove(entity)
            
            -- Add to new position
            local cell = self:getCell(entity.x, entity.y)
            cell[entity.id] = entity
            
            -- Track entity's current cell
            self.entityPositions[entity.id] = self:getCellKey(entity.x, entity.y)
            self.stats.totalEntities = self.stats.totalEntities + 1

        end
        
        SpatialGrid.instance.remove = function(self, entity)
            local currentCellKey = self.entityPositions[entity.id]
            if currentCellKey then
                if self.grid[currentCellKey] then
                    self.grid[currentCellKey][entity.id] = nil
                end
                self.entityPositions[entity.id] = nil
                self.stats.totalEntities = self.stats.totalEntities - 1
            end
        end
        
        SpatialGrid.instance.updateEntity = function(self, entity)
            local currentCellKey = self.entityPositions[entity.id]
            local newCellKey = self:getCellKey(entity.x, entity.y)
            
            if currentCellKey ~= newCellKey then
                self:insert(entity)  -- This handles removal from old cell
            end
        end
        
        SpatialGrid.instance.getNearbyEntities = function(self, x, y, radius)
            local nearby = {}
            local minCellX = math.floor((x - radius) / self.cellSize)
            local maxCellX = math.floor((x + radius) / self.cellSize)
            local minCellY = math.floor((y - radius) / self.cellSize)
            local maxCellY = math.floor((y + radius) / self.cellSize)
            
            for cellX = minCellX, maxCellX do
                for cellY = minCellY, maxCellY do
                    local key = cellX .. "," .. cellY
                    local cell = self.grid[key]
                    if cell then
                        for _, entity in pairs(cell) do
                            local dx = entity.x - x
                            local dy = entity.y - y
                            if dx * dx + dy * dy <= radius * radius then
                                table.insert(nearby, entity)
                            end
                        end
                    end
                end
            end
            
            return nearby
        end

        -- Debug method to visualize the grid
        SpatialGrid.instance.debugDraw = function(self)
            love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
            
            for key, cell in pairs(self.grid) do
                local cellX, cellY = key:match("([^,]+),([^,]+)")
                cellX, cellY = tonumber(cellX), tonumber(cellY)
                
                -- Draw cell boundaries
                love.graphics.rectangle("line",
                    cellX * self.cellSize,
                    cellY * self.cellSize,
                    self.cellSize,
                    self.cellSize
                )
                
                -- Draw entity count
                local count = 0
                for _ in pairs(cell) do count = count + 1 end
                if count > 0 then
                    love.graphics.print(count,
                        (cellX * self.cellSize) + self.cellSize/2,
                        (cellY * self.cellSize) + self.cellSize/2
                    )
                end
            end
            
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    return SpatialGrid.instance
end

return SpatialGrid