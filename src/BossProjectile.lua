--[[
    ISPPJ1 2023
    Study Case: The Legend of the Princess (ARPG)

    Author: Alejandro Mujica
    alejandro.j.mujic4@gmail.com

    This file contains the class Boss Projectile.
]]

BossProjectile = Class{__includes = Projectile}

function BossProjectile:init(def)
    Projectile.init(self, def.obj, "up")
    self.end_x = def.x
    self.end_y = def.y
    self.dead = false
    self.index_anim = 1
    self.boss = def.boss

    local toTween = {
        [self.obj] = {x = self.end_x, y = self.end_y}
    }

    -- for move the projectile
    Timer.tween(2, toTween):finish(function()
        self.boss.fire = false
    end)

    SOUNDS['fire-long']:play()
end

function BossProjectile:update(dt)
    if self.dead then
        return
    end

    if self.end_x == self.obj.x and self.end_y == self.obj.y then
        self.dead = true
    end

    if self.dead then
        SOUNDS['fire-short']:play()
        return
    end
end

function BossProjectile:render()
    love.graphics.draw(
        TEXTURES[self.obj.texture],
        FRAMES[self.obj.texture][self.obj.frame],
        self.obj.x,
        self.obj.y)

    self.index_anim = self.index_anim + 1

    if self.index_anim == 8 then
        self.index_anim = 1
    end
end