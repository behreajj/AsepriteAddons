local site = app.site
local sprite = site.sprite
if not sprite then return end
local layer = site.layer
if not layer then return end
if layer.isBackground then return end

local shift = -1

local parent = layer.parent
local parentLayers = parent.layers --[=[@as Layer[]]=]
local lenNeighbors = #parentLayers

if lenNeighbors > 1 then
    -- Edge case where background layer is at the bottom
    -- of the stack. A background can still be moved into
    -- a group; Sprite:backgroundLayer is unreliable here.
    local currStackIndex = layer.stackIndex
    if currStackIndex == 2
        and parentLayers[1].isBackground then
        return
    end

    app.transaction("Cycle Stack Down", function()
        local shifted = currStackIndex - 1 + shift
        layer.stackIndex = 1 + shifted % lenNeighbors
        app.activeLayer = layer
    end)
end