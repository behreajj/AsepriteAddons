---@param layer Layer
---@param tally integer
---@param idLayerDict table<integer, integer>
---@return integer
local function layerHierarchy(layer, tally, idLayerDict)
    if layer.isGroup then
        local children <const> = layer.layers
        if children then
            local lenChildren <const> = #children
            local i = 0
            while i < lenChildren do
                i = i + 1
                tally = layerHierarchy(children[i], tally, idLayerDict)
            end
        end
    end

    idLayerDict[layer.id] = tally + 1
    return tally + 1
end

---@param sprite Sprite
---@return table<integer, integer>
local function spriteHierarchy(sprite)
    ---@type table<integer, integer>
    local idLayerDict <const> = {}
    local tally = 0
    local topLayers <const> = sprite.layers
    local lenTopLayers <const> = #topLayers
    local h = 0
    while h < lenTopLayers do
        h = h + 1
        tally = layerHierarchy(topLayers[h], tally, idLayerDict)
    end
    return idLayerDict
end

local dlg <const> = Dialog { title = "Layer Rename" }

dlg:entry {
    id = "nameEntry",
    label = "Name:",
    focus = true,
    text = "Layer"
}

dlg:newrow { always = false }

dlg:check {
    id = "reverse",
    label = "Order:",
    text = "&Reverse",
    selected = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- TODO: Option to recolor or tint layers as well, similar to how Tag
        -- colors are created?

        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then return end

        local rangeLayers <const> = range.layers
        local lenRangeLayers <const> = #rangeLayers

        if lenRangeLayers <= 0 then return end

        local args <const> = dlg.data
        local nameEntry <const> = args.nameEntry --[[@as string]]
        local reverse <const> = args.reverse --[[@as boolean]]

        if lenRangeLayers <= 1 then
            app.transaction("Rename Layer", function()
                rangeLayers[1].name = nameEntry
            end)
            app.refresh()
            return
        end

        local idLayerDict <const> = spriteHierarchy(sprite)

        ---@type Layer[]
        local sortedLayers <const> = {}
        local j = 0
        while j < lenRangeLayers do
            j = j + 1
            sortedLayers[j] = rangeLayers[j]
        end
        table.sort(sortedLayers, function(a, b)
            return idLayerDict[a.id] < idLayerDict[b.id]
        end)

        local format <const> = "%s %d"
        local strfmt <const> = string.format
        local lenSortedLayers <const> = #sortedLayers

        app.transaction("Rename Layers", function()
            local i = 0
            while i < lenSortedLayers do
                i = i + 1
                local layer <const> = sortedLayers[i]
                local n <const> = reverse
                    and lenSortedLayers + 1 - i
                    or i
                layer.name = strfmt(format, nameEntry, n)
            end
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}