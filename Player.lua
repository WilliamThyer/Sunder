local CharacterBase = require("CharacterBase")
local anim8         = require("libraries.anim8")

local Player = {}
Player.__index = Player
setmetatable(Player, { __index = CharacterBase })

local CHARACTER_SCALE = 1

function Player:new(x, y, joystickIndex, world, aiController)
    local obj = CharacterBase:new(x, y)
    setmetatable(obj, Player)

    obj.index     = joystickIndex
    obj.joystick  = love.joystick.getJoysticks()[joystickIndex]
    obj.world     = world  -- store reference to the bump world
    obj.aiController = aiController

    obj.hasHitHeavy        = false
    obj.hasHitLight        = false
    obj.hasHitDownAir      = false

    obj.attackPressedLastFrame  = false
    obj.JumpPressedLastFrame    = false
    obj.dashPressedLastFrame    = false
    obj.counterPressedLastFrame = false
    obj.shieldHeld             = false

    obj:initializeAnimations()
    obj:initializeSoundEffects()

    -- Bump collision filter to handle player vs. map and player vs. player
    obj.collisionFilter = function(item, other)
        -- If "other" is a tile or a player, decide if we "slide" or "cross."
        -- Typically you'd check if `other` is a tile -> "slide"
        -- and if it's another player -> "cross". 
        --
        -- Because STI lumps tile collision boxes into objects with .properties,
        -- we can check something like: 
        --    if other.properties and other.properties.collidable then ...
        --
        -- But a simpler approach is: if other is a Player, return "cross",
        -- else "slide".
        if other.isPlayer then
            return "slide"   -- let players overlap for combos, etc.
        end
        return "slide"       -- environment collision is solid
    end

    -- Mark ourselves as a player for quick collision filtering
    obj.isPlayer = true

    return obj
end

function Player:initializeAnimations()
    self.spriteSheet = love.graphics.newImage("assets/sprites/hero.png")

    self.grid = anim8.newGrid(
        8, 8,
        self.spriteSheet:getWidth(),
        self.spriteSheet:getHeight(),
        0, 0, 1
    )

    local num_small_cols = 6
    local col_width = 9
    self.attackGrid = anim8.newGrid(
        12, 12,
        self.spriteSheet:getWidth(),
        self.spriteSheet:getHeight(),
        (num_small_cols*col_width)+2,
        0, 1
    )

    self.animations = {
        move         = anim8.newAnimation(self.grid(1, '1-2'), 0.2),
        jump         = anim8.newAnimation(self.grid(1, 4), 1),
        idle         = anim8.newAnimation(self.grid(4, '1-2'), 0.7),
        dash         = anim8.newAnimation(self.grid(3, 1), .2),
        heavyAttack  = anim8.newAnimation(self.attackGrid(1, '1-4'), {0.1, 0.25, 0.05, 0.1}),
        lightAttack  = anim8.newAnimation(self.attackGrid(2, '1-2'), {0.175, .325}),
        downAir      = anim8.newAnimation(self.attackGrid(3, '1-2'), {0.2, 0.8}),
        shield       = anim8.newAnimation(self.grid(2, 1), 1),
        shieldBlock  = anim8.newAnimation(self.grid(2, 2), 1),
        hurt         = anim8.newAnimation(self.grid(5, 1), 1),
        counter      = anim8.newAnimation(self.grid(2, 4), .5),
        die          = anim8.newAnimation(self.grid(6, 1), .5)
    }

    self.currentAnim = self.animations.idle
    self:initializeUIAnimations()
end

function Player:initializeUIAnimations()
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

function Player:initializeSoundEffects()
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

--------------------------------------------------------------------------
-- Standard update sequence
--------------------------------------------------------------------------
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

--------------------------------------------------------------------------
-- The new function that moves the player using Bump
--------------------------------------------------------------------------
function Player:moveWithBump(dt)
    -- Compute intended (goal) positions
    local goalX = self.x
    local goalY = self.y
    local tinyDown = 0

    -- Horizontal movement (walk or dash)
    if self.isDashing then
        goalX = self.x + (self.dashVelocity * dt)
    elseif self.isMoving and self.canMove then
        local inputX = self.direction -- already set in processInput
        goalX = self.x + (inputX * self.speed * 2 * dt)
    end

    -- Vertical movement (jumping, gravity, downAir, etc.)
    if self.isJumping then
        -- Apply velocity
        goalY = self.y + (self.jumpVelocity * dt)
        -- Update velocity by gravity
        self.jumpVelocity = self.jumpVelocity + (self.gravity * dt)
    else
        -- Check if we're still on solid ground
        tinyDown = 1  -- 1 pixel
        goalY = self.y + tinyDown
    end

    -- Use bump to attempt move:
    local actualX, actualY, cols, len = self.world:move(
        self,         -- item
        goalX,
        goalY,
        self.collisionFilter
    )

    -- Assign final positions
    self.x, self.y = actualX, actualY

    -- We'll see if anything is below us
    local foundFloor = false

    -- 4) Process collisions
    for i=1, len do
        local col = cols[i]
        local nx, ny = col.normal.x, col.normal.y

        if ny < 0 then
            -- Something is below us (tile, or another player)
            foundFloor = true
            if self.isDownAir then
                self:endDownAir()
            elseif self.isJumping then
                self:land()
            end

        elseif ny > 0 then
            -- Something above us => we hit our head
            self.jumpVelocity = 0
        end
    end

    -- 5) If we didn't find a floor, we're in the air
    if not foundFloor then
        -- Only set isJumping = true if we actually want to be in midair
        -- (i.e., we are not on a tile or another player’s head).
        if not self.isJumping then
            self.isJumping = true
        end
    end
end

function Player:draw()
    -- Flip horizontally if direction = -1
    local scaleX = CHARACTER_SCALE * self.direction
    local scaleY = CHARACTER_SCALE

    local offsetX = 0
    if self.direction == -1 then
        offsetX = 8 * CHARACTER_SCALE
    end

    -- Slight offset for attacks
    local offsetY = 0
    if self.isAttacking and not self.isDownAir then
        offsetY = -3 * CHARACTER_SCALE
    end

    self.currentAnim:draw(
        self.spriteSheet,
        self.x + offsetX,
        self.y + offsetY,
        0,
        scaleX,
        scaleY
    )

    self:drawUI()
end

function Player:drawUI()
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

function Player:drawIcon(x, y, iconName)
    local UI_SCALE = 1
    love.graphics.draw(
        self.iconSpriteSheet,
        self.iconSprites[iconName],
        x, y, 0,
        UI_SCALE, UI_SCALE
    )
end

--------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------
function Player:getPlayerInput(dt, otherPlayer)
    -- If we have an AI controller, delegate to AI logic
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

--------------------------------------------------------------------------
-- Process Input
--------------------------------------------------------------------------
function Player:processInput(dt, input)
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
            self.animations.heavyAttack:gotoFrame(1)
        end
    elseif input.lightAttack and self:canPerformAction("lightAttack") then
        if self:useStamina(self.staminaMapping["lightAttack"]) then
            self.soundEffects['lightAttack']:play()
            self.isAttacking       = true
            self.isLightAttacking  = true
            self.lightAttackTimer  = self.lightAttackDuration
            self.animations.lightAttack:gotoFrame(1)
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

    -- Movement (left/right):
    if self:canPerformAction("move") and math.abs(input.moveX) > 0.5 then
        self.isMoving  = true
        -- set direction for flipping the sprite
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
            self.animations.jump:gotoFrame(1)
        elseif self.canDoubleJump then
            self.soundEffects['jump']:play()
            self.isDownAir     = false
            self:resetGravity()
            self.jumpVelocity  = self.jumpHeight
            self.canDoubleJump = false
            self.animations.jump:gotoFrame(1)
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
            self.animations.dash:gotoFrame(1)
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

    -- IDLE check
    if self:canPerformAction("idle") then
        self.isIdle    = true
        self.idleTimer = self.idleTimer + dt
        if self.idleTimer < 1 then
            self.animations.idle:gotoFrame(1)
        end
    else
        self.idleTimer = 0
    end
end

--------------------------------------------------------------------------
-- Attack Handling
--------------------------------------------------------------------------
function Player:handleAttacks(dt, otherPlayer)
    if not otherPlayer then return end

    -- Heavy attack
    if self.isHeavyAttacking and not self.hasHitHeavy
       and (self.heavyAttackTimer <= self.heavyAttackDuration - self.heavyAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "heavyAttack") then
            otherPlayer:handleAttackEffects(self, dt, 1, "heavyAttack")
            self.hasHitHeavy = true
        end
    end

    -- Light attack
    if self.isLightAttacking and not self.hasHitLight
       and (self.lightAttackTimer <= self.lightAttackDuration - self.lightAttackNoDamageDuration)
    then
        if self:checkHit(otherPlayer, "lightAttack") then
            otherPlayer:handleAttackEffects(self, dt, 0.5, "lightAttack")
            self.hasHitLight = true
        end
    end
end

function Player:triggerDownAir()
    if not self:useStamina(self.staminaMapping['downAir']) then
        return
    end
    self.soundEffects['downAir']:play()
    self.isAttacking  = true
    self.isDownAir    = true
    self.downAirTimer = self.downAirDuration
    self.gravity      = self.gravity * 1.2
    self.animations.downAir:gotoFrame(1)
    self.hasHitDownAir = false
end

function Player:handleDownAir(dt, otherPlayer)
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

function Player:endDownAir()
    self.isDownAir     = false
    self.isAttacking   = false
    self.hasHitDownAir = false
    self:land()
end

function Player:resetGravity()
    self.gravity = 400
end

function Player:land()
    self:resetGravity()
    self.isJumping      = false
    self.jumpVelocity   = 0
    self.canDoubleJump  = false
    self.canDash        = true
    self.isDownAir      = false
end

--------------------------------------------------------------------------
-- Counter Logic
--------------------------------------------------------------------------
function Player:triggerCounter()
    self.soundEffects['counter']:play()
    self.isCountering  = true
    self.counterTimer  = self.counterDuration
    self.counterActive = true
end

function Player:updateCounter(dt)
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

--------------------------------------------------------------------------
-- Animation Update
--------------------------------------------------------------------------
function Player:updateAnimation(dt)
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

    self.currentAnim:update(dt)
end

--------------------------------------------------------------------------
-- Action Permissions
--------------------------------------------------------------------------
function Player:canPerformAction(action)
    if self.isShieldKnockback or self.canMove == false then
        return false
    end

    local conditions = {
        idle = (
            not self.isMoving
            and not self.isJumping
            and not self.isAttacking
            and not self.isDashing
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
        ),

        shield = (
            not self.isJumping
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.isAttacking
            and not self.isDashing
        ),

        heavyAttack = (
            not self.isAttacking
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.attackPressedLastFrame
            and self.stamina >= 2
        ),

        lightAttack = (
            not self.isAttacking
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.attackPressedLastFrame
            and self.stamina >= 1
        ),

        dash = (
            not self.isDashing
            and self.canDash
            and not self.isShielding
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.dashPressedLastFrame
            and self.stamina >= 1
        ),

        move = (
            self.canMove
            and not self.isDashing
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and (not self.isAttacking or self.isJumping)
            and not self.isCountering
        ),

        jump = (
            not self.isAttacking
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.JumpPressedLastFrame
        ),

        downAir = (
            self.isJumping
            and not self.isAttacking
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and self.stamina >= 2
        ),

        counter = (
            not self.isAttacking
            and not self.isJumping
            and not self.isShielding
            and not self.isDashing
            and not self.isHurt
            and not self.isStunned
            and not self.isCountering
            and not self.counterPressedLastFrame
        ),
    }

    return conditions[action]
end

return Player
