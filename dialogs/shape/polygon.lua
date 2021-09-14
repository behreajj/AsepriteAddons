dofile("../../support/mat3.lua")
dofile("../../support/mesh2.lua")
dofile("../../support/utilities.lua")
dofile("../../support/aseutilities.lua")

local defaults = {
    sides = 6,
    angle = 90,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    useFill = true,
    fillClr = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    pullFocus = false
}

local dlg = Dialog { title = "Convex Polygon" }

dlg:slider {
    id = "sides",
    label = "Sides:",
    min = 3,
    max = 16,
    value = defaults.sides
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
    id = "scale",
    label = "Scale:",
    text = string.format("%.1f", defaults.scale),
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
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()

    local args = dlg.data
    local mesh = Mesh2.polygon(args.sides)

    local t = Mat3.fromTranslation(
        args.xOrigin,
        args.yOrigin)
    local r = Mat3.fromRotZ(math.rad(args.angle))
    local sclval = args.scale
    if sclval < 2.0 then sclval = 2.0 end
    local s = Mat3.fromScale(sclval, -sclval)
    local mat = Mat3.mul(Mat3.mul(t, s), r)
    Utilities.mulMat3Mesh2(mat, mesh)

    local sprite = AseUtilities.initCanvas(
        64, 64, mesh.name,
        { args.fillClr.rgbaPixel,
          args.strokeClr.rgbaPixel })
    local layer = sprite.layers[#sprite.layers]
    local frame = app.activeFrame or sprite.frames[1]
    local cel = sprite:newCel(layer, frame)

    AseUtilities.drawMesh2(
        mesh,
        args.useFill,
        args.fillClr,
        args.useStroke,
        args.strokeClr,
        Brush(args.strokeWeight),
        cel,
        layer)
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