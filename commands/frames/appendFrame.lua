-- The default behavior for the active tag, if any, is to
-- expand to encompass this frame. That seems desirable
-- for this case (?), but it may not be in others.

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

app.transaction("Append Frame", function()
    local oldActiveFrObj <const> = site.frame
    if oldActiveFrObj then
        local oldActiveFrIdx <const> = oldActiveFrObj.frameNumber
        activeSprite:newEmptyFrame(oldActiveFrIdx + 1)
        app.frame = oldActiveFrObj
    else
        activeSprite:newEmptyFrame()
    end
end)