-- Mage.lua
local CharacterBase = require("CharacterBase")
local Missile = require("Missile")
local anim8 = require("libraries.anim8")

local Mage = {}
Mage.__index = Mage 
setmetatable(Mage, { __index = CharacterBase })

function Mage:new(x, y, joystickIndex, world, aiController, colorName)
    -- Call the base constructor:
    local instance = CharacterBase.new(self, x, y)
    setmetatable(instance, Mage)

    instance.index    = joystickIndex
    instance.joystick = love.joystick.getJoysticks()[joystickIndex]
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
    instance.dashDuration = 0.4
    instance.canDash      = true
    instance.dashSpeed    = 140

    -- DASH-TELEPORT STATE
    instance.dashPhase         = nil                  -- "start" or "end" (nil = no dash in progress)
    instance.dashDistance      = instance.dashSpeed * instance.dashDuration
    instance.dashStartDuration = 3 * 0.06             -- 3 frames × 0.05s/frame (match your dashStart anim)
    instance.dashEndDuration   = 3 * 0.06             -- same for dashEnd anim
    instance.dashStartTimer    = 0
    instance.dashEndTimer      = 0

    instance.jumpHeight    = -130

    instance.landingLag       = 0.15

    instance.heavyAttackDuration      = 0.85
    instance.heavyAttackNoDamageDuration = 0.7
    instance.heavyAttackWidth        = 6
    instance.heavyAttackHeight       = 8
    instance.heavyAttackHitboxOffset = 0.5
    instance.isUnblockableHeavy = true

    instance.lightAttackDuration      = 0.35
    instance.lightAttackNoDamageDuration = 0.175
    instance.lightAttackWidth        = 4
    instance.lightAttackHeight       = 8
    instance.lightAttackHitboxOffset = 0.5

    instance.downAirDuration          = 1
    instance.downAirTimer             = 0

    instance.chargeLaunched = false

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

    -- Missile & spawn‐flag
    instance.missiles        = {}
    instance.hasSpawnedMissile = false

    -- Mark as a player-controlled fighter (if needed)
    instance.isPlayer = true

    -- flight fields
    instance.isFlying            = false
    instance.flySpeed            = 60          -- pixels per second upward
    instance.flyStaminaDrainRate = 2           -- stamina per second

    return instance
end

--------------------------------------------------
-- Fighter–Specific (Mage) Methods
--------------------------------------------------
function Mage:initializeAnimations()
    local file = "assets/sprites/Mage" .. self.colorName .. ".png"
    if not love.filesystem.getInfo(file) then
        file = "assets/sprites/MageBlue.png"  -- fallback to default sprite
    end
    -- Load the sprite sheet and create grids for animations:
    self.spriteSheet = love.graphics.newImage(file)
    self.grid = anim8.newGrid(12, 12, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), 0, 0, 1)

    local num_small_cols = 6
    local col_width = 13
    self.attackGrid = anim8.newGrid(18, 18, self.spriteSheet:getWidth(), self.spriteSheet:getHeight(), (num_small_cols * col_width) + 1, 0, 1)

    self.animations = {
        move         = anim8.newAnimation(self.grid(1, '1-3'), 0.125),
        jump         = anim8.newAnimation(self.grid(1, '4-6'), .05),
        land         = anim8.newAnimation(self.grid(4, 2), 1),
        idle         = anim8.newAnimation(self.grid(4, '1-4'), 0.5),
        dashStart    = anim8.newAnimation(self.grid(3, '1-3'), 0.075),
        dashEnd      = anim8.newAnimation(self.grid(3, '3-1'), 0.075),
        heavyAttack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.1, 0.3, 0.3, 0.05}),
        lightAttack  = anim8.newAnimation(self.attackGrid(2, '1-3'), {0.2, 0.15, .05}),
        downAir      = anim8.newAnimation(self.attackGrid(3, '1-2'), {0.2, 0.8}),
        shield       = anim8.newAnimation(self.grid(2, '1-3'), .1),
        shieldBlock  = anim8.newAnimation(self.grid(2, 4), 1),
        hurt         = anim8.newAnimation(self.grid(5, 1), 1),
        counter      = anim8.newAnimation(self.grid(2, '5-6'), 0.1),
        die          = anim8.newAnimation(self.grid(6, 1), 0.5)
    }
    self.currentAnim = self.animations.idle

end

function Mage:initializeSoundEffects()
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

function Mage:draw()
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
        if self.direction == 1 then
            offsetX = offsetX - 1 * CHARACTER_SCALE
        else
            offsetX = offsetX + 1 * CHARACTER_SCALE
        end
    end

    local th = self.grid.frameHeight
    if self.currentAnim and self.spriteSheet then
        self.currentAnim:draw(self.spriteSheet, self.x + offsetX, self.y + offsetY, 0, scaleX, scaleY, 0, 2)
    end

    for _, fb in ipairs(self.missiles) do
        fb:draw()
    end

    self:drawUI()
end

function Mage:processInput(dt, input, otherPlayer)
    self.isIdle = true

    ----------------------------------------------------------------
    -- 1) Dash‐teleport phases
    ----------------------------------------------------------------
    if self.dashPhase == "start" then
        self.dashStartTimer = self.dashStartTimer - dt
        if self.dashStartTimer <= 0 then
            -- teleport through players but still collide with walls
            local goalX = self.x + (self.direction * self.dashDistance)
            local defaultFilter = function(item, other)
                return self:collisionFilter(item, other)
            end
            local phaseFilter = function(item, other)
                if other.isPlayer then return "cross" end
                return defaultFilter(item, other)
            end
            local actualX, actualY = self.world:move(self, goalX, self.y, phaseFilter)
            self.x, self.y = actualX, actualY

            -- begin portal‐out
            self.dashPhase    = "end"
            self.dashEndTimer = self.dashEndDuration
            self.currentAnim  = self.animations.dashEnd
        end

        -- **lock movement for the entire start phase**
        self.isMoving = false
        self.canMove  = false
        return

    elseif self.dashPhase == "end" then
        self.dashEndTimer = self.dashEndTimer - dt
        if self.dashEndTimer <= 0 then
            -- dash is fully over: restore both dash and move ability
            self.dashPhase = nil
            self.canDash   = true
            self.canMove   = true
        end

        -- **also lock movement during the end phase** 
        self.isMoving = false
        return
    end

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
            self.hasSpawnedMissile = false
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
            self.hasSpawnedMissile = false
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

    -- Flight logic: hold jump to rise (if you have stamina), release to fall
    local nowFlying = (input.jump and self.stamina > 0)
    self.isFlying = nowFlying

    -- If we just dropped out of hover, clear any accumulated fall velocity:
    if self.wasFlying and not self.isFlying then
        self.jumpVelocity = 0
        -- ensure we're in "falling" state so gravity kicks in
        self.isJumping   = true
    end
    self.wasFlying = self.isFlying

    -- Dash
    if input.dash and self:canPerformAction("dash") then
        if self:useStamina(self.staminaMapping.dash or 1) then
            -- portal‐in
            self.soundEffects['dash']:play()
            self.dashPhase         = "start"
            self.dashStartTimer    = self.dashStartDuration
            self.currentAnim       = self.animations.dashStart
            self.currentAnim:gotoFrame(1)
            self.canDash           = false
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
        if self.idleTimer < .3 then
            if self.animations and self.animations.idle then
                self.animations.idle:gotoFrame(1)
            end
        end
    else
        self.idleTimer = 0
    end
end

-- keep a reference to the base bump–move
local baseMoveWithBump = CharacterBase.moveWithBump

function Mage:moveWithBump(dt)
    if self.isFlying then
        -- drain stamina
        self.stamina = math.max(0, self.stamina - self.flyStaminaDrainRate * dt)

        -- compute goal pos: up + any left/right input
        local goalX = self.x
        if self.isMoving and self.canMove then
            goalX = goalX + (self.direction * self.speed * dt)
        end
        local goalY = self.y - (self.flySpeed * dt) 

        -- do the bump move
        local actualX, actualY, cols, len =
          self.world:move(self, goalX, goalY, self.collisionFilter)
        self.x, self.y = actualX, actualY

        -- if you ran out of stamina, stop flying this frame
        if self.stamina <= 0 then
            self.isFlying = false
        end
    else
        -- normal gravity/jump+fall behavior
        baseMoveWithBump(self, dt)
    end
end

function Mage:handleAttacks(dt, otherPlayer)
    if not otherPlayer then return end

       --------------------------------------------------
    -- 1) spawn missile once per heavy attack
    --------------------------------------------------
    if    self.isHeavyAttacking
      and not self.hasSpawnedMissile
      and (self.heavyAttackTimer <= self.heavyAttackDuration - self.heavyAttackNoDamageDuration)
    then
        -- spawn right in front of the mage:
        local spawnX = (self.direction == 1)
                       and (self.x + 10)
                       or (self.x - 10)
        local spawnY = self.y + (self.height * 0.5) - 9

        local fb = Missile:new(
            spawnX,
            spawnY,
            self.direction,
            self.damageMapping["heavyAttack"],
            self.colorName
        )
        table.insert(self.missiles, fb)
        self.hasSpawnedMissile = true
    end

    --------------------------------------------------
    --- 2) Melee attacks 
    --------------------------------------------------

    if self.isLightAttacking and not self.hasHitLight and
       (self.lightAttackTimer <= self.lightAttackDuration - self.lightAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "lightAttack") then
            otherPlayer:handleAttackEffects(self, dt, 0.5, "lightAttack")
            self.hasHitLight = true
        end
    end

    --------------------------------------------------
    -- 3) update & collide all missiles 
    --------------------------------------------------
    for i = #self.missiles,1,-1 do
        local fb = self.missiles[i]
        fb:update(dt)

        -- Check if the missile hits the other player
        if fb.active then
            local hitResult = fb:checkHit(otherPlayer)
            if hitResult == "countered" then
                -- Missile was countered - heal the player
                otherPlayer:heal(1)
                -- Remove the countered missile
                fb.active = false
            elseif hitResult == "hit" then
                -- Normal hit - apply damage
                otherPlayer:handleAttackEffects(self, dt, 1, "heavyAttack")
                fb.active = false
            end
        end

        if not fb.active then
            table.remove(self.missiles, i)
        end
    end

end

-- Save a reference to the base implementation:
local base_updateAnimation = CharacterBase.updateAnimation

-- Override updateAnimation so our portal anims actually play
function Mage:updateAnimation(dt)
    -- 1) dash‐teleport anims
    if self.dashPhase == "start" then
        self.currentAnim = self.animations.dashStart
        self.currentAnim:update(dt)
        return
    elseif self.dashPhase == "end" then
        self.currentAnim = self.animations.dashEnd
        self.currentAnim:update(dt)
        return
    end

    -- 2) hovering: always show the jump animation
    if self.isFlying then
        self.currentAnim = self.animations.jump
        self.currentAnim:update(dt)
        return
    end

    -- 3) falling: show idle animation instead of jump
    if self.isJumping then
        self.currentAnim = self.animations.idle
        self.currentAnim:update(dt)
        return
    end

    -- 4) everything else uses the base character logic
    base_updateAnimation(self, dt)
end

function Mage:canPerformAction(action)
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

return Mage
