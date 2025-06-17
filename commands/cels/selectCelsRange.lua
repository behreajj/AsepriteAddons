dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local tlHidden <const> = not app.preferences.general.visible_timeline --[[@as boolean]]
if tlHidden then
    app.command.Timeline { open = true }
end

local appRange <const> = app.range
if appRange.sprite == activeSprite then
    local selectCel <const> = AseUtilities.selectCel
    local spriteBounds <const> = activeSprite.bounds

    if appRange.isEmpty then
        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local xMouse <const>, yMouse <const> = AseUtilities.getMouse()
        local palettes <const> = activeSprite.palettes
        local specSprite <const> = activeSprite.spec
        local colorMode <const> = specSprite.colorMode
        local a01 <const>, candidate <const> = AseUtilities.layerUnderPoint(
            activeSprite, activeFrame, xMouse, yMouse, 1.0,
            palettes, colorMode)

        if a01 > 0.0 then
            local union <const> = Selection()
            local cel <const> = candidate:cel(activeFrame)
            if cel then
                union:add(selectCel(cel))
            end
            union:intersect(spriteBounds)
            if not union.isEmpty then
                activeSprite.selection = union
            end -- Non empty union.
            app.layer = candidate
        end -- Non zero alpha.
    else
        local rangeImages <const> = appRange.images
        local lenRangeImages <const> = #rangeImages
        local union <const> = Selection()

        local i = 0
        while i < lenRangeImages do
            i = i + 1
            local image <const> = rangeImages[i]
            local cel <const> = image.cel
            local layer <const> = cel.layer
            if layer.isBackground then
                union:add(spriteBounds)
                break
            elseif not layer.isReference then
                union:add(selectCel(cel))
            end
        end

        union:intersect(spriteBounds)
        if not union.isEmpty then
            activeSprite.selection = union
        end -- Non empty union.
    end     -- Range is empty check.
end         -- Range sprite is active sprite.

if tlHidden then
    app.command.Timeline { close = true }
end