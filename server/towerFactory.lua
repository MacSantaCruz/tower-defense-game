local FastTower = require "./towers/fastTower"
local MechTower = require "./towers/mechTower"

local TowerFactory = {
    towerTypes = {
        fastTower = FastTower,
        mechTower = MechTower
    }
}

function TowerFactory:createTower(towerType, x, y, side, id)
    local TowerClass = self.towerTypes[towerType]
    if not TowerClass then return nil end
    
    local tower = TowerClass:new(x, y)
    tower.id = id
    tower.side = side
    tower.type = towerType
    
    return tower
end

return TowerFactory