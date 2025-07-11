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
    gameState = "inputassign",       -- NEW: "inputassign", "menu", "characterselect", "game_1P", "game_2P"
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
    previousMode = nil        -- Track previous mode for char select
}

-- track if a button was pressed this frame
justPressed = {}

local world, map
local players = {}

-- Add at the top, after GameInfo definition:
local inputAssignSpaceReleased = true
local inputAssignStartReleased = {}
local blockMenuSpaceUntilRelease = false

function love.load()
    -- Initialize InputManager
    InputManager.initialize()
    
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
    
    -- Use the controller assignment from GameInfo, or fall back to default if not set
    local p1Controller = GameInfo.player1Controller or 1
    local p2Controller = GameInfo.player2Controller or 2

    if mode == "game_1P" then
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

    for _, p in ipairs(players) do
        world:add(p, p.x+1, p.y, p.width-2, p.height-1)
    end
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

-- Update the game (1P or 2P)
function updateGame(dt)
    if not map then return end
    if #players < 2 then return end

    local p1, p2 = players[1], players[2]
    
    -- Get input from the correct controllers based on GameInfo assignments
    local p1Input = nil
    local p2Input = nil
    
    -- Handle P1 input
    if GameInfo.p1InputType == "keyboard" then
        p1Input = InputManager.getKeyboardInput(1)
    else
        p1Input = InputManager.get(GameInfo.player1Controller)
    end
    
    -- Handle P2 input
    if GameInfo.gameState == "game_1P" then
        -- In 1P mode, P2 is AI controlled, so no input needed
        p2Input = nil
    else
        -- In 2P mode, get P2 input
        if GameInfo.p2InputType == "keyboard" then
            p2Input = InputManager.getKeyboardInput(2)
        else
            p2Input = InputManager.get(GameInfo.player2Controller)
        end
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

    map:update(dt)
end

function love.update(dt)
    -- Update InputManager for periodic controller detection
    InputManager.update(dt)

    if Menu.paused then return end
    if GameInfo.gameState == "inputassign" then
        -- Debug: print all detected joysticks and their IDs
        print("[DEBUG] Detected joysticks:")
        for _, js in ipairs(love.joystick.getJoysticks()) do
            print("  Joystick: ", js:getID(), js:getName())
        end
        -- Input assignment screen: P1 chooses input
        -- Listen for controller Start (edge detection) or Spacebar (keyboard)
        for _, js in ipairs(love.joystick.getJoysticks()) do
            local jid = js:getID()
            if justPressed[jid] and justPressed[jid]["start"] then
                GameInfo.p1InputType = js:getID()
                GameInfo.player1Controller = js:getID()
                GameInfo.keyboardPlayer = nil
                GameInfo.gameState = "menu"
                justPressed[jid]["start"] = nil
                blockMenuSpaceUntilRelease = false
                return
            end
        end
        if not love.keyboard.isDown("space") then
            inputAssignSpaceReleased = true
            blockMenuSpaceUntilRelease = false
        end
        if love.keyboard.isDown("space") and inputAssignSpaceReleased then
            GameInfo.p1InputType = "keyboard"
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
    else
        updateGame(dt)
        -- Always show restart menu when either player dies in 1P or 2P mode
        local shouldShowRestart = false
        if GameInfo.gameState == "game_1P" then
            shouldShowRestart = players[1].isDead or players[2].isDead
        else
            shouldShowRestart = players[1].isDead or players[2].isDead
        end
        if shouldShowRestart then
            Menu.restartMenu = true
            if not Menu.restartMenuOpenedAt then
                Menu.restartMenuOpenedAt = love.timer.getTime() -- Reset input delay timer only once
            end
            Menu.updateRestartMenu(GameInfo)
            Menu.drawRestartMenu(players)
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
            "Press Start (controller) or Space (keyboard) to begin",
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
    else
        if map then map:draw(0, 0, 1, 1) end
        for _, player in ipairs(players) do
            player:draw()
        end
        -- Always show restart menu when either player dies in 1P or 2P mode
        local shouldShowRestart = false
        if GameInfo.gameState == "game_1P" then
            shouldShowRestart = players[1].isDead or players[2].isDead
        else
            shouldShowRestart = players[1].isDead or players[2].isDead
        end
        if shouldShowRestart then
            Menu.restartMenu = true
            if not Menu.restartMenuOpenedAt then
                Menu.restartMenuOpenedAt = love.timer.getTime() -- Reset input delay timer only once
            end
            Menu.drawRestartMenu(players)
        end
        if Menu.paused then
            Menu.drawPauseOverlay()
        end
    end
    push:finish()
end
