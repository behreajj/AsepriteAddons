local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local oldActiveFrObj <const> = site.frame
if oldActiveFrObj then
    local oldActiveFrIdx <const> = oldActiveFrObj.frameNumber
    activeSprite:newEmptyFrame(oldActiveFrIdx)
    app.frame = activeSprite.frames[oldActiveFrIdx + 1]
else
    activeSprite:newEmptyFrame()
end