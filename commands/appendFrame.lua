-- Creates a new empty frame after the empty frame,
-- but returns to the active frame.

local site = app.site
local activeSprite = site.sprite
if not activeSprite then return end

local oldActiveFrObj = site.frame
if oldActiveFrObj then
    local oldActiveFrIdx = oldActiveFrObj.frameNumber
    activeSprite:newEmptyFrame(oldActiveFrIdx + 1)
    app.activeFrame = oldActiveFrObj
else
    activeSprite:newEmptyFrame()
end