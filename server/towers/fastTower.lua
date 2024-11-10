local ServerTower = require("towers.serverTower")

-- Server version
local FastServerTower = setmetatable({}, { __index = ServerTower })
FastServerTower.fireRate = 0.3
FastServerTower.damage = 5
FastServerTower.projectileSpeed = 1000
FastServerTower.cost = 150

return FastServerTower