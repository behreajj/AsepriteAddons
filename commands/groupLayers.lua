local site <const> = app.site
local activeSprite <const> = site.sprite
if not activeSprite then return end

---@type Layer[]
local layers <const> = {}
local parentGroup = nil
local stckIdxGroup = 0

local range <const> = app.range
if range.sprite == activeSprite and (not range.isEmpty) then
    local rangeLayers <const> = range.layers
    local lenRangeLayers <const> = #rangeLayers

    local parentInit <const> = rangeLayers[1].parent
    local idInit <const> = parentInit.id
    local sameParent = true
    local stckIdxMax = -2147483648

    local h = 0
    while h < lenRangeLayers do
        h = h + 1
        local rangeLayer <const> = rangeLayers[h]

        -- Do you have to worry about sprite ID overlapping with layer IDs
        -- as a unique identifier, e.g., sprite id = 1, layer id = 1?
        local parentCand <const> = rangeLayer.parent
        local idCand <const> = parentCand.id
        sameParent = sameParent and idCand == idInit

        if not rangeLayer.isBackground then
            layers[#layers + 1] = rangeLayer
            local stckIdxCand <const> = rangeLayer.stackIndex
            if stckIdxCand > stckIdxMax then stckIdxMax = stckIdxCand end
        end
    end

    if sameParent then
        parentGroup = parentInit
        -- Stack indices are meaningless unless all share the same parent.
        if stckIdxMax > 0 then
            stckIdxGroup = stckIdxMax
        end
    end

    -- Layers can be out of order vs. the stack, even if the range
    -- is sequential and all layers have the same parent.
    table.sort(layers, function(a, b)
        return a.stackIndex < b.stackIndex
    end)
else
    local activeLayer <const> = site.layer
    if activeLayer then
        if not activeLayer.isBackground then
            layers[1] = activeLayer
            parentGroup = activeLayer.parent
            stckIdxGroup = activeLayer.stackIndex + 1
        end
    end
end

local lenLayers <const> = #layers
if lenLayers < 1 then return end

app.transaction("Group Layers", function()
    local newGroup <const> = activeSprite:newGroup()
    if parentGroup then
        newGroup.parent = parentGroup
        if stckIdxGroup > 0 then
            newGroup.stackIndex = stckIdxGroup
        end
    end

    local i = 0
    while i < lenLayers do
        i = i + 1
        local layer <const> = layers[i]
        layer.parent = newGroup
        layer.stackIndex = i
    end

    app.layer = newGroup
end)