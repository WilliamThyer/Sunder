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

-- Custom mappings for each player (overrides default mappings)
local customMappings = {
    [1] = nil,  -- nil means use default, otherwise contains custom mapping
    [2] = nil
}

-- Default controller mappings (for reference)
local defaultControllerMappings = {
    a = "a",
    b = "b", 
    x = "x",
    y = "y",
    start = "start",
    back = "back",
    shoulderL = "leftshoulder",
    shoulderR = "rightshoulder"
}

-- Get the effective keyboard mapping for a player (custom or default)
function M.getEffectiveKeyboardMapping(playerIndex)
    if customMappings[playerIndex] then
        return customMappings[playerIndex]
    else
        return keyboardMaps[playerIndex]
    end
end

-- Set custom keyboard mapping for a player
function M.setCustomKeyboardMapping(playerIndex, mapping)
    customMappings[playerIndex] = mapping
end

-- Reset custom mapping for a player (use default)
function M.resetCustomKeyboardMapping(playerIndex)
    customMappings[playerIndex] = nil
end

-- Get custom mapping for a player (returns nil if using default)
function M.getCustomKeyboardMapping(playerIndex)
    return customMappings[playerIndex]
end

-- Check if a player has custom mapping
function M.hasCustomMapping(playerIndex)
    return customMappings[playerIndex] ~= nil
end

-- Custom controller mappings for each player
local customControllerMappings = {
    [1] = nil,  -- nil means use default, otherwise contains custom mapping
    [2] = nil
}

-- Get the effective controller mapping for a player (custom or default)
function M.getEffectiveControllerMapping(playerIndex)
    if customControllerMappings[playerIndex] then
        return customControllerMappings[playerIndex]
    else
        return defaultControllerMappings
    end
end

-- Set custom controller mapping for a player
function M.setCustomControllerMapping(playerIndex, mapping)
    customControllerMappings[playerIndex] = mapping
end

-- Reset custom controller mapping for a player (use default)
function M.resetCustomControllerMapping(playerIndex)
    customControllerMappings[playerIndex] = nil
end

-- Get custom controller mapping for a player (returns nil if using default)
function M.getCustomControllerMapping(playerIndex)
    return customControllerMappings[playerIndex]
end

-- Check if a player has custom controller mapping
function M.hasCustomControllerMapping(playerIndex)
    return customControllerMappings[playerIndex] ~= nil
end

-- Get all currently pressed buttons on a controller (for remapping)
function M.getPressedButtons(controllerID)
    local pressedButtons = {}
    local js = M.joysticks[controllerID]
    
    if js then
        -- Check all possible gamepad buttons
        local buttons = {"a", "b", "x", "y", "start", "back", "leftshoulder", "rightshoulder", "leftstick", "rightstick"}
        for _, button in ipairs(buttons) do
            if js:isGamepadDown(button) then
                table.insert(pressedButtons, button)
            end
        end
    end
    
    return pressedButtons
end

-- Get all currently pressed keys on keyboard (for remapping)
function M.getPressedKeys()
    local pressedKeys = {}
    local keys = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
                  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                  "space", "return", "escape", "tab", "lshift", "rshift", "lctrl", "rctrl", "lalt", "ralt",
                  "up", "down", "left", "right", "kp0", "kp1", "kp2", "kp3", "kp4", "kp5", "kp6", "kp7", "kp8", "kp9",
                  "kpenter", "kp+", "kp-", "kp*", "kp/", "kp.", "kp=",
                  "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"}
    
    for _, key in ipairs(keys) do
        if love.keyboard.isDown(key) then
            table.insert(pressedKeys, key)
        end
    end
    
    return pressedKeys
end

-- Get controller input with custom mapping support
function M.getControllerInput(controllerID, playerIndex)
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
    
    local js = M.joysticks[controllerID]
    if js then
        local lx, ly = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
        if math.abs(lx) > M.deadzone then input.moveX = lx end
        if math.abs(ly) > M.deadzone then input.moveY = ly end
        
        local mapping = M.getEffectiveControllerMapping(playerIndex)
        input.a = mapping.a and js:isGamepadDown(mapping.a)
        input.b = mapping.b and js:isGamepadDown(mapping.b)
        input.x = mapping.x and js:isGamepadDown(mapping.x)
        input.y = mapping.y and js:isGamepadDown(mapping.y)
        input.start = mapping.start and js:isGamepadDown(mapping.start)
        input.back = mapping.back and js:isGamepadDown(mapping.back)
        input.shoulderL = mapping.shoulderL and js:isGamepadDown(mapping.shoulderL)
        input.shoulderR = mapping.shoulderR and js:isGamepadDown(mapping.shoulderR)
    end
    
    return input
end

-- Check if a button/key is already mapped to another action
function M.isButtonAlreadyMapped(playerIndex, inputType, newButton, excludeAction)
    local mapping = nil
    
    if inputType == "keyboard" then
        mapping = M.getEffectiveKeyboardMapping(playerIndex)
    else
        mapping = M.getEffectiveControllerMapping(playerIndex)
    end
    
    if not mapping then return false end
    
    for actionKey, mappedButton in pairs(mapping) do
        if actionKey ~= excludeAction and mappedButton == newButton then
            return true
        end
    end
    
    return false
end



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
    local map = M.getEffectiveKeyboardMapping(playerIndex)
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
    if map.left and love.keyboard.isDown(map.left) then input.moveX = input.moveX - 1 end
    if map.right and love.keyboard.isDown(map.right) then input.moveX = input.moveX + 1 end
    if map.up and love.keyboard.isDown(map.up) then input.moveY = input.moveY - 1 end
    if map.down and love.keyboard.isDown(map.down) then input.moveY = input.moveY + 1 end
    if input.moveX ~= 0 and input.moveY ~= 0 then
        input.moveX = input.moveX * 0.707
        input.moveY = input.moveY * 0.707
    end
    input.a = map.a and love.keyboard.isDown(map.a)
    input.b = map.b and love.keyboard.isDown(map.b)
    input.x = map.x and love.keyboard.isDown(map.x)
    input.y = map.y and love.keyboard.isDown(map.y)
    input.start = map.start and love.keyboard.isDown(map.start)
    input.back = map.back and love.keyboard.isDown(map.back)
    input.shoulderL = map.shoulderL and love.keyboard.isDown(map.shoulderL)
    input.shoulderR = map.shoulderR and love.keyboard.isDown(map.shoulderR)
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
function M.get(controllerID, playerIndex)
    if controllerID == "keyboard" then
        -- This shouldn't happen, but handle it gracefully
        return {
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
    end
    
    -- Use default player index if not provided (for backward compatibility)
    playerIndex = playerIndex or 1
    return M.getControllerInput(controllerID, playerIndex)
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
    return M.getEffectiveKeyboardMapping(playerIndex)
end

return M 