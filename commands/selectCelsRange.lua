dofile("../support/aseutilities.lua")

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
        local activeLayer <const> = site.layer
        local activeFrame <const> = site.frame
        if activeLayer and activeFrame then
            if activeLayer.isBackground then
                activeSprite.selection = Selection(spriteBounds)
            else
                local leaves <const> = AseUtilities.appendLeaves(
                    activeLayer, {}, true, true, true, true)
                local lenLeaves <const> = #leaves
                local union <const> = Selection()

                local i = 0
                while i < lenLeaves do
                    i = i + 1
                    local leaf <const> = leaves[i]
                    local cel <const> = leaf:cel(activeFrame)
                    if cel then
                        union:add(selectCel(cel))
                    end
                end

                union:intersect(spriteBounds)
                if not union.isEmpty then
                    activeSprite.selection = union
                end -- Non empty union.
            end     -- Layer is background check.
        end         -- Active Layer and frame exist.
    else
        local images <const> = appRange.images
        local lenImages <const> = #images
        local union <const> = Selection()

        local i = 0
        while i < lenImages do
            i = i + 1
            local image <const> = images[i]
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