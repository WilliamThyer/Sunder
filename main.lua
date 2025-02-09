-- main.lua

if arg[#arg] == "vsc_debug" then
    require("lldebugger").start()
end
io.stdout:setvbuf("no")

love = require("love")

local push = require("libraries.push")
local sti  = require("libraries.sti")
local bump = require("libraries.bump")
local Player = require("Player")
local AIController = require("AIController")
local Menu = require("Menu")

local displayWidth, displayHeight = love.window.getDesktopDimensions()

-- Game info stored in a global table
GameInfo = {
    gameState = "menu",       -- "menu", "game_1P", or "game_2P"
    selectedOption = 1,       -- which menu option is highlighted
    gameWidth = 128,          -- internal virtual width
    gameHeight = 72,          -- internal virtual height
    displayWidth = displayWidth,
    displayHeight = displayHeight
    -- displayWidth = 512,
    -- displayHeight = 288
}

local world, map
local players = {}

function love.load()
    -- For pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")

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

-- Start the game after menu selection
function startGame(mode)
    -- Update the global state
    GameInfo.gameState = mode

    -- Create collision world
    world = bump.newWorld(8)

    -- Load map
    map = sti("assets/backgrounds/testNew.lua", {"bump"})
    map:bump_init(world)

    if GameInfo.gameState == "game_1P" then
        -- If 1P mode, Player 2 is AI
        local ai = AIController:new()
        players = {
            Player:new("berserker", 20, 49, 1, world, nil),  -- Player 1 (human)
            Player:new("berserker", 100, 49, 2, world, ai)   -- Player 2 (AI)
        }
    else
        -- 2P mode: both human
        players = {
            Player:new("berserker", 20, 49, 1, world, nil),
            Player:new("berserker", 100, 49, 2, world, nil)
        }
    end

    -- Add players to bump world
    for _, p in ipairs(players) do
        world:add(p, p.x+1, p.y, p.width-2, p.height-1)
    end
end

-- Update the game (1P or 2P)
function updateGame(dt)
    if not map then return end
    if #players < 2 then return end

    local p1, p2 = players[1], players[2]

    -- Update each player
    p1:update(dt, p2)
    p2:update(dt, p1)

    map:update(dt)
end

function love.update(dt)
    if GameInfo.gameState == "menu" then
        Menu.updateMenu(GameInfo)
    else
        updateGame(dt)
        if players[1].isDead or players[2].isDead then
            Menu.updateRestartMenu(GameInfo)
        end
    end
end

function love.draw()
    push:start()

    if GameInfo.gameState == "menu" then
        Menu.drawMenu(GameInfo)
    else
        if map then
            map:draw(0, 0, 1, 1)
        end

        for _, player in ipairs(players) do
            player:draw()
        end
        if players[1].isDead or players[2].isDead then
            Menu.drawRestartMenu(players)
        end
    end

    push:finish()
end
