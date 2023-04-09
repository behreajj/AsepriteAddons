-- Numpad 4 keybind doesn't work when a selection is active.

local activeSprite = app.activeSprite
if not activeSprite then return end

-- Preserve range if frames are selected. However, the
-- range could be from another sprite.
---@type Layer[]
local newRangeLayers = {}
local range = app.range
local isLayersType = range.type == RangeType.LAYERS
local sameSprite = activeSprite == range.sprite
local isValid = isLayersType and sameSprite
if isValid then
    local oldRangeLayers = range.layers
    local lenRangeLayers = #oldRangeLayers
    local i = 0
    while i < lenRangeLayers do
        i = i + 1
        newRangeLayers[i] = oldRangeLayers[i]
    end
end

local activeFrame = app.activeFrame --[[@as Frame]]
if activeFrame then
    -- Modulo arithmetic is easier to understand when index starts at 0.
    local frameNo = activeFrame.frameNumber - 1
    local lenFrames = #activeSprite.frames
    if app.preferences.editor.play_once then
        app.activeFrame = activeSprite.frames[1
            + math.min(math.max(frameNo - 1, 0), lenFrames - 1)]
    else
        app.activeFrame = activeSprite.frames[1 + (frameNo - 1) % lenFrames]
    end
else
    app.activeFrame = activeSprite.frames[1]
end

if isValid then
    app.range.layers = newRangeLayers
end