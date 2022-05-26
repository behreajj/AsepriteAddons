dofile("../../support/aseutilities.lua")
dofile("../../support/curve3.lua")

local defaults = {
    resolution = 32,
    handles = 0,
    xRadius = 32.0,
    yRadius = 24.0,
    xOrigin = 0.0,
    yOrigin = 0.0,
    angle = 0,
    axx = 0.0,
    axy = 0.0,
    axz = 1.0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.hexToAseColor(
        AseUtilities.DEFAULT_STROKE),
    useFill = true,
    fillClr = AseUtilities.hexToAseColor(
        AseUtilities.DEFAULT_FILL),
    pullFocus = false
}

local dlg = Dialog { title = "Ellipse" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 2,
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

dlg:number {
    id = "axx",
    label = "Axis:",
    text = string.format("%.3f", defaults.axx),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "axy",
    text = string.format("%.3f", defaults.axy),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "axz",
    text = string.format("%.3f", defaults.axz),
    decimals = AseUtilities.DISPLAY_DECIMAL
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
        -- Support for 3D rotation.
        -- See https://github.com/aseprite/api/issues/17 .

        local args = dlg.data
        local xr = args.xRadius or defaults.xRadius
        local yr = args.yRadius or defaults.yRadius
        local xc = args.xOrigin or defaults.xOrigin
        local yc = args.yOrigin or defaults.yOrigin
        local angDeg = args.angle or defaults.angle
        local axx = args.axx or defaults.axx
        local axy = args.axy or defaults.axy
        local axz = args.axz or defaults.axz

        local angRad = math.rad(angDeg)
        local axis = Vec3.new(axx, axy, axz)
        if Vec3.any(axis) then
            axis = Vec3.normalize(axis)
        else
            axis = Vec3.forward()
        end

        local curve = Curve3.ellipse(xr, yr)
        -- local layerName = string.format(
        --     "%s.%03d.(%.3f, %.3f, %.3f)",
        --     curve.name, angDeg, axis.x, axis.y, axis.z)
        local layerName = curve.name

        local t = Mat4.fromTranslation(xc, yc, 0.0)
        local r = Mat4.fromRotInternal(
            math.cos(angRad), math.sin(angRad),
            axis.x, axis.y, axis.z)
        local s = Mat4.fromScale(1.0, -1.0, 1.0)
        local mat = t * s * r
        Utilities.mulMat4Curve3(mat, curve)

        local sprite = AseUtilities.initCanvas(
            64, 64, layerName,
            { args.fillClr.rgbaPixel,
              args.strokeClr.rgbaPixel })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame or sprite.frames[1]
        local cel = sprite:newCel(layer, frame)

        -- Technically, this shouldn't work, but a Curve3
        -- has the same fields as a Curve2.
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

        app.refresh()
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