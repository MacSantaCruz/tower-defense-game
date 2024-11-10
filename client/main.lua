-- main.lua
local sti = require "sti"
local camera = require "camera"
local TowerManager = require "towerManager"
local FastEnemy = require "./enemies/fastEnemy"
local EnemyManager = require "enemyManager"
local PlayerManager = require "./playerManager"
local Network = require "network"
local logger = require('logger')

function love.load()
    _G.LOGGER = logger
    -- Initialize network connection
    local success = Network:init()
    if not success then
        LOGGER.error("Failed to initialize network!")
        return
    end

    -- Connect to server (could be localhost for testing or a remote server)
    local serverHost = "24.199.101.226"  -- Change this for remote server
    local serverPort = 12345
    
    success = Network:connect(serverHost, serverPort)
    if not success then
        LOGGER.error("Failed to connect to server!")
        return
    end

    -- Initialize player manager (now simplified as we're always a client)
    _G.playerManager = PlayerManager:new()

    -- Set window size
    love.window.setMode(1920, 1080, {
        resizable = false,
        vsync = true,
        minwidth = 1920,
        minheight = 1080
    })

    -- Load the map
    gameMap = sti("maps/kek_3.lua")
    if gameMap.layers["Paths"] then
        gameMap.layers["Paths"].visible = false
    end
    
    -- Window and map dimensions
    windowWidth = 1920
    windowHeight = 1080
    originalMapWidth = gameMap.width * gameMap.tilewidth
    worldWidth = originalMapWidth * 2
    worldHeight = gameMap.height * gameMap.tileheight
    tileSize = gameMap.tilewidth
    
    -- Initialize camera
    camera:load(worldWidth, worldHeight, windowWidth, windowHeight)

    -- Initialize game time
    gameTime = 0
    
    -- Create players (will be activated when server assigns sides)
    local playerConfig = {
        TowerManager = TowerManager,
        EnemyManager = EnemyManager,
        tileSize = tileSize,
        paths = walkwayPaths,
        gameMap = gameMap,
        mapWidth = originalMapWidth,
        spawnPoints = spawnPoints
    }

    playerManager:createPlayer("left", playerConfig)
    playerManager:createPlayer("right", playerConfig)
end

function love.update(dt)
    -- Update network state
    Network:update(dt)
    
    -- Only update game if we're connected
    if Network.connected then
        camera:update(dt)
        gameTime = gameTime + dt
        gameMap:update(dt)
        
        local leftPlayer = playerManager.players["left"]
        local rightPlayer = playerManager.players["right"]
        
        -- Update managers
        leftPlayer.enemyManager:update(dt)
        rightPlayer.enemyManager:update(dt)
        leftPlayer.towerManager:update(dt, camera, leftPlayer.enemyManager.enemies)
        rightPlayer.towerManager:update(dt, camera, rightPlayer.enemyManager.enemies)
    end
end

function love.draw()
    love.graphics.clear()

    -- World space drawing
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    
    local camX = math.floor(camera.x)
    local camY = math.floor(camera.y)
    
    -- Draw original map (left side)
    gameMap:draw(math.floor(-camX), math.floor(-camY), 1, 1)
    -- Draw mirrored map (right side)
    gameMap:draw(math.floor(-camX + originalMapWidth), math.floor(-camY), -1, 1)
    
    -- Draw dividing line
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(4)
    love.graphics.line(originalMapWidth, 0, originalMapWidth, worldHeight)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw game objects
    for _, player in pairs(playerManager.players) do
        player.towerManager:draw()
        player.enemyManager:draw()
    end
    
    
    love.graphics.pop()
    
    -- UI Elements
    love.graphics.print(string.format("Camera: %d, %d", camera.x, camera.y), 10, 10)
    
    -- Network status
    love.graphics.setColor(1, 1, 1, 1)
    local statusX = love.graphics.getWidth() - 200
    love.graphics.print("Network Status:", statusX, 10)
    
    -- Color-coded connection status
    if Network.connected then
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("Connected", statusX, 30)
    else
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print("Disconnected", statusX, 30)
    end
    
    -- Player side indicator
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Playing as: " .. (Network.playerSide or "unknown"), statusX, 50)
end

function love.mousepressed(x, y, button)
    if not Network.connected or not Network.playerSide then return end
    
    local worldX, worldY = camera:getWorldCoords(x, y)
    
    if button == 1 then
        local isLeftSide = worldX < originalMapWidth
        
        -- Check if player is trying to build on their side
        if (Network.playerSide == "left" and isLeftSide) or 
           (Network.playerSide == "right" and not isLeftSide) then
            
            local player = playerManager.players[Network.playerSide]
            if player and player.towerManager.selectedTowerType then
                -- Only check if placement would be valid locally
                local gridX = math.floor(worldX / tileSize) * tileSize + tileSize/2
                local gridY = math.floor(worldY / tileSize) * tileSize + tileSize/2
                local isValidPlacement = player.towerManager:isValidPlacement(gridX, gridY)

                if isValidPlacement then
                    LOGGER.info('Is Valid placement')
                    -- Only send to server, don't create tower yet
                    Network:sendTowerPlacement(worldX, worldY, player.towerManager.selectedTowerType)
                end
            end
        else
            LOGGER.info("Cannot build on opponent's side")
        end
    end
end

function love.keypressed(key)
    if not Network.connected or not Network.playerSide then return end
    
    local player = playerManager.players[Network.playerSide]
    if not player then return end
    
    -- Tower selection
    if key == "1" then
        player.towerManager:selectTowerType("fastTower")
    elseif key == "2" then
        player.towerManager:selectTowerType("mechTower")
    elseif key == "3" then
        -- Enemy spawning
        local targetSide = Network.playerSide == "left" and "right" or "left"
        Network:sendEnemySpawn(1, "fastEnemy", targetSide)
    end
end
