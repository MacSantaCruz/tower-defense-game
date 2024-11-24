local logger = require "logger"

local PathManager = {
    paths = {
        left = {},
        right = {}
    }
}

function PathManager:new(config)
    local manager = setmetatable({}, { __index = self })
    manager.tileSize = config.tileSize
    manager.width = config.width
    manager.originalWidth = config.originalWidth
    return manager
end

-- Convert a polyline's points to absolute coordinates
function PathManager:convertPolylineToAbsolute(object)
    local points = {}
    -- In Tiled, polyline points are stored as an array of {x=x, y=y} tables
    for _, point in ipairs(object.polyline) do
        table.insert(points, {
            x = object.x + point.x,
            y = object.y + point.y
        })
    end
    return points
end

function PathManager:mirrorPath(points)
    local mirroredPoints = {}
    local centerX = self.originalWidth * self.tileSize
    
    for _, point in ipairs(points) do
        table.insert(mirroredPoints, {
            x = (2 * centerX) - point.x,
            y = point.y
        })
    end
    
    return mirroredPoints
end

function PathManager:setupPaths(mapData)
    print("Setting up paths...")
    for _, layer in ipairs(mapData.layers) do
        print("Checking layer:", layer.name, "type:", layer.type)
        if layer.type == "objectgroup" and layer.name == "EnemyPaths" then
            for _, object in ipairs(layer.objects) do
                print("Found object:", object.name or "unnamed")
                if object.polyline then
                    print("Has polyline with", #object.polyline, "points")
                    if object.properties and object.properties.pathId then
                        print("PathId:", object.properties.pathId)
                        local pathId = object.properties.pathId
                        local points = self:convertPolylineToAbsolute(object)
                        print("Converted to", #points, "absolute points")
                        
                        -- Print first and last point for verification
                        if #points > 0 then
                            print("First point:", points[1].x, points[1].y)
                            print("Last point:", points[#points].x, points[#points].y)
                        end
                        
                        self.paths.left[pathId] = points
                        self.paths.right[pathId] = self:mirrorPath(points)
                    else
                        print("Warning: Polyline found without pathId property")
                    end
                end
            end
        end
    end
end

-- Helper function to get the next point on the path
function PathManager:getNextPathPoint(enemy)
    local path = self.paths[enemy.side][enemy.pathId]
    if not path then return nil end
    
    -- If enemy doesn't have a current target point, set it to the first point
    if not enemy.currentPathIndex then
        enemy.currentPathIndex = 1
    end
    
    return path[enemy.currentPathIndex]
end

-- Function to check if enemy has reached current target point
function PathManager:hasReachedPoint(enemy, point, threshold)
    threshold = threshold or 2 -- Allow small distance threshold
    local dx = enemy.x - point.x
    local dy = enemy.y - point.y
    return (dx * dx + dy * dy) <= threshold * threshold
end

-- Update enemy movement along path
function PathManager:updateEnemyMovement(enemy, dt)
    local targetPoint = self:getNextPathPoint(enemy)
    if not targetPoint then return 0, 0 end

    -- If reached current point, move to next point
    if self:hasReachedPoint(enemy, targetPoint) then
        enemy.currentPathIndex = enemy.currentPathIndex + 1
        targetPoint = self:getNextPathPoint(enemy)
        if not targetPoint then return 0, 0 end
    end
    
    -- Calculate direction to next point
    local dx = targetPoint.x - enemy.x
    local dy = targetPoint.y - enemy.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 0.001 then
        return 0, 0
    end
    
    -- Normalize direction and apply speed with fixed time step
    local moveSpeed = enemy.speed * dt
    if moveSpeed > distance then
        moveSpeed = distance
    end
    
    local moveX = (dx / distance) * moveSpeed
    local moveY = (dy / distance) * moveSpeed
    
    return moveX, moveY
end

return PathManager