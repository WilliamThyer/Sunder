-- CharacterBase.lua
local CharacterBase = {}
CharacterBase.__index = CharacterBase

-- Generic constructor and properties
function CharacterBase:new(x, y)
    local instance = setmetatable({}, self)
    
    -- Position & Size
    instance.x = x or 0
    instance.y = y or 0
    instance.width = 8
    instance.height = 8
    instance.groundY = instance.y

    instance.direction = 1
    instance.canMove   = true
    instance.speed     = 28
    instance.gravity   = 400

    instance.jumpHeight    = -120
    instance.jumpVelocity  = 0
    instance.isJumping     = false
    instance.canDoubleJump = false

    instance.landingLag       = 0.15
    instance.landingLagTimer  = 0
    instance.isLanding        = false

    -- Attack states
    instance.isAttacking              = false
    instance.isHeavyAttacking         = false
    instance.heavyAttackTimer         = 0
    instance.heavyAttackDuration      = 0.5
    instance.heavyAttackNoDamageDuration = 0.35
    instance.heavyAttackWidth        = 4.5
    instance.heavyAttackHeight       = 8
    instance.heavyAttackHitboxOffset = 0.5

    instance.isLightAttacking         = false
    instance.lightAttackTimer         = 0
    instance.lightAttackDuration      = 0.4
    instance.lightAttackNoDamageDuration = 0.175
    instance.lightAttackWidth        = 3
    instance.lightAttackHeight       = 8
    instance.lightAttackHitboxOffset = 0.5

    instance.isDownAir                = false
    instance.downAirDuration          = 1
    instance.downAirTimer             = 0

    instance.damageMapping = {
        lightAttack = 1,
        heavyAttack = 3,
        downAir     = 2,
        shockWave = 1
    }
    instance.staminaMapping = {
        lightAttack = 2,
        heavyAttack = 3,
        downAir     = 2,
        dash        = 1
    }

    -- Dash
    instance.isDashing    = false
    instance.dashTimer    = 0
    instance.dashDuration = 0.25
    instance.canDash      = true
    instance.dashSpeed    = 115
    instance.dashVelocity = 0

    -- Charge/Lunge system for special attacks
    instance.chargeVelocity = 0
    instance.chargeSpeed = 0
    instance.chargeDuration = 0
    instance.chargeTimer = 0

    -- Shield
    instance.isShielding = false

    -- Hurt / Knockback
    instance.isHurt             = false
    instance.hurtTimer          = 0
    instance.isInvincible       = false
    instance.invincibleTimer    = 0
    instance.knockbackBase      = instance.speed * 2 
    instance.knockbackSpeed     = 0
    instance.knockbackDirection = 1

    -- Idle / Movement
    instance.isIdle    = true
    instance.isMoving  = false
    instance.idleTimer = 0

    -- Stun + Counter
    instance.isStunned       = false
    instance.stunTimer       = 0
    instance.isCountering    = false
    instance.counterTimer    = 0
    instance.counterDuration = 0.5
    instance.counterActiveWindow = 0.25
    instance.counterActive   = false

    -- Health & Stamina
    instance.health          = 10
    instance.maxHealth       = 10
    instance.stamina         = 10
    instance.maxStamina      = 10
    instance.timeSinceStaminaUse     = 0
    instance.staminaRegenDelay       = 0.5 -- .5
    instance.staminaRegenAccumulator = 0
    instance.staminaRegenInterval    = 0.3 -- .3

    -- Death
    instance.timeToDeath = 0.15
    instance.isDead = false
    instance.isDying = false
    instance.isDyingTimer = 0

    -- Stocks & Respawning
    instance.stocks = 3
    instance.isRespawning = false
    instance.respawnDelayTimer = 0
    instance.respawnInvincibleTimer = 0
    instance.respawnInvincibleDuration = 1.0
    instance.respawnFlashAlpha = 0

    -- Shield Knockback
    instance.isShieldKnockback   = false
    instance.shieldKnockTimer    = 0
    instance.shieldKnockDuration = 0.2
    instance.shieldKnockBase     = instance.speed * 0.8
    instance.shieldKnockSpeed    = 0
    instance.shieldKnockDir      = 0

    return instance
end

--------------------------------------------------
-- Generic Collision Functions
--------------------------------------------------
function CharacterBase:checkCollision(other)
    return self.x < other.x + other.width and
           self.x + self.width > other.x and
           self.y < other.y + other.height and
           self.y + self.height > other.y
end

function CharacterBase:resolveCollision(other)
    if self:checkCollision(other) then
        local overlapLeft  = (self.x + self.width) - other.x
        local overlapRight = (other.x + other.width) - self.x
        if overlapLeft < overlapRight then
            self.x    = self.x - overlapLeft / 2
            other.x   = other.x + overlapLeft / 2
        else
            self.x    = self.x + overlapRight / 2
            other.x   = other.x - overlapRight / 2
        end
    end
end

--------------------------------------------------
-- Attack Helpers (Generic)
--------------------------------------------------
function CharacterBase:getHitbox(attackType)
    if attackType == "downAir" then
        -- pull the real frame size
        local aw, ah = self.attackGrid.frameWidth, self.attackGrid.frameHeight

        -- choose a narrower width (e.g. 50% of frame)…
        local w = aw * 0.5
        -- …and half the height if you like the lower half only
        local h = ah * 0.5

        -- center that smaller box under your character
        local x = self.x + (aw - w) * 0.5
        -- if self.y is the **top** of the sprite:
        local y = self.y + (ah * 0.5)
        -- if you switched to using oy=ah in draw (so self.y is **ground**), use: 
        -- local y = self.y - h

        return { x = x, y = y, width = w, height = h }
    elseif attackType == "lightAttack" then
        return {
            width  = self.lightAttackWidth,
            height = self.lightAttackHeight,
            x      = (self.direction == 1) and (self.x + self.width - self.lightAttackHitboxOffset) or (self.x - self.lightAttackWidth + self.lightAttackHitboxOffset),
            y      = self.y - (self.height * 0.5)
        }
    elseif attackType == "heavyAttack" then
        return {
            width  = self.heavyAttackWidth,
            height = self.heavyAttackHeight,
            x      = (self.direction == 1) and (self.x + self.width - self.heavyAttackHitboxOffset) or (self.x - self.heavyAttackWidth + self.heavyAttackHitboxOffset),
            y      = self.y - (self.height * 0.5)
        }
    elseif attackType == "upAir" then
        return {
            width  = self.width * 0.8,
            height = self.height * 0.5,
            x      = self.x + (self.width - self.width * 0.8) / 2,
            y      = self.y - self.height * 0.5
        }
    else
        local hitWidth = 3
        return {
            width  = hitWidth,
            height = self.height,
            x      = (self.direction == 1) and (self.x + self.width) or (self.x - hitWidth),
            y      = self.y
        }
    end
end

-- get hurtbox func
function CharacterBase:getHurtbox()
    return {
        width  = self.width,
        height = self.height,
        x      = self.x,
        y      = self.y
    }
end

function CharacterBase:checkHit(other, attackType)
    local hitbox = self:getHitbox(attackType)
    local hurtbox = other:getHurtbox()
    local hit = hitbox.x < hurtbox.x + hurtbox.width and
                hitbox.x + hitbox.width > hurtbox.x and
                hitbox.y < hurtbox.y + hurtbox.height and
                hitbox.y + hitbox.height > hurtbox.y
    -- Counter window check:
    if hit and other.isCountering and other.counterActive then
        -- Only allow counter if defender is facing the attacker
        local isFacingAttacker = (other.direction == 1 and self.x > other.x) or 
                                (other.direction == -1 and self.x < other.x)
        if isFacingAttacker then
            other:triggerSuccessfulCounter(self)
        end
        return false
    end
    return hit
end

function CharacterBase:checkShieldBlock(attacker)
    return self.isShielding and (self.direction ~= attacker.direction)
end

function CharacterBase:getKnockbackDirection(attacker)
    if attacker.x < self.x then
        return 1   -- push right
    else
        return -1  -- push left
    end
end

--------------------------------------------------
-- Stamina and Attack Effects
--------------------------------------------------
function CharacterBase:useStamina(amount)
    if self.stamina >= amount then
        self.stamina = self.stamina - amount
        self.timeSinceStaminaUse = 0
        return true
    end
    return false
end

function CharacterBase:triggerNoStaminaFeedback()
    -- Only trigger if not already hurt/dying/dead/respawning
    if not self.isHurt and not self.isDying and not self.isDead and not self.isRespawning then
        self:playSound('noStamina')
        self.isHurt = true
        self.hurtTimer = 0.5
        -- Zero out knockback to prevent sliding during the animation
        self.knockbackSpeed = 0
        self.knockbackDirection = 0
    end
end

function CharacterBase:heal(amount)
    self.health = math.min(self.maxHealth, self.health + amount)
end

--------------------------------------------------
-- Sound Effect Helpers
--------------------------------------------------
function CharacterBase:canPlaySounds()
    -- Don't play sounds if dead, dying, or respawning
    return not (self.isDead or self.isDying or self.isRespawning)
end

function CharacterBase:stopAllSounds()
    -- Stop all currently playing sound effects, except die and finalDie
    -- (these should play in their entirety)
    if self.soundEffects then
        for soundName, sound in pairs(self.soundEffects) do
            if sound and sound:isPlaying() then
                -- Don't stop die or finalDie sounds - let them play fully
                if soundName ~= 'die' and soundName ~= 'finalDie' then
                    sound:stop()
                end
            end
        end
    end
end

function CharacterBase:playSound(soundName)
    -- Safely play a sound effect only if character can play sounds
    if self:canPlaySounds() and self.soundEffects and self.soundEffects[soundName] then
        self.soundEffects[soundName]:play()
    end
end

function CharacterBase:updateStamina(dt)
    self.timeSinceStaminaUse = self.timeSinceStaminaUse + dt
    if self.timeSinceStaminaUse > self.staminaRegenDelay then
        self.staminaRegenAccumulator = self.staminaRegenAccumulator + dt
        while self.staminaRegenAccumulator >= self.staminaRegenInterval do
            self.staminaRegenAccumulator = self.staminaRegenAccumulator - self.staminaRegenInterval
            if self.stamina < self.maxStamina then
                self.stamina = self.stamina + 1
            end
        end
    end
end

function CharacterBase:handleAttackEffects(attacker, dt, knockbackMultiplier, attackType)
    local damage = self.damageMapping[attackType] or 1
    if self.isStunned then
        damage = damage + 1
    end
    local shieldCostMapping = {
        shockWave = 1,
        lightAttack = 1,
        heavyAttack = 3
    }
    local blockCost = shieldCostMapping[attackType] or 1
    
    local isUnblockable = (attackType == "heavyAttack") and attacker.isUnblockableHeavy

     -- Check invincibility (both hit invincibility and respawn invincibility)
     local isInvincible = self.isInvincible or (self.respawnInvincibleTimer > 0)
     if not self.isHurt and not isInvincible then
        -- Check for hit stun during attack startup frames
        local shouldInterruptAttack = false
        
        -- Check if player is in the middle of an attack during startup frames
        if self.isHeavyAttacking and self.heavyAttackTimer > (self.heavyAttackDuration - self.heavyAttackNoDamageDuration) then
            -- Player is in heavy attack startup frames
            shouldInterruptAttack = true
        elseif self.isLightAttacking and self.lightAttackTimer > (self.lightAttackDuration - self.lightAttackNoDamageDuration) then
            -- Player is in light attack startup frames
            shouldInterruptAttack = true
        elseif self.isDownAir and self.downAirTimer > (self.downAirDuration - 0.2) then
            -- Player is in down air startup frames (assuming 0.2s startup)
            shouldInterruptAttack = true
        end
        
        -- Interrupt the attack if hit during startup
        if shouldInterruptAttack then
            -- Stop attack sound effects that are currently playing
            if self.soundEffects then
                if self.isHeavyAttacking and self.soundEffects['heavyAttack'] then
                    self.soundEffects['heavyAttack']:stop()
                end
                if self.isLightAttacking and self.soundEffects['lightAttack'] then
                    self.soundEffects['lightAttack']:stop()
                end
                if self.isDownAir and self.soundEffects['downAir'] then
                    self.soundEffects['downAir']:stop()
                end
            end
            
            self.isAttacking = false
            self.isHeavyAttacking = false
            self.isLightAttacking = false
            self.isDownAir = false
            self.heavyAttackTimer = 0
            self.lightAttackTimer = 0
            self.downAirTimer = 0
            self.hasHitHeavy = false
            self.hasHitLight = false
            self.hasHitDownAir = false
            self.shockwaveSpawned = false
        end
        
        -- Use normal shield logic **only when the hit is NOT unblockable**
        if (not isUnblockable)
           and self:checkShieldBlock(attacker)
           and self:useStamina(blockCost) then
            -- regular shield-block response
            self:playSound('shieldHit')
            self.isShieldKnockback = true
            self.shieldKnockTimer  = self.shieldKnockDuration
            self.shieldKnockDir    = self:getKnockbackDirection(attacker)
            self.shieldKnockSpeed  = self.shieldKnockBase * (knockbackMultiplier or 1)
            -- Trigger freeze frame for shield hits (shorter duration)
            if GameInfo and triggerFreezeFrame then
                triggerFreezeFrame('shieldHit')
            end
        else
            -- full damage goes through
            self:playSound('hitHurt')
            self.health = math.max(0, self.health - damage)
            self.isHurt          = true
            self.hurtTimer       = 0.2
            self.isInvincible    = true
            self.invincibleTimer = 0.5
            if self.isJumping then
                self.jumpVelocity = -math.abs(self.knockbackSpeed * 1.5)
            end
            self.knockbackSpeed     = self.knockbackBase * (knockbackMultiplier or 1)
            self.knockbackDirection = self:getKnockbackDirection(attacker)
            self.x = self.x - self.knockbackSpeed * self.knockbackDirection * dt
            -- Trigger freeze frame for successful hits
            if GameInfo and triggerFreezeFrame then
                triggerFreezeFrame(attackType)
            end
        end
    end
end

function CharacterBase:triggerSuccessfulCounter(attacker)
    self:playSound('successfulCounter')
    self.isCountering = false
    self.counterTimer = 0
    self.counterActive = false

    attacker.isStunned = true
    attacker.stunTimer = 1

    attacker.isAttacking      = false
    attacker.isHeavyAttacking = false
    attacker.isLightAttacking = false
    attacker.isDownAir        = false
    
    -- Trigger freeze frame for successful counters
    if GameInfo and triggerFreezeFrame then
        triggerFreezeFrame('counter')
    end
end

--------------------------------------------------
-- Hurt/Death State Update (Generic)
--------------------------------------------------
function CharacterBase:updateHurtState(dt)
    if self.health == 0 and not self.isDying and not self.isDead and not self.isRespawning then
        self.isHurt = false
        self.isDying = true
        self.isDyingTimer = self.timeToDeath
        self.canMove = false
        -- Immediately update world position to move collision body off-screen
        if self.world then
            self.world:update(self, self.x+1, -10, self.width-2, self.height-1)
        end
        -- Stop all sounds when dying
        self:stopAllSounds()
        -- Play finalDie.wav if this is the last stock, otherwise play die.wav
        if self.stocks == 1 then
            self.soundEffects['finalDie']:play()
        else
            self.soundEffects['die']:play()
        end
        -- Trigger freeze frame for deaths
        if GameInfo and triggerFreezeFrame then
            triggerFreezeFrame('death')
        end
        -- Trigger hit flash for death visual feedback
        if GameInfo and triggerHitFlash then
            triggerHitFlash()
        end
    elseif self.isDying then
        self.isDyingTimer = self.isDyingTimer - dt
        if self.isDyingTimer <= 0 then
            -- Check if player has stocks remaining
            if self.stocks > 0 then
                -- Lose a stock and start respawn process
                self.stocks = self.stocks - 1
                self.isDying = false
                self.isRespawning = true
                self.respawnDelayTimer = 1.0  -- 1.0 second delay before respawn
                self.y = -10
                -- Immediately update world position to move collision body off-screen
                if self.world then
                    self.world:update(self, self.x+1, -10, self.width-2, self.height-1)
                end
                -- Stop all sounds when respawning
                self:stopAllSounds()
            else
                -- No stocks left, player is dead
                self.isDead = true
                self.isDying = false
                self.y = -10
                -- Immediately update world position to move collision body off-screen
                if self.world then
                    self.world:update(self, self.x+1, -10, self.width-2, self.height-1)
                end
                -- Stop all sounds when fully dead
                self:stopAllSounds()
            end
        end
    elseif self.isRespawning then
        -- Set stamina to max while respawning
        self.stamina = self.maxStamina
        -- If player has no stocks left, convert to dead state
        if self.stocks <= 0 then
            self.isRespawning = false
            self.isDead = true
            self.canMove = false
            self.y = -10
            -- Stop all sounds when fully dead
            self:stopAllSounds()
        -- Handle respawn delay
        elseif self.respawnDelayTimer > 0 then
            self.respawnDelayTimer = self.respawnDelayTimer - dt
            self.canMove = false
            self.y = -10  -- Keep player off-screen during delay
            -- Immediately update world position to move collision body off-screen
            if self.world then
                self.world:update(self, self.x+1, -10, self.width-2, self.height-1)
            end
        else
            -- Delay complete, respawn will be triggered from main.lua
            -- (we need the other player's position to calculate spawn)
        end
    elseif self.isDead then
        self.canMove = false
        self.y = -10
        -- Immediately update world position to move collision body off-screen
        if self.world then
            self.world:update(self, self.x+1, -10, self.width-2, self.height-1)
        end
        -- Set stamina to max while dead
        self.stamina = self.maxStamina
    end

    if self.isHurt then
        self.hurtTimer = self.hurtTimer - dt
        self.canMove   = false
        self.x = self.x - (self.knockbackSpeed * self.knockbackDirection * dt * -1)
        if self.hurtTimer <= 0 then
            self.isHurt   = false
            self.canMove  = true
        end
    end

    if self.isInvincible then
        self.invincibleTimer = self.invincibleTimer - dt
        if self.invincibleTimer <= 0 then
            self.isInvincible = false
        end
    end

    -- Update respawn invincibility timer
    if self.respawnInvincibleTimer > 0 then
        self.respawnInvincibleTimer = self.respawnInvincibleTimer - dt
        -- Flash on/off every 0.1 seconds (10 times per second)
        -- Use modulo to create on/off pattern: on when remainder is > 0.05, off when <= 0.05
        local flashCycle = (self.respawnInvincibleDuration - self.respawnInvincibleTimer) % 0.2
        self.respawnFlashAlpha = (flashCycle < 0.1) and 1 or 0  -- 1 = visible, 0 = invisible
        if self.respawnInvincibleTimer <= 0 then
            self.respawnInvincibleTimer = 0
            self.respawnFlashAlpha = 1  -- Always visible when not flashing
        end
    else
        self.respawnFlashAlpha = 1  -- Always visible when not invincible
    end

    if self.isStunned then
        self.stunTimer = self.stunTimer - dt
        self.canMove   = false
        if self.stunTimer <= 0 then
            self.isStunned = false
            self.canMove   = true
        end
    end

    if self.isShieldKnockback then
        self.isShielding = true
        self.shieldKnockTimer = self.shieldKnockTimer - dt
        self.canMove = false
        self.x = self.x - (self.shieldKnockSpeed * self.shieldKnockDir * dt * -1)
        if self.shieldKnockTimer <= 0 then
            self.isShieldKnockback = false
            self.canMove = true
        end
    end

    if self.isDying or self.isDead then
        self.canMove = false
    end
end

--------------------------------------------------
-- Respawn Method
--------------------------------------------------
function CharacterBase:respawn(x, y)
    -- Reset position
    self.x = x
    self.y = y
    
    -- Update bump world position
    if self.world then
        self.world:update(self, self.x+1, self.y, self.width-2, self.height-1)
    end
    
    -- Reset all combat states
    self.isAttacking = false
    self.isHeavyAttacking = false
    self.isLightAttacking = false
    self.isDownAir = false
    self.heavyAttackTimer = 0
    self.lightAttackTimer = 0
    self.downAirTimer = 0
    self.hasHitHeavy = false
    self.hasHitLight = false
    self.hasHitDownAir = false
    
    -- Reset shield state
    self.isShielding = false
    self.isShieldKnockback = false
    self.shieldKnockTimer = 0
    
    -- Reset dash state
    self.isDashing = false
    self.dashTimer = 0
    self.dashVelocity = 0
    self.canDash = true
    
    -- Reset jump state
    self.isJumping = false
    self.jumpVelocity = 0
    self.canDoubleJump = false
    
    -- Reset knockback/velocity
    self.knockbackSpeed = 0
    self.knockbackDirection = 1
    self.chargeVelocity = 0
    self.chargeTimer = 0
    
    -- Reset hurt/stun states
    self.isHurt = false
    self.hurtTimer = 0
    self.isStunned = false
    self.stunTimer = 0
    self.isCountering = false
    self.counterTimer = 0
    self.counterActive = false
    
    -- Reset health to full
    self.health = self.maxHealth
    self.stamina = self.maxStamina
    
    -- Set direction to face center (or opponent will be handled in main.lua)
    local centerX = 64  -- Center of 128-wide screen
    if x < centerX then
        self.direction = 1  -- Face right
    else
        self.direction = -1  -- Face left
    end
    
    -- Enable movement
    self.canMove = true
    
    -- Set respawn invincibility
    self.respawnInvincibleTimer = self.respawnInvincibleDuration
    self.respawnFlashAlpha = 0.5
    
    -- Mark respawning as complete
    self.isRespawning = false
end

--------------------------------------------------
-- Generic "Infrastructure" Methods
--------------------------------------------------
function CharacterBase:collisionFilter(item, other)
    if other and other.isPlayer then
        -- Exclude dead/dying players from collision detection
        if other.isDead or other.isDying or other.isRespawning then
            return nil
        end
        return "slide"
    end
    return "slide"
end

function CharacterBase:initializeUIAnimations()
    self.iconSpriteSheet = love.graphics.newImage("assets/sprites/icons.png")
    
    -- Map color name to starting column (1-indexed)
    -- Blue: columns 1-2, Red: columns 3-4, Yellow: columns 5-6, Purple: columns 7-8
    local colorToColumn = {
        Blue = 1,
        Red = 3,
        Yellow = 5,
        Purple = 7
    }
    
    -- Get starting column for this player's color, default to Blue (column 1)
    local colorName = self.colorName or "Blue"
    local startColumn = colorToColumn[colorName] or 1
    
    -- Calculate x positions: x = 1 + (column - 1) * 9
    -- Each sprite is 8x8 pixels with 1 pixel spacing (9 pixels per sprite)
    local heartX = 1 + (startColumn - 1) * 9
    local emptyHeartX = 1 + (startColumn) * 9
    
    self.iconSprites = {
        heart        = love.graphics.newQuad(heartX, 1, 8, 8, self.iconSpriteSheet),
        emptyHeart   = love.graphics.newQuad(emptyHeartX, 1, 8, 8, self.iconSpriteSheet),
        stamina      = love.graphics.newQuad(1, 10, 8, 8, self.iconSpriteSheet),
        emptyStamina = love.graphics.newQuad(10, 10, 8, 8, self.iconSpriteSheet),
        stock      = love.graphics.newQuad(1, 19, 8, 8, self.iconSpriteSheet),
        emptyStock = love.graphics.newQuad(10, 19, 8, 8, self.iconSpriteSheet)
    }
    if self.index == 1 then
        self.iconXPos = 2
    else
        self.iconXPos = 128 - (5 * self.maxHealth) - 10
    end
    self.healthYPos  = 72 - 9
    self.staminaYPos = 72 - 11
    self.stockYPos    = 72 - 3
end

function CharacterBase:moveWithBump(dt)
    local goalX = self.x
    local goalY = self.y
    local tinyDown = 0

    if self.isDashing then
        goalX = self.x + (self.dashVelocity * dt)
    elseif self.chargeVelocity and self.chargeVelocity ~= 0 then
        -- Apply charge velocity for lunging attacks
        goalX = self.x + (self.chargeVelocity * dt)
    elseif self.isMoving and self.canMove then
        local inputX = self.direction
        goalX = self.x + (inputX * self.speed * 2 * dt)
    end

    if self.isJumping then
        goalY = self.y + (self.jumpVelocity * dt)
        self.jumpVelocity = self.jumpVelocity + (self.gravity * dt)
    else
        tinyDown = 1
        goalY = self.y + tinyDown
    end

    local actualX, actualY, cols, len = self.world:move(self, goalX, goalY, self.collisionFilter)
    self.x, self.y = actualX, actualY

    local foundFloor = false
    for i = 1, len do
        local col = cols[i]
        local nx, ny = col.normal.x, col.normal.y
        if ny < 0 then
            foundFloor = true
            if self.isDownAir then
                self:endDownAir()
            elseif self.isJumping then
                self:land()
            end
        elseif ny > 0 then
            self.jumpVelocity = 0
        end
    end

    if not foundFloor and not self.isJumping then
        self.isJumping = true
    end
end

function CharacterBase:triggerDownAir()
    if not self:useStamina(self.staminaMapping['downAir']) then
        self:triggerNoStaminaFeedback()
        return
    end
    self:playSound('downAir')
    self.isAttacking  = true
    self.isDownAir    = true
    self.downAirTimer = self.downAirDuration
    self.gravity      = self.gravity * 1.2
    if self.animations and self.animations.downAir then
        self.animations.downAir:gotoFrame(1)
    end
    self.hasHitDownAir = false
end

function CharacterBase:handleDownAir(dt, otherPlayer)
    if self.isDownAir then
        if not self.hasHitDownAir then
            if otherPlayer and self:checkHit(otherPlayer, "downAir") then
                otherPlayer:handleAttackEffects(self, dt, 0.5, "downAir")
                self.hasHitDownAir = true
            end
        end
        self.downAirTimer = self.downAirTimer - dt
        if self.downAirTimer <= 0 then
            self:endDownAir()
        end
    end
end

function CharacterBase:endDownAir()
    self.isDownAir     = false
    self.isAttacking   = false
    self.hasHitDownAir = false
    self:land()
end

function CharacterBase:land()
    self:resetGravity()
    self.isJumping     = false
    self.jumpVelocity  = 0
    self.canDoubleJump = false
    self.canDash       = true
    self.isDownAir     = false
    if not self.isAttacking then
        self.landingLagTimer = self.landingLag
    end
    
end

function CharacterBase:resetGravity()
    self.gravity = 400
end

function CharacterBase:triggerCounter()
    self:playSound('counter')
    self.isCountering = true
    self.counterTimer = self.counterDuration
    self.counterActive = true
end

function CharacterBase:updateCounter(dt)
    if self.isCountering then
        self.counterTimer = self.counterTimer - dt
        if self.counterTimer <= (self.counterDuration - self.counterActiveWindow) then
            self.counterActive = false
        end
        if self.counterTimer <= 0 then
            self.isCountering  = false
            self.counterTimer  = 0
            self.counterActive = false
        end
    end
end

function CharacterBase:updateLandingLag(dt)
    if self.landingLagTimer > 0 then
        self.isLanding = true
        self.landingLagTimer = self.landingLagTimer - dt
        if self.landingLagTimer <= 0 then
            self.isLanding = false
            self.landingLagTimer = 0
        end
    end
end

function CharacterBase:updateAnimation(dt)
    if self.isDying or self.isDead then
        self.currentAnim = self.animations.die
    elseif self.isHurt or self.isStunned then
        self.currentAnim = self.animations.hurt
    elseif self.isShieldKnockback then
        self.currentAnim = self.animations.shieldBlock
    elseif self.isShielding then
        self.currentAnim = self.animations.shield
    elseif self.isLanding then
        self.currentAnim = self.animations.land
    elseif self.isCountering then
        self.currentAnim = self.animations.counter
    elseif self.isHeavyAttacking then
        self.currentAnim = self.animations.heavyAttack
    elseif self.isLightAttacking then
        self.currentAnim = self.animations.lightAttack
    elseif self.isDownAir then
        self.currentAnim = self.animations.downAir
    elseif self.isDashing then
        self.currentAnim = self.animations.dash
    elseif self.isJumping then
        self.currentAnim = self.animations.jump
    elseif self.isMoving then
        self.currentAnim = self.animations.move
    else
        self.currentAnim = self.animations.idle
    end

    if self.currentAnim and self.currentAnim.update then
        self.currentAnim:update(dt)
    end
end

function CharacterBase:drawUI()
    for h = 0, self.maxHealth - 1 do
        local icon = (self.health > h) and 'heart' or 'emptyHeart'
        local xPos = self.iconXPos + 6 * h
        self:drawIcon(xPos, self.healthYPos, icon)
    end

    for s = 0, self.maxStamina - 1 do
        -- Player 1 depletes from left to right, Player 2 depletes from right to left
        local staminaCheck
        if self.index == 1 then
            -- P1: reverse the check so leftmost depletes first
            staminaCheck = self.stamina > (self.maxStamina - 1 - s)
        else
            -- P2: keep current behavior (rightmost depletes first)
            staminaCheck = self.stamina > s
        end
        local icon = staminaCheck and 'stamina' or 'emptyStamina'
        local xPos = self.iconXPos + 6 * s
        self:drawIcon(xPos, self.staminaYPos, icon)
    end

    -- Draw stocks below hearts
    -- Both players: stocks aligned with innermost hearts/stamina, extending outward
    -- P1: extends left from innermost heart (outermost left, innermost at rightmost heart position)
    -- P2: extends right from innermost heart (outermost right, innermost at leftmost heart position)
    -- First stock lost is outermost, last stock remaining is innermost (middlemost)
    local maxStocks = 3
    local stockSpacing = 6
    
    if self.index == 1 then
        -- P1: innermost heart is at iconXPos + 6 * (maxHealth - 1) (rightmost heart)
        local innermostHeartX = self.iconXPos + 6 * (self.maxHealth - 1)
        -- Draw from innermost heart extending left
        -- Stock positions: innermostHeartX-12 (innermost, lost last), innermostHeartX-6 (middle), innermostHeartX (outermost, lost first)
        for st = 0, maxStocks - 1 do
            -- Reverse order: st=0 is outermost (rightmost position), st=2 is innermost (leftmost position)
            -- Check: outermost (st=0) shows if stocks >= 1, innermost (st=2) shows if stocks >= 3
            local stockCheck = maxStocks - st  -- st=0 checks stocks >= 1, st=1 checks stocks >= 2, st=2 checks stocks >= 3
            local icon = (self.stocks >= stockCheck) and 'stock' or 'emptyStock'
            -- Position: rightmost (outermost) at innermost heart, leftmost (innermost) at innermost heart - 12
            local xPos = innermostHeartX - stockSpacing * (maxStocks - 1 - st)
            self:drawIcon(xPos, self.stockYPos, icon)
        end
    else
        -- P2: innermost heart is at iconXPos (leftmost heart)
        local innermostHeartX = self.iconXPos
        -- Draw from innermost heart extending right
        -- Stock positions: innermostHeartX (innermost, lost last), innermostHeartX+6 (middle), innermostHeartX+12 (outermost, lost first)
        for st = 0, maxStocks - 1 do
            -- Reverse order: st=0 is outermost (leftmost position), st=2 is innermost (rightmost position)
            -- Check: outermost (st=0) shows if stocks >= 1, innermost (st=2) shows if stocks >= 3
            local stockCheck = maxStocks - st  -- st=0 checks stocks >= 1, st=1 checks stocks >= 2, st=2 checks stocks >= 3
            local icon = (self.stocks >= stockCheck) and 'stock' or 'emptyStock'
            -- Position: leftmost (outermost) at innermost heart, rightmost (innermost) at innermost heart + 12
            local xPos = innermostHeartX + stockSpacing * (maxStocks - 1 - st)
            self:drawIcon(xPos, self.stockYPos, icon)
        end
    end
end

function CharacterBase:drawIcon(x, y, iconName)
    local UI_SCALE = 1
    love.graphics.draw(self.iconSpriteSheet, self.iconSprites[iconName], x, y, 0, UI_SCALE, UI_SCALE)
end

return CharacterBase
