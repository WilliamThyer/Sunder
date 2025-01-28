-- AIController.lua
local AIController = {}
AIController.__index = AIController

local STATE_APPROACH   = "approach"
local STATE_ATTACK     = "attack"
local STATE_RETREAT    = "retreat"
local STATE_DEFEND     = "defend"
local STATE_RECOVER    = "recover"
local STATE_JUMP_ATTACK= "jump_attack"

function AIController:new()
    local ai = {
        currentState    = STATE_APPROACH,
        stateTimer      = 0,   -- how long we've been in the current state
        decisionTimer   = 1.5, -- the AI re-checks conditions every 1.5s by default

        -- For more human-like behavior, we'll keep track of “urgency” or “aggression”
        aggression      = 2,   -- can scale from 0 (very passive) to ~2 (very aggressive)
        defense         = 1,   -- can scale from 0..2 as well

        -- We can store random intervals to re-check or forcibly break from states
        nextDecisionChange = 1.5,
    }
    setmetatable(ai, AIController)
    return ai
end

--------------------------------------------------------------------------------
-- Main AI function
--------------------------------------------------------------------------------
function AIController:getInput(dt, player, opponent)
    -- Return a table shaped like your normal joystick input
    local input = {
        jump        = false,
        lightAttack = false,
        heavyAttack = false,
        attack      = false,
        dash        = false,
        shield      = false,
        moveX       = 0,
        down        = false,
        counter     = false
    }

    -- If there's no valid opponent or if the AI is dead, do nothing
    if not opponent or player.isDead then
        return input
    end

    -- The distance between AI and opponent
    local distX = opponent.x - player.x
    local absDistX = math.abs(distX)
    local distY = opponent.y - player.y

    -- The AI’s own health/stamina
    local myHealth  = player.health
    local myStamina = player.stamina
    local maxStamina= player.maxStamina

    -- Opponent’s health/stamina (could be used to make strategic calls)
    local oppHealth  = opponent.health
    local oppStamina = opponent.stamina

    -- Update how long we've been in the current state
    self.stateTimer = self.stateTimer + dt

    -- Periodically re-check if we should switch states
    self.nextDecisionChange = self.nextDecisionChange - dt
    if self.nextDecisionChange <= 0 then
        self:decideState(player, opponent)
        -- Randomize next state check a bit for unpredictability
        self.nextDecisionChange = 1.0 + math.random() * 1.0
    end

    -- If stamina is extremely low, switch to recover, unless we are in trouble
    if myStamina <= 2 and not (self.currentState == STATE_DEFEND) then
        self.currentState = STATE_RECOVER
    end

    -- Execute logic based on currentState
    if self.currentState == STATE_APPROACH then
        self:runApproachLogic(input, distX, absDistX, player, opponent)
    elseif self.currentState == STATE_ATTACK then
        self:runAttackLogic(input, player, opponent, absDistX, distY)
    elseif self.currentState == STATE_DEFEND then
        self:runDefendLogic(input, player, opponent, absDistX)
    elseif self.currentState == STATE_RETREAT then
        self:runRetreatLogic(input, distX, absDistX, player)
    elseif self.currentState == STATE_RECOVER then
        self:runRecoverLogic(input, player, opponent, distX, absDistX)
    elseif self.currentState == STATE_JUMP_ATTACK then
        self:runJumpAttackLogic(input, distX, distY, player, opponent)
    end

    return input
end

--------------------------------------------------------------------------------
-- State Decision
-- Called periodically to see if we should switch states.
--------------------------------------------------------------------------------
function AIController:decideState(player, opponent)
    local distX = opponent.x - player.x
    local absDistX = math.abs(distX)

    local myHealth  = player.health
    local myStamina = player.stamina
    local oppHealth = opponent.health

    local newState = self.currentState

    -- If we’re dangerously low on health, maybe be more defensive
    if myHealth < 3 then
        -- 50% chance to defend if we are too close or if random triggers
        if absDistX < 20 and math.random() < 0.5 then
            newState = STATE_DEFEND
        else
            newState = STATE_RETREAT
        end
    end

    -- If we have good health & stamina, be more aggressive
    if myHealth > 5 and myStamina >= 5 then
        if absDistX > 30 then
            newState = STATE_APPROACH
        else
            if math.random() < 0.5 then
                newState = STATE_ATTACK
            else
                newState = STATE_JUMP_ATTACK
            end
        end
    end

    -- If the opponent has very low health, press the advantage
    if oppHealth <= 2 and absDistX < 40 then
        newState = STATE_ATTACK
    end

    -- Switch states if different from current
    if newState ~= self.currentState then
        self.currentState = newState
        self.stateTimer   = 0
    end
end

--------------------------------------------------------------------------------
-- State Logic Implementations
--------------------------------------------------------------------------------

-- Approach: Move toward the opponent
function AIController:runApproachLogic(input, distX, absDistX, player, opponent)
    local myStamina = player.stamina

    -- Move closer
    input.moveX = (distX > 0) and 1 or -1

    -- Maybe dash if we have enough stamina
    if absDistX > 40 and myStamina > 3 and math.random() < 0.02 then
        input.dash = true
    end

    -- If we’re within attack range
    if absDistX < 20 then
        -- 30% chance to do a light attack
        if math.random() < 0.3 then
            input.lightAttack = true
            input.attack = true
        else
            -- or a heavy
            input.heavyAttack = true
            input.attack = true
        end
    end
end

-- Attack: We’re in an aggressive posture. Possibly chain attacks or jump attacks.
function AIController:runAttackLogic(input, player, opponent, absDistX, distY)
    local myStamina = player.stamina

    -- If we’re too far from the opponent, move in
    if absDistX > 10 then
        input.moveX = (opponent.x > player.x) and 1 or -1
    end

    -- If close and have stamina, choose attacks
    if absDistX < 16 then
        local r = math.random()
        if r < 0.4 and myStamina >= 1 then
            input.lightAttack = true
            input.attack      = true
        elseif r < 0.7 and myStamina >= 2 then
            input.heavyAttack = true
            input.attack      = true
        else
            -- Maybe shield to “bait” the opponent
            input.shield = true
        end
    end

    -- Sometimes jump to confuse the player
    if math.random() < 0.01 and not player.isJumping then
        input.jump = true
    end

    -- If we’re in the air and above them, do a down-air
    if player.isJumping and distY > 0 and math.random() < 0.1 then
        input.down   = true
        input.attack = true
    end
end

-- Defend: We’re either low on health or expecting an incoming attack
function AIController:runDefendLogic(input, player, opponent, absDistX)
    local myStamina = player.stamina

    -- If the opponent is close, shield or attempt a counter
    if absDistX < 16 then
        -- If we have enough stamina, hold shield
        if myStamina > 0 then
            input.shield = true
        end

        -- Occasionally attempt a counter
        if math.random() < 0.08 then
            input.counter = true
        end

        -- Possibly retreat a bit
        input.moveX = (opponent.x > player.x) and -1 or 1
    else
        -- If the opponent is far, maybe we can break defense
        -- and approach or recover
        if math.random() < 0.02 then
            input.moveX = (opponent.x > player.x) and 1 or -1
        end
    end
end

-- Retreat: Move away from the opponent
function AIController:runRetreatLogic(input, distX, absDistX, player)
    input.moveX = (distX > 0) and -1 or 1

    -- If we have enough stamina, maybe dash away
    if math.random() < 0.02 and player.stamina > 1 then
        input.dash = true
    end

    -- Occasionally shield while retreating
    if math.random() < 0.01 then
        input.shield = true
    end
end

-- Recover: Low stamina, we do minimal actions to build it back up
function AIController:runRecoverLogic(input, player, opponent, distX, absDistX)
    -- Try to keep distance while stamina recharges
    if absDistX < 25 then
        input.moveX = (distX > 0) and -1 or 1
    end

    -- Possibly shield if the opponent is quite close
    if absDistX < 15 then
        input.shield = true
    end

    -- Use the time to do nothing else so stamina can recover
end

-- Jump Attack: A state specifically for leaping then attacking from above
function AIController:runJumpAttackLogic(input, distX, distY, player, opponent)
    local absDistX = math.abs(distX)

    -- If not currently jumping, jump
    if not player.isJumping and absDistX < 40 then
        input.jump = true
    end

    -- If we’re already in the air
    if player.isJumping then
        -- Move horizontally toward the opponent to line up
        input.moveX = (distX > 0) and 1 or -1

        -- If slightly above the opponent, attempt a down-air
        if distY > 0 and math.random() < 0.2 then
            input.down   = true
            input.attack = true
        end
    else
        -- If we didn’t manage to jump (maybe out of stamina),
        -- just do a fallback approach
        if absDistX > 15 then
            input.moveX = (distX > 0) and 1 or -1
        else
            -- Attack if close
            if math.random() < 0.5 then
                input.lightAttack = true
                input.attack      = true
            else
                input.heavyAttack = true
                input.attack      = true
            end
        end
    end
end

return AIController
