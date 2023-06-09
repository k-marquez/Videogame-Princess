--[[
    ISPPJ1 2023
    Study Case: The Legend of the Princess (ARPG)

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Modified by Alejandro Mujica (alejandro.j.mujic4@gmail.com) for teaching purpose.

    Modified by Kevin Márquez (marquezberriosk@gmail.com) for academic purpose.

    This file contains the class Room.
]]
Room = Class{}

function Room:init(player, create_boss_room)
    -- reference to player for collisions, etc.
    self.player = player

    self.width = MAP_WIDTH
    self.height = MAP_HEIGHT

    self.tiles = {}
    self:generateWallsAndFloors()

    -- entities in the room
    self.entities = {}
    
    -- game objects in the room
    self.objects = {}

    -- bow flag
    self.spwan_bow = true

    -- doorways that lead to other dungeon rooms
    self.doorways = {}
    
    -- used for centering the dungeon rendering
    self.renderOffsetX = MAP_RENDER_OFFSET_X
    self.renderOffsetY = MAP_RENDER_OFFSET_Y

    -- used for drawing when this room is the next room, adjacent to the active
    self.adjacentOffsetX = 0
    self.adjacentOffsetY = 0

    -- projectiles
    self.projectiles = {}
    self.boss_projectiles = {}

    self.boss_room = create_boss_room

    -- If new room isn't a boss room, create entities and objects
    if not self.boss_room then
        self:generateEntities()
        self:generateObjects()
        table.insert(self.doorways, Doorway('top', false, self))
        table.insert(self.doorways, Doorway('bottom', false, self))
        table.insert(self.doorways, Doorway('left', false, self))
        table.insert(self.doorways, Doorway('right', false, self))
    end
end

function Room:create_boss()
    local boss_x = 0
    local boss_y = 0
    if self.player.direction == 'left' then
        boss_x = MAP_RENDER_OFFSET_X + 20
        boss_y = MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2) * TILE_SIZE - TILE_SIZE
        table.insert(self.doorways, Doorway('right', false, self))
    elseif self.player.direction == 'right' then
        boss_x = MAP_RENDER_OFFSET_X + (MAP_WIDTH * TILE_SIZE) - TILE_SIZE - 20
        boss_y = MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2 * TILE_SIZE) - TILE_SIZE
        table.insert(self.doorways, Doorway('left', false, self))
    elseif self.player.direction == 'up' then
        boss_x = MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2 * TILE_SIZE) - TILE_SIZE
        boss_y = MAP_RENDER_OFFSET_Y + 20
        table.insert(self.doorways, Doorway('bottom', false, self))
    else
        boss_x = MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2 * TILE_SIZE) - TILE_SIZE
        boss_y = MAP_RENDER_OFFSET_Y + (MAP_HEIGHT * TILE_SIZE) - TILE_SIZE - 20
        table.insert(self.doorways, Doorway('top', false, self))
    end
    table.insert(self.entities, Boss {
        animations = ENTITY_DEFS['boss'].animations,
        walkSpeed = ENTITY_DEFS['boss'].walkSpeed,
        
        type = 'boss',

        x = boss_x,
        y = boss_y,

        width = 14,
        height = 25,

        -- one heart == 2 health
        health = 15,

        -- rendering and collision offset for spaced sprites
        offsetY = 5,

        -- atributes necessary for functionality of boss
        room = self,
        player = self.player
    })

    self.entities[1].stateMachine = StateMachine {
        ['walk'] = function() return EntityWalkState(self.entities[1]) end,
        ['idle'] = function() return EntityIdleState(self.entities[1]) end
    }

    self.entities[1]:changeState('walk')
end

function Room:update(dt)
    -- don't update anything if we are sliding to another room (we have offsets)
    if self.adjacentOffsetX ~= 0 or self.adjacentOffsetY ~= 0 then return end

    self.player:update(dt)

    for i = #self.entities, 1, -1 do
        local entity = self.entities[i]

        -- remove entity from the table if health is <= 0
        if entity.health <= 0 then
            entity.dead = true
            -- chance to drop a heart
            if not entity.dropped and math.random(10) == 1 then
                table.insert(self.objects, GameObject(GAME_OBJECT_DEFS['heart'], entity.x, entity.y))
            end
            -- whether the entity dropped or not, it is assumed that it dropped
            entity.dropped = true
        elseif not entity.dead then
            entity:processAI({room = self}, dt)
            entity:update(dt)
        end

        -- collision between the player and entities in the room
        if not entity.dead and self.player:collides(entity) and not self.player.invulnerable then
            SOUNDS['hit-player']:play()
            if entity.type == 'boss' then
                self.player:damage(2)
            else
                self.player:damage(1)
            end 
            self.player:goInvulnerable(1.5)

            if self.player.health == 0 then
                stateMachine:change('game-over')
            end
        end
    end

    for k, object in pairs(self.objects) do
        object:update(dt)

        -- trigger collision callback on object
        if self.player:collides(object) then
            object:onCollide()

            if object.solid and not object.taken then
                local playerY = self.player.y + self.player.height / 2
                local playerHeight = self.player.height - self.player.height / 2
                local playerRight = self.player.x + self.player.width
                local playerBottom = playerY + playerHeight
                
                if self.player.direction == 'left' and not (playerY >= (object.y + object.height)) and not (playerBottom <= object.y) then
                    self.player.x = object.x + object.width
                elseif self.player.direction == 'right' and not (playerY >= (object.y + object.height)) and not (playerBottom <= object.y) then 
                    self.player.x = object.x - self.player.width
                elseif self.player.direction == 'down' and not (self.player.x >= (object.x + object.width)) and not (playerRight <= object.x) then
                    self.player.y = object.y - self.player.height
                elseif self.player.direction == 'up' and not (self.player.x >= (object.x + object.width)) and not (playerRight <= object.x) then
                    self.player.y = object.y + object.height - self.player.height/2
                end
            end

            if object.consumable then
                object.onConsume(self.player, object)
                table.remove(self.objects, k)
            end
        end
    end

    for k, projectile in pairs(self.projectiles) do
        projectile:update(dt)

        -- check collision with entities
        for e, entity in pairs(self.entities) do
            if projectile.dead then
                break
            end

            if not entity.dead and projectile:collides(entity) then
                if entity.type == 'boss' then
                    entity:goInvulnerable(3)
                    SOUNDS['hit-enemy']:play()
                else
                    entity:damage(1)
                    SOUNDS['hit-enemy']:play()
                    projectile.dead = true
                end
            end
        end

        if projectile.dead then
            table.remove(self.projectiles, k)
        end
    end

    for k, projectile in pairs(self.boss_projectiles) do
        projectile:update(dt)

        -- check collision with player
        if not projectile.dead then
            if not self.player.dead and projectile:collides(self.player) then
                SOUNDS['hit-player']:play()
                projectile.dead = true
                self.player:kill()
                stateMachine:change('game-over')
            end
        else
            table.remove(self.boss_projectiles, k)
        end
    end
end

--[[
    Generates the walls and floors of the room, randomizing the various varieties
    of said tiles for visual variety.
]]
function Room:generateWallsAndFloors()
    for y = 1, self.height do
        table.insert(self.tiles, {})

        for x = 1, self.width do
            local id = TILE_EMPTY

            if x == 1 and y == 1 then
                id = TILE_TOP_LEFT_CORNER
            elseif x == 1 and y == self.height then
                id = TILE_BOTTOM_LEFT_CORNER
            elseif x == self.width and y == 1 then
                id = TILE_TOP_RIGHT_CORNER
            elseif x == self.width and y == self.height then
                id = TILE_BOTTOM_RIGHT_CORNER
            
            -- random left-hand walls, right walls, top, bottom, and floors
            elseif x == 1 then
                id = TILE_LEFT_WALLS[math.random(#TILE_LEFT_WALLS)]
            elseif x == self.width then
                id = TILE_RIGHT_WALLS[math.random(#TILE_RIGHT_WALLS)]
            elseif y == 1 then
                id = TILE_TOP_WALLS[math.random(#TILE_TOP_WALLS)]
            elseif y == self.height then
                id = TILE_BOTTOM_WALLS[math.random(#TILE_BOTTOM_WALLS)]
            else
                id = TILE_FLOORS[math.random(#TILE_FLOORS)]
            end
            
            table.insert(self.tiles[y], {
                id = id
            })
        end
    end
end

--[[
    Randomly creates an assortment of enemies for the player to fight.
]]
function Room:generateEntities()
    local types = {'skeleton', 'slime', 'bat', 'ghost', 'spider'}

    for i = 1, 10 do
        local type_off = types[math.random(#types)]

        table.insert(self.entities, Entity {
            animations = ENTITY_DEFS[type_off].animations,
            walkSpeed = ENTITY_DEFS[type_off].walkSpeed or 20,

            -- ensure X and Y are within bounds of the map
            x = math.random(MAP_RENDER_OFFSET_X + TILE_SIZE,
                VIRTUAL_WIDTH - TILE_SIZE * 2 - 16),
            y = math.random(MAP_RENDER_OFFSET_Y + TILE_SIZE,
                VIRTUAL_HEIGHT - (VIRTUAL_HEIGHT - MAP_HEIGHT * TILE_SIZE) + MAP_RENDER_OFFSET_Y - TILE_SIZE - 16),

            type = type_off,

            width = 16,
            height = 16,

            health = 1
        })

        self.entities[i].stateMachine = StateMachine {
            ['walk'] = function() return EntityWalkState(self.entities[i]) end,
            ['idle'] = function() return EntityIdleState(self.entities[i]) end
        }

        self.entities[i]:changeState('walk')
    end
end

--[[
    Randomly creates an assortment of obstacles for the player to navigate around.
]]
function Room:generateObjects()
    table.insert(self.objects, GameObject(
        GAME_OBJECT_DEFS['switch'],
        math.random(MAP_RENDER_OFFSET_X + TILE_SIZE,
                    VIRTUAL_WIDTH - TILE_SIZE * 2 - 16),
        math.random(MAP_RENDER_OFFSET_Y + TILE_SIZE,
                    VIRTUAL_HEIGHT - (VIRTUAL_HEIGHT - MAP_HEIGHT * TILE_SIZE) + MAP_RENDER_OFFSET_Y - TILE_SIZE - 16)
    ))

    if math.random() < PROBABILITY_SPAWN_CHESS and self.player.bow == nil then
        table.insert(self.objects, GameObject(
            GAME_OBJECT_DEFS['chess'],
            math.random(MAP_RENDER_OFFSET_X + TILE_SIZE,
                        VIRTUAL_WIDTH - TILE_SIZE * 2 - 16),
            math.random(MAP_RENDER_OFFSET_Y + TILE_SIZE,
                        VIRTUAL_HEIGHT - (VIRTUAL_HEIGHT - MAP_HEIGHT * TILE_SIZE) + MAP_RENDER_OFFSET_Y - TILE_SIZE - 60)
        ))
    
        -- get a reference to the switch
        local chess = self.objects[2]

        -- define a function for the switch that will open all doors in the room
        chess.onCollide = function()
            if chess.state == 'closed' then
                chess.state = 'opened'
                
                if self.spwan_bow then
                    self.spwan_bow = false
                    table.insert(self.objects, GameObject(
                        GAME_OBJECT_DEFS['bow-takeable'],
                        chess.x + 5,
                        chess.y
                    ))

                    local bow = nil

                    for i = 1, #self.objects do
                        if self.objects[i].type == 'bow-takeable' then
                            bow = self.objects[i]
                        end
                    end

                    local toTween = {
                        [bow] = {y = bow.y + 16}
                    }

                    Timer.tween(1, toTween):finish(function()
                        bow.consumable = true
                    end)
                end

                SOUNDS['trunk']:play()
            end
        end
    end

    -- get a reference to the switch
    local switch = self.objects[1]

    -- define a function for the switch that will open all doors in the room
    switch.onCollide = function()
        if switch.state == 'unpressed' then
            switch.state = 'pressed'
            
            -- open every door in the room if we press the switch
            for k, doorway in pairs(self.doorways) do
                doorway.open = true
            end

            SOUNDS['door']:play()
        end
    end

    for y = 2, self.height -1 do
        for x = 2, self.width - 1 do
            -- change to spawn a pot
            if math.random(20) == 1 then
                table.insert(self.objects, GameObject(
                    GAME_OBJECT_DEFS['pot'], x*16, y*16
                ))
            end
        end
    end
end

function Room:render()
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self.tiles[y][x]
            love.graphics.draw(TEXTURES['tiles'], FRAMES['tiles'][tile.id],
                (x - 1) * TILE_SIZE + self.renderOffsetX + self.adjacentOffsetX, 
                (y - 1) * TILE_SIZE + self.renderOffsetY + self.adjacentOffsetY)
        end
    end

    -- render doorways; stencils are placed where the arches are after so the player can
    -- move through them convincingly
    for k, doorway in pairs(self.doorways) do
        doorway:render(self.adjacentOffsetX, self.adjacentOffsetY)
    end

    for k, object in pairs(self.objects) do
        object:render(self.adjacentOffsetX, self.adjacentOffsetY)
    end

    for k, entity in pairs(self.entities) do
        if not entity.dead then entity:render(self.adjacentOffsetX, self.adjacentOffsetY) end
    end

    -- stencil out the door arches so it looks like the player is going through
    love.graphics.stencil(function()
        -- left
        love.graphics.rectangle('fill', -TILE_SIZE - 6, MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2) * TILE_SIZE - TILE_SIZE * 2,
            TILE_SIZE * 2 + 6, TILE_SIZE * 3)
        
        -- right
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH * TILE_SIZE) - 6,
            MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2) * TILE_SIZE - TILE_SIZE * 2, TILE_SIZE * 2 + 6, TILE_SIZE * 3)
        
        -- top
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2) * TILE_SIZE - TILE_SIZE,
            -TILE_SIZE - 6, TILE_SIZE * 2, TILE_SIZE * 2 + 12)
        
        --bottom
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2) * TILE_SIZE - TILE_SIZE,
            VIRTUAL_HEIGHT - TILE_SIZE - 6, TILE_SIZE * 2, TILE_SIZE * 2 + 12)
    end, 'replace', 1)

    love.graphics.setStencilTest('less', 1)

    if self.player then
        self.player:render()
    end

    for k, projectile in pairs(self.projectiles) do
        projectile:render()
    end

    for k, projectile in pairs(self.boss_projectiles) do
        projectile:render()
    end

    love.graphics.setStencilTest()
end
