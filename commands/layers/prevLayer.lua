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
    local rangeFrObjs <const> = range.frames
    local lenRangeFrObjs <const> = #rangeFrObjs
    local i = 0
    while i < lenRangeFrObjs do
        i = i + 1
        rangeFrIdcs[i] = rangeFrObjs[i].frameNumber
    end
end

local activeLayer = site.layer
if activeLayer then
    local stackIndex = activeLayer.stackIndex
    if activeLayer.isGroup
        and #activeLayer.layers > 0
        and (stepInto or activeLayer.isExpanded) then
        app.layer = activeLayer.layers[#activeLayer.layers]
    elseif stackIndex > 1 then
        -- Needed for group layers with no children.
        app.layer = activeLayer.parent.layers[stackIndex - 1]
    ---@diagnostic disable-next-line: undefined-field
    elseif activeLayer.parent.__name == "doc::Sprite" then
        app.layer = activeSprite.layers[1]
    else
        ---@diagnostic disable-next-line: undefined-field
        while activeLayer.__name ~= "doc::Sprite"
            and stackIndex < 2 do
            stackIndex = activeLayer.stackIndex
            activeLayer = activeLayer.parent --[[@as Layer]]
        end

        -- Bottom-most layer in the stack is a group and has one child.
        if stackIndex > 1 then
            app.layer = activeLayer.layers[stackIndex - 1]
        end
    end
else
    app.layer = activeSprite.layers[1]
end

if isValid then
    app.range.frames = rangeFrIdcs
end