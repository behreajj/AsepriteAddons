-- Numpad 6 keybind doesn't work when a selection is active.

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

-- Preserve range if frames are selected. However, the
-- range could be from another sprite.
---@type Layer[]
local newRangeLayers <const> = {}
local range <const> = app.range
local isLayersType <const> = range.type == RangeType.LAYERS
local sameSprite <const> = activeSprite == range.sprite
local isValid <const> = isLayersType and sameSprite
if isValid then
    local oldRangeLayers <const> = range.layers
    local lenRangeLayers <const> = #oldRangeLayers
    local i = 0
    while i < lenRangeLayers do
        i = i + 1
        newRangeLayers[i] = oldRangeLayers[i]
    end
end

local activeFrame <const> = site.frame
if activeFrame then
    -- Modulo arithmetic is easier to understand when index starts at 0.
    local frIdx <const> = activeFrame.frameNumber - 1
    local lenFrObjs <const> = #activeSprite.frames
    if app.preferences.editor.play_once then
        app.frame = activeSprite.frames[1
        + math.min(math.max(frIdx + 1, 0), lenFrObjs - 1)]
    else
        app.frame = activeSprite.frames[1 + (frIdx + 1) % lenFrObjs]
    end
else
    app.frame = activeSprite.frames[1]
end

if isValid then
    app.range.layers = newRangeLayers
end