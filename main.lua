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
    gameState = "menu",       -- "menu", "game_1P", or "game_2P"
    selectedOption = 1,       -- which menu option is highlighted
    gameWidth = 128,          -- internal virtual width
    gameHeight = 72,          -- internal virtual height
    displayWidth = displayWidth,
    displayHeight = displayHeight,
    justEnteredCharacterSelect = false
}

-- track if a button was pressed this frame
justPressed = {}

local world, map
local players = {}

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
    -- 1) Mark "button was pressed this frame" for edge-detection:
    local jid = joystick:getID()
    justPressed[jid] = justPressed[jid] or {}
    justPressed[jid][button] = true

    -- 2) Still forward to pause logic in Menu:
    Menu.handlePauseInput(joystick, button)
end

function love.keypressed(key)
    -- Forward keyboard input to Menu for pause functionality
    Menu.handleKeyboardPauseInput(key)
end

-- Update the game (1P or 2P)
function updateGame(dt)
    if not map then return end
    if #players < 2 then return end

    local p1, p2 = players[1], players[2]
    
    -- Use the controller assignment from GameInfo, or fall back to default if not set
    local p1Controller = GameInfo.player1Controller or 1
    local p2Controller = GameInfo.player2Controller or 2

    -- Get input from InputManager for human players
    local p1Input = InputManager.get(p1Controller)
    local p2Input = InputManager.get(p2Controller)
    
    -- Merge keyboard input for P1 only if keyboard is enabled for P1
    local keyboardInput = InputManager.getKeyboardInput()
    if keyboardInput and GameInfo.keyboardPlayer == 1 then
        -- Combine axes (favor nonzero, or sum if both pressed)
        local moveX = p1Input.moveX ~= 0 and p1Input.moveX or keyboardInput.moveX
        if p1Input.moveX ~= 0 and keyboardInput.moveX ~= 0 then
            moveX = p1Input.moveX + keyboardInput.moveX
            if moveX > 1 then moveX = 1 elseif moveX < -1 then moveX = -1 end
        end
        local moveY = p1Input.moveY ~= 0 and p1Input.moveY or keyboardInput.moveY
        if p1Input.moveY ~= 0 and keyboardInput.moveY ~= 0 then
            moveY = p1Input.moveY + keyboardInput.moveY
            if moveY > 1 then moveY = 1 elseif moveY < -1 then moveY = -1 end
        end
        
        p1Input.moveX = moveX
        p1Input.moveY = moveY
        p1Input.a = p1Input.a or keyboardInput.a
        p1Input.b = p1Input.b or keyboardInput.b
        p1Input.x = p1Input.x or keyboardInput.x
        p1Input.y = p1Input.y or keyboardInput.y
        p1Input.start = p1Input.start or keyboardInput.start
        p1Input.back = p1Input.back or keyboardInput.back
        p1Input.shoulderL = p1Input.shoulderL or keyboardInput.shoulderL
        p1Input.shoulderR = p1Input.shoulderR or keyboardInput.shoulderR
    end
    
    -- Merge keyboard input for P2 only if keyboard is enabled for P2
    if GameInfo.KeyboardPlayer == 2 and keyboardInput then
        -- Combine axes (favor nonzero, or sum if both pressed)
        local moveX = p2Input.moveX ~= 0 and p2Input.moveX or keyboardInput.moveX
        if p2Input.moveX ~= 0 and keyboardInput.moveX ~= 0 then
            moveX = p2Input.moveX + keyboardInput.moveX
            if moveX > 1 then moveX = 1 elseif moveX < -1 then moveX = -1 end
        end
        local moveY = p2Input.moveY ~= 0 and p2Input.moveY or keyboardInput.moveY
        if p2Input.moveY ~= 0 and keyboardInput.moveY ~= 0 then
            moveY = p2Input.moveY + keyboardInput.moveY
            if moveY > 1 then moveY = 1 elseif moveY < -1 then moveY = -1 end
        end
        
        p2Input.moveX = moveX
        p2Input.moveY = moveY
        p2Input.a = p2Input.a or keyboardInput.a
        p2Input.b = p2Input.b or keyboardInput.b
        p2Input.x = p2Input.x or keyboardInput.x
        p2Input.y = p2Input.y or keyboardInput.y
        p2Input.start = p2Input.start or keyboardInput.start
        p2Input.back = p2Input.back or keyboardInput.back
        p2Input.shoulderL = p2Input.shoulderL or keyboardInput.shoulderL
        p2Input.shoulderR = p2Input.shoulderR or keyboardInput.shoulderR
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
            Menu.updateRestartMenu(GameInfo)
        end
    end
end

function love.draw()
    push:start()

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
            Menu.drawRestartMenu(players)
        end
        if Menu.paused then
            Menu.drawPauseOverlay()
        end
    end
    push:finish()
end
