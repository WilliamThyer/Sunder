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
    -- Single-step “Retreat”
    {
      name = "Retreat",
      steps = {
        -- Move away from opponent
        { duration = 0.2, input = { moveX = "awayFromOpponent" } }
      }
    },
    -- Single-step “Approach”
    {
      name = "Approach",
      steps = {
        -- Move toward opponent
        { duration = 0.2, input = { moveX = "faceOpponent" } }
      }
    },
    {
    -- Single-step "Wait"
      name = "Wait",
      steps = {
        -- Move toward opponent for 0.8s
        { duration = 0.1, input = {} }
      }
    },
    {
    -- Single-step "Dash Away"
      name = "DashAway",
      steps = {
        -- Dash away too avoid downair 
        { duration = 0.1, input = {"awayFromOpponent"} },
        { duration = 0.1, input = {dash = true} }
      }
    },
    ----------------------------------------------------------------------------
    -- Mid-range sequences (distX < 40 and distX > 10)
    ----------------------------------------------------------------------------

    -- Jump Approach 
    {
      name = "Jump Approach",
      steps = {
        { duration = 0.1, input = { moveX = "faceOpponent" , jump = true } },
      }
    },
    -- Dash + Light Attack
    {
      name = "Dash Light Attack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.25, input = { dash = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } }
      }
    },
    -- Jump + Down-Air
    {
      name = "Jump DownAir",
      steps = {
        { duration = 0.01, input = { jump = true} },
        { duration = 0.1, input = { moveX = "onOpponent"} },
        { duration = 0.4, input = { down = true, attack = true } }
      }
    },

    ----------------------------------------------------------------------------
    -- Close-range sequences (distX < 10)
    ----------------------------------------------------------------------------

    -- 6) Shield only
    {
      name = "ShieldOnly",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.2, input = { shield = true } }
      }
    },
    -- Counter + Heavy Attack
    {
      name = "Counter Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.6, input = { counter = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },
    -- Shield + Counter + Heavy Attack
    {
      name = "Shield Counter Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.3, input = { shield = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.6, input = { counter = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },
    -- Light Attack + Move Away
    {
      name = "LightAttack MoveAway",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } },
        { duration = 0.2, input = { moveX = "awayFromOpponent" } },
      }
    },
    -- Light Attack + Shield + Heavy Attack
    {
      name = "LightAttack Shield Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.2, input = { shield = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },
    -- Jump + Light Attack
    {
      name = "Jump LightAttack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.15, input = { moveX = "awayFromOpponent" } },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.3, input = { moveX = "faceOpponent" } },
        { duration = 0.6, input = { lightAttack = true, attack = true } },
      }
    },
    -- Jump + Heavy Attack
    {
      name = "Jump HeavyAttack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.4, input = { moveX = "awayFromOpponent" } },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.25, input = { moveX = "faceOpponent" } },
        { duration = 0.05, input = { } },
        { duration = 0.6, input = { heavyAttack = true, attack = true } },
      }
    },
    -- Jump Away + Down Air
    {
      name = "Jump Away DownAir",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.4, input = { moveX = "awayFromOpponent" } },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.25, input = { moveX = "onOpponent" } },
        { duration = 0.05, input = { down = true, attack = true } },
        { duration = 0.1, input = { moveX = "awayFromOpponent"} },
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
        activeSequenceName = nil,
        stepIndex      = 1,    -- Which step in the sequence we’re on
        stepTime       = 0,    -- How long we’ve been in the current step

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

    -- If we are not currently running a sequence, decide 
    if not self.activeSequence then
      self:decideAction(player, opponent)
    end

    self:runSequenceLogic(dt, input, player, opponent)

    return input
end

--------------------------------------------------------------------------------
-- DECIDE ACTION: A simpler approach using your conditions and picking sequences
--------------------------------------------------------------------------------
function AIController:decideAction(player, opponent)
    local distX     = opponent.x - player.x
    local distY     = opponent.y - player.y
    local absDistX  = math.abs(distX)
    local myStamina = player.stamina
    local r = math.random()

    -- Avoid downair 
    if opponent.isDownAir then
      if myStamina > 3 and r < .5 then
        self:startSequence("DashAway")
      else 
        self:startSequence("Retreat")
      end

    -- “Retreat”
    elseif myStamina < 3 then
      self:startSequence("Retreat")
    
    -- Chill
    elseif myStamina < 4 then
      if r < .3 then
          self:startSequence("Retreat")
      elseif r < .6 then
          self:startSequence("ShieldOnly")
      else
        if absDistX < 10 then
          self:startSequence("LightAttack MoveAway")
        end
      end

    -- “Approach”
    elseif absDistX > 40 then
        if r < .8 then -- 80%
            self:startSequence("Approach")
        else -- 20%
            self:startSequence("Wait")
        end

    -- Mid-range: pick one from
    elseif absDistX > 10 then
        local options = {
          "Jump Approach",
          "Dash Light Attack",
          "Approach",
        --   "Jump HeavyAttack",
          "Jump LightAttack",
          "LightAttack Shield Heavy",
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)

    -- On top of
    elseif absDistX < 4 and distY > 0 then
        print('ontopof')
        local options = {
          "Jump DownAir",
        --   "Jump HeavyAttack",
          "Jump Away DownAir"
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)

    -- Very close (absDistX < 10):
    else 
        local options = {
          "ShieldOnly",
          "Counter Heavy",
          "Shield Counter Heavy",
          "LightAttack MoveAway",
          "LightAttack Shield Heavy",
        --   "Jump LightAttack",
        --   "Jump DownAir",
          "Jump HeavyAttack",
          "Jump Away DownAir"
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)
    end

end

--------------------------------------------------------------------------------
-- Start a particular sequence by name
--------------------------------------------------------------------------------
function AIController:startSequence(name)
    self.activeSequenceName = name
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
    print(self.activeSequenceName)
    local seq  = self.activeSequence
    if not seq then
      self:stopSequence()
      return
    end
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
    self.activeSequenceName = nil
    self.stepIndex      = 1
    self.stepTime       = 0
end

--------------------------------------------------------------------------------
-- Helper to interpret "moveX" = "faceOpponent" or "awayFromOpponent"
--------------------------------------------------------------------------------
function AIController:handleMoveX(mode, input, player, opponent)
    local distX = (opponent.x - player.x)
    local absDistX = math.abs(distX)
    if mode == "faceOpponent" then
        if absDistX > 8 then
            input.moveX = (distX > 0) and 1 or -1
        else
            input.moveX = input.moveX * 0.5
        end
    elseif mode == "awayFromOpponent" then
        input.moveX = (distX > 0) and -1 or 1
    elseif mode == "onOpponent" then
        input.moveX = (distX > 0) and 1 or -1
    else
        input.moveX = 0
    end
end

return AIController
