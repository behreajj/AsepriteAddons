dofile("../../support/shapeutilities.lua")

local defaults = {
    sides = 6,
    skip = 0,
    pick = 0,
    inset = 50,
    resolution = 16,
    angle = 90,
    scale = 32,
    useStroke = false,
    strokeWeight = 1,
    useFill = true,
    pullFocus = false
}

local dlg = Dialog { title = "Polygon" }

dlg:slider {
    id = "sides",
    label = "Sides:",
    min = 3,
    max = 16,
    value = defaults.sides
}

dlg:newrow { always = false }

dlg:slider {
    id = "skip",
    label = "Skip:",
    min = 0,
    max = 10,
    value = defaults.skip,
    onchange = function()
        local args = dlg.data
        dlg:modify {
            id = "inset",
            visible = args.skip > 0 and args.pick > 0
        }
    end
}

dlg:slider {
    id = "pick",
    min = 0,
    max = 10,
    value = defaults.pick,
    onchange = function()
        local args = dlg.data
        dlg:modify {
            id = "inset",
            visible = args.skip > 0 and args.pick > 0
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "inset",
    label = "Inset:",
    min = 0,
    max = 100,
    value = defaults.inset,
    visible = defaults.skip > 0
        and defaults.pick > 0
}

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:newrow { always = false }

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.3f", defaults.scale),
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
        local args = dlg.data
        local sectors = args.sides or defaults.sides --[[@as integer]]
        local skip = args.skip or defaults.skip --[[@as integer]]
        local pick = args.pick or defaults.pick --[[@as integer]]
        local inset = args.inset or defaults.inset --[[@as integer]]

        local degrees = args.angle or defaults.angle --[[@as integer]]
        local scale = args.scale or defaults.scale --[[@as number]]
        local xOrig = args.xOrig --[[@as number]]
        local yOrig = args.yOrig --[[@as number]]

        local useStroke = args.useStroke --[[@as boolean]]
        local strokeWeight = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor = args.strokeClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local fillColor = args.fillClr --[[@as Color]]

        -- Create transform matrix.
        local t = Mat3.fromTranslation(xOrig, yOrig)

        local a = degrees * 0.017453292519943
        local query = AseUtilities.DIMETRIC_ANGLES[degrees]
        if query then a = query end
        local r = Mat3.fromRotZ(a)

        local sclVerif = scale
        if sclVerif < 2.0 then sclVerif = 2.0 end
        local s = Mat3.fromScale(sclVerif, -sclVerif)

        local mat = Mat3.mul(Mat3.mul(t, s), r)

        -- Initialize canvas.
        local fillHex = AseUtilities.aseColorToHex(
            fillColor, ColorMode.RGB)
        local strokeHex = AseUtilities.aseColorToHex(
            strokeColor, ColorMode.RGB)
        local name = string.format("Polygon.%03d", sectors)
        local sprite = AseUtilities.initCanvas(
            name, { fillHex, strokeHex })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame
            or sprite.frames[1] --[[@as Frame]]
        local cel = sprite:newCel(layer, frame)

        local mesh = Mesh2.star(
            sectors, skip, pick, inset * 0.01)
        Utilities.mulMat3Mesh2(mat, mesh)
        ShapeUtilities.drawMesh2(
            mesh, useFill, fillColor,
            useStroke, strokeColor,
            Brush { size = strokeWeight },
            cel, layer)

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