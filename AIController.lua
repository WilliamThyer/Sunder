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
        { duration = math.random(.1, .3), input = { moveX = "awayFromOpponent" } }
      }
    },
    -- Single-step "Approach"
    {
      name = "Approach",
      steps = {
        -- Move toward opponent
        { duration = math.random(.1, .3), input = { moveX = "faceOpponent" } }
      }
    },
    {
    -- Single-step "Wait"
      name = "Wait",
      steps = {
        -- Move toward opponent for 0.8s
        { duration = math.random(.1, .3), input = {} }
      }
    },
    -- Longer "Approach"
    {
      name = "LongApproach",
      steps = {
        -- Move toward opponent
        { duration = math.random(.3, .5), input = { moveX = "faceOpponent" } }
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
    -- Character-specific sequences
    ----------------------------------------------------------------------------
    
    -- Heavy Attack
    {
      name = "HeavyAttack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } },
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
        { duration = math.random(.05, .1), input = { moveX = "faceOpponent" } },
        { duration = 0.25, input = { dash = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } }
      }
    },
    -- Jump + Down-Air
    {
      name = "Jump DownAir",
      steps = {
        { duration = math.random(.1, .2), input = { moveX = "faceOpponent"} },
        { duration = 0.01, input = { jump = true} },
        { duration = math.random(.3, .6), input = { moveX = "onOpponent"} },
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
        { duration = math.random(.5, .8), input = { shield = true } }
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
    -- Wait + Counter + Heavy Attack
    {
      name = "Wait Counter Heavy",
      steps = {
        { duration = math.random(.1, .2), input = { } },
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
        { duration = math.random(.2, .4), input = { shield = true } },
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
        { duration = math.random(.1, .3), input = { moveX = "awayFromOpponent" } },
      }
    },
    -- Light Attack + Shield + Heavy Attack
    {
      name = "LightAttack Shield Heavy",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } },
        { duration = math.random(.05, .2), input = { moveX = "faceOpponent" } },
        { duration = math.random(.1, .4), input = { shield = true } },
        { duration = 0.01, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },
    -- Jump + Light Attack
    {
      name = "Jump LightAttack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = math.random(.1, .2), input = { moveX = "awayFromOpponent" } },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = math.random(.4, .5), input = { moveX = "faceOpponent" } },
        { duration = 0.2, input = { lightAttack = true, attack = true } },
        { duration = 0.4, input = { moveX = "faceOpponent" } },
      }
    },
    -- Jump + Heavy Attack
    {
      name = "Jump HeavyAttack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = math.random(.1, .3), input = { moveX = "faceOpponent" } },
        { duration = 0.2, input = { heavyAttack = true, attack = true } },
        { duration = 0.5, input = { moveX = "faceOpponent" } },
      }
    },
    -- Double Jump + Heavy Attack
    {
      name = "DoubleJump HeavyAttack",
      steps = {
        { duration = 0.01, input = { moveX = "awayFromOpponent" , jump = true} },
        { duration = math.random(.2, .3), input = { moveX = "awayFromOpponent" } },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = math.random(.3, .5), input = { moveX = "faceOpponent" } },
        { duration = 0.01, input = { heavyAttack = true, attack = true , moveX = "faceOpponent"} },
        { duration = 0.5, input = { moveX = "faceOpponent" } },
      }
    },
    -- Jump Away + Down Air
    {
      name = "Jump Away DownAir",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = math.random(.2, .4), input = { moveX = "awayFromOpponent" } },
        { duration = 0.1, input = { moveX = "faceOpponent"} },
        { duration = 0.01, input = { moveX = "faceOpponent" , jump = true} },
        { duration = 0.2, input = { moveX = "faceOpponent"} },
        { duration = math.random(.1, .2), input = { moveX = "onOpponent" } },
        { duration = 0.05, input = { down = true, attack = true } },
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

    ----------------------------------------------------------------------------
    -- Mage-Specific Sequences
    ----------------------------------------------------------------------------

    -- Mage Hover Approach - Hold jump to hover while moving toward opponent
    {
      name = "Mage Hover Approach",
      steps = {
        { duration = math.random(.4, .6), input = { moveX = "faceOpponent", jump = true } }
      }
    },

    -- Mage Hover Away - Hold jump to hover while moving away (for positioning)
    {
      name = "Mage Hover Away",
      steps = {
        { duration = math.random(.4, .6), input = { moveX = "awayFromOpponent", jump = true } }
      }
    },

    -- Mage Hover HeavyAttack - Hover, position above opponent, then heavy attack
    {
      name = "Mage Hover HeavyAttack",
      steps = {
        { duration = math.random(.1, .2), input = { moveX = "faceOpponent" } },
        { duration = math.random(.4, .6), input = { moveX = "onOpponent", jump = true } },
        { duration = 0.1, input = { moveX = "faceOpponent" } },
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },

    -- Mage Hover LightAttack - Hover, position, then light attack
    {
      name = "Mage Hover LightAttack",
      steps = {
        { duration = math.random(.1, .2), input = { moveX = "faceOpponent" } },
        { duration = math.random(.4, .6), input = { moveX = "onOpponent", jump = true } },
        { duration = 0.1, input = { moveX = "faceOpponent" } },
        { duration = 0.4, input = { lightAttack = true, attack = true } }
      }
    },

    -- Mage Teleport Light Attack - Dash toward opponent (teleports through, appearing behind), wait for teleport, turn, then light attack
    {
      name = "Mage Teleport Light Attack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Face opponent first
        { duration = 0.05, input = { moveX = "faceOpponent", dash = true } },  -- Dash toward (teleports through opponent)
        { duration = 0.4, input = { } },  -- Wait for teleport animation to complete
        { duration = 0.1, input = { moveX = "faceOpponent" } },  -- Turn to face opponent (now behind them)
        { duration = 0.4, input = { lightAttack = true, attack = true } }
      }
    },

    -- Mage Teleport Heavy Attack - Dash toward opponent (teleports through, appearing behind), wait for teleport, turn, then heavy attack
    {
      name = "Mage Teleport Heavy Attack",
      steps = {
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Face opponent first
        { duration = 0.05, input = { moveX = "faceOpponent", dash = true } },  -- Dash toward (teleports through opponent)
        { duration = 0.4, input = { } },  -- Wait for teleport animation to complete
        { duration = 0.01, input = { moveX = "faceOpponent" } },  -- Turn to face opponent (now behind them)
        { duration = 0.5, input = { heavyAttack = true, attack = true } }
      }
    },

    -- Mage MissileHover - Hold jump to hover above incoming missiles
    {
      name = "Mage MissileHover",
      steps = {
        { duration = math.random(.4, .8), input = { jump = true } }
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

        -- Projectile response tracking
        isRespondingToProjectile = false,  -- True if currently in a projectile response sequence
        projectileResponseTimer = 0,       -- Time since last projectile response (to prevent spam)

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

    -- Update projectile response timer
    if self.projectileResponseTimer > 0 then
        self.projectileResponseTimer = self.projectileResponseTimer - dt
    end

    -- Check for incoming projectiles first (highest priority)
    local hasIncomingProjectile, projectile = self:detectIncomingProjectile(player, opponent)
    if hasIncomingProjectile then
        -- Interrupt current sequence to respond to projectile
        if self.activeSequence and not self.isRespondingToProjectile then
            self:stopSequence()
        end
        self:startProjectileResponse(projectile, player, opponent)
    end

    -- If we are not currently running a sequence, decide 
    if not self.activeSequence then
      self:decideAction(player, opponent)
    end

    self:runSequenceLogic(dt, input, player, opponent)

    return input
end

--------------------------------------------------------------------------------
-- DECIDE ACTION: Character-specific logic
--------------------------------------------------------------------------------
function AIController:decideAction(player, opponent)
    -- Don't start new sequences if we're responding to a projectile
    if self.isRespondingToProjectile then
        return
    end

    local distX     = opponent.x - player.x
    local distY     = opponent.y - player.y
    local absDistX  = math.abs(distX)
    local myStamina = player.stamina
    local r = math.random()
    
    -- Get character type for character-specific logic
    local characterType = player.characterType

    -- Check for opponent attack and respond (high priority)
    if (opponent.isHeavyAttacking and absDistX < 15) or (opponent.isLightAttacking and absDistX < 10) then
        if r < 0.5 then  -- 50% chance to counter
            print("Opponent is heavy attacking, countering")
            self:startSequence("Wait Counter Heavy")
        else  -- 50% chance to shield
            print("Opponent is heavy attacking, shielding")
            self:startSequence("ShieldOnly")
        end
    end

    -- Avoid downair 
    if opponent.isDownAir and absDistX < 10 then
      if myStamina > 3 and r < .3 then
        self:startSequence("DashAway")
      else 
        self:startSequence("Retreat")
      end

    -- "Retreat"
    elseif myStamina < 2 then
      self:startSequence("Retreat")
    
    -- Chill
    elseif myStamina < 4 and absDistX < 10 then
      if r < .4 then
          self:startSequence("Retreat")
      elseif r < .6 then
        self:startSequence("ShieldOnly")
      else
        self:startSequence("LightAttack MoveAway")
      end

    -- Long range: Character-specific behavior
    elseif absDistX > 40 then
        if characterType == "Berserker" or characterType == "Mage" and myStamina >= 3 then
            if r < 0.4 then
                self:startSequence("HeavyAttack")
            elseif r < 0.8 then
                self:startSequence("Approach")
            else
              self:startSequence("Wait")
            end
        else
            -- Other characters approach normally
            if r < .8 then -- 80%
                self:startSequence("Approach")
            else -- 20%
                self:startSequence("Wait")
            end
        end

    -- Mid-range: pick one from

    -- If lancer, use heavy attack from mid-range
    elseif characterType == "Lancer" and absDistX > 10 then
      local options = {
        "Dash Light Attack",
        "Approach",
        "HeavyAttack"
      }
      local choice = options[math.random(#options)]
      self:startSequence(choice)

    -- Mage-specific mid-range behavior
    elseif characterType == "Mage" and absDistX > 10 then
        local options = {
          "Mage Teleport Light Attack",
          "Mage Teleport Heavy Attack",
          "Mage Hover Approach",
          "Approach",
          "Mage Hover HeavyAttack",
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)

    elseif absDistX > 10 then
        local options = {
          "Dash Light Attack",
          "Approach",
          "Jump HeavyAttack",
          "Jump LightAttack",
        }
        local choice = options[math.random(#options)]
        self:startSequence(choice)

    -- On top of
    elseif absDistX < 4 and distY > 0 then
        if characterType == "Mage" then
            local options = {
              "Mage Teleport Heavy Attack",
              "Dash Away",
              "Jump DownAir"
            }
            local choice = options[math.random(#options)]
            self:startSequence(choice)
        else
            local options = {
              "Jump DownAir",
              "DoubleJump HeavyAttack",
              "Jump Away DownAir"
            }
            local choice = options[math.random(#options)]
            self:startSequence(choice)
        end

    -- Very close (absDistX < 10):
    else 
        if characterType == "Mage" then
            -- Mage-specific close-range options
            local options = {
              "Approach",
              "Retreat",
              "ShieldOnly",
              "ShieldOnly",
              "Counter Heavy",
              "Shield Counter Heavy",
              "LightAttack MoveAway",
              "LightAttack Shield Heavy",
              "Mage Hover LightAttack",
              "Mage Hover HeavyAttack",
              "Mage Teleport Light Attack",
              "Mage Teleport Heavy Attack",
            }
            local choice = options[math.random(#options)]
            self:startSequence(choice)
        else
            local options = {
              "Approach",
              "Retreat",
              "ShieldOnly",
              "ShieldOnly",
              "Counter Heavy",
              "Shield Counter Heavy",
              "LightAttack MoveAway",
              "LightAttack Shield Heavy",
              "Jump LightAttack",
              "Jump DownAir",
              "Jump HeavyAttack",
              "DoubleJump HeavyAttack",
            }
            local choice = options[math.random(#options)]
            self:startSequence(choice)
        end
    end

end

--------------------------------------------------------------------------------
-- Start a particular sequence by name
--------------------------------------------------------------------------------
function AIController:startSequence(name)
  -- local r = math.random()
  -- if r < 0.2 then
  --   name = "Dash Light Attack"
  -- else
  --   name = "Retreat"
  -- end
  -- print("Starting sequence: " .. name)
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
    
    -- If we were responding to a projectile, mark that we're done
    if self.isRespondingToProjectile then
        self.isRespondingToProjectile = false
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
-- Projectile Detection and Response (Missiles and Shockwaves)
--------------------------------------------------------------------------------
function AIController:detectIncomingProjectile(player, opponent)
    -- If we're already responding to a projectile, don't check for new ones
    if self.isRespondingToProjectile then
        return false
    end
    
    -- If we recently responded to a projectile, wait a bit
    if self.projectileResponseTimer > 0 then
        return false
    end
    
    -- Find the closest incoming projectile (missile or shockwave)
    local closestProjectile = nil
    local closestDistance = math.huge
    
    -- Check for missiles
    if opponent.missiles and #opponent.missiles > 0 then
        for _, missile in ipairs(opponent.missiles) do
            if missile.active then
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
                
                -- Check if missile is close enough to be a threat
                local isClose = distance < 30  -- Adjust this threshold as needed
                
                if isIncoming and isClose and distance < closestDistance then
                    closestProjectile = missile
                    closestDistance = distance
                end
            end
        end
    end
    
    -- Check for shockwaves
    if opponent.shockwaves and #opponent.shockwaves > 0 then
        for _, shockwave in ipairs(opponent.shockwaves) do
            if shockwave.active then
                -- Calculate distance to shockwave
                local distX = shockwave.x - player.x
                local distY = shockwave.y - player.y
                local distance = math.sqrt(distX * distX + distY * distY)
                
                -- Check if shockwave is incoming (moving toward player)
                local isIncoming = false
                if shockwave.direction == 1 and distX < 0 then  -- Shockwave moving right, player is to the right
                    isIncoming = true
                elseif shockwave.direction == -1 and distX > 0 then  -- Shockwave moving left, player is to the left
                    isIncoming = true
                end
                
                -- Check if shockwave is close enough to be a threat
                local isClose = distance < 25  -- Slightly closer threshold for shockwaves
                
                if isIncoming and isClose and distance < closestDistance then
                    closestProjectile = shockwave
                    closestDistance = distance
                end
            end
        end
    end
    
    return closestProjectile ~= nil, closestProjectile
end

function AIController:startProjectileResponse(projectile, player, opponent)
    -- Mark that we're responding to a projectile
    self.isRespondingToProjectile = true
    self.projectileResponseTimer = 0.5  -- Prevent immediate re-triggering
    
    -- Choose response based on distance and random chance
    local distX = projectile.x - player.x
    local absDistX = math.abs(distX)
    local r = math.random()
    local characterType = player.characterType
    
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
        -- Further away - mostly jump/hover, sometimes shield
        if r < 0.3 then  -- 30% chance to shield
            responseSequence = "MissileShield"
        elseif r < 0.5 then
            -- Use mage hover for mage characters, regular jump for others
            if characterType == "Mage" then
                responseSequence = "Mage MissileHover"
            else
                responseSequence = "MissileJump"
            end
        else
          responseSequence = "JumpApproach"
        end
    end
    
    -- Start the projectile response sequence
    self:startSequence(responseSequence)
end

return AIController
