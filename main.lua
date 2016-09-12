--[[
A simple sample game for Corona SDK.
http://coronalabs.com

Made by @SergeyLerg.
Licence: MIT.
]]

-- Don't show pesky status bar.
display.setStatusBar(display.HiddenStatusBar)

-- Screen size.
local _W, _H = display.contentWidth, display.contentHeight
-- Screen center coordinates.
local _CX, _CY = _W / 2, _H / 2

-- Add Box 2D support.
local physics = require('physics')
physics.start()
physics.setGravity(0, 20) -- Standard gravity is too boring.

-- List of all colors used in the game.
local colors = {
    {0, 0.5, 0}, -- colors for each tetromino, indices from 1 to 5.
    {0, 0.5, 0.5},
    {0.5, 0, 0.5},
    {0.5, 0, 0},
    {0.5, 0.5, 0},
    cage = {0.6, 0.1, 0.8}, -- colors are in RGB format, 0 - min, 1 - max.
    stroke = {0.9, 1, 1}
}

-- Base layer for all display objects.
local group = display.newGroup()

-- Base size of all objects.
local size = 64
-- Cage width in size units.
local cageWidth = 8
-- List of all tetromino shapes.
local shapes = {
    {{0,0}, {0,1}, {0,2}, {0,3}}, -- line
    {{0,0}, {1,0}, {0,1}, {1,1}}, -- square
    {{0,0}, {-1,1}, {0,1}, {1,1}}, -- bolt
    {{0,0}, {0,1}, {0,2}, {1,2}}, -- L
    {{0,0}, {0,1}, {1,1}, {1,2}} -- zig-zag
}

-- Base object for all tetrominoes - a single rectangle.
local function newPart(params)
    local part = display.newRect(group, params.x, params.y, size - 2, size - 2) -- rectangle display object.
    part:setFillColor(unpack(colors[params.color])) -- fill color, individual for each tetromino.
    part:setStrokeColor(unpack(colors.stroke)) -- stroke color.
    part.strokeWidth = 2

    physics.addBody(part, 'dynamic', {density = 0.2, friction = 1, bounce = 0}) -- add physics to the object.

    -- Touch listener, the object becomes moveable by the player.
    function part:touch(event)
        if event.phase == 'began' then -- when player just touched the object.
            self.joint = physics.newJoint('touch', self, self.x, self.y) -- can't change x,y direclty, need to use the touch joint.
            display.getCurrentStage():setFocus(self)
            self.isFocused = true
        elseif self.isFocused then
            if event.phase == 'moved' then -- when player is moving the object.
                self.joint:setTarget(event.x, event.y) -- joint will drag the object towards these x,y coordinates.
            else -- when player released the object.
                self.joint:removeSelf() -- remove the joint.
                self.joint = nil
                display.getCurrentStage():setFocus()
                self.isFocused = false
            end
        end
        return true
    end
    part:addEventListener('touch')

    return part -- return value is not used, but nice to have.
end

-- Construct a tetromino from individual parts.
local function newTetromino(params)
    local index = math.random(1, #shapes) -- random tetromino shape index
    -- Random mirroring of the tetromino, values are either 1 or -1.
    local mx, my = math.random(0, 1) * 2 - 1, math.random(0, 1) * 2 - 1
    -- Random rotation of the tetromino.
    local isRotated = math.random(0, 1) == 1 and true or false -- ternary conditional, isRotated is either true or false.
    local shape = shapes[index]
    for i = 1, #shape do -- iterate over shape elements.
        local offset = table.copy(shape[i]) -- copy the shape so we don't mess it up with rotation.
        if isRotated then
            offset[1], offset[2] = offset[2], offset[1] -- swap x,y.
        end
        newPart{x = params.x + mx * offset[1] * size, y = params.y + my * offset[2] * size, color = index} -- create an individual part.
    end
end

-- Row lines that check for completeled rows and remove these parts.
local function newRow(params)
    local row = display.newLine(group, 0, params.y, _W, params.y) -- line display object.
    physics.addBody(row, 'static', {isSensor = true}) -- make is a physics sensor that only listens for collisions.
    row.isVisible = false -- make the line invisible.

    -- Internal list of all parts that collide with the current row.
    local list = {}
    function row:check()
        if #list == cageWidth then -- row is full.
            -- Need to add a slight delay for the physics engine to work correctly.
            timer.performWithDelay(1, function()
                -- Delete all parts for the current row.
                for i = #list, 1, -1 do
                    display.remove(list[i])
                    table.remove(list, i)
                end
            end)
        end
    end
    -- Find a part in the internal list.
    function row:indexOf(object)
        for i = 1, #list do
            if list[i] == object then
                return i
            end
        end
    end
    -- Add a part to the internal list.
    function row:add(object)
        if not self:indexOf(object) then
            table.insert(list, object)
        end
    end
    -- Remove a part from the internal list.
    function row:remove(object)
        local index = self:indexOf(object)
        if index then
            table.remove(list, index)
        end
    end

    -- Physics collision event.
    function row:collision(event)
        if event.phase == 'began' then -- part is colliding with the row line.
            self:add(event.other)
            self:check()
        else -- part is no more colliding with the row line.
            self:remove(event.other)
        end
    end
    row:addEventListener('collision')

    return row -- return value is not used, but nice to have.
end

-- Borders of the gameplay area.
local function newCage()
    local cageBodyParams = {bounce = 0.2, friction = 0.1} -- all borders share same physics properties.

    -- Bottom border.
    local floor = display.newRect(group, _CX, _H - size / 2, _W, size)
    floor:setFillColor(unpack(colors.cage))
    floor:setStrokeColor(unpack(colors.stroke))
    floor.strokeWidth = 2
    physics.addBody(floor, 'static', cageBodyParams)

    -- Left border.
    local leftWall = display.newRect(group, _CX - size * cageWidth / 2, _CY, size, _H)
    leftWall:setFillColor(unpack(colors.cage))
    leftWall:setStrokeColor(unpack(colors.stroke))
    leftWall.strokeWidth = 2
    leftWall.anchorX = 1
    physics.addBody(leftWall, 'static', cageBodyParams)

    -- Right botder.
    local rightWall = display.newRect(group, _CX + size * cageWidth / 2, _CY, size, _H)
    rightWall:setFillColor(unpack(colors.cage))
    rightWall:setStrokeColor(unpack(colors.stroke))
    rightWall.strokeWidth = 2
    rightWall.anchorX = 0
    physics.addBody(rightWall, 'static', cageBodyParams)

    -- Add row lines to check for completed rows.
    for y = floor.y - size, 0, -size do
        newRow{y = y}
    end
end

-- Random start value depends on the current time value.
math.randomseed(os.time())
-- Create the play area.
newCage()

-- Create the first tetromino.
newTetromino{x = _CX, y = _H * 0.1}

-- Create tetrominoes indefinitely each second.
timer.performWithDelay(1000, function()
    -- Position is random around the x center of the screen.
    newTetromino{x = math.random(_CX - size * 2, _CX + size * 2), y = -size * 2}
end, 0)
