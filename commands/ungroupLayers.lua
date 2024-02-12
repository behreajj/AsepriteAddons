local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

---@type Layer[]
local layers <const> = {}
local range <const> = app.range
if range.sprite == activeSprite and (not range.isEmpty) then
    local rangeLayers <const> = range.layers
    local lenRangeLayers <const> = #rangeLayers
    local h = 0
    while h < lenRangeLayers do
        h = h + 1
        local rangeLayer <const> = rangeLayers[h]
        layers[h] = rangeLayer
    end

    -- Layers can be out of order vs. the stack, even if the range
    -- is sequential and all layers have the same parent.
    table.sort(layers, function(a, b)
        return a.stackIndex < b.stackIndex
    end)
else
    local activeLayer <const> = site.layer
    if activeLayer then
        layers[1] = activeLayer
    end
end

local lenLayers <const> = #layers
if lenLayers < 1 then return end

app.transaction("Ungroup Layers", function()
    local i = 0
    while i < lenLayers do
        i = i + 1
        local layer <const> = layers[i]
        local parent <const> = layer.parent
        if parent.__name ~= "doc::Sprite" then
            local grandparent <const> = parent.parent
            layer.parent = grandparent
        end
    end

    app.layer = layers[1]
end)