-- CharacterSelect.lua
-- Uses a global `justPressed[jid][button] = true` populated in love.gamepadpressed.
-- Edge‐detection ("was pressed this frame") comes from consuming `justPressed`.

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
    local keyboardMap = InputManager.getKeyboardMapping()
    
    -- Check for key presses this frame
    if love.keyboard.isDown(keyboardMap.a) then
        keyboardJustPressed.a = true
    end
    if love.keyboard.isDown(keyboardMap.b) then
        keyboardJustPressed.b = true
    end
    if love.keyboard.isDown(keyboardMap.x) then
        keyboardJustPressed.x = true
    end
    if love.keyboard.isDown(keyboardMap.y) then
        keyboardJustPressed.y = true
    end
    if love.keyboard.isDown(keyboardMap.start) then
        keyboardJustPressed.start = true
    end
    if love.keyboard.isDown(keyboardMap.back) then
        keyboardJustPressed.back = true
    end
    if love.keyboard.isDown(keyboardMap.left) then
        keyboardJustPressed.left = true
    end
    if love.keyboard.isDown(keyboardMap.right) then
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
        -- Reset controller assignments
        controllerAssignments[1] = nil
        controllerAssignments[2] = nil
        -- Clear all justPressed entries so A/Y presses that opened this screen are ignored:
        justPressed = {}
        -- Clear keyboard edge detection
        clearKeyboardEdgeDetection()
        GameInfo.justEnteredCharacterSelect = false
    end

    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local dt = love.timer.getDelta()

    -- 2) For edge detection, copy and consume `justPressed` for each joystick index (1 & 2).
    --    After this, justPressed[jid] is nil, so it won't fire twice next frame.
    local justStates = {}
    for i = 1, 2 do
        local js = InputManager.getJoystick(i)
        if js then
            local jid = js:getID()
            justStates[i] = justPressed[jid] or {}
            justPressed[jid] = nil
        else
            justStates[i] = {}
        end
    end
    
    -- Merge keyboard edge detection into justStates for player 1 only if keyboard is enabled for P1
    if GameInfo.keyboardPlayer == 1 then
        for k,v in pairs(keyboardJustPressed) do
            if v then
                justStates[1][k] = true
            end
        end
    end
    -- Also merge keyboard edge detection for player 2 if keyboard is enabled for P2
    if GameInfo.keyboardPlayer == 2 then
        for k,v in pairs(keyboardJustPressed) do
            if v then
                justStates[2][k] = true
            end
        end
    end

    -- 3) Build `input1` and `input2` tables to feed into updateCharacter():
    local function makeInput(i)
        local baseInput = InputManager.get(i)
        local just = justStates[i]
        -- Merge keyboard input for player 1 only if keyboard is enabled for P1
        if i == 1 and GameInfo.keyboardPlayer == 1 then
            local kb = InputManager.getKeyboardInput()
            -- Combine axes (favor nonzero, or sum if both pressed)
            local moveX = baseInput.moveX ~= 0 and baseInput.moveX or kb.moveX
            if baseInput.moveX ~= 0 and kb.moveX ~= 0 then
                moveX = baseInput.moveX + kb.moveX
                if moveX > 1 then moveX = 1 elseif moveX < -1 then moveX = -1 end
            end
            local moveY = baseInput.moveY ~= 0 and baseInput.moveY or kb.moveY
            if baseInput.moveY ~= 0 and kb.moveY ~= 0 then
                moveY = baseInput.moveY + kb.moveY
                if moveY > 1 then moveY = 1 elseif moveY < -1 then moveY = -1 end
            end
            return {
                select      = (just["a"]     == true) or (just["a"]     == true),
                back        = (just["b"]     == true) or (just["b"]     == true),
                start       = (just["start"] == true) or (just["start"] == true),
                changeColor = (just["y"]     == true) or (just["y"]     == true),
                moveX       = moveX,
                moveY       = moveY,
                a           = baseInput.a or kb.a,
                b           = baseInput.b or kb.b,
                y           = baseInput.y or kb.y,
                start       = baseInput.start or kb.start
            }
        elseif i == 2 and GameInfo.keyboardPlayer == 2 then
            -- Merge keyboard input for player 2 if keyboard is enabled for P2
            local kb = InputManager.getKeyboardInput()
            -- Combine axes (favor nonzero, or sum if both pressed)
            local moveX = baseInput.moveX ~= 0 and baseInput.moveX or kb.moveX
            if baseInput.moveX ~= 0 and kb.moveX ~= 0 then
                moveX = baseInput.moveX + kb.moveX
                if moveX > 1 then moveX = 1 elseif moveX < -1 then moveX = -1 end
            end
            local moveY = baseInput.moveY ~= 0 and baseInput.moveY or kb.moveY
            if baseInput.moveY ~= 0 and kb.moveY ~= 0 then
                moveY = baseInput.moveY + kb.moveY
                if moveY > 1 then moveY = 1 elseif moveY < -1 then moveY = -1 end
            end
            return {
                select      = (just["a"]     == true),
                back        = (just["b"]     == true),
                start       = (just["start"] == true),
                changeColor = (just["y"]     == true),
                moveX       = moveX,
                moveY       = moveY,
                a           = baseInput.a or kb.a,
                b           = baseInput.b or kb.b,
                y           = baseInput.y or kb.y,
                start       = baseInput.start or kb.start
            }
        else
            return {
                select      = (just["a"]     == true),
                back        = (just["b"]     == true),
                start       = (just["start"] == true),
                changeColor = (just["y"]     == true),
                moveX       = baseInput.moveX,
                moveY       = baseInput.moveY,
                a           = baseInput.a,
                b           = baseInput.b,
                y           = baseInput.y,
                start       = baseInput.start
            }
        end
    end

    -- 4) Handle controller assignment based on first input
    for controllerIndex = 1, 2 do
        local js = InputManager.getJoystick(controllerIndex)
        if js then
            local input = makeInput(controllerIndex)
            local playerIndex = getPlayerForController(controllerIndex)
            
            -- If this controller has any input and isn't assigned yet, assign it
            if not playerIndex and (input.moveX ~= 0 or input.moveY ~= 0 or input.a or input.b or input.y or input.start) then
                -- Find the first available player slot
                for p = 1, 2 do
                    if not controllerAssignments[p] then
                        assignControllerToPlayer(controllerIndex, p)
                        break
                    end
                end
            end
        end
    end

    -- 5) One-Player Logic:
    if isOnePlayer then
        -- Handle "B" globally: 
        --   If P2 is locked, unlock P2; elseif P1 is locked, unlock P1; else exit to menu.
        local p1Controller = controllerAssignments[1]
        local p1Input
        if p1Controller then
            p1Input = makeInput(p1Controller)
        else
            p1Input = makeInput(1)
        end
        
        if p1Input and p1Input.back then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
            elseif playerSelections[1].locked then
                playerSelections[1].locked = false
            else
                GameInfo.gameState = "menu"
                return
            end
        end

        -- If P1 is not yet locked, update P1; otherwise update P2 with the same input.
        if p1Input then
            if not playerSelections[1].locked then
                CharacterSelect.updateCharacter(p1Input, 1, dt)
            else
                CharacterSelect.updateCharacter(p1Input, 2, dt)
            end
        end

    -- 6) Two-Player Logic:
    else
        -- Handle input for each assigned controller
        for playerIndex = 1, 2 do
            local controllerIndex = controllerAssignments[playerIndex]
            local input
            
            if controllerIndex then
                input = makeInput(controllerIndex)
            else
                input = makeInput(playerIndex)
            end
            
            if input then
                -- If player is unlocked and presses B, exit to menu
                if (not playerSelections[playerIndex].locked) and input.back then
                    GameInfo.gameState = "menu"
                    return
                end
                
                CharacterSelect.updateCharacter(input, playerIndex, dt)
            end
        end
    end

    -- 7) Start game when both players are locked and any START was just pressed.
    if playerSelections[1].locked and playerSelections[2].locked then
        local startPressed = false
        for playerIndex = 1, 2 do
            local controllerIndex = controllerAssignments[playerIndex]
            local input
            
            if controllerIndex then
                input = makeInput(controllerIndex)
            else
                input = makeInput(playerIndex)
            end
            
            if input and input.start then
                startPressed = true
                break
            end
        end
        
        if startPressed then
            CharacterSelect.beginGame(GameInfo)
        end
    end
    
    -- Clear keyboard edge detection after processing
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

    -- Set the controller assignments in GameInfo for the game
    GameInfo.player1Controller = controllerAssignments[1]
    GameInfo.player2Controller = controllerAssignments[2]

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
    
    -- Show keyboard controls if keyboard is enabled
    if GameInfo.keyboardPlayer == 1 or GameInfo.keyboardPlayer == 2 then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf("WASD: Move, SPACE: Select, K: Change Color, ESC: Back", 0, gameHeight - 20, gameWidth, "center", 0, 0.7, 0.7)
    end
end

return CharacterSelect
