local Menu = {}
Menu.__index = Menu

local push = require("libraries.push")

local font = love.graphics.newFont("assets/FreePixel.ttf", 16)
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

-- ----------------------------------------------------------------------
-- Menu logic
-- ----------------------------------------------------------------------
function Menu.updateMenu(GameInfo)
    local joysticks = love.joystick.getJoysticks()
    local input = getJoystickInput(joysticks[1])
    local input2 = getJoystickInput(joysticks[2])

    -- Move selection if axis is pressed up or down
    if input.moveY < -0.5 then
        GameInfo.selectedOption = 1
    elseif input.moveY > 0.5 then
        GameInfo.selectedOption = 2
    end

    -- Confirm selection with controller
    if input.select or input2.select then
        if GameInfo.selectedOption == 1 then
            GameInfo.previousMode = "game_1P"
        else
            GameInfo.previousMode = "game_2P"
        end
        GameInfo.gameState = "characterselect"
    end
    
end

-- ----------------------------------------------------------------------
-- Menu draw logic
-- ----------------------------------------------------------------------
function Menu.drawMenu(GameInfo)

    -- Clear background to black so the text is visible
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SUNDER", 0, 10, GameInfo.gameWidth, "center", 0, 1, 1)

    local color1 = (GameInfo.selectedOption == 1) and {1, 1, 0, 1} or {1, 1, 1, 1}
    local color2 = (GameInfo.selectedOption == 2) and {1, 1, 0, 1} or {1, 1, 1, 1}

    -- Option 1: 1 PLAYER
    love.graphics.setColor(color1)
    love.graphics.printf("1 PLAYER", GameInfo.gameWidth / 4, 30, GameInfo.gameWidth, "center", 0, .5, .5)

    -- Option 2: 2 PLAYERS
    love.graphics.setColor(color2)
    love.graphics.printf("2 PLAYERS", GameInfo.gameWidth / 4, 40, GameInfo.gameWidth, "center", 0, .5, .5)

    love.graphics.setColor(1,1,1,1)  -- reset
end

function Menu.updateRestartMenu(GameInfo)
    local joystick = love.joystick.getJoysticks()[1]

    -- Confirm selection with 'start' on controller
    if joystick:isGamepadDown("start") then
            startGame(GameInfo.gameState)
    end
end

function Menu.drawRestartMenu(players)
    local p1, p2 = players[1], players[2]

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    if p1.isDead and p2.isDead then
        love.graphics.printf("Nobody Wins", GameInfo.gameWidth / 4, 30, GameInfo.gameWidth, "center", 0, .5, .5)
    elseif p1.isDead then
        love.graphics.printf("Player 2 Wins", GameInfo.gameWidth / 4, 30, GameInfo.gameWidth, "center", 0, .5, .5)
    elseif p2.isDead then
        love.graphics.printf("Player 1 Wins", GameInfo.gameWidth / 4, 30, GameInfo.gameWidth, "center", 0, .5, .5)
    end
    love.graphics.printf("Press start to play again", GameInfo.gameWidth / 4, 40, GameInfo.gameWidth, "center", 0, .5, .5)

end

return Menu
