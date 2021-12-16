dofile("../../support/mat3.lua")
dofile("../../support/curve2.lua")
dofile("../../support/utilities.lua")
dofile("../../support/aseutilities.lua")

local defaults = {
    resolution = 32,
    handles = 0,
    xRadius = 32.0,
    yRadius = 24.0,
    xOrigin = 0.0,
    yOrigin = 0.0,
    angle = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    useFill = true,
    fillClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    pullFocus = false
}

local dlg = Dialog { title = "Ellipse" }

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
    id = "xRadius",
    label = "Radius:",
    text = string.format("%.1f", defaults.xRadius),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yRadius",
    text = string.format("%.1f", defaults.yRadius),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
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
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local curve = Curve2.ellipse(
            args.xRadius,
            args.yRadius)

        local t = Mat3.fromTranslation(
            args.xOrigin,
            args.yOrigin)
        local r = Mat3.fromRotZ(math.rad(args.angle))
        local s = Mat3.fromScale(1.0, -1.0)
        local mat = t * s * r
        Utilities.mulMat3Curve2(mat, curve)

        local sprite = AseUtilities.initCanvas(
            64, 64, curve.name,
            { args.fillClr.rgbaPixel,
              args.strokeClr.rgbaPixel })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame or sprite.frames[1]
        local cel = sprite:newCel(layer, frame)

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