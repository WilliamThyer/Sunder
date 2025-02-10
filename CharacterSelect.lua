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
--   prevSelect, prevBack, prevStart, prevY: to detect edge presses
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
--         or an empty table if no joystick is connected
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
        -- Move to the next color index
        playerSelections[playerIndex].colorIndex =
            playerSelections[playerIndex].colorIndex + 1

        if playerSelections[playerIndex].colorIndex > #colorOptions then
            playerSelections[playerIndex].colorIndex = 1
        end

        attempts = attempts + 1
    until (playerSelections[playerIndex].colorIndex
               ~= playerSelections[otherIndex].colorIndex)
          or (attempts >= maxAttempts)
    -- If attempts >= maxAttempts, it means all colors are taken,
    -- but with only 2 players, that situation typically won't happen
    -- unless you have only 1 color in colorOptions.
end

-----------------------------------------------------
-- Update the character select screen for a given player
--   controllingJoystickIndex: which joystick index is controlling *this* player
--   If controllingJoystickIndex = nil, means no control
-----------------------------------------------------
function CharacterSelect.updateCharacter(controllingJoystickIndex, playerIndex)
    if not controllingJoystickIndex then
        -- This player is CPU/AI or no control is allowed
        return
    end

    local dt = love.timer.getDelta()
    local joystick = love.joystick.getJoysticks()[controllingJoystickIndex]
    local input = getJoystickInput(joystick)

    -- Decrement the movement cooldown
    playerSelections[playerIndex].moveCooldown = math.max(
        0, playerSelections[playerIndex].moveCooldown - dt
    )

    -- 1) Movement input
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
                -- Reset the movement cooldown
                s.moveCooldown = 0.25
            end
        end
    end

    -- 2) Color changing (Y button) -- edge-detected
    if input.changeColor and (not playerSelections[playerIndex].prevY) then
        cycleColor(playerIndex)
    end

    -- 3) Lock/unlock with A/B (edge detection)
    if not playerSelections[playerIndex].locked then
        -- If A is pressed *now* but wasn't last frame => lock
        if input.select and (not playerSelections[playerIndex].prevSelect) then
            playerSelections[playerIndex].locked = true
        end
        -- If B is pressed *now* but wasn't last frame => unlock (redundant here if not locked)
        if input.back and (not playerSelections[playerIndex].prevBack) then
            playerSelections[playerIndex].locked = false
        end
    else
        -- If locked, allow unlocking with B
        if input.back and (not playerSelections[playerIndex].prevBack) then
            playerSelections[playerIndex].locked = false
        end
    end

    -- 4) Store previous button states
    playerSelections[playerIndex].prevSelect = input.select
    playerSelections[playerIndex].prevBack   = input.back
    playerSelections[playerIndex].prevStart  = input.start
    playerSelections[playerIndex].prevY      = input.changeColor
end

-----------------------------------------------------
-- Main update for the character select screen
-----------------------------------------------------
function CharacterSelect.update(GameInfo)
    -- Determine if we are in 1-player or 2-player mode
    local isOnePlayer = (GameInfo.gameState == "game_1P")

    if isOnePlayer then
        -- Player 1 uses joystick #1
        -- Step 1: Let P1 pick their character
        CharacterSelect.updateCharacter(1, 1)

        -- Step 2: If P1 is locked, let the same joystick control "P2" (the CPU).
        if playerSelections[1].locked then
            CharacterSelect.updateCharacter(1, 2)
        end
    else
        -- 2-player mode
        local joysticks = love.joystick.getJoysticks()
        -- Safely call updateCharacter if the joystick is present
        if joysticks[1] then
            CharacterSelect.updateCharacter(1, 1)
        end
        if joysticks[2] then
            CharacterSelect.updateCharacter(2, 2)
        end
    end

    -- === START THE GAME WHEN BOTH PLAYERS ARE LOCKED ===
    if playerSelections[1].locked and playerSelections[2].locked then
        -- If either player presses start, begin
        local js = love.joystick.getJoysticks()
        local p1Start = js[1] and getJoystickInput(js[1]).start
        local p2Start = js[2] and getJoystickInput(js[2]).start

        if p1Start or p2Start then
            CharacterSelect.beginGame(GameInfo)
        end
    end
end

-----------------------------------------------------
-- Called when both players have locked in their characters
-----------------------------------------------------
function CharacterSelect.beginGame(GameInfo)
    -- Save the chosen characters into GameInfo for later use by startGame.
    GameInfo.player1Character = characters[playerSelections[1].cursor]
    GameInfo.player2Character = characters[playerSelections[2].cursor]

    -- (Optional) You could also store colors if you want them later.
    GameInfo.player1Color = colorOptions[playerSelections[1].colorIndex]
    GameInfo.player2Color = colorOptions[playerSelections[2].colorIndex]

    -- Set the game state to the previously selected mode
    GameInfo.gameState = GameInfo.previousMode  -- e.g. "game_1P" or "game_2P"

    -- Now start the game
    startGame(GameInfo.gameState)
end

-----------------------------------------------------
-- Draw the character select screen
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
        -- Fill the box with that player's chosen color
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
        -- If in 1P mode and P1 isn't locked yet, don't draw P2's cursor
        if isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
            -- Hide the CPU cursor until P1 is locked
        else
            local cursorIndex = playerSelections[playerIndex].cursor
            local x = startX + (cursorIndex - 1) * (charBoxWidth + padding) + charBoxWidth/2
            local y = cursorY

            -- Player color
            love.graphics.setColor(getPlayerColor(playerIndex))

            -- Draw the arrow
            love.graphics.polygon("fill",
                x - arrowSize/2, y,
                x + arrowSize/2, y,
                x, y - arrowSize
            )

            -- Draw the label below the cursor
            love.graphics.setColor(1,1,1,1)
            local label = (playerIndex == 1) and "P1" or "P2"
            if isOnePlayer and playerIndex == 2 then
                label = "CPU"  -- in 1P mode, second is CPU
            end
            love.graphics.printf(
                label,
                x - 30, y + 5, 60, "center"  -- a small bounding box
            )
        end
    end

    love.graphics.setColor(1, 1, 1, 1)

    -- === If both players are locked, prompt to start the game ===
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf("Press start to begin",
            0, displayHeight - 150, displayWidth, "center")
    end

    push:start()
end

return CharacterSelect
