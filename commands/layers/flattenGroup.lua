dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

local activeLayer <const> = site.layer
if not activeLayer then return end
if not activeLayer.isGroup then
    app.alert {
        title = "Error",
        text = "Layer is not a group."
    }
    return
end

local frObjs <const> = activeSprite.frames

app.transaction("Flatten Group", function()
    AseUtilities.flattenGroup(
        activeSprite, activeLayer, frObjs,
        true, false, true, true)
    activeSprite:deleteLayer(activeLayer)
end)

app.refresh()