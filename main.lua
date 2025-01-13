if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
io.stdout:setvbuf("no")
_G.love = require("love")
anim8 = require 'libraries/anim8'


-- print(("Player 1 is hurt:%s"):format(player1.isHurt))
print('starting game')

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  function createPlayer(x, y, joystickIndex)
    local player = {}
    player.x = x
    player.y = y
    player.groundY = y
    player.width = 64 -- Scaled width of the sprite (8 * 8)
    player.height = 64 -- Scaled height of the sprite
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
    player.animations.hurt = anim8.newAnimation(player.grid(10, 7), 1)

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

    -- Hurt logic
    player.isHurt = false
    player.hurtTimer = 0

    -- Assign joystick
    player.index = joystickIndex
    player.joystick = love.joystick.getJoysticks()[joystickIndex]

    return player
  end

  -- Create two players
  player1 = createPlayer(400, 300, 1)
  player2 = createPlayer(600, 300, 2)
end

function checkCollision(p1, p2)
  return p1.x < p2.x + p2.width and
    p1.x + p1.width > p2.x and
    p1.y < p2.y + p2.height and
    p1.y + p1.height > p2.y
end

function resolveCollision(p1, p2)
  if checkCollision(p1, p2) then
    local overlapLeft = (p1.x + p1.width) - p2.x
    local overlapRight = (p2.x + p2.width) - p1.x

    if overlapLeft < overlapRight then
      p1.x = p1.x - overlapLeft / 2
      p2.x = p2.x + overlapLeft / 2
    else
      p1.x = p1.x + overlapRight / 2
      p2.x = p2.x - overlapRight / 2
    end
  end
end

function checkHit(attacker, target)
  -- Adjust hitbox closer to the attacker
  local hitboxWidth = 28 -- Reduced width for more accurate range
  local hitboxX = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - hitboxWidth)
  local hitboxY = attacker.y
  local hitboxHeight = attacker.height

  -- Calculate target's hurtbox (central 7x7 pixels)
  local hurtboxX = target.x + (target.width - 7 * 8) / 2
  local hurtboxY = target.y + (target.height - 7 * 8) / 2
  local hurtboxWidth = 7 * 8
  local hurtboxHeight = 7 * 8

  -- Check for overlap
  local hit = hitboxX < hurtboxX + hurtboxWidth and
    hitboxX + hitboxWidth > hurtboxX and
    hitboxY < hurtboxY + hurtboxHeight and
    hitboxY + hitboxHeight > hurtboxY

  -- Check shield direction
  if target.isShielding and target.direction ~= attacker.direction then
    hit = false -- Blocked by shield
  end

  return hit
end

function handleAttack(attacker, target, dt)
  if attacker.isAttacking then
    -- Check if attack hits the target
    if checkHit(attacker, target) then
      -- Apply hurt animation if not already hurt
      if not target.isHurt then
        target.isHurt = true
        target.hurtTimer = .2 -- Hurt duration
        target.idleTimer = 0
        target.anim = target.animations.hurt
      end
    end
  end

  -- Handle hurt state
  if target.isHurt then
    target.hurtTimer = target.hurtTimer - dt
    target.anim = target.animations.hurt
    target.canMove = false
    if target.hurtTimer <= 0 then
      target.isHurt = false
      target.anim = target.animations.idle
    end
  end
end


function updatePlayer(dt, player, otherPlayer)
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
  if attackIsPressed and not player.attackPressedLastFrame and not player.isAttacking and not player.isShielding and not player.isHurt then
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
  if player.isIdle and not player.isJumping and not player.isAttacking
    and not player.isDashing and not player.isShielding and not player.isHurt then
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

  -- Handle attack/hurt
  handleAttack(player, otherPlayer, dt)

  -- Update animation
  player.anim:update(dt)
  player.wasJumpPressedLastFrame = jumpIsDown

  -- Resolve collisions
  resolveCollision(player, otherPlayer)

end

function love.update(dt)
  updatePlayer(dt, player1, player2)
  updatePlayer(dt, player2, player1)
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
