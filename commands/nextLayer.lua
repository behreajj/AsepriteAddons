local stepInto <const> = false

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

-- Preserve range if frames are selected. However, the
-- range could be from another sprite.
---@type integer[]
local rangeFrIdcs <const> = {}
local range <const> = app.range
local isFramesType <const> = range.type == RangeType.FRAMES
local sameSprite <const> = activeSprite == range.sprite
local isValid <const> = isFramesType and sameSprite
if isValid then
    local rangeFrames <const> = range.frames
    local lenRangeFrames <const> = #rangeFrames
    local i = 0
    while i < lenRangeFrames do
        i = i + 1
        rangeFrIdcs[i] = rangeFrames[i].frameNumber
    end
end

local activeLayer <const> = site.layer
if activeLayer then
    local activeParent <const> = activeLayer.parent
    local index <const> = activeLayer.stackIndex
    local parentLayers <const> = activeParent.layers --[=[@as Layer[]]=]
    if index < #parentLayers then
        local nextLayer = parentLayers[index + 1]
        while nextLayer.isGroup
            and #nextLayer.layers > 0
            and (stepInto or nextLayer.isExpanded) do
            nextLayer = nextLayer.layers[1]
        end
        app.layer = nextLayer
    elseif activeParent.__name == "doc::Sprite" then
        app.layer = activeSprite.layers[#activeSprite.layers]
    else
        app.layer = activeParent
    end
else
    app.layer = activeSprite.layers[#activeSprite.layers]
end

if isValid then
    app.range.frames = rangeFrIdcs
end