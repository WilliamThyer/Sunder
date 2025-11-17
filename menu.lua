local Menu = {}
Menu.__index = Menu
Menu.paused      = false
Menu.pausePlayer = nil
Menu.restartMenu = false
Menu.restartMenuOpenedAt = nil -- Timestamp when restart menu was opened
Menu.restartMenuInputDelay = 0.5 -- Seconds to wait before accepting input

love.graphics.setDefaultFilter("nearest","nearest")

local push = require("libraries.push")
local InputManager = require("InputManager")

-- local font = love.graphics.newFont("assets/Minecraftia-Regular.ttf", 8)
local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

-- ----------------------------------------------------------------------
-- Menu sound effects
-- ----------------------------------------------------------------------
local menuSounds = {}

-- Initialize menu sound effects with error handling
local function initMenuSounds()
    local success, counter = pcall(love.audio.newSource, "assets/soundEffects/counter.wav", "static")
    if success then
        menuSounds.counter = counter
        menuSounds.counter:setLooping(false)
    else
        print("Warning: Could not load counter.wav")
    end
    
    local success2, downAir = pcall(love.audio.newSource, "assets/soundEffects/downAir.wav", "static")
    if success2 then
        menuSounds.downAir = downAir
        menuSounds.downAir:setLooping(false)
    else
        print("Warning: Could not load downAir.wav")
    end
    
    local success3, shield = pcall(love.audio.newSource, "assets/soundEffects/shield.wav", "static")
    if success3 then
        menuSounds.shield = shield
        menuSounds.shield:setLooping(false)
    else
        print("Warning: Could not load shield.wav")
    end
end

-- Safely play a menu sound effect
local function playMenuSound(soundName)
    if menuSounds[soundName] then
        menuSounds[soundName]:stop()
        menuSounds[soundName]:play()
    end
end

-- Export playMenuSound for use in other modules
Menu.playMenuSound = playMenuSound

-- Initialize sounds when module loads
initMenuSounds()

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
    local keyboardMap1 = InputManager.getKeyboardMapping(1)
    local keyboardMap2 = InputManager.getKeyboardMapping(2)
    
    -- Check for key presses this frame for P1
    if love.keyboard.isDown(keyboardMap1.a) then
        keyboardJustPressed.a = true
    end
    if love.keyboard.isDown(keyboardMap1.b) then
        keyboardJustPressed.b = true
    end
    if love.keyboard.isDown(keyboardMap1.x) then
        keyboardJustPressed.x = true
    end
    if love.keyboard.isDown(keyboardMap1.y) then
        keyboardJustPressed.y = true
    end
    if love.keyboard.isDown(keyboardMap1.start) then
        keyboardJustPressed.start = true
    end
    if love.keyboard.isDown(keyboardMap1.back) then
        keyboardJustPressed.back = true
    end
    if love.keyboard.isDown(keyboardMap1.up) then
        keyboardJustPressed.up = true
    end
    if love.keyboard.isDown(keyboardMap1.down) then
        keyboardJustPressed.down = true
    end
    if love.keyboard.isDown(keyboardMap1.left) then
        keyboardJustPressed.left = true
    end
    if love.keyboard.isDown(keyboardMap1.right) then
        keyboardJustPressed.right = true
    end
    -- Optionally, add similar checks for P2 if you want edge detection for both
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
-- Track previous selection to detect actual changes
local previousSelectedOption = nil

function Menu.updateMenu(GameInfo)
    -- Initialize selectedOption if not set (defaults to option 1)
    if not GameInfo.selectedOption then
        GameInfo.selectedOption = 1
    end
    
    -- Force refresh controllers when in menu to catch any newly connected ones
    InputManager.refreshControllersImmediate()
    
    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()
    
    -- Get input from the correct controllers based on GameInfo assignments
    local p1Input = nil
    local p2Input = nil
    
    -- Handle P1 input
    if GameInfo.p1InputType == "keyboard" then
        p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
    else
        p1Input = InputManager.get(GameInfo.player1Controller)
    end
    
    -- For menu navigation, we can use any available controller or keyboard
    -- Get joystick objects for edge detection
    local js1 = InputManager.getJoystick(GameInfo.player1Controller)
    local js2 = nil
    if GameInfo.p2InputType and GameInfo.p2InputType ~= "keyboard" then
        js2 = InputManager.getJoystick(GameInfo.player2Controller)
    end
    
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

    -- Allow either controller or keyboard to move the selection
    local moveUp = false
    local moveDown = false
    
    if js1 and (p1Input.moveY < -0.5) then
        moveUp = true
    elseif js2 and (p2Input and p2Input.moveY < -0.5) then
        moveUp = true
    elseif keyboardJustPressed.up then
        moveUp = true
    end
    
    if js1 and (p1Input.moveY > 0.5) then
        moveDown = true
    elseif js2 and (p2Input and p2Input.moveY > 0.5) then
        moveDown = true
    elseif keyboardJustPressed.down then
        moveDown = true
    end
    
    -- Track current selection before updating
    local currentSelection = GameInfo.selectedOption or 1
    
    -- Update selection and play sound only if it actually changed
    if moveUp then
        if currentSelection ~= 1 then
            playMenuSound("counter")
        end
        GameInfo.selectedOption = 1
        previousSelectedOption = 1
    elseif moveDown then
        if currentSelection ~= 2 then
            playMenuSound("counter")
        end
        GameInfo.selectedOption = 2
        previousSelectedOption = 2
    else
        -- No movement, preserve previous selection for next frame comparison
        previousSelectedOption = currentSelection
    end

    -- Check which controller or keyboard pressed A first to determine Player 1
    local p1Pressed = justStates[1] and justStates[1]["a"]
    local p2Pressed = justStates[2] and justStates[2]["a"]
    
    if p1Pressed or p2Pressed then
        -- Play selection sound
        playMenuSound("downAir")
        
        if GameInfo.selectedOption == 1 then
            GameInfo.previousMode = "game_1P"
            GameInfo.keyboardPlayer = 1
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2Assigned = false
        else
            GameInfo.previousMode = "game_2P"
            GameInfo.p2InputType = nil
            GameInfo.player2Controller = nil
            GameInfo.p2Assigned = false
            GameInfo.keyboardPlayer = nil
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
    -- if GameInfo.keyboardPlayer == 1 or GameInfo.keyboardPlayer == 2 then
    --     love.graphics.setColor(0.7, 0.7, 0.7, 1)
    --     love.graphics.printf("Use WASD to move, SPACE to select", 0, 50, GameInfo.gameWidth, "center", 0, 1, 1)
    -- end

    love.graphics.setColor(1,1,1,1)  -- reset
end

function Menu.updateRestartMenu(GameInfo)
    -- Wait for input delay
    if not Menu.restartMenuOpenedAt then
        Menu.restartMenuOpenedAt = love.timer.getTime()
        return
    end
    local now = love.timer.getTime()
    if now - Menu.restartMenuOpenedAt < Menu.restartMenuInputDelay then
        return
    end

    -- Update keyboard edge detection
    updateKeyboardEdgeDetection()

    local isTwoPlayer = (GameInfo.gameState == "game_2P")
    local startPressed, yPressed = false, false

    if isTwoPlayer then
        -- 2P mode: Either player can input
        -- Check P1 input
        if GameInfo.p1InputType == "keyboard" then
            startPressed = startPressed or keyboardJustPressed["a"]
            yPressed = yPressed or keyboardJustPressed["y"]
        else
            local js1 = InputManager.getJoystick(GameInfo.player1Controller)
            if js1 then
                local jid = js1:getID()
                local justStates = justPressed[jid] or {}
                justPressed[jid] = nil
                startPressed = startPressed or justStates["a"]
                yPressed = yPressed or justStates["y"]
            end
        end
        
        -- Check P2 input
        if GameInfo.p2InputType == "keyboard" then
            startPressed = startPressed or keyboardJustPressed["a"]
            yPressed = yPressed or keyboardJustPressed["y"]
        else
            local js2 = InputManager.getJoystick(GameInfo.player2Controller)
            if js2 then
                local jid = js2:getID()
                local justStates = justPressed[jid] or {}
                justPressed[jid] = nil
                startPressed = startPressed or justStates["a"]
                yPressed = yPressed or justStates["y"]
            end
        end
    else
        -- 1P mode: Only P1 (the human player) can input
        -- Check keyboard input for P1
        if GameInfo.p1InputType == "keyboard" then
            startPressed = keyboardJustPressed["a"]
            yPressed = keyboardJustPressed["y"]
        end
        
        -- Check controller input for P1 (if P1 is using a controller)
        if GameInfo.p1InputType ~= "keyboard" and GameInfo.player1Controller then
            local js1 = InputManager.getJoystick(GameInfo.player1Controller)
            if js1 then
                local jid = js1:getID()
                local justStates = justPressed[jid] or {}
                justPressed[jid] = nil
                startPressed = startPressed or justStates["a"]
                yPressed = yPressed or justStates["y"]
            end
        end
    end

    -- Confirm selection with 'a' button on controller
    if startPressed then
        Menu.restartMenu = false
        Menu.restartMenuOpenedAt = nil
        startGame(GameInfo.gameState)
    -- Press Y to go back to character select
    elseif yPressed then
        -- Play back/go back sound
        playMenuSound("shield")
        Menu.restartMenu = false
        Menu.restartMenuOpenedAt = nil
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
    love.graphics.printf("Press A to play again", GameInfo.gameWidth / 12, 30, GameInfo.gameWidth*.9, "center", 0, 1, 1)
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
function Menu.handleKeyboardPauseInput(key, playerIndex)
  -- only during an actual fight
  if not (GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P") then
    return
  end
  if Menu.restartMenu then
    -- if we're in the restart menu, we don't handle pause input
    return
  end

  local keyboardMap = InputManager.getKeyboardMapping(playerIndex or 1)
  
  if key == keyboardMap.start then
    if not Menu.paused then
      Menu.paused = true
      Menu.pausePlayer = playerIndex or "keyboard"
    elseif Menu.pausePlayer == (playerIndex or "keyboard") then
      Menu.paused = false
      Menu.pausePlayer = nil
    end
  end

  if Menu.paused 
  and Menu.pausePlayer == (playerIndex or "keyboard")
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
