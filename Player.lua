local CharacterBase = require("CharacterBase")
local anim8 = require("libraries.anim8")

local Player = {}
Player.__index = Player

-- Make Player inherit from CharacterBase
setmetatable(Player, { __index = CharacterBase })

function Player:new(x, y, joystickIndex)
    local obj = CharacterBase:new(x, y)
    setmetatable(obj, Player)

    obj.index     = joystickIndex
    obj.joystick = love.joystick.getJoysticks()[joystickIndex]

    obj.attackPressedLastFrame = false
    obj.JumpPressedLastFrame   = false
    obj.dashPressedLastFrame   = false

    obj:initializeAnimations()

    return obj
end

function Player:initializeAnimations()
    self.spriteSheet = love.graphics.newImage("sprites/Hero_update.png")

    self.grid = anim8.newGrid(
        8, 8,
        self.spriteSheet:getWidth(),
        self.spriteSheet:getHeight(),
        0
    )

    self.attackGrid = anim8.newGrid(
        12, 12,
        self.spriteSheet:getWidth(),
        self.spriteSheet:getHeight(),
        8 * 6,  -- offsetX
        0       -- offsetY
    )

    self.animations = {
        move    = anim8.newAnimation(self.grid('3-4', 1), 0.2),
        jump    = anim8.newAnimation(self.grid(3, 2), 1),
        idle    = anim8.newAnimation(self.grid('3-4', 6), 0.7),
        dash    = anim8.newAnimation(self.grid(1, 4), 1),
        attack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.05, 0.2, 0.05, 0.1}),
        downAir = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.2, 0.8}),
        shield  = anim8.newAnimation(self.grid(5, 1), 1),
        hurt    = anim8.newAnimation(self.grid(3, 7), 1)
    }

    self.currentAnim = self.animations.idle
end

---------------------------------------------------------------------
-- Override updateHurtState to set animation to "hurt"
---------------------------------------------------------------------
function Player:updateHurtState(dt)
    -- Call the base class logic for knockback, timers, etc.
    CharacterBase.updateHurtState(self, dt)

    if self.isHurt then
        -- Force the "hurt" animation while the character is hurt
        self.currentAnim = self.animations.hurt
    else
        -- If hurt has ended, revert to idle if nothing else is happening
        if not self.isAttacking and not self.isShielding
           and not self.isDashing and not self.isJumping then
            self.currentAnim = self.animations.idle
        end
    end
end

function Player:update(dt, otherPlayer)
    local input = self:getPlayerInput()

    self:processInput(dt, input)
    self:handleAttacks(dt, otherPlayer)
    self:handleDownAir(dt, otherPlayer)

    -- Update inherited hurt/invincibility logic
    self:updateHurtState(dt)

    -- Update current animation frame
    self.currentAnim:update(dt)

    -- Resolve collision with other player
    self:resolveCollision(otherPlayer)
end

function Player:draw()
    local scaleX = 8 * self.direction
    local offsetX = (self.direction == -1) and (8 * 8) or 0
    local offsetY = 0

    if self.isAttacking then
        offsetX = offsetX + ((self.direction == 1) and 8 or -8)
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
end

---------------------------------------------------------------------
-- Input
---------------------------------------------------------------------
function Player:getPlayerInput()
    if not self.joystick then
        return {
            attack = false,
            jump   = false,
            dash   = false,
            shield = false,
            moveX  = 0,
            down   = false
        }
    end

    return {
        attack = self.joystick:isGamepadDown("x"),
        jump   = self.joystick:isGamepadDown("a"),
        dash   = self.joystick:isGamepadDown("rightshoulder"),
        shield = self.joystick:isGamepadDown("leftshoulder"),
        moveX  = self.joystick:getGamepadAxis("leftx") or 0,
        down   = (self.joystick:getGamepadAxis("lefty") or 0) > 0.5
    }
end

---------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------
function Player:processInput(dt, input)
    self.isIdle = true

    -- Shield
    if input.shield and self:canPerformAction("shield") then
        self.canMove    = false
        self.isShielding= true
        self.currentAnim= self.animations.shield
    else
        self.isShielding= false
        self.canMove    = true
    end

    -- Attacks
    if input.down and input.attack and self:canPerformAction("downAir") then
        self:triggerDownAir()
    elseif input.attack and self:canPerformAction("attack") then
        self.isAttacking = true
        self.attackTimer = self.attackDuration
        self.currentAnim = self.animations.attack
        self.currentAnim:gotoFrame(1)
    end

    self.attackPressedLastFrame = input.attack

    if self.isAttacking then
        self.attackTimer = self.attackTimer - dt
        if self.attackTimer <= 0 then
            self.isAttacking = false
            self.currentAnim = self.animations.idle
        end
    end

    -- Movement
    if self:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
        self.isMoving   = true
        self.x          = self.x + input.moveX * self.speed * 2
        self.direction  = (input.moveX > 0) and 1 or -1

        if not self.isAttacking then
            self.currentAnim = self.animations.move
        end
    else
        self.isMoving = false
    end

    -- Jump
    if input.jump and self:canPerformAction("jump") then
        if not self.isJumping then
            -- Single jump
            self.jumpVelocity   = self.jumpHeight
            self.isJumping      = true
            self.canDoubleJump  = true
            self.canDash        = true
            self.currentAnim    = self.animations.jump
        elseif self.canDoubleJump then
            -- Double jump
            self.isDownAir      = false
            self:resetGravity()
            self.jumpVelocity   = self.jumpHeight
            self.canDoubleJump  = false
            self.currentAnim    = self.animations.jump
        end
    end
    self.JumpPressedLastFrame = input.jump

    if self.isJumping then
        self.y = self.y + self.jumpVelocity * dt
        self.jumpVelocity = self.jumpVelocity + self.gravity * dt

        if self.y >= self.groundY then
            self.y = self.groundY
            self:land()
        end

        if not self.isDashing and not self.isAttacking and not self.isDownAir then
            self.currentAnim = self.animations.jump
        end
    end

    -- Dash
    if input.dash and self:canPerformAction("dash") then
        self.isDashing    = true
        self.dashTimer    = self.dashDuration
        self.dashVelocity = self.dashSpeed * self.direction
        self.currentAnim  = self.animations.dash
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

    -- IDLE
    if self:canPerformAction("idle") then
        self.isIdle    = true
        self.idleTimer = self.idleTimer + dt
        self.currentAnim = self.animations.idle
        if self.idleTimer < 1 then
            self.currentAnim:gotoFrame(1)
        end
    else
        self.idleTimer = 0
    end

end

function Player:handleAttacks(dt, otherPlayer)
    -- If in the damaging portion of the attack
    if self.isAttacking and (self.attackTimer <= self.attackNoDamageDuration) then
        if self:checkHit(otherPlayer, "sideAttack") then
            otherPlayer:handleAttackEffects(self, dt, 1)
        end
    end
end

function Player:triggerDownAir()
    self.isAttacking = true
    self.isDownAir   = true
    self.downAirTimer= self.downAirDuration
    self.gravity     = self.gravity * 1.2  -- speed up descent
    self.currentAnim = self.animations.downAir
    self.currentAnim:gotoFrame(1)
end

function Player:handleDownAir(dt, otherPlayer)
    if self.isDownAir then
        self.currentAnim = self.animations.downAir

        if self:checkHit(otherPlayer, "downAir") then
            -- Apply half knockback
            otherPlayer:handleAttackEffects(self, dt, 0.5)
        end

        self.downAirTimer = self.downAirTimer - dt
        if self.downAirTimer <= 0 then
            self:endDownAir()
        elseif self.y >= self.groundY then
            self:land()
        end
    end
end

function Player:endDownAir()
    self.isDownAir   = false
    self.isAttacking = false
    self.currentAnim = self.animations.jump
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

    if not self.isAttacking then
        self.currentAnim = self.animations.idle
    end
end

---------------------------------------------------------------------
-- Enhanced canPerformAction
-- Add "not self.isAttacking" to move
---------------------------------------------------------------------
function Player:canPerformAction(action)
    local conditions = {
        idle = ( not self.isMoving
                 and not self.isJumping
                 and not self.isAttacking
                 and not self.isDashing
                 and not self.isShielding
                 and not self.isHurt ),

        shield = ( not self.isJumping
                   and not self.isHurt ),

        attack = ( not self.isAttacking
                   and not self.isShielding
                   and not self.isHurt
                   and not self.attackPressedLastFrame ),

        dash = ( not self.isDashing
                 and self.canDash
                 and not self.isShielding
                 and not self.isHurt
                 and not self.dashPressedLastFrame ),

        -- Disallow move if currently attacking:
        move = ( self.canMove
                 and not self.isDashing
                 and not self.isShielding
                 and not self.isHurt
                 and (
                    -- If on the ground and attacking, disallow movement
                    not self.isAttacking or self.isJumping
                )),

        jump = ( not self.isAttacking
                 and not self.isShielding
                 and not self.isHurt
                 and not self.JumpPressedLastFrame ),

        downAir = ( self.isJumping
                    and not self.isAttacking
                    and not self.isShielding
                    and not self.isHurt )
    }

    return conditions[action]
end

return Player
