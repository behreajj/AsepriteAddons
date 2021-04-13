dofile("../support/mat3.lua")
dofile("../support/mesh2.lua")
dofile("../support/utilities.lua")
dofile("../support/aseutilities.lua")

local defaults = {
    cells = 8,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(128, 119, 102, 255),
    useFill = true,
    fillClr = Color(255, 245, 215, 255)}

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
    focus = true,
    onclick = function()

    local args = dlg.data
    if args.ok then
        local mesh = Mesh2.gridDimetric(args.cells)

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        if args.margin > 0 then
            local mrgval = math.min(
                0.999999,
                args.margin * 0.01)
            Mesh2.uniformData(mesh, mesh)
            mesh:scaleFacesIndiv(1.0 - mrgval)
        end

        local t = Mat3.fromTranslation(
            args.xOrigin,
            args.yOrigin)
        local sclval = args.scale
        if sclval < 2.0 then sclval = 2.0 end
        local s = Mat3.fromScale(sclval, -sclval)
        local mat = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        local sprite = AseUtilities.initCanvas(
            64, 64, mesh.name,
            { args.fillClr, args.strokeClr })
        local layer = sprite.layers[#sprite.layers]

        AseUtilities.drawMesh2(
            mesh,
            args.useFill,
            args.fillClr,
            args.useStroke,
            args.strokeClr,
            Brush(args.strokeWeight),
            sprite:newCel(layer, 1),
            layer)
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