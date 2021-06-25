dofile("../../support/aseutilities.lua")

local defaults = {
    startAngle = 0,
    stopAngle = 90,
    startWeight = 50,
    stopWeight = 50,
    sectors = 32,
    margin = 0,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.DEFAULT_STROKE,
    useFill = true,
    fillClr = AseUtilities.DEFAULT_FILL,
    pullFocus = false
}

local dlg = Dialog { title = "Mesh Arc" }

dlg:slider {
    id = "startAngle",
    label = "Angles:",
    min = 0,
    max = 360,
    value = defaults.startAngle
}

dlg:slider {
    id = "stopAngle",
    text = "Stop",
    min = 0,
    max = 360,
    value = defaults.stopAngle
}

dlg:newrow { always = false }

dlg:slider {
    id = "startWeight",
    label = "Weights:",
    min = 0,
    max = 100,
    value = defaults.startWeight
}

dlg:slider {
    id = "stopWeight",
    min = 0,
    max = 100,
    value = defaults.stopWeight
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 3,
    max = 64,
    value = defaults.sectors
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
    id = "confirm",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()

    local args = dlg.data
    local useQuads = args.margin > 0
    local mesh = Mesh2.arc(
        math.rad(args.startAngle),
        math.rad(args.stopAngle),
        0.01 * args.startWeight,
        0.01 * args.stopWeight,
        args.sectors,
        useQuads)

    local sclval = args.scale
    if sclval < 2.0 then
        sclval = 2.0
    end

    local mrgval = args.margin * 0.01
    if mrgval > 0.0 then
        mrgval = math.min(mrgval, 0.99)
        Mesh2.uniformData(mesh, mesh)
        mesh:scaleFacesIndiv(1.0 - mrgval)
    end

    local t = Mat3.fromTranslation(
        args.xOrigin,
        args.yOrigin)
    local s = Mat3.fromScale(sclval, -sclval)
    local mat = Mat3.mul(t, s)
    Utilities.mulMat3Mesh2(mat, mesh)

    local sprite = AseUtilities.initCanvas(
        64, 64,
        mesh.name,
        { args.fillClr, args.strokeClr })
    local layer = sprite.layers[#sprite.layers]
    local frame = app.activeFrame or 1
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
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }