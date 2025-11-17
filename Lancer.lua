-- Lancer.lua
local CharacterBase = require("CharacterBase")
local anim8 = require("libraries.anim8")

local Lancer = {}
Lancer.__index = Lancer 
setmetatable(Lancer, { __index = CharacterBase })

function Lancer:new(x, y, joystickIndex, world, aiController, colorName)
    -- Call the base constructor:
    local instance = CharacterBase.new(self, x, y)
    setmetatable(instance, Lancer)

    instance.characterType = 'Lancer'
    instance.index    = joystickIndex
    instance.world    = world
    instance.aiController = aiController

    instance.colorName        = colorName or "Blue"

    -- Position & Size
    instance.x = x or 0
    instance.y = y or 0
    instance.width = 10
    instance.height = 10
    instance.groundY = instance.y

    instance.speed     = 30
    instance.dashDuration = 0.3
    instance.canDash      = true
    instance.dashSpeed    = 120


    instance.jumpHeight    = -130

    instance.landingLag       = 0.15

    instance.heavyAttackDuration      = 0.65
    instance.heavyAttackNoDamageDuration = 0.5
    instance.heavyAttackWidth        = 6
    instance.heavyAttackHeight       = 8
    instance.heavyAttackHitboxOffset = 0.5
    instance.isUnblockableHeavy = true

    instance.lightAttackWidth        = 4
    instance.lightAttackHeight       = 8
    instance.lightAttackHitboxOffset = 0.5

    instance.downAirDuration          = 1
    instance.downAirTimer             = 0

    instance.chargeLaunched = false
    instance.chargeVelocity = 0
    instance.chargeSpeed = 200  -- Speed of the lunge
    instance.chargeDuration = 0.2  -- How long the lunge lasts
    instance.chargeTimer = 0

    instance.damageMapping = {
        lightAttack = 1,
        heavyAttack = 4,
        downAir     = 2
    }
    instance.staminaMapping = {
        lightAttack = 2,
        heavyAttack = 3,
        downAir     = 1,
        dash        = 1
    }

    instance.hasHitHeavy   = false
    instance.hasHitLight   = false
    instance.hasHitDownAir = false

    instance.attackPressedLastFrame  = false
    instance.JumpPressedLastFrame    = false
    instance.dashPressedLastFrame    = false
    instance.counterPressedLastFrame = false
    instance.shieldHeld              = false

    instance.isLightAttacking         = false
    instance.lightAttackTimer         = 0
    instance.lightAttackDuration      = .35
    instance.lightAttackNoDamageDuration = 0.175

    instance:initializeAnimations()
    instance:initializeSoundEffects()
    instance:initializeUIAnimations()  -- from CharacterBase

    -- Mark as a player-controlled fighter (if needed)
    instance.isPlayer = true

    return instance
end

--------------------------------------------------
-- Fighter–Specific (Lancer) Methods
--------------------------------------------------
function Lancer:initializeAnimations()
    local file = "assets/sprites/Lancer" .. self.colorName .. ".png"
    if not love.filesystem.getInfo(file) then
        file = "assets/sprites/LancerBlue.png"  -- fallback to default sprite
    end
    -- Load the sprite sheet and create grids for animations:
    self.spriteSheet = love.graphics.newImage(file)
    self.grid = anim8.newGrid(12, 12, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 0, 0, 1)

    local num_small_cols = 6
    local col_width = 13
    self.attackGrid = anim8.newGrid(18, 18, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), (num_small_cols * col_width) + 1, 0, 1)

    self.animations = {
        move         = anim8.newAnimation(self.grid(1, '1-2'), 0.125),
        jump         = anim8.newAnimation(self.grid(1, 4), 1),
        land         = anim8.newAnimation(self.grid(4, 2), 1),
        idle         = anim8.newAnimation(self.grid(4, '1-2'), 0.7),
        dash         = anim8.newAnimation(self.grid(3, 1), 0.2),
        heavyAttack  = anim8.newAnimation(self.attackGrid(1, '1-3'), {0.1, 0.4, 0.15}),
        lightAttack  = anim8.newAnimation(self.attackGrid(2, '1-3'), {0.05, 0.2, .1}),
        downAir      = anim8.newAnimation(self.attackGrid(3, '1-2'), {0.2, 0.8}),
        shield       = anim8.newAnimation(self.grid(2, 1), 1),
        shieldBlock  = anim8.newAnimation(self.grid(2, 2), 1),
        hurt         = anim8.newAnimation(self.grid(5, 1), 1),
        counter      = anim8.newAnimation(self.grid(2, 4), 0.5),
        die          = anim8.newAnimation(self.grid(6, 1), 0.5)
    }
    self.currentAnim = self.animations.idle
end

function Lancer:initializeSoundEffects()
    self.soundEffects = {
        counter             = love.audio.newSource("assets/soundEffects/counter.wav", "static"),
        dash                = love.audio.newSource("assets/soundEffects/lancerDash.wav", "static"),
        die                 = love.audio.newSource("assets/soundEffects/die.wav", "static"),
        finalDie            = love.audio.newSource("assets/soundEffects/finalDie.wav", "static"),
        downAir             = love.audio.newSource("assets/soundEffects/downAir.wav", "static"),
        heavyAttack         = love.audio.newSource("assets/soundEffects/heavyAttackFullLancer.wav", "static"),
        lightAttack         = love.audio.newSource("assets/soundEffects/lancerBerserkerLightAttack.wav", "static"),
        hitHurt             = love.audio.newSource("assets/soundEffects/hitHurt.wav", "static"),
        jump                = love.audio.newSource("assets/soundEffects/jump.wav", "static"),
        shield              = love.audio.newSource("assets/soundEffects/shield.wav", "static"),
        shieldHit           = love.audio.newSource("assets/soundEffects/shieldHit.wav", "static"),
        successfulCounter   = love.audio.newSource("assets/soundEffects/successfulCounter.wav", "static")
    }
end

function Lancer:draw()
    local CHARACTER_SCALE = 1
    local scaleX = CHARACTER_SCALE * self.direction
    local scaleY = CHARACTER_SCALE

    local offsetX = 0
    if self.direction == -1 then
        offsetX = 12 * CHARACTER_SCALE
    end

    local offsetY = 0
    if self.isAttacking and not self.isDownAir then
        offsetY = -3 * CHARACTER_SCALE
        offsetX = offsetX -1 * CHARACTER_SCALE
    end

    local th = self.grid.frameHeight
    
    -- Flash sprite on/off during respawn invincibility
    if self.respawnInvincibleTimer > 0 then
        -- Only draw sprite when flash is "on" (respawnFlashAlpha == 1)
        if self.respawnFlashAlpha == 1 and self.currentAnim and self.spriteSheet then
            self.currentAnim:draw(self.spriteSheet, self.x + offsetX, self.y + offsetY, 0, scaleX, scaleY, 0, 2)
        end
    else
        -- Normal drawing when not invincible
        if self.currentAnim and self.spriteSheet then
            self.currentAnim:draw(self.spriteSheet, self.x + offsetX, self.y + offsetY, 0, scaleX, scaleY, 0, 2)
        end
    end

    self:drawUI()
end

function Lancer:processInput(dt, input, otherPlayer)
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
            self:resetChargeFlags()
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
        -- Even if we cannot "move," check if we're shielding so we can flip direction
        -- without actually moving our X position:
        if self.isShielding then
            if math.abs(input.moveX) > 0.5 then
                self.direction = (input.moveX > 0) and 1 or -1
            end
        end
        
        self.isMoving = false
    end

    -- Jump logic
    if input.jump and self:canPerformAction("jump") then
        -- First jump
        if not self.isJumping then
            -- Check if we can pay the stamina cost
            if self:useStamina(1) then
                self.soundEffects['jump']:play()
                self.jumpVelocity   = self.jumpHeight
                self.isJumping      = true
                self.canDoubleJump  = true
                self.canDash        = true
                if self.animations and self.animations.jump then
                    self.animations.jump:gotoFrame(1)
                end
            end
        -- Double jump
        elseif self.canDoubleJump then
            if self:useStamina(1) then
                self.soundEffects['jump']:play()
                self.isDownAir    = false
                self:resetGravity()
                self.jumpVelocity  = self.jumpHeight
                self.canDoubleJump = false
                if self.animations and self.animations.jump then
                    self.animations.jump:gotoFrame(1)
                end
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

function Lancer:resetChargeFlags()
    self.chargeLaunched = false
    self.chargeVelocity = 0
    self.chargeTimer = 0
end

function Lancer:handleAttacks(dt, otherPlayer)
    if not otherPlayer then return end

    -- once "wind-up" has passed, initiate the lunge (only once)
    if self.isHeavyAttacking
       and not self.chargeLaunched
       and (self.heavyAttackTimer <= self.heavyAttackDuration - self.heavyAttackNoDamageDuration)
    then
        self.chargeVelocity = self.chargeSpeed * self.direction
        self.chargeTimer = self.chargeDuration
        self.chargeLaunched = true
    end

    -- Apply charge velocity during the lunge
    if self.chargeLaunched and self.chargeTimer > 0 then
        self.chargeTimer = self.chargeTimer - dt
        if self.chargeTimer <= 0 then
            self.chargeVelocity = 0
        end
    end

    -- **2) your old melee-hit checks** (unchanged)
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
            self.soundEffects['lightAttack']:play()
            otherPlayer:handleAttackEffects(self, dt, 0.5, "lightAttack")
            self.hasHitLight = true
        end
    end

end

function Lancer:canPerformAction(action)
    local conditions = {
        idle = (
            not self.isMoving and
            not self.isJumping and
            not self.isAttacking and
            not self.isDashing and
            not self.isShielding and
            not self.isHurt and
            not self.isStunned and
            not self.isLanding and
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
            not self.isLanding and
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
            not self.isLanding and
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
            not self.isLanding and
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
            not self.isDownAir and
            not self.isLanding
        ),
        jump = (
            not self.isAttacking and
            not self.isShielding and
            not self.isDashing and
            not self.isHurt and
            not self.isStunned and
            not self.isCountering and
            not self.JumpPressedLastFrame and
            not self.isLanding
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
            not self.counterPressedLastFrame and
            not self.isLanding
        )
    }
    return conditions[action]
end

return Lancer
