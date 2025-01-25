-- Player.lua
-- Player-specific class that inherits from CharacterBase.
-- Handles:
--   - Controller input
--   - Movement & jumping logic
--   - Dashing, shielding
--   - Attack triggers
--   - Animations

local CharacterBase = require("CharacterBase")
local anim8 = require("libraries.anim8")

local Player = {}
Player.__index = Player
setmetatable(Player, { __index = CharacterBase })  -- Inherit from CharacterBase

---------------------------------------------------------------------
-- Constructor / Initialization
---------------------------------------------------------------------
function Player:new(x, y, joystickIndex)
    -- Create a base-class instance
    local obj = CharacterBase:new(x, y)

    -- Set Player as its metatable
    setmetatable(obj, Player)

    -- Add/override any Player-specific fields
    obj.index = joystickIndex
    obj.joystick = love.joystick.getJoysticks()[joystickIndex]

    -- We might keep some of your existing fields here:
    obj.attackPressedLastFrame = false
    obj.JumpPressedLastFrame   = false
    obj.dashPressedLastFrame   = false

    -- Initialize animations
    obj:initializeAnimations()

    return obj
end

function Player:initializeAnimations()
    self.spriteSheet = love.graphics.newImage("sprites/Hero_update.png")

    -- Note: The original uses multiple grids. We'll replicate that logic:
    self.grid = anim8.newGrid(8, 8, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 0)
    -- Attack grid starts offset? The original code had "8 * 6" offset, but we’ll replicate carefully:
    -- self.attackGrid = anim8.newGrid(12, 12, w, h, offsetX, offsetY) 
    self.attackGrid = anim8.newGrid(12, 12,
                                    self.spriteSheet:getWidth(),
                                    self.spriteSheet:getHeight(),
                                    8*6,  -- offset X in pixels
                                    0)    -- offset Y

    -- Build out the animations table
    self.animations = {
        move    = anim8.newAnimation(self.grid('3-4', 1), 0.2),
        jump    = anim8.newAnimation(self.grid(3, 2), 1),
        idle    = anim8.newAnimation(self.grid('3-4', 6), 0.7),
        dash    = anim8.newAnimation(self.grid(1, 4), 1),
        attack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.05, 0.2, 0.05, 0.1}),
        downAir = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.2, 0.8}),
        shield  = anim8.newAnimation(self.grid(5, 1), 1),
        hurt    = anim8.newAnimation(self.grid(3, 7), 1),
    }

    -- We’ll store our current animation in self.currentAnim
    self.currentAnim = self.animations.idle
end

---------------------------------------------------------------------
-- Main Update
---------------------------------------------------------------------
function Player:update(dt, otherPlayer)
    -- 1) Gather controller input
    local input = self:getPlayerInput()

    -- 2) Process that input (movement, attacks, jumps, etc.)
    self:processInput(dt, input)

    -- 3) Handle collisions & attacks
    self:handleAttacks(dt, otherPlayer)
    self:handleDownAir(dt, otherPlayer)

    -- 4) Update hurt (knockback, invincibility) from base class
    self:updateHurtState(dt)

    -- 5) Update the animation
    self.currentAnim:update(dt)

    -- 6) Resolve collision with the other player (if 2-player scenario)
    self:resolveCollision(otherPlayer)
end

---------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------
function Player:draw()
    -- Scale horizontally based on direction. Also handle offset so sprite
    -- flips around origin.
    local scaleX = 8 * self.direction
    local offsetX = (self.direction == -1) and (8 * 8) or 0
    local offsetY = 0

    -- If attacking, shift slightly and move sprite up a bit
    if self.isAttacking then
        offsetX = offsetX + ((self.direction == 1) and 8 or -8)
        offsetY = -4 * 8
    end

    self.currentAnim:draw(self.spriteSheet, self.x + offsetX, self.y + offsetY, 0, scaleX, 8)
end

---------------------------------------------------------------------
-- Controller Input
---------------------------------------------------------------------
function Player:getPlayerInput()
    if not self.joystick then
        -- No controller? Return default no-input
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
-- Input Processing
---------------------------------------------------------------------
function Player:processInput(dt, input)
    -- Reset some flags each frame
    self.isIdle = true

    -- Handle shielding
    if input.shield and self:canPerformAction("shield") then
        self.canMove = false
        self.isShielding = true
        self.currentAnim = self.animations.shield
    else
        self.isShielding = false
        self.canMove = true
    end

    -- Handle attacks
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

    -- Horizontal Movement
    if self:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
        self.isMoving = true
        self.x = self.x + input.moveX * self.speed * 2
        self.direction = (input.moveX > 0) and 1 or -1

        if not self.isAttacking then
            self.currentAnim = self.animations.move
        end
    else
        self.isMoving = false
    end

    -- Jumping
    if input.jump and self:canPerformAction("jump") then
        if not self.isJumping then
            -- Single jump
            self.jumpVelocity = self.jumpHeight
            self.isJumping = true
            self.canDoubleJump = true
            self.canDash = true
            self.currentAnim = self.animations.jump
        elseif self.canDoubleJump then
            -- Double jump
            self.isDownAir = false
            self:resetGravity()
            self.jumpVelocity = self.jumpHeight
            self.canDoubleJump = false
            self.currentAnim = self.animations.jump
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

        if (not self.isDashing) and (not self.isAttacking) and (not self.isDownAir) then
            self.currentAnim = self.animations.jump
        end
    end

    -- Dashing
    if input.dash and self:canPerformAction("dash") then
        self.isDashing = true
        self.dashTimer = self.dashDuration
        self.dashVelocity = self.dashSpeed * self.direction
        self.currentAnim = self.animations.dash
    end
    self.dashPressedLastFrame = input.dash

    if self.isDashing then
        self.canDash = false
        self.x = self.x + self.dashVelocity * dt
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then
            if not self.isJumping then
                self.canDash = true
            end
            self.isDashing = false
            self.dashVelocity = 0
        end
    end

    -- IDLE check
    if self:canPerformAction("idle") then
        self.isIdle = true
        self.idleTimer = self.idleTimer + dt
        self.currentAnim = self.animations.idle
        if self.idleTimer < 1 then
            self.currentAnim:gotoFrame(1)
        end
    else
        self.idleTimer = 0
    end
end

---------------------------------------------------------------------
-- Attack Handling
---------------------------------------------------------------------
function Player:handleAttacks(dt, otherPlayer)
    -- If we are in the part of the attack that can deal damage
    if self.isAttacking and (self.attackTimer <= self.attackNoDamageDuration) then
        if self:checkHit(otherPlayer, "sideAttack") then
            otherPlayer:handleAttackEffects(self, dt, 1)
        end
    end
end

function Player:triggerDownAir()
    self.isAttacking = true
    self.isDownAir = true
    self.downAirTimer = self.downAirDuration
    self.gravity = self.gravity * 1.2  -- speed up descent
    self.currentAnim = self.animations.downAir
    self.currentAnim:gotoFrame(1)
end

function Player:handleDownAir(dt, otherPlayer)
    if self.isDownAir then
        self.currentAnim = self.animations.downAir

        if self:checkHit(otherPlayer, "downAir") then
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
    self.isDownAir = false
    self.isAttacking = false
    self.currentAnim = self.animations.jump
    if self.isJumping then
        self:resetGravity()
    else
        self:land()
    end
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function Player:resetGravity()
    self.gravity = 2250
end

function Player:land()
    self:resetGravity()
    self.isJumping = false
    self.jumpVelocity = 0
    self.canDoubleJump = false
    self.canDash = true
    self.isDownAir = false

    if not self.isAttacking then
        self.currentAnim = self.animations.idle
    end
end

---------------------------------------------------------------------
-- Action Permissions
---------------------------------------------------------------------
function Player:canPerformAction(action)
    local conditions = {
        idle   = ( not self.isMoving
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
        dash   = ( not self.isDashing
                   and self.canDash
                   and not self.isShielding
                   and not self.isHurt
                   and not self.dashPressedLastFrame ),
        move   = ( self.canMove
                   and not self.isDashing
                   and not self.isShielding
                   and not self.isHurt ),
        jump   = ( not self.isAttacking
                   and not self.isShielding
                   and not self.isHurt
                   and not self.JumpPressedLastFrame ),
        downAir = ( self.isJumping
                    and not self.isAttacking
                    and not self.isShielding
                    and not self.isHurt ),
    }

    return conditions[action]
end

return Player
