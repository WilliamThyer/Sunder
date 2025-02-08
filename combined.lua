--- CharacterBase.lua ---

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
    instance.speed     = 30
    instance.gravity   = 400

    instance.jumpHeight    = -120
    instance.jumpVelocity  = 0
    instance.isJumping     = false
    instance.canDoubleJump = false

    -- Attack states
    instance.isAttacking              = false
    instance.isHeavyAttacking         = false
    instance.heavyAttackTimer         = 0
    instance.heavyAttackDuration      = 0.5
    instance.heavyAttackNoDamageDuration = 0.35

    instance.isLightAttacking         = false
    instance.lightAttackTimer         = 0
    instance.lightAttackDuration      = 0.4
    instance.lightAttackNoDamageDuration = 0.175

    instance.isDownAir                = false
    instance.downAirDuration          = 1
    instance.downAirTimer             = 0

    instance.damageMapping = {
        lightAttack = 1,
        heavyAttack = 3,
        downAir     = 2
    }
    instance.staminaMapping = {
        lightAttack = 2,
        heavyAttack = 4,
        downAir     = 2,
        dash        = 1
    }

    -- Dash
    instance.isDashing    = false
    instance.dashTimer    = 0
    instance.dashDuration = 0.25
    instance.canDash      = true
    instance.dashSpeed    = 125
    instance.dashVelocity = 0

    -- Shield
    instance.isShielding = false

    -- Hurt / Knockback
    instance.isHurt             = false
    instance.hurtTimer          = 0
    instance.isInvincible       = false
    instance.invincibleTimer    = 0
    instance.knockbackBase      = instance.speed * 1.5
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
    instance.counterActiveWindow = 0.15
    instance.counterActive   = false

    -- Health & Stamina
    instance.health          = 10
    instance.maxHealth       = 10
    instance.stamina         = 10
    instance.maxStamina      = 10
    instance.timeSinceStaminaUse     = 0
    instance.staminaRegenDelay       = 0.75
    instance.staminaRegenAccumulator = 0
    instance.staminaRegenInterval    = 0.3

    -- Death
    instance.timeToDeath = 0.15
    instance.isDead = false
    instance.isDying = false
    instance.isDyingTimer = 0

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
        return {
            width  = self.width * 0.8,
            height = self.height * 0.5,
            x      = self.x + (self.width - self.width * 0.8) / 2,
            y      = self.y + self.height
        }
    elseif attackType == "heavyAttack" or attackType == "lightAttack" then
        local hitWidth = 4
        return {
            width  = hitWidth,
            height = self.height,
            x      = (self.direction == 1) and (self.x + self.width) or (self.x - hitWidth),
            y      = self.y
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

function CharacterBase:checkHit(other, attackType)
    local hitbox = self:getHitbox(attackType)
    local hurtbox = {
        width  = 8,
        height = 8,
        x      = other.x + (other.width - 8) / 2,
        y      = other.y + (other.height - 8) / 2
    }
    local hit = hitbox.x < hurtbox.x + hurtbox.width and
                hitbox.x + hitbox.width > hurtbox.x and
                hitbox.y < hurtbox.y + hurtbox.height and
                hitbox.y + hitbox.height > hurtbox.y
    -- Counter window check:
    if hit and other.isCountering and other.counterActive then
        other:triggerSuccessfulCounter(self)
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
        lightAttack = 1,
        heavyAttack = 3
    }
    local blockCost = shieldCostMapping[attackType] or 1

    if not self.isHurt and not self.isInvincible then
        if self:checkShieldBlock(attacker) and self:useStamina(blockCost) then
            self.soundEffects['shieldHit']:play()
            self.isShieldKnockback = true
            self.shieldKnockTimer  = self.shieldKnockDuration
            self.shieldKnockDir    = self:getKnockbackDirection(attacker)
            self.shieldKnockSpeed  = self.shieldKnockBase * (knockbackMultiplier or 1)
        else
            self.soundEffects['hitHurt']:play()
            self.health = math.max(0, self.health - damage)
            self.isHurt         = true
            self.hurtTimer      = 0.2
            self.isInvincible   = true
            self.invincibleTimer= 0.5

            self.knockbackSpeed     = self.knockbackBase * (knockbackMultiplier or 1)
            self.knockbackDirection = self:getKnockbackDirection(attacker)
            self.x = self.x - self.knockbackSpeed * self.knockbackDirection * dt
        end
    end
end

function CharacterBase:triggerSuccessfulCounter(attacker)
    self.soundEffects['successfulCounter']:play()
    self.isCountering = false
    self.counterTimer = 0
    self.counterActive = false

    attacker.isStunned = true
    attacker.stunTimer = 1

    attacker.isAttacking      = false
    attacker.isHeavyAttacking = false
    attacker.isLightAttacking = false
    attacker.isDownAir        = false
end

--------------------------------------------------
-- Hurt/Death State Update (Generic)
--------------------------------------------------
function CharacterBase:updateHurtState(dt)
    if self.health == 0 and not self.isDying and not self.isDead then
        self.isHurt = false
        self.isDying = true
        self.isDyingTimer = self.timeToDeath
        self.canMove = false
        self.soundEffects['die']:play()
    elseif self.isDying then
        self.isDyingTimer = self.isDyingTimer - dt
        if self.isDyingTimer <= 0 then
            self.isDead = true
            self.isDying = false
        end
    elseif self.isDead then
        self.canMove = false
        self.y = -10
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
-- Generic “Infrastructure” Methods
--------------------------------------------------
function CharacterBase:collisionFilter(item, other)
    if other and other.isPlayer then
        return "slide"
    end
    return "slide"
end

function CharacterBase:initializeUIAnimations()
    self.iconSpriteSheet = love.graphics.newImage("assets/sprites/icons.png")
    self.iconSprites = {
        heart        = love.graphics.newQuad(1, 1, 8, 8, self.iconSpriteSheet),
        emptyHeart   = love.graphics.newQuad(10, 1, 8, 8, self.iconSpriteSheet),
        stamina      = love.graphics.newQuad(1, 10, 8, 8, self.iconSpriteSheet),
        emptyStamina = love.graphics.newQuad(10, 10, 8, 8, self.iconSpriteSheet)
    }
    if self.index == 1 then
        self.iconXPos = 2
    else
        self.iconXPos = 128 - (5 * self.maxHealth) - 10
    end
    self.healthYPos  = 72 - 6
    self.staminaYPos = 72 - 11
end

function CharacterBase:moveWithBump(dt)
    local goalX = self.x
    local goalY = self.y
    local tinyDown = 0

    if self.isDashing then
        goalX = self.x + (self.dashVelocity * dt)
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
    if not self:useStamina(self.staminaMapping['downAir']) then return end
    self.soundEffects['downAir']:play()
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
end

function CharacterBase:resetGravity()
    self.gravity = 400
end

function CharacterBase:triggerCounter()
    self.soundEffects['counter']:play()
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

function CharacterBase:updateAnimation(dt)
    if self.isDying or self.isDead then
        self.currentAnim = self.animations.die
    elseif self.isHurt or self.isStunned then
        self.currentAnim = self.animations.hurt
    elseif self.isShieldKnockback then
        self.currentAnim = self.animations.shieldBlock
    elseif self.isShielding then
        self.currentAnim = self.animations.shield
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
        local icon = (self.stamina > s) and 'stamina' or 'emptyStamina'
        local xPos = self.iconXPos + 6 * s
        self:drawIcon(xPos, self.staminaYPos, icon)
    end
end

function CharacterBase:drawIcon(x, y, iconName)
    local UI_SCALE = 1
    love.graphics.draw(self.iconSpriteSheet, self.iconSprites[iconName], x, y, 0, UI_SCALE, UI_SCALE)
end

return CharacterBase


--- Player.lua ---

-- Player.lua
local Warrior = require("Warrior")
local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Warrior })

function Player:new(x, y, joystickIndex, world, aiController)
    local instance = Warrior.new(self, x, y, joystickIndex, world, aiController)
    setmetatable(instance, Player)
    return instance
end

function Player:update(dt, otherPlayer)
    local input = self:getPlayerInput(dt, otherPlayer)
    self:processInput(dt, input)
    self:moveWithBump(dt)        -- <--- Bump-based environment collision
    self:handleAttacks(dt, otherPlayer)
    self:handleDownAir(dt, otherPlayer)
    self:updateHurtState(dt)
    self:updateCounter(dt)
    self:updateStamina(dt)
    self:updateAnimation(dt)
end

function Player:getPlayerInput(dt, otherPlayer)
    if self.aiController then
        return self.aiController:getInput(dt, self, otherPlayer)
    end
    if not self.joystick then
        return {
            heavyAttack = false,
            lightAttack = false,
            jump        = false,
            dash        = false,
            shield      = false,
            moveX       = 0,
            down        = false,
            counter     = false,
            attack      = false,
        }
    end
    return {
        jump        = self.joystick:isGamepadDown("x"),
        lightAttack = self.joystick:isGamepadDown("a"),
        heavyAttack = self.joystick:isGamepadDown("b"),
        attack      = (self.joystick:isGamepadDown("a") or self.joystick:isGamepadDown("b")),
        dash        = self.joystick:isGamepadDown("rightshoulder"),
        shield      = self.joystick:isGamepadDown("leftshoulder"),
        moveX       = self.joystick:getGamepadAxis("leftx") or 0,
        down        = (self.joystick:getGamepadAxis("lefty") or 0) > 0.5,
        counter     = self.joystick:isGamepadDown("y")
    }
end

return Player


--- Warrior.lua ---

-- Warrior.lua
local CharacterBase = require("CharacterBase")
local anim8 = require("libraries.anim8")

local Warrior = {}
Warrior.__index = Warrior
setmetatable(Warrior, { __index = CharacterBase })

function Warrior:new(x, y, joystickIndex, world, aiController)
    -- Call the base constructor:
    local instance = CharacterBase.new(self, x, y)
    setmetatable(instance, Warrior)
    
    instance.index    = joystickIndex
    instance.joystick = love.joystick.getJoysticks()[joystickIndex]
    instance.world    = world
    instance.aiController = aiController

    instance.hasHitHeavy   = false
    instance.hasHitLight   = false
    instance.hasHitDownAir = false

    instance.attackPressedLastFrame  = false
    instance.JumpPressedLastFrame    = false
    instance.dashPressedLastFrame    = false
    instance.counterPressedLastFrame = false
    instance.shieldHeld              = false

    instance:initializeAnimations()
    instance:initializeSoundEffects()
    instance:initializeUIAnimations()  -- from CharacterBase

    -- Mark as a player-controlled fighter (if needed)
    instance.isPlayer = true

    return instance
end

--------------------------------------------------
-- Fighter–Specific (Warrior) Methods
--------------------------------------------------
function Warrior:initializeAnimations()
    self.spriteSheet = love.graphics.newImage("assets/sprites/hero.png")
    self.grid = anim8.newGrid(8, 8, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 0, 0, 1)

    local num_small_cols = 6
    local col_width = 9
    self.attackGrid = anim8.newGrid(12, 12, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), (num_small_cols * col_width) + 2, 0, 1)

    self.animations = {
        move         = anim8.newAnimation(self.grid(1, '1-2'), 0.2),
        jump         = anim8.newAnimation(self.grid(1, 4), 1),
        idle         = anim8.newAnimation(self.grid(4, '1-2'), 0.7),
        dash         = anim8.newAnimation(self.grid(3, 1), 0.2),
        heavyAttack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.1, 0.25, 0.05, 0.1}),
        lightAttack  = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.175, 0.325}),
        downAir      = anim8.newAnimation(self.attackGrid(3, '1-2'), {0.2, 0.8}),
        shield       = anim8.newAnimation(self.grid(2, 1), 1),
        shieldBlock  = anim8.newAnimation(self.grid(2, 2), 1),
        hurt         = anim8.newAnimation(self.grid(5, 1), 1),
        counter      = anim8.newAnimation(self.grid(2, 4), 0.5),
        die          = anim8.newAnimation(self.grid(6, 1), 0.5)
    }
    self.currentAnim = self.animations.idle
end

function Warrior:initializeSoundEffects()
    self.soundEffects = {
        counter             = love.audio.newSource("assets/soundEffects/counter.wav", "static"),
        dash                = love.audio.newSource("assets/soundEffects/dash.wav", "static"),
        die                 = love.audio.newSource("assets/soundEffects/die.wav", "static"),
        downAir             = love.audio.newSource("assets/soundEffects/downAir.wav", "static"),
        heavyAttack         = love.audio.newSource("assets/soundEffects/heavyAttack.wav", "static"),
        heavyAttackCharge   = love.audio.newSource("assets/soundEffects/heavyAttackCharge.wav", "static"),
        lightAttack         = love.audio.newSource("assets/soundEffects/lightAttack.wav", "static"),
        hitHurt             = love.audio.newSource("assets/soundEffects/hitHurt.wav", "static"),
        jump                = love.audio.newSource("assets/soundEffects/jump.wav", "static"),
        shield              = love.audio.newSource("assets/soundEffects/shield.wav", "static"),
        shieldHit           = love.audio.newSource("assets/soundEffects/shieldHit.wav", "static"),
        successfulCounter   = love.audio.newSource("assets/soundEffects/successfulCounter.wav", "static")
    }
end

function Warrior:draw()
    local CHARACTER_SCALE = 1
    local scaleX = CHARACTER_SCALE * self.direction
    local scaleY = CHARACTER_SCALE

    local offsetX = 0
    if self.direction == -1 then
        offsetX = 8 * CHARACTER_SCALE
    end

    local offsetY = 0
    if self.isAttacking and not self.isDownAir then
        offsetY = -3 * CHARACTER_SCALE
    end

    if self.currentAnim and self.spriteSheet then
        self.currentAnim:draw(self.spriteSheet, self.x + offsetX, self.y + offsetY, 0, scaleX, scaleY)
    end

    self:drawUI()
end

function Warrior:processInput(dt, input, otherPlayer)
    self.isIdle = true

    -- Shield
    if input.shield and self:canPerformAction("shield") and self.stamina > 0 then
        if not self.shieldHeld then
            self.soundEffects['shield']:play()
        end
        self.isShielding = true
        self.shieldHeld  = true
    else
        self.isShielding = false
        self.shieldHeld  = false
    end

    -- Counter
    if input.counter and self:canPerformAction("counter") then
        self:triggerCounter()
    end
    self.counterPressedLastFrame = input.counter

    -- Attacks
    if input.down and input.attack and self:canPerformAction("downAir") then
        self:triggerDownAir()
    elseif input.heavyAttack and self:canPerformAction("heavyAttack") then
        if self:useStamina(self.staminaMapping["heavyAttack"]) then
            self.soundEffects['heavyAttack']:play()
            self.isAttacking      = true
            self.isHeavyAttacking = true
            self.heavyAttackTimer = self.heavyAttackDuration
            if self.animations and self.animations.heavyAttack then
                self.animations.heavyAttack:gotoFrame(1)
            end
        end
    elseif input.lightAttack and self:canPerformAction("lightAttack") then
        if self:useStamina(self.staminaMapping["lightAttack"]) then
            self.soundEffects['lightAttack']:play()
            self.isAttacking       = true
            self.isLightAttacking  = true
            self.lightAttackTimer  = self.lightAttackDuration
            if self.animations and self.animations.lightAttack then
                self.animations.lightAttack:gotoFrame(1)
            end
        end
    end
    self.attackPressedLastFrame = input.attack

    if self.isHeavyAttacking then
        self.heavyAttackTimer = self.heavyAttackTimer - dt
        if self.heavyAttackTimer <= 0 then
            self.isAttacking      = false
            self.isHeavyAttacking = false
            self.hasHitHeavy      = false
        end
    end

    if self.isLightAttacking then
        self.lightAttackTimer = self.lightAttackTimer - dt
        if self.lightAttackTimer <= 0 then
            self.isAttacking       = false
            self.isLightAttacking  = false
            self.hasHitLight       = false
        end
    end

    -- Movement
    if self:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
        self.isMoving  = true
        self.direction = (input.moveX > 0) and 1 or -1
    else
        self.isMoving = false
    end

    -- Jump
    if input.jump and self:canPerformAction("jump") then
        if not self.isJumping then
            self.soundEffects['jump']:play()
            self.jumpVelocity   = self.jumpHeight
            self.isJumping      = true
            self.canDoubleJump  = true
            self.canDash        = true
            if self.animations and self.animations.jump then
                self.animations.jump:gotoFrame(1)
            end
        elseif self.canDoubleJump then
            self.soundEffects['jump']:play()
            self.isDownAir     = false
            self:resetGravity()
            self.jumpVelocity  = self.jumpHeight
            self.canDoubleJump = false
            if self.animations and self.animations.jump then
                self.animations.jump:gotoFrame(1)
            end
        end
    end
    self.JumpPressedLastFrame = input.jump

    -- Dash
    if input.dash and self:canPerformAction("dash") then
        if self:useStamina(1) then
            self.soundEffects['dash']:play()
            self.isDashing    = true
            self.dashTimer    = self.dashDuration
            self.dashVelocity = self.dashSpeed * self.direction
            if self.isJumping then
                self.canDash = false
            end
            if self.animations and self.animations.dash then
                self.animations.dash:gotoFrame(1)
            end
        end
    end
    self.dashPressedLastFrame = input.dash

    if self.isDashing then
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then
            if not self.isJumping then
                self.canDash = true
            end
            self.isDashing    = false
            self.dashVelocity = 0
        end
    end

    -- Idle check
    if self:canPerformAction("idle") then
        self.isIdle    = true
        self.idleTimer = self.idleTimer + dt
        if self.idleTimer < 1 then
            if self.animations and self.animations.idle then
                self.animations.idle:gotoFrame(1)
            end
        end
    else
        self.idleTimer = 0
    end
end

function Warrior:handleAttacks(dt, otherPlayer)
    if not otherPlayer then return end

    if self.isHeavyAttacking and not self.hasHitHeavy and
       (self.heavyAttackTimer <= self.heavyAttackDuration - self.heavyAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "heavyAttack") then
            otherPlayer:handleAttackEffects(self, dt, 1, "heavyAttack")
            self.hasHitHeavy = true
        end
    end

    if self.isLightAttacking and not self.hasHitLight and
       (self.lightAttackTimer <= self.lightAttackDuration - self.lightAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "lightAttack") then
            otherPlayer:handleAttackEffects(self, dt, 0.5, "lightAttack")
            self.hasHitLight = true
        end
    end
end

function Warrior:canPerformAction(action)
    local conditions = {
        idle = (
            not self.isMoving and
            not self.isJumping and
            not self.isAttacking and
            not self.isDashing and
            not self.isShielding and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering
        ),
        shield = (
            not self.isJumping and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.isAttacking and
            not self.isDashing
        ),
        heavyAttack = (
            not self.isAttacking and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.attackPressedLastFrame and
            self.stamina >= 2
        ),
        lightAttack = (
            not self.isAttacking and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.attackPressedLastFrame and
            self.stamina >= 1
        ),
        dash = (
            not self.isDashing and
            self.canDash and
            not self.isShielding and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.dashPressedLastFrame and
            self.stamina >= 1
        ),
        move = (
            self.canMove and
            not self.isDashing and
            not self.isShielding and
            not self.isHurt and
            not self.isStunned and
            (not self.isAttacking or self.isJumping) and
            not self.isCountering and
            not self.isDownAir
        ),
        jump = (
            not self.isAttacking and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.JumpPressedLastFrame
        ),
        downAir = (
            self.isJumping and
            not self.isAttacking and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            self.stamina >= 2
        ),
        counter = (
            not self.isAttacking and
            not self.isJumping and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.counterPressedLastFrame
        )
    }
    return conditions[action]
end

return Warrior


