local AIController = {}
AIController.__index = AIController

--------------------------------------------------------------------------------
-- PARAM Table (Tuning Constants)
--------------------------------------------------------------------------------
local PARAM = {
    HEAVY_COUNTER_RANGE = 15,
    HEAVY_REACTION_TIME = 0.04,  -- very fast
    HEAVY_SHIELD_HOLD_TIME = 0.5,
    LIGHT_BLOCK_RANGE = 10,
    PROJ_SHIELD_THRESHOLD = 30,
    PROJ_PERFECT_COUNTER_WINDOW = 0.22, -- seconds before impact
    PROJ_SHIELD_HOLD_TIME = 0.6,
    JUMP_WINDOW = 0.25,
    APPROACH_IDEAL_DIST = 8,
    APPROACH_TOLERANCE = 1.5,
    STAMINA_HEAVY_COST = 2,
    STAMINA_COUNTER_COST = 1,
    EDGE_MARGIN = 6,
    MAX_ACTION_DURATION = 1.2
}

--------------------------------------------------------------------------------
-- CharacterProfile Table
--------------------------------------------------------------------------------
local CharacterProfile = {
    Mage = {
        preferHoverOnProjectile = true,
        heavyRange = 14,
        teleportCooldown = 1.2,
        mobility = 0.7,
        idealDistance = 8,
        aggressiveBias = 0.3
    },
    Lancer = {
        preferHeavyAtMid = true,
        heavyRange = 12,
        mobility = 0.4,
        idealDistance = 12,
        aggressiveBias = 0.5
    },
    Berserker = {
        aggressiveBias = 0.8,
        heavyThreshold = 3,
        idealDistance = 6,
        mobility = 0.6
    },
    Warrior = {
        idealDistance = 8,
        mobility = 0.5,
        aggressiveBias = 0.5
    }
}


--------------------------------------------------------------------------------
-- Helper Methods
--------------------------------------------------------------------------------

-- Calculate projectile threat (distance, time to impact, urgency)
function AIController:calculateProjectileThreat(projectile, player)
    local distX = projectile.x - player.x
    local distY = projectile.y - player.y
    local distance = math.sqrt(distX * distX + distY * distY)
    
    -- Determine projectile speed
    local speed = 70  -- default missile speed
    if projectile.speed then
        speed = projectile.speed
    elseif projectile.direction then
        speed = 50  -- shockwave speed
    end
    
    -- Calculate time to impact
    local timeToImpact = distance / speed
    
    -- Calculate urgency (higher = more urgent)
    local urgency = 1 / (timeToImpact + 0.1)  -- add small value to avoid division by zero
    
    -- Determine type
    local projType = "missile"
    if projectile.direction and not projectile.dir then
        projType = "shockwave"
    end
    
    return {
        projectile = projectile,
        distance = distance,
        timeToImpact = timeToImpact,
        urgency = urgency,
        type = projType
    }
end

-- Wrapper for character's canPerformAction
function AIController:canPerformAction(action, player)
    if not player.canPerformAction then
        return false
    end
    return player:canPerformAction(action)
end

-- Get ideal distance from CharacterProfile
function AIController:getIdealDistance(characterType)
    local profile = CharacterProfile[characterType]
    if profile and profile.idealDistance then
        return profile.idealDistance
    end
    return PARAM.APPROACH_IDEAL_DIST
end

-- Check if distance is within tolerance
function AIController:isWithinTolerance(distance, ideal, tolerance)
    return math.abs(distance - ideal) <= tolerance
end

-- Face opponent by setting moveX direction
function AIController:faceOpponent(input, player, opponent)
    local distX = opponent.x - player.x
    local absDistX = math.abs(distX)
    if absDistX > 8 then
        input.moveX = (distX > 0) and 1 or -1
    else
        input.moveX = input.moveX * 0.5
    end
end

-- Update cooldowns
function AIController:updateCooldowns(dt)
    for key, cooldown in pairs(self.blackboard.cooldowns) do
        self.blackboard.cooldowns[key] = math.max(0, cooldown - dt)
    end
end

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

-- Update blackboard with current game state
function AIController:updateBlackboard(dt, player, opponent)
    local bb = self.blackboard
    
    -- Calculate distances
    bb.distX = opponent.x - player.x
    bb.distY = opponent.y - player.y
    bb.absDistX = math.abs(bb.distX)
    
    -- Resources
    bb.stamina = player.stamina
    bb.health = player.health
    
    -- Character state
    bb.characterState.isAttacking = player.isAttacking
    bb.characterState.isDashing = player.isDashing
    bb.characterState.isHurt = player.isHurt
    bb.characterState.isStunned = player.isStunned
    bb.characterState.isLanding = player.isLanding
    bb.characterState.isCountering = player.isCountering
    bb.characterState.canDash = player.canDash
    bb.characterState.dashPhase = player.dashPhase
    
    -- Opponent attack states
    bb.opponentHeavyAttacking = opponent.isHeavyAttacking
    bb.opponentLightAttacking = opponent.isLightAttacking
    
    -- Detect heavy attack startup
    if opponent.isHeavyAttacking and opponent.heavyAttackTimer then
        local startupThreshold = opponent.heavyAttackDuration - (opponent.heavyAttackNoDamageDuration or 0.35)
        bb.opponentHeavyStartup = opponent.heavyAttackTimer > startupThreshold
        
        -- Track when first detected
        if bb.opponentHeavyStartup and not bb.threatDetectedAt.heavyAttack then
            bb.threatDetectedAt.heavyAttack = 0  -- current time (will be updated with dt)
        end
    else
        bb.opponentHeavyStartup = false
        bb.threatDetectedAt.heavyAttack = nil
    end
    
    -- Update threat detection timers
    if bb.threatDetectedAt.heavyAttack then
        bb.threatDetectedAt.heavyAttack = bb.threatDetectedAt.heavyAttack + dt
    end
    if bb.threatDetectedAt.projectile then
        bb.threatDetectedAt.projectile = bb.threatDetectedAt.projectile + dt
    end
    
    -- Evaluate ALL projectiles, find most urgent
    bb.incomingProjectile = nil
    local mostUrgent = nil
    local highestUrgency = 0
    
    -- Check missiles
    if opponent.missiles and #opponent.missiles > 0 then
        for _, missile in ipairs(opponent.missiles) do
            if missile.active then
                local distX = missile.x - player.x
                local isIncoming = false
                if missile.dir == 1 and distX < 0 then
                    isIncoming = true
                elseif missile.dir == -1 and distX > 0 then
                    isIncoming = true
                end
                
                if isIncoming then
                    local threat = self:calculateProjectileThreat(missile, player)
                    if threat.urgency > highestUrgency and threat.distance < PARAM.PROJ_SHIELD_THRESHOLD then
                        mostUrgent = threat
                        highestUrgency = threat.urgency
                    end
                end
            end
        end
    end
    
    -- Check shockwaves
    if opponent.shockwaves and #opponent.shockwaves > 0 then
        for _, shockwave in ipairs(opponent.shockwaves) do
            if shockwave.active then
                local distX = shockwave.x - player.x
                local isIncoming = false
                if shockwave.direction == 1 and distX < 0 then
                    isIncoming = true
                elseif shockwave.direction == -1 and distX > 0 then
                    isIncoming = true
                end
                
                if isIncoming then
                    local threat = self:calculateProjectileThreat(shockwave, player)
                    if threat.urgency > highestUrgency and threat.distance < PARAM.PROJ_SHIELD_THRESHOLD then
                        mostUrgent = threat
                        highestUrgency = threat.urgency
                    end
                end
            end
        end
    end
    
    bb.incomingProjectile = mostUrgent
    
    -- Update cooldowns
    self:updateCooldowns(dt)
    
    -- Calculate edge distance
    bb.edgeDistance = math.min(player.x - self.stageLeft, self.stageRight - player.x)
end

-- Validate action before execution
function AIController:validateAction(action, player)
    -- Map action types to character action names
    local actionMap = {
        shield = "shield",
        counter = "counter",
        dash = "dash",
        jump = "jump",
        heavyAttack = "heavyAttack",
        lightAttack = "lightAttack",
        move = "move"
    }
    
    local charAction = actionMap[action.type] or action.type
    
    -- Check canPerformAction
    if not self:canPerformAction(charAction, player) then
        return false
    end
    
    -- Check stamina requirements
    if action.staminaCost then
        if player.stamina < action.staminaCost then
            return false
        end
    end
    
    -- Check cooldowns
    if action.cooldownType then
        if self.blackboard.cooldowns[action.cooldownType] > 0 then
            return false
        end
    end
    
    return true
end

-- Check priority interrupts
function AIController:checkPriorityInterrupts(player, opponent)
    local bb = self.blackboard
    
    -- 1. Incoming Projectile (highest priority)
    if bb.incomingProjectile then
        local proj = bb.incomingProjectile
        
        -- Priority 1: If within perfect counter window, counter (all characters)
        if proj.timeToImpact <= PARAM.PROJ_PERFECT_COUNTER_WINDOW then
            if self:validateAction({type = "counter", staminaCost = PARAM.STAMINA_COUNTER_COST}, player) then
                return {type = "counter", followUp = {type = "heavyAttack"}}
            end
        end
        
        -- Priority 2: If close, shield (all characters)
        if proj.distance < 15 then
            if self:validateAction({type = "shield"}, player) then
                return {type = "shield", duration = PARAM.PROJ_SHIELD_HOLD_TIME}
            end
        end
        
        -- Priority 3: Jump/hover (Mage can hover, others jump)
        if player.characterType == "Mage" then
            if self:validateAction({type = "jump"}, player) then
                return {type = "jump", hold = true}
            end
        else
            -- Other characters jump to avoid
            if self:validateAction({type = "jump"}, player) then
                return {type = "jump"}
            end
        end
    end
    
    -- 2. Opponent Heavy Attack (within range, reaction time window)
    if bb.opponentHeavyStartup and bb.absDistX < PARAM.HEAVY_COUNTER_RANGE then
        local reactionTime = bb.threatDetectedAt.heavyAttack or 999
        -- Wait 0.2 seconds after detecting heavy attack to account for charge up time
        if reactionTime >= 0.2 then
            -- Counter if stamina available
            if self:validateAction({type = "counter", staminaCost = PARAM.STAMINA_COUNTER_COST}, player) then
                return {type = "counter", followUp = {type = "heavyAttack"}}
            end
            -- Else shield
            if self:validateAction({type = "shield"}, player) then
                return {type = "shield", duration = PARAM.HEAVY_SHIELD_HOLD_TIME}
            end
        end
    end
    
    -- 3. Opponent Light Attack (within range)
    if bb.opponentLightAttacking and bb.absDistX < PARAM.LIGHT_BLOCK_RANGE then
        if bb.stamina > 0 and self:validateAction({type = "shield"}, player) then
            return {type = "shield", duration = 0.3}
        end
    end
    
    return nil  -- No interrupt
end

-- Select tactic using utility scoring
function AIController:selectTactic(player, opponent)
    local bb = self.blackboard
    local profile = CharacterProfile[player.characterType] or CharacterProfile.Warrior
    local idealDist = self:getIdealDistance(player.characterType)
    
    local tactics = {}
    
    -- Score each tactic
    -- Approach
    if bb.absDistX > idealDist + PARAM.APPROACH_TOLERANCE then
        local score = 1.0 - (bb.absDistX - idealDist) / 40
        -- All characters should approach when far away
        if bb.absDistX > 40 then
            score = 1.5  -- High priority to approach when very far (all characters)
        elseif bb.absDistX > 20 then
            score = 1.2  -- Good priority when moderately far
        end
        if bb.edgeDistance < PARAM.EDGE_MARGIN and bb.distX > 0 then
            score = score * 0.3  -- Penalize moving toward edge
        end
        tactics.approach = math.max(0, score)
    else
        tactics.approach = 0
    end
    
    -- Retreat
    -- Retreat when stamina < 3 (not just < 2) to prevent stamina loop
    if bb.stamina < 3 or bb.absDistX < idealDist - PARAM.APPROACH_TOLERANCE then
        local score = 0.5
        if bb.stamina < 3 then
            score = score + 0.5  -- Higher priority when low stamina
        end
        if bb.edgeDistance < PARAM.EDGE_MARGIN then
            score = score + 0.3  -- Retreat from edge
        end
        tactics.retreat = score
    else
        tactics.retreat = 0
    end
    
    -- Mage: retreat to create space for heavy attack when at medium range (20-30)
    if player.characterType == "Mage" and bb.absDistX >= 20 and bb.absDistX <= 30 then
        if self:validateAction({type = "heavyAttack", staminaCost = PARAM.STAMINA_HEAVY_COST}, player) then
            local retreatScore = 0.6  -- Moderate priority to retreat and create space
            if tactics.retreat < retreatScore then
                tactics.retreat = retreatScore
            end
        end
    end
    
    -- Heavy Attack
    if self:validateAction({type = "heavyAttack", staminaCost = PARAM.STAMINA_HEAVY_COST}, player) then
        local distScore = 1.0 - math.abs(bb.absDistX - idealDist) / 10
        
        -- Mage: only use heavy attack at long range (> 30), not at close range
        if player.characterType == "Mage" then
            if bb.absDistX > 30 then
                distScore = 0.8  -- Good score for long range heavy attack
            else
                distScore = 0  -- Don't use heavy attack when close (< 30)
            end
        -- Berserker: can use heavy attack at both close and far range (> 30)
        elseif player.characterType == "Berserker" then
            if bb.absDistX > 30 then
                distScore = 0.8  -- Good score for long range heavy attack (occasional use)
            elseif bb.absDistX < idealDist + PARAM.APPROACH_TOLERANCE then
                -- At close range, reduce heavy attack score to encourage light attacks
                distScore = distScore * 0.4  -- Reduce score at close range
            end
        -- Lancer: prefer closer range (8-14 instead of 10-20)
        elseif player.characterType == "Lancer" then
            if profile.preferHeavyAtMid and bb.absDistX > 8 and bb.absDistX < 14 then
                distScore = distScore + 0.5
            end
        elseif profile.preferHeavyAtMid and bb.absDistX > 10 and bb.absDistX < 20 then
            distScore = distScore + 0.5
        end
        
        tactics.attack_heavy = math.max(0, distScore * (1 + profile.aggressiveBias))
    else
        tactics.attack_heavy = 0
    end
    
    -- Light Attack
    if self:validateAction({type = "lightAttack", staminaCost = 2}, player) then
        local distScore = 1.0 - math.abs(bb.absDistX - 6) / 8
        -- Berserker: favor light attacks at close range to avoid predictable heavy attacks
        if player.characterType == "Berserker" and bb.absDistX < idealDist + PARAM.APPROACH_TOLERANCE then
            distScore = distScore * 1.5  -- Boost light attack score at close range
        end
        tactics.attack_light = math.max(0, distScore * (1 + profile.aggressiveBias * 0.5))
    else
        tactics.attack_light = 0
    end
    
    -- Defend
    if bb.absDistX < 10 and self:validateAction({type = "shield"}, player) then
        tactics.defend = 0.3
    else
        tactics.defend = 0
    end
    
    -- Reposition (dash/jump)
    -- Only dash during final approach (close to ideal distance) to avoid excessive dashing
    -- Also prevent dashing when stamina is low (< 3) to prevent stamina loop
    if bb.stamina >= 3 and bb.absDistX < idealDist + 5 and bb.absDistX > idealDist - 2 and bb.characterState.canDash then
        if self:validateAction({type = "dash"}, player) then
            tactics.reposition = 0.4
        else
            tactics.reposition = 0
        end
    else
        tactics.reposition = 0
    end
    
    -- Special (character-specific)
    if player.characterType == "Mage" then
        -- Don't teleport when very far (> 40) - prefer approach instead
        if self.blackboard.cooldowns.teleport <= 0 and bb.absDistX > 10 and bb.absDistX <= 40 then
            tactics.special = 0.6
        else
            tactics.special = 0
        end
    elseif player.characterType == "Lancer" and bb.absDistX > 8 and bb.absDistX < 14 then
        tactics.special = 0.5
    else
        tactics.special = 0
    end
    
    -- Wait (fallback, always available)
    tactics.wait = 0.1
    
    -- Find highest scoring tactic
    local bestTactic = "wait"
    local bestScore = tactics.wait
    
    for tactic, score in pairs(tactics) do
        if score > bestScore then
            bestScore = score
            bestTactic = tactic
        end
    end
    
    return bestTactic
end

-- Execute action
function AIController:executeAction(action, input, player, opponent)
    if not action or not action.type then
        return
    end
    
    -- Validate before execution
    if not self:validateAction(action, player) then
        return
    end
    
    local actionType = action.type
    
    if actionType == "shield" then
        input.shield = true
        self:faceOpponent(input, player, opponent)
    elseif actionType == "counter" then
        -- Edge detection: only set if wasn't pressed last frame
        if not self.prevInput.counter then
            input.counter = true
        end
        self:faceOpponent(input, player, opponent)
    elseif actionType == "move" then
        if action.direction == "toward" then
            self:faceOpponent(input, player, opponent)
        elseif action.direction == "away" then
            local distX = opponent.x - player.x
            input.moveX = (distX > 0) and -1 or 1
        end
    elseif actionType == "dash" then
        -- Edge detection: only set if wasn't pressed last frame
        if not self.prevInput.dash and self.blackboard.characterState.canDash then
            input.dash = true
        end
        if action.direction then
            if action.direction == "toward" then
                self:faceOpponent(input, player, opponent)
            elseif action.direction == "away" then
                local distX = opponent.x - player.x
                input.moveX = (distX > 0) and -1 or 1
            end
        end
    elseif actionType == "jump" then
        input.jump = true
        if action.hold then
            -- Keep jump held (for Mage hover)
        end
        -- If jumping forward as part of approach, also move forward
        if action.direction == "toward" then
            self:faceOpponent(input, player, opponent)
        end
    elseif actionType == "heavyAttack" then
        input.heavyAttack = true
        input.attack = true
        self:faceOpponent(input, player, opponent)
    elseif actionType == "lightAttack" then
        input.lightAttack = true
        input.attack = true
        self:faceOpponent(input, player, opponent)
    elseif actionType == "special" then
        -- Character-specific actions
        if player.characterType == "Mage" then
            -- Mage teleport (dash toward)
            if self.blackboard.cooldowns.teleport <= 0 then
                input.dash = true
                self:faceOpponent(input, player, opponent)
                self.blackboard.cooldowns.teleport = (CharacterProfile.Mage.teleportCooldown or 1.2)
            end
        elseif player.characterType == "Lancer" then
            -- Lancer heavy attack at mid range
            if self:validateAction({type = "heavyAttack", staminaCost = PARAM.STAMINA_HEAVY_COST}, player) then
                input.heavyAttack = true
                input.attack = true
                self:faceOpponent(input, player, opponent)
            end
        end
    end
end

-- Update action queue
function AIController:updateActionQueue(dt, input, player, opponent)
    local queue = self.actionQueue
    
    if queue.activeAction then
        queue.elapsedTime = queue.elapsedTime + dt
        
        -- Check hard cap
        if queue.elapsedTime > PARAM.MAX_ACTION_DURATION then
            queue.activeAction = nil
            queue.elapsedTime = 0
            return
        end
        
        -- Check if action duration exceeded
        if queue.activeAction.duration and queue.elapsedTime >= queue.activeAction.duration then
            -- Action complete, check for follow-up
            if queue.activeAction.followUp then
                queue.activeAction = queue.activeAction.followUp
                queue.activeAction.startTime = 0
                queue.elapsedTime = 0
            else
                queue.activeAction = nil
                queue.elapsedTime = 0
            end
        else
            -- Continue executing current action
            self:executeAction(queue.activeAction, input, player, opponent)
        end
    end
end

--------------------------------------------------------------------------------
-- AIController
--------------------------------------------------------------------------------
function AIController:new()
    local ai = {
        -- Blackboard (state management)
        blackboard = {
            distX = 0,
            distY = 0,
            absDistX = 0,
            stamina = 0,
            health = 0,
            opponentHeavyAttacking = false,
            opponentLightAttacking = false,
            opponentHeavyStartup = false,
            incomingProjectile = nil,  -- { projectile, distance, timeToImpact, urgency, type }
            cooldowns = {
                teleport = 0,
                dash = 0
            },
            edgeDistance = 0,
            characterState = {
                isAttacking = false,
                isDashing = false,
                isHurt = false,
                isStunned = false,
                isLanding = false,
                isCountering = false,
                canDash = true,
                dashPhase = nil
            },
            threatDetectedAt = {
                heavyAttack = nil,
                projectile = nil
            }
        },
        
        -- Action queue
        actionQueue = {
            activeAction = nil,  -- { type, startTime, duration, followUp }
            elapsedTime = 0
        },
        
        -- Approach variation state
        approachVariation = {
            lastVariation = 0,  -- Time since last variation
            variationCooldown = 0.5,  -- Cooldown between variations
            currentDirection = "toward",  -- Current approach direction (toward/away)
            directionChangeTime = 0  -- Time since last direction change
        },
        
        -- Previous input state for edge detection
        prevInput = {
            counter = false,
            dash = false
        },
        
        -- Stage boundaries
        stageLeft = 0,
        stageRight = 128,
        
        -- Legacy fields (will be removed after migration)
        activeSequence = nil,
        activeSequenceName = nil,
        stepIndex = 1,
        stepTime = 0,
        isRespondingToProjectile = false,
        projectileResponseTimer = 0
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

    -- Step 1: Update blackboard (first step, always)
    self:updateBlackboard(dt, player, opponent)
    
    -- Update approach variation cooldown
    self.approachVariation.lastVariation = self.approachVariation.lastVariation + dt
    self.approachVariation.directionChangeTime = self.approachVariation.directionChangeTime + dt
    
    -- Step 2: Check priority interrupts (can preempt any action)
    local interrupt = self:checkPriorityInterrupts(player, opponent)
    if interrupt then
        -- Interrupt current action
        self.actionQueue.activeAction = nil
        self.actionQueue.elapsedTime = 0
        
        -- Set up interrupt action
        interrupt.startTime = 0
        if not interrupt.duration then
            -- Default durations
            if interrupt.type == "shield" then
                interrupt.duration = 0.5
            elseif interrupt.type == "counter" then
                interrupt.duration = 0.6
            elseif interrupt.type == "jump" then
                interrupt.duration = 0.3
            end
        end

        self.actionQueue.activeAction = interrupt
        self:executeAction(interrupt, input, player, opponent)
        
        -- Update previous input state
        self.prevInput.counter = input.counter
        self.prevInput.dash = input.dash
        
        return input
    end
    
    -- Step 3: If no active action, select and execute tactic
    if not self.actionQueue.activeAction then
        local tactic = self:selectTactic(player, opponent)
        
        -- Convert tactic to action
        local action = nil
        if tactic == "approach" then
            -- Vary approach behavior: sometimes dash, sometimes stop, sometimes jump, sometimes walk
            -- Add back-and-forth movement to make approach less predictable
            local bb = self.blackboard
            local variationReady = self.approachVariation.lastVariation >= self.approachVariation.variationCooldown
            local rand = math.random()
            
            -- Determine movement direction with back-and-forth pattern
            local moveDirection = "toward"
            local directionChangeInterval = 0.4  -- Change direction every 0.4 seconds
            if self.approachVariation.directionChangeTime >= directionChangeInterval then
                -- Randomly decide to move away briefly (20% chance when ready to change)
                if rand < 0.2 then
                    moveDirection = "away"
                    self.approachVariation.currentDirection = "away"
                else
                    moveDirection = "toward"
                    self.approachVariation.currentDirection = "toward"
                end
                self.approachVariation.directionChangeTime = 0
            else
                -- Continue in current direction
                moveDirection = self.approachVariation.currentDirection
            end
            
            if variationReady and rand < 0.25 and bb.stamina >= 3 and bb.characterState.canDash and moveDirection == "toward" then
                -- 25% chance: Dash forward (if stamina available and moving toward)
                if self:validateAction({type = "dash"}, player) then
                    action = {type = "dash", direction = "toward", duration = 0.25}
                    self.approachVariation.lastVariation = 0
                else
                    action = {type = "move", direction = moveDirection, duration = 0.3}
                end
            elseif variationReady and rand < 0.45 and moveDirection == "toward" then
                -- 20% chance: Jump forward (only when moving toward)
                if self:validateAction({type = "jump"}, player) then
                    action = {type = "jump", direction = "toward", duration = 0.2}
                    self.approachVariation.lastVariation = 0
                else
                    action = {type = "move", direction = moveDirection, duration = 0.3}
                end
            elseif variationReady and rand < 0.6 then
                -- 15% chance: Stop briefly (wait)
                action = {type = "move", direction = moveDirection, duration = 0.15}
                self.approachVariation.lastVariation = 0
            else
                -- 40% chance: Normal walk (can be toward or away)
                action = {type = "move", direction = moveDirection, duration = 0.3}
                if variationReady then
                    self.approachVariation.lastVariation = 0
                end
            end
        elseif tactic == "retreat" then
            -- Longer retreat duration when stamina is low to prevent stamina loop
            local retreatDuration = 0.3
            if self.blackboard.stamina < 3 then
                retreatDuration = 0.7  -- Longer retreat when low stamina
            end
            action = {type = "move", direction = "away", duration = retreatDuration}
        elseif tactic == "attack_heavy" then
            action = {type = "heavyAttack", staminaCost = PARAM.STAMINA_HEAVY_COST, duration = 0.5}
        elseif tactic == "attack_light" then
            action = {type = "lightAttack", staminaCost = 2, duration = 0.4}
        elseif tactic == "defend" then
            action = {type = "shield", duration = 0.5}
        elseif tactic == "reposition" then
            action = {type = "dash", direction = "toward", duration = 0.25}
        elseif tactic == "special" then
            if player.characterType == "Mage" then
                action = {type = "special", cooldownType = "teleport", duration = 0.4}
            elseif player.characterType == "Lancer" then
                action = {type = "special", duration = 0.5}
            end
        elseif tactic == "wait" then
            action = {type = "move", duration = 0.2}  -- Minimal action
        end
        
        if action then
            action.startTime = 0
            self.actionQueue.activeAction = action
            self.actionQueue.elapsedTime = 0
        end
    end

    -- Step 4: Update action queue (executes current action)
    self:updateActionQueue(dt, input, player, opponent)
    
    -- Update previous input state for edge detection
    self.prevInput.counter = input.counter
    self.prevInput.dash = input.dash
    
    return input
end

-- Old sequence-based methods removed - using new architecture

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

-- Old projectile detection methods removed - now handled in updateBlackboard and checkPriorityInterrupts

return AIController
