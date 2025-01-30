local AIController = {}
AIController.__index = AIController

-- A library of “sequences” (aka combos).
-- Each sequence has a `name` and a list of `steps`.
-- Each step has:
--   duration = how long (in seconds) to hold these inputs
--   input    = table of input flags to apply
-- 
-- To allow simple “faceOpponent” or “awayFromOpponent,”
-- we’ll use special strings in `moveX` that we interpret in code.

local SEQUENCES = {
    -- 1) Single-step “Retreat”
    {
      name = "Retreat",
      steps = {
        -- Move away from opponent for 0.8s
        { duration = 0.3, input = { moveX = "awayFromOpponent" } }
      }
    },
    -- 2) Single-step “Approach”
    {
      name = "Approach",
      steps = {
        -- Move toward opponent for 0.8s
        { duration = 0.3, input = { moveX = "faceOpponent" } }
      }
    },

    ----------------------------------------------------------------------------
    -- Mid-range sequences (distX < 40 and distX > 10)
    ----------------------------------------------------------------------------

    -- 3) Dash + Light Attack
    {
      name = "Dash Light Attack",
      steps = {
        { duration = 0.3, input = { dash = true } },
        { duration = 0.2, input = { lightAttack = true, attack = true } }
      }
    },
    -- 4) Jump + Dash + Heavy Attack
    {
      name = "Jump Dash Heavy Attack",
      steps = {
        { duration = 0.2, input = { jump = true, moveX = "faceOpponent" } },
        { duration = 0.3, input = { dash = true } },
        { duration = 0.3, input = { heavyAttack = true, attack = true } }
      }
    },
    -- 5) Double Jump + Dash + Down-Air
    {
      name = "Double Jump Dash DownAir",
      steps = {
        { duration = 0.2, input = { jump = true, moveX = "faceOpponent"} },
        { duration = 0.3, input = { jump = true} },
        { duration = 0.06, input = { dash = true } },
        { duration = 0.4, input = { down = true, attack = true } }
      }
    },

    ----------------------------------------------------------------------------
    -- Close-range sequences (distX < 10)
    ----------------------------------------------------------------------------

    -- 6) Shield only (simulate “30% chance” by picking it randomly among others)
    {
      name = "ShieldOnly",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.1, input = { shield = true } }
      }
    },
    -- 7) Shield + Counter + Heavy Attack
    {
      name = "Shield Counter Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.1, input = { shield = true } },
        { duration = 0.6, input = { counter = true } },
        { duration = 0.4, input = { heavyAttack = true, attack = true } }
      }
    },
    -- 8) Double Jump + Down Air
    {
      name = "DoubleJump DownAir",
      steps = {
        { duration = 0.2, input = { jump = true } },
        { duration = 0.05, input = { moveX = "faceOpponent" } },
        { duration = 0.2, input = { jump = true } },
        { duration = 0.4, input = { down = true, attack = true } },
      }
    },
    -- 9) Light Attack + Dash Away
    {
      name = "LightAttack DashAway",
      steps = {
        { duration = 0.4, input = { lightAttack = true, attack = true } },
        { duration = 0.01, input = { moveX = "awayFromOpponent" } },
        { duration = 0.06, input = { dash = true } }
      }
    },
    -- 10) Light Attack + Shield + Heavy Attack
    {
      name = "LightAttack Shield Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } },
        { duration = 0.2, input = { shield = true } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },
}

--------------------------------------------------------------------------------
-- AIController
--------------------------------------------------------------------------------
function AIController:new()
    local ai = {
        -- Sequence-related tracking
        activeSequence = nil,  -- The currently executing sequence (table)
        stepIndex      = 1,    -- Which step in the sequence we’re on
        stepTime       = 0,    -- How long we’ve been in the current step
        nextDecisionTime = 0,  -- When to pick a new action if idle

        -- Stage boundaries, etc.
        stageLeft  = 0,
        stageRight = 128
    }
    setmetatable(ai, AIController)
    return ai
end

function AIController:getInput(dt, player, opponent)
    -- Blank input each frame
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

    -- If there's no valid opponent or AI is dead, do nothing
    if (not opponent) or player.isDead then
        return input
    end

    -- If we are currently running a sequence, continue that
    if self.activeSequence then
        self:runSequenceLogic(dt, input, player, opponent)
        return input
    end

    -- Otherwise, if enough time has passed to pick a new action, decide now
    self.nextDecisionTime = self.nextDecisionTime - dt
    if self.nextDecisionTime <= 0 then
        self:decideAction(player, opponent)
        -- If we *did* pick a sequence, the next frame runSequenceLogic will apply
    end

    -- For safety, return input (still blank if we’re between sequences)
    return input
end

--------------------------------------------------------------------------------
-- DECIDE ACTION: A simpler approach using your conditions and picking sequences
--------------------------------------------------------------------------------
function AIController:decideAction(player, opponent)
    local distX     = opponent.x - player.x
    local absDistX  = math.abs(distX)
    local myStamina = player.stamina

    if myStamina < 2 then
        -- 1) “Retreat”
        self:startSequence("Retreat")

    elseif absDistX > 40 then
        -- 2) “Approach”
        self:startSequence("Approach")

    elseif absDistX > 10 then
        -- 3) Mid-range: pick one from
        --    - Dash Light Attack
        --    - Jump Dash Heavy Attack
        --    - Double Jump Dash DownAir
        --    - Approach
        local options = {
          "Dash Light Attack",
          "Jump Dash Heavy Attack",
          "Double Jump Dash DownAir",
          "Approach"
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)

    else
        -- 4) Very close (absDistX < 10): pick from
        --    - ShieldOnly
        --    - Shield Counter Heavy
        --    - DoubleJump DownAir
        --    - LightAttack DashAway
        --    - LightAttack Shield Heavy
        local options = {
          "ShieldOnly",
          "Shield Counter Heavy",
          "DoubleJump DownAir",
          "LightAttack DashAway",
          "LightAttack Shield Heavy"
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)
    end

    -- To avoid spamming new decisions every single frame,
    -- set nextDecisionTime to e.g. 0.2~0.5s
    self.nextDecisionTime = 0.2 + math.random() * 0.3
end

--------------------------------------------------------------------------------
-- Start a particular sequence by name
--------------------------------------------------------------------------------
function AIController:startSequence(name)
    -- Find the sequence in SEQUENCES
    for _, seq in ipairs(SEQUENCES) do
        if seq.name == name then
            self.activeSequence = seq
            self.stepIndex      = 1
            self.stepTime       = 0
            return
        end
    end
    -- If not found, do nothing (or default to Approach)
    print("Sequence not found:", name)
end

--------------------------------------------------------------------------------
-- Advance the current sequence step by step
--------------------------------------------------------------------------------
function AIController:runSequenceLogic(dt, input, player, opponent)
    local seq  = self.activeSequence
    local step = seq.steps[self.stepIndex]
    if not step then
        -- No step? We’re done.
        self:stopSequence()
        return
    end

    -- Apply the step inputs into `input`
    for k, v in pairs(step.input) do
        if k == "moveX" then
            -- Handle special strings like "faceOpponent" or "awayFromOpponent"
            self:handleMoveX(v, input, player, opponent)
        else
            input[k] = v
        end
    end

    -- Update time in this step
    self.stepTime = self.stepTime + dt
    if self.stepTime >= step.duration then
        -- Move to next step
        self.stepIndex = self.stepIndex + 1
        self.stepTime  = 0

        -- If we finished all steps, stop the sequence
        if self.stepIndex > #seq.steps then
            self:stopSequence()
        end
    end
end

function AIController:stopSequence()
    self.activeSequence = nil
    self.stepIndex      = 1
    self.stepTime       = 0
end

--------------------------------------------------------------------------------
-- Helper to interpret "moveX" = "faceOpponent" or "awayFromOpponent"
--------------------------------------------------------------------------------
function AIController:handleMoveX(mode, input, player, opponent)
    local distX = (opponent.x - player.x)
    if mode == "faceOpponent" then
        input.moveX = (distX > 0) and 1 or -1
    elseif mode == "awayFromOpponent" then
        input.moveX = (distX > 0) and -1 or 1
    else
        -- Or if mode was a number, you could just do input.moveX = mode
        input.moveX = 0
    end
end

return AIController
