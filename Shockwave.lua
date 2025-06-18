-- Shockwave.lua
local anim8 = require("libraries.anim8")

local Shockwave = {}
Shockwave.__index = Shockwave

function Shockwave:new(x, y, direction, damage, sender)
    local instance = setmetatable({}, Shockwave)
    instance.x         = x
    instance.y         = y
    instance.direction = direction
    instance.speed     = 50            -- pixels/sec
    instance.damage    = damage
    instance.sender    = sender        -- Reference to the player who sent this shockwave
    instance.active    = true

    -- load your 2-frame sheet 
    instance.spriteSheet = love.graphics.newImage("assets/sprites/Shockwave.png")
    instance.width  = 8
    instance.height = 8
    local fw, fh = instance.width, instance.height

    -- create grid. Sprites are 8x8, 2 frames in a single row.
    -- there is a 1 pixel border around the sprites to avoid artifacts.
    instance.spriteSheet:setFilter("nearest", "nearest")  -- for pixel art
    instance.grid = anim8.newGrid(fw, fh,
        instance.spriteSheet:getWidth(),
        instance.spriteSheet:getHeight(),
        1, 1  -- offset for the border
    )  
    instance.anim = anim8.newAnimation(instance.grid("1-2",1), 0.1)

    return instance
end

function Shockwave:update(dt)
    self.x = self.x + self.speed * self.direction * dt
    self.anim:update(dt)
    -- deactivate once off-screen
    if self.x < -self.width or self.x > GameInfo.gameWidth + self.width then
        self.active = false
    end
end

function Shockwave:draw()
    self.anim:draw(self.spriteSheet, self.x, self.y, 0, self.direction, 1)
end

function Shockwave:getHitbox()
    local w = self.width - 1
    local h = self.height - 5

    -- If we're facing right, draw+hitbox both start at self.x.
    -- If we're facing left, the drawn sprite actually spans [self.x - width .. self.x],
    -- so we must also shift the hitbox left by its own width.
    local hx = (self.direction == 1) and self.x or (self.x - w)

    return {
      x      = hx,
      y      = self.y,
      width  = w,
      height = h
    }
end

function Shockwave:checkHit(target)
    local hb = self:getHitbox()
    local th = target:getHurtbox()
    return hb.x < th.x + th.width
       and hb.x + hb.width > th.x
       and hb.y < th.y + th.height
       and hb.y + hb.height > th.y
end

function Shockwave:reverseDirection(newSender)
    self.direction = -self.direction
    self.sender = newSender
end

return Shockwave
