if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")

-- Global modules
_G.love = require("love")
_G.anim8 = require 'libraries/anim8'
local Player = require("Player")
local PlayerHelper = require("PlayerHelper")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize players
    players = {
        Player.createPlayer(250, 300, 1),
        Player.createPlayer(550, 300, 2)
    }
end

function love.update(dt)
    -- Update players
    for i, player in ipairs(players) do
        local otherPlayer = players[i % #players + 1] -- Get the other player
        PlayerHelper.updatePlayer(dt, player, otherPlayer)
    end
end

function love.draw()
    -- Draw players
    for _, player in ipairs(players) do
        PlayerHelper.drawPlayer(player)
    end
end
