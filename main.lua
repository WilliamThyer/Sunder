if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")

_G.love = require("love")
anim8 = require 'libraries/anim8'
local Player = require("Player")
local PlayerHelper = require("PlayerHelper")

-- print(("Player 1 is hurt:%s"):format(player1.isHurt))
print('starting game')

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  -- Create two players
  Player1 = Player.createPlayer(250, 700, 1)
  Player2 = Player.createPlayer(1250, 700, 2)
end

function love.update(dt)
  PlayerHelper.updatePlayer(dt, Player1, Player2)
  PlayerHelper.updatePlayer(dt, Player2, Player1)
end

function love.draw()
  PlayerHelper.drawPlayer(Player1)
  PlayerHelper.drawPlayer(Player2)
end
