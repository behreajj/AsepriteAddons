dofile("../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tlHidden <const> = not app.preferences.general.visible_timeline
if tlHidden then
    app.command.Timeline { open = true }
end

local appRange <const> = app.range
if appRange.sprite == activeSprite then
    local selectCel <const> = AseUtilities.selectCel
    local sprBounds <const> = activeSprite.bounds

    if appRange.isEmpty then
        local activeCel <const> = site.cel
        if activeCel then
            activeSprite.selection = selectCel(activeCel)
        end
    else
        local images <const> = appRange.images
        local lenImages <const> = #images
        local union <const> = Selection()

        local i = 0
        while i < lenImages do
            i = i + 1
            local image <const> = images[i]
            local cel <const> = image.cel
            local sel <const> = selectCel(cel)
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