local ClientTower = require("towers.clientTower")

-- Client version
local FastClientTower = setmetatable({}, { __index = ClientTower })
FastClientTower.fireRate = 0.3
FastClientTower.projectileSpeed = 1000
FastClientTower.color = {0, 0.8, 1, 1}
FastClientTower.sprite = love.graphics.newImage("images/towers/idle/7.png")
FastClientTower.frameDelay = 0.15
FastClientTower.tilesWide = 2
FastClientTower.tilesHigh = 2
FastClientTower:setupAnimation(6)

return FastClientTower
