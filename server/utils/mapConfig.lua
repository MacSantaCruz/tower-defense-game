local logger = require "logger"
local PathManager = require "utils.pathManager"

local MapConfig = {
    tileSize = 32,
    width = 75 * 2,
    originalWidth = 75,
    height = 56,
    pathTiles = {},  
    paths = {},
    trees = {
        left = {},    
        right = {}    
    },
    basePositions = {
        left = nil,
        right = nil
    }
}

function MapConfig:createMirroredObject(object, isTree)
    if not object.id then 
        object.id = 1  -- Provide default ID if none exists
    end

    local centerX = self.width * self.tileSize / 2
    
    local mirroredObject = {
        id = object.id + 10000, -- Ensure unique ID for mirrored object
        x = (2 * centerX) - (object.x + object.width), -- Mirror X position
        y = object.y,
        width = object.width,
        height = object.height,
        name = object.name and (object.name .. "_mirrored") or nil
    }
    
    return mirroredObject
end

function MapConfig:SetupMap()
    self.pathTiles = {}
    self.mapData = require("maps/kekw3")

    self.pathManager = PathManager:new({
        tileSize = self.tileSize,
        width = self.width,
        originalWidth = self.originalWidth
    })

    self.pathManager:setupPaths(self.mapData)
    
    if not self.mapData then
        error("Failed to load map data")
    end
    
    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "objectgroup" then
            if layer.name == "Trees" then
                -- Process trees
                for _, object in ipairs(layer.objects) do
                    -- local centerX = self.width * self.tileSize / 2
                    -- Only process trees on the left side
                    -- if object.x + (object.width / 2) < centerX then
                        -- Create a complete tree object with all properties
                        local tree = {
                            id = object.id,
                            x = object.x,
                            y = object.y,
                            width = object.width,
                            height = object.height,
                            name = object.name
                        }
                        table.insert(self.trees.left, tree)
                        
                        -- Create and store mirrored tree
                        local mirroredTree = self:createMirroredObject(tree, true)
                        table.insert(self.trees.right, mirroredTree)
                    -- end
                end
            elseif layer.name == "Base" then
                -- Process base objects
                for _, object in ipairs(layer.objects) do
                    if object.name == "Base" then
                        local centerX = self.width * self.tileSize / 2
                        -- Only process base on the left side
                        if object.x + (object.width / 2) < centerX then
                            -- Create left base with full object properties
                            self.basePositions.left = {
                                id = object.id,
                                x = object.x + (object.width / 2),
                                y = object.y + (object.height / 2),
                                width = object.width,
                                height = object.height,
                                name = object.name
                            }
                            
                            self.basePositions.right = {
                                id = object.id + 10000,
                                x = (2 * centerX) - (object.x + (object.width / 2)),  -- Mirror the center position
                                y = object.y + (object.height / 2),
                                width = object.width,
                                height = object.height,
                                name = object.name .. "_mirrored"
                            }
                        end
                    end
                end
            end
        end
    end

end



return MapConfig