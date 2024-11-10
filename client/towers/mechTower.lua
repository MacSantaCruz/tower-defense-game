local ClientTower = require("towers.clientTower")

-- Client version
local MechClientTower = setmetatable({}, { __index = ClientTower })
MechClientTower.fireRate = 1.5
MechClientTower.projectileSpeed = 500
MechClientTower.color = {0, 0.8, 1, 1}
MechClientTower.sprite = love.graphics.newImage("images/towers/mech_tower.png")
MechClientTower.frameDelay = 0.15
MechClientTower:setupAnimation(4)

return MechClientTower
