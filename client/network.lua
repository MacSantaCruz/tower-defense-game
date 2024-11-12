local socket = require "socket"
local Serialization = require "serialization"
local logger = require "logger"
local MessageHandlers = require "network.messageHandlers"
local MessageConstructors = require "network.messageConstructors"
local NetworkConstants = require "network.networkConstants"

local Network = {
    connected = false,
    socket = nil,
    gameState = {
        towers = {},
        enemies = {},
    },
    playerSide = nil
}

function Network:init()
    return true
end

function Network:connect(host, port)
    local client, err = socket.connect(host, port)
    if not client then
        LOGGER.error("Failed to connect:", err)
        return false
    end
    
    client:settimeout(0)
    self.socket = client
    self.connected = true
    LOGGER.info("Connected to server")
    return true
end

function Network:update(dt)
    if not self.connected then return end
    
    -- Receive updates from server
    local data, err = self.socket:receive()
    if data then
        self:handleServerMessage(data)
    elseif err == "closed" then
        self.connected = false
        LOGGER.info("Disconnected from server")
    end
end

function Network:handleServerMessage(message)
    local success, data = pcall(function()
        return Serialization.deserialize(message)
    end)

    if not success or not data then 
        LOGGER.error("Failed to deserialize message:", message)
        return 
    end

    local handler = MessageHandlers[data.type]
    if handler then
        local handlerSuccess, error = pcall(function()
            handler(self, data)
        end)
        
        if not handlerSuccess then
            LOGGER.error("Error in handler for " .. data.type .. ":", error)
        end
    else
        LOGGER.error("No handler found for message type:", data.type)
    end
end

function Network:placeTower(x, y, towerType)
    if not Network.connected then
        return false, "Not connected to server"
    end
    
    local message = MessageConstructors[NetworkConstants.CLIENT.PLACE_TOWER](x, y, towerType)
    LOGGER.info("Sending tower placement:", x, y, towerType)
    
    return Network:sendToServer(message)
end


function Network:spawnEnemy(spawnPointIndex, enemyType, targetSide)
    if not Network.connected then
        return false, "Not connected to server"
    end
    
    local message = MessageConstructors[NetworkConstants.CLIENT.SPAWN_ENEMY](
        spawnPointIndex,
        enemyType,
        targetSide
    )
    LOGGER.info("Sending enemy spawn:", enemyType, "at point", spawnPointIndex)
    
    return Network:sendToServer(message)
end

function Network:sendToServer(message)
    if not self.connected then return end
    
    local serialized = "return " .. Serialization.serialize(message)
    self.socket:send(serialized .. "\n")
end


return Network