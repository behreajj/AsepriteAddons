local stepInto = false

local site = app.site
local activeSprite = site.sprite
if not activeSprite then return end

-- Preserve range if frames are selected. However, the
-- range could be from another sprite.
---@type integer[]
local rangeFrIdcs = {}
local range = app.range
local isFramesType = range.type == RangeType.FRAMES
local sameSprite = activeSprite == range.sprite
local isValid = isFramesType and sameSprite
if isValid then
    local rangeFrames = range.frames --[=[@as Frame[]]=]
    local lenRangeFrames = #rangeFrames
    local i = 0
    while i < lenRangeFrames do
        i = i + 1
        rangeFrIdcs[i] = rangeFrames[i].frameNumber
    end
end

local activeLayer = site.layer --[[@as userdata]]
if activeLayer then
    local stackIndex = activeLayer.stackIndex
    if activeLayer.isGroup
        and #activeLayer.layers > 0
        and (stepInto or activeLayer.isExpanded) then
        app.activeLayer = activeLayer.layers[#activeLayer.layers]
    elseif stackIndex > 1 then
        -- Needed for group layers with no children.
        app.activeLayer = activeLayer.parent.layers[stackIndex - 1]
    elseif activeLayer.parent.__name == "doc::Sprite" then
        app.activeLayer = activeSprite.layers[1]
    else
        while activeLayer.__name ~= "doc::Sprite"
            and stackIndex < 2 do
            stackIndex = activeLayer.stackIndex
            activeLayer = activeLayer.parent
        end

        -- Bottom-most layer in the stack is a group and has one child.
        if stackIndex > 1 then
            app.activeLayer = activeLayer.layers[stackIndex - 1]
        end
    end
else
    app.activeLayer = activeSprite.layers[1]
end

if isValid then
    app.range.frames = rangeFrIdcs
end