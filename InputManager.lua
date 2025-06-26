-- InputManager.lua
local M = {
    joysticks = {},    -- [playerIndex] = joystick object or nil
    deadzone  = 0.3,
    lastRefresh = 0,   -- Track when we last refreshed controller detection
    refreshInterval = 1.0, -- Check for new controllers every second
}

function M.initialize()
    M.refreshControllers()
    
    -- listen for hot-plugs
    love.handlers.joystickadded = function(_, stick)
        if stick then
            print("InputManager: joystickadded event received for joystick " .. stick:getID())
            M.refreshControllers()
        end
    end
    
    love.handlers.joystickremoved = function(_, stick)
        if stick then
            print("InputManager: joystickremoved event received for joystick " .. stick:getID())
            for i = 1, 2 do
                if M.joysticks[i] == stick then 
                    M.joysticks[i] = nil 
                    print("InputManager: Removed joystick " .. stick:getID() .. " from player " .. i)
                end
            end
        end
    end
end

-- Refresh controller detection - can be called manually or periodically
function M.refreshControllers()
    local currentTime = love.timer.getTime()
    
    -- Only refresh if enough time has passed to avoid excessive checking
    if currentTime - M.lastRefresh < M.refreshInterval then
        return
    end
    
    M.lastRefresh = currentTime
    
    -- Get all currently connected joysticks
    local allJoysticks = love.joystick.getJoysticks()
    
    -- Check for any new joysticks that aren't already assigned
    for _, stick in ipairs(allJoysticks) do
        local alreadyAssigned = false
        for i = 1, 2 do
            if M.joysticks[i] == stick then
                alreadyAssigned = true
                break
            end
        end
        
        -- If this joystick isn't assigned, assign it to the first available slot
        if not alreadyAssigned then
            for i = 1, 2 do
                if not M.joysticks[i] then
                    M.joysticks[i] = stick
                    print("InputManager: Assigned joystick " .. stick:getID() .. " to player " .. i)
                    break
                end
            end
        end
    end
end

-- Manual refresh function for immediate controller detection
function M.refreshControllersImmediate()
    M.lastRefresh = 0  -- Force immediate refresh
    M.refreshControllers()
end

-- Update function to be called each frame for periodic checking
function M.update(dt)
    M.refreshControllers()
end

-- Read normalized axes & buttons
function M.get(playerIndex)
    local js = M.joysticks[playerIndex]
    local input = {
        moveX  = 0,
        moveY  = 0,
        a      = false,
        b      = false,
        x      = false,
        y      = false,
        start  = false,
        back   = false,
        shoulderL = false,
        shoulderR = false,
    }
    
    if js then
        local lx, ly = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if math.abs(lx) > M.deadzone then input.moveX = lx end
        if math.abs(ly) > M.deadzone then input.moveY = ly end
        
        -- Direct button mapping
        input.a = js:isGamepadDown("a")
        input.b = js:isGamepadDown("b")
        input.x = js:isGamepadDown("x")
        input.y = js:isGamepadDown("y")
        input.start = js:isGamepadDown("start")
        input.back = js:isGamepadDown("back")
        input.shoulderL = js:isGamepadDown("leftshoulder")
        input.shoulderR = js:isGamepadDown("rightshoulder")
        
        -- Debug: print button presses
        if input.a or input.b or input.x or input.y or input.start or input.back or input.shoulderL or input.shoulderR then
            print("InputManager: Player " .. playerIndex .. " pressed buttons - A:" .. tostring(input.a) .. " B:" .. tostring(input.b) .. " X:" .. tostring(input.x) .. " Y:" .. tostring(input.y))
        end
    end
    
    return input
end

-- Get the joystick object for a player (useful for edge detection)
function M.getJoystick(playerIndex)
    return M.joysticks[playerIndex]
end

-- Check if a player has a controller connected
function M.hasController(playerIndex)
    return M.joysticks[playerIndex] ~= nil
end

return M 