-- main.lua

if arg[#arg] == "vsc_debug" then
    require("lldebugger").start()
end
io.stdout:setvbuf("no")
love.graphics.setDefaultFilter("nearest", "nearest")
love = require("love")

local push = require("libraries.push")
local sti  = require("libraries.sti")
local bump = require("libraries.bump")
local Player = require("Player")
local AIController = require("AIController")
local Menu = require("Menu")
local CharacterSelect = require("CharacterSelect")
local InputManager = require("InputManager")

local displayWidth, displayHeight = love.window.getDesktopDimensions()

-- Game info stored in a global table
GameInfo = {
    gameState = "inputassign",       -- NEW: "inputassign", "menu", "characterselect", "game_1P", "game_2P", "game_story", "story_victory"
    selectedOption = 1,       -- which menu option is highlighted
    gameWidth = 128,          -- internal virtual width
    gameHeight = 72,          -- internal virtual height
    displayWidth = displayWidth,
    displayHeight = displayHeight,
    justEnteredCharacterSelect = false,
    p1InputType = nil,        -- "keyboard" or joystick ID
    p2InputType = nil,        -- "keyboard" or joystick ID
    p2Assigned = false,       -- For 2P mode: has P2 picked input yet?
    keyboardPlayer = nil,     -- 1 or 2, which player is using keyboard
    previousMode = nil,       -- Track previous mode for char select
    p1KeyboardMapping = nil,  -- Which keyboard mapping (1 or 2) P1 is using
    p2KeyboardMapping = nil,  -- Which keyboard mapping (1 or 2) P2 is using
    gameStartDelay = nil,      -- Delay timer before starting the game (in seconds)
    pauseSelectedOption = 1,   -- which pause menu option is highlighted (1 = Resume, 2 = Return to Menu)
    restartSelectedOption = 1,  -- which restart menu option is highlighted (1 = Restart Fight, 2 = Return to Menu)
    storyMenuSelectedOption = 1,  -- which story menu option is highlighted (1 = Next Fight/Try Again, 2 = Return to Menu)
    -- Story mode tracking
    storyMode = false,        -- flag to track if in story mode
    storyOpponentIndex = 1,   -- current opponent (1, 2, or 3)
    storyOpponents = {},      -- array of 3 opponent characters to fight
    storyOpponentColors = {}, -- array of 3 opponent colors
    storyPlayerCharacter = nil, -- player's selected character
    storyPlayerColor = nil,    -- player's selected color
    -- Fight start sequence
    fightStartPhase = nil,     -- nil, "ready", or "fight"
    fightStartTimer = nil      -- timer for current phase
}

-- track if a button was pressed this frame
justPressed = {}

local world, map
local players = {}

-- Fight start sound effect
local fightStartSound = nil

-- Initialize fight start sound
local function initFightStartSound()
    local success, sound = pcall(love.audio.newSource, "assets/soundEffects/fightStart.wav", "static")
    if success then
        fightStartSound = sound
        fightStartSound:setLooping(false)
    else
        print("Warning: Could not load fightStart.wav")
    end
end

-- Add at the top, after GameInfo definition:
local inputAssignSpaceReleased = true
local inputAssignStartReleased = {}
local blockMenuSpaceUntilRelease = false

-- Button state tracking to prevent carryover from menus
-- Track last button states per input source (controller ID or "keyboard_P1"/"keyboard_P2")
local lastButtonStates = {}
-- Track if we need to wait for button release after menu transition
local waitForButtonRelease = {
    p1 = false,
    p2 = false
}

-- Function to set button release wait flag and capture current button state
-- Called from Menu when resuming/restarting
function setButtonReleaseWait(playerIndex, inputSource, currentInput)
    if playerIndex == 1 then
        waitForButtonRelease.p1 = true
    elseif playerIndex == 2 then
        waitForButtonRelease.p2 = true
    end
    
    -- Capture current button state
    if inputSource and currentInput then
        lastButtonStates[inputSource] = {
            a = currentInput.a or false,
            b = currentInput.b or false,
            x = currentInput.x or false,
            y = currentInput.y or false
        }
    end
end

function love.load()
    -- Initialize InputManager
    InputManager.initialize()
    
    -- Initialize fight start sound
    initFightStartSound()
    
    -- For pixel art
    push:setupScreen(
        GameInfo.gameWidth,
        GameInfo.gameHeight,
        GameInfo.displayWidth,
        GameInfo.displayHeight,
        {
            fullscreen   = true,
            resizable    = false,
            vsync        = true,
            pixelperfect = true,
            stretched    = false
        }
    )
end

function startGame(mode)
    GameInfo.gameState = mode
    world = bump.newWorld(8)
    map = sti("assets/backgrounds/dungeon.lua", {"bump"})
    map:bump_init(world)

    -- read both character *and* color
    local p1Char  = GameInfo.player1Character or "Warrior"
    local p2Char  = GameInfo.player2Character or "Warrior"
    local p1Color = GameInfo.player1Color     or "Blue"
    local p2Color = GameInfo.player2Color     or "Blue"
    
    -- Story mode: use story mode tracking
    if mode == "game_story" then
        p1Char = GameInfo.storyPlayerCharacter
        p1Color = GameInfo.storyPlayerColor
        p2Char = GameInfo.storyOpponents[GameInfo.storyOpponentIndex]
        p2Color = GameInfo.storyOpponentColors[GameInfo.storyOpponentIndex]
    end
    
    -- Use the controller assignment from GameInfo, or fall back to default if not set
    local p1Controller = GameInfo.player1Controller or 1
    local p2Controller = GameInfo.player2Controller or 2

    if mode == "game_1P" or mode == "game_story" then
        local ai = AIController:new()
        players = {
            -- signature now: Player:new(character, color, x, y, playerIndex, world, aiController)
            -- Note: playerIndex is 1 for left side UI, 2 for right side UI
            Player:new(p1Char, p1Color, 20, 49, 1, world, nil),
            Player:new(p2Char, p2Color, 100, 49, 2, world, ai)
        }
    else
        players = {
            Player:new(p1Char, p1Color, 20, 49, 1, world, nil),
            Player:new(p2Char, p2Color, 100, 49, 2, world, nil)
        }
    end
    
    -- DEBUG: Set P2 health to 1
    -- players[2].health = 1

    for _, p in ipairs(players) do
        world:add(p, p.x+1, p.y, p.width-2, p.height-1)
    end
    
    -- Set up fight start sequence: "Ready" for 1 second
    GameInfo.fightStartPhase = "ready"
    GameInfo.fightStartTimer = 1.0
end

function love.gamepadpressed(joystick, button)
    -- Debug: print which joystick/button was pressed
    print("[DEBUG] gamepadpressed: joystick ID=", joystick:getID(), "button=", button)
    -- 1) Mark "button was pressed this frame" for edge-detection:
    local jid = joystick:getID()
    justPressed[jid] = justPressed[jid] or {}
    justPressed[jid][button] = true

    -- 2) Still forward to pause logic in Menu:
    Menu.handlePauseInput(joystick, button)
end

function love.keypressed(key)
    -- Forward keyboard input to Menu for pause functionality
    local keyboardMap1 = InputManager.getKeyboardMapping(1)
    local keyboardMap2 = InputManager.getKeyboardMapping(2)
    if key == keyboardMap1.start or key == keyboardMap1.y then
        Menu.handleKeyboardPauseInput(key, 1)
    elseif key == keyboardMap2.start or key == keyboardMap2.y then
        Menu.handleKeyboardPauseInput(key, 2)
    else
        -- fallback for legacy or menu
        Menu.handleKeyboardPauseInput(key)
    end
end

-- Helper function to filter button inputs until released after menu transition
local function filterButtonInput(input, inputSource, waitForRelease, playerIndex)
    if not input then
        return input
    end
    
    -- Get the last button state for this input source
    local lastState = lastButtonStates[inputSource] or {}
    
    -- Check if button 'a' was previously pressed
    local aWasPressed = lastState.a or false
    local aIsPressed = input.a or false
    
    -- If we're waiting for release
    if waitForRelease then
        -- If button is still held from before, block it
        if aWasPressed and aIsPressed then
            -- Create a filtered copy of input with 'a' blocked
            local filteredInput = {}
            for k, v in pairs(input) do
                if k == "a" then
                    filteredInput[k] = false
                else
                    filteredInput[k] = v
                end
            end
            -- Update last state (keep tracking that button is still pressed)
            lastButtonStates[inputSource] = {
                a = aIsPressed,
                b = input.b or false,
                x = input.x or false,
                y = input.y or false
            }
            return filteredInput
        end
        
        -- If button was released, we can stop waiting for this player
        if aWasPressed and not aIsPressed then
            if playerIndex == 1 then
                waitForButtonRelease.p1 = false
            elseif playerIndex == 2 then
                waitForButtonRelease.p2 = false
            end
        end
    end
    
    -- Update last state (always track current state)
    lastButtonStates[inputSource] = {
        a = aIsPressed,
        b = input.b or false,
        x = input.x or false,
        y = input.y or false
    }
    
    return input
end

-- Update the game (1P or 2P)
function updateGame(dt)
    if not map then return end
    if #players < 2 then return end

    local p1, p2 = players[1], players[2]
    
    -- Get input from the correct controllers based on GameInfo assignments
    local p1Input = nil
    local p2Input = nil
    local p1InputSource = nil
    local p2InputSource = nil
    
    -- Handle P1 input
    if GameInfo.p1InputType == "keyboard" then
        p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1)
        p1InputSource = "keyboard_P1"
    else
        p1Input = InputManager.get(GameInfo.player1Controller)
        p1InputSource = tostring(GameInfo.player1Controller)
    end
    
    -- Handle P2 input
    if GameInfo.gameState == "game_1P" then
        -- In 1P mode, P2 is AI controlled, so no input needed
        p2Input = nil
        p2InputSource = nil
    else
        -- In 2P mode, get P2 input
        if GameInfo.p2InputType == "keyboard" then
            p2Input = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2)
            p2InputSource = "keyboard_P2"
        else
            p2Input = InputManager.get(GameInfo.player2Controller)
            p2InputSource = tostring(GameInfo.player2Controller)
        end
    end

    -- Filter button inputs to prevent carryover from menus
    if p1Input then
        p1Input = filterButtonInput(p1Input, p1InputSource, waitForButtonRelease.p1, 1)
    end
    if p2Input then
        p2Input = filterButtonInput(p2Input, p2InputSource, waitForButtonRelease.p2, 2)
    end

    -- Block all player updates during fight start sequence
    if GameInfo.fightStartPhase then
        -- Don't update players at all during fight start sequence
        -- Just update the map
        map:update(dt)
        return
    end

    -- Update each player with their input (only pass input to human players)
    p1:update(dt, p2, p1Input)
    -- p1.stamina = 10
    
    -- Only pass input to P2 if they don't have an AI controller
    if p2.aiController then
        p2:update(dt, p1, nil)  -- Let AI controller handle input
    else
        p2:update(dt, p1, p2Input)
    end
    -- p2.stamina = 10
    -- DEBUG: Set P2 health to 1
    -- p2.health = 1

    -- Check if game is over (any player has 0 stocks)
    local gameOver = (p1.stocks == 0 or p2.stocks == 0)
    
    -- Handle respawning (only if game is not over)
    -- Check if P1 needs to respawn (only if they have stocks left and game is not over)
    if not gameOver and p1.isRespawning and p1.respawnDelayTimer <= 0 and p1.stocks > 0 then
        -- Calculate respawn position on opposite side from P2
        local respawnX
        local groundY = 49  -- Ground level
        if not p2.isDead and not p2.isDying and not p2.isRespawning then
            -- P2 is alive, spawn on opposite side
            if p2.x < 64 then  -- P2 is on left side
                respawnX = 100  -- Spawn on right side
            else  -- P2 is on right side
                respawnX = 20   -- Spawn on left side
            end
        else
            -- P2 is also dead/respawning, spawn at default position
            respawnX = 20
        end
        p1:respawn(respawnX, groundY)
    end
    
    -- Check if P2 needs to respawn (only if they have stocks left and game is not over)
    if not gameOver and p2.isRespawning and p2.respawnDelayTimer <= 0 and p2.stocks > 0 then
        -- Calculate respawn position on opposite side from P1
        local respawnX
        local groundY = 49  -- Ground level
        if not p1.isDead and not p1.isDying and not p1.isRespawning then
            -- P1 is alive, spawn on opposite side
            if p1.x < 64 then  -- P1 is on left side
                respawnX = 100  -- Spawn on right side
            else  -- P1 is on right side
                respawnX = 20   -- Spawn on left side
            end
        else
            -- P1 is also dead/respawning, spawn at default position
            respawnX = 100
        end
        p2:respawn(respawnX, groundY)
    end

    map:update(dt)
end

function love.update(dt)
    -- Update InputManager for periodic controller detection
    InputManager.update(dt)

    if Menu.paused then
        -- Update pause menu navigation when paused
        if GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" or GameInfo.gameState == "game_story" then
            Menu.updatePauseMenu(GameInfo)
        end
        return
    end
    if GameInfo.gameState == "inputassign" then
        -- Debug: print all detected joysticks and their IDs
        print("[DEBUG] Detected joysticks:")
        for _, js in ipairs(love.joystick.getJoysticks()) do
            print("  Joystick: ", js:getID(), js:getName())
        end
        -- Input assignment screen: P1 chooses input
        -- Listen for controller A button (edge detection) or Spacebar (keyboard)
        for _, js in ipairs(love.joystick.getJoysticks()) do
            local jid = js:getID()
            if justPressed[jid] and justPressed[jid]["a"] then
                Menu.playMenuSound("downAir")
                GameInfo.p1InputType = js:getID()
                GameInfo.player1Controller = js:getID()
                GameInfo.p1KeyboardMapping = nil
                GameInfo.keyboardPlayer = nil
                GameInfo.gameState = "menu"
                justPressed[jid]["a"] = nil
                blockMenuSpaceUntilRelease = false
                return
            end
        end
        if not love.keyboard.isDown("space") then
            inputAssignSpaceReleased = true
            blockMenuSpaceUntilRelease = false
        end
        if love.keyboard.isDown("space") and inputAssignSpaceReleased then
            Menu.playMenuSound("downAir")
            GameInfo.p1InputType = "keyboard"
            GameInfo.p1KeyboardMapping = 1
            GameInfo.keyboardPlayer = 1
            GameInfo.gameState = "menu"
            inputAssignSpaceReleased = false
            blockMenuSpaceUntilRelease = true
            for _, js in ipairs(love.joystick.getJoysticks()) do
                justPressed[js:getID()] = nil
            end
            return
        end
        return
    end
    -- Block menu Space input until released after assignment
    if GameInfo.gameState == "menu" and blockMenuSpaceUntilRelease then
        if not love.keyboard.isDown("space") then
            blockMenuSpaceUntilRelease = false
        end
        return
    end
    if GameInfo.gameState == "menu" then
        Menu.updateMenu(GameInfo)
    elseif GameInfo.gameState == "characterselect" then
        CharacterSelect.update(GameInfo)
    elseif GameInfo.gameState == "game_starting" then
        -- Initialize game immediately (startGame will set up fight start sequence)
        local mode = GameInfo.previousMode
        startGame(mode)
        -- Transition to actual game state (fight sequence will run during gameplay)
        GameInfo.gameState = mode
        GameInfo.gameStartDelay = nil
    else
        -- Handle fight start sequence
        if GameInfo.fightStartPhase == "ready" then
            -- Countdown "Ready" phase (1 second)
            GameInfo.fightStartTimer = GameInfo.fightStartTimer - dt
            if GameInfo.fightStartTimer <= 0 then
                -- Transition to "Fight!" phase (0.5 second)
                GameInfo.fightStartPhase = "fight"
                GameInfo.fightStartTimer = 0.5
                -- Play fight start sound
                if fightStartSound then
                    fightStartSound:stop()
                    fightStartSound:play()
                end
            end
        elseif GameInfo.fightStartPhase == "fight" then
            -- Countdown "Fight!" phase (0.5 second)
            GameInfo.fightStartTimer = GameInfo.fightStartTimer - dt
            if GameInfo.fightStartTimer <= 0 then
                -- Sequence complete, allow gameplay
                GameInfo.fightStartPhase = nil
                GameInfo.fightStartTimer = nil
            end
        end
        
        updateGame(dt)
        -- Handle story mode fight completion
        if GameInfo.gameState == "game_story" then
            if players[1].stocks == 0 or players[2].stocks == 0 then
                -- Show story menu when fight ends
                Menu.storyMenu = true
                if not Menu.storyMenuOpenedAt then
                    -- Clear all queued button presses to prevent inputs from the fight affecting the menu
                    justPressed = {}
                    Menu.storyMenuOpenedAt = love.timer.getTime() -- Reset input delay timer only once
                end
                local playerWon = (players[2].stocks == 0)
                Menu.updateStoryMenu(GameInfo, playerWon)
            end
        end
        
        -- Show restart menu when either player loses all stocks (stocks == 0)
        local shouldShowRestart = false
        if GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" then
            shouldShowRestart = players[1].stocks == 0 or players[2].stocks == 0
        end
        if shouldShowRestart then
            Menu.restartMenu = true
            if not Menu.restartMenuOpenedAt then
                -- Clear all queued button presses to prevent inputs from the fight affecting the menu
                justPressed = {}
                Menu.restartMenuOpenedAt = love.timer.getTime() -- Reset input delay timer only once
            end
            Menu.updateRestartMenu(GameInfo)
        end
        if Menu.paused then
            Menu.drawPauseOverlay()
        end
    end
end

function love.draw()
    push:start()

    if GameInfo.gameState == "inputassign" then
        -- Draw input assignment screen
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            "Press A or Space to begin",
            0, GameInfo.gameHeight / 2 - 8,
            GameInfo.gameWidth, "center"
        )
        push:finish()
        return
    end
    if GameInfo.gameState == "menu" then
        Menu.drawMenu(GameInfo)
    elseif GameInfo.gameState == "characterselect" then
        CharacterSelect.draw(GameInfo)
    elseif GameInfo.gameState == "game_starting" then
        -- In Story Mode, skip character select screen during fight transitions
        if GameInfo.storyMode then
            love.graphics.clear(0, 0, 0, 1)
        else
            CharacterSelect.draw(GameInfo)
        end
    else
        if map then map:draw(0, 0, 1, 1) end
        for _, player in ipairs(players) do
            player:draw()
        end
        -- Draw fight start sequence text overlay
        if GameInfo.fightStartPhase then
            love.graphics.setColor(1, 1, 1, 1)
            local text = ""
            if GameInfo.fightStartPhase == "ready" then
                text = "Ready"
            elseif GameInfo.fightStartPhase == "fight" then
                text = "Fight!"
            end
            if text ~= "" then
                -- Calculate center position accounting for scale
                local scale = 2
                local font = love.graphics.getFont()
                local textWidth = font:getWidth(text) * scale
                local textHeight = font:getHeight() * scale
                local x = (GameInfo.gameWidth - textWidth) / 2
                local y = (GameInfo.gameHeight - textHeight) / 2
                love.graphics.print(text, x, y, 0, scale, scale)
            end
        end
        -- Show restart menu when either player loses all stocks (stocks == 0)
        local shouldShowRestart = false
        if GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" then
            shouldShowRestart = players[1].stocks == 0 or players[2].stocks == 0
        end
        if shouldShowRestart then
            Menu.restartMenu = true
            if not Menu.restartMenuOpenedAt then
                -- Clear all queued button presses to prevent inputs from the fight affecting the menu
                justPressed = {}
                Menu.restartMenuOpenedAt = love.timer.getTime() -- Reset input delay timer only once
            end
            Menu.drawRestartMenu(players)
        end
        -- Show story menu when story mode fight ends
        if Menu.storyMenu and GameInfo.gameState == "game_story" then
            local playerWon = (players[2].stocks == 0)
            Menu.drawStoryMenu(playerWon)
        end
        if Menu.paused then
            Menu.drawPauseOverlay()
        end
    end
    push:finish()
end
