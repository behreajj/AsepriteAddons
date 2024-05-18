local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local layer <const> = site.layer
if not layer then return end
if layer.isBackground then return end

local shift <const> = 1

local parent <const> = layer.parent
local parentLayers <const> = parent.layers
if parentLayers then
    local lenNeighbors <const> = #parentLayers

    if lenNeighbors > 1 then
        -- Edge case where background layer is at the bottom of the stack.
        -- A background can still be moved into a group. Sprite:backgroundLayer
        -- is unreliable here.
        local currStackIndex <const> = layer.stackIndex
        if currStackIndex == lenNeighbors
            and parentLayers[1].isBackground then
            return
        end

        app.transaction("Cycle Stack Up", function()
            local shifted <const> = currStackIndex - 1 + shift
            layer.stackIndex = 1 + shifted % lenNeighbors
            app.layer = layer
        end)
    end
end