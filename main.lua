-- main.lua
-- This sets up the game environment, loads players, updates and draws them.

if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")

-- We still need the Love2D modules
love = require("love")  -- Globally, but you can localize if you prefer

local Player = require("Player")  -- The new Player class (which inherits from CharacterBase)

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize the two players
    players = {
        Player:new(250, 300, 1),
        Player:new(550, 300, 2)
    }
end

function love.update(dt)
    -- Update players
    -- For a 2-player scenario:
    local p1, p2 = players[1], players[2]

    p1:update(dt, p2)
    p2:update(dt, p1)
end

function love.draw()
    -- Draw players
    for _, player in ipairs(players) do
        player:draw()
    end
end
