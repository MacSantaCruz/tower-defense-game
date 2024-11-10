local ServerTower = require("towers.serverTower")


-- Server version
local MechServerTower = setmetatable({}, { __index = ServerTower })
MechServerTower.fireRate = 1.5
MechServerTower.damage = 20
MechServerTower.projectileSpeed = 500
MechServerTower.cost = 200

return MechServerTower