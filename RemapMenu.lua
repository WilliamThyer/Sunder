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
    
    -- Get input using menu defaults (always use defaults for menu navigation)
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
    
    -- If in remapping mode, wait for next button press
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
            -- Check all keys
            local keyboardMap = InputManager.getKeyboardMapping(GameInfo.p1KeyboardMapping or (playerIndex == 1 and 1 or 2))
            for key, keyName in pairs(keyboardMap) do
                -- Skip menu navigation keys (start, back, up, down)
                if key ~= "start" and key ~= "back" and key ~= "up" and key ~= "down" then
                    if love.keyboard.isDown(keyName) and not (lastKeyStates[keyName] or false) then
                        pressedKey = keyName
                        break
                    end
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
                    
                    -- Also check stick movement for left/right
                    local lx = js:getGamepadAxis("leftx")
                    if math.abs(lx) > 0.3 then
                        if lx < 0 then
                            pressedButton = "left"
                        else
                            pressedButton = "right"
                        end
                    end
                end
            end
        end
        
        -- Update last button/key states
        if isKeyboard then
            local keyboardMap = InputManager.getKeyboardMapping(GameInfo.p1KeyboardMapping or (playerIndex == 1 and 1 or 2))
            for key, keyName in pairs(keyboardMap) do
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
        
        -- If a button/key was pressed, map it
        if pressedButton or pressedKey then
            -- Get current custom mapping or create new one
            local customMap = nil
            if isKeyboard then
                customMap = InputManager.getCustomKeyboardMapping(playerIndex) or {}
            else
                customMap = InputManager.getCustomGamepadMapping(playerIndex) or {}
            end
            
            -- Unmap this button/key from any other action
            for otherAction, mappedButton in pairs(customMap) do
                if mappedButton == (pressedButton or pressedKey) then
                    customMap[otherAction] = nil
                end
            end
            
            -- Map the button/key to this action
            customMap[actionKey] = pressedButton or pressedKey
            
            -- Save the mapping
            if isKeyboard then
                InputManager.setCustomKeyboardMapping(playerIndex, customMap)
            else
                InputManager.setCustomGamepadMapping(playerIndex, customMap)
            end
            
            -- Exit remapping mode
            GameInfo.remapMenuRemapping = nil
        end
        
        -- Check for B/back to cancel remapping
        if (justStates.b or justStates.back) then
            GameInfo.remapMenuRemapping = nil
        end
        
        return
    end
    
    -- Normal navigation mode
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
            
            if isKeyboard then
                -- Mark all currently pressed keys as already pressed
                local keyboardMap = InputManager.getKeyboardMapping(GameInfo.p1KeyboardMapping or (playerIndex == 1 and 1 or 2))
                for key, keyName in pairs(keyboardMap) do
                    if love.keyboard.isDown(keyName) then
                        lastKeyStates[keyName] = true
                    end
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
                    end
                end
            end
        elseif GameInfo.remapMenuSelectedOption == numOptions - 1 then
            -- Save mapping
            GameInfo.remapMenuActive = false
            GameInfo.remapMenuPlayer = nil
            GameInfo.remapMenuSelectedOption = 1
            GameInfo.remapMenuRemapping = nil
        elseif GameInfo.remapMenuSelectedOption == numOptions then
            -- Back without save (discard changes)
            -- Clear custom mappings for this player
            if isKeyboard then
                InputManager.setCustomKeyboardMapping(playerIndex, nil)
            else
                InputManager.setCustomGamepadMapping(playerIndex, nil)
            end
            GameInfo.remapMenuActive = false
            GameInfo.remapMenuPlayer = nil
            GameInfo.remapMenuSelectedOption = 1
            GameInfo.remapMenuRemapping = nil
        end
    end
    
    -- Handle B/back to exit menu
    if (justStates.b or justStates.back) then
        -- Back without save (discard changes)
        if isKeyboard then
            InputManager.setCustomKeyboardMapping(playerIndex, nil)
        else
            InputManager.setCustomGamepadMapping(playerIndex, nil)
        end
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
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, GameInfo.gameWidth, GameInfo.gameHeight)
    
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw title
    local title = "Remap Controls - Player " .. playerIndex
    love.graphics.printf(title, 0, 5, GameInfo.gameWidth, "center", 0, 1, 1)
    
    -- Draw action list
    local startY = 15
    local lineHeight = 8
    local leftColumnX = 5
    local rightColumnX = 70
    
    for i, action in ipairs(actions) do
        local y = startY + (i - 1) * lineHeight
        
        -- Highlight selected action
        if i == GameInfo.remapMenuSelectedOption then
            love.graphics.setColor(127/255, 146/255, 237/255, 1)  -- Blue highlight
            love.graphics.rectangle("fill", leftColumnX - 2, y - 1, GameInfo.gameWidth - 10, lineHeight)
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        -- Draw action name
        love.graphics.printf(action, leftColumnX, y, rightColumnX - leftColumnX, "left", 0, 1, 1)
        
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
    local saveY = startY + #actions * lineHeight + 5
    local backY = saveY + lineHeight
    
    -- Highlight Save if selected
    if GameInfo.remapMenuSelectedOption == #actions + 1 then
        love.graphics.setColor(127/255, 146/255, 237/255, 1)  -- Blue highlight
        love.graphics.rectangle("fill", leftColumnX - 2, saveY - 1, GameInfo.gameWidth - 10, lineHeight)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    love.graphics.printf("Save Mapping", leftColumnX, saveY, GameInfo.gameWidth - 10, "center", 0, 1, 1)
    
    -- Highlight Back if selected
    if GameInfo.remapMenuSelectedOption == #actions + 2 then
        love.graphics.setColor(127/255, 146/255, 237/255, 1)  -- Blue highlight
        love.graphics.rectangle("fill", leftColumnX - 2, backY - 1, GameInfo.gameWidth - 10, lineHeight)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    love.graphics.printf("Back without Save", leftColumnX, backY, GameInfo.gameWidth - 10, "center", 0, 1, 1)
end

return RemapMenu

