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
local RemapMenu = require("RemapMenu")

local displayWidth, displayHeight = love.window.getDesktopDimensions()

-- Game info stored in a global table
GameInfo = {
    gameState = "menu",       -- "menu", "characterselect", "game_1P", "game_2P", "game_story", "story_victory"
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
    storyOpponentIndex = 1,   -- current opponent (1, 2, 3, or 4)
    storyOpponents = {},      -- array of 4 opponent characters to fight
    storyOpponentColors = {}, -- array of 4 opponent colors
    storyPlayerCharacter = nil, -- player's selected character
    storyPlayerColor = nil,    -- player's selected color
    storyPlayerHealth = nil,   -- player's health to persist between battles (nil = start fresh)
    storyPlayerStocks = nil,   -- player's stocks to persist between battles (nil = start fresh)
    -- Fight start sequence
    fightStartPhase = nil,     -- nil, "ready", or "fight"
    fightStartTimer = nil,     -- timer for current phase
    -- Freeze frame system
    freezeFrameTimer = 0,      -- current freeze frame timer (0 = not frozen)
    freezeFrameEnabled = true,  -- toggle to enable/disable freeze frames
    -- Hit flash system
    hitFlashTimer = 0,         -- current hit flash timer (0 = no flash)
    hitFlashEnabled = true,     -- toggle to enable/disable hit flash
    -- Remap menu system
    remapMenuActive = false,   -- whether remap menu is showing
    remapMenuPlayer = nil,     -- which player (1 or 2) is remapping
    remapMenuSelectedOption = 1, -- which action is selected (1-8 for actions, 9-10 for Save/Back)
    remapMenuRemapping = nil   -- which action is being remapped (nil if not in remap mode)
}

-- Freeze Frame Configuration
-- Easily adjustable values for freeze frame duration per attack type
FreezeFrameConfig = {
    -- Global multiplier: adjust this to make all freeze frames stronger/weaker
    globalMultiplier = 1.0,
    
    -- Base durations in seconds for each attack type
    -- Increase these values for longer freeze frames, decrease for shorter
    durations = {
        lightAttack = 0.05,    -- 50ms base duration
        heavyAttack = 0.12,    -- 120ms base duration
        downAir = 0.08,       -- 80ms base duration
        shockWave = 0.06,    -- 60ms base duration
        shieldHit = 0.03,    -- 30ms base duration (blocks)
        counter = 0.10,       -- 100ms base duration (successful counters)
        death = 0.15          -- 150ms base duration (deaths)
    }
}

-- Hit Flash Configuration
-- Configurable hit flash duration
HitFlashConfig = {
    -- Global multiplier: adjust this to make all hit flashes stronger/weaker
    globalMultiplier = 1.0,
    
    -- Base duration in seconds for hit flash
    -- Increase for longer flash, decrease for shorter
    duration = 0.05  -- 50ms base duration
}

-- track if a button was pressed this frame
justPressed = {}

local world, map
local players = {}

-- Fight start sound effect
local fightStartSound = nil
local menuSoundPlayed = false  -- Track if we've played the sound for the initial menu display

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
    
    -- Load menu background map
    GameInfo.menuMap = sti("assets/backgrounds/menu.lua")
    
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

-- Select map based on game mode
-- For 1P/2P: random selection from all maps
-- For story mode: map determined by opponent character
local function selectMap(mode)
    if mode == "game_story" then
        -- Story mode: map based on opponent character
        local opponentChar = GameInfo.storyOpponents[GameInfo.storyOpponentIndex]
        local mapMapping = {
            Warrior = "dungeon",
            Berserk = "desert",
            Lancer = "forest",
            Mage = "laboratory"
        }
        local mapName = mapMapping[opponentChar] or "dungeon"  -- fallback to dungeon
        return "assets/backgrounds/" .. mapName .. ".lua"
    else
        -- 1P or 2P mode: random selection
        local maps = {"desert", "dungeon", "forest", "laboratory"}
        local randomIndex = love.math.random(1, #maps)
        return "assets/backgrounds/" .. maps[randomIndex] .. ".lua"
    end
end

function startGame(mode)
    GameInfo.gameState = mode
    world = bump.newWorld(8)
    local mapPath = selectMap(mode)
    map = sti(mapPath, {"bump"})
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
    
    -- In gauntlet mode (story mode), restore player health and stocks from previous battle
    if mode == "game_story" and GameInfo.storyPlayerHealth ~= nil and GameInfo.storyPlayerStocks ~= nil then
        players[1].health = GameInfo.storyPlayerHealth
        players[1].stocks = GameInfo.storyPlayerStocks
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

-- Freeze Frame Functions
function triggerFreezeFrame(attackType)
    if not GameInfo.freezeFrameEnabled then return end
    
    local baseDuration = FreezeFrameConfig.durations[attackType] or 0.05
    local duration = baseDuration * FreezeFrameConfig.globalMultiplier
    GameInfo.freezeFrameTimer = math.max(GameInfo.freezeFrameTimer, duration)
end

function updateFreezeFrame(dt)
    if GameInfo.freezeFrameTimer > 0 then
        GameInfo.freezeFrameTimer = GameInfo.freezeFrameTimer - dt
        if GameInfo.freezeFrameTimer < 0 then
            GameInfo.freezeFrameTimer = 0
        end
    end
end

function isFrozen()
    return GameInfo.freezeFrameTimer > 0
end

-- Hit Flash Functions
function triggerHitFlash()
    if not GameInfo.hitFlashEnabled then return end
    
    local duration = HitFlashConfig.duration * HitFlashConfig.globalMultiplier
    GameInfo.hitFlashTimer = math.max(GameInfo.hitFlashTimer, duration)
end

function updateHitFlash(dt)
    if GameInfo.hitFlashTimer > 0 then
        GameInfo.hitFlashTimer = GameInfo.hitFlashTimer - dt
        if GameInfo.hitFlashTimer < 0 then
            GameInfo.hitFlashTimer = 0
        end
    end
end

function getHitFlashAlpha()
    if GameInfo.hitFlashTimer <= 0 then
        return 0
    end
    -- Fade from 1.0 to 0.0 over the duration
    -- Use the remaining timer divided by the base duration to get alpha
    local baseDuration = HitFlashConfig.duration * HitFlashConfig.globalMultiplier
    return math.min(1.0, GameInfo.hitFlashTimer / baseDuration)
end

-- Update the game (1P or 2P)
function updateGame(dt)
    if not map then return end
    if #players < 2 then return end

    -- Handle freeze frames: if frozen, don't update game logic
    if isFrozen() then
        -- Only update freeze frame timer and map (for visual continuity)
        updateFreezeFrame(dt)
        map:update(dt)
        return
    end

    local p1, p2 = players[1], players[2]
    
    -- Get input from the correct controllers based on GameInfo assignments
    local p1Input = nil
    local p2Input = nil
    local p1InputSource = nil
    local p2InputSource = nil
    
    -- Handle P1 input (use custom mappings for gameplay)
    if GameInfo.p1InputType == "keyboard" then
        p1Input = InputManager.getKeyboardInput(GameInfo.p1KeyboardMapping or 1, false)  -- useMenuDefaults = false for gameplay
        p1InputSource = "keyboard_P1"
    else
        p1Input = InputManager.get(GameInfo.player1Controller, false)  -- useMenuDefaults = false for gameplay
        p1InputSource = tostring(GameInfo.player1Controller)
    end
    
    -- Handle P2 input
    if GameInfo.gameState == "game_1P" then
        -- In 1P mode, P2 is AI controlled, so no input needed
        p2Input = nil
        p2InputSource = nil
    else
        -- In 2P mode, get P2 input (use custom mappings for gameplay)
        if GameInfo.p2InputType == "keyboard" then
            p2Input = InputManager.getKeyboardInput(GameInfo.p2KeyboardMapping or 2, false)  -- useMenuDefaults = false for gameplay
            p2InputSource = "keyboard_P2"
        else
            p2Input = InputManager.get(GameInfo.player2Controller, false)  -- useMenuDefaults = false for gameplay
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
    -- Update freeze frame timer (always update, even when paused)
    updateFreezeFrame(dt)
    
    -- Update hit flash timer (always update, even when paused)
    updateHitFlash(dt)
    
    -- Update InputManager for periodic controller detection
    InputManager.update(dt)

    -- Check for remap menu (takes priority over other game states)
    if GameInfo.remapMenuActive then
        RemapMenu.update(GameInfo)
        return
    end

    if Menu.paused then
        -- Update pause menu navigation when paused
        if GameInfo.gameState == "game_1P" or GameInfo.gameState == "game_2P" or GameInfo.gameState == "game_story" then
            Menu.updatePauseMenu(GameInfo)
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
        
        -- Only update game if not frozen (freeze frame handling is inside updateGame)
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
                -- Store player health and stocks for gauntlet mode persistence before advancing
                if playerWon then
                    GameInfo.storyPlayerHealth = players[1].health
                    GameInfo.storyPlayerStocks = players[1].stocks
                end
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

    -- Check for remap menu (draws on top of character select)
    if GameInfo.remapMenuActive then
        -- Draw character select background first
        if GameInfo.gameState == "characterselect" then
            CharacterSelect.draw(GameInfo)
        else
            love.graphics.clear(0, 0, 0, 1)
        end
        -- Draw remap menu on top
        RemapMenu.draw(GameInfo)
        push:finish()
        return
    end

    if GameInfo.gameState == "menu" then
        -- Play fight start sound when main menu is first displayed
        if not menuSoundPlayed and fightStartSound then
            fightStartSound:play()
            menuSoundPlayed = true
        end
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
        
        -- Draw hit flash overlay (white screen flash on damage)
        if GameInfo.hitFlashTimer > 0 then
            local alpha = getHitFlashAlpha()
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.rectangle("fill", 0, 0, GameInfo.gameWidth, GameInfo.gameHeight)
            love.graphics.setColor(1, 1, 1, 1)  -- Reset color to white/opaque
        end
    end
    push:finish()
end
