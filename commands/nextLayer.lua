local stepInto = false

local activeSprite = app.activeSprite
if not activeSprite then return end

-- Preserve range if frames are selected.
local range = app.range
local isFramesType = range.type == RangeType.FRAMES
local rangeFrIdcs = {}
if isFramesType then
    local rangeFrames = range.frames --[[@as Frame[] ]]
    local lenRangeFrames = #rangeFrames
    local i = 0
    while i < lenRangeFrames do
        i = i + 1
        rangeFrIdcs[i] = rangeFrames[i].frameNumber
    end
end

local activeLayer = app.activeLayer
if activeLayer then
    local activeParent = activeLayer.parent
    local index = activeLayer.stackIndex
    local parentLayers = activeParent.layers
    if index < #parentLayers then
        local nextLayer = parentLayers[index + 1]
        while nextLayer.isGroup
            and #nextLayer.layers > 0
            and (stepInto or nextLayer.isExpanded) do
            nextLayer = nextLayer.layers[1]
        end
        app.activeLayer = nextLayer
    elseif activeParent.__name == "doc::Sprite" then
        app.activeLayer = activeSprite.layers[#activeSprite.layers]
    else
        app.activeLayer = activeParent
    end
else
    app.activeLayer = activeSprite.layers[#activeSprite.layers]
end

if isFramesType then
    app.range.frames = rangeFrIdcs
end