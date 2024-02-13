dofile("../../support/gradientutilities.lua")

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

---@param dialog Dialog
local function swapColors(dialog)
    local args <const> = dialog.data
    local frColor <const> = args.fromColor --[[@as Color]]
    local toColor <const> = args.toColor --[[@as Color]]
    dialog:modify {
        id = "fromColor",
        color = AseUtilities.aseColorCopy(
            toColor, "")
    }
    dialog:modify {
        id = "toColor",
        color = AseUtilities.aseColorCopy(
            frColor, "")
    }
end

local dlg <const> = Dialog { title = "Bulk Edit Layers" }

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
    id = "renameButton",
    text = "RE&NAME",
    focus = false,
    onclick = function()
        -- TODO: Option to set/multiply/add/divide/subtract opacity.

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

        ---@type Layer[]
        local sortedLayers <const> = {}
        local h = 0
        while h < lenRangeLayers do
            h = h + 1
            sortedLayers[h] = rangeLayers[h]
        end

        local idLayerDict <const> = spriteHierarchy(sprite)
        table.sort(sortedLayers, function(a, b)
            return idLayerDict[a.id] < idLayerDict[b.id]
        end)

        local format <const> = "%s %d"
        local strfmt <const> = string.format

        app.transaction("Rename Layers", function()
            local lenSortedLayers <const> = #sortedLayers
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

dlg:separator { id = "colorSep" }

dlg:color {
    id = "fromColor",
    label = "From:",
    color = Color { r = 106, g = 32, b = 121, a = 255 }
}

dlg:color {
    id = "toColor",
    label = "To:",
    color = Color { r = 243, g = 206, b = 82, a = 255 }
}

dlg:newrow { always = false }

dlg:button {
    id = "swapColors",
    text = "&SWAP",
    focus = false,
    onclick = function() swapColors(dlg) end
}

dlg:button {
    id = "tintButton",
    text = "&TINT",
    focus = false,
    onclick = function()
        -- TODO: Option to recolor or tint layers as well, similar to how Tag
        -- colors are created?

        -- You shouldn't need the reverse option here, since  from and to can
        -- be reversed by the user.

        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then return end

        local rangeLayers <const> = range.layers
        local lenRangeLayers <const> = #rangeLayers

        if lenRangeLayers <= 0 then return end

        local args <const> = dlg.data
        local fromColor <const> = args.fromColor --[[@as Color]]
        local toColor <const> = args.toColor --[[@as Color]]

        if lenRangeLayers <= 1 then
            app.transaction("Tint Layer", function()
                rangeLayers[1].color = toColor
            end)
            app.refresh()
            return
        end

        ---@type Layer[]
        local sortedLayers <const> = {}
        local h = 0
        while h < lenRangeLayers do
            h = h + 1
            sortedLayers[h] = rangeLayers[h]
        end

        local idLayerDict <const> = spriteHierarchy(sprite)
        table.sort(sortedLayers, function(a, b)
            return idLayerDict[a.id] < idLayerDict[b.id]
        end)

        local hueFunc <const> = GradientUtilities.lerpHueCw
        local mixer <const> = Clr.mixSrLch
        local clrToAse <const> = AseUtilities.clrToAseColor
        local fromClr <const> = AseUtilities.aseColorToClr(fromColor)
        local toClr <const> = AseUtilities.aseColorToClr(toColor)

        app.transaction("Tint Layers", function()
            local lenSortedLayers <const> = #sortedLayers
            local i = 0
            local iToFac <const> = 1.0 / (lenSortedLayers - 1.0)
            while i < lenSortedLayers do
                local iFac <const> = i * iToFac
                local clr <const> = mixer(fromClr, toClr, iFac, hueFunc)
                local color <const> = clrToAse(clr)
                i = i + 1
                local layer <const> = sortedLayers[i]
                layer.color = color
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

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