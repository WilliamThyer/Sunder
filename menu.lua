local Menu = {}
Menu.__index = Menu
Menu.paused      = false
Menu.pausePlayer = nil
Menu.restartMenu = false

love.graphics.setDefaultFilter("nearest","nearest")

local push = require("libraries.push")
local InputManager = require("InputManager")

-- local font = love.graphics.newFont("assets/Minecraftia-Regular.ttf", 8)
local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

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
    if love.keyboard.isDown(keyboardMap.up) then
        keyboardJustPressed.up = true
    end
    if love.keyboard.isDown(keyboardMap.down) then
        keyboardJustPressed.down = true
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

-- ----------------------------------------------------------------------
-- Menu logic
-- ----------------------------------------------------------------------
function Menu.updateMenu(GameInfo)
    -- Force refresh controllers when in menu to catch any newly connected ones
    InputManager.refreshControllersImmediate()
    
    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()
    
    -- Get input from both controllers
    local input1 = InputManager.get(1)
    local input2 = InputManager.get(2)
    
    -- Get joystick objects for edge detection
    local js1 = InputManager.getJoystick(1)
    local js2 = InputManager.getJoystick(2)
    
    -- Copy and consume justPressed for edge detection
    local justStates = {}
    if js1 then
        local jid1 = js1:getID()
        justStates[1] = justPressed[jid1] or {}
        justPressed[jid1] = nil
    else
        justStates[1] = {}
    end
    
    if js2 then
        local jid2 = js2:getID()
        justStates[2] = justPressed[jid2] or {}
        justPressed[jid2] = nil
    else
        justStates[2] = {}
    end
    
    -- Merge keyboard edge detection into justStates for player 1
    for k,v in pairs(keyboardJustPressed) do
        if v then
            justStates[1][k] = true
        end
    end
    -- Optionally, allow keyboard for player 2 as well (uncomment if desired)
    -- for k,v in pairs(keyboardJustPressed) do
    --     if v then
    --         justStates[2][k] = true
    --     end
    -- end

    -- Allow either controller or keyboard to move the selection
    local moveUp = false
    local moveDown = false
    
    if js1 and (input1.moveY < -0.5) then
        moveUp = true
    elseif js2 and (input2.moveY < -0.5) then
        moveUp = true
    elseif keyboardJustPressed.up then
        moveUp = true
    end
    
    if js1 and (input1.moveY > 0.5) then
        moveDown = true
    elseif js2 and (input2.moveY > 0.5) then
        moveDown = true
    elseif keyboardJustPressed.down then
        moveDown = true
    end
    
    if moveUp then
        GameInfo.selectedOption = 1
    elseif moveDown then
        GameInfo.selectedOption = 2
    end

    -- Check which controller or keyboard pressed A first to determine Player 1
    local p1Pressed = justStates[1] and justStates[1]["a"]
    local p2Pressed = justStates[2] and justStates[2]["a"]
    
    if p1Pressed or p2Pressed then
        -- Determine which controller becomes Player 1
        if p1Pressed then
            -- Controller 1 or keyboard for player 1 pressed A first
            GameInfo.player1Controller = 1
            GameInfo.player2Controller = 2
        else
            -- Controller 2 or keyboard for player 2 pressed A first
            GameInfo.player1Controller = 2
            GameInfo.player2Controller = 1
        end
        
        if GameInfo.selectedOption == 1 then
            GameInfo.previousMode = "game_1P"
            GameInfo.keyboardPlayer = 1
        else
            GameInfo.previousMode = "game_2P"
            -- For 2-player mode, assign keyboard to the player that doesn't have a controller
            if GameInfo.player1Controller == 1 then
                -- P1 has controller 1, so assign keyboard to P2
                GameInfo.keyboardPlayer = 2
            else
                -- P1 has controller 2, so assign keyboard to P2
                GameInfo.keyboardPlayer = 2
            end
        end
        GameInfo.gameState = "characterselect"
        GameInfo.justEnteredCharacterSelect = true
    end
    
    -- Clear keyboard edge detection after processing
    clearKeyboardEdgeDetection()
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

    -- Show keyboard controls if keyboard is enabled
    if GameInfo.keyboardPlayer == 1 or GameInfo.keyboardPlayer == 2 then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf("Use WASD to move, SPACE to select", 0, 50, GameInfo.gameWidth, "center", 0, 0.8, 0.8)
    end

    love.graphics.setColor(1,1,1,1)  -- reset
end

function Menu.updateRestartMenu(GameInfo)
    -- Get input from the human player only (Player 1)
    local humanController = GameInfo.player1Controller or 1
    local input = InputManager.get(humanController)
    
    -- Get joystick object for edge detection
    local js = InputManager.getJoystick(humanController)
    
    -- Copy and consume justPressed for edge detection
    local justStates = {}
    if js then
        local jid = js:getID()
        justStates = justPressed[jid] or {}
        justPressed[jid] = nil
    else
        justStates = {}
    end
    
    -- Add keyboard edge detection if keyboard is enabled for this player
    if InputManager.isKeyboardPlayer(humanController) then
        justStates = keyboardJustPressed
    end

    -- Check for start button press from the human player only
    local startPressed = justStates["start"]
    local yPressed = justStates["y"]

    -- Confirm selection with 'start' on controller
    if startPressed then
        Menu.restartMenu = false
        startGame(GameInfo.gameState)
    -- Press Y to go back to character select
    elseif yPressed then
        Menu.restartMenu = false
        GameInfo.gameState = "characterselect"
        GameInfo.justEnteredCharacterSelect = true
    end
    
    -- Clear keyboard edge detection after processing
    clearKeyboardEdgeDetection()
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

-- Handle keyboard pause input
function Menu.handleKeyboardPauseInput(key)
  -- only during an actual fight
  if not (GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P") then
    return
  end
  if Menu.restartMenu then
    -- if we're in the restart menu, we don't handle pause input
    return
  end

  local keyboardMap = InputManager.getKeyboardMapping()
  
  if key == keyboardMap.start then
    if not Menu.paused then
      Menu.paused = true
      Menu.pausePlayer = "keyboard"
    elseif Menu.pausePlayer == "keyboard" then
      Menu.paused = false
      Menu.pausePlayer = nil
    end
  end

  if Menu.paused 
  and Menu.pausePlayer == "keyboard"
  and key == keyboardMap.y then
    -- return to character select
    Menu.paused = false
    Menu.pausePlayer = nil
    GameInfo.gameState = "characterselect"
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
