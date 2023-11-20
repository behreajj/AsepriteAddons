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

---@param blendMode BlendMode
---@return string
local function blendModeToStr(blendMode)
    if blendMode == BlendMode.DARKEN then return "DARKEN" end
    if blendMode == BlendMode.MULTIPLY then return "MULTIPLY" end
    if blendMode == BlendMode.COLOR_BURN then return "COLOR_BURN" end

    if blendMode == BlendMode.LIGHTEN then return "LIGHTEN" end
    if blendMode == BlendMode.SCREEN then return "SCREEN" end
    if blendMode == BlendMode.COLOR_DODGE then return "COLOR_DODGE" end
    if blendMode == BlendMode.ADDITION then return "ADDITION" end

    if blendMode == BlendMode.OVERLAY then return "OVERLAY" end
    if blendMode == BlendMode.SOFT_LIGHT then return "SOFT_LIGHT" end
    if blendMode == BlendMode.HARD_LIGHT then return "HARD_LIGHT" end

    if blendMode == BlendMode.DIFFERENCE then return "DIFFERENCE" end
    if blendMode == BlendMode.EXCLUSION then return "EXCLUSION" end
    if blendMode == BlendMode.SUBTRACT then return "SUBTRACT" end
    if blendMode == BlendMode.DIVIDE then return "DIVIDE" end

    if blendMode == BlendMode.HSL_HUE then return "HSL_HUE" end
    if blendMode == BlendMode.HSL_SATURATION then return "HSL_SATURATION" end
    if blendMode == BlendMode.HSL_COLOR then return "HSL_COLOR" end
    if blendMode == BlendMode.HSL_LUMINOSITY then return "HSL_LUMINOSITY" end

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

dlg:separator { id = "frameSep", text = "Frame" }

dlg:label {
    id = "frameNo",
    label = "Number:",
    text = string.format("%d", frameUiOffset + frame.frameNumber),
    focus = false
}

dlg:newrow { always = false }

dlg:number {
    id = "frameDuration",
    label = "Duration:",
    text = string.format("%05d", math.floor(1000.0 * frame.duration + 0.5)),
    decimals = 0,
    focus = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "frameUpdate",
    text = "UP&DATE",
    focus = false,
    onclick = function()
        local args = dlg.data
        local msDur <const> = args.frameDuration --[[@as integer]]

        app.transaction("Set Frame", function()
            frame.duration = math.min(math.max(math.abs(
                msDur) * 0.001, 0.001), 65.535)
        end)

        app.refresh()
        dlg:close()
    end
}

dlg:separator { id = "layerSep", text = "Layer" }

dlg:label {
    id = "layerType",
    label = "Type:",
    text = getLayerType(layer),
    visible = false,
}

dlg:newrow { always = false }

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

dlg:newrow { always = false }

dlg:button {
    id = "layerUpdate",
    text = "U&PDATE",
    focus = false,
    onclick = function()
        local args = dlg.data
        local name <const> = args.layerName --[[@as string]]
        local blendStr <const> = args.layerBlend --[[@as string]]
        local opacity <const> = args.layerOpacity --[[@as integer]]
        local uiColor <const> = args.layerColor --[[@as Color]]
        local userData <const> = args.layerUserData --[[@as string]]

        app.transaction("Set Layer", function()
            layer.name = name
            if (not layer.isGroup) and (not layer.isBackground) then
                layer.blendMode = BlendMode[blendStr]
                layer.opacity = opacity
            end
            layer.color = uiColor
            layer.data = userData
        end)

        app.refresh()
        dlg:close()
    end
}

if layer.isTilemap then
    -- TODO: Extra section for if layer is a tile map?
    -- Except for tile set name, none of the information can be changed
    -- or is all that useful...
end

if cel then
    dlg:separator { id = "celSep", text = "Cel" }

    dlg:number {
        id = "xPosCel",
        label = "Position:",
        text = string.format("%0d", cel.position.x),
        decimals = 0,
        focus = false,
        visible = (not layer.isBackground)
            and (not layer.isReference),
    }

    dlg:number {
        id = "yPosCel",
        text = string.format("%0d", cel.position.y),
        decimals = 0,
        focus = false,
        visible = (not layer.isBackground)
            and (not layer.isReference),
    }

    dlg:newrow { always = false }

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

    dlg:newrow { always = false }

    dlg:button {
        id = "celUpdate",
        text = "&UPDATE",
        focus = false,
        onclick = function()
            local args = dlg.data
            local xPos <const> = args.xPosCel --[[@as integer]]
            local yPos <const> = args.yPosCel --[[@as integer]]
            local opacity <const> = args.celOpacity --[[@as integer]]
            local zIndex <const> = args.celZIndex --[[@as integer]]
            local uiColor <const> = args.celColor --[[@as Color]]
            local userData <const> = args.celUserData --[[@as string]]

            app.transaction("Set Cel", function()
                cel.position = Point(xPos, yPos)
                cel.opacity = opacity
                cel.zIndex = zIndex
                cel.color = uiColor
                cel.data = userData
            end)

            app.refresh()
            dlg:close()
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

dlg:show {
    autoscrollbars = true,
    wait = true
}