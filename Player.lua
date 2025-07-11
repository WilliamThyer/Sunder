-- Player.lua
local Berserker   = require("Berserker")
local Warrior     = require("Warrior")
local Lancer     = require("Lancer")
local Mage     = require("Mage")
local Player      = {}
Player.__index    = Player

function Player:new(characterType, colorName, x, y, playerIndex, world, aiController)
      local fighterClass

    if characterType == "Berserk" then
        fighterClass = Berserker
    elseif characterType == "Lancer" then
        fighterClass = Lancer
    elseif characterType == "Mage" then
        fighterClass = Mage
    else
        -- fallback (Warrior covers "Warrior" and any unrecognized string)
        fighterClass = Warrior
    end

    local fighterInstance =
        fighterClass:new(x, y, playerIndex, world, aiController, colorName)

    local instance = { base = fighterInstance }

    setmetatable(instance, {
        __index = function(t, k)
            -- Player methods first, then fighter methods
            if Player[k] then
                return Player[k]
            else
                return fighterInstance[k]
            end
        end,
        __newindex = function(t, k, v)
            -- write through to fighter if it already has that field
            if fighterInstance[k] ~= nil then
                fighterInstance[k] = v
            else
                rawset(t, k, v)
            end
        end
    })

    return instance
end

function Player:update(dt, otherPlayer, input)
    -- If input is provided, convert it to the expected format; otherwise get it from the controller
    if input then
        -- Convert InputManager format to the format expected by processInput
        input = {
            jump        = input.x,
            lightAttack = input.a,
            heavyAttack = input.b,
            attack      = (input.a or input.b),
            dash        = input.shoulderR,
            shield      = input.shoulderL,
            moveX       = input.moveX,
            down        = input.moveY > 0.5,
            counter     = input.y
        }
    else
        input = self:getPlayerInput(dt, otherPlayer)
    end
    
    self:processInput(dt, input)
    self:moveWithBump(dt)
    self:handleAttacks(dt, otherPlayer)
    self:handleDownAir(dt, otherPlayer)
    self:updateHurtState(dt)
    self:updateCounter(dt)
    self:updateLandingLag(dt)
    self:updateStamina(dt)
    self:updateAnimation(dt)
end

function Player:getPlayerInput(dt, otherPlayer)
    if self.aiController then
        return self.aiController:getInput(dt, self, otherPlayer)
    end
    
    -- Use InputManager to get input for this player
    local InputManager = require("InputManager")
    
    -- Get the correct controller index based on player position
    local controllerIndex
    if self.index == 1 then
        controllerIndex = GameInfo.player1Controller or 1
    else
        controllerIndex = GameInfo.player2Controller or 2
    end
    
            local input = InputManager.get(controllerIndex, self.playerIndex)
    
    -- Convert InputManager format to the format expected by processInput
    return {
        jump        = input.x,
        lightAttack = input.a,
        heavyAttack = input.b,
        attack      = (input.a or input.b),
        dash        = input.shoulderR,
        shield      = input.shoulderL,
        moveX       = input.moveX,
        down        = input.moveY > 0.5,
        counter     = input.y
    }
end

return Player
