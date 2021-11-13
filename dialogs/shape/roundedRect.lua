dofile("../../support/aseutilities.lua")

local cornerInputs = { "NON_UNIFORM", "UNIFORM" }

local defaults = {
    resolution = 32,
    lbx = 5,
    lby = 5,
    ubx = 95,
    uby = 95,
    tl = 7,
    tr = 7,
    br = 7,
    bl = 7,
    crnrUni = 7,
    cornerInput = "UNIFORM",
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    useFill = true,
    fillClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    handles = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Rounded Rectangle" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:slider {
    id = "handles",
    label = "Handles:",
    min = 0,
    max = 255,
    value = defaults.handles
}

dlg:newrow { always = false }

dlg:slider {
    id = "lbx",
    label = "Horizontal %:",
    min = 0,
    max = 100,
    value = defaults.lbx
}

dlg:slider {
    id = "ubx",
    min = 0,
    max = 100,
    value = defaults.ubx
}

dlg:newrow { always = false }

dlg:slider {
    id = "lby",
    label = "Vertical %:",
    min = 0,
    max = 100,
    value = defaults.lby
}

dlg:slider {
    id = "uby",
    min = 0,
    max = 100,
    value = defaults.uby
}

dlg:newrow { always = false }

dlg:slider {
    id = "crnrUni",
    label = "Corners %:",
    min = -50,
    max = 50,
    value = defaults.crnrUni,
    visible = true,
    onchange = function()
        local uni = dlg.data.crnrUni
        dlg:modify { id = "tl", value = uni }
        dlg:modify { id = "tr", value = uni }
        dlg:modify { id = "br", value = uni }
        dlg:modify { id = "bl", value = uni }
    end
}

dlg:slider {
    id = "tl",
    label = "Corners %:",
    min = -50,
    max = 50,
    value = defaults.tl,
    visible = false
}

dlg:slider {
    id = "tr",
    min = -50,
    max = 50,
    value = defaults.tr,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "bl",
    min = -50,
    max = 50,
    value = defaults.bl,
    visible = false
}

dlg:slider {
    id = "br",
    min = -50,
    max = 50,
    value = defaults.br,
    visible = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "cornerInput",
    option = defaults.cornerInput,
    options = cornerInputs,
    onchange = function()
        local md = dlg.data.cornerInput
        local isnu = md == "NON_UNIFORM"
        dlg:modify { id = "tl", visible = isnu }
        dlg:modify { id = "tr", visible = isnu }
        dlg:modify { id = "br", visible = isnu }
        dlg:modify { id = "bl", visible = isnu }

        dlg:modify {
            id = "crnrUni",
            visible = not isnu
        }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useStroke",
    label = "Stroke:",
    text = "Enable",
    selected = defaults.useStroke,
    onclick = function()
        dlg:modify {
            id = "strokeWeight",
            visible = dlg.data.useStroke
        }
        dlg:modify {
            id = "strokeClr",
            visible = dlg.data.useStroke
        }
    end
}

dlg:slider {
    id = "strokeWeight",
    min = 1,
    max = 64,
    value = defaults.strokeWeight,
    visible = defaults.useStroke
}

dlg:color {
    id = "strokeClr",
    color = defaults.strokeClr,
    visible = defaults.useStroke
}

dlg:newrow { always = false }

dlg:check {
    id = "useFill",
    label = "Fill:",
    text = "Enable",
    selected = defaults.useFill,
    onclick = function()
        dlg:modify {
            id = "fillClr",
            visible = dlg.data.useFill
        }
    end
}

dlg:color {
    id = "fillClr",
    color = defaults.fillClr,
    visible = defaults.useFill
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- TODO: Include an option to add a slice for the rect?
        local args = dlg.data
        local sprite = AseUtilities.initCanvas(
            64, 64, "Rectangle",
            { args.fillClr.rgbaPixel,
              args.strokeClr.rgbaPixel })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame or sprite.frames[1]
        local cel = sprite:newCel(layer, frame)

        local wPrc = sprite.width * 0.01
        local hPrc = sprite.height * 0.01
        local prc = math.min(wPrc, hPrc)

        local bl = args.bl or defaults.bl
        local br = args.br or defaults.br
        local tr = args.tr or defaults.tr
        local tl = args.tl or defaults.tl

        local cornerInput = args.cornerInput or defaults.cornerInput
        if cornerInput == "UNIFORM" then
            local crnrUni = args.crnrUni or defaults.crnrUni
            bl = crnrUni
            br = crnrUni
            tr = crnrUni
            tl = crnrUni
        end

        local curve = Curve2.rect(
            wPrc * args.lbx, hPrc * args.lby,
            wPrc * args.ubx, hPrc * args.uby,
            prc * bl, prc * br,
            prc * tr, prc * tl)

        AseUtilities.drawCurve2(
            curve,
            args.resolution,
            args.useFill,
            args.fillClr,
            args.useStroke,
            args.strokeClr,
            Brush(args.strokeWeight),
            cel,
            layer)

        if args.handles > 0 then
            local hlLyr = sprite:newLayer()
            hlLyr.name = curve.name .. ".Handles"
            hlLyr.opacity = args.handles
            AseUtilities.drawHandles2(
                curve,
                sprite:newCel(hlLyr, frame),
                hlLyr)
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }