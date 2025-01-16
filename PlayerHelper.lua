local PlayerHelper = {}

-- Check if two players are colliding
function PlayerHelper.checkCollision(p1, p2)
  return p1.x < p2.x + p2.width and
    p1.x + p1.width > p2.x and
    p1.y < p2.y + p2.height and
    p1.y + p1.height > p2.y
end

-- Resolve collisions between players
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

-- Get hitbox dimensions and position based on attack type
local function getHitbox(attacker, attackType)
  if attackType == "downAir" then
    return {
      width = attacker.width * 0.8,
      height = attacker.height * 0.5,
      x = attacker.x + (attacker.width - attacker.width * 0.8) / 2,
      y = attacker.y + attacker.height
    }
  elseif attackType == "sideAttack" then
    local width = 40
    return {
      width = width,
      height = attacker.height,
      x = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - width),
      y = attacker.y
    }
  elseif attackType == "upAir" then
    return {
      width = attacker.width * 0.8,
      height = attacker.height * 0.5,
      x = attacker.x + (attacker.width - attacker.width * 0.8) / 2,
      y = attacker.y - attacker.height * 0.5
    }
  else
    local width = 40
    return {
      width = width,
      height = attacker.height,
      x = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - width),
      y = attacker.y
    }
  end
end

-- Check if an attack hit the target
function PlayerHelper.checkHit(attacker, target, attackType)
  local hitbox = getHitbox(attacker, attackType)
  local hurtbox = {
    width = 56,
    height = 56,
    x = target.x + (target.width - 56) / 2,
    y = target.y + (target.height - 56) / 2
  }

  local hit = hitbox.x < hurtbox.x + hurtbox.width and
    hitbox.x + hitbox.width > hurtbox.x and
    hitbox.y < hurtbox.y + hurtbox.height and
    hitbox.y + hitbox.height > hurtbox.y

  if target.isShielding and target.direction ~= attacker.direction then
    hit = false
  end

  return hit
end

-- Handle the effects of an attack
function PlayerHelper.handleAttackEffects(attacker, target, dt, knockbackMultiplier)
  if not target.isHurt and not target.isInvincible then
    target.isHurt = true
    target.hurtTimer = 0.2
    target.isInvincible = true
    target.invincibleTimer = 0.5
    target.idleTimer = 0
    target.anim = target.animations.hurt
    target.knockbackSpeed = target.knockbackSpeed * (knockbackMultiplier or 1)

    local overlapLeft = (attacker.x + attacker.width) - target.x
    local overlapRight = (target.x + target.width) - attacker.x
    target.knockbackDirection = overlapLeft < overlapRight and 1 or -1

    target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt
  end
end

-- Update the hurt state of a player
function PlayerHelper.updateHurtState(target, dt)
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

-- Handle player attacks
function PlayerHelper.handleAttack(attacker, target, dt)
  if attacker.isAttacking and attacker.attackTimer <= attacker.attackNoDamageDuration then
    if PlayerHelper.checkHit(attacker, target) then
      PlayerHelper.handleAttackEffects(attacker, target, dt, 1)
    end
  end
  PlayerHelper.updateHurtState(target, dt)
end

-- Handle Down-Air attacks
function PlayerHelper.handleDownAir(player, target, dt)
  if player.isDownAir then
    player.anim = player.animations.downAir

    if PlayerHelper.checkHit(player, target, "downAir") then
      PlayerHelper.handleAttackEffects(player, target, dt, 0.5)
    end

    player.downAirTimer = player.downAirTimer - dt
    if player.downAirTimer <= 0 then
      player:endDownAir()
    elseif player.y >= player.groundY then
      player:land()
    end
  end
  PlayerHelper.updateHurtState(target, dt)
end

-- Update a player's state
function PlayerHelper.updatePlayer(dt, player, otherPlayer)
  local input = PlayerHelper.getPlayerInput(player.joystick)
  PlayerHelper.processInput(input, player, dt)

  PlayerHelper.handleAttack(player, otherPlayer, dt)
  PlayerHelper.handleDownAir(player, otherPlayer, dt)

  player.anim:update(dt)
  PlayerHelper.resolveCollision(player, otherPlayer)
end

-- Process player input
function PlayerHelper.getPlayerInput(joystick)
  if not joystick then
    return {
      attack = false,
      jump = false,
      dash = false,
      shield = false,
      moveX = 0, -- Default to no movement
      down = false
    }
  end

  return {
    attack = joystick:isGamepadDown("x"),
    jump = joystick:isGamepadDown("a"),
    dash = joystick:isGamepadDown("rightshoulder"),
    shield = joystick:isGamepadDown("leftshoulder"),
    moveX = joystick:getGamepadAxis("leftx") or 0, -- Default to 0 if nil
    down = (joystick:getGamepadAxis("lefty") or 0) > 0.5
  }
end


-- Process the input to update player state
function PlayerHelper.processInput(input, player, dt)
  player.isIdle = true

  -- Handle shielding
  if input.shield and player:canPerformAction("shield") then
    player.canMove = false
    player.isShielding = true
    player.anim = player.animations.shield
  else
    player.isShielding = false
    player.canMove = true
  end

  -- Handle attacks
  if input.down and input.attack and player:canPerformAction("downAir") then
    player:triggerDownAir()
  elseif input.attack and player:canPerformAction("attack") then
    player.isAttacking = true
    player.attackTimer = player.attackDuration
    player.anim = player.animations.attack
    player.anim:gotoFrame(1)
  end
  player.attackPressedLastFrame = input.attack

  if player.isAttacking then
    player.attackTimer = player.attackTimer - dt
    if player.attackTimer <= 0 then
      player.isAttacking = false
      player.anim = player.animations.idle
    end
  end

  -- Handle movement
  if player:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
    player.isMoving = true
    player.x = player.x + input.moveX * player.speed * 2
    player.direction = input.moveX > 0 and 1 or -1
    if not player.isAttacking then
        player.anim = player.animations.move
    end
  else
    player.isMoving = false
  end

  -- Handle jumping
  if input.jump and player:canPerformAction("jump") then
    if not player.isJumping then
      player.jumpVelocity = player.jumpHeight
      player.isJumping = true
      player.canDoubleJump = true
      player.canDash = true
      player.anim = player.animations.jump
    elseif player.canDoubleJump then
      player.isDownAir = false
      player:resetGravity()
      player.jumpVelocity = player.jumpHeight
      player.canDoubleJump = false
      player.anim = player.animations.jump
    end
  end
  player.JumpPressedLastFrame = input.jump

  -- Update vertical position
  if player.isJumping then
    player.y = player.y + player.jumpVelocity * dt
    player.jumpVelocity = player.jumpVelocity + player.gravity * dt

    if player.y >= player.groundY then
      player.y = player.groundY
      player:land()
      if not player.isAttacking then
        player.anim = player.animations.idle
      end
    end
    if not player.isDashing and not player.isAttacking and not player.isDownAir then
      player.anim = player.animations.jump
    end
  end

  -- DASH
  if input.dash and player:canPerformAction("dash") then
    player.isDashing = true
    player.dashTimer = player.dashDuration
    player.dashVelocity = player.dashSpeed * player.direction
    player.anim = player.animations.dash
  end
  player.DashPressedLastFrame = input.dash

  if player.isDashing then
    player.canDash = false
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

  -- IDLE
  if player:canPerformAction("idle") then
    player.isIdle = true
    player.idleTimer = player.idleTimer + dt
    player.anim = player.animations.idle
    if player.idleTimer < 1 then
      player.anim:gotoFrame(1)
    end
  else
    player.idleTimer = 0
  end

end

function PlayerHelper.drawPlayer(player)
  local scaleX = 8 * player.direction
  local offsetX = (player.direction == -1) and (8 * 8) or 0
  local offsetY = 0

  if player.isAttacking then
    offsetX = offsetX + (player.direction == 1 and 8 or -8)
    offsetY = -4 * 8 -- Add Y offset for attacking
  end

  player.anim:draw(player.spriteSheet, player.x + offsetX, player.y + offsetY, 0, scaleX, 8)
end

return PlayerHelper
