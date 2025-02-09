-- Player.lua
local Warrior   = require("Warrior")
local Berserker = require("Berserker")

local Player = {}
Player.__index = Player
local characterType = "warrior"

function Player:new(characterType, x, y, joystickIndex, world, aiController)
    local baseClass
    if characterType == "berserker" then
        baseClass = Berserker
    else
        baseClass = Warrior
    end

    -- Create the actual base instance
    local baseInstance = baseClass:new(x, y, joystickIndex, world, aiController)

    -- Now make a new table that can see both `Player` and `baseInstance`.
    local instance = {
        base = baseInstance  -- store the base in a field
    }

    -- The custom __index looks up Player methods first, else fallback to baseInstance
    setmetatable(instance, {
        __index = function(t, k)
            return Player[k] or t.base[k]
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
