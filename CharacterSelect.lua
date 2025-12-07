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
    {181/255, 26/255, 223/255},  -- Purple
    {241/255, 225/255, 115/255},  -- Yellow
}
local colorNames = {"Blue", "Red", "Purple", "Yellow", "Gray"}

-- List of characters
local characters = {"Warrior", "Berserk", "Lancer", "Mage"}

-- Load sprite sheets for the characters that have sprites
local sprites = {
    Warrior = {
       Red    = love.graphics.newImage("assets/sprites/WarriorRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/WarriorBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/WarriorYellow.png"),
       Purple   = love.graphics.newImage("assets/sprites/WarriorPurple.png"),
       Gray   = love.graphics.newImage("assets/sprites/WarriorGray.png")
    },
    Berserk = {
       Red    = love.graphics.newImage("assets/sprites/BerserkRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/BerserkBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/BerserkYellow.png"),
       Purple   = love.graphics.newImage("assets/sprites/BerserkPurple.png"),
       Gray   = love.graphics.newImage("assets/sprites/BerserkGray.png")
    },
    Lancer = {
        Red    = love.graphics.newImage("assets/sprites/LancerRed.png"),
        Blue   = love.graphics.newImage("assets/sprites/LancerBlue.png"),
        Yellow = love.graphics.newImage("assets/sprites/LancerYellow.png"),
        Purple   = love.graphics.newImage("assets/sprites/LancerPurple.png"),
        Gray   = love.graphics.newImage("assets/sprites/LancerGray.png")
        },
    Mage = {
        Red    = love.graphics.newImage("assets/sprites/MageRed.png"),
        Blue   = love.graphics.newImage("assets/sprites/MageBlue.png"),
        Yellow = love.graphics.newImage("assets/sprites/MageYellow.png"),
        Purple   = love.graphics.newImage("assets/sprites/MagePurple.png"),
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

-- Load box sprite and create quads for all box variants
local boxImage = love.graphics.newImage("assets/sprites/boxes.png")
local boxImageWidth = boxImage:getWidth()
local boxImageHeight = boxImage:getHeight()

-- Helper function to get box quad based on row (0=deselected, 1=selected) and column (0-4)
-- Columns: 0=white, 1=yellow, 2=blue, 3=purple, 4=red
local function getBoxQuad(row, col)
    local boxSize = 16
    local x = col * boxSize
    local y = row * boxSize
    return love.graphics.newQuad(
        x, y, boxSize, boxSize,
        boxImageWidth,
        boxImageHeight
    )
end

-- Map colorIndex to box column
-- colorIndex 1 = Blue = column 2
-- colorIndex 2 = Red = column 4
-- colorIndex 3 = Purple = column 3
-- colorIndex 4 = Yellow = column 1
local function getColorColumn(colorIndex)
    local colorToColumn = {
        [1] = 2,  -- Blue
        [2] = 4,  -- Red
        [3] = 3,  -- Purple
        [4] = 1   -- Yellow
    }
    return colorToColumn[colorIndex] or 0  -- Default to white (column 0)
end

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
--   remapButtonSelected: whether this player has navigated to the remap button
--   remapButtonPreviousCursor: cursor position before navigating to remap button
local playerSelections = {
    [1] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 1, colorChangeCooldown = 0, inputDelay = 0, backButtonSelected = false, previousCursor = 1, verticalMoveCooldown = 0, remapButtonSelected = false, remapButtonPreviousCursor = 1 },
    [2] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 2, colorChangeCooldown = 0, inputDelay = 0, backButtonSelected = false, previousCursor = 1, verticalMoveCooldown = 0, remapButtonSelected = false, remapButtonPreviousCursor = 1 }
}

-- Controller assignment tracking
local controllerAssignments = {
    [1] = nil,  -- Player 1's controller index
    [2] = nil   -- Player 2's controller index
}

-- Keyboard edge detection state - separate per player mapping
local keyboardJustPressed = {
    [1] = {
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
    },
    [2] = {
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
}

-- Track previous key states for proper edge detection
local keyboardPrevState = {
    [1] = {},
    [2] = {}
}

-- Update keyboard edge detection
local function updateKeyboardEdgeDetection()
    local keyboardMap1 = InputManager.getKeyboardMapping(1)
    local keyboardMap2 = InputManager.getKeyboardMapping(2)
    
    -- Update for player 1 mapping
    local keys1 = {"a", "b", "x", "y", "start", "back", "left", "right", "up", "down"}
    for _, key in ipairs(keys1) do
        local keyName = keyboardMap1[key]
        if keyName then
            local isDown = love.keyboard.isDown(keyName)
            local wasDown = keyboardPrevState[1][key] or false
            
            -- Edge detection: only true on transition from not-pressed to pressed
            keyboardJustPressed[1][key] = isDown and not wasDown
            keyboardPrevState[1][key] = isDown
        else
            -- If keyName is nil, mark as not pressed
            keyboardJustPressed[1][key] = false
            keyboardPrevState[1][key] = false
        end
    end
    
    -- Update for player 2 mapping
    local keys2 = {"a", "b", "x", "y", "start", "back", "left", "right", "up", "down"}
    for _, key in ipairs(keys2) do
        local keyName = keyboardMap2[key]
        if keyName then
            local isDown = love.keyboard.isDown(keyName)
            local wasDown = keyboardPrevState[2][key] or false
            
            -- Edge detection: only true on transition from not-pressed to pressed
            keyboardJustPressed[2][key] = isDown and not wasDown
            keyboardPrevState[2][key] = isDown
        else
            -- If keyName is nil, mark as not pressed
            keyboardJustPressed[2][key] = false
            keyboardPrevState[2][key] = false
        end
    end
end

-- Clear keyboard edge detection (call this after processing input)
local function clearKeyboardEdgeDetection()
    for playerIndex = 1, 2 do
        for key, _ in pairs(keyboardJustPressed[playerIndex]) do
            keyboardJustPressed[playerIndex][key] = false
        end
    end
end

-- Reset keyboard previous state to current state (call when entering character select)
local function resetKeyboardPrevState()
    local keyboardMap1 = InputManager.getKeyboardMapping(1)
    local keyboardMap2 = InputManager.getKeyboardMapping(2)
    
    -- Reset for player 1 mapping
    local keys1 = {"a", "b", "x", "y", "start", "back", "left", "right", "up", "down"}
    for _, key in ipairs(keys1) do
        local keyName = keyboardMap1[key]
        if keyName then
            keyboardPrevState[1][key] = love.keyboard.isDown(keyName)
        else
            keyboardPrevState[1][key] = false
        end
    end
    
    -- Reset for player 2 mapping
    local keys2 = {"a", "b", "x", "y", "start", "back", "left", "right", "up", "down"}
    for _, key in ipairs(keys2) do
        local keyName = keyboardMap2[key]
        if keyName then
            keyboardPrevState[2][key] = love.keyboard.isDown(keyName)
        else
            keyboardPrevState[2][key] = false
        end
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
    
    -- Debug: Verify p1InputType persistence (only log once when entering)
    if GameInfo.justEnteredCharacterSelect then
        print("[CharacterSelect] Entering character select. p1InputType: " .. tostring(GameInfo.p1InputType) .. ", p1KeyboardMapping: " .. tostring(GameInfo.p1KeyboardMapping))
    end
    
    -- 1) If we just entered this screen, reset all selections AND clear any leftover justPressed so no input carries over:
    if GameInfo.justEnteredCharacterSelect then
        -- Check mode before initializing to set P2 colorIndex appropriately
        local isOnePlayer = (GameInfo.previousMode == "game_1P")
        local isStoryMode = (GameInfo.previousMode == "game_story")
        
        for i = 1, 2 do
            playerSelections[i].locked       = false
            playerSelections[i].cursor       = 1
            playerSelections[i].moveCooldown = 0
            -- In 1P mode, P2's colorIndex is nil until P1 locks in
            if i == 1 then
                playerSelections[i].colorIndex = 1
            elseif isOnePlayer then
                playerSelections[i].colorIndex = nil
            else
                playerSelections[i].colorIndex = 2
            end
            playerSelections[i].colorChangeCooldown = 0.5  -- Increased delay to prevent carryover
            playerSelections[i].inputDelay = 0.3  -- 300ms delay to prevent input carryover
            playerSelections[i].backButtonSelected = false
            playerSelections[i].previousCursor = 1
            playerSelections[i].verticalMoveCooldown = 0
            playerSelections[i].remapButtonSelected = false
            playerSelections[i].remapButtonPreviousCursor = 1
        end
        -- Only reset P2 controller assignment in 2P mode
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
            -- Reset health and stocks for fresh start of gauntlet mode
            GameInfo.storyPlayerHealth = nil
            GameInfo.storyPlayerStocks = nil
        end
        -- Clear all justPressed entries so A/Y presses that opened this screen are ignored:
        justPressed = {}
        -- Clear keyboard edge detection
        clearKeyboardEdgeDetection()
        -- Reset keyboard previous state to current state so held keys don't block input
        resetKeyboardPrevState()
        GameInfo.justEnteredCharacterSelect = false
    end

    -- Update keyboard edge detection (after reset if we just entered)
    updateKeyboardEdgeDetection()

    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local isStoryMode = (GameInfo.previousMode == "game_story")
    local dt = love.timer.getDelta()

    -- Edge detection for kpenter and return (P2 keyboard assignment)
    CharacterSelect._p2KpenterReleased = CharacterSelect._p2KpenterReleased ~= false
    CharacterSelect._p2ReturnReleased = CharacterSelect._p2ReturnReleased ~= false
    if not isOnePlayer and not isP2Assigned() then
        -- Allow P2 to assign controller or keyboard ONLY with A (controller) or Enter (keyboard)
        -- Check all joysticks for A press, but don't consume justPressed yet (will be consumed in edge detection)
        for _, js in ipairs(love.joystick.getJoysticks()) do
            local jid = js:getID()
            -- Check if this controller is not P1's controller and A was just pressed
            if (justPressed[jid] and justPressed[jid]["a"]) and (GameInfo.p1InputType ~= js:getID()) then
                GameInfo.p2InputType = js:getID()
                GameInfo.player2Controller = js:getID()
                playCharacterSelectSound("downAir")
                -- Consume the justPressed entry so it doesn't get processed again
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
            -- Assign keyboard mapping to P2:
            -- - If P1 is using keyboard, P2 gets the second keyboard mapping (2)
            -- - If P1 is using gamepad (or anything else), P2 gets the main keyboard mapping (1)
            print("[CharacterSelect] P2 joining with keyboard. P1 inputType: " .. tostring(GameInfo.p1InputType) .. " (type: " .. type(GameInfo.p1InputType) .. ")")
            -- Explicitly check if P1 is using keyboard
            if GameInfo.p1InputType == "keyboard" then
                GameInfo.p2KeyboardMapping = 2
                print("[CharacterSelect] P1 is using keyboard, assigning P2 mapping 2")
            else
                -- P1 is using a gamepad (p1InputType is a number/joystick ID) or nil, so P2 gets the main keyboard mapping
                GameInfo.p2KeyboardMapping = 1
                print("[CharacterSelect] P1 is using gamepad (or nil), assigning P2 mapping 1. p1InputType=" .. tostring(GameInfo.p1InputType))
            end
            print("[CharacterSelect] Final p2KeyboardMapping: " .. tostring(GameInfo.p2KeyboardMapping))
            playCharacterSelectSound("downAir")
            CharacterSelect._p2KpenterReleased = false
            CharacterSelect._p2ReturnReleased = false
        end
        -- Do not process any other input for P2 until assigned
    end
    -- Edge detection for both players (needed early for P2 join check)
    local justStates = {}
    for i = 1, 2 do
        justStates[i] = {}
    end
    -- P1 edge detection (only consume justPressed for P1's assigned controller)
    local p1Input = nil
    if GameInfo.p1InputType == "keyboard" then
        local p1Mapping = GameInfo.p1KeyboardMapping or 1
        -- Ensure keyboardJustPressed table exists for this mapping
        if keyboardJustPressed[p1Mapping] then
            for k,v in pairs(keyboardJustPressed[p1Mapping]) do
                if v then justStates[1][k] = true end
            end
        end
        p1Input = InputManager.getKeyboardInput(p1Mapping, true)  -- useMenuDefaults = true
        -- Defensive check: ensure p1Input is not nil
        if not p1Input then
            print("[CharacterSelect] WARNING: p1Input is nil for keyboard mapping " .. tostring(p1Mapping))
        end
    elseif GameInfo.p1InputType then
        -- Only consume justPressed if P1 has an assigned controller (not nil)
        local js = InputManager.getJoystick(GameInfo.player1Controller)
        if js then
            local jid = js:getID()
            justStates[1] = justPressed[jid] or {}
            justPressed[jid] = nil
            p1Input = InputManager.get(GameInfo.player1Controller, true)  -- useMenuDefaults = true
        end
    end
    -- P2 edge detection (also check for unassigned controllers for join)
    local p2Input = nil
    if isOnePlayer then
        p2Input = p1Input
        justStates[2] = justStates[1]
    elseif GameInfo.p2InputType == "keyboard" then
        local kb = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2, true)  -- useMenuDefaults = true
        local p2Mapping = GameInfo.p2KeyboardMapping or 2
        for k,v in pairs(keyboardJustPressed[p2Mapping]) do
            if v then justStates[2][k] = true end
        end
        p2Input = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2, true)  -- useMenuDefaults = true
    elseif GameInfo.p2InputType then
        local js = InputManager.getJoystick(GameInfo.player2Controller)
        if js then
            local jid = js:getID()
            justStates[2] = justPressed[jid] or {}
            justPressed[jid] = nil
            p2Input = InputManager.get(GameInfo.player2Controller, true)  -- useMenuDefaults = true
        end
    end

    -- Unassign P2 if back is pressed and not locked (using edge detection)
    if not isOnePlayer and isP2Assigned() and not playerSelections[2].locked then
        local unassign = false
        if GameInfo.p2InputType == "keyboard" then
            local p2Mapping = GameInfo.p2KeyboardMapping or 2
            if keyboardJustPressed[p2Mapping] and keyboardJustPressed[p2Mapping].b then
                unassign = true
            end
        else
            -- Use edge-detected justStates instead of isGamepadDown
            if justStates[2] and justStates[2].b then
                unassign = true
            end
        end
        if unassign then
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2KeyboardMapping = nil
            -- Clear the edge state since we consumed it
            if justStates[2] then
                justStates[2].b = nil
            end
            clearKeyboardEdgeDetection()
            return
        end
    end

    -- 1P mode or Story mode: handle B for deselect or exit
    if isOnePlayer or isStoryMode then
        -- Keyboard B
        local p1Mapping = GameInfo.p1KeyboardMapping or 1
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed[p1Mapping] and keyboardJustPressed[p1Mapping].b then
            if isOnePlayer and playerSelections[2].locked then
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            elseif playerSelections[1].locked then
                playCharacterSelectSound("shield")
                playerSelections[1].locked = false
                -- In 1P mode, reset P2's colorIndex when P1 unlocks
                if isOnePlayer then
                    playerSelections[2].colorIndex = nil
                end
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
                -- In 1P mode, reset P2's colorIndex when P1 unlocks
                if isOnePlayer then
                    playerSelections[2].colorIndex = nil
                end
                return
            else
                -- Play back to menu sound
                playCharacterSelectSound("shield")
                GameInfo.gameState = "menu"
                return
            end
        end
    end
    -- 2P mode: handle P2 B for deselect or unassign (using edge detection)
    if not isOnePlayer and isP2Assigned() then
        local p2BPressed = false
        if GameInfo.p2InputType == "keyboard" then
            local p2Mapping = GameInfo.p2KeyboardMapping or 2
            p2BPressed = keyboardJustPressed[p2Mapping].b or false
        elseif GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" then
            -- Use edge-detected justStates instead of isGamepadDown
            p2BPressed = (justStates[2] and justStates[2].b) or false
        end
        
        if p2BPressed then
            if playerSelections[2].locked then
                -- Only deselect, don't unassign
                playCharacterSelectSound("shield")
                playerSelections[2].locked = false
                -- Clear the edge state since we consumed it
                if justStates[2] then
                    justStates[2].b = nil
                end
                clearKeyboardEdgeDetection()
                return
            else
                -- Unassign only if not locked (handled earlier, but keep for safety)
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                GameInfo.p2KeyboardMapping = nil
                -- Clear the edge state since we consumed it
                if justStates[2] then
                    justStates[2].b = nil
                end
                clearKeyboardEdgeDetection()
                return
            end
        end
    end

    -- Handle back button navigation (up/down/left/right) for each player
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
        
        -- Check for right press to navigate to remap button (when on back button)
        local moveRight = false
        if ps.verticalMoveCooldown <= 0 and ps.backButtonSelected then
            if input and input.moveX > 0.5 then
                moveRight = true
            elseif justState and justState.right then
                moveRight = true
            end
        end
        
        -- Navigate to back button (only from left side character boxes: cursor 1 or 2)
        if moveDown and not ps.backButtonSelected and not ps.remapButtonSelected then
            -- Only allow navigation to back button if on left side characters (1 or 2)
            if ps.cursor == 1 or ps.cursor == 2 then
                ps.previousCursor = ps.cursor
                ps.backButtonSelected = true
                ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
                playCharacterSelectSound("counter")
            end
        end
        
        -- Navigate back to character selection
        if moveUp and ps.backButtonSelected then
            ps.cursor = ps.previousCursor
            ps.backButtonSelected = false
            ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
            playCharacterSelectSound("counter")
        end
        
        -- Navigate from back button to remap button
        if moveRight and ps.backButtonSelected then
            ps.backButtonSelected = false
            ps.remapButtonSelected = true
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
    
    -- Handle remap button navigation (right side, opposite to back button)
    local function handleRemapButtonNavigation(playerIndex, input, justState, dt)
        local ps = playerSelections[playerIndex]
        ps.verticalMoveCooldown = math.max(0, ps.verticalMoveCooldown - dt)
        
        -- Only handle navigation if not locked
        if ps.locked then
            return false
        end
        
        -- Check for down press to navigate to remap button (from stick or keyboard)
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
        
        -- Check for left press to navigate to back button (when on remap button)
        local moveLeft = false
        if ps.verticalMoveCooldown <= 0 and ps.remapButtonSelected then
            if input and input.moveX < -0.5 then
                moveLeft = true
            elseif justState and justState.left then
                moveLeft = true
            end
        end
        
        -- Navigate to remap button (right side) - from character selection with down (only from right side: cursor 3 or 4)
        if moveDown and not ps.remapButtonSelected and not ps.backButtonSelected then
            -- Only allow navigation to remap button if on right side characters (3 or 4)
            if ps.cursor == 3 or ps.cursor == 4 then
                ps.remapButtonPreviousCursor = ps.cursor
                ps.remapButtonSelected = true
                ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
                playCharacterSelectSound("counter")
            end
        end
        
        -- Navigate back to character selection
        if moveUp and ps.remapButtonSelected then
            ps.cursor = ps.remapButtonPreviousCursor
            ps.remapButtonSelected = false
            ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
            playCharacterSelectSound("counter")
        end
        
        -- Navigate from remap button to back button
        if moveLeft and ps.remapButtonSelected then
            ps.remapButtonSelected = false
            ps.backButtonSelected = true
            ps.verticalMoveCooldown = 0.25  -- 250ms cooldown
            playCharacterSelectSound("counter")
        end
        
        -- Handle A press on remap button
        local aPressed = (justState and justState.a) or false
        
        if aPressed and ps.remapButtonSelected then
            -- Open remap menu for this player
            -- In 1 Player mode, always remap P1 controls (P2 is CPU)
            local remapPlayer = playerIndex
            if GameInfo.previousMode == "game_1P" then
                remapPlayer = 1
            end
            playCharacterSelectSound("downAir")
            GameInfo.remapMenuActive = true
            GameInfo.remapMenuPlayer = remapPlayer
            GameInfo.remapMenuSelectedOption = 1
            GameInfo.remapMenuRemapping = nil
            return true  -- Signal that we're opening remap menu
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
        
        -- Handle remap button navigation
        if handleRemapButtonNavigation(activePlayer, activeInput, activeJustState, dt) then
            clearKeyboardEdgeDetection()
            return
        end
    else
        -- In 2P mode, handle for both players independently
        -- Defensive check: if p1InputType is keyboard but p1Input is nil, log warning
        if GameInfo.p1InputType == "keyboard" and not p1Input then
            print("[CharacterSelect] WARNING: p1InputType is 'keyboard' but p1Input is nil. Mapping: " .. tostring(GameInfo.p1KeyboardMapping or 1))
        end
        if p1Input then
            if handleBackButtonNavigation(1, p1Input, justStates[1], dt) then
                clearKeyboardEdgeDetection()
                return
            end
            if handleRemapButtonNavigation(1, p1Input, justStates[1], dt) then
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p2InputType and p2Input then
            if handleBackButtonNavigation(2, p2Input, justStates[2], dt) then
                clearKeyboardEdgeDetection()
                return
            end
            if handleRemapButtonNavigation(2, p2Input, justStates[2], dt) then
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
            -- Defensive check: if p1InputType is keyboard but p1Input is nil, log warning
            if GameInfo.p1InputType == "keyboard" and not p1Input then
                print("[CharacterSelect] WARNING: p1InputType is 'keyboard' but p1Input is nil. Mapping: " .. tostring(GameInfo.p1KeyboardMapping or 1))
            end
            if p1Input then
                -- Prevent horizontal movement when back button or remap button is selected
                local moveX = (playerSelections[1].backButtonSelected or playerSelections[1].remapButtonSelected) and 0 or p1Input.moveX
                local aPressed = (justStates[1] and justStates[1].a) or false
                local yPressed = (justStates[1] and justStates[1].y) or false
                local wasLocked = playerSelections[1].locked
                CharacterSelect.updateCharacter({
                    a = aPressed, b = false, y = yPressed,
                    moveX = moveX, moveY = p1Input.moveY
                }, 1, dt)
                -- If P1 just locked in 1P mode, assign P2 a color
                if isOnePlayer and not wasLocked and playerSelections[1].locked and playerSelections[2].colorIndex == nil then
                    -- Assign P2 the first color that's different from P1's color
                    local p1ColorIndex = playerSelections[1].colorIndex
                    for colorIdx = 1, #colorOptions do
                        if colorIdx ~= p1ColorIndex then
                            playerSelections[2].colorIndex = colorIdx
                            break
                        end
                    end
                    -- Fallback: if somehow all colors match (shouldn't happen), use color 2
                    if playerSelections[2].colorIndex == nil then
                        playerSelections[2].colorIndex = 2
                    end
                end
                -- Clear edge-detected states after use
                if justStates[1] then
                    justStates[1].a = nil
                    justStates[1].y = nil
                end
            end
        elseif isOnePlayer then
            -- Only handle P2 selection in 1P mode, not story mode
            if p1Input then
                -- Prevent horizontal movement when back button or remap button is selected
                local moveX = (playerSelections[2].backButtonSelected or playerSelections[2].remapButtonSelected) and 0 or p1Input.moveX
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
        -- Defensive check: if p1InputType is keyboard but p1Input is nil, log warning
        if GameInfo.p1InputType == "keyboard" and not p1Input then
            print("[CharacterSelect] WARNING: p1InputType is 'keyboard' but p1Input is nil. Mapping: " .. tostring(GameInfo.p1KeyboardMapping or 1))
        end
        if p1Input then
            -- Prevent horizontal movement when back button or remap button is selected
            local moveX = (playerSelections[1].backButtonSelected or playerSelections[1].remapButtonSelected) and 0 or p1Input.moveX
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
            -- Prevent horizontal movement when back button or remap button is selected
            local moveX = (playerSelections[2].backButtonSelected or playerSelections[2].remapButtonSelected) and 0 or p2Input.moveX
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
        local p1Mapping = GameInfo.p1KeyboardMapping or 1
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed[p1Mapping] and keyboardJustPressed[p1Mapping].b then
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
        local p2Mapping = GameInfo.p2KeyboardMapping or 2
        if GameInfo.p2InputType == "keyboard" and keyboardJustPressed[p2Mapping] and keyboardJustPressed[p2Mapping].b then
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
        
        -- Character-specific opponent order mapping
        -- Each character fights the others in a specific order, then fights themselves last
        local opponentOrder = {
            Warrior = {"Lancer", "Berserk", "Mage", "Warrior"},
            Berserk = {"Warrior", "Lancer", "Mage", "Berserk"},
            Lancer = {"Warrior", "Berserk", "Mage", "Lancer"},
            Mage = {"Warrior", "Lancer", "Berserk", "Mage"}
        }
        
        -- Set opponents based on player's character
        GameInfo.storyOpponents = {}
        local order = opponentOrder[GameInfo.storyPlayerCharacter]
        if order then
            for _, char in ipairs(order) do
                table.insert(GameInfo.storyOpponents, char)
            end
        end
        
        -- Calculate opponent colors: use all colors, excluding player's color
        local allColors = {"Blue", "Red", "Yellow", "Purple"}
        GameInfo.storyOpponentColors = {}
        -- First 3 opponents get colors excluding player's color
        for _, color in ipairs(allColors) do
            if color ~= GameInfo.storyPlayerColor then
                table.insert(GameInfo.storyOpponentColors, color)
            end
        end
        -- Final opponent (mirror) gets a different color than player
        -- Reuse the first available color from the non-player colors
        table.insert(GameInfo.storyOpponentColors, GameInfo.storyOpponentColors[1])
        
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
        -- Safety check: if P2's colorIndex is nil (shouldn't happen, but just in case), assign a default
        if playerSelections[2].colorIndex == nil then
            -- Assign first color that's different from P1's color
            local p1ColorIndex = playerSelections[1].colorIndex
            for colorIdx = 1, #colorOptions do
                if colorIdx ~= p1ColorIndex then
                    playerSelections[2].colorIndex = colorIdx
                    break
                end
            end
            -- Fallback: if somehow all colors match, use color 2
            if playerSelections[2].colorIndex == nil then
                playerSelections[2].colorIndex = 2
            end
        end
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

    -- Draw menu background map
    if GameInfo.menuMap then
        GameInfo.menuMap:draw(0, 0, 1, 1)
    end

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
    local paddingY   = 12

    local p1BoxX = paddingX + 4
    local p1BoxY = paddingY
    local p2BoxX = gameWidth - boxWidth - paddingX - 4
    local p2BoxY = paddingY

    local function getPlayerColor(playerIndex)
        local ci = playerSelections[playerIndex].colorIndex
        if ci == nil or ci < 1 or ci > #colorOptions then
            -- Return white/default color if colorIndex is invalid
            return 1, 1, 1
        end
        return colorOptions[ci][1], colorOptions[ci][2], colorOptions[ci][3]
    end

    -- --- Draw Player 1's box ---
    love.graphics.setColor(1, 1, 1, 1)
    -- Before selection: deselected box matching color; after selection: selected box matching color
    local row = playerSelections[1].locked and 1 or 0  -- 0=deselected, 1=selected
    local col = getColorColumn(playerSelections[1].colorIndex)
    love.graphics.draw(boxImage, getBoxQuad(row, col), p1BoxX, p1BoxY)
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
        love.graphics.setColor(1, 1, 1, 1)
        local row, col
        if isOnePlayer then
            -- In 1P mode (CPU): white deselected box until P1 locks, then deselected CPU color, then selected CPU color
            if not playerSelections[1].locked then
                -- Before P1 locks: deselected white box
                row, col = 0, 0
            elseif playerSelections[2].locked then
                -- After CPU locks: selected box matching CPU color
                row, col = 1, getColorColumn(playerSelections[2].colorIndex)
            else
                -- After P1 locks but before CPU locks: deselected box matching CPU color
                row, col = 0, getColorColumn(playerSelections[2].colorIndex)
            end
        else
            -- In 2P mode: white deselected until join, then deselected matching color, then selected matching color
            if not isP2Assigned() then
                -- Before P2 joins: deselected white box
                row, col = 0, 0
            elseif playerSelections[2].locked then
                -- After selection: selected box matching color
                row, col = 1, getColorColumn(playerSelections[2].colorIndex)
            else
                -- After join but before selection: deselected box matching color
                row, col = 0, getColorColumn(playerSelections[2].colorIndex)
            end
        end
        love.graphics.draw(boxImage, getBoxQuad(row, col), p2BoxX, p2BoxY)
        -- In 2P mode, show "Press to Join" text inside the box when P2 hasn't joined
        if not isOnePlayer and not isP2Assigned() then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(
                "Press to Join",
                p2BoxX - boxWidth/2 - 22,
                p2BoxY + 3,
                boxWidth*5,
                "center",
                0, 1, 1
            )
            -- love.graphics.printf("Player 2", p2BoxX - boxWidth/2 - 22, p2BoxY - 9, boxWidth*5, "center", 0, 1, 1)
        end
        -- Only draw warrior sprite if P2 has a color assigned (in 1P mode, this means P1 has locked)
        -- In 2P mode, also require that P2 has joined
        if playerSelections[2].colorIndex ~= nil and (isOnePlayer or isP2Assigned()) then
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
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Player 2", p2BoxX - boxWidth/2 - 22, p2BoxY - 9, boxWidth*5, "center", 0, 1, 1)
    end

    -- === Draw character boxes in the center ===
    -- Only draw if not all players are locked
    if not allPlayersLocked then
        local charBoxWidth   = 16
        local charBoxHeight  = 16
        local startX         = 10
        local startY         = p1BoxY + boxHeight + 12 
        local charBoxPadding = 16

        for i, charName in ipairs(characters) do
            local x = startX + (i - 1) * (charBoxWidth + charBoxPadding)
            local y = startY
            love.graphics.setColor(1, 1, 1, 1)
            -- Character boxes always use selected white box (row 1, column 0)
            love.graphics.draw(boxImage, getBoxQuad(1, 0), x, y)

            -- Draw a preview with gray sprite 
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
            elseif charName == "Mage" then
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
        local cursorY     = startY + charBoxHeight + 5
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
                -- Only draw arrow if back button and remap button are not selected for this player
                if not cs.backButtonSelected and not cs.remapButtonSelected then
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
    local backTextX = 6
    local backTextY = gameHeight - 13
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
    
    -- Draw remap button in bottom right (opposite to back button)
    love.graphics.setColor(1, 1, 1, 1)
    local remapText = "Remap"
    local remapTextWidth = font:getWidth(remapText)
    local remapTextX = gameWidth - remapTextWidth - 6
    
    local remapTextY = gameHeight - 13
    love.graphics.printf(remapText, gameWidth - remapTextWidth - 5, remapTextY, remapTextWidth, "right", 0, 1, 1)
    
    -- Draw player arrows to the left of "Remap" text when remap button is selected
    local remapArrowSize = 5
    local remapArrowSpacing = 8  -- Space between arrows if multiple players select remap
    -- local remapBaseArrowX = gameWidth - remapTextWidth + 6 - remapArrowSpacing  -- Position arrow to the left of text
    local remapBaseArrowX = gameWidth - remapTextWidth - 5 - remapArrowSpacing  -- Position arrow to the left of text
    local remapArrowY = remapTextY + 5  -- Center vertically with text
    
    -- Draw arrow for each player who has selected the remap button
    local remapArrowOffset = 0
    for playerIndex = 1, 2 do
        if playerSelections[playerIndex].remapButtonSelected then
            local remapArrowX = remapBaseArrowX - remapArrowOffset  -- Offset to the left
            love.graphics.setColor(getPlayerColor(playerIndex))
            -- Draw right-pointing arrow (triangle pointing right)
            love.graphics.polygon(
                "fill",
                remapArrowX, remapArrowY,  -- Right point
                remapArrowX - remapArrowSize, remapArrowY - remapArrowSize/2,  -- Top left
                remapArrowX - remapArrowSize, remapArrowY + remapArrowSize/2   -- Bottom left
            )
            love.graphics.setColor(1, 1, 1, 1)
            remapArrowOffset = remapArrowOffset + remapArrowSpacing  -- Offset next arrow if both players select
        end
    end

    -- Show keyboard controls if keyboard is enabled
    -- if GameInfo.p1InputType == "keyboard" or GameInfo.p2InputType == "keyboard" then
    --     love.graphics.setColor(0.7, 0.7, 0.7, 1)
    --     love.graphics.printf("P1: WASD/Space, P2: Arrows/Keypad0, K/L: Color, Shift: Back", 0, gameHeight - 20, gameWidth, "center", 0, 1, 1)
    -- end
end

return CharacterSelect
