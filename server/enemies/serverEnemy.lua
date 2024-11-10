-- enemy.lua
local Enemy = {
    -- Default properties
    health = 100,
    maxHealth = 100,
    speed = 50,
    armor = 0,
    value = 10,  -- Money gained when killed
    
    -- Movement properties
    x = 0,
    y = 0,
    direction = 0,

    -- Collission related
    radius = 16,  -- Half of the 32px sprite size
    dead = false  -- Track if enemy is destroyed
}

function Enemy:new(x, y, properties)
    local enemy = properties or {}
    setmetatable(enemy, self)
    self.__index = self
    
    enemy.x = x or 0
    enemy.y = y or 0
    enemy.health = enemy.maxHealth
    enemy.id = nil
    
    return enemy
end

function Enemy:takeDamage(amount)
    -- Apply armor reduction if you want
    local damage = amount * (1 - self.armor/100)
    self.health = self.health - damage
    self.dead = self.health <= 0
    return self.dead
end

return Enemy