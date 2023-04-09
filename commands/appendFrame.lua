-- Creates a new empty frame after the empty frame,
-- but returns to the active frame.

local activeSprite = app.activeSprite
if not activeSprite then return end

local oldActiveFrObj = app.activeFrame --[[@as Frame]]
if oldActiveFrObj then
    local oldActiveFrIdx = oldActiveFrObj.frameNumber
    activeSprite:newEmptyFrame(oldActiveFrIdx + 1)
    app.activeFrame = oldActiveFrIdx
else
    activeSprite:newEmptyFrame()
end