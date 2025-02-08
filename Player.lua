-- Player.lua
local Warrior = require("Warrior")
local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Warrior })

function Player:new(x, y, joystickIndex, world, aiController)
    local instance = Warrior.new(self, x, y, joystickIndex, world, aiController)
    setmetatable(instance, Player)
    return instance
end

function Player:update(dt, otherPlayer)
    local input = self:getPlayerInput(dt, otherPlayer)
    self:processInput(dt, input)
    self:moveWithBump(dt)        -- <--- Bump-based environment collision
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
