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

-- GAME RESOLUTION: small, pixel-art-friendly, 16:9 ratio
local GAME_WIDTH  = 128
local GAME_HEIGHT = 72

function love.load()
    -- For pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Get user's desktop resolution
    local displayWidth, displayHeight = love.window.getDesktopDimensions()
    displayWidth = 512
    displayHeight = 288

    -- Decide on either fullscreen or windowed, your choice.
    -- We'll do windowed in this example:
    push:setupScreen(
        GAME_WIDTH,          -- “virtual” / game resolution width
        GAME_HEIGHT,         -- “virtual” / game resolution height
        displayWidth,        -- actual window width
        displayHeight,       -- actual window height
        {
        fullscreen   = false,
        resizable    = false,
        vsync        = true,
        pixelperfect = true,  -- ensures integer scaling
        stretched    = false  -- letterbox to preserve aspect
        }
    )

    -- Load the Tiled map
    world = bump.newWorld(8)
    map = sti("assets/backgrounds/testNew.lua", {"bump"})
    map:bump_init(world)

    -- Create AI for player 2:
    local ai = AIController:new()
    local ai2 = AIController:new()

    -- Initialize players
    players = {
        Player:new(20, 49, 1, world, ai2),       -- Human
        Player:new(100, 49, 2, world, ai)        -- AI
    }
    for _, player in ipairs(players) do
        world:add(player, player.x+1, player.y, player.width-2, player.height-1)
    end
end

function love.update(dt)
    local p1, p2 = players[1], players[2]

    p1:update(dt, p2)
    p2:update(dt, p1)

    map:update(dt)  -- in case your STI map has dynamic layers, etc.
end

function love.draw()
    -- Start push
    push:start()

    -- Draw Tiled map
    map:draw(0, 0, 1, 1)

    -- Draw players
    for _, player in ipairs(players) do
        player:draw()
    end

    -- End push
    push:finish()
end
