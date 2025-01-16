-- Define the Player class
local Player = {}
Player.__index = Player

-- Constructor
function Player.createPlayer(x, y, joystickIndex)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.groundY = y
    self.width = 64
    self.height = 64
    self.speed = 3
    self.direction = joystickIndex == 1 and 1 or -1
    self.canMove = true

    self:initializeSprites()
    self:initializeState(joystickIndex)

    return self
end

-- Initialize sprites and animations
function Player:initializeSprites()
    self.spriteSheet = love.graphics.newImage('sprites/Hero_update.png')
    self.grid = anim8.newGrid(8, 8, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 0)
    self.attackGrid = anim8.newGrid(12, 12, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 8 * 6, 0)

    self.animations = {
        move = anim8.newAnimation(self.grid('3-4', 1), 0.2),
        jump = anim8.newAnimation(self.grid(3, 2), 1),
        idle = anim8.newAnimation(self.grid('3-4', 6), 0.7),
        dash = anim8.newAnimation(self.grid(1, 4), 1),
        attack = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.05, 0.2, 0.05, 0.1}),
        downAir = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.2, 0.8}),
        shield = anim8.newAnimation(self.grid(5, 1), 1),
        hurt = anim8.newAnimation(self.grid(3, 7), 1)
    }

    self.anim = self.animations.idle
end

-- Initialize player state
function Player:initializeState(joystickIndex)
    self.isIdle = true
    self.isMoving = false
    self.idleTimer = 0

    -- Physics and movement
    self.jumpHeight = -850
    self.jumpVelocity = 0
    self.isJumping = false
    self.canDoubleJump = false
    self.gravity = 2250
    self.wasJumpPressedLastFrame = false

    -- Attack state
    self.isAttacking = false
    self.attackTimer = 0
    self.attackDuration = 0.5
    self.attackNoDamageDuration = 0.25
    self.attackPressedLastFrame = false

    -- Downair
    self.isDownAir = false
    self.downAirDuration = 1
    self.downAirTimer = 0

    -- Dash state
    self.isDashing = false
    self.dashTimer = 0
    self.dashDuration = 0.06
    self.canDash = true
    self.dashSpeed = self.speed * 750
    self.dashPressedLastFrame = false

    -- Shield state
    self.isShielding = false

    -- Hurt state
    self.isHurt = false
    self.hurtTimer = 0
    self.knockbackSpeed = self.speed * 150

    -- Joystick
    self.index = joystickIndex
    self.joystick = love.joystick.getJoysticks()[joystickIndex]
end

function Player:triggerDownAir()
    self.isAttacking = true
    self.isDownAir = true
    self.downAirTimer = self.downAirDuration
    self.gravity = self.gravity * 1.2 -- speed up descent
    self.anim = self.animations.downAir
    self.anim:gotoFrame(1)
end

function Player:endDownAir()
    self.isDownAir = false
    self.isAttacking = false
    self.anim = self.animations.jump
    if self.isJumping then
        self:resetGravity()
    else
        self:land()
    end
end


-- Reset gravity to default
function Player:resetGravity()
    self.gravity = 2250
end

-- Land player on the ground
function Player:land()
    self:resetGravity()
    self.isJumping = false
    self.jumpVelocity = 0
    self.canDoubleJump = false
    self.canDash = true
    self.isDownAir = false
    if not self.isAttacking then
        self.anim = self.animations.idle
    end
end

-- Check if the player can perform certain actions
function Player:canPerformAction(action)
    local conditions = {
        idle = self.isIdle and not self.isMoving and not self.isJumping and not self.isAttacking and not self.isDashing and not self.isShielding and not self.isHurt,
        shield = not self.isJumping and not self.isHurt,
        attack = not self.isAttacking and not self.isShielding and not self.isHurt and not self.attackPressedLastFrame,
        dash = not self.isDashing and self.canDash and not self.isShielding and not self.isHurt and not self.dashPressedLastFrame,
        move = self.canMove and not self.isDashing and not self.isShielding and not self.isHurt,
        jump = not self.isAttacking and not self.isShielding and not self.isHurt and not self.JumpPressedLastFrame,
        downAir = self.isJumping and not self.isAttacking and not self.isShielding and not self.isHurt
    }
    return conditions[action]
end

return Player
