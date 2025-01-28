-- main.lua
if arg[#arg] == "vsc_debug" then
    require("lldebugger").start()
end
io.stdout:setvbuf("no")

love = require("love")

local push = require("libraries.push")
local sti  = require("libraries.sti")

local Player = require("Player")

-- GAME RESOLUTION: small, pixel-art-friendly, 16:9 ratio
local GAME_WIDTH  = 128
local GAME_HEIGHT = 72

function love.load()
    -- For pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Get user's desktop resolution
    local displayWidth, displayHeight = love.window.getDesktopDimensions()

    -- Decide on either fullscreen or windowed, your choice.
    -- We'll do windowed in this example:
    push:setupScreen(
        GAME_WIDTH,          -- “virtual” / game resolution width
        GAME_HEIGHT,         -- “virtual” / game resolution height
        displayWidth,        -- actual window width
        displayHeight,       -- actual window height
        {
        fullscreen   = true,
        resizable    = false,
        vsync        = true,
        pixelperfect = true,  -- ensures integer scaling
        stretched    = false  -- letterbox to preserve aspect
        }
    )

    -- Load the Tiled map
    map = sti("assets/backgrounds/testNew.lua")

    -- Initialize players
    -- Place them near bottom of the map, e.g. (20, 64) and (100, 64)
    players = {
        Player:new(20, 49, 1),
        Player:new(100, 49, 2)
    }
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

    -- Draw Tiled map at (0,0) with NO extra scale now.
    map:draw(0, 0)

    -- Draw players
    for _, player in ipairs(players) do
        player:draw()
    end

    -- End push
    push:finish()
end
