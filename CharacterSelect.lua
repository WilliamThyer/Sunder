-- CharacterSelect.lua
-- This file contains the character select screen logic.

local CharacterSelect = {}
CharacterSelect.__index = CharacterSelect

local push = require("libraries.push")

-- === Predefined colors for players ===
local colorOptions = {
    {127/255, 146/255, 237/255},  -- Blue
    {234/255, 94/255, 94/255},    -- Red
    {141/255, 141/255, 141/255},  -- Gray
    {241/255, 225/255, 115/255},  -- Yellow
}

-- List of characters for now
local characters = {"Warrior", "Berserker", "Duelist", "Mage"}

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

local font = love.graphics.newFont("assets/Minecraft.ttf", 16)
love.graphics.setFont(font)
font:setFilter("nearest", "nearest")

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
    until (playerSelections[playerIndex].colorIndex
               ~= playerSelections[otherIndex].colorIndex)
          or (attempts >= maxAttempts)
end

-----------------------------------------------------
-- Update the character select screen for a given player.
-- controllingJoystickIndex:
--    which joystick to use for controlling this player's selection.
--    If nil, no control is available (e.g. for the CPU in 1P mode when not active).
-----------------------------------------------------
function CharacterSelect.updateCharacter(controllingJoystickIndex, playerIndex)
    if not controllingJoystickIndex then
        -- This player is CPU/AI or not controlled.
        return
    end

    local dt = love.timer.getDelta()
    local joystick = love.joystick.getJoysticks()[controllingJoystickIndex]
    local input = getJoystickInput(joystick)

    -- Decrement the movement cooldown
    playerSelections[playerIndex].moveCooldown = math.max(
        0, playerSelections[playerIndex].moveCooldown - dt
    )

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
                if s.cursor < 1 then
                    s.cursor = #characters
                elseif s.cursor > #characters then
                    s.cursor = 1
                end
                s.moveCooldown = 0.25
            end
        end
    end

    -- 2) Color changing (Y button) -- edge-detected
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
    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local joysticks = love.joystick.getJoysticks()

    if isOnePlayer then
        -- Only joystick[1] is used in one-player mode.
        local input = getJoystickInput(joysticks[1])
        if not playerSelections[1].locked then
            -- In P1 selection state: if B is pressed before locking, go back to main menu.
            if input.back and (not playerSelections[1].prevBack) then
                GameInfo.gameState = "menu"   -- Use "menu" so main.lua draws the menu.
                return
            end
            playerSelections[2].prevSelect = true -- to avoid misinput 
            CharacterSelect.updateCharacter(1, 1)
        else
            -- P1 is locked, so we are in CPU (P2) selection state.
            if input.back and (not playerSelections[1].prevBack) then
                -- B pressed while controlling CPU: unlock P1 (and reset CPU lock)
                playerSelections[1].locked = false
                playerSelections[2].locked = false
            else
                CharacterSelect.updateCharacter(1, 2)
            end
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

        -- Update each player's selection if their joystick is present.
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

    -- (Optional) Also store colors if needed later.
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
    push:finish()
    love.graphics.clear(0, 0, 0, 1)

    local displayWidth  = GameInfo.displayWidth
    local displayHeight = GameInfo.displayHeight

    local isOnePlayer = (GameInfo.gameState == "game_1P")

    -- === Draw player info boxes at the top ===
    local boxWidth  = 200
    local boxHeight = 100
    local padding   = 20

    local p1BoxX = padding
    local p1BoxY = padding
    local p2BoxX = displayWidth - boxWidth - padding
    local p2BoxY = padding

    -- Helper to get a player's current color
    local function getPlayerColor(playerIndex)
        local ci = playerSelections[playerIndex].colorIndex
        return colorOptions[ci][1], colorOptions[ci][2], colorOptions[ci][3]
    end

    -- --- Draw Player 1's box ---
    if playerSelections[1].locked then
        love.graphics.setColor(getPlayerColor(1))
        love.graphics.rectangle("fill", p1BoxX, p1BoxY, boxWidth, boxHeight)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", p1BoxX, p1BoxY, boxWidth, boxHeight)
    local p1Character = characters[playerSelections[1].cursor]
    love.graphics.printf("Player 1\n" .. p1Character,
        p1BoxX, p1BoxY + 30, boxWidth, "center", 0, 0.5, 0.5)

    -- --- Draw Player 2's box ---
    if playerSelections[2].locked then
        love.graphics.setColor(getPlayerColor(2))
        love.graphics.rectangle("fill", p2BoxX, p2BoxY, boxWidth, boxHeight)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", p2BoxX, p2BoxY, boxWidth, boxHeight)
    local p2Character = characters[playerSelections[2].cursor]
    love.graphics.printf("Player 2\n" .. p2Character,
        p2BoxX, p2BoxY + 30, boxWidth, "center", 0, 0.5, 0.5)

    -- === Draw character boxes in the center ===
    local charBoxWidth  = 150
    local charBoxHeight = 100
    local totalWidth    = charBoxWidth * #characters + padding * (#characters - 1)
    local startX        = (displayWidth - totalWidth) / 2
    local startY        = p1BoxY + boxHeight + 50

    for i, charName in ipairs(characters) do
        local x = startX + (i - 1) * (charBoxWidth + padding)
        local y = startY
        love.graphics.rectangle("line", x, y, charBoxWidth, charBoxHeight)
        love.graphics.printf(charName, x, y + charBoxHeight/2 - 10, charBoxWidth, "center")
    end

    -- === Draw each player’s cursor below the character boxes ===
    local cursorY   = startY + charBoxHeight + 10
    local arrowSize = 20

    for playerIndex = 1, 2 do
        -- In 1-player mode, do not draw the CPU (P2) cursor until P1 is locked.
        if isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
            -- (CPU cursor is hidden until P1 has locked in.)
        else
            local cursorIndex = playerSelections[playerIndex].cursor
            local x = startX + (cursorIndex - 1) * (charBoxWidth + padding) + charBoxWidth/2
            local y = cursorY

            love.graphics.setColor(getPlayerColor(playerIndex))
            love.graphics.polygon("fill",
                x - arrowSize/2, y,
                x + arrowSize/2, y,
                x, y - arrowSize
            )

            -- Draw label under the cursor: "P1" or "P2" (or "CPU" in 1P mode for player 2)
            love.graphics.setColor(1,1,1,1)
            local label = (playerIndex == 1) and "P1" or "P2"
            if isOnePlayer and playerIndex == 2 then
                label = "CPU"
            end
            love.graphics.printf(label,
                x - 30, y + 5, 60, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf("Press start to begin",
            0, displayHeight - 150, displayWidth, "center")
    end

    push:start()
end

return CharacterSelect
