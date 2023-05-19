dofile("../../support/shapeutilities.lua")

local defaults = {
    resolution = 32,
    handles = 0,
    xRadius = 32.0,
    yRadius = 24.0,
    angle = 0,
    axx = 0.0,
    axy = 0.0,
    axz = 1.0,
    useStroke = false,
    strokeWeight = 1,
    useFill = true,
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
    text = string.format("%.3f", defaults.xRadius),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yRadius",
    text = string.format("%.3f", defaults.yRadius),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrig",
    label = "Origin:",
    text = string.format("%.3f",
        app.preferences.new_file.width * 0.5),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yOrig",
    text = string.format("%.3f",
        app.preferences.new_file.height * 0.5),
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
    color = app.preferences.color_bar.bg_color,
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
    color = app.preferences.color_bar.fg_color,
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

        local site = app.site
        local sprite = site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frame = site.frame
        if not frame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args = dlg.data
        local resolution = args.resolution or defaults.resolution --[[@as integer]]
        local handles = args.handles or defaults.handles --[[@as integer]]
        local xr = args.xRadius or defaults.xRadius --[[@as number]]
        local yr = args.yRadius or defaults.yRadius --[[@as number]]
        local xc = args.xOrig --[[@as number]]
        local yc = args.yOrig --[[@as number]]
        local angDeg = args.angle or defaults.angle --[[@as integer]]
        local axx = args.axx or defaults.axx --[[@as number]]
        local axy = args.axy or defaults.axy --[[@as number]]
        local axz = args.axz or defaults.axz --[[@as number]]

        local useStroke = args.useStroke --[[@as boolean]]
        local strokeWeight = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor = args.strokeClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local fillColor = args.fillClr --[[@as Color]]

        local angRad = math.rad(angDeg)
        local axis = Vec3.new(axx, axy, axz)
        if Vec3.any(axis) then
            axis = Vec3.normalize(axis)
        else
            axis = Vec3.forward()
        end

        local curve = Curve3.ellipse(xr, yr)

        local t = Mat4.fromTranslation(xc, yc, 0.0)
        local r = Mat4.fromRotInternal(
            math.cos(angRad), math.sin(angRad),
            axis.x, axis.y, axis.z)
        local s = Mat4.fromScale(1.0, -1.0, 1.0)
        local mat = Mat4.mul(Mat4.mul(t, s), r)
        Utilities.mulMat4Curve3(mat, curve)

        local layer = nil
        app.transaction("New Layer", function()
            layer = sprite:newLayer()
            layer.name = curve.name
        end)

        -- Technically, this shouldn't work, but a Curve3
        -- has the same fields as a Curve2.
        ShapeUtilities.drawCurve2(
            curve --[[@as Curve2]],
            resolution,
            useFill, fillColor,
            useStroke, strokeColor,
            Brush { size = strokeWeight },
            frame, layer)

        if handles > 0 then
            local handlesLayer = nil
            app.transaction("Handles Layer", function()
                handlesLayer = sprite:newLayer()
                handlesLayer.name = curve.name .. ".Handles"
                handlesLayer.opacity = handles
            end)
            ShapeUtilities.drawHandles2(
                curve --[[@as Curve2]],
                frame, handlesLayer)
        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }