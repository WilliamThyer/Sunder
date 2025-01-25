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
        attack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.05, 0.2, 0.05, 0.1}),
        downAir = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.2, 0.8}),
        shield  = anim8.newAnimation(self.grid(5, 1), 1),
        hurt    = anim8.newAnimation(self.grid(3, 7), 1)
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
    self:updateAnimation(dt)
end

function Player:draw()
    local scaleX = 8 * self.direction
    local offsetX = (self.direction == -1) and (8 * 8) or 0
    local offsetY = 0

    -- You can keep this "offset if attacking" logic if you want
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

--------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------
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

--------------------------------------------------------------------------
-- Process Input
--------------------------------------------------------------------------
function Player:processInput(dt, input)
    -- This sets the state flags; we won't set animations directly here
    self.isIdle = true

    -- Shield
    if input.shield and self:canPerformAction("shield") then
        self.canMove     = false
        self.isShielding = true
    else
        self.isShielding = false
        self.canMove     = true
    end

    -- Attacks
    if input.down and input.attack and self:canPerformAction("downAir") then
        self:triggerDownAir()
    elseif input.attack and self:canPerformAction("attack") then
        self.isAttacking = true
        self.attackTimer = self.attackDuration

        -- We do want the attack animation to start on frame 1
        self.animations.attack:gotoFrame(1)
    end
    self.attackPressedLastFrame = input.attack

    if self.isAttacking then
        self.attackTimer = self.attackTimer - dt
        if self.attackTimer <= 0 then
            self.isAttacking = false
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
            self.animations.jump:gotoFrame(1) -- Start jump anim from frame 1
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
            self:land()
        end
    end

    -- Dash
    if input.dash and self:canPerformAction("dash") then
        self.isDashing    = true
        self.dashTimer    = self.dashDuration
        self.dashVelocity = self.dashSpeed * self.direction
        self.animations.dash:gotoFrame(1)  -- Start dash anim from frame 1
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
    self.gravity     = self.gravity * 1.2

    -- Start downAir anim on frame 1
    self.animations.downAir:gotoFrame(1)
end

function Player:handleDownAir(dt, otherPlayer)
    if self.isDownAir then
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
-- Unified Animation Update
--------------------------------------------------------------------------
function Player:updateAnimation(dt)
    -------------------------------------------------------------------
    --  Animation Priority:
    --    1) isHurt        => self.animations.hurt
    --    2) isShielding   => self.animations.shield
    --    3) isAttacking   => if isDownAir => downAir, else => attack
    --    4) isDashing     => dash
    --    5) isJumping     => jump
    --    6) isMoving      => move
    --    7) otherwise     => idle
    -------------------------------------------------------------------
    if self.isHurt then
        self.currentAnim = self.animations.hurt
    elseif self.isShielding then
        self.currentAnim = self.animations.shield
    elseif self.isAttacking then
        if self.isDownAir then
            self.currentAnim = self.animations.downAir
        else
            self.currentAnim = self.animations.attack
        end
    elseif self.isDashing then
        self.currentAnim = self.animations.dash
    elseif self.isJumping then
        self.currentAnim = self.animations.jump
    elseif self.isMoving then
        self.currentAnim = self.animations.move
    else
        self.currentAnim = self.animations.idle
    end

    -- Finally, update the currently selected animation
    self.currentAnim:update(dt)
end

--------------------------------------------------------------------------
-- Action Permissions
--------------------------------------------------------------------------
function Player:canPerformAction(action)
    local conditions = {
        idle = (not self.isMoving
                and not self.isJumping
                and not self.isAttacking
                and not self.isDashing
                and not self.isShielding
                and not self.isHurt),

        shield = (not self.isJumping
                  and not self.isHurt),

        attack = (not self.isAttacking
                  and not self.isShielding
                  and not self.isHurt
                  and not self.attackPressedLastFrame),

        dash = (not self.isDashing
                and self.canDash
                and not self.isShielding
                and not self.isHurt
                and not self.dashPressedLastFrame),

        move = (self.canMove
                and not self.isDashing
                and not self.isShielding
                and not self.isHurt
                and not self.isAttacking),

        jump = (not self.isAttacking
                and not self.isShielding
                and not self.isHurt
                and not self.JumpPressedLastFrame),

        downAir = (self.isJumping
                   and not self.isAttacking
                   and not self.isShielding
                   and not self.isHurt)
    }
    return conditions[action]
end

return Player
