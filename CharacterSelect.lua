-- CharacterSelect.lua
-- Uses a global `justPressed[jid][button] = true` populated in love.gamepadpressed.
-- Edge‐detection ("was pressed this frame") comes from consuming `justPressed`.

-- Add a helper to check if P2 is assigned
local function isP2Assigned()
    return GameInfo and GameInfo.p2InputType ~= nil
end

local CharacterSelect = {}
CharacterSelect.__index = CharacterSelect

local push = require("libraries.push")
local InputManager = require("InputManager")
love.graphics.setDefaultFilter("nearest", "nearest")

-- === Predefined colors for players ===
local colorOptions = {
    {127/255, 146/255, 237/255},  -- Blue
    {234/255,  94/255,  94/255},  -- Red
    {141/255, 141/255, 141/255},  -- Gray
    {241/255, 225/255, 115/255},  -- Yellow
}
local colorNames = {"Blue", "Red", "Gray", "Yellow"}

-- List of characters
local characters = {"Warrior", "Berserk", "Lancer", "Mage"}

-- Load sprite sheets for the characters that have sprites
local sprites = {
    Warrior = {
       Red    = love.graphics.newImage("assets/sprites/WarriorRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/WarriorBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/WarriorYellow.png"),
       Gray   = love.graphics.newImage("assets/sprites/WarriorGray.png")
    },
    Berserk = {
       Red    = love.graphics.newImage("assets/sprites/BerserkRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/BerserkBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/BerserkYellow.png"),
       Gray   = love.graphics.newImage("assets/sprites/BerserkGray.png")
    },
    Lancer = {
        Red    = love.graphics.newImage("assets/sprites/LancerRed.png"),
        Blue   = love.graphics.newImage("assets/sprites/LancerBlue.png"),
        Yellow = love.graphics.newImage("assets/sprites/LancerYellow.png"),
        Gray   = love.graphics.newImage("assets/sprites/LancerGray.png")
        },
    Mage = {
        Red    = love.graphics.newImage("assets/sprites/MageRed.png"),
        Blue   = love.graphics.newImage("assets/sprites/MageBlue.png"),
        Yellow = love.graphics.newImage("assets/sprites/MageYellow.png"),
        Gray   = love.graphics.newImage("assets/sprites/MageGray.png")
        }
}

-- Quads for the first sprite of each sheet
local warriorQuad = love.graphics.newQuad(
    0, 1, 9, 8,
    sprites.Warrior.Blue:getWidth(),
    sprites.Warrior.Blue:getHeight()
)
local berserkQuad = love.graphics.newQuad(
    1, 2, 13, 13,
    sprites.Berserk.Blue:getWidth(),
    sprites.Berserk.Blue:getHeight()
)
local lancerQuad = love.graphics.newQuad(
    1, 2, 13, 13,
    sprites.Lancer.Blue:getWidth(),
    sprites.Lancer.Blue:getHeight()
)
local mageQuad = love.graphics.newQuad(
    1, 2, 13, 13,
    sprites.Mage.Blue:getWidth(),
    sprites.Mage.Blue:getHeight()
)
-- Per-player state (two players: 1 and 2)
--   locked: whether that player has pressed A to lock in
--   cursor: which character index is highlighted (1..#characters)
--   moveCooldown: to prevent too-fast joystick scrolling
--   prevY, prevSelect, prevBack, prevStart: (no longer needed here)
--   colorIndex: which color (1..4) is chosen
--   colorChangeCooldown: to prevent rapid color cycling
--   inputDelay: to prevent input carryover from menu
--   backButtonSelected: whether this player has navigated to the back button
--   previousCursor: cursor position before navigating to back button
--   verticalMoveCooldown: to prevent rapid vertical navigation
local playerSelections = {
    [1] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 1, colorChangeCooldown = 0, inputDelay = 0, backButtonSelected = false, previousCursor = 1, verticalMoveCooldown = 0 },
    [2] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 2, colorChangeCooldown = 0, inputDelay = 0, backButtonSelected = false, previousCursor = 1, verticalMoveCooldown = 0 }
}

-- Controller assignment tracking
local controllerAssignments = {
    [1] = nil,  -- Player 1's controller index
    [2] = nil   -- Player 2's controller index
}

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
    
    -- Check for key presses this frame for both players
    if love.keyboard.isDown(keyboardMap1.a) or love.keyboard.isDown(keyboardMap2.a) then
        keyboardJustPressed.a = true
    end
    if love.keyboard.isDown(keyboardMap1.b) or love.keyboard.isDown(keyboardMap2.b) then
        keyboardJustPressed.b = true
    end
    if love.keyboard.isDown(keyboardMap1.x) or love.keyboard.isDown(keyboardMap2.x) then
        keyboardJustPressed.x = true
    end
    if love.keyboard.isDown(keyboardMap1.y) or love.keyboard.isDown(keyboardMap2.y) then
        keyboardJustPressed.y = true
    end
    if love.keyboard.isDown(keyboardMap1.start) or love.keyboard.isDown(keyboardMap2.start) then
        keyboardJustPressed.start = true
    end
    if love.keyboard.isDown(keyboardMap1.back) or love.keyboard.isDown(keyboardMap2.back) then
        keyboardJustPressed.back = true
    end
    if love.keyboard.isDown(keyboardMap1.left) or love.keyboard.isDown(keyboardMap2.left) then
        keyboardJustPressed.left = true
    end
    if love.keyboard.isDown(keyboardMap1.right) or love.keyboard.isDown(keyboardMap2.right) then
        keyboardJustPressed.right = true
    end
    if love.keyboard.isDown(keyboardMap1.up) or love.keyboard.isDown(keyboardMap2.up) then
        keyboardJustPressed.up = true
    end
    if love.keyboard.isDown(keyboardMap1.down) or love.keyboard.isDown(keyboardMap2.down) then
        keyboardJustPressed.down = true
    end
end

-- Clear keyboard edge detection (call this after processing input)
local function clearKeyboardEdgeDetection()
    for key, _ in pairs(keyboardJustPressed) do
        keyboardJustPressed[key] = false
    end
end

local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

-- ----------------------------------------------------------------------
-- Character Select sound effects
-- ----------------------------------------------------------------------
local characterSelectSounds = {}

-- Initialize character select sound effects with error handling
local function initCharacterSelectSounds()
    local success, counter = pcall(love.audio.newSource, "assets/soundEffects/counter.wav", "static")
    if success then
        characterSelectSounds.counter = counter
        characterSelectSounds.counter:setLooping(false)
    else
        print("Warning: Could not load counter.wav")
    end
    
    local success2, downAir = pcall(love.audio.newSource, "assets/soundEffects/downAir.wav", "static")
    if success2 then
        characterSelectSounds.downAir = downAir
        characterSelectSounds.downAir:setLooping(false)
    else
        print("Warning: Could not load downAir.wav")
    end
    
    local success3, shield = pcall(love.audio.newSource, "assets/soundEffects/shield.wav", "static")
    if success3 then
        characterSelectSounds.shield = shield
        characterSelectSounds.shield:setLooping(false)
    else
        print("Warning: Could not load shield.wav")
    end
    
    local success4, heavyAttackBerserker = pcall(love.audio.newSource, "assets/soundEffects/heavyAttackBerserker.wav", "static")
    if success4 then
        characterSelectSounds.heavyAttackBerserker = heavyAttackBerserker
        characterSelectSounds.heavyAttackBerserker:setLooping(false)
    else
        print("Warning: Could not load heavyAttackBerserker.wav")
    end
end

-- Safely play a character select sound effect
local function playCharacterSelectSound(soundName)
    if characterSelectSounds[soundName] then
        characterSelectSounds[soundName]:stop()
        characterSelectSounds[soundName]:play()
    end
end

-- Initialize sounds when module loads
initCharacterSelectSounds()

-----------------------------------------------------
-- Helper: Advance colorIndex for `playerIndex`, skipping the other player's color
-----------------------------------------------------
local function cycleColor(playerIndex)
    local otherIndex = (playerIndex == 1) and 2 or 1
    local maxAttempts = #colorOptions
    local attempts = 0

    repeat
        playerSelections[playerIndex].colorIndex =
            playerSelections[playerIndex].colorIndex + 1

        if playerSelections[playerIndex].colorIndex > #colorOptions then
            playerSelections[playerIndex].colorIndex = 1
        end

        attempts = attempts + 1
    until (
        playerSelections[playerIndex].colorIndex ~=
        playerSelections[otherIndex].colorIndex
    ) or (attempts >= maxAttempts)
end

-----------------------------------------------------
-- Helper: Assign controller to player if not already assigned
-----------------------------------------------------
local function assignControllerToPlayer(controllerIndex, playerIndex)
    -- Check if this controller is already assigned
    for p = 1, 2 do
        if controllerAssignments[p] == controllerIndex then
            return false  -- Controller already assigned
        end
    end
    
    -- Check if this player already has a controller
    if controllerAssignments[playerIndex] then
        return false  -- Player already has a controller
    end
    
    -- Assign the controller to this player
    controllerAssignments[playerIndex] = controllerIndex
    return true
end

-----------------------------------------------------
-- Helper: Get the player index for a given controller
-----------------------------------------------------
local function getPlayerForController(controllerIndex)
    for playerIndex = 1, 2 do
        if controllerAssignments[playerIndex] == controllerIndex then
            return playerIndex
        end
    end
    return nil
end

-----------------------------------------------------
-- Update a single player's selection given the `input` table
--   `input` fields (all booleans except moveX/moveY):
--     select      = true if "A was pressed this frame"
--     back        = true if "B was pressed this frame"
--     start       = true if "START was pressed this frame"
--     changeColor = true if "Y was pressed this frame"
--     moveX, moveY = current axis values for left stick
-----------------------------------------------------
function CharacterSelect.updateCharacter(input, playerIndex, dt)
    local ps = playerSelections[playerIndex]
    ps.moveCooldown = math.max(0, ps.moveCooldown - dt)
    ps.colorChangeCooldown = math.max(0, ps.colorChangeCooldown - dt)
    ps.inputDelay = math.max(0, ps.inputDelay - dt)

    -- 1) Move cursor left/right if not locked
    if (not ps.locked) and ps.moveCooldown <= 0 then
        local move = 0
        if input.moveX < -0.5 then move = -1
        elseif input.moveX >  0.5 then move =  1 end

        if move ~= 0 then
            -- Play cursor movement sound
            playCharacterSelectSound("counter")
            ps.cursor = ps.cursor + move
            if ps.cursor < 1 then
                ps.cursor = #characters
            elseif ps.cursor > #characters then
                ps.cursor = 1
            end
            ps.moveCooldown = 0.25
        end
    end

    -- 2) Y (changeColor) toggles through available colors (only if not locked and input delay is over)
    if input.y and ps.colorChangeCooldown <= 0 and ps.inputDelay <= 0 then
        cycleColor(playerIndex)
        ps.colorChangeCooldown = 0.2  -- 200ms cooldown
    end

    -- 3) If not locked, A (select) locks in character. If already locked, B (back) unlocks.
    if not ps.locked then
        if input.a and ps.inputDelay <= 0 then
            -- Play selection sound
            playCharacterSelectSound("downAir")
            ps.locked = true
        end
    else
        if input.b then
            -- Play unlock/back sound
            playCharacterSelectSound("shield")
            ps.locked = false
        end
    end
end

-----------------------------------------------------
-- Main update for the character select screen.
--   Relies on a global `justPressed[jid][button]` table,
--   which gets cleared each frame after consumption.
-----------------------------------------------------
function CharacterSelect.update(GameInfo)
    -- Force refresh controllers when in character select to catch any newly connected ones
    InputManager.refreshControllersImmediate()
    
    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()
    
    -- 1) If we just entered this screen, reset all selections AND clear any leftover justPressed so no input carries over:
    if GameInfo.justEnteredCharacterSelect then
        for i = 1, 2 do
            playerSelections[i].locked       = false
            playerSelections[i].cursor       = 1
            playerSelections[i].moveCooldown = 0
            playerSelections[i].colorIndex   = (i == 1) and 1 or 2
            playerSelections[i].colorChangeCooldown = 0.5  -- Increased delay to prevent carryover
            playerSelections[i].inputDelay = 0.3  -- 300ms delay to prevent input carryover
            playerSelections[i].backButtonSelected = false
            playerSelections[i].previousCursor = 1
            playerSelections[i].verticalMoveCooldown = 0
        end
        -- Only reset P2 controller assignment in 2P mode
        local isOnePlayer = (GameInfo.previousMode == "game_1P")
        local isStoryMode = (GameInfo.previousMode == "game_story")
        if not isOnePlayer and not isStoryMode then
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2KeyboardMapping = nil
            controllerAssignments[2] = nil
        end
        -- Initialize story mode if needed
        if isStoryMode then
            GameInfo.storyMode = true
            GameInfo.storyOpponentIndex = 1
            GameInfo.storyOpponents = {}
            GameInfo.storyOpponentColors = {}
        end
        -- Clear all justPressed entries so A/Y presses that opened this screen are ignored:
        justPressed = {}
        -- Clear keyboard edge detection
        clearKeyboardEdgeDetection()
        GameInfo.justEnteredCharacterSelect = false
    end

    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local isStoryMode = (GameInfo.previousMode == "game_story")
    local dt = love.timer.getDelta()

    -- Edge detection for kpenter and return (P2 keyboard assignment)
    CharacterSelect._p2KpenterReleased = CharacterSelect._p2KpenterReleased ~= false
    CharacterSelect._p2ReturnReleased = CharacterSelect._p2ReturnReleased ~= false
    if not isOnePlayer and not isP2Assigned() then
        -- Allow P2 to assign controller or keyboard ONLY with A (controller) or Enter (keyboard)
        for _, js in ipairs(love.joystick.getJoysticks()) do
            local jid = js:getID()
            if (justPressed[jid] and justPressed[jid]["a"]) and (GameInfo.p1InputType ~= js:getID()) then
                GameInfo.p2InputType = js:getID()
                GameInfo.player2Controller = js:getID()
                playCharacterSelectSound("downAir")
                justPressed[jid]["a"] = nil
                break
            end
        end
        if not love.keyboard.isDown("kpenter") then
            CharacterSelect._p2KpenterReleased = true
        end
        if not love.keyboard.isDown("return") then
            CharacterSelect._p2ReturnReleased = true
        end
        if (love.keyboard.isDown("kpenter") and CharacterSelect._p2KpenterReleased) or (love.keyboard.isDown("return") and CharacterSelect._p2ReturnReleased) then
            GameInfo.p2InputType = "keyboard"
            GameInfo.player2Controller = "keyboard"
            -- If P1 is using keyboard (mapping 1), P2 gets mapping 2; otherwise P2 gets mapping 1
            if GameInfo.p1InputType == "keyboard" then
                GameInfo.p2KeyboardMapping = 2
            else
                GameInfo.p2KeyboardMapping = 1
            end
            playCharacterSelectSound("downAir")
            CharacterSelect._p2KpenterReleased = false
            CharacterSelect._p2ReturnReleased = false
        end
        -- Do not process any other input for P2 until assigned
    end
    -- Unassign P2 if back is pressed and not locked
    if not isOnePlayer and isP2Assigned() and not playerSelections[2].locked then
        local unassign = false
        if GameInfo.p2InputType == "keyboard" then
            local kb = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
            if kb.b then unassign = true end
        else
            for _, js in ipairs(love.joystick.getJoysticks()) do
                if js:getID() == GameInfo.p2InputType and js:isGamepadDown("b") then
                    unassign = true
                end
            end
        end
        if unassign then
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2KeyboardMapping = nil
            return
        end
    end

    -- Edge detection for both players
    local justStates = {}
    for i = 1, 2 do
        justStates[i] = {}
    end
    -- P1 edge detection
    local p1Input = nil
    if GameInfo.p1InputType == "keyboard" then
        local kb = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
        for k,v in pairs(keyboardJustPressed) do
            if v then justStates[1][k] = true end
        end
        p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
    else
        local js = InputManager.getJoystick(GameInfo.player1Controller)
        if js then
            local jid = js:getID()
            justStates[1] = justPressed[jid] or {}
            justPressed[jid] = nil
            p1Input = InputManager.get(GameInfo.player1Controller)
        end
    end
    -- P2 edge detection
    local p2Input = nil
    if isOnePlayer then
        p2Input = p1Input
        justStates[2] = justStates[1]
    elseif GameInfo.p2InputType == "keyboard" then
        local kb = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
        for k,v in pairs(keyboardJustPressed) do
            if v then justStates[2][k] = true end
        end
        p2Input = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
    elseif GameInfo.p2InputType then
        local js = InputManager.getJoystick(GameInfo.player2Controller)
        if js then
            local jid = js:getID()
            justStates[2] = justPressed[jid] or {}
            justPressed[jid] = nil
            p2Input = InputManager.get(GameInfo.player2Controller)
        end
    end

    -- 1P mode or Story mode: handle B for deselect or exit
    if isOnePlayer or isStoryMode then
        -- Keyboard B
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed.b then
            if isOnePlayer and playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            elseif playerSelections[1].locked then
                playCharacterSelectSound("shield")
                playerSelections[1].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                -- Play back to menu sound
                playCharacterSelectSound("shield")
                GameInfo.gameState = "menu"
                clearKeyboardEdgeDetection()
                return
            end
        end
        -- Controller B (edge-detection)
        if GameInfo.p1InputType ~= "keyboard" and justStates[1] and justStates[1].b then
            if isOnePlayer and playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                return
            elseif playerSelections[1].locked then
                playCharacterSelectSound("shield")
                playerSelections[1].locked = false
                return
            else
                -- Play back to menu sound
                playCharacterSelectSound("shield")
                GameInfo.gameState = "menu"
                return
            end
        end
    end
    -- 2P mode: handle P2 B for deselect or unassign
    if not isOnePlayer and isP2Assigned() and GameInfo.p2InputType == "keyboard" then
        local kb = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
        if kb.b then
            if playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                GameInfo.p2KeyboardMapping = nil
                clearKeyboardEdgeDetection()
                return
            end
        end
    end
    if not isOnePlayer and isP2Assigned() and GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" then
        for _, js in ipairs(love.joystick.getJoysticks()) do
            if js:getID() == GameInfo.p2InputType and js:isGamepadDown("b") then
                if playerSelections[2].locked then
                    playCharacterSelectSound("shield")
                    playerSelections[2].locked = false
                    clearKeyboardEdgeDetection()
                    return
                else
                    GameInfo.p2InputType = nil
                    GameInfo.player2Controller = nil
                    GameInfo.p2KeyboardMapping = nil
                    clearKeyboardEdgeDetection()
                    return
                end
            end
        end
    end

    -- Handle back button navigation (up/down) for each player
    -- This needs to happen before character updates to prevent horizontal movement when on back button
    local function handleBackButtonNavigation(playerIndex, input, justState, dt)
        local ps = playerSelections[playerIndex]
        ps.verticalMoveCooldown = math.max(0, ps.verticalMoveCooldown - dt)
        
        -- Only handle navigation if not locked
        if ps.locked then
            return false
        end
        
        -- Check for down press to navigate to back button (from stick or keyboard)
        local moveDown = false
        if ps.verticalMoveCooldown <= 0 then
            if input and input.moveY > 0.5 then
                moveDown = true
            elseif justState and justState.down then
                moveDown = true
            end
        end
        
        -- Check for up press to navigate back to character selection (from stick or keyboard)
        local moveUp = false
        if ps.verticalMoveCooldown <= 0 then
            if input and input.moveY < -0.5 then
                moveUp = true
            elseif justState and justState.up then
                moveUp = true
            end
        end
        
        -- Navigate to back button
        if moveDown and not ps.backButtonSelected then
            ps.previousCursor = ps.cursor
            ps.backButtonSelected = true
            ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
            playCharacterSelectSound("counter")
        end
        
        -- Navigate back to character selection
        if moveUp and ps.backButtonSelected then
            ps.cursor = ps.previousCursor
            ps.backButtonSelected = false
            ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
            playCharacterSelectSound("counter")
        end
        
        -- Handle A press on back button
        local aPressed = (justState and justState.a) or false
        
        if aPressed and ps.backButtonSelected then
            -- Only allow the player who navigated to the back button to go back
            playCharacterSelectSound("downAir")
            GameInfo.gameState = "menu"
            return true  -- Signal that we're going back to menu
        end
        
        return false
    end
    
    -- Handle back button navigation for each active player
    if isOnePlayer or isStoryMode then
        -- In 1P/Story mode, handle for the active player (P1 if not locked, P2 if P1 is locked and in 1P mode)
        local activePlayer = (isOnePlayer and playerSelections[1].locked) and 2 or 1
        local activeInput = p1Input
        local activeJustState = justStates[1]
        
        if handleBackButtonNavigation(activePlayer, activeInput, activeJustState, dt) then
            clearKeyboardEdgeDetection()
            return
        end
    else
        -- In 2P mode, handle for both players independently
        if p1Input then
            if handleBackButtonNavigation(1, p1Input, justStates[1], dt) then
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p2InputType and p2Input then
            if handleBackButtonNavigation(2, p2Input, justStates[2], dt) then
                clearKeyboardEdgeDetection()
                return
            end
        end
    end

    -- Story mode: Start game when P1 locks in (no P2 selection needed)
    if isStoryMode and playerSelections[1].locked then
        local startPressed = false
        if justStates[1] and justStates[1].a then
            startPressed = true
        end
        if startPressed then
            -- Play fight start sound
            playCharacterSelectSound("heavyAttackBerserker")
            -- Clear edge-detected states after use
            if justStates[1] then
                justStates[1].a = nil
            end
            CharacterSelect.beginGame(GameInfo)
            clearKeyboardEdgeDetection()
            return
        end
    end

    -- Start game when both players are locked and any A button was just pressed.
    -- Check this BEFORE processing character updates to avoid clearing edge states first.
    if not isStoryMode and playerSelections[1].locked and playerSelections[2].locked then
        local startPressed = false
        if (justStates[1] and justStates[1].a) or (justStates[2] and justStates[2].a) then
            startPressed = true
        end
        if startPressed then
            -- Play fight start sound
            playCharacterSelectSound("heavyAttackBerserker")
            -- Clear edge-detected states after use
            if justStates[1] then
                justStates[1].a = nil
            end
            if justStates[2] then
                justStates[2].a = nil
            end
            CharacterSelect.beginGame(GameInfo)
            clearKeyboardEdgeDetection()
            return
        end
    end

    -- P1 always has input
    if isOnePlayer or isStoryMode then
        if not playerSelections[1].locked then
            if p1Input then
                -- Prevent horizontal movement when back button is selected
                local moveX = playerSelections[1].backButtonSelected and 0 or p1Input.moveX
                local aPressed = (justStates[1] and justStates[1].a) or false
                local yPressed = (justStates[1] and justStates[1].y) or false
                CharacterSelect.updateCharacter({
                    a = aPressed, b = false, y = yPressed,
                    moveX = moveX, moveY = p1Input.moveY
                }, 1, dt)
                -- Clear edge-detected states after use
                if justStates[1] then
                    justStates[1].a = nil
                    justStates[1].y = nil
                end
            end
        elseif isOnePlayer then
            -- Only handle P2 selection in 1P mode, not story mode
            if p1Input then
                -- Prevent horizontal movement when back button is selected
                local moveX = playerSelections[2].backButtonSelected and 0 or p1Input.moveX
                local aPressed = (justStates[1] and justStates[1].a) or false
                local yPressed = (justStates[1] and justStates[1].y) or false
                -- Only clear A button if P2 is not locked (we might use it to lock P2)
                -- If P2 is already locked, keep A for game start check
                local shouldClearA = not playerSelections[2].locked
                CharacterSelect.updateCharacter({
                    a = aPressed, b = false, y = yPressed,
                    moveX = moveX, moveY = p1Input.moveY
                }, 2, dt)
                -- Clear edge-detected states after use (only A if player wasn't locked)
                if justStates[1] then
                    if shouldClearA then
                        justStates[1].a = nil
                    end
                    justStates[1].y = nil
                end
            end
        end
    else
        if p1Input then
            -- Prevent horizontal movement when back button is selected
            local moveX = playerSelections[1].backButtonSelected and 0 or p1Input.moveX
            local aPressed = (justStates[1] and justStates[1].a) or false
            local yPressed = (justStates[1] and justStates[1].y) or false
            -- Only clear A button if P1 is not locked (we might use it to lock P1)
            -- If P1 is already locked, keep A for game start check
            local shouldClearA = not playerSelections[1].locked
            CharacterSelect.updateCharacter({
                a = aPressed, b = false, y = yPressed,
                moveX = moveX, moveY = p1Input.moveY
            }, 1, dt)
            -- Clear edge-detected states after use (only A if player wasn't locked)
            if justStates[1] then
                if shouldClearA then
                    justStates[1].a = nil
                end
                justStates[1].y = nil
            end
        end
        if GameInfo.p2InputType and p2Input then
            -- Prevent horizontal movement when back button is selected
            local moveX = playerSelections[2].backButtonSelected and 0 or p2Input.moveX
            local aPressed = (justStates[2] and justStates[2].a) or false
            local yPressed = (justStates[2] and justStates[2].y) or false
            -- Only clear A button if P2 is not locked (we might use it to lock P2)
            -- If P2 is already locked, keep A for game start check
            local shouldClearA = not playerSelections[2].locked
            CharacterSelect.updateCharacter({
                a = aPressed, b = false, y = yPressed,
                moveX = moveX, moveY = p2Input.moveY
            }, 2, dt)
            -- Clear edge-detected states after use (only A if player wasn't locked)
            if justStates[2] then
                if shouldClearA then
                    justStates[2].a = nil
                end
                justStates[2].y = nil
            end
        end
    end

    -- 2P mode: allow P1 to deselect or return to menu
    if not isOnePlayer then
        -- P1: Deselect if locked, else return to menu
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed.b then
            if playerSelections[1].locked then
                playCharacterSelectSound("shield")
                playerSelections[1].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                -- Play back to menu sound
                playCharacterSelectSound("shield")
                GameInfo.gameState = "menu"
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p1InputType ~= "keyboard" and justStates[1] and justStates[1].b then
            if playerSelections[1].locked then
                playCharacterSelectSound("shield")
                playerSelections[1].locked = false
                return
            else
                -- Play back to menu sound
                playCharacterSelectSound("shield")
                GameInfo.gameState = "menu"
                return
            end
        end
        -- P2: Deselect if locked, else unassign controller (one action per press)
        if GameInfo.p2InputType == "keyboard" and keyboardJustPressed.b then
            if playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            elseif not playerSelections[2].locked then
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                GameInfo.p2KeyboardMapping = nil
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" and justStates[2] and justStates[2].b then
            if playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                return
            elseif not playerSelections[2].locked then
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                GameInfo.p2KeyboardMapping = nil
                return
            end
        end
    end

    clearKeyboardEdgeDetection()
end

-----------------------------------------------------
-- Called when both players have locked in their characters (or P1 in story mode).
-----------------------------------------------------
function CharacterSelect.beginGame(GameInfo)
    local isStoryMode = (GameInfo.previousMode == "game_story")
    
    if isStoryMode then
        -- Story mode: only P1 selects
        GameInfo.storyPlayerCharacter = characters[playerSelections[1].cursor]
        GameInfo.storyPlayerColor = colorNames[playerSelections[1].colorIndex]
        
        -- Calculate opponents: exclude player's character from [Warrior, Berserk, Lancer, Mage]
        local allCharacters = {"Warrior", "Berserk", "Lancer", "Mage"}
        GameInfo.storyOpponents = {}
        for _, char in ipairs(allCharacters) do
            if char ~= GameInfo.storyPlayerCharacter then
                table.insert(GameInfo.storyOpponents, char)
            end
        end
        
        -- Calculate opponent colors: exclude player's color from [Blue, Red, Yellow, Gray]
        local allColors = {"Blue", "Red", "Yellow", "Gray"}
        GameInfo.storyOpponentColors = {}
        for _, color in ipairs(allColors) do
            if color ~= GameInfo.storyPlayerColor then
                table.insert(GameInfo.storyOpponentColors, color)
            end
        end
        
        -- Set up for first opponent
        GameInfo.storyOpponentIndex = 1
        GameInfo.player1Character = GameInfo.storyPlayerCharacter
        GameInfo.player1Color = GameInfo.storyPlayerColor
        GameInfo.player2Character = GameInfo.storyOpponents[1]
        GameInfo.player2Color = GameInfo.storyOpponentColors[1]
    else
        -- Normal mode: both players select
        GameInfo.player1Character = characters[playerSelections[1].cursor]
        GameInfo.player2Character = characters[playerSelections[2].cursor]

        GameInfo.player1Color = colorNames[playerSelections[1].colorIndex]
        GameInfo.player2Color = colorNames[playerSelections[2].colorIndex]
    end

    -- The controller assignments are already set in GameInfo from the input assignment process
    -- No need to override them here

    -- Clear all input states to prevent button press from carrying over
    justPressed = {}
    clearKeyboardEdgeDetection()
    
    -- Set delay before starting the game (0.5 seconds)
    GameInfo.gameStartDelay = 0.5
    GameInfo.gameState = "game_starting"
end

-----------------------------------------------------
-- Draw the character select screen (unchanged from before).
-----------------------------------------------------
function CharacterSelect.draw(GameInfo)
    love.graphics.clear(0, 0, 0, 1)

    local gameWidth   = GameInfo.gameWidth
    local gameHeight  = GameInfo.gameHeight
    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local isStoryMode = (GameInfo.previousMode == "game_story")
    
    -- Check if all players are locked (same condition as "Press A to begin!" message)
    local allPlayersLocked = (isStoryMode and playerSelections[1].locked) or
                             (not isStoryMode and playerSelections[1].locked and playerSelections[2].locked)

    -- === Draw player info boxes at the top ===
    local boxWidth   = 16
    local boxHeight  = 16
    local paddingX   = 32
    local paddingY   = 10

    local p1BoxX = paddingX
    local p1BoxY = paddingY
    local p2BoxX = gameWidth - boxWidth - paddingX
    local p2BoxY = paddingY

    local function getPlayerColor(playerIndex)
        local ci = playerSelections[playerIndex].colorIndex
        return colorOptions[ci][1], colorOptions[ci][2], colorOptions[ci][3]
    end

    -- --- Draw Player 1's box ---
    if playerSelections[1].locked then
        love.graphics.setColor(getPlayerColor(1))
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.rectangle("line", p1BoxX, p1BoxY, boxWidth, boxHeight)
    local p1Char = characters[playerSelections[1].cursor]
    if p1Char == "Warrior" or p1Char == "Berserk" or p1Char == "Lancer" or p1Char == "Mage" then
        local colName = colorNames[playerSelections[1].colorIndex]
        local image, quad, spriteW, spriteH
        if p1Char == "Warrior" then
            image, quad = sprites.Warrior[colName], warriorQuad
            spriteW, spriteH = 8, 8
        elseif p1Char == "Berserk" then
            image, quad = sprites.Berserk[colName], berserkQuad
            spriteW, spriteH = 12, 12
        elseif p1Char == "Lancer" then
            image, quad = sprites.Lancer[colName], lancerQuad
            spriteW, spriteH = 12, 12
        elseif p1Char == "Mage" then
            image, quad = sprites.Mage[colName], mageQuad
            spriteW, spriteH = 12, 12
        end
        local offsetX = (boxWidth - spriteW) / 2
        local offsetY = (boxHeight - spriteH) / 2
        love.graphics.draw(image, quad, p1BoxX + offsetX, p1BoxY + offsetY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 1", p1BoxX - boxWidth/2 - 22, p1BoxY - 9, boxWidth*5, "center", 0, 1, 1)

    -- --- Draw Player 2's box ---
    if not isStoryMode then
        if playerSelections[2].locked then
            love.graphics.setColor(getPlayerColor(2))
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.rectangle("line", p2BoxX, p2BoxY, boxWidth, boxHeight)
        local p2Char = characters[playerSelections[2].cursor]
        if p2Char == "Warrior" or p2Char == "Berserk" or p2Char == "Lancer" or p2Char == "Mage" then
            local colName = colorNames[playerSelections[2].colorIndex]
            local image, quad, spriteW, spriteH
            if p2Char == "Warrior" then
                image, quad = sprites.Warrior[colName], warriorQuad
                spriteW, spriteH = 8, 8
            elseif p2Char == "Berserk" then
                image, quad = sprites.Berserk[colName], berserkQuad
                spriteW, spriteH = 12, 12
            elseif p2Char == "Lancer" then
                image, quad = sprites.Lancer[colName], lancerQuad
                spriteW, spriteH = 12, 12
            elseif p2Char == "Mage" then
                image, quad = sprites.Mage[colName], mageQuad
                spriteW, spriteH = 12, 12
            end
            local offsetX = (boxWidth - spriteW) / 2
            local offsetY = (boxHeight - spriteH) / 2
            love.graphics.draw(image, quad, p2BoxX + offsetX, p2BoxY + offsetY)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Player 2", p2BoxX - boxWidth/2 - 22, p2BoxY - 9, boxWidth*5, "center", 0, 1, 1)
    end

    -- === Draw character boxes in the center ===
    -- Only draw if not all players are locked
    if not allPlayersLocked then
        local charBoxWidth   = 16
        local charBoxHeight  = 16
        local startX         = 6
        local startY         = p1BoxY + boxHeight + 12 
        local charBoxPadding = 16

        for i, charName in ipairs(characters) do
            local x = startX + (i - 1) * (charBoxWidth + charBoxPadding)
            local y = startY
            love.graphics.rectangle("line", x, y, charBoxWidth, charBoxHeight)

            -- Draw a gray preview if we have a sprite
            if charName == "Warrior" then
                local image, quad = sprites.Warrior["Gray"], warriorQuad
                local spriteW, spriteH = 8, 8
                local offsetX = (charBoxWidth - spriteW) / 2
                local offsetY = (charBoxHeight - spriteH) / 2
                love.graphics.draw(image, quad, x + offsetX, y + offsetY, 0, 1, 1, 0, -1)
            elseif charName == "Berserk" then
                local image, quad = sprites.Berserk["Gray"], berserkQuad
                local spriteW, spriteH = 12, 12
                local offsetX = (charBoxWidth - spriteW) / 2
                local offsetY = (charBoxHeight - spriteH) / 2
                love.graphics.draw(image, quad, x + offsetX, y + offsetY)
            elseif charName == "Lancer" then
                local image, quad = sprites.Lancer["Gray"], lancerQuad
                local spriteW, spriteH = 12, 12
                local offsetX = (charBoxWidth - spriteW) / 2
                local offsetY = (charBoxHeight - spriteH) / 2
                love.graphics.draw(image, quad, x + offsetX, y + offsetY)
            elseif charName == "Mage" and sprites.Mage["Gray"] then
                local image, quad = sprites.Mage["Gray"], mageQuad
                local spriteW, spriteH = 12, 12
                local offsetX = (charBoxWidth - spriteW) / 2
                local offsetY = (charBoxHeight - spriteH) / 2
                love.graphics.draw(image, quad, x + offsetX, y + offsetY)
            else
                -- No sprite, so just draw a gray box
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
                love.graphics.rectangle("fill", x + 1, y + 1, charBoxWidth - 2, charBoxHeight - 2)
                love.graphics.setColor(1, 1, 1, 1)
            end

            love.graphics.printf(
              charName,
              x - charBoxWidth * 2,
              y - charBoxHeight/2 - 1,
              charBoxWidth * 5,
              "center",
              0, 1, 1
            )
        end

        -- === Draw each player's cursor below the character boxes ===
        local cursorY     = startY + charBoxHeight + 7
        local arrowSize   = 5
        local charSpacing = charBoxPadding

        for playerIndex = 1, 2 do
            if isStoryMode and playerIndex == 2 then
                -- Hide P2 cursor in story mode
            elseif isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
                -- Hide CPU's cursor until P1 locks
            elseif not isOnePlayer and not isStoryMode and playerIndex == 2 and not isP2Assigned() then
                -- Hide P2 cursor in 2P mode until P2 joins
            else
                local cs = playerSelections[playerIndex]
                -- Only draw arrow if back button is not selected for this player
                if not cs.backButtonSelected then
                    local cursorIndex = cs.cursor
                    local offsetX = (playerIndex == 1) and -3 or 3
                    local x = startX + (cursorIndex - 1) * (charBoxWidth + charSpacing)
                             + charBoxWidth/2 + offsetX
                    local y = cursorY

                    love.graphics.setColor(getPlayerColor(playerIndex))
                    love.graphics.polygon(
                      "fill",
                      x - arrowSize/2, y,
                      x + arrowSize/2, y,
                      x, y - arrowSize
                    )
                    love.graphics.setColor(1, 1, 1, 1)
                end
            end
        end
    end

    -- If both locked (or P1 locked in story mode), prompt "Press A to begin!"
    if isStoryMode and playerSelections[1].locked then
        love.graphics.printf(
          "Press A to begin!",
          0,
          gameHeight/2,
          gameWidth, "center", 0, 1, 1
        )
    elseif not isStoryMode and playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf(
          "Press A to begin!",
          0,
          gameHeight/2,
          gameWidth, "center", 0, 1, 1
        )
    end
    
    -- Draw back button in bottom left
    love.graphics.setColor(1, 1, 1, 1)
    local backTextX = 4
    local backTextY = gameHeight - 10
    love.graphics.printf("Back", backTextX, backTextY, gameWidth, "left", 0, 1, 1)
    
    -- Draw player arrows to the right of "Back" text when back button is selected
    local backTextWidth = font:getWidth("Back")
    local arrowSize = 5
    local arrowSpacing = 8  -- Space between arrows if multiple players select back
    local baseArrowX = backTextX + backTextWidth + 1  -- Position arrow to the right of text
    local arrowY = backTextY + 5  -- Center vertically with text
    
    -- Draw arrow for each player who has selected the back button
    local arrowOffset = 0
    for playerIndex = 1, 2 do
        if playerSelections[playerIndex].backButtonSelected then
            local arrowX = baseArrowX + arrowOffset
            love.graphics.setColor(getPlayerColor(playerIndex))
            -- Draw left-pointing arrow (triangle pointing left)
            love.graphics.polygon(
                "fill",
                arrowX, arrowY,  -- Left point
                arrowX + arrowSize, arrowY - arrowSize/2,  -- Top right
                arrowX + arrowSize, arrowY + arrowSize/2   -- Bottom right
            )
            love.graphics.setColor(1, 1, 1, 1)
            arrowOffset = arrowOffset + arrowSpacing  -- Offset next arrow if both players select
        end
    end
    
    -- Show P2 assignment prompt if needed
    if not isOnePlayer and not isStoryMode and not isP2Assigned() then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            "P2: Press to Join",
            0, gameHeight - 10,
            gameWidth, "center"
        )
        return
    end

    -- Show keyboard controls if keyboard is enabled
    -- if GameInfo.p1InputType == "keyboard" or GameInfo.p2InputType == "keyboard" then
    --     love.graphics.setColor(0.7, 0.7, 0.7, 1)
    --     love.graphics.printf("P1: WASD/Space, P2: Arrows/Keypad0, K/L: Color, Shift: Back", 0, gameHeight - 20, gameWidth, "center", 0, 1, 1)
    -- end
end

return CharacterSelect
