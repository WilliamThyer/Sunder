-- InputManager.lua
local M = {
    joysticks = {},    -- [joystickID] = joystick object (changed from [playerIndex])
    deadzone  = 0.3,
    lastRefresh = 0,   -- Track when we last refreshed controller detection
    refreshInterval = 1.0, -- Check for new controllers every second
    keyboardEnabled = false, -- Whether keyboard input is enabled
    keyboardPlayer = nil, -- Which player (1 or 2) is using keyboard
}

-- Keyboard mappings for P1 (left) and P2 (right)
local keyboardMaps = {
    [1] = {
        left = "a", right = "d", up = "w", down = "s",
        a = "space", b = "lshift", x = "f", y = "g", start = "return", back = "lshift", shoulderL = "q", shoulderR = "e"
    },
    [2] = {
        left = "j", right = "l", up = "i", down = "k",
        a = ";", b = "rshift", x = "o", y = "p", start = "rctrl", back = "rshift", shoulderL = "u", shoulderR = "i"
    }
}

function M.initialize()
    M.refreshControllers()
    
    -- listen for hot-plugs
    love.handlers.joystickadded = function(_, stick)
        if stick then
            -- print("InputManager: joystickadded event received for joystick " .. stick:getID())
            M.refreshControllers()
        end
    end
    
    love.handlers.joystickremoved = function(_, stick)
        if stick then
            -- print("InputManager: joystickremoved event received for joystick " .. stick:getID())
            M.joysticks[stick:getID()] = nil
            -- print("InputManager: Removed joystick " .. stick:getID())
        end
    end
end

-- Get keyboard input for a given player (1 or 2)
function M.getKeyboardInput(playerIndex)
    local map = keyboardMaps[playerIndex]
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
    if not map then return input end
    if love.keyboard.isDown(map.left) then input.moveX = input.moveX - 1 end
    if love.keyboard.isDown(map.right) then input.moveX = input.moveX + 1 end
    if love.keyboard.isDown(map.up) then input.moveY = input.moveY - 1 end
    if love.keyboard.isDown(map.down) then input.moveY = input.moveY + 1 end
    if input.moveX ~= 0 and input.moveY ~= 0 then
        input.moveX = input.moveX * 0.707
        input.moveY = input.moveY * 0.707
    end
    input.a = love.keyboard.isDown(map.a)
    input.b = love.keyboard.isDown(map.b)
    input.x = love.keyboard.isDown(map.x)
    input.y = love.keyboard.isDown(map.y)
    input.start = love.keyboard.isDown(map.start)
    input.back = love.keyboard.isDown(map.back)
    input.shoulderL = love.keyboard.isDown(map.shoulderL)
    input.shoulderR = love.keyboard.isDown(map.shoulderR)
    return input
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
    
    -- Store joysticks by their ID instead of automatically assigning to player slots
    for _, stick in ipairs(allJoysticks) do
        M.joysticks[stick:getID()] = stick
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

-- Get input for a specific controller (by joystick ID or "keyboard")
function M.get(controllerID)
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
    
    if controllerID == "keyboard" then
        -- This shouldn't happen, but handle it gracefully
        return input
    end
    
    local js = M.joysticks[controllerID]
    if js then
        local lx, ly = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if math.abs(lx) > M.deadzone then input.moveX = lx end
        if math.abs(ly) > M.deadzone then input.moveY = ly end
        input.a = js:isGamepadDown("a")
        input.b = js:isGamepadDown("b")
        input.x = js:isGamepadDown("x")
        input.y = js:isGamepadDown("y")
        input.start = js:isGamepadDown("start")
        input.back = js:isGamepadDown("back")
        input.shoulderL = js:isGamepadDown("leftshoulder")
        input.shoulderR = js:isGamepadDown("rightshoulder")
    end
    
    return input
end

-- Get joystick object by ID
function M.getJoystick(joystickID)
    return M.joysticks[joystickID]
end

-- Check if a controller is available
function M.hasController(controllerID)
    if controllerID == "keyboard" then
        return true
    end
    return M.joysticks[controllerID] ~= nil
end

-- Get keyboard mapping for display purposes
function M.getKeyboardMapping(playerIndex)
    return keyboardMaps[playerIndex]
end

return M 