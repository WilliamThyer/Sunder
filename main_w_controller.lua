if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")
_G.love = require("love")
anim8 = require 'libraries/anim8'

print('starting game')

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  player = {}
  player.x = 400
  player.y = 400
  player.groundY = 400
  player.speed = 3
  player.direction = 1 -- 1 = right, -1 = left
  player.canMove = true

  -- Load sprite sheet
  player.spriteSheet = love.graphics.newImage('sprites/Chroma-Noir-8x8/Hero.png')
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
  player.animations.attack = anim8.newAnimation(player.attackGrid(1, 1), 1)

  -- Set default animation
  player.anim = player.animations.idle
  player.isIdle = true
  player.isMoving = false
  player.idleTimer = 0

  -- Jump physics
  player.jumpHeight    = -550
  player.gravity       = 1500
  player.jumpVelocity  = 0
  player.isJumping     = false
  player.canDoubleJump = false
  player.wasJumpPressedLastFrame = false

  -- Attack logic
  player.isAttacking   = false
  player.attackTimer   = 0     -- counts down when attacking
  player.attackDuration = 0.3  -- how long the attack lasts in seconds
  player.attackPressedLastFrame = false -- Prevent holding attack

  -- Controller
  joystick = love.joystick.getJoysticks()[1] -- Get the first connected joystick
end

function love.update(dt)
  local attackIsPressed = false
  local jumpIsDown = false
  local moveX = 0

  if joystick then
    -- Read controller inputs
    attackIsPressed = joystick:isGamepadDown("x") -- Map "X" button for attack
    jumpIsDown = joystick:isGamepadDown("a") -- Map "A" button for jump
    moveX = joystick:getGamepadAxis("leftx") -- Map left stick horizontal movement
  end

  -- Handle attack
  if attackIsPressed and not player.attackPressedLastFrame and not player.isAttacking then
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

  -- Handle movement
  if math.abs(moveX) > 0.2 then -- Dead zone for analog stick
    if player.canMove or player.isJumping then
      player.x = player.x + moveX * player.speed * 2 -- Multiply for analog sensitivity
      player.direction = moveX > 0 and 1 or -1
      player.isIdle = false
      player.isMoving = true
      if not player.isJumping and not player.isAttacking then
        player.anim = player.animations.move
      end
    else
      player.isMoving = false
      player.anim = player.anim
    end
  end

  -- Handle jump
  if jumpIsDown and not player.wasJumpPressedLastFrame and not player.isAttacking then
    if not player.isJumping then
      player.jumpVelocity = player.jumpHeight
      player.isJumping = true
      player.canDoubleJump = true
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
      if not player.isAttacking then
        player.anim = player.animations.idle
      end
    end
  end

  -- Handle idle stance 
  if player.isIdle and not player.isJumping and not player.isAttacking and not player.isMoving then
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

function love.draw()
  local scaleX = 8 * player.direction -- Flip horizontally if direction is -1
  local offsetX = (player.direction == -1) and (8 * 8) or 0 -- Shift sprite when flipped
  player.anim:draw(player.spriteSheet, player.x + offsetX, player.y, 0, scaleX, 8)
end
