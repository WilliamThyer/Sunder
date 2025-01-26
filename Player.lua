--- player.lua ---
local CharacterBase = require("CharacterBase")
local anim8 = require("libraries.anim8")

local Player = {}
Player.__index = Player
setmetatable(Player, { __index = CharacterBase })  -- Inherit from CharacterBase

function Player:new(x, y, joystickIndex)
    local obj = CharacterBase:new(x, y)
    setmetatable(obj, Player)

    obj.index       = joystickIndex
    obj.joystick    = love.joystick.getJoysticks()[joystickIndex]

    obj.attackPressedLastFrame = false
    obj.JumpPressedLastFrame   = false
    obj.dashPressedLastFrame   = false
    obj.counterPressedLastFrame= false

    obj:initializeAnimations()
    return obj
end

function Player:initializeAnimations()
    self.spriteSheet = love.graphics.newImage("sprites/Hero_update.png")

    self.grid = anim8.newGrid(8, 8,
                              self.spriteSheet:getWidth(),
                              self.spriteSheet:getHeight(),
                              0)
    self.attackGrid = anim8.newGrid(12, 12,
                                    self.spriteSheet:getWidth(),
                                    self.spriteSheet:getHeight(),
                                    8 * 6,
                                    0
                                )

    self.animations = {
        move    = anim8.newAnimation(self.grid('3-4', 1), 0.2),
        jump    = anim8.newAnimation(self.grid(3, 2), 1),
        idle    = anim8.newAnimation(self.grid('3-4', 6), 0.7),
        dash    = anim8.newAnimation(self.grid(1, 4), 1),
        heavyAttack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.1, 0.25, 0.05, 0.1}),
        lightAttack  = anim8.newAnimation(self.attackGrid('1-2', 5), {0.175, .325}),
        downAir      = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.2, 0.8}),
        shield       = anim8.newAnimation(self.grid(5, 1), 1),
        hurt         = anim8.newAnimation(self.grid(3, 7), 1),
        counter      = anim8.newAnimation(self.grid(4, 2), .5),
    }

    self.currentAnim = self.animations.idle
end

--------------------------------------------------------------------------
-- Standard update sequence
--------------------------------------------------------------------------
function Player:update(dt, otherPlayer)
    local input = self:getPlayerInput()

    self:processInput(dt, input)
    self:handleAttacks(dt, otherPlayer)
    self:handleDownAir(dt, otherPlayer)
    self:updateHurtState(dt)
    self:resolveCollision(otherPlayer)
    self:updateCounter(dt)
    self:updateStamina(dt)
    self:updateAnimation(dt)
end

function Player:draw()
    local scaleX = 8 * self.direction
    local offsetX = (self.direction == -1) and (8 * 8) or 0
    local offsetY = 0

    if self.isAttacking then
        offsetY = -4 * 8
    end

    self.currentAnim:draw(
        self.spriteSheet,
        self.x + offsetX,
        self.y + offsetY,
        0,
        scaleX,
        8
    )

    -- Simple printing of health/stamina above each player
    love.graphics.print("P" .. self.index .. " HP: " .. self.health .. " / " .. self.maxHealth,
                        self.x, self.y - 30)
    love.graphics.print("STM: " .. self.stamina .. " / " .. self.maxStamina,
                        self.x, self.y - 15)
end

--------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------
function Player:getPlayerInput()
    if not self.joystick then
        return {
            heavyAttack = false,
            lightAttack = false,
            jump   = false,
            dash   = false,
            shield = false,
            moveX  = 0,
            down   = false,
            counter= false,
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

--------------------------------------------------------------------------
-- Process Input
--------------------------------------------------------------------------
function Player:processInput(dt, input)
    self.isIdle = true

    -- Shield
    -- If stamina is at 0, we cannot stay shielding.
    if input.shield and self:canPerformAction("shield") and self.stamina > 0 then
        self.canMove     = false
        self.isShielding = true
    else
        self.canMove     = true
        self.isShielding = false
    end

    -- Counter
    if input.counter and self:canPerformAction("counter") then
        self:triggerCounter()
    end
    self.counterPressedLastFrame = input.counter

    -- Attacks
    if input.down and input.attack and self:canPerformAction("downAir") then
        self:triggerDownAir()
    elseif input.heavyAttack and self:canPerformAction("heavyAttack") then
        if not self:useStamina(self.staminaMapping["heavyAttack"]) then
            -- Not enough stamina => skip heavy attack
        else
            self.isAttacking       = true
            self.isHeavyAttacking  = true
            self.heavyAttackTimer  = self.heavyAttackDuration
            self.animations.heavyAttack:gotoFrame(1)
        end
    elseif input.lightAttack and self:canPerformAction("lightAttack") then
        if not self:useStamina(self.staminaMapping["lightAttack"]) then
            -- Not enough stamina => skip light attack
        else
            self.isAttacking       = true
            self.isLightAttacking  = true
            self.lightAttackTimer  = self.lightAttackDuration
            self.animations.lightAttack:gotoFrame(1)
        end
    end
    self.attackPressedLastFrame = input.attack

    if self.isHeavyAttacking then
        self.heavyAttackTimer = self.heavyAttackTimer - dt
        if self.heavyAttackTimer <= 0 then
            self.isAttacking = false
            self.isHeavyAttacking = false
        end
    end

    if self.isLightAttacking then
        self.lightAttackTimer = self.lightAttackTimer - dt
        if self.lightAttackTimer <= 0 then
            self.isAttacking = false
            self.isLightAttacking = false
        end
    end

    -- Movement
    if self:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
        self.isMoving  = true
        self.x         = self.x + (input.moveX * self.speed * 2)
        self.direction = (input.moveX > 0) and 1 or -1
    else
        self.isMoving = false
    end

    -- Jump
    if input.jump and self:canPerformAction("jump") then
        if not self.isJumping then
            self.jumpVelocity   = self.jumpHeight
            self.isJumping      = true
            self.canDoubleJump  = true
            self.canDash        = true
            self.animations.jump:gotoFrame(1)
        elseif self.canDoubleJump then
            self.isDownAir      = false
            self:resetGravity()
            self.jumpVelocity   = self.jumpHeight
            self.canDoubleJump  = false
            self.animations.jump:gotoFrame(1)
        end
    end
    self.JumpPressedLastFrame = input.jump

    if self.isJumping then
        self.y = self.y + (self.jumpVelocity * dt)
        self.jumpVelocity = self.jumpVelocity + (self.gravity * dt)

        if self.y >= self.groundY then
            self.y = self.groundY
            if self.isDownAir then
                self:endDownAir()
            else
                self:land()
            end
        end
    end

    -- Dash
    if input.dash and self:canPerformAction("dash") then
        -- Spend stamina for dash (1)
        if self:useStamina(1) then
            self.isDashing    = true
            self.dashTimer    = self.dashDuration
            self.dashVelocity = self.dashSpeed * self.direction
            self.animations.dash:gotoFrame(1)
        end
    end
    self.dashPressedLastFrame = input.dash

    if self.isDashing then
        self.canDash = false
        self.x       = self.x + self.dashVelocity * dt
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then
            if not self.isJumping then
                self.canDash = true
            end
            self.isDashing    = false
            self.dashVelocity = 0
        end
    end

    -- IDLE check
    if self:canPerformAction("idle") then
        self.isIdle    = true
        self.idleTimer = self.idleTimer + dt
        if self.idleTimer < 1 then
            self.animations.idle:gotoFrame(1)
        end
    else
        self.idleTimer = 0
    end
end

--------------------------------------------------------------------------
-- Attack Handling
--------------------------------------------------------------------------
function Player:handleAttacks(dt, otherPlayer)
    -- If our heavy attack is in the damaging window
    if self.isHeavyAttacking
       and (self.heavyAttackTimer <= self.heavyAttackDuration - self.heavyAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "heavyAttack") then
            otherPlayer:handleAttackEffects(self, dt, 1, "heavyAttack")
        end
    end

    -- If our light attack is in the damaging window
    if self.isLightAttacking
       and (self.lightAttackTimer <= self.lightAttackDuration - self.lightAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "lightAttack") then
            otherPlayer:handleAttackEffects(self, dt, 0.5, "lightAttack")
        end
    end
end

function Player:triggerDownAir()
    if not self:useStamina(self.staminaMapping['downAir']) then
        return
    end

    self.isAttacking  = true
    self.isDownAir    = true
    self.downAirTimer = self.downAirDuration
    self.gravity      = self.gravity * 1.2
    self.animations.downAir:gotoFrame(1)
end

function Player:handleDownAir(dt, otherPlayer)
    if self.isDownAir then
        if self:checkHit(otherPlayer, "downAir") then
            otherPlayer:handleAttackEffects(self, dt, 0.5, "downAir")
        end

        self.downAirTimer = self.downAirTimer - dt
        if self.downAirTimer <= 0 then
            self:endDownAir()
        elseif self.y >= self.groundY then
            self:endDownAir()
        end
    end
end

function Player:endDownAir()
    self.isDownAir   = false
    self.isAttacking = false
    if self.isJumping then
        self:resetGravity()
    else
        self:land()
    end
end

function Player:resetGravity()
    self.gravity = 2250
end

function Player:land()
    self:resetGravity()
    self.isJumping      = false
    self.jumpVelocity   = 0
    self.canDoubleJump  = false
    self.canDash        = true
    self.isDownAir      = false
end

--------------------------------------------------------------------------
-- Counter Logic
--------------------------------------------------------------------------
function Player:triggerCounter()
    self.isCountering  = true
    self.counterTimer  = self.counterDuration
    self.counterActive = true
end

function Player:updateCounter(dt)
    if self.isCountering then
        self.counterTimer = self.counterTimer - dt

        if self.counterTimer <= (self.counterDuration - self.counterActiveWindow) then
            self.counterActive = false
        end

        if self.counterTimer <= 0 then
            self.isCountering  = false
            self.counterTimer  = 0
            self.counterActive = false
        end
    end
end

--------------------------------------------------------------------------
-- Unified Animation Update
--------------------------------------------------------------------------
function Player:updateAnimation(dt)
    if self.isHurt or self.isStunned then
        self.currentAnim = self.animations.hurt
    elseif self.isShielding then
        self.currentAnim = self.animations.shield
    elseif self.isCountering then
        self.currentAnim = self.animations.counter
    elseif self.isHeavyAttacking then
        self.currentAnim = self.animations.heavyAttack
    elseif self.isLightAttacking then
        self.currentAnim = self.animations.lightAttack
    elseif self.isDownAir then
        self.currentAnim = self.animations.downAir
    elseif self.isDashing then
        self.currentAnim = self.animations.dash
    elseif self.isJumping then
        self.currentAnim = self.animations.jump
    elseif self.isMoving then
        self.currentAnim = self.animations.move
    else
        self.currentAnim = self.animations.idle
    end

    self.currentAnim:update(dt)
end

--------------------------------------------------------------------------
-- Action Permissions
--------------------------------------------------------------------------
function Player:canPerformAction(action)
    local conditions = {
        idle = (
            not self.isMoving
            and not self.isJumping
            and not self.isAttacking
            and not self.isDashing
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
        ),

        shield = (
            not self.isJumping
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
        ),

        heavyAttack = (
            not self.isAttacking
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.attackPressedLastFrame
            and self.stamina >= 2
        ),

        lightAttack = (
            not self.isAttacking
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.attackPressedLastFrame
            and self.stamina >= 1
        ),

        dash = (
            not self.isDashing
            and self.canDash
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.dashPressedLastFrame
            and self.stamina >= 1
        ),

        move = (
            self.canMove
            and not self.isDashing
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isAttacking
            and not self.isCountering
        ),

        jump = (
            not self.isAttacking
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.JumpPressedLastFrame
        ),

        downAir = (
            self.isJumping
            and not self.isAttacking
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and self.stamina >= 2
        ),

        counter = (
            not self.isAttacking
            and not self.isJumping
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.counterPressedLastFrame
        ),
    }

    return conditions[action]
end

return Player
