dofile("../../support/gradientutilities.lua")

local blendModes <const> = {
    "NORMAL", "DARKEN", "MULTIPLY", "COLOR_BURN",
    "LIGHTEN", "SCREEN", "COLOR_DODGE", "ADDITION",
    "OVERLAY", "SOFT_LIGHT", "HARD_LIGHT", "DIFFERENCE",
    "EXCLUSION", "SUBTRACT", "DIVIDE", "HSL_HUE",
    "HSL_SATURATION", "HSL_COLOR", "HSL_LUMINOSITY",
}

local defaults <const> = {
    nameEntry = "Layer",
    blendMode = "NORMAL",
    reverse = false
}

---@param sprite Sprite|nil
---@param range Range
---@param opFlag string
---@param opNum integer
local function adjustOpacity(sprite, range, opFlag, opNum)
    if not sprite then return end

    if range.sprite ~= sprite then
        app.alert {
            title = "Error",
            text = "Range sprite doesn't match active sprite."
        }
        return
    end

    local rangeLayers <const> = range.type == RangeType.FRAMES
        and { app.layer or sprite.layers[1] }
        or range.layers
    local lenRangeLayers <const> = #rangeLayers

    if lenRangeLayers <= 0 then
        app.alert {
            title = "Error",
            text = "No layers selected."
        }
        return
    end

    local floor <const> = math.floor
    local max <const> = math.max
    local min <const> = math.min

    if opFlag == "ADD" then
        app.transaction("Add Layer Opacity", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                local layer <const> = rangeLayers[i]
                if not (layer.isGroup or layer.isBackground) then
                    local opLayer <const> = layer.opacity
                    local opSum <const> = opLayer + opNum
                    layer.opacity = min(max(opSum, 0), 255)
                end
            end
        end)
    elseif opFlag == "SUBTRACT" then
        app.transaction("Subtract Layer Opacity", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                local layer <const> = rangeLayers[i]
                if not (layer.isGroup or layer.isBackground) then
                    local opLayer <const> = layer.opacity
                    local opDiff <const> = opLayer - opNum
                    layer.opacity = min(max(opDiff, 0), 255)
                end
            end
        end)
    elseif opFlag == "MULTIPLY" then
        local op01 <const> = opNum / 255.0
        app.transaction("Multiply Layer Opacity", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                local layer <const> = rangeLayers[i]
                if not (layer.isGroup or layer.isBackground) then
                    local opLayer01 <const> = layer.opacity / 255.0
                    local opProd01 <const> = min(max(opLayer01 * op01, 0.0), 1.0)
                    layer.opacity = floor(opProd01 * 255.0 + 0.5)
                end
            end
        end)
    elseif opFlag == "DIVIDE" then
        local op01 <const> = opNum ~= 0 and 255.0 / opNum or 0.0
        app.transaction("Divide Layer Opacity", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                local layer <const> = rangeLayers[i]
                if not (layer.isGroup or layer.isBackground) then
                    local opLayer01 <const> = layer.opacity / 255.0
                    local opQuot01 <const> = min(max(opLayer01 * op01, 0.0), 1.0)
                    layer.opacity = floor(opQuot01 * 255.0 + 0.5)
                end
            end
        end)
    else
        -- Default to set.
        app.transaction("Set Layer Opacity", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                local layer <const> = rangeLayers[i]
                if not (layer.isGroup or layer.isBackground) then
                    layer.opacity = opNum
                end
            end
        end)
    end

    app.refresh()
end

---@param layer Layer
---@param tally integer
---@param idTallyDict table<integer, integer>
---@return integer
local function layerHierarchy(layer, tally, idTallyDict)
    if layer.isGroup then
        local children <const> = layer.layers
        if children then
            local lenChildren <const> = #children
            local i = 0
            while i < lenChildren do
                i = i + 1
                tally = layerHierarchy(children[i], tally, idTallyDict)
            end
        end
    end

    idTallyDict[layer.id] = tally + 1
    return tally + 1
end

---@param sprite Sprite
---@return table<integer, integer>
local function spriteHierarchy(sprite)
    ---@type table<integer, integer>
    local idTallyDict <const> = {}
    local tally = 0
    local topLayers <const> = sprite.layers
    local lenTopLayers <const> = #topLayers
    local h = 0
    while h < lenTopLayers do
        h = h + 1
        tally = layerHierarchy(topLayers[h], tally, idTallyDict)
    end
    return idTallyDict
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
    focus = false,
    text = defaults.nameEntry
}

dlg:newrow { always = false }

dlg:check {
    id = "reverse",
    label = "Order:",
    text = "&Reverse",
    selected = defaults.reverse
}

dlg:newrow { always = false }

dlg:button {
    id = "renameButton",
    text = "RE&NAME",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers

        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

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

        local idTallyDict <const> = spriteHierarchy(sprite)
        table.sort(sortedLayers, function(a, b)
            return idTallyDict[a.id] < idTallyDict[b.id]
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

dlg:separator { id = "toggleSep" }

dlg:button {
    id = "hideButton",
    label = "Toggle:",
    text = "&HIDE",
    focus = true,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers
        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

        local i = 0
        while i < lenRangeLayers do
            i = i + 1
            local layer <const> = rangeLayers[i]
            layer.isVisible = not layer.isVisible
        end

        app.refresh()
    end
}

dlg:button {
    id = "lockButton",
    text = "&LOCK",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers
        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

        local i = 0
        while i < lenRangeLayers do
            i = i + 1
            local layer <const> = rangeLayers[i]
            layer.isEditable = not layer.isEditable
        end

        app.refresh()
    end
}

dlg:button {
    id = "contigButton",
    text = "C&ONTIG",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers
        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

        local i = 0
        while i < lenRangeLayers do
            i = i + 1
            local layer <const> = rangeLayers[i]
            if not layer.isGroup then
                layer.isContinuous = not layer.isContinuous
            end
        end

        app.refresh()
    end
}

dlg:separator { id = "blendSep" }

dlg:combobox {
    id = "blendMode",
    label = "Blend:",
    option = defaults.blendMode,
    options = blendModes,
    focus = false
}

dlg:newrow { always = false }

dlg:button {
    id = "blendButton",
    text = "CHAN&GE",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers

        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

        local args <const> = dlg.data
        local blendModeStr <const> = args.blendMode
            or defaults.blendMode --[[@as string]]
        local blendMode <const> = BlendMode[blendModeStr]

        app.transaction("Set Blend Mode", function()
            local i = 0
            while i < lenRangeLayers do
                i = i + 1
                rangeLayers[i].blendMode = blendMode
            end
        end)

        app.refresh()
    end
}

dlg:separator { id = "opacitySep" }

dlg:slider {
    id = "opNum",
    label = "Opacity:",
    min = 0,
    max = 255,
    value = 255,
    focus = false
}

dlg:newrow { always = false }

dlg:button {
    id = "addButton",
    text = "&ADD",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local opNum <const> = args.opNum --[[@as integer]]
        adjustOpacity(app.site.sprite, app.range, "ADD", opNum)
    end
}

dlg:button {
    id = "subButton",
    text = "&SUBTRACT",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local opNum <const> = args.opNum --[[@as integer]]
        adjustOpacity(app.site.sprite, app.range, "SUBTRACT", opNum)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "mulButton",
    text = "&MULTIPLY",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local opNum <const> = args.opNum --[[@as integer]]
        adjustOpacity(app.site.sprite, app.range, "MULTIPLY", opNum)
    end
}

dlg:button {
    id = "divButton",
    text = "&DIVIDE",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local opNum <const> = args.opNum --[[@as integer]]
        adjustOpacity(app.site.sprite, app.range, "DIVIDE", opNum)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "setButton",
    text = "S&ET",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local opNum <const> = args.opNum --[[@as integer]]
        adjustOpacity(app.site.sprite, app.range, "SET", opNum)
    end
}

dlg:separator { id = "colorSep" }

dlg:color {
    id = "fromColor",
    label = "From:",
    color = Color { r = 125, g = 64, b = 136, a = 255 }
}

dlg:color {
    id = "toColor",
    label = "To:",
    color = Color { r = 172, g = 118, b = 49, a = 255 }
}

dlg:newrow { always = false }

dlg:combobox {
    id = "huePreset",
    label = "Easing:",
    option = GradientUtilities.DEFAULT_HUE_EASING,
    options = GradientUtilities.HUE_EASING_PRESETS
}

dlg:newrow { always = false }

dlg:button {
    id = "swapColors",
    text = "S&WAP",
    focus = false,
    onclick = function() swapColors(dlg) end
}

dlg:button {
    id = "tintButton",
    text = "&TINT",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.alert {
                title = "Error",
                text = "Range sprite doesn't match active sprite."
            }
            return
        end

        local rangeLayers <const> = range.type == RangeType.FRAMES
            and { app.layer or sprite.layers[1] }
            or range.layers
        local lenRangeLayers <const> = #rangeLayers

        if lenRangeLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers selected."
            }
            return
        end

        local args <const> = dlg.data
        local fromColor <const> = args.fromColor --[[@as Color]]
        local toColor <const> = args.toColor --[[@as Color]]
        local huePreset <const> = args.huePreset --[[@as string]]

        if lenRangeLayers <= 1 then
            app.transaction("Tint Layer", function()
                rangeLayers[1].color = AseUtilities.aseColorCopy(toColor, "")
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

        local hueFunc <const> = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        local mixer <const> = Clr.mixSrLch
        local clrToAse <const> = AseUtilities.clrToAseColor
        local fromClr = AseUtilities.aseColorToClr(fromColor)
        local toClr = AseUtilities.aseColorToClr(toColor)
        if fromClr.a <= 0.0 and toClr.a <= 0.0 then
            fromClr = Clr.new(0.0, 0.0, 0.0, 0.0)
            toClr = Clr.new(0.0, 0.0, 0.0, 0.0)
        end

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

local appPrefs <const> = app.preferences
if appPrefs then
    local genPrefs <const> = appPrefs.general
    if genPrefs then
        local posPrefs <const> = genPrefs.timeline_position --[[@as integer]]
        if posPrefs then
            local dlgBounds <const> = dlg.bounds
            if posPrefs == 1 then
                dlg.bounds = Rectangle(
                    dlgBounds.x * 2 - 52, dlgBounds.y,
                    dlgBounds.w, dlgBounds.h)
            elseif posPrefs == 2 then
                dlg.bounds = Rectangle(
                    16, dlgBounds.y,
                    dlgBounds.w, dlgBounds.h)
            end
        end
    end
end