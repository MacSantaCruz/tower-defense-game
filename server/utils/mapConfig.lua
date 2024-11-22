local MapConfig = {
    tileSize = 32,
    width = 75 * 2,
    originalWidth = 75,
    height = 56,
    pathTiles = {},  
    spawnPoints = {
        left = {},
        right = {}
    },
    paths = {},
    trees = {
        left = {},    
        right = {}    
    },
    zones = {
        left = {},    
        right = {}    
    },
    spawnZones = {
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
    self.zones = { left = {}, right = {} }
    self.spawnZones = { left = {}, right = {} }
    
    self.mapData = require("maps/kekw")
    print("MapData:", self.mapData)  -- Should show table memory address
    
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

    print("Setting up zones...")
    self:SetupZones()
end

function MapConfig:SetupZones()
    local zonesLayer
    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "objectgroup" and layer.name == "Zones" then
            zonesLayer = layer
            break
        end
    end

    if zonesLayer then
        -- First pass: collect all zones
        local zonesById = {}
        for _, object in ipairs(zonesLayer.objects) do
            if object.shape == "rectangle" then
                local zone = {
                    id = object.id,
                    x = object.x,
                    y = object.y,
                    width = object.width,
                    height = object.height,
                    name = object.name,
                    isSpawn = object.properties.isSpawn or false,
                    nextZoneId = object.properties.nextZone and object.properties.nextZone.id
                }
                zonesById[object.id] = zone
                
                -- Add to appropriate collection based on zone type
                if zone.isSpawn then
                    table.insert(self.spawnZones.left, zone)
                else
                    table.insert(self.zones.left, zone)
                end
                
                -- Create mirrored zone for right side
                local mirroredZone = self:createMirroredZone(zone)
                if mirroredZone then
                    zonesById[mirroredZone.id] = mirroredZone
                    if zone.isSpawn then
                        table.insert(self.spawnZones.right, mirroredZone)
                    else
                        table.insert(self.zones.right, mirroredZone)
                    end
                end
            end
        end
        
        -- Second pass: link zones
        for _, zone in pairs(zonesById) do
            if zone.nextZoneId then
                zone.nextZone = zonesById[zone.nextZoneId]
            end
        end
    end
end

function MapConfig:createMirroredZone(zone)
    local centerX = self.width * self.tileSize / 2
    local nextZoneId = zone.nextZoneId
    if nextZoneId then
        nextZoneId = nextZoneId + 10000
    end

    local mirroredZone = {
        id = zone.id + 10000, -- Ensure unique ID for mirrored zone
        x = (2 * centerX) - (zone.x + zone.width), -- Mirror X position
        y = zone.y,
        width = zone.width,
        height = zone.height,
        name = zone.name .. "_mirrored",
        isSpawn = zone.isSpawn,
        nextZoneId = nextZoneId
    }
    
    return mirroredZone
end


return MapConfig