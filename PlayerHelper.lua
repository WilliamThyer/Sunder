local PlayerHelper = {}

function PlayerHelper.checkCollision(p1, p2)
  return p1.x < p2.x + p2.width and
    p1.x + p1.width > p2.x and
    p1.y < p2.y + p2.height and
    p1.y + p1.height > p2.y
end

function PlayerHelper.resolveCollision(p1, p2)
  if PlayerHelper.checkCollision(p1, p2) then
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

function PlayerHelper.checkHit(attacker, target, attackType)
  -- Define hitbox dimensions based on attack type
  local hitboxWidth, hitboxHeight, hitboxX, hitboxY

  if attackType == "downAir" then
    -- Hitbox for downAir: positioned below the attacker
    hitboxWidth = attacker.width * 0.8 -- Narrower than the player's width
    hitboxHeight = attacker.height * 0.5 -- Half of the player's height
    hitboxX = attacker.x + (attacker.width - hitboxWidth) / 2
    hitboxY = attacker.y + attacker.height -- Below the player
  elseif attackType == "sideAttack" then
    -- Hitbox for side attack: positioned to the side of the attacker
    hitboxWidth = 8 * 5 -- Default width for standard side attack
    hitboxHeight = attacker.height -- Match player's height
    hitboxX = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - hitboxWidth)
    hitboxY = attacker.y
  elseif attackType == "upAir" then
    -- Hitbox for upAir: positioned above the attacker
    hitboxWidth = attacker.width * 0.8 -- Narrower than the player's width
    hitboxHeight = attacker.height * 0.5 -- Half of the player's height
    hitboxX = attacker.x + (attacker.width - hitboxWidth) / 2
    hitboxY = attacker.y - hitboxHeight -- Above the player
  else
    -- Default hitbox: for other or unspecified attacks
    hitboxWidth = 8 * 5 -- Default width
    hitboxHeight = attacker.height -- Match player's height
    hitboxX = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - hitboxWidth)
    hitboxY = attacker.y
  end

  -- Target's hurtbox
  local hurtboxWidth = 7 * 8
  local hurtboxHeight = 7 * 8
  local hurtboxX = target.x + (target.width - hurtboxWidth) / 2
  local hurtboxY = target.y + (target.height - hurtboxHeight) / 2

  -- Check for collision
  local hit = hitboxX < hurtboxX + hurtboxWidth and
    hitboxX + hitboxWidth > hurtboxX and
    hitboxY < hurtboxY + hurtboxHeight and
    hitboxY + hitboxHeight > hurtboxY

  -- Ignore hit if target is shielding and facing the attacker
  if target.isShielding and target.direction ~= attacker.direction then
    hit = false
  end

  return hit
end

function PlayerHelper.handleAttack(attacker, target, dt)
  if attacker.isAttacking and attacker.attackTimer <= attacker.attackNoDamageDuration then
    if PlayerHelper.checkHit(attacker, target) then
      if not target.isHurt and not target.isInvincible then
        target.canMove = false
        target.isHurt = true
        target.hurtTimer = .2
        target.isInvincible = true
        target.invincibleTimer = .5
        target.idleTimer = 0
        target.anim = target.animations.hurt
        target.knockbackDirection = attacker.direction
        target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt * -1
      end
    end
  end

  if target.isHurt then
    target.hurtTimer = target.hurtTimer - dt
    target.anim = target.animations.hurt
    target.canMove = false
    target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt * -1
    if target.hurtTimer <= 0 then
      target.isHurt = false
      target.anim = target.animations.idle
    end
  end

  if target.isInvincible then
    target.invincibleTimer = target.invincibleTimer - dt
    if target.invincibleTimer <= 0 then
      target.isInvincible = false
    end
  end
end

function PlayerHelper.handleDownAir(player, target, dt)
  if player.isDownAir then
    -- Check collision with target
    if PlayerHelper.checkHit(player, target, "downAir")
      and not target.isHurt and not target.isInvincible then
      print('hurt!')
      target.isHurt = true
      target.hurtTimer = 0.2
      target.isInvincible = true
      target.invincibleTimer = 0.5
      target.idleTimer = 0
      target.anim = target.animations.hurt
      target.knockbackSpeed = target.defaultKnockbackSpeed / 2 -- Reduce knockback for downAir

      -- Calculate knockback direction based on overlap
      local overlapLeft = (player.x + player.width) - target.x
      local overlapRight = (target.x + target.width) - player.x

      if overlapLeft < overlapRight then
        target.knockbackDirection = 1 -- Push left
        -- target.x = target.x - overlapLeft / 2 -- Resolve collision
      else
        target.knockbackDirection = -1 -- Push right
        -- target.x = target.x + overlapRight / 2 -- Resolve collision
      end

      -- Apply knockback
      target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt
    end

    -- End the move when the timer ends or landing
    player.downAirTimer = player.downAirTimer - dt
    print(player.downAirTimer)
    print(player.isDownAir)
    if player.downAirTimer <= 0 then
      player:endDownAir()
    elseif player.y >= player.groundY then
      player:land()
    end
  end

  if target.isHurt then
    print('hurt')
    target.hurtTimer = target.hurtTimer - dt
    target.anim = target.animations.hurt
    target.canMove = false
    target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt * -1
    if target.hurtTimer <= 0 then
      target.isHurt = false
      target.anim = target.animations.idle
    end
  end

  if target.isInvincible then
    target.invincibleTimer = target.invincibleTimer - dt
  end
  if target.invincibleTimer <= 0 then
    target.isInvincible = false
  end
end


function PlayerHelper.updatePlayer(dt, player, otherPlayer)
  player.isIdle = true
  local attackIsPressed = false
  local jumpIsDown = false
  local dashIsPressed = false
  local shieldIsPressed = false
  local downIsPressed = false
  local moveX = 0

  -- Get joystick input
  if player.joystick then
    attackIsPressed = player.joystick:isGamepadDown("x")
    jumpIsDown = player.joystick:isGamepadDown("a")
    dashIsPressed = player.joystick:isGamepadDown("rightshoulder")
    shieldIsPressed = player.joystick:isGamepadDown("leftshoulder")
    moveX = player.joystick:getGamepadAxis("leftx")
    downIsPressed = player.joystick:getGamepadAxis("lefty") > 0.5
  end

  -- SHIELD
  if shieldIsPressed and player:isAbleToShield() then
    player.canMove = false
    player.isShielding = true
    player.anim = player.animations.shield
  else
    player.isShielding = false
    player.canMove = true
  end

  -- ATTACKS
  -- Downair
  if downIsPressed and attackIsPressed and player:isAbleToDownAir() then
    player.anim = player.animations.downAir
    player:triggerDownAir()
    player.anim:gotoFrame(1)
  end
  -- Slash
  if attackIsPressed and not downIsPressed and player:isAbleToAttack() then
    player.canMove = false
    player.isAttacking = true
    player.attackTimer = player.attackDuration
    player.anim = player.animations.attack
    player.anim:gotoFrame(1)
  end
  player.attackPressedLastFrame = attackIsPressed

  if player.isAttacking then
    player.attackTimer = player.attackTimer - dt
    if player.attackTimer <= 0 then
      player.isAttacking = false
      player.canMove = true
    end
  end

  -- DASH
  if dashIsPressed and player:isAbleToDash() then
    player.isDashing = true
    player.canDash = false
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

  -- MOVE
  if player:isAbleToMove() then
    if math.abs(moveX) > 0.5 then
      player.x = player.x + moveX * player.speed * 2
      player.direction = moveX > 0 and 1 or -1
      player.isIdle = false
      player.isMoving = true
      if not player.isJumping and not player.isAttacking then
        player.anim = player.animations.move
      end
    end
  end

  -- JUMP
  if jumpIsDown and player:isAbleToJump() then
    if not player.isJumping then
      player.jumpVelocity = player.jumpHeight
      player.isJumping = true
      player.canDoubleJump = true
      player.canDash = true
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
      player.canDash = true
      if not player.isAttacking then
        player.anim = player.animations.idle
      end
    end
    if not player.isDashing and not player.isAttacking and not player.isDownAir then
      player.anim = player.animations.jump
    end
  end
  player.wasJumpPressedLastFrame = jumpIsDown

  -- IDLE
  if player:isAbleToIdle() then
    player.idleTimer = player.idleTimer + dt
    player.anim = player.animations.idle
    if player.idleTimer < 1 then
      player.anim:gotoFrame(2)
    end
  else
    player.idleTimer = 0
  end

  -- HANDLE ATTACK
  PlayerHelper.handleAttack(player, otherPlayer, dt)

  -- HANDLE DOWNAIR
  PlayerHelper.handleDownAir(player, otherPlayer, dt)

  -- ANIMATE
  player.anim:update(dt)

  -- RESOLVE COLLISIONS
  PlayerHelper.resolveCollision(player, otherPlayer)
end

function PlayerHelper.drawPlayer(player)
  local scaleX = 8 * player.direction -- Flip horizontally if direction is -1
  local offsetX = (player.direction == -1) and (8 * 8) or 0 -- Base offset for flipping
  local offsetY = 0

  -- Adjust offsets for specific states, like attacking
  if player.isAttacking then
    -- Adjust horizontally and vertically
    if player.direction == 1 then -- Facing right
      offsetX = offsetX + 1 * 8 -- Add to the right
    else -- Facing left
      offsetX = offsetX - 1 * 8 -- Subtract to the left
    end
    offsetY = offsetY - 4 * 8 -- Move up
  end

  -- Draw the sprite
  player.anim:draw(player.spriteSheet, player.x + offsetX, player.y + offsetY, 0, scaleX, 8)
end

return PlayerHelper

