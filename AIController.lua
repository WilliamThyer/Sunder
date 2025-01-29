-- AIController.lua
local AIController = {}
AIController.__index = AIController

-- States
local STATE_APPROACH    = "approach"
local STATE_ATTACK      = "attack"
local STATE_RETREAT     = "retreat"
local STATE_DEFEND      = "defend"
local STATE_RECOVER     = "recover"
local STATE_JUMP_ATTACK = "jump_attack"

function AIController:new()
    local ai = {
        currentState      = STATE_APPROACH,
        stateTimer        = 0,    -- how long we've been in the current state
        nextDecisionChange= 1,

        -- Behavior tuning
        aggression        = 1, -- unused
        defense           = 1, -- unused

        -- Stage boundaries (example: 128x72). Adjust as needed.
        stageLeft         = 0,
        stageRight        = 128
    }
    setmetatable(ai, AIController)
    return ai
end

--------------------------------------------------------------------------------
-- MAIN INPUT FUNCTION
--------------------------------------------------------------------------------
function AIController:getInput(dt, player, opponent)
    -- Build an input table with the same shape as your normal joystick logic
    local input = {
        jump        = false,
        lightAttack = false,
        heavyAttack = false,
        attack      = false, -- convenience flag
        dash        = false,
        shield      = false,
        moveX       = 0,
        down        = false,
        counter     = false
    }

    -- If there's no valid opponent or the AI is dead, do nothing
    if not opponent or player.isDead then
        return input
    end

    -- Calculate distances
    local distX    = opponent.x - player.x
    local absDistX = math.abs(distX)
    local distY    = opponent.y - player.y

    local myHealth  = player.health
    local myStamina = player.stamina
    local oppHealth = opponent.health

    -- Update time in the current state
    self.stateTimer = self.stateTimer + dt

    -- Periodically decide if we should switch states
    self.nextDecisionChange = self.nextDecisionChange - dt
    if self.nextDecisionChange <= 0 then
        self:decideState(player, opponent)
        -- Randomize the next interval
        self.nextDecisionChange = 1.0 + math.random()
    end

    -- If stamina is critically low, switch to recover (unless we’re already defending)
    if myStamina <= 2 and self.currentState ~= STATE_DEFEND then
        self.currentState = STATE_RECOVER
    end

    ----------------------------------------------------------------------------
    -- OVERRIDE LOGIC: if opponent stands on AI's head
    ----------------------------------------------------------------------------
    -- If the opponent is basically on top (within 12 px above, 8 px horizontally),
    -- try to jump or move out.
    if distY < 0 and math.abs(distY) < 12 and math.abs(distX) < 8 then
        -- If not already jumping, jump
        if not player.isJumping then
            input.jump = true
        else
            -- Maybe double jump if available
            if player.canDoubleJump and math.random() < 0.5 then
                input.jump = true
            else
                -- Move away horizontally
                input.moveX = (distX > 0) and -1 or 1
            end
        end
        -- Return early since this is a special override
        return input
    end

    ----------------------------------------------------------------------------
    -- STATE-SPECIFIC LOGIC
    ----------------------------------------------------------------------------
    if     self.currentState == STATE_APPROACH    then
        self:runApproachLogic(input, distX, absDistX, player, opponent)
    elseif self.currentState == STATE_ATTACK      then
        self:runAttackLogic(input, player, opponent, distX, distY)
    elseif self.currentState == STATE_DEFEND      then
        self:runDefendLogic(input, player, opponent, absDistX, distY)
    elseif self.currentState == STATE_RETREAT     then
        self:runRetreatLogic(input, distX, absDistX, player, opponent)
    elseif self.currentState == STATE_RECOVER     then
        self:runRecoverLogic(input, player, opponent, distX, absDistX)
    elseif self.currentState == STATE_JUMP_ATTACK then
        self:runJumpAttackLogic(input, distX, distY, player, opponent)
    end

    return input
end

--------------------------------------------------------------------------------
-- DECIDE STATE: Called periodically to see if we should switch states
--------------------------------------------------------------------------------
function AIController:decideState(player, opponent)
    local distX      = opponent.x - player.x
    local absDistX   = math.abs(distX)
    local myHealth   = player.health
    local myStamina  = player.stamina
    local oppHealth  = opponent.health

    local newState = self.currentState

    -- If we’re dangerously low on health, be more defensive, but not always cornered
    if myHealth <= 2 then
        if absDistX < 20 and math.random() < 0.5 then
            newState = STATE_DEFEND
        else
            newState = STATE_ATTACK
        end
    end

    -- If we have good health & stamina, be aggressive
    if myHealth > 2 and myStamina >= 3 then
        if absDistX > math.random(10,25) then
            newState = STATE_APPROACH
        else
            if math.random() < 0.5 then
                newState = STATE_ATTACK
            else
                newState = STATE_JUMP_ATTACK
            end
        end
    end

    if newState ~= self.currentState then
        self.currentState = newState
        self.stateTimer   = 0
    end
end

--------------------------------------------------------------------------------
-- APPROACH: Move toward the opponent
--------------------------------------------------------------------------------
function AIController:runApproachLogic(input, distX, absDistX, player, opponent)
    local myStamina = player.stamina

    -- Move closer
    input.moveX = (distX > 0) and 1 or -1
    if math.random() < 0.2 then
        input.jump = true
    end

    -- Possibly dash if far enough away and have stamina
    if absDistX > 40 and myStamina > 3 then
        local num = math.random()
        if num < 0.5 then
            input.dash = true
        elseif num > 0.7 then
            input.jump = true
        end
    end

    -- If in close range, attempt an attack
    if absDistX < 12 then
        local num = math.random()
        if num > 0.7 and myStamina >= 1 then
            input.lightAttack = true
            input.attack      = true
        elseif num > 0.7 and myStamina >= 2 then
            input.heavyAttack = true
            input.attack      = true
        elseif num > 0.5 then
            input.shield = true
        elseif num < 0.5 then
            input.counter = true
        end
    end
end

--------------------------------------------------------------------------------
-- ATTACK: Aggressive posture
--------------------------------------------------------------------------------
function AIController:runAttackLogic(input, player, opponent, distX, distY)
    local myStamina = player.stamina
    local absDistX = math.abs(distX)

    -- Move in if not close enough
    if absDistX > 8 then
        input.moveX = (opponent.x > player.x) and 1 or -1
    end

    -- If very close, attempt a variety of attacks
    if absDistX < 10 then
        local r = math.random()
        if r < 0.4 and myStamina >= 1 then
            input.lightAttack = true
            input.attack      = true
        elseif r < 0.7 and myStamina >= 2 then
            input.heavyAttack = true
            input.attack      = true
        else
            -- Maybe shield briefly
            input.shield = true
            -- Face the opponent while shielding
            if distX > 0 then
                input.moveX =  0.1
            else
                input.moveX = -0.1
            end
        end
    end

    -- Small chance to jump to throw off the opponent
    if math.random() < 0.2 and player.canDoubleJump then
        input.jump = true
    end

    -- If in the air and the opponent is below, do a down-air
    if player.isJumping and distY > 0 and math.random() < 0.1 then
        input.down   = true
        input.attack = true
    end
end

--------------------------------------------------------------------------------
-- DEFEND: Low health or expect an incoming attack
--------------------------------------------------------------------------------
function AIController:runDefendLogic(input, player, opponent, distX, distY)
    local myStamina = player.stamina
    local absDistX = math.abs(distX)

    -- If the opponent is close, shield or attempt a counter
    if absDistX < 10 then
        -- Shield if we have stamina
        if myStamina > 0 then
            input.shield = true
            -- Face the opponent
            if opponent.x > player.x then
                input.moveX =  0.1
            else
                input.moveX = -0.1
            end
        end

        -- Occasionally attempt a counter
        if math.random() < 0.2 and not player.isJumping then
            input.counter = true
        end

        -- Possibly move away
        if math.random() < 0.3 then
            input.moveX = (distX > 0) and -1 or 1
        end
    else
        -- If the opponent is far, we can relax or move slightly
        if math.random() < 0.2 then
            input.moveX = (distX > 0) and 1 or -1
        end
    end
end

--------------------------------------------------------------------------------
-- RECOVER: Low stamina, do minimal to regain
--------------------------------------------------------------------------------
function AIController:runRecoverLogic(input, player, opponent, distX, absDistX)
    -- Keep some distance so stamina can recover
    if absDistX < 25 then
        input.moveX = (distX > 0) and -1 or 1
    end

    -- Possibly shield if the opponent is closing in
    if absDistX < 15 then
        input.shield = true
        -- Face the opponent
        if distX > 0 then
            input.moveX =  0.1
        else
            input.moveX = -0.1
        end
    end
end

--------------------------------------------------------------------------------
-- JUMP ATTACK: Specifically for leaping attacks
--------------------------------------------------------------------------------
function AIController:runJumpAttackLogic(input, distX, distY, player, opponent)
    local absDistX   = math.abs(distX)
    local myStamina  = player.stamina

    -- If not currently jumping, jump if in range
    if player.canDoubleJump and absDistX < 30 then
        input.jump = true
    end

    -- Once in the air, move horizontally toward the opponent
    if player.isJumping then
        input.moveX = (distX > 0) and 1 or -1

        -- If above them, do a down-air
        local r = math.random()
        if distY > 0 and r < 0.2 then
            input.down   = true
            input.attack = true
        elseif r > 0.7 then
            input.lightAttack = true
        else
            input.heavyAttack = true
        end
    else
        -- If we're not in the air (couldn't jump), fallback to approach or basic attack
        if absDistX > 15 then
            input.moveX = (distX > 0) and 1 or -1
        else
            -- Attack if close
            if math.random() < 0.5 and myStamina >= 1 then
                input.lightAttack = true
                input.attack      = true
            elseif myStamina >= 2 then
                input.heavyAttack = true
                input.attack      = true
            end
        end
    end
end

return AIController
