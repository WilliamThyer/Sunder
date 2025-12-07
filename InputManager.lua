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

-- Custom mappings storage
-- customKeyboardMappings[playerIndex] = {action = key, ...}
-- customGamepadMappings[playerIndex] = {action = button, ...}
local customKeyboardMappings = {}
local customGamepadMappings = {}

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
-- useMenuDefaults: if true, always use default mappings (for menu navigation)
--                  if false or nil, use custom mappings if they exist, otherwise defaults (for gameplay)
function M.getKeyboardInput(playerIndex, useMenuDefaults)
    -- Determine which mapping to use
    local map = keyboardMaps[playerIndex]
    if not map then
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
        return input
    end
    
    -- If useMenuDefaults is true, always use default mapping
    -- Otherwise, check for custom mapping first
    local customMap = nil
    if not useMenuDefaults then
        customMap = customKeyboardMappings[playerIndex]
    end
    
    -- Build the effective mapping: custom if available and not using menu defaults, otherwise default
    local effectiveMap = {}
    if customMap and not useMenuDefaults then
        -- Use custom mapping, but need to reverse it: action -> key
        -- We need to map from actions back to the input structure
        -- For now, we'll use a hybrid approach: check custom mapping for actions, fall back to defaults for menu buttons
        effectiveMap = map  -- Start with defaults
        -- Override with custom mappings for game actions
        -- But we need to know which key maps to which action
        -- This is complex, so we'll handle it differently in the input reading below
    else
        effectiveMap = map
    end
    
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
    
    -- Read input using effective mapping
    -- For menu navigation (useMenuDefaults = true), always use default map
    -- For gameplay (useMenuDefaults = false/nil), use custom if available
    local activeMap = map
    if customMap and not useMenuDefaults then
        -- We need to reverse the custom mapping: action -> key to key -> action
        -- Create a reverse lookup
        local reverseMap = {}
        for action, key in pairs(customMap) do
            reverseMap[key] = action
        end
        -- Now check which keys are pressed and map them to actions
        -- But we still need the default map structure for menu buttons (start, back, up, down)
        -- So we'll check both
        
        -- Check custom mapped keys
        for action, key in pairs(customMap) do
            -- Skip empty string mappings (explicitly cleared actions)
            if key ~= "" and love.keyboard.isDown(key) then
                if action == "lightAttack" then input.a = true
                elseif action == "heavyAttack" then input.b = true
                elseif action == "counter" then input.y = true
                elseif action == "shield" then input.shoulderL = true
                elseif action == "dash" then input.shoulderR = true
                elseif action == "jump" then input.x = true
                elseif action == "moveLeft" then input.moveX = input.moveX - 1
                elseif action == "moveRight" then input.moveX = input.moveX + 1
                end
            end
        end
        
        -- Always use defaults for menu navigation buttons (start, back, up, down)
        if love.keyboard.isDown(map.start) then input.start = true end
        if love.keyboard.isDown(map.back) then input.back = true end
        if love.keyboard.isDown(map.up) then input.moveY = input.moveY - 1 end
        if love.keyboard.isDown(map.down) then input.moveY = input.moveY + 1 end
        
        -- Also check default movement keys if not remapped (or if remapped to empty string)
        if not customMap.moveLeft or customMap.moveLeft == "" then
            if love.keyboard.isDown(map.left) then
                input.moveX = input.moveX - 1
            end
        end
        if not customMap.moveRight or customMap.moveRight == "" then
            if love.keyboard.isDown(map.right) then
                input.moveX = input.moveX + 1
            end
        end
    else
        -- Use default mapping
        activeMap = map
        if love.keyboard.isDown(activeMap.left) then input.moveX = input.moveX - 1 end
        if love.keyboard.isDown(activeMap.right) then input.moveX = input.moveX + 1 end
        if love.keyboard.isDown(activeMap.up) then input.moveY = input.moveY - 1 end
        if love.keyboard.isDown(activeMap.down) then input.moveY = input.moveY + 1 end
        input.a = love.keyboard.isDown(activeMap.a)
        input.b = love.keyboard.isDown(activeMap.b)
        input.x = love.keyboard.isDown(activeMap.x)
        input.y = love.keyboard.isDown(activeMap.y)
        input.start = love.keyboard.isDown(activeMap.start)
        input.back = love.keyboard.isDown(activeMap.back)
        input.shoulderL = love.keyboard.isDown(activeMap.shoulderL)
        input.shoulderR = love.keyboard.isDown(activeMap.shoulderR)
    end
    
    if input.moveX ~= 0 and input.moveY ~= 0 then
        input.moveX = input.moveX * 0.707
        input.moveY = input.moveY * 0.707
    end
    
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
-- useMenuDefaults: if true, always use default mappings (for menu navigation)
--                  if false or nil, use custom mappings if they exist, otherwise defaults (for gameplay)
function M.get(controllerID, useMenuDefaults)
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
    if not js then
        return input
    end
    
    -- Determine which player this controller belongs to (for custom mapping lookup)
    -- We need to check GameInfo to find which player uses this controller
    local playerIndex = nil
    if GameInfo then
        if GameInfo.player1Controller == controllerID then
            playerIndex = 1
        elseif GameInfo.player2Controller == controllerID then
            playerIndex = 2
        end
    end
    
    -- Get custom mapping if available and not using menu defaults
    local customMap = nil
    if playerIndex and not useMenuDefaults then
        customMap = customGamepadMappings[playerIndex]
    end
    
    -- Read raw gamepad input
    local lx, ly = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
    local rawButtons = {
        a = js:isGamepadDown("a"),
        b = js:isGamepadDown("b"),
        x = js:isGamepadDown("x"),
        y = js:isGamepadDown("y"),
        start = js:isGamepadDown("start"),
        back = js:isGamepadDown("back"),
        shoulderL = js:isGamepadDown("leftshoulder"),
        shoulderR = js:isGamepadDown("rightshoulder"),
        left = lx < -M.deadzone,
        right = lx > M.deadzone,
        up = ly < -M.deadzone,
        down = ly > M.deadzone
    }
    
    -- Apply custom mapping if available and not using menu defaults
    if customMap and not useMenuDefaults then
        -- Map custom actions to input structure
        for action, button in pairs(customMap) do
            -- Skip empty string mappings (explicitly cleared actions)
            if button ~= "" and rawButtons[button] then
                if action == "lightAttack" then input.a = true
                elseif action == "heavyAttack" then input.b = true
                elseif action == "counter" then input.y = true
                elseif action == "shield" then input.shoulderL = true
                elseif action == "dash" then input.shoulderR = true
                elseif action == "jump" then input.x = true
                elseif action == "moveLeft" then
                    if math.abs(lx) > M.deadzone and lx < 0 then
                        input.moveX = lx
                    end
                elseif action == "moveRight" then
                    if math.abs(lx) > M.deadzone and lx > 0 then
                        input.moveX = lx
                    end
                end
            end
        end
        
        -- Always use defaults for menu navigation buttons (start, back, up, down)
        input.start = rawButtons.start
        input.back = rawButtons.back
        if rawButtons.up then input.moveY = input.moveY - 1 end
        if rawButtons.down then input.moveY = input.moveY + 1 end
        
        -- Also check default movement if not remapped (or if remapped to empty string)
        if (not customMap.moveLeft or customMap.moveLeft == "") and rawButtons.left then
            input.moveX = lx
        end
        if (not customMap.moveRight or customMap.moveRight == "") and rawButtons.right then
            input.moveX = lx
        end
    else
        -- Use default mapping
        if math.abs(lx) > M.deadzone then input.moveX = lx end
        if math.abs(ly) > M.deadzone then input.moveY = ly end
        input.a = rawButtons.a
        input.b = rawButtons.b
        input.x = rawButtons.x
        input.y = rawButtons.y
        input.start = rawButtons.start
        input.back = rawButtons.back
        input.shoulderL = rawButtons.shoulderL
        input.shoulderR = rawButtons.shoulderR
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

-- Get default keyboard mapping
function M.getDefaultKeyboardMapping(playerIndex)
    return keyboardMaps[playerIndex]
end

-- Get default gamepad mapping structure
function M.getDefaultGamepadMapping()
    return {
        lightAttack = "a",
        heavyAttack = "b",
        counter = "y",
        shield = "shoulderL",
        dash = "shoulderR",
        jump = "x",
        moveLeft = "left",
        moveRight = "right"
    }
end

-- Get custom keyboard mapping
function M.getCustomKeyboardMapping(playerIndex)
    return customKeyboardMappings[playerIndex]
end

-- Set custom keyboard mapping
function M.setCustomKeyboardMapping(playerIndex, mapping)
    customKeyboardMappings[playerIndex] = mapping
end

-- Get custom gamepad mapping
function M.getCustomGamepadMapping(playerIndex)
    return customGamepadMappings[playerIndex]
end

-- Set custom gamepad mapping
function M.setCustomGamepadMapping(playerIndex, mapping)
    customGamepadMappings[playerIndex] = mapping
end

-- Get button display name for remap menu
-- action: the action name (e.g., "lightAttack", "heavyAttack")
-- isKeyboard: true for keyboard, false for gamepad
-- playerIndex: player index (1 or 2)
function M.getButtonDisplayName(action, isKeyboard, playerIndex)
    local currentMapping = nil
    
    if isKeyboard then
        -- Check for custom mapping first
        local customMap = customKeyboardMappings[playerIndex]
        if customMap and customMap[action] then
            -- If it's an empty string, that means it was explicitly cleared
            if customMap[action] == "" then
                currentMapping = nil  -- Will return "None"
            else
                currentMapping = customMap[action]
            end
        else
            -- Use default mapping
            local defaultMap = keyboardMaps[playerIndex]
            if defaultMap then
                -- Map action to default key
                if action == "lightAttack" then currentMapping = defaultMap.a
                elseif action == "heavyAttack" then currentMapping = defaultMap.b
                elseif action == "counter" then currentMapping = defaultMap.y
                elseif action == "shield" then currentMapping = defaultMap.shoulderL
                elseif action == "dash" then currentMapping = defaultMap.shoulderR
                elseif action == "jump" then currentMapping = defaultMap.x
                elseif action == "moveLeft" then currentMapping = defaultMap.left
                elseif action == "moveRight" then currentMapping = defaultMap.right
                end
            end
        end
        
        if currentMapping then
            -- Return readable key name
            local keyNames = {
                space = "Space",
                lshift = "LShift",
                rshift = "RShift",
                f = "F",
                g = "G",
                ["return"] = "Enter",
                rctrl = "RCtrl",
                q = "Q",
                e = "E",
                a = "A",
                d = "D",
                w = "W",
                s = "S",
                j = "J",
                l = "L",
                i = "I",
                k = "K",
                [";"] = ";",
                o = "O",
                p = "P",
                u = "U"
            }
            return keyNames[currentMapping] or string.upper(currentMapping)
        end
        return "None"
    else
        -- Gamepad: check for custom mapping first
        local customMap = customGamepadMappings[playerIndex]
        if customMap and customMap[action] then
            -- If it's an empty string, that means it was explicitly cleared
            if customMap[action] == "" then
                currentMapping = nil  -- Will return "None"
            else
                currentMapping = customMap[action]
            end
        else
            -- Use default mapping
            if action == "lightAttack" then currentMapping = "a"
            elseif action == "heavyAttack" then currentMapping = "b"
            elseif action == "counter" then currentMapping = "y"
            elseif action == "shield" then currentMapping = "shoulderL"
            elseif action == "dash" then currentMapping = "shoulderR"
            elseif action == "jump" then currentMapping = "x"
            elseif action == "moveLeft" then currentMapping = "left"
            elseif action == "moveRight" then currentMapping = "right"
            end
        end
        
        if currentMapping then
            -- Return readable button name
            local buttonNames = {
                a = "A",
                b = "B",
                x = "X",
                y = "Y",
                start = "Start",
                back = "Back",
                shoulderL = "LB",
                shoulderR = "RB",
                left = "Left",
                right = "Right",
                up = "Up",
                down = "Down"
            }
            return buttonNames[currentMapping] or currentMapping
        end
        return "None"
    end
end

return M 