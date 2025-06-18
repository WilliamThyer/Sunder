local AIController = {}
AIController.__index = AIController

-- A library of "sequences" (aka combos).
-- Each sequence has a `name` and a list of `steps`.
-- Each step has:
--   duration = how long (in seconds) to hold these inputs
--   input    = table of input flags to apply
-- 
-- To allow simple "faceOpponent" or "awayFromOpponent,"
-- we'll use special strings in `moveX` that we interpret in code.

local SEQUENCES = {
    -- Single-step "Retreat"
    {
      name = "Retreat",
      steps = {
        -- Move away from opponent
        { duration = 0.2, input = { moveX = "awayFromOpponent" } }
      }
    },
    -- Single-step "Approach"
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

    ----------------------------------------------------------------------------
    -- Missile Response Sequences (high priority, can interrupt other sequences)
    ----------------------------------------------------------------------------

    -- Jump to avoid missile
    {
      name = "MissileJump",
      steps = {
        { duration = 0.1, input = { jump = true } },
        { duration = 0.1, input = {} },
        { duration = 0.1, input = { jump = true } }  -- Double jump
      }
    },
    -- Shield to block missile
    {
      name = "MissileShield",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Face the missile
        { duration = 0.5, input = { shield = true } }  -- Hold shield
      }
    },
    -- Counter the missile 
    {
      name = "MissileCounter",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Face the missile
        { duration = 0.3, input = { counter = true } }  -- Counter window
      }
    },
    -- Delayed Missile Counter
    {
      name = "DelayedMissileCounter",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Face the missile
        { duration = 0.1, input = { } },  -- Wait for the missile to get closer
        { duration = 0.3, input = { counter = true } }  -- Counter window
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
        stepIndex      = 1,    -- Which step in the sequence we're on
        stepTime       = 0,    -- How long we've been in the current step

        -- Missile response tracking
        isRespondingToMissile = false,  -- True if currently in a missile response sequence
        missileResponseTimer = 0,       -- Time since last missile response (to prevent spam)

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

    -- Update missile response timer
    if self.missileResponseTimer > 0 then
        self.missileResponseTimer = self.missileResponseTimer - dt
    end

    -- Check for incoming missiles first (highest priority)
    local hasIncomingMissile, missile = self:detectIncomingMissile(player, opponent)
    if hasIncomingMissile then
        -- Interrupt current sequence to respond to missile
        if self.activeSequence and not self.isRespondingToMissile then
            self:stopSequence()
        end
        self:startMissileResponse(missile, player, opponent)
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
    -- Don't start new sequences if we're responding to a missile
    if self.isRespondingToMissile then
        return
    end

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

    -- "Retreat"
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

    -- "Approach"
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
end

--------------------------------------------------------------------------------
-- Advance the current sequence step by step
--------------------------------------------------------------------------------
function AIController:runSequenceLogic(dt, input, player, opponent)
    local seq  = self.activeSequence
    if not seq then
      self:stopSequence()
      return
    end
    local step = seq.steps[self.stepIndex]
    if not step then
        -- No step? We're done.
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
    
    -- If we were responding to a missile, mark that we're done
    if self.isRespondingToMissile then
        self.isRespondingToMissile = false
    end
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

--------------------------------------------------------------------------------
-- Missile Detection and Response
--------------------------------------------------------------------------------
function AIController:detectIncomingMissile(player, opponent)
    -- If we're already responding to a missile, don't check for new ones
    if self.isRespondingToMissile then
        return false
    end
    
    -- If we recently responded to a missile, wait a bit
    if self.missileResponseTimer > 0 then
        return false
    end
    
    -- Check if opponent has any active missiles
    if not opponent.missiles or #opponent.missiles == 0 then
        return false
    end
    
    -- Find the closest incoming missile
    local closestMissile = nil
    local closestDistance = math.huge
    
    for _, missile in ipairs(opponent.missiles) do
        if missile.active then
          print(missile.x, missile.y, player.x, player.y)
            -- Calculate distance to missile
            local distX = missile.x - player.x
            local distY = missile.y - player.y
            local distance = math.sqrt(distX * distX + distY * distY)
            
            -- Check if missile is incoming (moving toward player)
            local isIncoming = false
            if missile.dir == 1 and distX < 0 then  -- Missile moving right, player is to the right
                isIncoming = true
            elseif missile.dir == -1 and distX > 0 then  -- Missile moving left, player is to the left
                isIncoming = true
            end
            print('isIncoming', isIncoming)
            
            -- Check if missile is close enough to be a threat
            local isClose = distance < 30  -- Adjust this threshold as needed
            print('isClose', isClose)
            
            if isIncoming and isClose and distance < closestDistance then
                closestMissile = missile
                closestDistance = distance
            end
        end
    end
    
    return closestMissile ~= nil, closestMissile
end

function AIController:startMissileResponse(missile, player, opponent)
    -- Mark that we're responding to a missile
    self.isRespondingToMissile = true
    self.missileResponseTimer = 0.5  -- Prevent immediate re-triggering
    
    -- Choose response based on distance and random chance
    local distX = missile.x - player.x
    local absDistX = math.abs(distX)
    local r = math.random()
    
    local responseSequence = nil
    
    if absDistX < 15 then
        -- Very close - mostly shield, sometimes counter
        if r < 0.2 then  -- 20% chance to counter
            responseSequence = "MissileCounter"
        else
            responseSequence = "MissileShield"
        end
      elseif absDistX < 30 then
        if r < 0.8 then
          responseSequence = "DelayedMissileCounter"
        else
          responseSequence = "MissileShield"
        end
      else
        -- Further away - mostly jump, sometimes shield
        if r < 0.3 then  -- 30% chance to shield
            responseSequence = "MissileShield"
        elseif r < 0.5 then
            responseSequence = "MissileJump"
        else
          responseSequence = "JumpApproach"
        end
    end
    
    -- Start the missile response sequence
    self:startSequence(responseSequence)
end

return AIController
