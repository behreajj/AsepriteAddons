local blendModes <const> = {
    "NORMAL",

    "DARKEN",
    "MULTIPLY",
    "COLOR_BURN",

    "LIGHTEN",
    "SCREEN",
    "COLOR_DODGE",
    "ADDITION",

    "OVERLAY",
    "SOFT_LIGHT",
    "HARD_LIGHT",

    "DIFFERENCE",
    "EXCLUSION",
    "SUBTRACT",
    "DIVIDE",

    "HSL_HUE",
    "HSL_SATURATION",
    "HSL_COLOR",
    "HSL_LUMINOSITY",
}

---@param bm BlendMode
---@return string
local function blendModeToStr(bm)
    if bm == BlendMode.DARKEN then return "DARKEN" end
    if bm == BlendMode.MULTIPLY then return "MULTIPLY" end
    if bm == BlendMode.COLOR_BURN then return "COLOR_BURN" end

    if bm == BlendMode.LIGHTEN then return "LIGHTEN" end
    if bm == BlendMode.SCREEN then return "SCREEN" end
    if bm == BlendMode.COLOR_DODGE then return "COLOR_DODGE" end
    if bm == BlendMode.ADDITION then return "ADDITION" end

    if bm == BlendMode.OVERLAY then return "OVERLAY" end
    if bm == BlendMode.SOFT_LIGHT then return "SOFT_LIGHT" end
    if bm == BlendMode.HARD_LIGHT then return "HARD_LIGHT" end

    if bm == BlendMode.DIFFERENCE then return "DIFFERENCE" end
    if bm == BlendMode.EXCLUSION then return "EXCLUSION" end
    if bm == BlendMode.SUBTRACT then return "SUBTRACT" end
    if bm == BlendMode.DIVIDE then return "DIVIDE" end

    if bm == BlendMode.HSL_HUE then return "HSL_HUE" end
    if bm == BlendMode.HSL_SATURATION then return "HSL_SATURATION" end
    if bm == BlendMode.HSL_COLOR then return "HSL_COLOR" end
    if bm == BlendMode.HSL_LUMINOSITY then return "HSL_LUMINOSITY" end

    return "NORMAL"
end

---@param layer Layer
---@return string
local function getLayerType(layer)
    if layer.isReference then return "Reference" end
    if layer.isBackground then return "Background" end
    if layer.isGroup then return "Group" end
    if layer.isTilemap then return "Tile Map" end
    return "Normal"
end

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end
local layer <const> = site.layer or sprite.layers[1]
local isBkg <const> = layer.isBackground
local isGroup <const> = layer.isGroup
local frame <const> = site.frame or sprite.frames[1]
local cel <const> = layer:cel(frame)
local docPrefs <const> = app.preferences.document(sprite)
local tlPrefs <const> = docPrefs.timeline
local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

local dlg <const> = Dialog { title = "Properties" }

dlg:separator {
    id = "frameSep",
    text = string.format("Frame %d", frameUiOffset + frame.frameNumber)
}

dlg:number {
    id = "frameDuration",
    label = "Duration:",
    text = string.format("%d", math.floor(1000.0 * frame.duration + 0.5)),
    decimals = 0,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local msDur <const> = args.frameDuration --[[@as integer]]
        frame.duration = math.min(math.max(math.abs(
            msDur) * 0.001, 0.001), 65.535)
        app.refresh()
    end
}

dlg:separator {
    id = "layerSep",
    text = string.format("%s Layer", getLayerType(layer))
}

dlg:entry {
    id = "layerName",
    label = "Name:",
    text = layer.name,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerName <const> = args.layerName --[[@as string]]
        layer.name = layerName
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "layerBlend",
    label = "Blend:",
    option = blendModeToStr(layer.blendMode),
    options = blendModes,
    focus = false,
    visible = (not isBkg) and (not isGroup),
    onchange = function()
        if (not isBkg) and (not isGroup) then
            local args <const> = dlg.data
            local blendStr <const> = args.layerBlend --[[@as string]]
            layer.blendMode = BlendMode[blendStr]
            app.refresh()
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "layerOpacity",
    label = "Opacity:",
    min = 0,
    max = 255,
    value = layer.opacity,
    focus = false,
    visible = (not isBkg) and (not isGroup),
    onchange = function()
        if (not isBkg) and (not isGroup) then
            local args <const> = dlg.data
            local layerOpacity <const> = args.layerOpacity --[[@as integer]]
            layer.opacity = layerOpacity
            app.refresh()
        end
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "layerColor",
    label = "UI:",
    color = layer.color,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerColor <const> = args.layerColor --[[@as Color]]
        layer.color = layerColor
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "layerUserData",
    label = "User Data:",
    text = layer.data,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local layerUserData <const> = args.layerUserData --[[@as string]]
        layer.data = layerUserData
        app.refresh()
    end
}

if layer.isTilemap then
    local tileSet <const> = layer.tileset
    if tileSet then
        -- TODO: Any way to set the allowed flip flags (X, Y, D)?

        local gridSize <const> = tileSet.grid.tileSize

        dlg:separator {
            id = "tileSep",
            text = string.format("Tileset %d x %d (#%d)",
                gridSize.width, gridSize.height, #tileSet)
        }

        dlg:entry {
            id = "tilesetName",
            label = "Name:",
            text = tileSet.name,
            focus = false,
            onchange = function()
                local args <const> = dlg.data
                local tilesetName <const> = args.tilesetName --[[@as string]]
                tileSet.name = tilesetName
                app.refresh()
            end
        }

        dlg:newrow { always = false }

        dlg:number {
            id = "tilesetBaseIndex",
            label = "Base Index:",
            text = string.format("%0d", tileSet.baseIndex),
            decimals = 0,
            focus = false,
            onchange = function()
                local args <const> = dlg.data
                local tilesetBaseIndex <const> = args.tilesetBaseIndex --[[@as integer]]
                tileSet.baseIndex = math.max(1, math.abs(tilesetBaseIndex))
                app.refresh()
            end
        }
    end
end

if cel then
    -- There are enough other ways to change a cel's position, it doesn't need
    -- to be changed here.

    dlg:separator { id = "celSep", text = "Cel" }

    dlg:slider {
        id = "celZIndex",
        label = "Z Index:",
        min = -128,
        max = 127,
        value = cel.zIndex,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local zIndex <const> = args.celZIndex --[[@as integer]]
            cel.zIndex = zIndex
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "celOpacity",
        label = "Opacity:",
        min = 0,
        max = 255,
        value = cel.opacity,
        visible = not isBkg,
        focus = false,
        onchange = function()
            if not isBkg then
                local args <const> = dlg.data
                local celOpacity <const> = args.celOpacity --[[@as integer]]
                cel.opacity = celOpacity
                app.refresh()
            end
        end
    }

    dlg:newrow { always = false }

    dlg:color {
        id = "celColor",
        label = "UI:",
        color = cel.color,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local celColor <const> = args.celColor --[[@as Color]]
            cel.color = celColor
            app.refresh()
        end
    }

    dlg:newrow { always = false }

    dlg:entry {
        id = "celUserData",
        label = "User Data:",
        text = cel.data,
        focus = false,
        onchange = function()
            local args <const> = dlg.data
            local celUserData <const> = args.celUserData --[[@as string]]
            cel.data = celUserData
            app.refresh()
        end
    }
end

dlg:separator { id = "cancelSep" }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

-- Dialog bounds cannot be realigned because of wait = true.
dlg:show {
    autoscrollbars = true,
    wait = true
}