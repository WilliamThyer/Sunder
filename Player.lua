-- Player.lua
local Berserker   = require("Berserker")
local Warrior     = require("Warrior")
local Player      = {}
Player.__index    = Player

function Player:new(characterType, colorName, x, y, joystickIndex, world, aiController)
    -- pick your fighter class
    local fighterClass = (characterType == "Berserk") and Berserker or Warrior

    -- create the actual fighter (passes colorName through to constructor)
    local fighterInstance = fighterClass:new(x, y, joystickIndex, world, aiController, colorName)

    -- build the Player wrapper
    local instance = {
        base = fighterInstance
    }

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

function Player:update(dt, otherPlayer)
    -- Because we changed the instance’s metatable to Player,
    -- we can now refer to self’s methods or data. If you want
    -- to invoke the baseClass version of update (Warrior or Berserker)
    -- you’d call something like `Warrior.update(self, dt, otherPlayer)`
    -- or `getmetatable(self):update(dt, otherPlayer)` if needed.
    --
    -- But if the base class has no `update()`, then just do your usual:
    local input = self:getPlayerInput(dt, otherPlayer)
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
    if not self.joystick then
        return {
            heavyAttack = false,
            lightAttack = false,
            jump        = false,
            dash        = false,
            shield      = false,
            moveX       = 0,
            down        = false,
            counter     = false,
            attack      = false,
        }
    end
    return {
        jump        = self.joystick:isGamepadDown("x"),
        lightAttack = self.joystick:isGamepadDown("a"),
        heavyAttack = self.joystick:isGamepadDown("b"),
        attack      = (self.joystick:isGamepadDown("a") or self.joystick:isGamepadDown("b")),
        dash        = self.joystick:isGamepadDown("rightshoulder"),
        shield      = self.joystick:isGamepadDown("leftshoulder"),
        moveX       = self.joystick:getGamepadAxis("leftx") or 0,
        down        = (self.joystick:getGamepadAxis("lefty") or 0) > 0.5,
        counter     = self.joystick:isGamepadDown("y")
    }
end

return Player
