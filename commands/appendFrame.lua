local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local oldActiveFrObj <const> = site.frame
if oldActiveFrObj then
    local oldActiveFrIdx <const> = oldActiveFrObj.frameNumber
    activeSprite:newEmptyFrame(oldActiveFrIdx + 1)
    app.frame = oldActiveFrObj
else
    activeSprite:newEmptyFrame()
end