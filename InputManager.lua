-- InputManager.lua
local M = {
    joysticks = {},    -- [playerIndex] = joystick object or nil
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
            for i = 1, 2 do
                if M.joysticks[i] == stick then 
                    M.joysticks[i] = nil 
                    -- print("InputManager: Removed joystick " .. stick:getID() .. " from player " .. i)
                end
            end
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
                    -- print("InputManager: Assigned joystick " .. stick:getID() .. " to player " .. i)
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

-- Update get to use keyboard config if assigned
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
        input.a = js:isGamepadDown("a")
        input.b = js:isGamepadDown("b")
        input.x = js:isGamepadDown("x")
        input.y = js:isGamepadDown("y")
        input.start = js:isGamepadDown("start")
        input.back = js:isGamepadDown("back")
        input.shoulderL = js:isGamepadDown("leftshoulder")
        input.shoulderR = js:isGamepadDown("rightshoulder")
    end
    -- Use keyboard config if assigned
    if GameInfo and GameInfo["p"..playerIndex.."InputType"] == "keyboard" then
        local kb = M.getKeyboardInput(playerIndex)
        -- Combine axes (favor nonzero, or sum if both pressed)
        local moveX = input.moveX ~= 0 and input.moveX or kb.moveX
        if input.moveX ~= 0 and kb.moveX ~= 0 then
            moveX = input.moveX + kb.moveX
            if moveX > 1 then moveX = 1 elseif moveX < -1 then moveX = -1 end
        end
        local moveY = input.moveY ~= 0 and input.moveY or kb.moveY
        if input.moveY ~= 0 and kb.moveY ~= 0 then
            moveY = input.moveY + kb.moveY
            if moveY > 1 then moveY = 1 elseif moveY < -1 then moveY = -1 end
        end
        input.moveX = moveX
        input.moveY = moveY
        input.a = input.a or kb.a
        input.b = input.b or kb.b
        input.x = input.x or kb.x
        input.y = input.y or kb.y
        input.start = input.start or kb.start
        input.back = input.back or kb.back
        input.shoulderL = input.shoulderL or kb.shoulderL
        input.shoulderR = input.shoulderR or kb.shoulderR
    end
    return input
end

-- Update getJoystick to never return nil for keyboard
function M.getJoystick(playerIndex)
    return M.joysticks[playerIndex]
end

-- Update hasController to always return true if either joystick or keyboard is assigned
function M.hasController(playerIndex)
    if GameInfo and GameInfo["p"..playerIndex.."InputType"] == "keyboard" then
        return true
    end
    return M.joysticks[playerIndex] ~= nil
end

-- Get keyboard mapping for display purposes
function M.getKeyboardMapping(playerIndex)
    return keyboardMaps[playerIndex]
end

return M 