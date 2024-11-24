local ServerTower = require("towers.serverTower")

-- Server version
local FastServerTower = setmetatable({}, { __index = ServerTower })
FastServerTower.fireRate = 0.3
FastServerTower.damage = 20
FastServerTower.projectileSpeed = 1000
FastServerTower.cost = 200

return FastServerTower