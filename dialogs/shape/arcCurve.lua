dofile("../../support/aseutilities.lua")

local defaults = {
    startAngle = 0,
    stopAngle = 90,
    thickness = 25,
    thickOffset = 0,
    resolution = 32,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.DEFAULT_STROKE,
    useFill = true,
    fillClr = AseUtilities.DEFAULT_FILL,
    handles = 0,
    pullFocus = false
}

local dlg = Dialog { title = "Curve Arc" }

dlg:slider {
    id = "startAngle",
    label = "Angles:",
    min = 0,
    max = 360,
    value = defaults.startAngle
}

dlg:slider {
    id = "stopAngle",
    min = 0,
    max = 360,
    value = defaults.stopAngle
}

dlg:newrow { always = false }

dlg:number {
    id = "thickness",
    label = "Thickness:",
    text = string.format("%.1f", defaults.thickness),
    decimals = 5
}

dlg:newrow { always = false }

dlg:slider {
    id = "thickOffset",
    label = "Offset:",
    min = -100,
    max = 100,
    value = defaults.thickOffset
}

dlg:newrow { always = false }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:slider {
    id = "handles",
    label = "Handles:",
    min = 0,
    max = 255,
    value = defaults.handles
}

dlg:newrow { always = false }

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.1f", defaults.scale),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
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
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = AseUtilities.initCanvas(
                64, 64, "Arc",
                { args.fillClr, args.strokeClr })
            local layer = sprite.layers[#sprite.layers]
            local frame = app.activeFrame or 1
            local cel = sprite:newCel(layer, frame)

            local curve = Curve2.arcSector(
                math.rad(360 - args.startAngle),
                math.rad(360 - args.stopAngle),
                args.scale,
                args.thickness,
                0.01 * args.thickOffset,
                args.xOrigin,
                args.yOrigin)

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
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }