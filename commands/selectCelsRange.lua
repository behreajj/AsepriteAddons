dofile("../support/aseutilities.lua")

local site = app.site
local activeSprite = site.sprite
if not activeSprite then return end

local tlHidden = not app.preferences.general.visible_timeline
if tlHidden then
    app.command.Timeline { open = true }
end

local appRange = app.range
if appRange.sprite == activeSprite then
    local selectCel = AseUtilities.selectCel
    local sprBounds = activeSprite.bounds

    if appRange.isEmpty then
        local activeCel = site.cel
        if activeCel then
            activeSprite.selection = selectCel(activeCel, sprBounds)
        end
    else
        local images = app.range.images
        local lenImages = #images
        local union = Selection()

        local i = 0
        while i < lenImages do
            i = i + 1
            local image = images[i]
            local cel = image.cel
            local sel = selectCel(cel, sprBounds)
            union:add(sel)
        end

        if not union.isEmpty then
            activeSprite.selection = union
        end
    end
end

if tlHidden then
    app.command.Timeline { close = true }
end