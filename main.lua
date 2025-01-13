if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")
_G.love = require("love")
anim8 = require 'libraries/anim8'

print('starting game')

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  function createPlayer(x, y, joystickIndex)
    local player = {}
    player.x = x
    player.y = y
    player.groundY = y
    player.speed = 3
    player.direction = 1 -- 1 = right, -1 = left
    player.canMove = true

    -- Load sprite sheet
    player.spriteSheet = love.graphics.newImage('sprites/Chroma-Noir-8x8/Hero_w_shield.png')
    -- Player grid
    player.grid = anim8.newGrid(8, 8,
      player.spriteSheet:getWidth(),
      player.spriteSheet:getHeight(),
      0
    )
    -- Attack grid, to account for extra width of sword sprite
    player.attackGrid = anim8.newGrid(10, 8,
      player.spriteSheet:getWidth(),
      player.spriteSheet:getHeight(),
      8*9, 8*2
    )

    -- Animations
    player.animations = {}
    player.animations.move   = anim8.newAnimation(player.grid('10-11', 1), 0.2)
    player.animations.jump   = anim8.newAnimation(player.grid(10, 2), 1)
    player.animations.idle   = anim8.newAnimation(player.grid('11-10', 6), .7)
    player.animations.dash = anim8.newAnimation(player.grid(1, 4), 1)
    player.animations.attack = anim8.newAnimation(player.attackGrid(1, 1), 1)
    player.animations.shield = anim8.newAnimation(player.grid(11, 2), 1)

    -- Set default animation
    player.anim = player.animations.idle
    player.isIdle = true
    player.isMoving = false
    player.idleTimer = 0

    -- Jump physics
    player.jumpHeight    = -750
    player.gravity       = 2250
    player.jumpVelocity  = 0
    player.isJumping     = false
    player.canDoubleJump = false
    player.wasJumpPressedLastFrame = false

    -- Attack logic
    player.isAttacking   = false
    player.attackTimer   = 0     -- counts down when attacking
    player.attackDuration = 0.15  -- how long the attack lasts in seconds
    player.attackPressedLastFrame = false -- Prevent holding attack

    -- Dash logic
    player.isDashing = false
    player.dashTimer = 0
    player.dashDuration = 0.06
    player.canDash = true
    player.dashSpeed = player.speed * 750
    player.dashPressedLastFrame = false -- Prevent holding dash

    -- Shield logic
    player.isShielding = false

    -- Assign joystick
    player.joystick = love.joystick.getJoysticks()[joystickIndex]

    return player
  end

  -- Create two players
  player1 = createPlayer(400, 700, 1)
  player2 = createPlayer(600, 700, 2)
end

function updatePlayer(dt, player, controls)
  player.isIdle = true
  local attackIsPressed = false
  local jumpIsDown = false
  local dashIsPressed = false
  local shieldIsPressed = false
  local moveX = 0

  if player.joystick then
    -- Read controller inputs
    attackIsPressed = player.joystick:isGamepadDown("x")
    jumpIsDown = player.joystick:isGamepadDown("a")
    dashIsPressed = player.joystick:isGamepadDown("rightshoulder")
    shieldIsPressed = player.joystick:isGamepadDown("leftshoulder")
    moveX = player.joystick:getGamepadAxis("leftx")
  end

  -- Handle shield
  if shieldIsPressed and not player.isJumping then
    player.canMove = false
    player.isShielding = true
    player.anim = player.animations.shield
  else
    player.isShielding = false
    player.canMove = true
  end

  -- Handle attack
  if attackIsPressed and not player.attackPressedLastFrame and not player.isAttacking and not player.isShielding then
    player.canMove = false
    player.isAttacking = true
    player.attackTimer = player.attackDuration
    player.anim = player.animations.attack
  end
  player.attackPressedLastFrame = attackIsPressed

  if player.isAttacking then
    player.attackTimer = player.attackTimer - dt
    if player.attackTimer <= 0 then
      player.isAttacking = false
      player.canMove = true
    end
  end

  -- Handle dashing
  if dashIsPressed and not player.dashPressedLastFrame and not player.isDashing and player.canDash and not player.isShielding then
    player.isDashing = true
    player.canDash = false -- Disable further dashes until reset
    player.dashTimer = player.dashDuration
    player.dashVelocity = player.dashSpeed * player.direction
    player.anim = player.animations.dash
  end
  player.dashPressedLastFrame = dashIsPressed

  if player.isDashing then
    player.x = player.x + player.dashVelocity * dt
    player.dashTimer = player.dashTimer - dt
    if player.dashTimer <= 0 then
      if not player.isJumping then
        player.canDash = true
      end
      player.isDashing = false
      player.dashVelocity = 0
    end
  end

  -- Handle movement
  if player.canMove and not player.isDashing and not player.isShielding or player.isJumping then
    if math.abs(moveX) > 0.5 then -- Dead zone for analog stick
      player.x = player.x + moveX * player.speed * 2 -- Multiply for analog sensitivity
      player.direction = moveX > 0 and 1 or -1
      player.isIdle = false
      player.isMoving = true
      if not player.isJumping and not player.isAttacking then
        player.anim = player.animations.move
      end
    end
  end

  -- Handle jump
  if jumpIsDown and not player.wasJumpPressedLastFrame and not player.isAttacking and not player.isShielding then
    if not player.isJumping then
      player.jumpVelocity = player.jumpHeight
      player.isJumping = true
      player.canDoubleJump = true
      player.canDash = true -- Reset dash ability
      player.anim = player.animations.jump
    elseif player.canDoubleJump then
      player.jumpVelocity = player.jumpHeight
      player.canDoubleJump = false
      player.anim = player.animations.jump
    end
  end

  if player.isJumping then
    player.y = player.y + player.jumpVelocity * dt
    player.jumpVelocity = player.jumpVelocity + player.gravity * dt

    if player.y >= player.groundY then
      player.y = player.groundY
      player.isJumping = false
      player.jumpVelocity = 0
      player.canDoubleJump = false
      player.canDash = true -- Reset dash when landing
      if not player.isAttacking then
        player.anim = player.animations.idle
      end
    end
    if not player.isDashing and not player.isAttacking then
      player.anim = player.animations.jump
    end
  end

  -- Handle idle stance
  if player.isIdle and not player.isJumping and not player.isAttacking and not player.isDashing and not player.isShielding then
    -- Accumulate time in idle state
    player.idleTimer = player.idleTimer + dt
    player.anim = player.animations.idle
    if player.idleTimer < 1 then
      player.anim:gotoFrame(2)
    end
  else
    -- Reset when not idle or jumping/attacking
    player.idleTimer = 0
  end

  -- Update animation
  player.anim:update(dt)
  player.wasJumpPressedLastFrame = jumpIsDown
end

function love.update(dt)
  updatePlayer(dt, player1)
  updatePlayer(dt, player2)
end

function love.draw()
  local function drawPlayer(player)
    local scaleX = 8 * player.direction -- Flip horizontally if direction is -1
    local offsetX = (player.direction == -1) and (8 * 8) or 0 -- Shift sprite when flipped
    player.anim:draw(player.spriteSheet, player.x + offsetX, player.y, 0, scaleX, 8)
  end

  drawPlayer(player1)
  drawPlayer(player2)
end
