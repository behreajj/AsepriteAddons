dofile("../../support/shapeutilities.lua")

local defaults <const> = {
    rings = 4,
    xScale = 32,
    yScale = 32,
    useDimetric = false,
    margin = 0,
    rounding = 0,
    useStroke = true,
    strokeWeight = 1,
    useFill = true,
    useAntialias = false,
}

local dlg <const> = Dialog { title = "Hexagon Grid" }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 1,
    max = 32,
    value = defaults.rings,
    focus = true
}

dlg:newrow { always = false }

dlg:number {
    id = "xScale",
    label = "Cell:",
    text = string.format("%.3f", defaults.xScale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yScale",
    text = string.format("%.3f", defaults.yScale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:check {
    id = "useDimetric",
    label = "Dimetric:",
    text = "&Scale",
    selected = defaults.useDimetric
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
    id = "margin",
    label = "Margin:",
    min = 0,
    max = 100,
    value = defaults.margin
}

dlg:newrow { always = false }

dlg:slider {
    id = "rounding",
    label = "Rounding:",
    min = 0,
    max = 100,
    value = defaults.rounding
}

dlg:newrow { always = false }

dlg:check {
    id = "useStroke",
    label = "Stroke:",
    text = "Enable",
    selected = defaults.useStroke,
    onclick = function()
        local args <const> = dlg.data
        local useStroke <const> = args.useStroke --[[@as boolean]]
        dlg:modify { id = "strokeWeight", visible = useStroke }
        dlg:modify { id = "strokeClr", visible = useStroke }
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
    color = app.preferences.color_bar.fg_color --[[@as Color]],
    visible = defaults.useStroke
}

dlg:newrow { always = false }

dlg:check {
    id = "useFill",
    label = "Fill:",
    text = "Enable",
    selected = defaults.useFill,
    onclick = function()
        local args <const> = dlg.data
        local useFill <const> = args.useFill --[[@as boolean]]
        dlg:modify {
            id = "fillClr",
            visible = useFill
        }
    end
}

dlg:color {
    id = "fillClr",
    color = app.preferences.color_bar.bg_color --[[@as Color]],
    visible = defaults.useFill
}

dlg:newrow { always = false }

dlg:check {
    id = "useAntialias",
    label = "Antialias:",
    text = "Enable",
    selected = defaults.useAntialias
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frame <const> = site.frame
        if not frame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args <const> = dlg.data
        local rings <const> = args.rings
            or defaults.rings --[[@as integer]]
        local xScale = args.xScale
            or defaults.xScale --[[@as number]]
        local yScale = args.yScale
            or defaults.yScale --[[@as number]]
        local useDimetric <const> = args.useDimetric --[[@as boolean]]
        local xOrig <const> = args.xOrig --[[@as number]]
        local yOrig <const> = args.yOrig --[[@as number]]
        local margin100 <const> = args.margin
            or defaults.margin --[[@as integer]]
        local rounding100 <const> = args.rounding
            or defaults.rounding --[[@as integer]]

        local useStroke <const> = args.useStroke --[[@as boolean]]
        local strokeWeight <const> = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor <const> = args.strokeClr --[[@as Color]]
        local useFill <const> = args.useFill --[[@as boolean]]
        local fillColor <const> = args.fillClr --[[@as Color]]
        local useAntialias <const> = args.useAntialias --[[@as boolean]]

        if xScale < 2.0 then xScale = 2.0 end
        if yScale < 2.0 then yScale = 2.0 end
        if useDimetric then
            -- sqrt(3) / 2 = 0.8660254
            xScale = xScale * 1.1547005383793
        end

        local curves <const> = Curve2.gridHex(rings,
            0.5, 0.5 * (margin100 * 0.01), rounding100 * 0.01)

        local t <const> = Mat3.fromTranslation(xOrig, yOrig)
        local s <const> = Mat3.fromScale(xScale, -yScale)
        local mat <const> = Mat3.mul(t, s)

        local layer <const> = sprite:newLayer()
        layer.name = "Hex Grid"

        local useTrim <const> = true
        local lenCurves <const> = #curves
        local i = 0
        while i < lenCurves do
            i = i + 1
            local curve <const> = curves[i]
            Utilities.mulMat3Curve2(mat, curve)
            ShapeUtilities.drawCurve2(
                sprite, curve,
                useFill, fillColor,
                useStroke, strokeColor, strokeWeight,
                frame, layer,
                useAntialias, useTrim)
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

dlg:show {
    autoscrollbars = true,
    wait = false
}