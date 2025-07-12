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
local playerSelections = {
    [1] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 1, colorChangeCooldown = 0, inputDelay = 0 },
    [2] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 2, colorChangeCooldown = 0, inputDelay = 0 }
}

-- Remap menu state
local remapState = {
    active = false,
    playerIndex = nil,
    selectedAction = 1,
    remapping = false,
    remapCooldown = 0,
    lastPressedButtons = {},
    lastPressedKeys = {}
}

-- Actions that can be remapped
local remappableActions = {
    { name = "Light Attack/Select", key = "a" },
    { name = "Heavy Attack/Back", key = "b" },
    { name = "Jump", key = "y" },
    { name = "Counter", key = "x" },
    { name = "Dash", key = "shoulderL" },
    { name = "Shield", key = "shoulderR" },
    { name = "Left", key = "left" },
    { name = "Right", key = "right" }
}

-- Get remappable actions for a specific player (keyboard players get left/right, controllers don't)
local function getRemappableActionsForPlayer(playerIndex)
    local inputType = (playerIndex == 1) and GameInfo.p1InputType or GameInfo.p2InputType
    local actions = {}
    
    for i, action in ipairs(remappableActions) do
        -- Skip left/right for controller players
        if inputType == "keyboard" or (action.key ~= "left" and action.key ~= "right") then
            table.insert(actions, action)
        end
    end
    
    return actions
end

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
    local keyboardMap = InputManager.getDefaultKeyboardMapping(1)
    
    -- Check for key presses this frame
    if keyboardMap.a and love.keyboard.isDown(keyboardMap.a) then
        keyboardJustPressed.a = true
    end
    if keyboardMap.b and love.keyboard.isDown(keyboardMap.b) then
        keyboardJustPressed.b = true
    end
    if keyboardMap.x and love.keyboard.isDown(keyboardMap.x) then
        keyboardJustPressed.x = true
    end
    if keyboardMap.y and love.keyboard.isDown(keyboardMap.y) then
        keyboardJustPressed.y = true
    end
    if keyboardMap.start and love.keyboard.isDown(keyboardMap.start) then
        keyboardJustPressed.start = true
    end
    if keyboardMap.back and love.keyboard.isDown(keyboardMap.back) then
        keyboardJustPressed.back = true
    end
    if keyboardMap.left and love.keyboard.isDown(keyboardMap.left) then
        keyboardJustPressed.left = true
    end
    if keyboardMap.right and love.keyboard.isDown(keyboardMap.right) then
        keyboardJustPressed.right = true
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
-- Remap menu functions
-----------------------------------------------------

-- Start remap menu for a player
local function startRemapMenu(playerIndex)
    remapState.active = true
    remapState.playerIndex = playerIndex
    remapState.selectedAction = 1
    remapState.remapping = false
    remapState.remapCooldown = 0
    remapState.lastPressedButtons = {}
    remapState.lastPressedKeys = {}
end

-- Exit remap menu
local function exitRemapMenu()
    remapState.active = false
    remapState.playerIndex = nil
    remapState.selectedAction = 1
    remapState.remapping = false
    
    -- Clear edge detection state to prevent input carryover
    clearKeyboardEdgeDetection()
    -- Clear controller edge detection
    justPressed = {}
end

-- Update remap menu
local function updateRemapMenu(dt)
    if not remapState.active then return end
    
    remapState.remapCooldown = math.max(0, remapState.remapCooldown - dt)
    
    local playerIndex = remapState.playerIndex
    local inputType = (playerIndex == 1) and GameInfo.p1InputType or GameInfo.p2InputType
    
    if remapState.remapping then
        -- In remapping mode, wait for a new button press
        local newButton = nil
        
        if inputType == "keyboard" then
            local currentKeys = InputManager.getPressedKeys()
            for _, key in ipairs(currentKeys) do
                local found = false
                for _, lastKey in ipairs(remapState.lastPressedKeys) do
                    if key == lastKey then
                        found = true
                        break
                    end
                end
                if not found then
                    newButton = key
                    break
                end
            end
            remapState.lastPressedKeys = currentKeys
        else
            local currentButtons = InputManager.getPressedButtons(inputType)
            for _, button in ipairs(currentButtons) do
                local found = false
                for _, lastButton in ipairs(remapState.lastPressedButtons) do
                    if button == lastButton then
                        found = true
                        break
                    end
                end
                if not found then
                    newButton = button
                    break
                end
            end
            remapState.lastPressedButtons = currentButtons
        end
        
        if newButton and remapState.remapCooldown <= 0 then
            -- Map the new button to the selected action
            local playerActions = getRemappableActionsForPlayer(playerIndex)
            local actionKey = playerActions[remapState.selectedAction].key
            
            if inputType == "keyboard" then
                local currentMapping = InputManager.getCustomKeyboardMapping(playerIndex) or InputManager.getKeyboardMapping(playerIndex)
                
                -- Clear any existing mapping for this button
                for existingKey, existingButton in pairs(currentMapping) do
                    if existingButton == newButton then
                        currentMapping[existingKey] = nil
                    end
                end
                
                currentMapping[actionKey] = newButton
                InputManager.setCustomKeyboardMapping(playerIndex, currentMapping)
            else
                local currentMapping = InputManager.getCustomControllerMapping(playerIndex) or InputManager.getEffectiveControllerMapping(playerIndex)
                
                -- Clear any existing mapping for this button
                for existingKey, existingButton in pairs(currentMapping) do
                    if existingButton == newButton then
                        currentMapping[existingKey] = nil
                    end
                end
                
                currentMapping[actionKey] = newButton
                InputManager.setCustomControllerMapping(playerIndex, currentMapping)
            end
            
            remapState.remapping = false
            remapState.remapCooldown = 0.2
        end
    else
        -- In selection mode, handle navigation (use default mappings for remap menu navigation)
        local input = nil
        if inputType == "keyboard" then
            input = InputManager.getDefaultKeyboardInput(playerIndex)
        else
            input = InputManager.getDefault(inputType, playerIndex)
        end
        
        if input then
            -- Navigate with up/down
            local playerActions = getRemappableActionsForPlayer(playerIndex)
            if input.moveY < -0.5 and remapState.remapCooldown <= 0 then
                remapState.selectedAction = remapState.selectedAction - 1
                if remapState.selectedAction < 1 then
                    remapState.selectedAction = #playerActions
                end
                remapState.remapCooldown = 0.2
            elseif input.moveY > 0.5 and remapState.remapCooldown <= 0 then
                remapState.selectedAction = remapState.selectedAction + 1
                if remapState.selectedAction > #playerActions then
                    remapState.selectedAction = 1
                end
                remapState.remapCooldown = 0.2
            end
            
            -- Enter remap mode with A
            if input.a and remapState.remapCooldown <= 0 then
                remapState.remapping = true
                remapState.remapCooldown = 0.2
                
                -- Initialize last pressed buttons/keys
                if inputType == "keyboard" then
                    remapState.lastPressedKeys = InputManager.getPressedKeys()
                else
                    remapState.lastPressedButtons = InputManager.getPressedButtons(inputType)
                end
            end
            
            -- Exit with B
            if input.b and remapState.remapCooldown <= 0 then
                exitRemapMenu()
                remapState.remapCooldown = 0.2
            end
        end
    end
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
            ps.locked = true
        end
    else
        if input.b then
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
    
    -- Update remap menu if active
    local dt = love.timer.getDelta()
    updateRemapMenu(dt)
    
    -- If remap menu is active, only process remap menu input
    if remapState.active then
        clearKeyboardEdgeDetection()
        return
    end
    
    -- 1) If we just entered this screen, reset all selections AND clear any leftover justPressed so no input carries over:
    if GameInfo.justEnteredCharacterSelect then
        for i = 1, 2 do
            playerSelections[i].locked       = false
            playerSelections[i].cursor       = 1
            playerSelections[i].moveCooldown = 0
            playerSelections[i].colorIndex   = (i == 1) and 1 or 2
            playerSelections[i].colorChangeCooldown = 0.5  -- Increased delay to prevent carryover
            playerSelections[i].inputDelay = 0.3  -- 300ms delay to prevent input carryover
        end
        -- Only reset P2 controller assignment in 2P mode
        local isOnePlayer = (GameInfo.previousMode == "game_1P")
        if not isOnePlayer then
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            controllerAssignments[2] = nil
        end
        -- Clear all justPressed entries so A/Y presses that opened this screen are ignored:
        justPressed = {}
        -- Clear keyboard edge detection
        clearKeyboardEdgeDetection()
        GameInfo.justEnteredCharacterSelect = false
    end

    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local dt = love.timer.getDelta()

    -- Edge detection for kpenter and return (P2 keyboard assignment)
    CharacterSelect._p2KpenterReleased = CharacterSelect._p2KpenterReleased ~= false
    CharacterSelect._p2ReturnReleased = CharacterSelect._p2ReturnReleased ~= false
    if not isOnePlayer and not isP2Assigned() then
        -- Allow P2 to assign controller or keyboard ONLY with Start (controller) or Enter (keyboard)
        for _, js in ipairs(love.joystick.getJoysticks()) do
            local jid = js:getID()
            if (justPressed[jid] and justPressed[jid]["start"]) and (GameInfo.p1InputType ~= js:getID()) then
                GameInfo.p2InputType = js:getID()
                GameInfo.player2Controller = js:getID()
                justPressed[jid]["start"] = nil
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
            CharacterSelect._p2KpenterReleased = false
            CharacterSelect._p2ReturnReleased = false
        end
        -- Do not process any other input for P2 until assigned
    end
    -- Unassign P2 if back is pressed and not locked
    if not isOnePlayer and isP2Assigned() and not playerSelections[2].locked then
        local unassign = false
        if GameInfo.p2InputType == "keyboard" then
            local kb = InputManager.getDefaultKeyboardInput(2)
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
            return
        end
    end

    -- Edge detection for both players
    local justStates = {}
    for i = 1, 2 do
        justStates[i] = {}
    end
    -- P1 edge detection (use default mappings for character select navigation)
    local p1Input = nil
    if GameInfo.p1InputType == "keyboard" then
        local kb = InputManager.getDefaultKeyboardInput(1)
        for k,v in pairs(keyboardJustPressed) do
            if v then justStates[1][k] = true end
        end
        p1Input = InputManager.getDefaultKeyboardInput(1)
    else
        local js = InputManager.getJoystick(GameInfo.player1Controller)
        if js then
            local jid = js:getID()
            justStates[1] = justPressed[jid] or {}
            justPressed[jid] = nil
            p1Input = InputManager.getDefault(GameInfo.player1Controller, 1)
        end
    end
    -- P2 edge detection (use default mappings for character select navigation)
    local p2Input = nil
    if isOnePlayer then
        p2Input = p1Input
        justStates[2] = justStates[1]
    elseif GameInfo.p2InputType == "keyboard" then
        local kb = InputManager.getDefaultKeyboardInput(2)
        for k,v in pairs(keyboardJustPressed) do
            if v then justStates[2][k] = true end
        end
        p2Input = InputManager.getDefaultKeyboardInput(2)
    elseif GameInfo.p2InputType then
        local js = InputManager.getJoystick(GameInfo.player2Controller)
        if js then
            local jid = js:getID()
            justStates[2] = justPressed[jid] or {}
            justPressed[jid] = nil
            p2Input = InputManager.getDefault(GameInfo.player2Controller, 2)
        end
    end

    -- 1P mode: handle B for deselect or exit
    if isOnePlayer then
        -- Keyboard B
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed.b and not remapState.active then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            elseif playerSelections[1].locked then
                playerSelections[1].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                GameInfo.gameState = "menu"
                clearKeyboardEdgeDetection()
                return
            end
        end
        -- Controller B (edge-detection)
        if GameInfo.p1InputType ~= "keyboard" and justStates[1] and justStates[1].b and not remapState.active then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
                return
            elseif playerSelections[1].locked then
                playerSelections[1].locked = false
                return
            else
                GameInfo.gameState = "menu"
                return
            end
        end
    end
    -- 2P mode: handle P2 B for deselect or unassign
    if not isOnePlayer and isP2Assigned() and GameInfo.p2InputType == "keyboard" and not remapState.active then
        local kb = InputManager.getDefaultKeyboardInput(2)
        if kb.b then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                clearKeyboardEdgeDetection()
                return
            end
        end
    end
    if not isOnePlayer and isP2Assigned() and GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" and not remapState.active then
        for _, js in ipairs(love.joystick.getJoysticks()) do
            if js:getID() == GameInfo.p2InputType and js:isGamepadDown("b") then
                if playerSelections[2].locked then
                    playerSelections[2].locked = false
                    clearKeyboardEdgeDetection()
                    return
                else
                    GameInfo.p2InputType = nil
                    GameInfo.player2Controller = nil
                    clearKeyboardEdgeDetection()
                    return
                end
            end
        end
    end

    -- P1 always has input (use default mappings for character select navigation)
    if isOnePlayer then
        if not playerSelections[1].locked then
            if p1Input then
                -- Check for X button to enter remap menu (edge detection)
                if p1Input.x and not remapState.active and justStates[1] and justStates[1].x then
                    startRemapMenu(1)
                    clearKeyboardEdgeDetection()
                    return
                end
                
                CharacterSelect.updateCharacter({
                    a = p1Input.a, b = false, y = p1Input.y, start = p1Input.start,
                    moveX = p1Input.moveX, moveY = p1Input.moveY
                }, 1, dt)
            end
        else
            if p1Input then
                -- Check for X button to enter remap menu (edge detection)
                if p1Input.x and not remapState.active and justStates[1] and justStates[1].x then
                    startRemapMenu(1)
                    clearKeyboardEdgeDetection()
                    return
                end
                
                CharacterSelect.updateCharacter({
                    a = p1Input.a, b = false, y = p1Input.y, start = p1Input.start,
                    moveX = p1Input.moveX, moveY = p1Input.moveY
                }, 2, dt)
            end
        end
    else
        if p1Input then
            -- Check for X button to enter remap menu (edge detection)
            if p1Input.x and not remapState.active and justStates[1] and justStates[1].x then
                startRemapMenu(1)
                clearKeyboardEdgeDetection()
                return
            end
            
            CharacterSelect.updateCharacter({
                a = p1Input.a, b = false, y = p1Input.y, start = p1Input.start,
                moveX = p1Input.moveX, moveY = p1Input.moveY
            }, 1, dt)
        end
        if GameInfo.p2InputType and p2Input then
            -- Check for X button to enter remap menu (edge detection)
            if p2Input.x and not remapState.active and justStates[2] and justStates[2].x then
                startRemapMenu(2)
                clearKeyboardEdgeDetection()
                return
            end
            
            CharacterSelect.updateCharacter({
                a = p2Input.a, b = false, y = p2Input.y, start = p2Input.start,
                moveX = p2Input.moveX, moveY = p2Input.moveY
            }, 2, dt)
        end
    end

    -- Start game when both players are locked and any START was just pressed.
    if playerSelections[1].locked and playerSelections[2].locked then
        local startPressed = false
        if (p1Input and p1Input.start) or (p2Input and p2Input.start) then
            startPressed = true
        end
        if startPressed then
            CharacterSelect.beginGame(GameInfo)
        end
    end

    -- 2P mode: allow P1 to deselect or return to menu
    if not isOnePlayer then
        -- P1: Deselect if locked, else return to menu
        if GameInfo.p1InputType == "keyboard" and keyboardJustPressed.b and not remapState.active then
            if playerSelections[1].locked then
                playerSelections[1].locked = false
                clearKeyboardEdgeDetection()
                return
            else
                GameInfo.gameState = "menu"
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p1InputType ~= "keyboard" and justStates[1] and justStates[1].b and not remapState.active then
            if playerSelections[1].locked then
                playerSelections[1].locked = false
                return
            else
                GameInfo.gameState = "menu"
                return
            end
        end
        -- P2: Deselect if locked, else unassign controller (one action per press)
        if GameInfo.p2InputType == "keyboard" and keyboardJustPressed.b and not remapState.active then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
                clearKeyboardEdgeDetection()
                return
            elseif not playerSelections[2].locked then
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                clearKeyboardEdgeDetection()
                return
            end
        end
        if GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" and justStates[2] and justStates[2].b and not remapState.active then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
                return
            elseif not playerSelections[2].locked then
                GameInfo.p2InputType = nil
                GameInfo.player2Controller = nil
                return
            end
        end
    end

    clearKeyboardEdgeDetection()
end

-----------------------------------------------------
-- Called when both players have locked in their characters.
-----------------------------------------------------
function CharacterSelect.beginGame(GameInfo)
    GameInfo.player1Character = characters[playerSelections[1].cursor]
    GameInfo.player2Character = characters[playerSelections[2].cursor]

    GameInfo.player1Color = colorNames[playerSelections[1].colorIndex]
    GameInfo.player2Color = colorNames[playerSelections[2].colorIndex]

    -- The controller assignments are already set in GameInfo from the input assignment process
    -- No need to override them here

    GameInfo.gameState = GameInfo.previousMode
    startGame(GameInfo.gameState)
end

-----------------------------------------------------
-- Draw the character select screen (unchanged from before).
-----------------------------------------------------
function CharacterSelect.draw(GameInfo)
    love.graphics.clear(0, 0, 0, 1)

    local gameWidth   = GameInfo.gameWidth
    local gameHeight  = GameInfo.gameHeight
    local isOnePlayer = (GameInfo.previousMode == "game_1P")

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

    -- === Draw character boxes in the center ===
    local charBoxWidth   = 16
    local charBoxHeight  = 16
    local startX         = 6
    local startY         = p1BoxY + boxHeight + 20
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
        if isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
            -- Hide CPU's cursor until P1 locks
        else
            local cs = playerSelections[playerIndex]
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

    -- If both locked, prompt "Press START to begin!"
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf(
          "Press start to begin!",
          0, gameHeight - 43,
          gameWidth, "center", 0, 1, 1
        )
    end
    
    -- Show P2 assignment prompt if needed
    if not isOnePlayer and not isP2Assigned() then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            "Player 2: Press Start (controller) or Enter (keyboard)",
            0, gameHeight / 2 + 20,
            gameWidth, "center"
        )
        return
    end

    -- Show keyboard controls if keyboard is enabled
    if GameInfo.p1InputType == "keyboard" or GameInfo.p2InputType == "keyboard" then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf("P1: WASD/Space, P2: Arrows/Keypad0, K/L: Color, Shift: Back", 0, gameHeight - 20, gameWidth, "center", 0, 0.7, 0.7)
    end
    
    -- Show remap prompt
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Press X to remap controls", 0, gameHeight - 35, gameWidth, "center", 0, 0.8, 0.8)
    
    -- Draw remap menu if active
    if remapState.active then
        drawRemapMenu(GameInfo)
    end
end

-----------------------------------------------------
-- Draw the remap menu
-----------------------------------------------------
function drawRemapMenu(GameInfo)
    local gameWidth = GameInfo.gameWidth
    local gameHeight = GameInfo.gameHeight
    
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, gameWidth, gameHeight)
    
    -- Draw menu box
    love.graphics.setColor(1, 1, 1, 1)
    local menuWidth = 80
    local menuHeight = 60
    local menuX = (gameWidth - menuWidth) / 2
    local menuY = (gameHeight - menuHeight) / 2
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    
    -- Draw title
    local playerText = "Player " .. remapState.playerIndex .. " Remap"
    love.graphics.printf(playerText, menuX, menuY - 10, menuWidth, "center")
    
    -- Draw action list
    local startY = menuY + 10
    local lineHeight = 6
    local playerActions = getRemappableActionsForPlayer(remapState.playerIndex)
    
    for i, action in ipairs(playerActions) do
        local y = startY + (i - 1) * lineHeight
        local color = (i == remapState.selectedAction) and {1, 1, 0, 1} or {1, 1, 1, 1}
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        
        local text = action.name
        if remapState.remapping and i == remapState.selectedAction then
            text = text .. " [Press Button]"
        else
            -- Show current mapping
            local playerIndex = remapState.playerIndex
            local inputType = (playerIndex == 1) and GameInfo.p1InputType or GameInfo.p2InputType
            local currentMapping = nil
            
            if inputType == "keyboard" then
                currentMapping = InputManager.getEffectiveKeyboardMapping(playerIndex)
            else
                currentMapping = InputManager.getEffectiveControllerMapping(playerIndex)
            end
            
            if currentMapping and currentMapping[action.key] then
                text = text .. ": " .. currentMapping[action.key]
            end
        end
        
        love.graphics.printf(text, menuX + 2, y, menuWidth - 4, "left")
    end
    
    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local instructionY = menuY + menuHeight + 5
    love.graphics.printf("Up/Down: Select, A: Remap, B: Exit", menuX, instructionY, menuWidth, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

return CharacterSelect
