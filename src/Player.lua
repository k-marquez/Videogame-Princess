--[[
    ISPPJ1 2023
    Study Case: The Legend of the Princess (ARPG)

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Modified by Alejandro Mujica (alejandro.j.mujic4@gmail.com) for teaching purpose.

    Modified by Kevin Márquez (marquezberriosk@gmail.com) for academic purpose.

    Modified by Lewis Ochoa (lewis8a@gmail.com) for academic purpose.

    This file contains the class Player.
]]
Player = Class{__includes = Entity}

function Player:init(def)
    Entity.init(self, def)
    self.bow = nil
    self.has_bow = false
end

function Player:take_bow()
    if not self.has_bow then
        self.has_bow = true
        self.bow = Bow{definition_obj = GAME_OBJECT_DEFS['bow'], player = self}
    end
end

function Player:update(dt)
    Entity.update(self, dt)
end

function Player:collides(target)
    local selfY, selfHeight = self.y + self.height / 2, self.height - self.height / 2
    
    return not (self.x + self.width < target.x or self.x > target.x + target.width or
                selfY + selfHeight < target.y or selfY > target.y + target.height)
end

function Player:render()
    Entity.render(self)
    -- love.graphics.setColor(love.math.colorFromBytes(255, 0, 255, 255))
    -- love.graphics.rectangle('line', self.x, self.y, self.width, self.height)
    -- love.graphics.setColor(love.math.colorFromBytes(255, 255, 255, 255))
end

function Player:kill()
    self.dead = true
    
end