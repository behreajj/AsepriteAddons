local site = app.site
local sprite = site.sprite
if not sprite then return end
local layer = site.layer
if not layer then return end

local shift = 1

local lenNeighbors = #layer.parent.layers
if lenNeighbors > 1 then
    app.transaction("Cycle Stack Up", function()
        local shifted = layer.stackIndex - 1 + shift
        layer.stackIndex = 1 + shifted % lenNeighbors
        app.activeLayer = layer
    end)
end