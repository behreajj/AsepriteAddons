dofile("../../support/shapeutilities.lua")

local defaults = {
    cells = 8,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    useFill = true,
    pullFocus = false
}

local dlg = Dialog { title = "Dimetric Grid" }

dlg:slider {
    id = "cells",
    label = "Cells:",
    min = 2,
    max = 32,
    value = defaults.cells
}

dlg:newrow { always = false }

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.3f", 2 * math.min(
        app.preferences.new_file.width,
        app.preferences.new_file.height)),
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
        local cells = args.cells or defaults.cells --[[@as integer]]
        local margin100 = args.margin or defaults.margin --[[@as integer]]

        local scale = args.scale or defaults.scale --[[@as number]]
        local xOrig = args.xOrig --[[@as number]]
        local yOrig = args.yOrig --[[@as number]]

        local useStroke = args.useStroke --[[@as boolean]]
        local strokeWeight = args.strokeWeight or defaults.strokeWeight --[[@as integer]]
        local strokeColor = args.strokeClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local fillColor = args.fillClr --[[@as Color]]

        local mesh = Mesh2.gridDimetric(cells)

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        if margin100 > 0 then
            local marginVerif = math.min(
                0.999999,
                margin100 * 0.01)
            Mesh2.uniformData(mesh, mesh)
            mesh:scaleFacesIndiv(1.0 - marginVerif)
        end
        local scaleVerif = math.max(2.0, scale)

        -- Create transformation matrix.
        local t = Mat3.fromTranslation(xOrig, yOrig)
        local s = Mat3.fromScale(scaleVerif, -scaleVerif)
        local mat = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        -- Initialize canvas.
        local fillHex = AseUtilities.aseColorToHex(
            fillColor, ColorMode.RGB)
        local strokeHex = AseUtilities.aseColorToHex(
            strokeColor, ColorMode.RGB)
        local sprite = AseUtilities.initCanvas(
            mesh.name, { fillHex, strokeHex })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame
            or sprite.frames[1] --[[@as Frame]]
        local cel = sprite:newCel(layer, frame)

        ShapeUtilities.drawMesh2(
            mesh, useFill, fillColor,
            useStroke, strokeColor,
            Brush(strokeWeight),
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