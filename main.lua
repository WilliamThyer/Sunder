-- main.lua
if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")

local push = require("libraries.push")
local Player = require("Player")
local sti = require("libraries.sti")

-- Define a lower virtual resolution for easier scaling
local VIRTUAL_WIDTH  = 160
local VIRTUAL_HEIGHT = 90

-- Define the scale factor
local SCALE = 8

local WINDOW_WIDTH  = VIRTUAL_WIDTH * SCALE  -- 1280
local WINDOW_HEIGHT = VIRTUAL_HEIGHT * SCALE -- 720

local bigFont

function love.load()
    -- Set nearest filter for pixel-perfect scaling
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Load and set the font
    bigFont = love.graphics.newFont("assets/Minecraft.ttf", 16) -- Adjust font size as needed
    love.graphics.setFont(bigFont)

    -- Push setup with integer scaling
    push:setupScreen(
        VIRTUAL_WIDTH,
        VIRTUAL_HEIGHT,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        {
            fullscreen   = false,
            resizable    = false,
            vsync        = true,
            pixelperfect = true, -- Enable pixel-perfect scaling
            stretched    = false  -- Maintain aspect ratio with letterboxing if necessary
        }
    )

    -- Initialize players with positions relative to the base resolution
    players = {
        Player:new(50, VIRTUAL_HEIGHT - 18, 1),  -- Adjusted y-position for ground
        Player:new(110, VIRTUAL_HEIGHT - 18, 2)
    }

    -- Load the background map
    map = sti("assets/backgrounds/testNew.lua")
end

function love.update(dt)
    players[1]:update(dt, players[2])
    players[2]:update(dt, players[1])
    map:update(dt)
end

function love.draw()
    push:apply('start')

    -- Draw the background without additional scaling
    map:draw()

    -- Draw players
    for _, player in ipairs(players) do
        player:draw()
    end

    push:apply('end')

    -- Draw UI elements outside Push scaling
    for _, player in ipairs(players) do
        player:drawUI()
    end
end

function love.resize(w, h)
    push:resize(w, h)
end
