local ClientBaseManager = {
    bases = {},
    basePositions = {
        left = nil,
        right = nil
    }
}
ClientBaseManager.__index = ClientBaseManager

local BASE_SIZE = 256

function ClientBaseManager:new(side)
    local instance = setmetatable({}, self)
    instance.bases = {}
    instance.basePositions = {
        left = nil,
        right = nil
    }
    return instance
end

function ClientBaseManager:initializeBases(positions)
    self.basePositions = positions
    
    -- Create bases for each side
    for side, pos in pairs(positions) do
        self.bases[side] = {
            side = side,
            position = pos,
            health = 1000,
            maxHealth = 1000,
            size = BASE_SIZE,
            destroyed = false,
            damageFlashTime = 0
        }
    end
end

function ClientBaseManager:takeDamage(side, amount, currentHealth)
    local base = self.bases[side]
    if base then
        base.health = currentHealth
        base.damageFlashTime = 0.1
    end
end

function ClientBaseManager:update(dt)
    for _, base in pairs(self.bases) do
        if base.damageFlashTime > 0 then
            base.damageFlashTime = base.damageFlashTime - dt
        end
    end
end

function ClientBaseManager:draw()
    for side, base in pairs(self.bases) do
        if not base.destroyed then
            -- Save current color
            local r, g, b, a = love.graphics.getColor()
            
            -- Draw base with damage flash effect
            if base.damageFlashTime > 0 then
                love.graphics.setColor(1, 0, 0, 1)
            else
                if side == "left" then
                    love.graphics.setColor(0.2, 0.6, 0.8, 1)
                else
                    love.graphics.setColor(0.8, 0.2, 0.2, 1)
                end
            end
            
            -- Draw larger base
            love.graphics.rectangle("fill", 
                base.position.x - base.size/2,
                base.position.y - base.size/2,
                base.size, base.size)
            
            -- Larger health bar to match base size
            local healthBarWidth = base.size
            local healthBarHeight = 16  -- Made health bar taller too
            local healthPercentage = base.health / base.maxHealth
            
            -- Health bar background
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill",
                base.position.x - healthBarWidth/2,
                base.position.y - base.size/2 - healthBarHeight - 10,  -- Moved up a bit more
                healthBarWidth, healthBarHeight)
            
            -- Health bar fill
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
            love.graphics.rectangle("fill",
                base.position.x - healthBarWidth/2,
                base.position.y - base.size/2 - healthBarHeight - 10,
                healthBarWidth * healthPercentage, healthBarHeight)
            
            -- Restore color
            love.graphics.setColor(r, g, b, a)
        end
    end
end

return ClientBaseManager