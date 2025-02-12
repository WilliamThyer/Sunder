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
local CharacterSelect = require("CharacterSelect")

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

function startGame(mode)
    GameInfo.gameState = mode  -- mode is now either "game_1P" or "game_2P"

    world = bump.newWorld(8)
    map = sti("assets/backgrounds/testNew.lua", {"bump"})
    map:bump_init(world)

    local p1Character = GameInfo.player1Character or "warrior"
    local p2Character = GameInfo.player2Character or "warrior"

    if mode == "game_1P" then
        local ai = AIController:new()
        players = {
            Player:new(p1Character, 20, 49, 1, world, nil),
            Player:new(p2Character, 100, 49, 2, world, ai)
        }
    else
        players = {
            Player:new(p1Character, 20, 49, 1, world, nil),
            Player:new(p2Character, 100, 49, 2, world, nil)
        }
    end

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
    elseif GameInfo.gameState == "characterselect" then
        CharacterSelect.update(GameInfo)
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
    elseif GameInfo.gameState == "characterselect" then
        CharacterSelect.draw(GameInfo)
    else
        if map then map:draw(0, 0, 1, 1) end

        for _, player in ipairs(players) do
            player:draw()
        end

        if players[1].isDead or players[2].isDead then
            Menu.drawRestartMenu(players)
        end
    end

    push:finish()
end
