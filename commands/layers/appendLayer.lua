-- https://steamcommunity.com/app/431730/discussions/2/651441050097836149/

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

app.transaction("Append Layer", function()
    local srcLayer <const> = site.layer
    local parent <const> = srcLayer
        and srcLayer.parent
        or sprite
    -- local idx <const> = srcLayer
    --     and srcLayer.stackIndex + 1
    --     or #parent.layers
    local trgLayer <const> = sprite:newLayer()
    trgLayer.parent = parent
    -- trgLayer.stackIndex = idx
    app.layer = trgLayer
end)
app.refresh()