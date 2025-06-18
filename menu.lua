local Menu = {}
Menu.__index = Menu
Menu.paused      = false
Menu.pausePlayer = nil
Menu.restartMenu = false

love.graphics.setDefaultFilter("nearest","nearest")

local push = require("libraries.push")

-- local font = love.graphics.newFont("assets/Minecraftia-Regular.ttf", 8)
local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

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
        GameInfo.justEnteredCharacterSelect = true
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
    love.graphics.printf("SUNDER", 0, 10, GameInfo.gameWidth/2, "center", 0, 2, 2)

    local color1 = (GameInfo.selectedOption == 1) and {1, 1, 0, 1} or {1, 1, 1, 1}
    local color2 = (GameInfo.selectedOption == 2) and {1, 1, 0, 1} or {1, 1, 1, 1}

    -- Option 1: 1 PLAYER
    love.graphics.setColor(color1)
    love.graphics.printf("1 PLAYER", 0, 30, GameInfo.gameWidth, "center", 0, 1, 1)

    -- Option 2: 2 PLAYERS
    love.graphics.setColor(color2)
    love.graphics.printf("2 PLAYERS", 0, 40, GameInfo.gameWidth, "center", 0, 1, 1)

    love.graphics.setColor(1,1,1,1)  -- reset
end

function Menu.updateRestartMenu(GameInfo)
    local joystick = love.joystick.getJoysticks()[1]

    -- Confirm selection with 'start' on controller
    if joystick:isGamepadDown("start") then
        Menu.restartMenu = false
        startGame(GameInfo.gameState)
    -- Press Y to go back to character select
    elseif joystick:isGamepadDown("y") then
        Menu.restartMenu = false
        GameInfo.gameState = "characterselect"
        GameInfo.justEnteredCharacterSelect = true
    end
end

function Menu.drawRestartMenu(players)
    local p1, p2 = players[1], players[2]

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    if p1.isDead and p2.isDead then
        love.graphics.printf("Nobody Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    elseif p1.isDead then
        love.graphics.printf("Player 2 Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    elseif p2.isDead then
        love.graphics.printf("Player 1 Wins", GameInfo.gameWidth / 4, 20, GameInfo.gameWidth/2, "center", 0, 1, 1)
    end
    love.graphics.printf("Press start to play again", GameInfo.gameWidth / 12, 30, GameInfo.gameWidth*.9, "center", 0, 1, 1)
    love.graphics.printf("Press Y to return to menu", GameInfo.gameWidth / 12, 40, GameInfo.gameWidth*.9, "center", 0, 1, 1)

end

-- called by love.gamepadpressed in main.lua
function Menu.handlePauseInput(joystick, button)
  -- only during an actual fight
  if not (GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P") then
    return
  end
  if Menu.restartMenu then
    -- if we're in the restart menu, we don't handle pause input
    return
  end

  if button == "start" then
    if not Menu.paused then
      Menu.paused      = true
      Menu.pausePlayer = joystick:getID()
    elseif joystick:getID() == Menu.pausePlayer then
      Menu.paused      = false
      Menu.pausePlayer = nil
    end
  end

  if Menu.paused 
  and joystick:getID() == Menu.pausePlayer
  and button == "y" then
    -- return to character select
    Menu.paused      = false
    Menu.pausePlayer = nil
    GameInfo.gameState               = "characterselect"
    GameInfo.justEnteredCharacterSelect = true
  end
end

function Menu.drawPauseOverlay()
  -- a translucent black
  love.graphics.setColor(0,0,0,0.75)
  love.graphics.rectangle("fill", 0,0, GameInfo.gameWidth, GameInfo.gameHeight)
  love.graphics.setColor(1,1,1,1)
  love.graphics.printf(
    "PAUSED\nPress START to resume\nPress Y to return to menu",
    0, GameInfo.gameHeight/2 - 10,
    GameInfo.gameWidth, "center"
  )
end


return Menu
