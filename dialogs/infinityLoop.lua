dofile("../Support/mat3.lua")
dofile("../Support/curve2.lua")
dofile("../Support/utilities.lua")
dofile("../Support/aseutilities.lua")

local defaults = {
    resolution = 32,
    angle = 0,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useFill = false,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(255, 245, 215, 255),
    fillClr = Color(32, 32, 32, 255),
    handles = 0
}

local dlg = Dialog { title = "Infinity Loop" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.1f", defaults.scale),
    decimals = 5
}

dlg:number {
    id = "xOrigin",
    label = "Origin X:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    label = "Origin Y:",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
}

dlg:check {
    id = "useStroke",
    label = "Use Stroke:",
    selected = defaults.useStroke
}

dlg:slider {
    id = "strokeWeight",
    label = "Stroke Weight:",
    min = 1,
    max = 64,
    value = defaults.strokeWeight
}

dlg:color {
    id = "strokeClr",
    label = "Stroke Color:",
    color = defaults.strokeClr
}

dlg:check {
    id = "useFill",
    label = "Use Fill:",
    selected = defaults.useFill
}

dlg:color {
    id = "fillClr",
    label = "Fill Color:",
    color = defaults.fillClr
}

dlg:slider {
    id = "handles",
    label = "Handles:",
    min = 0,
    max = 255,
    value = defaults.handles
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()

        local args = dlg.data
        if args.ok then
            local curve = Curve2.infinity()

            local t = Mat3.fromTranslation(
                args.xOrigin,
                args.yOrigin)
            local r = Mat3.fromRotZ(math.rad(args.angle))
            local sclval = args.scale
            if sclval < 2.0 then sclval = 2.0 end
            local s = Mat3.fromScale(sclval, -sclval)
            local mat = Mat3.mul(Mat3.mul(t, s), r)
            Utilities.mulMat3Curve2(mat, curve)

            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local layer = sprite:newLayer()
            layer.name = curve.name

            AseUtilities.drawCurve2(
                curve,
                args.resolution,
                args.useFill,
                args.fillClr,
                args.useStroke,
                args.strokeClr,
                Brush(args.strokeWeight),
                sprite:newCel(layer, 1),
                layer)

            if args.handles > 0 then
                local hlLyr = sprite:newLayer()
                hlLyr.name = curve.name .. ".Handles"
                hlLyr.opacity = args.handles
                AseUtilities.drawHandles2(
                    curve,
                    sprite:newCel(hlLyr, 1),
                    hlLyr)
            end
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