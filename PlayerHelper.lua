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

function PlayerHelper.checkHit(attacker, target)
  local hitboxWidth = 8*5 -- Reduced width for more accurate range
  local hitboxX = attacker.direction == 1 and (attacker.x + attacker.width) or (attacker.x - hitboxWidth)
  local hitboxY = attacker.y
  local hitboxHeight = attacker.height

  local hurtboxX = target.x + (target.width - 7 * 8) / 2
  local hurtboxY = target.y + (target.height - 7 * 8) / 2
  local hurtboxWidth = 7 * 8
  local hurtboxHeight = 7 * 8

  local hit = hitboxX < hurtboxX + hurtboxWidth and
    hitboxX + hitboxWidth > hurtboxX and
    hitboxY < hurtboxY + hurtboxHeight and
    hitboxY + hitboxHeight > hurtboxY

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
        if PlayerHelper.checkHit(player, target) then
            if not target.isHurt and not target.isInvincible then
                target.isHurt = true
                target.hurtTimer = 0.5
                target.anim = target.animations.hurt
                target.knockbackSpeed = player.knockbackSpeed / 2 -- Reduce knockback for downAir
                target.x = target.x - target.knockbackSpeed * target.knockbackDirection * dt
            end
        end

        -- End the move when the timer ends or landing
        player.downAirTimer = player.downAirTimer - dt
        if player.downAirTimer <= 0 then
            player:endDownAir()
        elseif player.y >= player.groundY then
            player:land()
        end
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
    player:triggerDownAir()
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

  -- DASH
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
    if not player.isDashing and not player.isAttacking then
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

  -- Handle downAir logic
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

