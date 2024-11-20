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

    local particleCanvas = love.graphics.newCanvas(4, 4)
    love.graphics.setCanvas(particleCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, 4, 4)
    love.graphics.setCanvas() -- Reset canvas to default
    
    -- Create particle system using the canvas as the particle image
    instance.particleSystem = love.graphics.newParticleSystem(particleCanvas, 1000)
    instance.particleSystem:setParticleLifetime(0.5, 1.5)
    instance.particleSystem:setLinearAcceleration(-200, -200, 200, 200)
    instance.particleSystem:setColors(
        1, 1, 1, 1,    -- Start color (white)
        1, 0, 0, 1,    -- Mid color (red)
        0.3, 0, 0, 0   -- End color (dark red, fade to transparent)
    )
    instance.particleSystem:setSizes(2, 1, 0)
    instance.particleSystem:setSpeed(100, 300)
    instance.particleSystem:setEmissionArea("uniform", BASE_SIZE/2, BASE_SIZE/2)

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
    LOGGER.info("Base taking damage - Side:", side, "Amount:", amount, "Current Health:", currentHealth)
    
    local base = self.bases[side]
    if base then
        LOGGER.info("Previous health:", base.health, "New health:", currentHealth)
        base.health = currentHealth
        base.damageFlashTime = 0.1
        if currentHealth <= 0 and not base.destructionTimer then
            self:startBaseDestruction(side)
        end
    else
        LOGGER.error("No base found for side:", side)
    end
end

function ClientBaseManager:update(dt)
    self.particleSystem:update(dt)
    
    for side, base in pairs(self.bases) do
        if base.damageFlashTime > 0 then
            base.damageFlashTime = base.damageFlashTime - dt
        end
        
        -- Handle destruction animation
        if base.destructionTimer then
            base.destructionTimer = base.destructionTimer - dt
            base.opacity = base.destructionTimer / 2  -- 2-second fade out
            
            -- Add shake effect during destruction
            base.shake = math.sin(base.destructionTimer * 20) * 10 * (base.destructionTimer / 2)
            
            if base.destructionTimer <= 0 then
                base.destroyed = true
                base.destructionTimer = nil
            end
        end
    end
end


function ClientBaseManager:startBaseDestruction(side)
    local base = self.bases[side]
    if base then
        base.destructionTimer = 2  -- 2 seconds for destruction animation
        
        -- Emit a burst of particles
        self.particleSystem:setPosition(base.position.x, base.position.y)
        self.particleSystem:emit(500)
        
        -- You could play a sound here if you have sound effects
        -- love.audio.play(explosionSound)
    end
end

function ClientBaseManager:draw()
    -- Draw particles
    love.graphics.draw(self.particleSystem)
    
    for side, base in pairs(self.bases) do
        if not base.destroyed then
            -- Save current color
            local r, g, b, a = love.graphics.getColor()
            
            -- Calculate base position with shake effect
            local drawX = base.position.x + (base.shake or 0)
            local drawY = base.position.y + (base.shake or 0)
            
            -- Draw base with damage flash effect and opacity
            if base.damageFlashTime > 0 then
                love.graphics.setColor(1, 0, 0, base.opacity or 1)
            else
                if side == "left" then
                    love.graphics.setColor(0.2, 0.6, 0.8, base.opacity or 1)
                else
                    love.graphics.setColor(0.8, 0.2, 0.2, base.opacity or 1)
                end
            end
            
            -- Draw base
            love.graphics.rectangle("fill", 
                drawX - base.size/2,
                drawY - base.size/2,
                base.size, base.size)
            
            -- Draw health bar if base isn't being destroyed
            if not base.destructionTimer then
                local healthBarWidth = base.size
                local healthBarHeight = 16
                local healthPercentage = base.health / base.maxHealth
                
                -- Health bar background
                love.graphics.setColor(0.3, 0.3, 0.3, base.opacity or 1)
                love.graphics.rectangle("fill",
                    drawX - healthBarWidth/2,
                    drawY - base.size/2 - healthBarHeight - 10,
                    healthBarWidth, healthBarHeight)
                
                -- Health bar fill
                love.graphics.setColor(0.2, 0.8, 0.2, base.opacity or 1)
                love.graphics.rectangle("fill",
                    drawX - healthBarWidth/2,
                    drawY - base.size/2 - healthBarHeight - 10,
                    healthBarWidth * healthPercentage, healthBarHeight)
            end
            
            -- Restore color
            love.graphics.setColor(r, g, b, a)
        end
    end
end

return ClientBaseManager