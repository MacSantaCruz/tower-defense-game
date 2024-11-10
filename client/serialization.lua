local Serialization = {}

function Serialization.serialize(value, seen)
    seen = seen or {}
    
    -- Handle cycles in tables
    if seen[value] then
        return "nil"
    end
    
    local valueType = type(value)
    
    if valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "table" then
        -- Remove the metatable check - we want to serialize the actual data
        seen[value] = true
        local parts = {"{"}
        
        -- Serialize array part
        local arraySize = #value
        for i = 1, arraySize do
            if i > 1 then
                table.insert(parts, ",")
            end
            table.insert(parts, Serialization.serialize(value[i], seen))
        end
        
        -- Serialize hash part
        for k, v in pairs(value) do
            if type(k) ~= "number" or k < 1 or k > arraySize then
                -- Skip any function values or metatables
                if type(v) ~= "function" and k ~= "__index" then
                    if #parts > 1 then
                        table.insert(parts, ",")
                    end
                    table.insert(parts, "[")
                    table.insert(parts, Serialization.serialize(k, seen))
                    table.insert(parts, "]=")
                    table.insert(parts, Serialization.serialize(v, seen))
                end
            end
        end
        
        table.insert(parts, "}")
        seen[value] = nil
        return table.concat(parts)
    end
    
    return "nil"
end

function Serialization.deserialize(str)
    -- First verify the string is safe
    if string.match(str, "^%s*return%s+{.*}%s*$") == nil then
        return nil, "Invalid serialized data format"
    end
    
    local fn, err = load(str)
    if not fn then
        return nil, "Failed to load serialized data: " .. (err or "unknown error")
    end
    
    local success, result = pcall(fn)
    if not success then
        return nil, "Failed to deserialize data: " .. (result or "unknown error")
    end
    
    return result
end

return Serialization