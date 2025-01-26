--- CharacterBase.lua ---
local CharacterBase = {}
CharacterBase.__index = CharacterBase

function CharacterBase:new(x, y)
    local instance = setmetatable({}, CharacterBase)

    -- Position & Size
    instance.x = x or 0
    instance.y = y or 0
    instance.width = 64
    instance.height = 64
    instance.groundY = instance.y

    instance.direction = 1
    instance.canMove   = true
    instance.speed     = 3
    instance.gravity   = 2250

    instance.jumpHeight    = -850
    instance.jumpVelocity  = 0
    instance.isJumping     = false
    instance.canDoubleJump = false

    -- Attack states 
    instance.isAttacking              = false
    -- Heavy attack
    instance.isHeavyAttacking         = false
    instance.heavyAttackTimer         = 0
    instance.heavyAttackDuration      = 0.5
    instance.heavyAttackNoDamageDuration = 0.35
    -- Light attack
    instance.isLightAttacking         = false
    instance.lightAttackTimer         = 0
    instance.lightAttackDuration      = 0.4
    instance.lightAttackNoDamageDuration = 0.175
    -- Downair attack
    instance.isDownAir                = false
    instance.downAirDuration          = 1
    instance.downAirTimer             = 0
    instance.damageMapping = {
            lightAttack = 1,
            heavyAttack = 3,
            downAir     = 2
        }
    instance.staminaMapping = {
            lightAttack = 1,
            heavyAttack = 2,
            downAir     = 2,
            dash = 1
        }

    -- Dash
    instance.isDashing    = false
    instance.dashTimer    = 0
    instance.dashDuration = 0.06
    instance.canDash      = true
    instance.dashSpeed    = instance.speed * 750
    instance.dashVelocity = 0

    -- Shield
    instance.isShielding = false

    -- Hurt / Knockback
    instance.isHurt             = false
    instance.hurtTimer          = 0
    instance.isInvincible       = false
    instance.invincibleTimer    = 0
    instance.knockbackBase      = instance.speed * 150
    instance.knockbackSpeed     = 0
    instance.knockbackDirection = 1

    -- Idle / Movement states
    instance.isIdle    = true
    instance.isMoving  = false
    instance.idleTimer = 0

    -- (Stun + Counter)
    instance.isStunned       = false
    instance.stunTimer       = 0
    instance.isCountering    = false
    instance.counterTimer    = 0
    instance.counterDuration = 0.5
    instance.counterActiveWindow = 0.15
    instance.counterActive       = false

    -- Health & Stamina
    instance.health          = 10
    instance.maxHealth       = 10
    instance.stamina         = 10
    instance.maxStamina      = 10
    -- Timers to handle stamina regen
    instance.timeSinceStaminaUse    = 0      -- how long since we last spent stamina
    instance.staminaRegenDelay      = 0.5    -- wait 0.5s before regenerating
    instance.staminaRegenAccumulator= 0      -- accumulates time after the delay
    instance.staminaRegenInterval   = 0.25   -- gain 1 stamina every 0.25s once regen starts

    return instance
end

----------------------------------------------------------------
-- Collision
----------------------------------------------------------------
function CharacterBase:checkCollision(other)
    return self.x < other.x + other.width
       and self.x + self.width > other.x
       and self.y < other.y + other.height
       and self.y + self.height > other.y
end

function CharacterBase:resolveCollision(other)
    if self:checkCollision(other) then
        local overlapLeft  = (self.x + self.width)  - other.x
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

----------------------------------------------------------------
-- Attack Helpers
----------------------------------------------------------------
local function getHitbox(character, attackType)
    if attackType == "downAir" then
        return {
            width  = character.width * 0.8,
            height = character.height * 0.5,
            x      = character.x + (character.width - character.width * 0.8) / 2,
            y      = character.y + character.height
        }
    elseif attackType == "heavyAttack" then
        local width = 40
        return {
            width  = width,
            height = character.height,
            x      = (character.direction == 1)
                        and (character.x + character.width)
                        or  (character.x - width),
            y      = character.y
        }
    elseif attackType == "lightAttack" then
        local width = 40
        return {
            width  = width,
            height = character.height,
            x      = (character.direction == 1)
                        and (character.x + character.width)
                        or  (character.x - width),
            y      = character.y
        }
    elseif attackType == "upAir" then
        return {
            width  = character.width * 0.8,
            height = character.height * 0.5,
            x      = character.x + (character.width - character.width * 0.8) / 2,
            y      = character.y - character.height * 0.5
        }
    else
        -- Default to sideAttack
        local width = 40
        return {
            width  = width,
            height = character.height,
            x      = (character.direction == 1)
                        and (character.x + character.width)
                        or  (character.x - width),
            y      = character.y
        }
    end
end

function CharacterBase:checkHit(other, attackType)
    local hitbox  = getHitbox(self, attackType)
    local hurtbox = {
        width  = 56,
        height = 56,
        x      = other.x + (other.width - 56) / 2,
        y      = other.y + (other.height - 56) / 2
    }

    local hit = hitbox.x < hurtbox.x + hurtbox.width
             and hitbox.x + hitbox.width > hurtbox.x
             and hitbox.y < hurtbox.y + hurtbox.height
             and hitbox.y + hitbox.height > hurtbox.y

    -- Check if other is in an active counter window
    if hit and other.isCountering and other.counterActive then
        -- If the defender is in a counter window, the attacker gets countered
        other:triggerSuccessfulCounter(self)
        -- Return false so that the normal handleAttackEffects won't apply
        return false
    end

    return hit
end

function CharacterBase:checkShieldBlock(attacker)
    -- Shield block requires that the defender is shielding
    -- and that the defender is facing the attacker (direction ~= attacker.direction).
    local block = self.isShielding and (self.direction ~= attacker.direction)
    return block
end

-- function to spend stamina
function CharacterBase:useStamina(amount)
    if self.stamina >= amount then
        self.stamina = self.stamina - amount
        self.timeSinceStaminaUse = 0 -- reset timer so regen doesn't start immediately
        return true
    end
    return false
end

-- function to handle stamina regeneration
function CharacterBase:updateStamina(dt)
    -- If we have done nothing that uses stamina for `timeSinceStaminaUse` seconds,
    -- we start regenerating stamina.
    self.timeSinceStaminaUse = self.timeSinceStaminaUse + dt

    if self.timeSinceStaminaUse > self.staminaRegenDelay then
        -- Start accumulating
        self.staminaRegenAccumulator = self.staminaRegenAccumulator + dt

        -- Each time we exceed the regen interval, gain 1 stamina
        while self.staminaRegenAccumulator >= self.staminaRegenInterval do
            self.staminaRegenAccumulator = self.staminaRegenAccumulator - self.staminaRegenInterval
            -- Only regain stamina if not at max
            if self.stamina < self.maxStamina then
                self.stamina = self.stamina + 1
            end
        end
    end
end

function CharacterBase:handleAttackEffects(attacker, dt, knockbackMultiplier, attackType)

    
    local damage = self.damageMapping[attackType] or 1  -- default fallback

    if not self.isHurt and not self.isInvincible then
        -- If we are blocking
        if self:checkShieldBlock(attacker) then
            -- Blocking costs stamina (varies by attack)
            local shieldCostMapping = {
                lightAttack = 1,
                heavyAttack = 3
            }
            local blockCost = shieldCostMapping[attackType] or 1

            -- If we have enough stamina to block, we reduce knockback
            -- Otherwise, we don't block effectively (take full damage)
            if self:useStamina(blockCost) then
                -- Partially negate knockback
                knockbackMultiplier = -0.5
                -- No health lost on successful shield block
            else
                -- Not enough stamina to keep blocking => take full damage
                self.health = math.max(0, self.health - damage)
            end
        else
            -- Not shielding => we take damage to health
            self.health = math.max(0, self.health - damage)

            self.isHurt         = true
            self.hurtTimer      = 0.2
            self.isInvincible   = true
            self.invincibleTimer= 0.5
            self.idleTimer      = 0
        end

        -- Reset knockback each time so it doesn't keep shrinking
        self.knockbackSpeed = self.knockbackBase * (knockbackMultiplier or 1)

        -- Overlap-based direction to figure out push
        local overlapLeft  = (attacker.x + attacker.width) - self.x
        local overlapRight = (self.x + self.width) - attacker.x
        self.knockbackDirection = (overlapLeft < overlapRight) and 1 or -1

        -- Immediately apply some knockback
        self.x = self.x - self.knockbackSpeed * self.knockbackDirection * dt
    end
end

----------------------------------------------------------------
-- Counter & Stun
----------------------------------------------------------------
function CharacterBase:triggerSuccessfulCounter(attacker)
    -- Stop defender’s counter state
    self.isCountering = false
    self.counterTimer = 0
    self.counterActive= false

    -- Attacker is stunned
    attacker.isStunned = true
    attacker.stunTimer = 1

    -- Attacker's attack ends
    attacker.isAttacking       = false
    attacker.isHeavyAttacking  = false
    attacker.isLightAttacking  = false
    attacker.isDownAir         = false
end

----------------------------------------------------------------
-- State Updates
----------------------------------------------------------------
function CharacterBase:updateHurtState(dt)
    if self.isHurt then
        self.hurtTimer = self.hurtTimer - dt
        self.canMove   = false
        -- Continue knockback movement
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

    if self.isStunned then
        self.stunTimer = self.stunTimer - dt
        self.canMove   = false
        if self.stunTimer <= 0 then
            self.isStunned = false
            self.canMove   = true
        end
    end
end

return CharacterBase
