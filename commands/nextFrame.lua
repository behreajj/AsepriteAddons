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
    local frameNo <const> = activeFrame.frameNumber - 1
    local lenFrames <const> = #activeSprite.frames
    if app.preferences.editor.play_once then
        app.activeFrame = activeSprite.frames[1
        + math.min(math.max(frameNo + 1, 0), lenFrames - 1)]
    else
        app.activeFrame = activeSprite.frames[1 + (frameNo + 1) % lenFrames]
    end
else
    app.activeFrame = activeSprite.frames[1]
end

if isValid then
    app.range.layers = newRangeLayers
end