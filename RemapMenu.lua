-- RemapMenu.lua
local RemapMenu = {}

local InputManager = require("InputManager")
local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")

-- Action list for remapping
local actions = {
    "Light Attack",
    "Heavy Attack",
    "Counter",
    "Shield",
    "Dash",
    "Jump",
    "Move Left",
    "Move Right"
}

-- Map action names to action keys (for storage)
local actionKeys = {
    ["Light Attack"] = "lightAttack",
    ["Heavy Attack"] = "heavyAttack",
    ["Counter"] = "counter",
    ["Shield"] = "shield",
    ["Dash"] = "dash",
    ["Jump"] = "jump",
    ["Move Left"] = "moveLeft",
    ["Move Right"] = "moveRight"
}

-- Navigation cooldown
local moveCooldown = 0
local moveCooldownDuration = 0.25

-- Track previous button states for remapping
local lastButtonStates = {}
local lastKeyStates = {}
local lastStickLeft = false
local lastStickRight = false

-- Backup storage for custom mappings when entering the menu
local backupKeyboardMapping = nil
local backupGamepadMapping = nil
local backupInitialized = false

-- Helper function to deep copy a mapping table
local function copyMapping(mapping)
    if not mapping then
        return nil
    end
    local copy = {}
    for k, v in pairs(mapping) do
        copy[k] = v
    end
    return copy
end

-- Helper function to get all keyboard keys to check
local function getAllKeyboardKeys()
    return {
        -- Letters
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        -- Numbers
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        -- Special keys
        "space", "return", "escape", "backspace", "tab",
        "lshift", "rshift", "lctrl", "rctrl", "lalt", "ralt",
        "up", "down", "left", "right",
        "home", "end", "pageup", "pagedown",
        "insert", "delete",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
        -- Punctuation and symbols
        "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/"
    }
end

function RemapMenu.update(GameInfo)
    local dt = love.timer.getDelta()
    moveCooldown = math.max(0, moveCooldown - dt)
    
    local playerIndex = GameInfo.remapMenuPlayer
    if not playerIndex then
        return
    end
    
    -- Determine if player is using keyboard or gamepad
    local isKeyboard = false
    local controllerID = nil
    if GameInfo.p1InputType == "keyboard" and playerIndex == 1 then
        isKeyboard = true
    elseif GameInfo.p2InputType == "keyboard" and playerIndex == 2 then
        isKeyboard = true
    elseif playerIndex == 1 then
        controllerID = GameInfo.player1Controller
    elseif playerIndex == 2 then
        controllerID = GameInfo.player2Controller
    end
    
    -- Save backup of current mappings when first entering the menu
    if not backupInitialized then
        if isKeyboard then
            backupKeyboardMapping = copyMapping(InputManager.getCustomKeyboardMapping(playerIndex))
            -- Initialize all key states to current state (for proper edge detection)
            lastKeyStates = {}
            local allKeys = getAllKeyboardKeys()
            for _, keyName in ipairs(allKeys) do
                lastKeyStates[keyName] = love.keyboard.isDown(keyName)
            end
        else
            backupGamepadMapping = copyMapping(InputManager.getCustomGamepadMapping(playerIndex))
            -- Initialize button states to current state to prevent the button press that opened the menu from triggering remap
            lastButtonStates = {}
            lastStickLeft = false
            lastStickRight = false
            if controllerID then
                local js = InputManager.getJoystick(controllerID)
                if js then
                    lastButtonStates["a"] = js:isGamepadDown("a")
                    lastButtonStates["b"] = js:isGamepadDown("b")
                    lastButtonStates["x"] = js:isGamepadDown("x")
                    lastButtonStates["y"] = js:isGamepadDown("y")
                    lastButtonStates["shoulderL"] = js:isGamepadDown("leftshoulder")
                    lastButtonStates["shoulderR"] = js:isGamepadDown("rightshoulder")
                    -- Initialize stick states
                    local lx = js:getGamepadAxis("leftx")
                    lastStickLeft = (lx < -0.3)
                    lastStickRight = (lx > 0.3)
                end
            end
        end
        backupInitialized = true
    end
    
    -- If in remapping mode, check for key/button presses FIRST (before processing menu input)
    if GameInfo.remapMenuRemapping then
        local actionKey = actionKeys[GameInfo.remapMenuRemapping]
        if not actionKey then
            GameInfo.remapMenuRemapping = nil
            return
        end
        
        -- Check for any button/key press
        local pressedButton = nil
        local pressedKey = nil
        
        if isKeyboard then
            -- Check all possible keyboard keys (not just mapped ones)
            -- Allow remapping to ANY key, including menu navigation keys
            local allKeys = getAllKeyboardKeys()
            
            -- Check all keys for remapping (don't exclude any keys - user should be able to remap to anything)
            for _, keyName in ipairs(allKeys) do
                if love.keyboard.isDown(keyName) and not (lastKeyStates[keyName] or false) then
                    pressedKey = keyName
                    break
                end
            end
        else
            -- Check all gamepad buttons
            if controllerID then
                local js = InputManager.getJoystick(controllerID)
                if js then
                    -- Check all buttons except menu navigation
                    local buttons = {"a", "b", "x", "y", "leftshoulder", "rightshoulder"}
                    for _, button in ipairs(buttons) do
                        if js:isGamepadDown(button) then
                            -- Convert to our button names
                            local buttonName = button
                            if button == "leftshoulder" then buttonName = "shoulderL"
                            elseif button == "rightshoulder" then buttonName = "shoulderR"
                            end
                            
                            -- Check if this button was just pressed
                            local wasDown = lastButtonStates[buttonName] or false
                            if not wasDown then
                                pressedButton = buttonName
                                break
                            end
                        end
                    end
                    
                    -- Also check stick movement for left/right (with edge detection)
                    local lx = js:getGamepadAxis("leftx")
                    local stickLeft = (lx < -0.3)
                    local stickRight = (lx > 0.3)
                    
                    if stickLeft and not lastStickLeft then
                        pressedButton = "left"
                    elseif stickRight and not lastStickRight then
                        pressedButton = "right"
                    end
                    
                    lastStickLeft = stickLeft
                    lastStickRight = stickRight
                end
            end
        end
        
        -- Update last button/key states
        if isKeyboard then
            -- Track all possible keyboard keys for proper edge detection
            local allKeys = getAllKeyboardKeys()
            for _, keyName in ipairs(allKeys) do
                lastKeyStates[keyName] = love.keyboard.isDown(keyName)
            end
        else
            if controllerID then
                local js = InputManager.getJoystick(controllerID)
                if js then
                    lastButtonStates["a"] = js:isGamepadDown("a")
                    lastButtonStates["b"] = js:isGamepadDown("b")
                    lastButtonStates["x"] = js:isGamepadDown("x")
                    lastButtonStates["y"] = js:isGamepadDown("y")
                    lastButtonStates["shoulderL"] = js:isGamepadDown("leftshoulder")
                    lastButtonStates["shoulderR"] = js:isGamepadDown("rightshoulder")
                end
            end
        end
        
        -- If a button/key was pressed, map it (check this FIRST so users can remap to any key, including back)
        if pressedButton or pressedKey then
            -- Get current custom mapping or create new one
            local customMap = nil
            if isKeyboard then
                customMap = InputManager.getCustomKeyboardMapping(playerIndex) or {}
            else
                customMap = InputManager.getCustomGamepadMapping(playerIndex) or {}
            end
            
            -- Get the button/key that was pressed
            local pressedInput = pressedButton or pressedKey
            
            -- Unmap this button/key from any other action in customMap (clear any action that currently uses this button/key)
            -- Skip the action we're currently remapping - we'll set it to the pressed input below
            for otherAction, mappedInput in pairs(customMap) do
                if mappedInput == pressedInput and otherAction ~= actionKey then
                    customMap[otherAction] = ""  -- Set to empty string to mark as explicitly cleared (not reset to default)
                end
            end
            
            -- Also check default mappings - if a default action uses this button/key, override it to ""
            if isKeyboard then
                -- For keyboard, we need to reverse lookup: find which input key (a, b, x, etc.) maps to this keyboard key
                local defaultKeyboardMap = InputManager.getDefaultKeyboardMapping(GameInfo.p1KeyboardMapping or (playerIndex == 1 and 1 or 2))
                if defaultKeyboardMap then
                    -- Reverse lookup: find which input key uses this keyboard key
                    for inputKey, keyboardKey in pairs(defaultKeyboardMap) do
                        if keyboardKey == pressedInput then
                            -- Now find which action uses this input key by default
                            -- Only override if it's not already in customMap (meaning it's using the default)
                            -- and it's not the action we're currently remapping
                            if inputKey == "a" then
                                if not customMap.lightAttack and actionKey ~= "lightAttack" then
                                    customMap.lightAttack = ""  -- Override default
                                end
                            elseif inputKey == "b" then
                                if not customMap.heavyAttack and actionKey ~= "heavyAttack" then
                                    customMap.heavyAttack = ""  -- Override default
                                end
                            elseif inputKey == "x" then
                                if not customMap.jump and actionKey ~= "jump" then
                                    customMap.jump = ""  -- Override default
                                end
                            elseif inputKey == "y" then
                                if not customMap.counter and actionKey ~= "counter" then
                                    customMap.counter = ""  -- Override default
                                end
                            elseif inputKey == "shoulderL" then
                                if not customMap.shield and actionKey ~= "shield" then
                                    customMap.shield = ""  -- Override default
                                end
                            elseif inputKey == "shoulderR" then
                                if not customMap.dash and actionKey ~= "dash" then
                                    customMap.dash = ""  -- Override default
                                end
                            elseif inputKey == "left" then
                                if not customMap.moveLeft and actionKey ~= "moveLeft" then
                                    customMap.moveLeft = ""  -- Override default
                                end
                            elseif inputKey == "right" then
                                if not customMap.moveRight and actionKey ~= "moveRight" then
                                    customMap.moveRight = ""  -- Override default
                                end
                            end
                        end
                    end
                end
            else
                -- For gamepad, check default gamepad mapping directly
                local defaultGamepadMap = InputManager.getDefaultGamepadMapping()
                if defaultGamepadMap then
                    for defaultAction, defaultButton in pairs(defaultGamepadMap) do
                        if defaultButton == pressedInput then
                            -- This default action uses the pressed button, so override it
                            -- Only override if it's not already in customMap (meaning it's using the default)
                            -- and it's not the action we're currently remapping
                            if not customMap[defaultAction] and defaultAction ~= actionKey then
                                customMap[defaultAction] = ""  -- Override default
                            end
                        end
                    end
                end
            end
            
            -- Map the button/key to this action
            customMap[actionKey] = pressedInput
            
            -- Save the mapping
            if isKeyboard then
                InputManager.setCustomKeyboardMapping(playerIndex, customMap)
            else
                InputManager.setCustomGamepadMapping(playerIndex, customMap)
            end
            
            -- Exit remapping mode
            GameInfo.remapMenuRemapping = nil
        else
            -- No key/button was pressed for remapping, check for cancel (Escape key)
            if isKeyboard then
                local escapeWasDown = lastKeyStates["escape"] or false
                local escapeIsDown = love.keyboard.isDown("escape")
                if escapeIsDown and not escapeWasDown then
                    -- Escape was just pressed, cancel remapping
                    GameInfo.remapMenuRemapping = nil
                end
            end
        end
        
        return
    end
    
    -- Normal navigation mode - get input using menu defaults
    local input = nil
    local justStates = {}
    
    if isKeyboard then
        local keyboardMapping = GameInfo.p1KeyboardMapping or (playerIndex == 1 and 1 or 2)
        input = InputManager.getKeyboardInput(keyboardMapping, true)  -- useMenuDefaults = true
        
        -- Edge detection for keyboard
        local keyboardMap = InputManager.getKeyboardMapping(keyboardMapping)
        for key, _ in pairs(keyboardMap) do
            local keyName = keyboardMap[key]
            local isDown = love.keyboard.isDown(keyName)
            local wasDown = lastKeyStates[keyName] or false
            if isDown and not wasDown then
                justStates[key] = true
            end
            lastKeyStates[keyName] = isDown
        end
    else
        if controllerID then
            input = InputManager.get(controllerID, true)  -- useMenuDefaults = true
            
            -- Get joystick for edge detection
            local js = InputManager.getJoystick(controllerID)
            if js then
                local jid = js:getID()
                justStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        end
    end
    local numOptions = #actions + 2  -- 8 actions + Save + Back
    
    -- Handle navigation (up/down)
    local moveUp = false
    local moveDown = false
    
    if moveCooldown <= 0 then
        if input then
            if input.moveY < -0.5 then
                moveUp = true
            elseif input.moveY > 0.5 then
                moveDown = true
            end
        end
        if justStates.up then
            moveUp = true
        elseif justStates.down then
            moveDown = true
        end
    end
    
    if moveUp then
        if GameInfo.remapMenuSelectedOption > 1 then
            GameInfo.remapMenuSelectedOption = GameInfo.remapMenuSelectedOption - 1
            moveCooldown = moveCooldownDuration
        end
    elseif moveDown then
        if GameInfo.remapMenuSelectedOption < numOptions then
            GameInfo.remapMenuSelectedOption = GameInfo.remapMenuSelectedOption + 1
            moveCooldown = moveCooldownDuration
        end
    end
    
    -- Handle A press
    local aPressed = (justStates.a) or false
    
        if aPressed then
        if GameInfo.remapMenuSelectedOption <= #actions then
            -- Select an action to remap
            GameInfo.remapMenuRemapping = actions[GameInfo.remapMenuSelectedOption]
            -- Initialize button/key states with current state to prevent the A press from being detected as a remap
            lastButtonStates = {}
            lastKeyStates = {}
            lastStickLeft = false
            lastStickRight = false
            
            if isKeyboard then
                -- Initialize all key states to current state (for proper edge detection)
                local allKeys = getAllKeyboardKeys()
                for _, keyName in ipairs(allKeys) do
                    lastKeyStates[keyName] = love.keyboard.isDown(keyName)
                end
            else
                -- Mark all currently pressed buttons as already pressed
                if controllerID then
                    local js = InputManager.getJoystick(controllerID)
                    if js then
                        lastButtonStates["a"] = js:isGamepadDown("a")
                        lastButtonStates["b"] = js:isGamepadDown("b")
                        lastButtonStates["x"] = js:isGamepadDown("x")
                        lastButtonStates["y"] = js:isGamepadDown("y")
                        lastButtonStates["shoulderL"] = js:isGamepadDown("leftshoulder")
                        lastButtonStates["shoulderR"] = js:isGamepadDown("rightshoulder")
                        -- Initialize stick states
                        local lx = js:getGamepadAxis("leftx")
                        lastStickLeft = (lx < -0.3)
                        lastStickRight = (lx > 0.3)
                    end
                end
            end
        elseif GameInfo.remapMenuSelectedOption == numOptions - 1 then
            -- Save mapping (keep current mappings as-is)
            backupKeyboardMapping = nil
            backupGamepadMapping = nil
            backupInitialized = false
            GameInfo.remapMenuActive = false
            GameInfo.remapMenuPlayer = nil
            GameInfo.remapMenuSelectedOption = 1
            GameInfo.remapMenuRemapping = nil
        elseif GameInfo.remapMenuSelectedOption == numOptions then
            -- Back without save (restore backup)
            if isKeyboard then
                InputManager.setCustomKeyboardMapping(playerIndex, backupKeyboardMapping)
            else
                InputManager.setCustomGamepadMapping(playerIndex, backupGamepadMapping)
            end
            backupKeyboardMapping = nil
            backupGamepadMapping = nil
            backupInitialized = false
            GameInfo.remapMenuActive = false
            GameInfo.remapMenuPlayer = nil
            GameInfo.remapMenuSelectedOption = 1
            GameInfo.remapMenuRemapping = nil
        end
    end
    
    -- Handle B/back to exit menu
    if (justStates.b or justStates.back) then
        -- Back without save (restore backup)
        if isKeyboard then
            InputManager.setCustomKeyboardMapping(playerIndex, backupKeyboardMapping)
        else
            InputManager.setCustomGamepadMapping(playerIndex, backupGamepadMapping)
        end
        backupKeyboardMapping = nil
        backupGamepadMapping = nil
        backupInitialized = false
        GameInfo.remapMenuActive = false
        GameInfo.remapMenuPlayer = nil
        GameInfo.remapMenuSelectedOption = 1
        GameInfo.remapMenuRemapping = nil
    end
end

function RemapMenu.draw(GameInfo)
    local playerIndex = GameInfo.remapMenuPlayer
    if not playerIndex then
        return
    end
    
    -- Determine if player is using keyboard or gamepad
    local isKeyboard = false
    if GameInfo.p1InputType == "keyboard" and playerIndex == 1 then
        isKeyboard = true
    elseif GameInfo.p2InputType == "keyboard" and playerIndex == 2 then
        isKeyboard = true
    end
    
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, GameInfo.gameWidth, GameInfo.gameHeight)
    
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw title
    local title = "Player " .. playerIndex .. " Controls"
    love.graphics.printf(title, 0, 1, GameInfo.gameWidth, "center", 0, 1, 1)
    
    -- Draw action list
    local startY = 8
    local lineHeight = 6
    local leftColumnX = 7
    local rightColumnX = 70
    
    -- Blue color matching Main Menu and Pause Menu
    local blueColor = {127/255, 146/255, 237/255}
    local arrowSize = 5
    
    for i, action in ipairs(actions) do
        local y = startY + (i - 1) * lineHeight
        
        -- Draw action name
        love.graphics.printf(action, leftColumnX, y, rightColumnX - leftColumnX, "left", 0, 1, 1)
        
        -- Draw arrow to the left of selected action
        if i == GameInfo.remapMenuSelectedOption then
            local arrowX = leftColumnX - 6
            local arrowY = y + 5  -- Center vertically on the text line
            love.graphics.setColor(blueColor)
            love.graphics.polygon(
                "fill",
                arrowX, arrowY - arrowSize/2,
                arrowX, arrowY + arrowSize/2,
                arrowX + arrowSize, arrowY
            )
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        -- Draw current mapping
        local actionKey = actionKeys[action]
        local displayName = InputManager.getButtonDisplayName(actionKey, isKeyboard, playerIndex)
        love.graphics.printf(displayName, rightColumnX, y, GameInfo.gameWidth - rightColumnX - 5, "right", 0, 1, 1)
        
        -- Show "Remapping..." if this action is being remapped
        if GameInfo.remapMenuRemapping == action then
            love.graphics.setColor(1, 1, 0, 1)  -- Yellow
            love.graphics.printf("Remapping...", rightColumnX, y, GameInfo.gameWidth - rightColumnX - 5, "right", 0, 1, 1)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    -- Draw Save and Back options
    local saveY = startY + #actions * lineHeight
    
    love.graphics.printf("Save Mapping", leftColumnX, saveY, GameInfo.gameWidth - 10, "center", 0, 1, 1)
    
    -- Draw arrow to the left of Save if selected
    if GameInfo.remapMenuSelectedOption == #actions + 1 then
        local centerX = GameInfo.gameWidth / 2
        local textOffset = 40  -- Approximate offset to left of centered text
        local arrowX = centerX - textOffset
        local arrowY = saveY + 5
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    love.graphics.printf("Back without Saving", leftColumnX, saveY+6, GameInfo.gameWidth - 10, "center", 0, 1, 1)
    
    -- Draw arrow to the left of Back if selected
    if GameInfo.remapMenuSelectedOption == #actions + 2 then
        local centerX = GameInfo.gameWidth / 2
        local textOffset = 50  -- Approximate offset to left of centered text (longer text)
        local arrowX = centerX - textOffset
        local arrowY = saveY + 11
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return RemapMenu

