-- CharacterSelect.lua
-- This file contains the character select screen logic.

local CharacterSelect = {}
CharacterSelect.__index = CharacterSelect

local push = require("libraries.push")
love.graphics.setDefaultFilter("nearest", "nearest")

-- === Predefined colors for players ===
local colorOptions = {
    {127/255, 146/255, 237/255},  -- Blue
    {234/255, 94/255, 94/255},    -- Red
    {141/255, 141/255, 141/255},  -- Gray
    {241/255, 225/255, 115/255},  -- Yellow
}
-- Mapping from our color index to color name (used for sprite sheet lookup)
local colorNames = {"Blue", "Red", "Gray", "Yellow"}

-- List of characters for now
local characters = {"Warrior", "Berserk", "Duelist", "Mage"}

-- Load sprite sheets for the characters that have sprites.
-- (Note: no sprites are loaded for Duelist and Mage.)
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
    }
}

-- Create quads to pull the first sprite from each sheet.
-- For Warrior: grid 8×8; for Berserk: grid 12×12.
local warriorQuad = love.graphics.newQuad(0, 1, 9, 8, sprites.Warrior.Blue:getWidth(), sprites.Warrior.Blue:getHeight())
local berserkQuad = love.graphics.newQuad(1, 2, 13, 13, sprites.Berserk.Blue:getWidth(), sprites.Berserk.Blue:getHeight())

-- Store each player's selection state.
--   moveCooldown: a timer to delay repeated stick moves (in seconds)
--   prevSelect, prevBack, prevStart, prevY: for edge-detection
--   colorIndex: which color index from colorOptions
local playerSelections = {
    [1] = {
      cursor = 1, locked = false, moveCooldown = 0,
      prevSelect = true, prevBack = false, prevStart = false, prevY = false,
      colorIndex = 1  -- Player 1 default: Blue
    },
    [2] = {
      cursor = 1, locked = false, moveCooldown = 0,
      prevSelect = true, prevBack = false, prevStart = false, prevY = false,
      colorIndex = 2  -- Player 2 default: Red
    }
}

local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

-----------------------------------------------------
-- Helper: Return current input for a given joystick
--         (or a table of "false" values if no joystick is connected)
-----------------------------------------------------
local function getJoystickInput(joystick)
    if joystick then
        return {
            select = joystick:isGamepadDown("a"),
            back   = joystick:isGamepadDown("b"),
            start  = joystick:isGamepadDown("start"),
            changeColor = joystick:isGamepadDown("y"),
            moveX  = joystick:getGamepadAxis("leftx") or 0,
            moveY  = joystick:getGamepadAxis("lefty") or 0
        }
    else
        return {
            select = false, back = false, start = false,
            changeColor = false,
            moveX = 0, moveY = 0
        }
    end
end

-----------------------------------------------------
-- Helper: Cycle to the next color for a player, skipping
--         any color currently taken by the other player.
-----------------------------------------------------
local function cycleColor(playerIndex)
    local otherIndex = (playerIndex == 1) and 2 or 1
    local maxAttempts = #colorOptions

    local attempts = 0
    repeat
        -- Advance to the next color index
        playerSelections[playerIndex].colorIndex =
            playerSelections[playerIndex].colorIndex + 1

        if playerSelections[playerIndex].colorIndex > #colorOptions then
            playerSelections[playerIndex].colorIndex = 1
        end

        attempts = attempts + 1
    until (playerSelections[playerIndex].colorIndex ~= playerSelections[otherIndex].colorIndex)
          or (attempts >= maxAttempts)
end

-----------------------------------------------------
-- Update the character select screen for a given player.
-- controllingJoystickIndex:
--    which joystick to use for controlling this player's selection.
--    If nil, no control is available (e.g. for the CPU in 1P mode when not active).
-----------------------------------------------------
function CharacterSelect.updateCharacter(controllingJoystickIndex, playerIndex)
    if not controllingJoystickIndex then return end

    local dt = love.timer.getDelta()
    local joystick = love.joystick.getJoysticks()[controllingJoystickIndex]
    local input = getJoystickInput(joystick)

    playerSelections[playerIndex].moveCooldown = math.max(0, playerSelections[playerIndex].moveCooldown - dt)

    -- 1) Movement input (only if not locked)
    if not playerSelections[playerIndex].locked then
        if playerSelections[playerIndex].moveCooldown <= 0 then
            local move = 0
            local axisX = input.moveX
            if axisX < -0.5 then
                move = -1
            elseif axisX > 0.5 then
                move = 1
            end

            if move ~= 0 then
                local s = playerSelections[playerIndex]
                s.cursor = s.cursor + move
                if s.cursor < 1 then s.cursor = #characters
                elseif s.cursor > #characters then s.cursor = 1 end
                s.moveCooldown = 0.25
            end
        end
    end

    -- 2) Color changing (Y button)
    if input.changeColor and (not playerSelections[playerIndex].prevY) then
        cycleColor(playerIndex)
    end

    -- 3) Lock/unlock with A/B (edge-detected)
    if not playerSelections[playerIndex].locked then
        -- Lock in selection when A is pressed
        if input.select and (not playerSelections[playerIndex].prevSelect) then
            playerSelections[playerIndex].locked = true
        end
        -- (Do NOT handle B here when not locked --
        --  global update will cancel character select if B is pressed.)
    else
        -- When already locked, allow unlocking with B
        if input.back and (not playerSelections[playerIndex].prevBack) then
            playerSelections[playerIndex].locked = false
        end
    end

    -- 4) Store previous button states (for edge detection)
    playerSelections[playerIndex].prevSelect = input.select
    playerSelections[playerIndex].prevBack   = input.back
    playerSelections[playerIndex].prevStart  = input.start
    playerSelections[playerIndex].prevY      = input.changeColor
end

-----------------------------------------------------
-- Main update for the character select screen.
--
-- In 1-player mode:
--   - If P1 is not locked, B returns to the main menu.
--   - Once P1 locks, the same joystick is used to update CPU (P2).
--   - While in CPU selection, B unlocks P1 so that you can reselect.
--
-- In 2-player mode:
--   - Each controller updates its own player.
--   - If a controller is in the unlocked state and its B is pressed, the screen exits.
-----------------------------------------------------
function CharacterSelect.update(GameInfo)
    -- Reset selection state if just entering character select.
    if GameInfo.justEnteredCharacterSelect then
        playerSelections[1].locked = false
        playerSelections[2].locked = false
        playerSelections[1].cursor = 1
        playerSelections[2].cursor = 1
        GameInfo.justEnteredCharacterSelect = false
    end

    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local joysticks = love.joystick.getJoysticks()

    if isOnePlayer then
        -- Only use joystick[1] for one-player mode.
        local input = getJoystickInput(joysticks[1])
        -- NEW: Check for B button first.
        if input.back and (not playerSelections[1].prevBack) then
            if playerSelections[1].locked then
                -- If P1 is locked, unlock both so the player can reselect.
                playerSelections[1].locked = false
                playerSelections[2].locked = false
            else
                -- If not locked, exit to menu.
                GameInfo.gameState = "menu"
                return
            end
        end
        if not playerSelections[1].locked then
            CharacterSelect.updateCharacter(1, 1)
        else
            CharacterSelect.updateCharacter(1, 2)
        end
    else
        -- Two-player mode
        -- First, check for cancellation (B pressed) on any unlocked controller.
        local input1 = getJoystickInput(joysticks[1])
        local input2 = getJoystickInput(joysticks[2])
        if (not playerSelections[1].locked) and input1.back and (not playerSelections[1].prevBack) then
            GameInfo.gameState = "menu"
            return
        end
        if (not playerSelections[2].locked) and input2.back and (not playerSelections[2].prevBack) then
            GameInfo.gameState = "menu"
            return
        end

        if joysticks[1] then
            CharacterSelect.updateCharacter(1, 1)
        end
        if joysticks[2] then
            CharacterSelect.updateCharacter(2, 2)
        end
    end

    -- === START THE GAME WHEN BOTH PLAYERS ARE LOCKED ===
    if playerSelections[1].locked and playerSelections[2].locked then
        if getJoystickInput(joysticks[1]).start or getJoystickInput(joysticks[2]).start then
            CharacterSelect.beginGame(GameInfo)
        end
    end
end

-----------------------------------------------------
-- Called when both players have locked in their characters.
-----------------------------------------------------
function CharacterSelect.beginGame(GameInfo)
    -- Save the chosen characters into GameInfo for later use by startGame.
    GameInfo.player1Character = characters[playerSelections[1].cursor]
    GameInfo.player2Character = characters[playerSelections[2].cursor]

    -- Also store colors for later.
    GameInfo.player1Color = colorOptions[playerSelections[1].colorIndex]
    GameInfo.player2Color = colorOptions[playerSelections[2].colorIndex]

    -- Transition to the previously selected game mode (e.g. "game_1P" or "game_2P")
    GameInfo.gameState = GameInfo.previousMode
    startGame(GameInfo.gameState)
end

-----------------------------------------------------
-- Draw the character select screen.
-----------------------------------------------------
function CharacterSelect.draw(GameInfo)
    love.graphics.clear(0, 0, 0, 1)

    local gameWidth  = GameInfo.gameWidth
    local gameHeight = GameInfo.gameHeight
    local isOnePlayer = (GameInfo.previousState == "game_1P")

    -- === Draw player info boxes at the top ===
    local boxWidth  = 16
    local boxHeight = 16
    local paddingX  = 32
    local paddingY  = 10

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
    -- In the player box, if the selected character has a sprite (Warrior or Berserk), draw it
    local p1Char = characters[playerSelections[1].cursor]
    if p1Char == "Warrior" or p1Char == "Berserk" then
        local colName = colorNames[playerSelections[1].colorIndex]
        local image, quad, spriteW, spriteH
        if p1Char == "Warrior" then
            image = sprites.Warrior[colName]
            quad = warriorQuad
            spriteW, spriteH = 8, 8
        elseif p1Char == "Berserk" then
            image = sprites.Berserk[colName]
            quad = berserkQuad
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
    if p2Char == "Warrior" or p2Char == "Berserk" then
        local colName = colorNames[playerSelections[2].colorIndex]
        local image, quad, spriteW, spriteH
        if p2Char == "Warrior" then
            image = sprites.Warrior[colName]
            quad = warriorQuad
            spriteW, spriteH = 8, 8
        elseif p2Char == "Berserk" then
            image = sprites.Berserk[colName]
            quad = berserkQuad
            spriteW, spriteH = 12, 12
        end
        local offsetX = (boxWidth - spriteW) / 2
        local offsetY = (boxHeight - spriteH) / 2
        love.graphics.draw(image, quad, p2BoxX + offsetX, p2BoxY + offsetY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 2", p2BoxX - boxWidth/2 - 22, p2BoxY - 9, boxWidth*5, "center", 0, 1, 1)

    -- === Draw character boxes in the center ===
    local charBoxWidth  = 16
    local charBoxHeight = 16
    local startX        = 6
    local startY        = p1BoxY + boxHeight + 20
    local charBoxPadding = 16

    for i, charName in ipairs(characters) do
        local x = startX + (i - 1) * (charBoxWidth + charBoxPadding)
        local y = startY
        love.graphics.rectangle("line", x, y, charBoxWidth, charBoxHeight)
        -- For characters with sprites (Warrior or Berserk), draw the blue sprite in the option box.
        if charName == "Warrior" then
            local image = sprites.Warrior["Gray"]
            local quad = warriorQuad
            local spriteW, spriteH = 8, 8
            local offsetX = (charBoxWidth - spriteW) / 2
            local offsetY = (charBoxHeight - spriteH) / 2
            love.graphics.draw(image, quad, x + offsetX, y + offsetY, 0, 1, 1, 0, -1)
        elseif charName == "Berserk" then
            local image = sprites.Berserk["Gray"]
            local quad = berserkQuad
            local spriteW, spriteH = 12, 12
            local offsetX = (charBoxWidth - spriteW) / 2
            local offsetY = (charBoxHeight - spriteH) / 2
            love.graphics.draw(image, quad, x + offsetX, y + offsetY, 0, 1, 1, 0, 0)
        end
        love.graphics.printf(charName, x - charBoxWidth * 2, y - charBoxHeight/2 - 1, charBoxWidth*5, "center", 0, 1, 1)
    end

    -- === Draw each player’s cursor below the character boxes ===
    local cursorY   = startY + charBoxHeight + 7
    local arrowSize = 5
    local charBoxSpace = charBoxPadding

    for playerIndex = 1, 2 do
        if isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
            -- Hide CPU cursor until P1 is locked.
        else
            local cursorIndex = playerSelections[playerIndex].cursor
            local offsetX = (playerIndex == 1) and -3 or 3
            local x = startX + (cursorIndex - 1) * (charBoxWidth + charBoxPadding) + charBoxWidth/2 + offsetX
            local y = cursorY

            love.graphics.setColor(getPlayerColor(playerIndex))
            love.graphics.polygon("fill", x - arrowSize/2, y, x + arrowSize/2, y, x, y - arrowSize)
            love.graphics.setColor(1, 1, 1, 1)
            local label = (playerIndex == 1) and "P1" or "P2"
            if isOnePlayer and playerIndex == 2 then label = "CPU" end
            -- love.graphics.printf(label, x - 30, y - 5, 60, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf("Press start to begin!", 0, gameHeight - 43, gameWidth, "center", 0, 1, 1)
    end
end

return CharacterSelect
