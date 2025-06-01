-- CharacterSelect.lua
-- Uses a global `justPressed[jid][button] = true` populated in love.gamepadpressed.
-- Edge‐detection (“was pressed this frame”) comes from consuming `justPressed`.

local CharacterSelect = {}
CharacterSelect.__index = CharacterSelect

local push = require("libraries.push")
love.graphics.setDefaultFilter("nearest", "nearest")

-- === Predefined colors for players ===
local colorOptions = {
    {127/255, 146/255, 237/255},  -- Blue
    {234/255,  94/255,  94/255},  -- Red
    {141/255, 141/255, 141/255},  -- Gray
    {241/255, 225/255, 115/255},  -- Yellow
}
local colorNames = {"Blue", "Red", "Gray", "Yellow"}

-- List of characters
local characters = {"Warrior", "Berserk", "Duelist", "Mage"}

-- Load sprite sheets for the characters that have sprites
local sprites = {
    Warrior = {
       Red    = love.graphics.newImage("assets/sprites/WarriorRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/WarriorBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/WarriorYellow.png"),
       Gray   = love.graphics.newImage("assets/sprites/WarriorGray.png")
    },
    Berserk = {
       Red    = love.graphics.newImage("assets/sprites/BerserkRed.png"),
       Blue   = love.graphics.newImage("assets/sprites/BerserkBlue.png"),
       Yellow = love.graphics.newImage("assets/sprites/BerserkYellow.png"),
       Gray   = love.graphics.newImage("assets/sprites/BerserkGray.png")
    }
}

-- Quads for the first sprite of each sheet
local warriorQuad = love.graphics.newQuad(
    0, 1, 9, 8,
    sprites.Warrior.Blue:getWidth(),
    sprites.Warrior.Blue:getHeight()
)
local berserkQuad = love.graphics.newQuad(
    1, 2, 13, 13,
    sprites.Berserk.Blue:getWidth(),
    sprites.Berserk.Blue:getHeight()
)

-- Per-player state (two players: 1 and 2)
--   locked: whether that player has pressed A to lock in
--   cursor: which character index is highlighted (1..#characters)
--   moveCooldown: to prevent too-fast joystick scrolling
--   prevY, prevSelect, prevBack, prevStart: (no longer needed here)
--   colorIndex: which color (1..4) is chosen
local playerSelections = {
    [1] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 1 },
    [2] = { cursor = 1, locked = false, moveCooldown = 0, colorIndex = 2 }
}

local font = love.graphics.newFont("assets/6px-Normal.ttf", 8)
font:setFilter("nearest", "nearest")
love.graphics.setFont(font)

-----------------------------------------------------
-- Helper: Advance colorIndex for `playerIndex`, skipping the other player's color
-----------------------------------------------------
local function cycleColor(playerIndex)
    local otherIndex = (playerIndex == 1) and 2 or 1
    local maxAttempts = #colorOptions
    local attempts = 0

    repeat
        playerSelections[playerIndex].colorIndex =
            playerSelections[playerIndex].colorIndex + 1

        if playerSelections[playerIndex].colorIndex > #colorOptions then
            playerSelections[playerIndex].colorIndex = 1
        end

        attempts = attempts + 1
    until (
        playerSelections[playerIndex].colorIndex ~=
        playerSelections[otherIndex].colorIndex
    ) or (attempts >= maxAttempts)
end

-----------------------------------------------------
-- Update a single player’s selection given the `input` table
--   `input` fields (all booleans except moveX/moveY):
--     select      = true if “A was pressed this frame”
--     back        = true if “B was pressed this frame”
--     start       = true if “START was pressed this frame”
--     changeColor = true if “Y was pressed this frame”
--     moveX, moveY = current axis values for left stick
-----------------------------------------------------
function CharacterSelect.updateCharacter(input, playerIndex, dt)
    local ps = playerSelections[playerIndex]
    ps.moveCooldown = math.max(0, ps.moveCooldown - dt)

    -- 1) Move cursor left/right if not locked
    if (not ps.locked) and ps.moveCooldown <= 0 then
        local move = 0
        if input.moveX < -0.5 then move = -1
        elseif input.moveX >  0.5 then move =  1 end

        if move ~= 0 then
            ps.cursor = ps.cursor + move
            if ps.cursor < 1 then
                ps.cursor = #characters
            elseif ps.cursor > #characters then
                ps.cursor = 1
            end
            ps.moveCooldown = 0.25
        end
    end

    -- 2) Y (changeColor) toggles through available colors (only if not locked)
    if input.changeColor then
        cycleColor(playerIndex)
    end

    -- 3) If not locked, A (select) locks in character. If already locked, B (back) unlocks.
    if not ps.locked then
        if input.select then
            ps.locked = true
        end
    else
        if input.back then
            ps.locked = false
        end
    end
end

-----------------------------------------------------
-- Main update for the character select screen.
--   Relies on a global `justPressed[jid][button]` table,
--   which gets cleared each frame after consumption.
-----------------------------------------------------
function CharacterSelect.update(GameInfo)
    -- 1) If we just entered this screen, reset all selections AND clear any leftover justPressed so no input carries over:
    if GameInfo.justEnteredCharacterSelect then
        for i = 1, 2 do
            playerSelections[i].locked       = false
            playerSelections[i].cursor       = 1
            playerSelections[i].moveCooldown = 0
            playerSelections[i].colorIndex   = (i == 1) and 1 or 2
        end
        -- Clear all justPressed entries so A/Y presses that opened this screen are ignored:
        for jid, _ in pairs(justPressed) do
            justPressed[jid] = nil
        end
        GameInfo.justEnteredCharacterSelect = false
    end


    local isOnePlayer = (GameInfo.previousMode == "game_1P")
    local joysticks   = love.joystick.getJoysticks()
    local dt = love.timer.getDelta()

    -- 2) For edge detection, copy and consume `justPressed` for each joystick index (1 & 2).
    --    After this, justPressed[jid] is nil, so it won’t fire twice next frame.
    local justStates = {}
    for i = 1, 2 do
        local js = joysticks[i]
        if js then
            local jid = js:getID()
            justStates[i] = justPressed[jid] or {}
            justPressed[jid] = nil
        else
            justStates[i] = {}
        end
    end

    -- 3) Build `input1` and `input2` tables to feed into updateCharacter():
    local function makeInput(i)
        local js = joysticks[i]
        local just = justStates[i]
        return {
            select      = (just["a"]     == true),
            back        = (just["b"]     == true),
            start       = (just["start"] == true),
            changeColor = (just["y"]     == true),
            moveX       = js and (js:getGamepadAxis("leftx") or 0) or 0,
            moveY       = js and (js:getGamepadAxis("lefty") or 0) or 0
        }
    end

    local input1 = makeInput(1)
    local input2 = makeInput(2)

    -- 4) One-Player Logic:
    if isOnePlayer then
        -- Handle “B” globally: 
        --   If P2 is locked, unlock P2; elseif P1 is locked, unlock P1; else exit to menu.
        if input1.back then
            if playerSelections[2].locked then
                playerSelections[2].locked = false
            elseif playerSelections[1].locked then
                playerSelections[1].locked = false
            else
                GameInfo.gameState = "menu"
                return
            end
        end

        -- If P1 is not yet locked, update P1; otherwise update P2 with the same joystick.
        if not playerSelections[1].locked then
            CharacterSelect.updateCharacter(input1, 1, dt)
        else
            CharacterSelect.updateCharacter(input1, 2, dt)
        end

    -- 5) Two-Player Logic:
    else
        -- If P1 is unlocked and presses B, exit to menu; same for P2.
        if (not playerSelections[1].locked) and input1.back then
            GameInfo.gameState = "menu"
            return
        end
        if (not playerSelections[2].locked) and input2.back then
            GameInfo.gameState = "menu"
            return
        end

        if joysticks[1] then
            CharacterSelect.updateCharacter(input1, 1, dt)
        end
        if joysticks[2] then
            CharacterSelect.updateCharacter(input2, 2, dt)
        end
    end

    -- 6) Start game when both players are locked and any START was just pressed.
    if playerSelections[1].locked and playerSelections[2].locked then
        if input1.start or input2.start then
            CharacterSelect.beginGame(GameInfo)
        end
    end
end

-----------------------------------------------------
-- Called when both players have locked in their characters.
-----------------------------------------------------
function CharacterSelect.beginGame(GameInfo)
    GameInfo.player1Character = characters[playerSelections[1].cursor]
    GameInfo.player2Character = characters[playerSelections[2].cursor]

    GameInfo.player1Color = colorNames[playerSelections[1].colorIndex]
    GameInfo.player2Color = colorNames[playerSelections[2].colorIndex]

    GameInfo.gameState = GameInfo.previousMode
    startGame(GameInfo.gameState)
end

-----------------------------------------------------
-- Draw the character select screen (unchanged from before).
-----------------------------------------------------
function CharacterSelect.draw(GameInfo)
    love.graphics.clear(0, 0, 0, 1)

    local gameWidth   = GameInfo.gameWidth
    local gameHeight  = GameInfo.gameHeight
    local isOnePlayer = (GameInfo.previousMode == "game_1P")

    -- === Draw player info boxes at the top ===
    local boxWidth   = 16
    local boxHeight  = 16
    local paddingX   = 32
    local paddingY   = 10

    local p1BoxX = paddingX
    local p1BoxY = paddingY
    local p2BoxX = gameWidth - boxWidth - paddingX
    local p2BoxY = paddingY

    local function getPlayerColor(playerIndex)
        local ci = playerSelections[playerIndex].colorIndex
        return colorOptions[ci][1], colorOptions[ci][2], colorOptions[ci][3]
    end

    -- --- Draw Player 1's box ---
    if playerSelections[1].locked then
        love.graphics.setColor(getPlayerColor(1))
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.rectangle("line", p1BoxX, p1BoxY, boxWidth, boxHeight)
    local p1Char = characters[playerSelections[1].cursor]
    if p1Char == "Warrior" or p1Char == "Berserk" then
        local colName = colorNames[playerSelections[1].colorIndex]
        local image, quad, spriteW, spriteH
        if p1Char == "Warrior" then
            image, quad = sprites.Warrior[colName], warriorQuad
            spriteW, spriteH = 8, 8
        else
            image, quad = sprites.Berserk[colName], berserkQuad
            spriteW, spriteH = 12, 12
        end
        local offsetX = (boxWidth - spriteW) / 2
        local offsetY = (boxHeight - spriteH) / 2
        love.graphics.draw(image, quad, p1BoxX + offsetX, p1BoxY + offsetY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 1", p1BoxX - boxWidth/2 - 22, p1BoxY - 9, boxWidth*5, "center", 0, 1, 1)

    -- --- Draw Player 2's box ---
    if playerSelections[2].locked then
        love.graphics.setColor(getPlayerColor(2))
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.rectangle("line", p2BoxX, p2BoxY, boxWidth, boxHeight)
    local p2Char = characters[playerSelections[2].cursor]
    if p2Char == "Warrior" or p2Char == "Berserk" then
        local colName = colorNames[playerSelections[2].colorIndex]
        local image, quad, spriteW, spriteH
        if p2Char == "Warrior" then
            image, quad = sprites.Warrior[colName], warriorQuad
            spriteW, spriteH = 8, 8
        else
            image, quad = sprites.Berserk[colName], berserkQuad
            spriteW, spriteH = 12, 12
        end
        local offsetX = (boxWidth - spriteW) / 2
        local offsetY = (boxHeight - spriteH) / 2
        love.graphics.draw(image, quad, p2BoxX + offsetX, p2BoxY + offsetY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 2", p2BoxX - boxWidth/2 - 22, p2BoxY - 9, boxWidth*5, "center", 0, 1, 1)

    -- === Draw character boxes in the center ===
    local charBoxWidth   = 16
    local charBoxHeight  = 16
    local startX         = 6
    local startY         = p1BoxY + boxHeight + 20
    local charBoxPadding = 16

    for i, charName in ipairs(characters) do
        local x = startX + (i - 1) * (charBoxWidth + charBoxPadding)
        local y = startY
        love.graphics.rectangle("line", x, y, charBoxWidth, charBoxHeight)

        -- Draw a gray preview if we have a sprite
        if charName == "Warrior" then
            local image, quad = sprites.Warrior["Gray"], warriorQuad
            local spriteW, spriteH = 8, 8
            local offsetX = (charBoxWidth - spriteW) / 2
            local offsetY = (charBoxHeight - spriteH) / 2
            love.graphics.draw(image, quad, x + offsetX, y + offsetY, 0, 1, 1, 0, -1)
        elseif charName == "Berserk" then
            local image, quad = sprites.Berserk["Gray"], berserkQuad
            local spriteW, spriteH = 12, 12
            local offsetX = (charBoxWidth - spriteW) / 2
            local offsetY = (charBoxHeight - spriteH) / 2
            love.graphics.draw(image, quad, x + offsetX, y + offsetY)
        end

        love.graphics.printf(
          charName,
          x - charBoxWidth * 2,
          y - charBoxHeight/2 - 1,
          charBoxWidth * 5,
          "center",
          0, 1, 1
        )
    end

    -- === Draw each player’s cursor below the character boxes ===
    local cursorY     = startY + charBoxHeight + 7
    local arrowSize   = 5
    local charSpacing = charBoxPadding

    for playerIndex = 1, 2 do
        if isOnePlayer and playerIndex == 2 and (not playerSelections[1].locked) then
            -- Hide CPU’s cursor until P1 locks
        else
            local cs = playerSelections[playerIndex]
            local cursorIndex = cs.cursor
            local offsetX = (playerIndex == 1) and -3 or 3
            local x = startX + (cursorIndex - 1) * (charBoxWidth + charSpacing)
                     + charBoxWidth/2 + offsetX
            local y = cursorY

            love.graphics.setColor(getPlayerColor(playerIndex))
            love.graphics.polygon(
              "fill",
              x - arrowSize/2, y,
              x + arrowSize/2, y,
              x, y - arrowSize
            )
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- If both locked, prompt “Press START to begin!”
    if playerSelections[1].locked and playerSelections[2].locked then
        love.graphics.printf(
          "Press start to begin!",
          0, gameHeight - 43,
          gameWidth, "center", 0, 1, 1
        )
    end
end

return CharacterSelect
