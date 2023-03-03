dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if not activeSprite then return end

local sprBounds = activeSprite.bounds
local images = app.range.images
local lenImages = #images
local union = Selection()
local selectCel = AseUtilities.selectCel

local i = 0
while i < lenImages do
    i = i + 1
    union:add(selectCel(
        images[i].cel, sprBounds))
end

activeSprite.selection = union