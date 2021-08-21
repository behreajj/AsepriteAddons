dofile("../../support/aseutilities.lua")

local defaults = {
    rings = 4,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(AseUtilities.DEFAULT_STROKE),
    useFill = true,
    fillClr = Color(AseUtilities.DEFAULT_FILL),
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
    id = "scale",
    label = "Cell Size:",
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
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        local mesh = Mesh2.gridHex(args.rings)

        local sclval = args.scale
        if sclval < 2.0 then
            sclval = 2.0
        end

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        local mrgval = args.margin * 0.01
        if mrgval > 0.0 then
            mrgval = math.min(mrgval, 0.99)
            mesh:scaleFacesIndiv(1.0 - mrgval)
        end

        local t = Mat3.fromTranslation(
            args.xOrigin,
            args.yOrigin)
        local s = Mat3.fromScale(sclval, -sclval)
        local mat = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        local sprite = AseUtilities.initCanvas(
            64, 64, mesh.name,
            { args.fillClr.rgbaPixel,
              args.strokeClr.rgbaPixel })
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
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }