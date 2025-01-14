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
  player1 = Player.createPlayer(250, 700, 1)
  player2 = Player.createPlayer(1250, 700, 2)
end

function love.update(dt)
  PlayerHelper.updatePlayer(dt, player1, player2)
  PlayerHelper.updatePlayer(dt, player2, player1)
end

function love.draw()
  PlayerHelper.drawPlayer(player1)
  PlayerHelper.drawPlayer(player2)
end
