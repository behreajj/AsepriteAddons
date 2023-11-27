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
    text = string.format("%05d", math.floor(1000.0 * frame.duration + 0.5)),
    decimals = 0,
    focus = false,
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
}

dlg:newrow { always = false }

dlg:combobox {
    id = "layerBlend",
    label = "Blend:",
    option = blendModeToStr(layer.blendMode),
    options = blendModes,
    visible = (not layer.isBackground)
        and (not layer.isGroup),
}

dlg:newrow { always = false }

dlg:slider {
    id = "layerOpacity",
    label = "Opacity:",
    min = 0,
    max = 255,
    value = layer.opacity,
    visible = (not layer.isBackground)
        and (not layer.isGroup),
}

dlg:newrow { always = false }

dlg:color {
    id = "layerColor",
    label = "UI:",
    color = layer.color,
}

dlg:newrow { always = false }

dlg:entry {
    id = "layerUserData",
    label = "User Data:",
    text = layer.data,
    focus = false,
}

if layer.isTilemap then
    local tileset <const> = layer.tileset
    if tileset then
        -- TODO: Any way to set the allowed flip flags (X, Y, D)?

        dlg:separator { id = "tileSep", text = "Tileset" }

        dlg:entry {
            id = "tilesetName",
            label = "Name:",
            text = layer.tileset.name,
            focus = false,
        }

        dlg:newrow { always = false }

        dlg:number {
            id = "tilesetBaseIndex",
            label = "Base Index:",
            text = string.format("%0d", tileset.baseIndex),
            decimals = 0,
            focus = false,
        }
    end
end

if cel then
    -- There are enough other ways to change a cel's position, it doesn't need
    -- to be changed here.

    dlg:separator { id = "celSep", text = "Cel" }

    dlg:slider {
        id = "celOpacity",
        label = "Opacity:",
        min = 0,
        max = 255,
        value = cel.opacity,
        visible = not layer.isBackground,
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "celZIndex",
        label = "Z Index:",
        min = -128,
        max = 127,
        value = cel.zIndex,
        visible = not layer.isBackground,
    }

    dlg:newrow { always = false }

    dlg:color {
        id = "celColor",
        label = "UI:",
        color = cel.color,
    }

    dlg:newrow { always = false }

    dlg:entry {
        id = "celUserData",
        label = "User Data:",
        text = cel.data,
        focus = false,
    }
end

dlg:separator { id = "cancelSep" }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlg.data

        -- Frame.
        local msDur <const> = args.frameDuration --[[@as integer]]

        -- Layer.
        local name <const> = args.layerName --[[@as string]]
        local blendStr <const> = args.layerBlend --[[@as string]]
        local layerOpacity <const> = args.layerOpacity --[[@as integer]]
        local layerColor <const> = args.layerColor --[[@as Color]]
        local layerUserData <const> = args.layerUserData --[[@as string]]

        -- Cel.
        local celOpacity <const> = args.celOpacity --[[@as integer]]
        local zIndex <const> = args.celZIndex --[[@as integer]]
        local celColor <const> = args.celColor --[[@as Color]]
        local celUserData <const> = args.celUserData --[[@as string]]

        app.transaction("Set Properties", function()
            frame.duration = math.min(math.max(math.abs(
                msDur) * 0.001, 0.001), 65.535)

            layer.name = #name > 0 and name or "Layer"
            if (not layer.isGroup) and (not layer.isBackground) then
                layer.blendMode = BlendMode[blendStr]
                layer.opacity = layerOpacity
            end
            layer.color = layerColor
            layer.data = layerUserData

            cel.opacity = celOpacity
            cel.zIndex = zIndex
            cel.color = celColor
            cel.data = celUserData

            if layer.isTilemap and layer.tileset then
                local tileset <const> = layer.tileset

                local tilesetName <const> = args.tilesetName --[[@as string]]
                local tilesetBaseIndex <const> = args.tilesetBaseIndex --[[@as integer]]

                tileset.name = #tilesetName > 0 and tilesetName or "Tileset"
                tileset.baseIndex = math.max(1, math.abs(tilesetBaseIndex))
            end
        end)

        app.refresh()
        dlg:close()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = true
}