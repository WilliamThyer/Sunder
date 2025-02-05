local Menu = {}
Menu.__index = Menu

local push = require("libraries.push")

local bigFont = love.graphics.newFont("assets/Minecraft.ttf", 200)
local font = love.graphics.newFont("assets/Minecraft.ttf", 100)

-- ----------------------------------------------------------------------
-- Menu logic
-- ----------------------------------------------------------------------
function Menu.updateMenu(GameInfo)
    local joystick = love.joystick.getJoysticks()[1]

    -- Check controller input first
    if joystick then
        local axisY = joystick:getGamepadAxis("lefty") or 0
        -- Move selection if axis is pressed up or down
        if axisY < -0.5 then
            GameInfo.selectedOption = 1
        elseif axisY > 0.5 then
            GameInfo.selectedOption = 2
        end

        -- Confirm selection with 'A' on controller
        if joystick:isGamepadDown("a") then
            if GameInfo.selectedOption == 1 then
                startGame("game_1P")
            else
                startGame("game_2P")
            end
        end
    else
        -- Fallback to keyboard input
        if love.keyboard.isDown("up") then
            GameInfo.selectedOption = 1
        elseif love.keyboard.isDown("down") then
            GameInfo.selectedOption = 2
        end

        -- Confirm selection with Enter
        if love.keyboard.isDown("return") then
            if GameInfo.selectedOption == 1 then
                startGame("game_1P")
            else
                startGame("game_2P")
            end
        end
    end
end

-- ----------------------------------------------------------------------
-- Menu draw logic
-- ----------------------------------------------------------------------
function Menu.drawMenu(GameInfo)
    push:finish()
    -- Clear background to black so the text is visible
    love.graphics.clear(0, 0, 0, 1)

    -- Use the *display* or *game* width for centering
    -- but since we're in push virtual coords, let's center using GameInfo.gameWidth
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(bigFont)
    love.graphics.printf("SUNDER", 0, 100, GameInfo.displayWidth, "center")

    local color1 = (GameInfo.selectedOption == 1) and {1, 1, 0, 1} or {1, 1, 1, 1}
    local color2 = (GameInfo.selectedOption == 2) and {1, 1, 0, 1} or {1, 1, 1, 1}

    -- Option 1: 1 PLAYER
    love.graphics.setColor(color1)
    love.graphics.setFont(font)
    love.graphics.printf("1 PLAYER", 0, 350, GameInfo.displayWidth, "center")

    -- Option 2: 2 PLAYERS
    love.graphics.setColor(color2)
    love.graphics.printf("2 PLAYERS", 0, 450, GameInfo.displayWidth, "center")

    love.graphics.setColor(1,1,1,1)  -- reset
    push:start()
end

function Menu.updateRestartMenu(GameInfo)
    local joystick = love.joystick.getJoysticks()[1]

    -- Confirm selection with 'start' on controller
    if joystick:isGamepadDown("start") then
            startGame(GameInfo.gameState)
    end
end

function Menu.drawRestartMenu(players)
    push:finish()
    local p1, p2 = players[1], players[2]

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(bigFont)
    if p1.isDead and p2.isDead then
        love.graphics.printf("Nobody Wins", 0, 100, GameInfo.displayWidth, "center")
    elseif p1.isDead then
        love.graphics.printf("Player 2 Wins", 0, 100, GameInfo.displayWidth, "center")
    elseif p2.isDead then
        love.graphics.printf("Player 1 Wins", 0, 100, GameInfo.displayWidth, "center")
    end
    love.graphics.setFont(font)
    love.graphics.printf("Press start to play again", 0, 300, GameInfo.displayWidth, "center")

    push:start()
end

return Menu
