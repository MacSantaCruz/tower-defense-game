local FastTower = require "towers.fastTower"
local MechTower = require "towers.mechTower"

local TowerFactory = {
    towerTypes = {
        fastTower = FastTower,
        mechTower = MechTower
    }
}

function TowerFactory:createTower(data)
    local TowerClass = self.towerTypes[data.type]
    if not TowerClass then return nil end
    
    local tower = TowerClass:new(data.x, data.y)
    tower.id = data.id
    tower.side = data.side
    
    return tower
end

return TowerFactory
