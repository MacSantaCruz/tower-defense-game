local ServerBaseManager = {
    bases = {},  -- Store all bases
    basePositions = {  -- Similar to how you store spawnPoints in enemy manager
        left = nil,
        right = nil
    }
}
ServerBaseManager.__index = ServerBaseManager

local BASE_MAX_HEALTH = 1000

function ServerBaseManager:new(config)
    local instance = setmetatable({}, self)
    instance.bases = {}
    instance.basePositions = config.basePositions  -- Get from MapConfig
    
    -- Create bases for each side
    for side, pos in pairs(instance.basePositions) do
        instance.bases[side] = {
            side = side,
            position = pos,
            health = BASE_MAX_HEALTH,
            maxHealth = BASE_MAX_HEALTH
        }
    end
    
    return instance
end

function ServerBaseManager:takeDamage(side, amount)
    local base = self.bases[side]
    if not base then return end
    
    base.health = math.max(0, base.health - amount)
    
    local update = {
        type = "baseTakeDamage",
        side = side,
        damage = amount,
        currentHealth = base.health
    }
    
    if base.health <= 0 then
        table.insert(updates, {
            type = "baseDestroyed",
            side = side
        })
    end
    
    return update
end

function ServerBaseManager:getBasePositions()
    return self.basePositions
end

return ServerBaseManager