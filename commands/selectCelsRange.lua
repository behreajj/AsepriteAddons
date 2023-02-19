dofile("../support/aseutilities.lua")

local activeSprite = app.activeSprite
if not activeSprite then return end

local spriteBounds = activeSprite.bounds

local appRange = app.range
local imgsRange = appRange.images
local lenImgsRange = #imgsRange

local union = Selection()

local i = 0
while i < lenImgsRange do
    i = i + 1
    local image = imgsRange[i]
    local cel = image.cel
    local select = AseUtilities.selectCel(
        cel, spriteBounds)
    union:add(select)
end

activeSprite.selection = union

app.refresh()
app.command.Refresh()