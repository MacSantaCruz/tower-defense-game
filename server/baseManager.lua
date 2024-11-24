local SpatialGrid = require "utils.spatialGrid"

local ServerBaseManager = {
    bases = {},  -- Store all bases
    basePositions = {  -- Similar to how you store spawnPoints in enemy manager
        left = nil,
        right = nil
    }
}
ServerBaseManager.__index = ServerBaseManager

local BASE_MAX_HEALTH = 1000
local BASE_SIZE = 256

function ServerBaseManager:new(config)
    local instance = setmetatable({}, self)
    instance.bases = {}
    instance.basePositions = config.basePositions  -- Get from MapConfig
    instance.grid = config.grid or SpatialGrid.getInstance()

    --TODO: FIX THIS 
    local baseId = 10000 
    for side, pos in pairs(instance.basePositions) do
        instance.bases[side] = {
            id = baseId,
            side = side,
            position = pos,
            x = pos.x,
            y = pos.y,
            width = pos.width,
            height = pos.height,
            health = BASE_MAX_HEALTH,
            maxHealth = BASE_MAX_HEALTH,
            size = pos.width,  -- Use actual width from map
            type = "base"
        }
        
        -- Add base to spatial grid
        instance.grid:insert(instance.bases[side])
        baseId = baseId + 1
    end
    
    return instance
end

function ServerBaseManager:takeDamage(side, amount)
    updates = {}
    local base = self.bases[side]
    if not base then return end
    
    base.health = math.max(0, base.health - amount)
    
    table.insert(updates, {
        type = "baseTakeDamage",
        side = side,
        damage = amount,
        currentHealth = base.health
    })
    
    -- If base is destroyed, remove from spatial grid
    if base.health <= 0 then
        self.grid:remove(base)
        table.insert(updates, {
            type = "baseDestroyed",
            side = side
        })
    end
    return updates
end

function ServerBaseManager:getBasePositions()
    return self.basePositions
end

function ServerBaseManager:cleanup()
    -- Remove bases from spatial grid when cleaning up
    for _, base in pairs(self.bases) do
        self.grid:remove(base)
    end
    self.bases = {}
end

function ServerBaseManager:getBaseAtPosition(x, y)
    local nearbyEntities = self.grid:getNearbyEntities(x, y, math.max(BASE_SIZE, 256))  -- Use larger search radius
    
    for _, entity in ipairs(nearbyEntities) do
        if entity.type == "base" then
            -- Use actual width/height for bounds checking
            local dx = x - entity.x
            local dy = y - entity.y
            local halfWidth = entity.width / 2
            local halfHeight = entity.height / 2
            
            if math.abs(dx) <= halfWidth and math.abs(dy) <= halfHeight then
                return entity
            end
        end
    end
    
    return nil
end

return ServerBaseManager