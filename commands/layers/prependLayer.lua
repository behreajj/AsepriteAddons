local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

app.transaction("Prepend Layer", function()
    local srcLayer <const> = site.layer
    local parent <const> = srcLayer
        and srcLayer.parent
        or sprite
    local trgLayer <const> = sprite:newLayer()
    trgLayer.parent = parent
    trgLayer.stackIndex = 1
    app.layer = trgLayer
end)
app.refresh()