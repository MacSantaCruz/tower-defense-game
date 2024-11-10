-- logger.lua
local logger = {}

local active_loggers = {}

-- Helper function to concatenate multiple arguments into a single string
local function concatenateArgs(...)
    local args = {...}
    local parts = {}
    for i, arg in ipairs(args) do
        parts[i] = tostring(arg)
    end
    return table.concat(parts, " ")
end

-- Create a new logger instance for a specific client
function logger.createLogger(client_id)
    local instance = {}
    
    
    -- Initialize the log file with timestamp and client ID
    local date = os.date("%Y%m%d_%H%M%S")
    
    -- Log levels
    instance.LEVELS = {
        DEBUG = "DEBUG",
        INFO = "INFO",
        WARNING = "WARNING",
        ERROR = "ERROR"
    }
    
    -- Write a message to this client's log file
    function instance.log(level, ...)
        local message
        if select('#', ...) == 0 then
            message = level
            level = instance.LEVELS.INFO
        else
            message = concatenateArgs(...)
        end
        
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local log_entry = string.format("[%s] [Server: %s] [%s] %s\n", 
            timestamp, client_id, level, message)
        
        print(log_entry)
    end
    
    -- Convenience methods
    function instance.debug(...)
        instance.log(instance.LEVELS.DEBUG, ...)
    end
    
    function instance.info(...)
        instance.log(instance.LEVELS.INFO, ...)
    end
    
    function instance.warning(...)
        instance.log(instance.LEVELS.WARNING, ...)
    end
    
    function instance.error(...)
        instance.log(instance.LEVELS.ERROR, ...)
    end
    
    -- Get the full path to this client's log file
    function instance.getLogPath()
        return log_path
    end
    
    -- Store the logger instance
    active_loggers[client_id] = instance
    
    -- Log initial creation
    instance.info("Logger initialized")
    
    return instance
end

-- Create default system logger
local system_logger = logger.createLogger("system")

-- Expose system logger methods at the top level
logger.log = function(...) system_logger.log(...) end
logger.debug = function(...) system_logger.debug(...) end
logger.info = function(...) system_logger.info(...) end
logger.warning = function(...) system_logger.warning(...) end
logger.error = function(...) system_logger.error(...) end
logger.getLogPath = function() return system_logger.getLogPath() end

return logger