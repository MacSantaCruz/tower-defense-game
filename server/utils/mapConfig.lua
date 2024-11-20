local MapConfig = {
    tileSize = 32,
    width = 75 * 2,      -- Number of tiles wide
    height = 56,      -- Number of tiles high
    pathTiles = {},    -- Will store path tile positions
    spawnPoints = {
        left = {},
        right = {}
    },
    paths = {},
    basePositions = {
        left = nil,
        right = nil
    }
}

function MapConfig:SetupMap()
    self.pathTiles = {}
    self.spawnPoints.left = {}
    self.spawnPoints.right = {}
    self.paths = {}
    
    local mapData = require("maps/kek_3")
    self:SetupEnemyPaths(mapData)
    self:SetupPathTiles(mapData)
end

function MapConfig:SetupEnemyPaths(mapData)
    local pathsLayer
    for _, layer in ipairs(mapData.layers) do
        if layer.type == "objectgroup" and layer.name == "Paths" then
            pathsLayer = layer
            break
        end
    end

    -- Figure out all the paths for enemies 
    if pathsLayer then
        local pathsById = {}
        
        -- First pass: collect polylines/paths
        for _, object in ipairs(pathsLayer.objects) do
            if object.shape == "polyline" then
                local path = {}
                -- Convert polyline points to absolute coordinates
                for _, point in ipairs(object.polyline) do
                    table.insert(path, {
                        x = object.x + point.x,
                        y = object.y + point.y
                    })
                end
                path.name = object.name
                pathsById[object.id] = path
            end
        end
        
        -- Second pass: process spawn points
        for _, object in ipairs(pathsLayer.objects) do
            if object.shape == "point" and object.name:match("^spawn_") then
                local pathRef = object.properties.pathName
                local pathId = pathRef and pathRef.id
                local linkedPath = pathsById[pathId]
                
                if linkedPath then
                    -- Create original spawn point
                    table.insert(self.spawnPoints.left, {
                        x = object.x,
                        y = object.y,
                        path = linkedPath,
                        name = object.name
                    })
                    
                    -- Create mirrored spawn point (flipping across center)
                    local mirroredPath = self:createMirroredPath(linkedPath)
                    table.insert(self.spawnPoints.right, {
                        x = self.width * self.tileSize - object.x,
                        y = object.y,
                        path = mirroredPath,
                        name = object.name .. "_mirrored"
                    })
                end
            elseif object.shape == "point" and object.name == "end" then
                self.basePositions.left = {
                    x = object.x,
                    y = object.y
                }
                
                self.basePositions.right = {
                    x = self.width * self.tileSize - object.x,
                    y = object.y
                }
            end
        end
    end
end

function MapConfig:SetupPathTiles(mapData)
     -- Find the TilePath layer
    local tilePathLayer
    for _, layer in ipairs(mapData.layers) do
        if layer.name == "TilePath" then
            tilePathLayer = layer
            break
        end
    end

    -- Process path tiles for both sides
    if tilePathLayer then
        for y = 1, self.height do
            self.pathTiles[y] = {}
            
            -- Original (left) side
            for x = 1, 75 do  -- Original map width
                -- Lua arrays start at 1, adjust index calculation
                local index = ((y-1) * 75) + x
                if tilePathLayer.data[index] and tilePathLayer.data[index] ~= 0 then
                    self.pathTiles[y][x] = true
                    
                    -- Mirror the path tile to the right side
                    local mirroredX = (75 * 2) - x + 1  -- Mirror position
                    self.pathTiles[y][mirroredX] = true
                end
            end
        end
    end
end

function MapConfig:createMirroredPath(originalPath)
    if not originalPath then return nil end
    
    local mirroredPath = {}
    local centerX = self.width * self.tileSize / 2
    
    for _, point in ipairs(originalPath) do
        -- Mirror across the center line
        table.insert(mirroredPath, {
            x = (2 * centerX) - point.x,
            y = point.y
        })
    end
    
    return mirroredPath
end


return MapConfig