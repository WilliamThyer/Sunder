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
    instance.isAttacking        = false
    -- Heavy attack
    instance.isHeavyAttacking = false
    instance.heavyAttackTimer        = 0
    instance.heavyAttackDuration     = 0.5
    instance.heavyAttackNoDamageDuration = 0.35
    -- Light attack
    instance.isLightAttacking = false
    instance.lightAttackTimer        = 0
    instance.lightAttackDuration     = .4
    instance.lightAttackNoDamageDuration = 0.175
    -- Downair attack
    instance.isDownAir          = false
    instance.downAirDuration    = 1
    instance.downAirTimer       = 0

    -- Dash
    instance.isDashing   = false
    instance.dashTimer   = 0
    instance.dashDuration= 0.06
    instance.canDash     = true
    instance.dashSpeed   = instance.speed * 750
    instance.dashVelocity= 0

    -- Shield
    instance.isShielding = false

    -- Hurt / Knockback
    instance.isHurt            = false
    instance.hurtTimer         = 0
    instance.isInvincible      = false
    instance.invincibleTimer   = 0
    instance.knockbackBase     = instance.speed * 150
    instance.knockbackSpeed    = 0
    instance.knockbackDirection= 1

    -- Idle / Movement states
    instance.isIdle   = true
    instance.isMoving = false
    instance.idleTimer= 0

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

    -- Shield block
    if other.isShielding and (other.direction ~= self.direction) then
        hit = false
    end
    return hit
end

function CharacterBase:handleAttackEffects(attacker, dt, knockbackMultiplier)
    if not self.isHurt and not self.isInvincible then
        self.isHurt         = true
        self.hurtTimer      = 0.2
        self.isInvincible   = true
        self.invincibleTimer= 0.5
        self.idleTimer      = 0

        -- Reset knockback each time so it doesn't keep shrinking
        self.knockbackSpeed = self.knockbackBase * (knockbackMultiplier or 1)

        -- Overlap-based direction
        local overlapLeft  = (attacker.x + attacker.width) - self.x
        local overlapRight = (self.x + self.width) - attacker.x
        self.knockbackDirection = (overlapLeft < overlapRight) and 1 or -1

        -- Immediately apply some knockback
        self.x = self.x - self.knockbackSpeed * self.knockbackDirection * dt
    end
end

----------------------------------------------------------------
-- Hurt State (knockback, invincibility)
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
end

return CharacterBase
