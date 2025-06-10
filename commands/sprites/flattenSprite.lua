dofile("../../support/aseutilities.lua")

local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

app.transaction("Flatten Sprite", function()
    app.layer = AseUtilities.flattenSprite(activeSprite)
end)
app.refresh()