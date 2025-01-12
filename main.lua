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
  player.attackDuration = 0.2  -- how long the attack lasts in seconds
  player.attackPressedLastFrame = false -- Prevent holding attack
end

function love.update(dt)
  -- Reset idle to true each frame (we’ll switch it off if we move, jump, or attack)
  player.isIdle = true

  ----------------------------------------------------------------------
  -- 1) Handle Attack (pressing "x")
  ----------------------------------------------------------------------
  local attackIsPressed = love.keyboard.isDown("x")
  if attackIsPressed and not player.attackPressedLastFrame and not player.isAttacking then
    -- Start attack if not already attacking
    player.isAttacking = true
    player.attackTimer = player.attackDuration  -- reset timer
    player.anim        = player.animations.attack
    -- Optionally, you could limit movement or jumping here if desired
  end
  player.attackPressedLastFrame = attackIsPressed

  -- If currently attacking, count down
  if player.isAttacking then
    player.attackTimer = player.attackTimer - dt
    if player.attackTimer <= 0 then
      -- Attack time finished
      player.isAttacking = false
    end
  end

  ----------------------------------------------------------------------
  -- 2) Movement (only when not attacking, or allow movement anyway)
  ----------------------------------------------------------------------
  local canMove = true  -- Set false if you want to lock the player during attack
  if canMove then
    if love.keyboard.isDown("right") then
      player.x = player.x + player.speed
      player.direction = 1
      player.isIdle = false
      -- Only set to "move" if we're not jumping or attacking
      if (not player.isJumping) and (not player.isAttacking) then
        player.anim = player.animations.move
      end
    elseif love.keyboard.isDown("left") then
      player.x = player.x - player.speed
      player.direction = -1
      player.isIdle = false
      if (not player.isJumping) and (not player.isAttacking) then
        player.anim = player.animations.move
      end
    end
  end

  ----------------------------------------------------------------------
  -- 3) Jump Logic (pressed detection)
  ----------------------------------------------------------------------
  local jumpIsDown = love.keyboard.isDown("up")

  if jumpIsDown and not player.wasJumpPressedLastFrame then
    if not player.isJumping then
      player.jumpVelocity   = player.jumpHeight
      player.isJumping      = true
      player.canDoubleJump  = true
      player.anim           = player.animations.jump
      player.isIdle         = false
    elseif player.canDoubleJump then
      player.jumpVelocity   = player.jumpHeight
      player.canDoubleJump  = false
      player.anim           = player.animations.jump
      player.isIdle         = false
    end
  end

  -- Apply gravity if jumping
  if player.isJumping then
    player.y = player.y + player.jumpVelocity * dt
    player.jumpVelocity = player.jumpVelocity + player.gravity * dt

    -- Check for landing
    if player.y >= player.groundY then
      player.y = player.groundY
      player.isJumping = false
      player.jumpVelocity = 0
      player.canDoubleJump = false
      -- If attack is still active, keep playing that animation;
      -- otherwise revert to idle
      if not player.isAttacking then
        player.anim = player.animations.idle
      end
    end
  end

  ----------------------------------------------------------------------
  -- 4) Idle Animation (if not jumping or attacking or moving)
  ----------------------------------------------------------------------
  if player.isIdle and not player.isJumping and not player.isAttacking then
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

  -- Update the animation
  player.anim:update(dt)

  -- Keep track of jump press state
  player.wasJumpPressedLastFrame = jumpIsDown
end

function love.draw()
  local scaleX = 8 * player.direction -- Flip horizontally if direction is -1
  local offsetX = (player.direction == -1) and (8 * 8) or 0 -- Shift sprite when flipped
  player.anim:draw(player.spriteSheet, player.x + offsetX, player.y, 0, scaleX, 8)
end
