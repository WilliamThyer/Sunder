-- heavyAttackMissile.lua
local anim8 = require("libraries.anim8")

local heavyAttackMissile = {}
heavyAttackMissile.__index = heavyAttackMissile

-- cache tables shared by all instances
local spriteSheets = {}
local grids        = {}

-- helper: ensure resources for a given color
local function ensureResources(colorName)
    if not spriteSheets[colorName] then
        local file = "assets/sprites/Mage" .. colorName .. ".png"
        if not love.filesystem.getInfo(file) then
            file = "assets/sprites/MageBlue.png"  -- fallback to default sprite
        end
        -- Load the sprite sheet and create grids for animations:
        local spriteSheet = love.graphics.newImage(file)
        local grid = anim8.newGrid(12, 12, spriteSheet:getWidth(), spriteSheet:getHeight(), 0, 0, 1)

        -- load once
        spriteSheets[colorName] = spriteSheet
        grids       [colorName] = grid
    end
end

function heavyAttackMissile:new(x, y, dir, damage, colorName, world)
    -- make sure our texture & grid are loaded
    ensureResources(colorName)

    local o = setmetatable({}, self)
    o.x      = x
    o.y      = y
    o.dir    = dir
    o.speed  = 70
    o.damage = damage or 1
    o.active = true
    o.world  = world  -- Store reference to bump world

    -- just reference the cached img & grid
    o.spriteSheet = spriteSheets[colorName]
    o.grid        = grids       [colorName]
    o.anim        = anim8.newAnimation(o.grid(5,'5-6'), 0.05)

    -- Don't add to bump world - missiles shouldn't be physical objects
    o.width = 8   -- Missile hitbox width for collision detection
    o.height = 8  -- Missile hitbox height for collision detection

    return o
end

function heavyAttackMissile:update(dt)
    if not self.active then return end
    
    -- Calculate goal position
    local goalX = self.x + self.speed * self.dir * dt
    local goalY = self.y
    
    -- Check for wall collisions using bump's query functions
    if self.world then
        -- Query for any objects at the goal position
        local items, len = self.world:queryRect(goalX, goalY, self.width, self.height)
        
        -- Check if any of the items are walls (not players)
        for i = 1, len do
            local item = items[i]
            if not item.isPlayer then
                -- Hit a wall, deactivate missile
                self.active = false
                break
            end
        end
        
        -- If no wall collision, move to goal position
        if self.active then
            self.x = goalX
            self.y = goalY
        end
    else
        -- Fallback to simple movement if no world
        self.x = goalX
    end
    
    self.anim:update(dt)
end

function heavyAttackMissile:draw()
    if not self.active then return end

    -- flip horizontally around its own center
    local fw = self.grid.frameWidth    -- e.g. 8
    local sx = self.dir                -- 1 or -1
    -- when flipped we must offset by frame‐width so it still comes from the same spot
    local ox = (sx < 0) and fw or 0

    -- anim8:draw(image, x, y,  r,  sx, sy, ox, oy)
    --   here we pass ox=ox, oy=0 so the sprite flips in place
    self.anim:draw(
      self.spriteSheet,
      self.x + ox,
      self.y,
      0,
      sx, 1,
      0, 0
    )
end

function heavyAttackMissile:checkHit(target)
    if not self.active then return false end
    if self.x < target.x + target.width
    and self.x + 8 > target.x
    and self.y < target.y + target.height
    and self.y + 8 > target.y then
        -- Check if target is countering
        if target.isCountering and target.counterActive then
            -- Only allow counter if defender is facing the missile
            local isFacingMissile = (target.direction == 1 and self.x > target.x) or 
                                  (target.direction == -1 and self.x < target.x)
            if isFacingMissile then
                target:triggerSuccessfulCounter(self)
                return "countered"
            end
        end
        return "hit"
    end
    return false
end

return heavyAttackMissile
