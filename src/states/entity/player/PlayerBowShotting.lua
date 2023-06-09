--[[
    ISPPJ1 2023
    Study Case: The Legend of the Princess (ARPG)

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Modified by Kevin Márquez (marquezberrioskgmail@gmail.com) for academic purpose.

    Modified by Lewis Ochoa (lewis8a@gmail.com) for academic purpose.

    This file contains the class PlayerBowShotting.
]]
PlayerBowShotting = Class{__includes = BaseState}

function PlayerBowShotting:init(player, dungeon)
    self.player = player
    self.player.bow['dungeon'] = dungeon

    -- render offset for spaced character sprite
    self.player.offsetY = 5
    self.player.offsetX = 8

    self.player:changeAnimation('bow-' .. self.player.direction)
end

function PlayerBowShotting:enter(params)
    SOUNDS['flying-arrow']:stop()
    SOUNDS['flying-arrow']:play()
    SOUNDS['shoot-arrow']:stop()
    SOUNDS['shoot-arrow']:play()

    -- restart bow swing animation
    self.player.currentAnimation:refresh()
end

function PlayerBowShotting:update(dt)
    self.player.bow:update(dt)
    
    if self.player.currentAnimation.timesPlayed > 0 then
        self.player.currentAnimation.timesPlayed = 0
        self.player.bow:shot()
        self.player:changeState('idle')
    end

    if love.keyboard.wasPressed('d') and self.player.bow ~= nil then
        self.player:changeState('shot-bow')
    elseif love.keyboard.wasPressed('space') then
        self.player:changeState('swing-sword')
    end
end

function PlayerBowShotting:render()
    self.player.bow:render()
end