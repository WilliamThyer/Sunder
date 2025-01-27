--- main.lua ---
if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")

local push = require("libraries.push")
love = require("love")
local Player = require("Player")
local sti = require("libraries.sti")

-- Pick a 16:9 virtual resolution.
local VIRTUAL_WIDTH  = 1280
local VIRTUAL_HEIGHT = 720

local bigFont = love.graphics.newFont("assets/Minecraft.ttf", 32)
love.graphics.setFont(bigFont)

function love.load()
    -- Disable filtering for crisp pixels (still helps old-school look)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Get user's desktop resolution
    local displayWidth, displayHeight = love.window.getDesktopDimensions()

    -- Compute scale WITHOUT flooring, so it's not strictly integer
    local scaleX = displayWidth  / VIRTUAL_WIDTH
    local scaleY = displayHeight / VIRTUAL_HEIGHT
    local finalScale = math.min(scaleX, scaleY)

    -- The actual window size is our virtual size multiplied by finalScale (rounded)
    local windowWidth  = math.floor(VIRTUAL_WIDTH  * finalScale + 0.5)
    local windowHeight = math.floor(VIRTUAL_HEIGHT * finalScale + 0.5)
    -- windowWidth = 800
    -- windowHeight = 450

    -- Push setup
    push:setupScreen(
        VIRTUAL_WIDTH,
        VIRTUAL_HEIGHT,
        windowWidth,
        windowHeight,
        {
            fullscreen   = true,
            resizable    = false,
            vsync        = true,
            pixelperfect = false, -- false => allow non-integer scale
            stretched    = false  -- letterbox to preserve 16:9
        }
    )

    -- Initialize players
    players = {
        Player:new(400, 712, 1),
        Player:new(820, 712, 2)
    }

    map = sti("assets/backgrounds/testNew.lua")
end

function love.update(dt)
    local p1, p2 = players[1], players[2]
    p1:update(dt, p2)
    p2:update(dt, p1)
    map:update()
end

function love.draw()
    map:draw(1*8,2*8+5,10,10)
    for _, player in ipairs(players) do
        player:draw()
    end

end
