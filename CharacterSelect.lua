local CharacterSelect = {}
CharacterSelect.__index = CharacterSelect

local push = require("libraries.push")

-- List of characters for now
local characters = {"Warrior", "Berserker", "Duelist", "Mage"}

-- Store each player’s selection state.
-- Each entry has a 'cursor' index (starting at 1) and a 'locked' flag.
local playerSelections = {
    [1] = {cursor = 1, locked = true},
    [2] = {cursor = 2, locked = false}
}

local font = love.graphics.newFont("assets/Minecraft.ttf", 16)
love.graphics.setFont(font)
font:setFilter("nearest", "nearest")

local function getJoystickInput(joystick)
    if joystick then
        return {
            select = joystick:isGamepadDown("a"),
            back = joystick:isGamepadDown("b"),
            start = joystick:isGamepadDown("start"),
            moveY = joystick:getGamepadAxis("lefty") or 0,
            moveX = joystick:getGamepadAxis("leftx") or 0
        }
    else
        -- return empty dict if no joystick
        return {
            select = false,
            back = false,
            start = false,
            moveY = 0,
            moveX = 0
        }
    end
end

-- (Optionally, you might want to add a timer/delay so that rapid stick movement doesn’t
-- change the selection too fast. For simplicity, this example does not include that.)

-----------------------------------------------------
-- Update the character select screen
-----------------------------------------------------

function CharacterSelect.updateCharacter(joysticks, playerIndex)

    if not playerSelections[playerIndex].locked then
        local move = 0
        local axisX = getJoystickInput(joysticks[playerIndex]).moveX
        if axisX < -0.5 then
            move = -1
        elseif axisX > 0.5 then
            move = 1
        end

        if move ~= 0 then
            playerSelections[playerIndex].cursor = playerSelections[playerIndex].cursor + move
            if playerSelections[playerIndex].cursor < 1 then 
                playerSelections[playerIndex].cursor = #characters 
            elseif playerSelections[playerIndex].cursor > #characters then 
                playerSelections[playerIndex].cursor = 1 
            end
        end

        -- Confirm selection (A button)
        if getJoystickInput(joysticks[playerIndex]).select then
            playerSelections[playerIndex].locked = true
        end

        -- Unlock selection with B (or Backspace)
        if getJoystickInput(joysticks[playerIndex]).back then
            playerSelections[playerIndex].locked = false
        end
    else
        -- Even when locked, allow unlocking if the button is pressed.
        if getJoystickInput(joysticks[playerIndex]).back then
            playerSelections[playerIndex].locked = false
        end
    end
end

function CharacterSelect.update(GameInfo)
    local joysticks = love.joystick.getJoysticks()
    CharacterSelect.updateCharacter(joysticks, 1)
    CharacterSelect.updateCharacter(joysticks, 2)

    -- === START THE GAME WHEN BOTH PLAYERS ARE LOCKED ===
    if playerSelections[1].locked and playerSelections[2].locked then
        local startPressed = false

        if getJoystickInput(joysticks[1]).start or getJoystickInput(joysticks[2]).start then 
            startPressed = true
        end

        if startPressed then
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

    -- Set the game state to the previously selected mode.
    -- (GameInfo.previousMode should have been set in the main menu.)
    GameInfo.gameState = GameInfo.previousMode  -- e.g. "game_1P" or "game_2P"

    -- Now start the game.
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

    -- === Draw player info boxes at the top ===
    local boxWidth  = 200
    local boxHeight = 100
    local padding   = 20

    local p1BoxX = padding
    local p1BoxY = padding
    local p2BoxX = displayWidth - boxWidth - padding
    local p2BoxY = padding

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", p1BoxX, p1BoxY, boxWidth, boxHeight)
    love.graphics.rectangle("line", p2BoxX, p2BoxY, boxWidth, boxHeight)

    love.graphics.printf("Player 1", p1BoxX, p1BoxY + 30, boxWidth, "center", 0, .5, .5)
    love.graphics.printf("Player 2", p2BoxX, p2BoxY + 30, boxWidth, "center", 0, .5, .5)

    -- === Draw character boxes below ===
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
    local cursorY = startY + charBoxHeight + 10
    local arrowSize = 20

    for playerIndex = 1, 2 do
        local cursorIndex = playerSelections[playerIndex].cursor
        local x = startX + (cursorIndex - 1) * (charBoxWidth + padding) + charBoxWidth/2
        local y = cursorY
        if playerIndex == 1 then
            love.graphics.setColor(1, 0, 0, 1)  -- red for player 1
        else
            love.graphics.setColor(0, 0, 1, 1)  -- blue for player 2
        end
        love.graphics.polygon("fill", x - arrowSize/2, y, x + arrowSize/2, y, x, y - arrowSize)
    end

    love.graphics.setColor(1, 1, 1, 1)

    -- === If both players are locked, prompt to start the game ===
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf("Press start to begin", 0, displayHeight - 150, displayWidth, "center")
    end

    push:start()
end

return CharacterSelect