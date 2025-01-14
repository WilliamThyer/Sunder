-- Define the Player class
local Player = {}
Player.__index = Player

-- Constructor
function Player.createPlayer(x, y, joystickIndex)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.groundY = y
    self.width = 64 -- Scaled width of the sprite (8 * 8)
    self.height = 64 -- Scaled height of the sprite
    self.speed = 3
    if joystickIndex == 1 then
        self.direction = 1 -- 1 = right, -1 = left
    else
        self.direction = -1 -- 1 = right, -1 = left
    end
    self.canMove = true

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage('sprites/Chroma-Noir-8x8/Hero_w_shield.png')
    -- Player grid
    self.grid = anim8.newGrid(8, 8,
      self.spriteSheet:getWidth(),
      self.spriteSheet:getHeight(),
      0
    )
    -- Attack grid, to account for extra width of sword sprite
    self.attackGrid = anim8.newGrid(10, 8,
      self.spriteSheet:getWidth(),
      self.spriteSheet:getHeight(),
      8*9, 8*2
    )

    -- Animations
    self.animations = {}
    self.animations.move   = anim8.newAnimation(self.grid('10-11', 1), 0.2)
    self.animations.jump   = anim8.newAnimation(self.grid(10, 2), 1)
    self.animations.idle   = anim8.newAnimation(self.grid('11-10', 6), .7)
    self.animations.dash = anim8.newAnimation(self.grid(1, 4), 1)
    self.animations.attack = anim8.newAnimation(self.attackGrid(1, 1), 1)
    self.animations.shield = anim8.newAnimation(self.grid(11, 2), 1)
    self.animations.hurt = anim8.newAnimation(self.grid(10, 7), 1)

    -- Set default animation
    self.anim = self.animations.idle
    self.isIdle = true
    self.isMoving = false
    self.idleTimer = 0

    -- Jump physics
    self.jumpHeight    = -750
    self.gravity       = 2250
    self.jumpVelocity  = 0
    self.isJumping     = false
    self.canDoubleJump = false
    self.wasJumpPressedLastFrame = false

    -- Attack logic
    self.isAttacking   = false
    self.attackTimer   = 0     -- counts down when attacking
    self.attackDuration = 0.15  -- how long the attack lasts in seconds
    self.attackPressedLastFrame = false -- Prevent holding attack

    -- Dash logic
    self.isDashing = false
    self.dashTimer = 0
    self.dashDuration = 0.06
    self.canDash = true
    self.dashSpeed = self.speed * 750
    self.dashPressedLastFrame = false -- Prevent holding dash

    -- Shield logic
    self.isShielding = false

    -- Hurt logic
    self.isHurt = false
    self.hurtTimer = 0
    self.knockbackSpeed = 150 * self.speed
    self.knockbackDirection = 1
    self.isInvincible = false
    self.invincibleTimer = 0

    -- Assign joystick
    self.index = joystickIndex
    self.joystick = love.joystick.getJoysticks()[joystickIndex]

    return self
end

function Player:isAbleToShield()
    return not self.isJumping and not self.isHurt
end

function Player:isAbleToAttack()
    return not self.attackPressedLastFrame and not self.isAttacking and not self.isShielding and not self.isHurt
end

function Player:isAbleToDash()
    return not self.dashPressedLastFrame and not self.isDashing and self.canDash and not self.isShielding and not self.isHurt
end

function Player:isAbleToMove()
    return self.canMove and not self.isDashing and not self.isShielding and not self.isHurt or self.isJumping
end

function Player:isAbleToJump()
    return not self.wasJumpPressedLastFrame and not self.isAttacking and not self.isShielding and not self.isHurt
end

function Player:isAbleToIdle()
    return self.isIdle and not self.isJumping and not self.isAttacking and not self.isDashing and not self.isShielding and not self.isHurt
end

return Player
