dofile("../../support/shapeutilities.lua")

local defaults = {
    rings = 4,
    xScale = 32,
    yScale = 32,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    useFill = true,
    pullFocus = false
}

local dlg = Dialog { title = "Hexagon Grid" }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 1,
    max = 32,
    value = defaults.rings
}

dlg:newrow { always = false }

dlg:number {
    id = "xScale",
    label = "Cell:",
    text = string.format("%.1f", defaults.xScale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yScale",
    text = string.format("%.1f", defaults.yScale),
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
    id = "margin",
    label = "Margin:",
    min = 0,
    max = 100,
    value = defaults.margin
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
        local rings = args.rings or defaults.rings --[[@as integer]]
        local xScale = args.xScale or defaults.xScale --[[@as number]]
        local yScale = args.yScale or defaults.yScale --[[@as number]]
        local xOrig = args.xOrig --[[@as number]]
        local yOrig = args.yOrig --[[@as number]]

        local useStroke = args.useStroke --[[@as boolean]]
        local strokeWeight = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor = args.strokeClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local fillColor = args.fillClr --[[@as Color]]

        if xScale < 2.0 then xScale = 2.0 end
        if yScale < 2.0 then yScale = 2.0 end
        local fillHex = AseUtilities.aseColorToHex(
            fillColor, ColorMode.RGB)
        local strokeHex = AseUtilities.aseColorToHex(
            strokeColor, ColorMode.RGB)

        local mesh = Mesh2.gridHex(rings)

        local t = Mat3.fromTranslation(xOrig, yOrig)
        local s = Mat3.fromScale(xScale, -yScale)
        local mat = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        local margin = args.margin * 0.01
        if margin > 0.0 then
            margin = 1.0 - math.min(margin, 0.99)
            mesh:scaleFacesIndiv(margin)
        end

        local sprite = AseUtilities.initCanvas(
            mesh.name, { fillHex, strokeHex })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame
            or sprite.frames[1] --[[@as Frame]]
        local cel = sprite:newCel(layer, frame)

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