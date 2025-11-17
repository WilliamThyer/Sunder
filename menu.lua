local Menu = {}
Menu.__index = Menu
Menu.paused      = false
Menu.pausePlayer = nil
Menu.restartMenu = false
Menu.restartMenuOpenedAt = nil -- Timestamp when restart menu was opened
Menu.restartMenuInputDelay = 0.5 -- Seconds to wait before accepting input
Menu.menuMoveCooldown = 0 -- Cooldown timer for menu navigation

love.graphics.setDefaultFilter("nearest","nearest")

local push = require("libraries.push")
local InputManager = require("InputManager")

-- local font = love.graphics.newFont("assets/Minecraftia-Regular.ttf", 8)
local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

-- ----------------------------------------------------------------------
-- Menu sound effects
-- ----------------------------------------------------------------------
local menuSounds = {}

-- Initialize menu sound effects with error handling
local function initMenuSounds()
    local success, counter = pcall(love.audio.newSource, "assets/soundEffects/counter.wav", "static")
    if success then
        menuSounds.counter = counter
        menuSounds.counter:setLooping(false)
    else
        print("Warning: Could not load counter.wav")
    end
    
    local success2, downAir = pcall(love.audio.newSource, "assets/soundEffects/downAir.wav", "static")
    if success2 then
        menuSounds.downAir = downAir
        menuSounds.downAir:setLooping(false)
    else
        print("Warning: Could not load downAir.wav")
    end
    
    local success3, shield = pcall(love.audio.newSource, "assets/soundEffects/shield.wav", "static")
    if success3 then
        menuSounds.shield = shield
        menuSounds.shield:setLooping(false)
    else
        print("Warning: Could not load shield.wav")
    end
end

-- Safely play a menu sound effect
local function playMenuSound(soundName)
    if menuSounds[soundName] then
        menuSounds[soundName]:stop()
        menuSounds[soundName]:play()
    end
end

-- Export playMenuSound for use in other modules
Menu.playMenuSound = playMenuSound

-- Initialize sounds when module loads
initMenuSounds()

-- Keyboard edge detection state
local keyboardJustPressed = {
    a = false,
    b = false,
    x = false,
    y = false,
    start = false,
    back = false,
    up = false,
    down = false,
    left = false,
    right = false
}

-- Update keyboard edge detection
local function updateKeyboardEdgeDetection()
    local keyboardMap1 = InputManager.getKeyboardMapping(1)
    local keyboardMap2 = InputManager.getKeyboardMapping(2)
    
    -- Check for key presses this frame for P1
    if love.keyboard.isDown(keyboardMap1.a) then
        keyboardJustPressed.a = true
    end
    if love.keyboard.isDown(keyboardMap1.b) then
        keyboardJustPressed.b = true
    end
    if love.keyboard.isDown(keyboardMap1.x) then
        keyboardJustPressed.x = true
    end
    if love.keyboard.isDown(keyboardMap1.y) then
        keyboardJustPressed.y = true
    end
    if love.keyboard.isDown(keyboardMap1.start) then
        keyboardJustPressed.start = true
    end
    if love.keyboard.isDown(keyboardMap1.back) then
        keyboardJustPressed.back = true
    end
    if love.keyboard.isDown(keyboardMap1.up) then
        keyboardJustPressed.up = true
    end
    if love.keyboard.isDown(keyboardMap1.down) then
        keyboardJustPressed.down = true
    end
    if love.keyboard.isDown(keyboardMap1.left) then
        keyboardJustPressed.left = true
    end
    if love.keyboard.isDown(keyboardMap1.right) then
        keyboardJustPressed.right = true
    end
    -- Optionally, add similar checks for P2 if you want edge detection for both
end

-- Clear keyboard edge detection (call this after processing input)
local function clearKeyboardEdgeDetection()
    for key, _ in pairs(keyboardJustPressed) do
        keyboardJustPressed[key] = false
    end
end

-- ----------------------------------------------------------------------
-- Menu logic
-- ----------------------------------------------------------------------
-- Track previous selection to detect actual changes
local previousSelectedOption = nil

function Menu.updateMenu(GameInfo)
    -- Initialize selectedOption if not set (defaults to option 1)
    if not GameInfo.selectedOption then
        GameInfo.selectedOption = 1
    end
    
    -- Get delta time and update cooldown
    local dt = love.timer.getDelta()
    Menu.menuMoveCooldown = math.max(0, Menu.menuMoveCooldown - dt)
    
    -- Force refresh controllers when in menu to catch any newly connected ones
    InputManager.refreshControllersImmediate()
    
    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()
    
    -- Get input from the correct controllers based on GameInfo assignments
    local p1Input = nil
    local p2Input = nil
    
    -- Handle P1 input
    if GameInfo.p1InputType == "keyboard" then
        p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
    else
        p1Input = InputManager.get(GameInfo.player1Controller)
    end
    
    -- For menu navigation, we can use any available controller or keyboard
    -- Get joystick objects for edge detection
    local js1 = InputManager.getJoystick(GameInfo.player1Controller)
    local js2 = nil
    if GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" then
        js2 = InputManager.getJoystick(GameInfo.player2Controller)
    end
    
    -- Copy and consume justPressed for edge detection
    local justStates = {}
    if js1 then
        local jid1 = js1:getID()
        justStates[1] = justPressed[jid1] or {}
        justPressed[jid1] = nil
    else
        justStates[1] = {}
    end
    
    if js2 then
        local jid2 = js2:getID()
        justStates[2] = justPressed[jid2] or {}
        justPressed[jid2] = nil
    else
        justStates[2] = {}
    end
    
    -- Merge keyboard edge detection into justStates for player 1
    for k,v in pairs(keyboardJustPressed) do
        if v then
            justStates[1][k] = true
        end
    end

    -- Allow either controller or keyboard to move the selection
    -- Only allow movement when cooldown has expired
    local moveUp = false
    local moveDown = false
    
    if Menu.menuMoveCooldown <= 0 then
        if js1 and (p1Input.moveY < -0.5) then
            moveUp = true
        elseif js2 and (p2Input and p2Input.moveY < -0.5) then
            moveUp = true
        elseif keyboardJustPressed.up then
            moveUp = true
        end
        
        if js1 and (p1Input.moveY > 0.5) then
            moveDown = true
        elseif js2 and (p2Input and p2Input.moveY > 0.5) then
            moveDown = true
        elseif keyboardJustPressed.down then
            moveDown = true
        end
    end
    
    -- Track current selection before updating
    local currentSelection = GameInfo.selectedOption or 1
    
    -- Update selection and play sound only if it actually changed
    if moveUp then
        if currentSelection > 1 then
            playMenuSound("counter")
        end
        GameInfo.selectedOption = math.max(1, currentSelection - 1)
        previousSelectedOption = GameInfo.selectedOption
        Menu.menuMoveCooldown = 0.25  -- Set cooldown after movement
    elseif moveDown then
        if currentSelection < 3 then
            playMenuSound("counter")
        end
        GameInfo.selectedOption = math.min(3, currentSelection + 1)
        previousSelectedOption = GameInfo.selectedOption
        Menu.menuMoveCooldown = 0.25  -- Set cooldown after movement
    else
        -- No movement, preserve previous selection for next frame comparison
        previousSelectedOption = currentSelection
    end

    -- Check which controller or keyboard pressed A first to determine Player 1
    local p1Pressed = justStates[1] and justStates[1]["a"]
    local p2Pressed = justStates[2] and justStates[2]["a"]
    
    if p1Pressed or p2Pressed then
        -- Play selection sound
        playMenuSound("downAir")
        
        if GameInfo.selectedOption == 1 then
            GameInfo.previousMode = "game_1P"
            GameInfo.keyboardPlayer = 1
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2Assigned = false
        elseif GameInfo.selectedOption == 2 then
            GameInfo.previousMode = "game_2P"
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2Assigned = false
            GameInfo.keyboardPlayer = nil
        else
            -- Story Mode
            GameInfo.previousMode = "game_story"
            GameInfo.keyboardPlayer = 1
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2Assigned = false
        end
        GameInfo.gameState = "characterselect"
        GameInfo.justEnteredCharacterSelect = true
    end
    
    -- Clear keyboard edge detection after processing
    clearKeyboardEdgeDetection()
end

-- ----------------------------------------------------------------------
-- Menu draw logic
-- ----------------------------------------------------------------------
function Menu.drawMenu(GameInfo)

    -- Clear background to black so the text is visible
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SUNDER", 0, 10, GameInfo.gameWidth/2, "center", 0, 2, 2)

    -- Blue color matching CharacterSelect menu (127/255, 146/255, 237/255)
    local blueColor = {127/255, 146/255, 237/255}
    local arrowSize = 5

    -- Option 1: 1 PLAYER
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("1 PLAYER", 0, 30, GameInfo.gameWidth, "center", 0, 1, 1)

    -- Option 2: 2 PLAYERS
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("2 PLAYERS", 0, 40, GameInfo.gameWidth, "center", 0, 1, 1)

    -- Option 3: STORY MODE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("STORY MODE", 0, 50, GameInfo.gameWidth, "center", 0, 1, 1)

    -- Draw blue arrow to the left of selected option
    local centerX = GameInfo.gameWidth / 2
    local textOffset = 25  -- Approximate offset to left of centered text
    local arrowX = centerX - textOffset
    
    if GameInfo.selectedOption == 1 then
        local arrowY = 35
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
    elseif GameInfo.selectedOption == 2 then
        local arrowY = 45
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
    elseif GameInfo.selectedOption == 3 then
        local arrowY = 55
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
    end

    -- Show keyboard controls if keyboard is enabled
    -- if GameInfo.keyboardPlayer == 1 or GameInfo.keyboardPlayer == 2 then
    --     love.graphics.setColor(0.7, 0.7, 0.7, 1)
    --     love.graphics.printf("Use WASD to move, SPACE to select", 0, 50, GameInfo.gameWidth, "center", 0, 1, 1)
    -- end

    love.graphics.setColor(1,1,1,1)  -- reset
end

-- Track previous pause selection to detect actual changes
local previousPauseSelectedOption = nil

function Menu.updatePauseMenu(GameInfo)
    -- Initialize pauseSelectedOption if not set (defaults to option 1)
    if not GameInfo.pauseSelectedOption then
        GameInfo.pauseSelectedOption = 1
    end
    
    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()
    
    -- Get input from the pause player
    local pauseInput = nil
    local pauseJoystick = nil
    local pauseJustStates = {}
    
    -- Determine which player paused and get their input
    if Menu.pausePlayer == "keyboard" then
        -- Pause player is using keyboard (assume P1)
        pauseInput = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
        -- Merge keyboard edge detection
        for k, v in pairs(keyboardJustPressed) do
            if v then
                pauseJustStates[k] = true
            end
        end
    elseif type(Menu.pausePlayer) == "number" then
        -- Pause player is using a controller or is a player index
        -- Check if it matches a controller ID
        if GameInfo.player1Controller == Menu.pausePlayer then
            -- P1's controller
            if GameInfo.p1InputType == "keyboard" then
                pauseInput = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
                for k, v in pairs(keyboardJustPressed) do
                    if v then
                        pauseJustStates[k] = true
                    end
                end
            else
                pauseJoystick = InputManager.getJoystick(GameInfo.player1Controller)
                pauseInput = InputManager.get(GameInfo.player1Controller)
                local jid = pauseJoystick:getID()
                pauseJustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        elseif GameInfo.player2Controller == Menu.pausePlayer then
            -- P2's controller
            if GameInfo.p2InputType == "keyboard" then
                pauseInput = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
                for k, v in pairs(keyboardJustPressed) do
                    if v then
                        pauseJustStates[k] = true
                    end
                end
            else
                pauseJoystick = InputManager.getJoystick(GameInfo.player2Controller)
                pauseInput = InputManager.get(GameInfo.player2Controller)
                local jid = pauseJoystick:getID()
                pauseJustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        elseif Menu.pausePlayer == 1 then
            -- Player index 1
            if GameInfo.p1InputType == "keyboard" then
                pauseInput = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
                for k, v in pairs(keyboardJustPressed) do
                    if v then
                        pauseJustStates[k] = true
                    end
                end
            elseif GameInfo.player1Controller then
                pauseJoystick = InputManager.getJoystick(GameInfo.player1Controller)
                pauseInput = InputManager.get(GameInfo.player1Controller)
                local jid = pauseJoystick:getID()
                pauseJustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        elseif Menu.pausePlayer == 2 then
            -- Player index 2
            if GameInfo.p2InputType == "keyboard" then
                pauseInput = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
                for k, v in pairs(keyboardJustPressed) do
                    if v then
                        pauseJustStates[k] = true
                    end
                end
            elseif GameInfo.player2Controller then
                pauseJoystick = InputManager.getJoystick(GameInfo.player2Controller)
                pauseInput = InputManager.get(GameInfo.player2Controller)
                local jid = pauseJoystick:getID()
                pauseJustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        end
    end
    
    -- Allow arrow navigation
    local moveUp = false
    local moveDown = false
    
    if pauseJoystick and pauseInput and (pauseInput.moveY < -0.5) then
        moveUp = true
    elseif keyboardJustPressed.up then
        moveUp = true
    end
    
    if pauseJoystick and pauseInput and (pauseInput.moveY > 0.5) then
        moveDown = true
    elseif keyboardJustPressed.down then
        moveDown = true
    end
    
    -- Track current selection before updating
    local currentSelection = GameInfo.pauseSelectedOption or 1
    
    -- Update selection and play sound only if it actually changed
    if moveUp then
        if currentSelection ~= 1 then
            playMenuSound("counter")
        end
        GameInfo.pauseSelectedOption = 1
        previousPauseSelectedOption = 1
    elseif moveDown then
        if currentSelection ~= 2 then
            playMenuSound("counter")
        end
        GameInfo.pauseSelectedOption = 2
        previousPauseSelectedOption = 2
    else
        -- No movement, preserve previous selection for next frame comparison
        previousPauseSelectedOption = currentSelection
    end
    
    -- Handle 'a' button press to select option
    local aPressed = pauseJustStates["a"] or false
    
    if aPressed then
        -- Play selection sound
        playMenuSound("downAir")
        
        if GameInfo.pauseSelectedOption == 1 then
            -- Resume (unpause)
            -- Determine which player paused and capture their button state
            local pausePlayerIndex = nil
            local pauseInputSource = nil
            
            if Menu.pausePlayer == "keyboard" then
                pausePlayerIndex = 1
                pauseInputSource = "keyboard_P1"
            elseif type(Menu.pausePlayer) == "number" then
                if GameInfo.player1Controller == Menu.pausePlayer or Menu.pausePlayer == 1 then
                    pausePlayerIndex = 1
                    if GameInfo.p1InputType == "keyboard" then
                        pauseInputSource = "keyboard_P1"
                    else
                        pauseInputSource = tostring(GameInfo.player1Controller)
                    end
                elseif GameInfo.player2Controller == Menu.pausePlayer or Menu.pausePlayer == 2 then
                    pausePlayerIndex = 2
                    if GameInfo.p2InputType == "keyboard" then
                        pauseInputSource = "keyboard_P2"
                    else
                        pauseInputSource = tostring(GameInfo.player2Controller)
                    end
                end
            end
            
            -- Capture current button state and set wait flag
            if pausePlayerIndex and pauseInputSource and pauseInput then
                setButtonReleaseWait(pausePlayerIndex, pauseInputSource, pauseInput)
            end
            
            Menu.paused = false
            Menu.pausePlayer = nil
        else
            -- Return to Menu
            Menu.paused = false
            Menu.pausePlayer = nil
            -- Reset story mode flags if in story mode
            if GameInfo.storyMode then
                GameInfo.storyMode = false
                GameInfo.storyOpponentIndex = 1
                GameInfo.storyOpponents = {}
                GameInfo.storyOpponentColors = {}
                GameInfo.storyPlayerCharacter = nil
                GameInfo.storyPlayerColor = nil
            end
            GameInfo.gameState = "characterselect"
            GameInfo.justEnteredCharacterSelect = true
        end
    end
    
    -- Clear keyboard edge detection after processing
    clearKeyboardEdgeDetection()
end

-- Track previous restart selection to detect actual changes
local previousRestartSelectedOption = nil

function Menu.updateRestartMenu(GameInfo)
    -- Wait for input delay to prevent immediate inputs from the fight affecting the menu
    -- This ensures players have time to see the menu before any input is accepted
    if not Menu.restartMenuOpenedAt then
        Menu.restartMenuOpenedAt = love.timer.getTime()
        -- Clear keyboard edge detection state to prevent any queued inputs
        clearKeyboardEdgeDetection()
        return  -- Return early on first call, before delay period
    end
    local now = love.timer.getTime()
    if now - Menu.restartMenuOpenedAt < Menu.restartMenuInputDelay then
        -- Clear keyboard edge detection state during delay period to prevent any queued inputs
        clearKeyboardEdgeDetection()
        return  -- Return early if delay hasn't passed yet, preventing all input processing
    end

    -- Initialize restartSelectedOption if not set (defaults to option 1)
    if not GameInfo.restartSelectedOption then
        GameInfo.restartSelectedOption = 1
    end

    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()

    local isTwoPlayer = (GameInfo.gameState == "game_2P")
    local p1Input = nil
    local p2Input = nil
    local p1JustStates = {}
    local p2JustStates = {}
    
    -- Get input from players
    if isTwoPlayer then
        -- 2P mode: Either player can input
        -- Check P1 input
        if GameInfo.p1InputType == "keyboard" then
            p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
            -- Merge keyboard edge detection
            for k, v in pairs(keyboardJustPressed) do
                if v then
                    p1JustStates[k] = true
                end
            end
        else
            local js1 = InputManager.getJoystick(GameInfo.player1Controller)
            if js1 then
                p1Input = InputManager.get(GameInfo.player1Controller)
                local jid = js1:getID()
                p1JustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        end
        
        -- Check P2 input
        if GameInfo.p2InputType == "keyboard" then
            p2Input = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
            -- Merge keyboard edge detection for P2 (if different mapping)
            if GameInfo.p2KeyboardMapping == 2 then
                local keyboardMap2 = InputManager.getKeyboardMapping(2)
                -- P2 keyboard uses different keys, but we'll use the same keyboardJustPressed
                for k, v in pairs(keyboardJustPressed) do
                    if v then
                        p2JustStates[k] = true
                    end
                end
            else
                -- Same keyboard mapping, use same states
                for k, v in pairs(p1JustStates) do
                    p2JustStates[k] = v
                end
            end
        else
            local js2 = InputManager.getJoystick(GameInfo.player2Controller)
            if js2 then
                p2Input = InputManager.get(GameInfo.player2Controller)
                local jid = js2:getID()
                p2JustStates = justPressed[jid] or {}
                justPressed[jid] = nil
            end
        end
    else
        -- 1P mode: Only P1 (the human player) can input - CPU inputs must never affect this menu
        -- Check keyboard input for P1 (only if P1 is using keyboard)
        if GameInfo.p1InputType == "keyboard" then
            p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
            -- Merge keyboard edge detection
            for k, v in pairs(keyboardJustPressed) do
                if v then
                    p1JustStates[k] = true
                end
            end
        end
        
        -- Check controller input for P1 (only if P1 is using a controller)
        -- Explicitly filter to only accept inputs from P1's assigned controller ID
        if GameInfo.p1InputType ~= "keyboard" and GameInfo.player1Controller then
            local js1 = InputManager.getJoystick(GameInfo.player1Controller)
            if js1 then
                p1Input = InputManager.get(GameInfo.player1Controller)
                local p1Jid = js1:getID()
                -- Only check justPressed for P1's specific controller ID
                -- Ignore all other joystick IDs to prevent CPU or other controllers from affecting the menu
                if justPressed[p1Jid] then
                    p1JustStates = justPressed[p1Jid]
                    justPressed[p1Jid] = nil
                end
            end
        end
        -- Note: In 1P mode, we intentionally ignore all other joysticks in justPressed
        -- to prevent any CPU or unassigned controllers from affecting the restart menu
    end

    -- Get joystick objects for arrow navigation
    local js1 = nil
    local js2 = nil
    if GameInfo.p1InputType and GameInfo.p1InputType ~= "keyboard" then
        js1 = InputManager.getJoystick(GameInfo.player1Controller)
    end
    if isTwoPlayer and GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" then
        js2 = InputManager.getJoystick(GameInfo.player2Controller)
    end

    -- Allow arrow navigation (either player can navigate)
    local moveUp = false
    local moveDown = false
    
    if js1 and p1Input and (p1Input.moveY < -0.5) then
        moveUp = true
    elseif js2 and p2Input and (p2Input.moveY < -0.5) then
        moveUp = true
    elseif keyboardJustPressed.up then
        moveUp = true
    end
    
    if js1 and p1Input and (p1Input.moveY > 0.5) then
        moveDown = true
    elseif js2 and p2Input and (p2Input.moveY > 0.5) then
        moveDown = true
    elseif keyboardJustPressed.down then
        moveDown = true
    end
    
    -- Track current selection before updating
    local currentSelection = GameInfo.restartSelectedOption or 1
    
    -- Update selection and play sound only if it actually changed
    if moveUp then
        if currentSelection ~= 1 then
            playMenuSound("counter")
        end
        GameInfo.restartSelectedOption = 1
        previousRestartSelectedOption = 1
    elseif moveDown then
        if currentSelection ~= 2 then
            playMenuSound("counter")
        end
        GameInfo.restartSelectedOption = 2
        previousRestartSelectedOption = 2
    else
        -- No movement, preserve previous selection for next frame comparison
        previousRestartSelectedOption = currentSelection
    end

    -- Handle selection with 'a' button or START button
    local aPressed = (p1JustStates["a"] or p2JustStates["a"]) or false
    local startPressed = (p1JustStates["start"] or p2JustStates["start"]) or false
    
    if aPressed or startPressed then
        -- Play selection sound
        playMenuSound("downAir")
        
        if GameInfo.restartSelectedOption == 1 then
            -- Restart Fight
            -- Capture button states for both players to prevent carryover
            -- Determine input sources and capture current states
            if p1Input then
                local p1InputSource = nil
                if GameInfo.p1InputType == "keyboard" then
                    p1InputSource = "keyboard_P1"
                else
                    p1InputSource = tostring(GameInfo.player1Controller)
                end
                if p1InputSource then
                    setButtonReleaseWait(1, p1InputSource, p1Input)
                end
            end
            
            if p2Input and isTwoPlayer then
                local p2InputSource = nil
                if GameInfo.p2InputType == "keyboard" then
                    p2InputSource = "keyboard_P2"
                else
                    p2InputSource = tostring(GameInfo.player2Controller)
                end
                if p2InputSource then
                    setButtonReleaseWait(2, p2InputSource, p2Input)
                end
            end
            
            Menu.restartMenu = false
            Menu.restartMenuOpenedAt = nil
            startGame(GameInfo.gameState)
        else
            -- Return to Menu
            Menu.restartMenu = false
            Menu.restartMenuOpenedAt = nil
            -- Reset story mode flags if in story mode
            if GameInfo.storyMode then
                GameInfo.storyMode = false
                GameInfo.storyOpponentIndex = 1
                GameInfo.storyOpponents = {}
                GameInfo.storyOpponentColors = {}
                GameInfo.storyPlayerCharacter = nil
                GameInfo.storyPlayerColor = nil
            end
            GameInfo.gameState = "characterselect"
            GameInfo.justEnteredCharacterSelect = true
        end
    end
    
    -- Clear keyboard edge detection after processing
    clearKeyboardEdgeDetection()
end

function Menu.drawRestartMenu(players)
    local p1, p2 = players[1], players[2]

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    if p1.isDead and p2.isDead then
        love.graphics.printf("Nobody Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    elseif p1.isDead then
        love.graphics.printf("Player 2 Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    elseif p2.isDead then
        love.graphics.printf("Player 1 Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    end
    
    -- Blue color matching main menu (127/255, 146/255, 237/255)
    local blueColor = {127/255, 146/255, 237/255}
    local arrowSize = 5
    
    -- Option 1: Restart Fight
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Restart Fight", 0, 30, GameInfo.gameWidth, "center", 0, 1, 1)
    
    -- Option 2: Return to Menu
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Return to Menu", 0, 40, GameInfo.gameWidth, "center", 0, 1, 1)
    
    -- Draw blue arrow to the left of selected option
    local centerX = GameInfo.gameWidth / 2
    local textOffset = 30  -- Approximate offset to left of centered text
    local arrowX = centerX - textOffset
    
    if GameInfo.restartSelectedOption == 1 then
        local arrowY = 35
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
    elseif GameInfo.restartSelectedOption == 2 then
        local arrowY = 45
        love.graphics.setColor(blueColor)
        love.graphics.polygon(
            "fill",
            arrowX, arrowY - arrowSize/2,
            arrowX, arrowY + arrowSize/2,
            arrowX + arrowSize, arrowY
        )
    end
    
    love.graphics.setColor(1,1,1,1)  -- reset
end

-- called by love.gamepadpressed in main.lua
function Menu.handlePauseInput(joystick, button)
  -- only during an actual fight
  if not (GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" or GameInfo.gameState == "game_story") then
    return
  end
  if Menu.restartMenu then
    -- if we're in the restart menu, we don't handle pause input
    return
  end

  if button == "start" then
    if not Menu.paused then
      Menu.paused      = true
      Menu.pausePlayer = joystick:getID()
    elseif joystick:getID() == Menu.pausePlayer then
      -- Resume game when START is pressed while paused
      Menu.paused      = false
      Menu.pausePlayer = nil
    end
  end
end

-- Handle keyboard pause input
function Menu.handleKeyboardPauseInput(key, playerIndex)
  -- only during an actual fight
  if not (GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" or GameInfo.gameState == "game_story") then
    return
  end
  if Menu.restartMenu then
    -- if we're in the restart menu, we don't handle pause input
    return
  end

  local keyboardMap = InputManager.getKeyboardMapping(playerIndex or 1)
  
  if key == keyboardMap.start then
    if not Menu.paused then
      Menu.paused = true
      Menu.pausePlayer = playerIndex or "keyboard"
    elseif Menu.pausePlayer == (playerIndex or "keyboard") then
      -- Resume game when START is pressed while paused
      Menu.paused = false
      Menu.pausePlayer = nil
    end
  end
end

function Menu.drawPauseOverlay()
  -- a translucent black
  love.graphics.setColor(0,0,0,0.75)
  love.graphics.rectangle("fill", 0,0, GameInfo.gameWidth, GameInfo.gameHeight)
  
  love.graphics.setFont(font)
  love.graphics.setColor(1,1,1,1)
  
  -- Draw "PAUSED" title
  love.graphics.printf("PAUSED", 0, GameInfo.gameHeight/2 - 20, GameInfo.gameWidth, "center", 0, 1, 1)
  
  -- Blue color matching main menu (127/255, 146/255, 237/255)
  local blueColor = {127/255, 146/255, 237/255}
  local arrowSize = 5
  
  -- Option 1: Resume
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf("Resume", 0, GameInfo.gameHeight/2 - 5, GameInfo.gameWidth, "center", 0, 1, 1)
  
  -- Option 2: Return to Menu
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf("Return to Menu", 0, GameInfo.gameHeight/2 + 5, GameInfo.gameWidth, "center", 0, 1, 1)
  
  -- Draw blue arrow to the left of selected option
  local centerX = GameInfo.gameWidth / 2
  local textOffset = 30  -- Approximate offset to left of centered text
  local arrowX = centerX - textOffset
  
  if GameInfo.pauseSelectedOption == 1 then
    local arrowY = GameInfo.gameHeight/2
    love.graphics.setColor(blueColor)
    love.graphics.polygon(
      "fill",
      arrowX, arrowY - arrowSize/2,
      arrowX, arrowY + arrowSize/2,
      arrowX + arrowSize, arrowY
    )
  elseif GameInfo.pauseSelectedOption == 2 then
    local arrowY = GameInfo.gameHeight/2 + 10
    love.graphics.setColor(blueColor)
    love.graphics.polygon(
      "fill",
      arrowX, arrowY - arrowSize/2,
      arrowX, arrowY + arrowSize/2,
      arrowX + arrowSize, arrowY
    )
  end
  
  love.graphics.setColor(1,1,1,1)  -- reset
end


return Menu
