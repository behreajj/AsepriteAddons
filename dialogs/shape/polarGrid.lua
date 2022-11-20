dofile("../../support/aseutilities.lua")

local defaults = {
    sectors = 8,
    rings = 2,
    angOffset = 0,
    angMargin = 0,
    ringMargin = 0,
    resolution = 32,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = AseUtilities.hexToAseColor(
        AseUtilities.DEFAULT_STROKE),
    useFill = false,
    fillClr = AseUtilities.hexToAseColor(
        AseUtilities.DEFAULT_FILL),
    pullFocus = false
}

local dlg = Dialog { title = "Polar Grid" }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 1,
    max = 36,
    value = defaults.sectors
}

dlg:newrow { always = false }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 2,
    max = 32,
    value = defaults.rings
}

dlg:newrow { always = false }

dlg:slider {
    id = "angOffset",
    label = "Angle Offset:",
    min = -45,
    max = 45,
    value = defaults.angOffset
}

dlg:newrow { always = false }

dlg:slider {
    id = "angMargin",
    label = "Angle Margin:",
    min = 0,
    max = 30,
    value = defaults.angMargin
}

dlg:newrow { always = false }

dlg:number {
    id = "ringMargin",
    label = "Ring Margin:",
    text = string.format("%.3f", defaults.ringMargin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 2,
    max = 64,
    value = defaults.resolution
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
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.3f", defaults.xOrigin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.3f", defaults.yOrigin),
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
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local sprite = AseUtilities.initCanvas(
            64, 64, "Grid.Polar",
            { args.fillClr.rgbaPixel,
                args.strokeClr.rgbaPixel })
        local layer = sprite.layers[#sprite.layers]
        local frame = app.activeFrame or sprite.frames[1]
        local cel = sprite:newCel(layer, frame)

        local sectors = args.sectors
        local rings = args.rings
        local angOffset = args.angOffset * 0.017453292519943
        local angMargin = args.angMargin * 0.017453292519943
        local ringMargin = args.ringMargin or defaults.ringMargin
        local scale = args.scale or defaults.scale
        local xOrigin = args.xOrigin or defaults.xOrigin --[[@as number]]
        local yOrigin = args.yOrigin or defaults.yOrigin --[[@as number]]

        local toScale = 1.0 / rings
        local toTheta = 6.2831853071796 / sectors
        local halfAngMargin = angMargin * 0.5
        local halfRingMargin = ringMargin * 0.5
        local thickness = scale / rings - halfRingMargin

        local brush = Brush(args.strokeWeight)
        local strokeClr = args.strokeClr or defaults.strokeClr --[[@as Color]]
        local useStroke = args.useStroke --[[@as boolean]]
        local fillClr = args.fillClr or defaults.fillClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local resolution = args.resolution
            or defaults.resolution --[[@as integer]]

        app.transaction(function()
            local k = 0
            local len2 = rings * sectors
            while k < len2 do
                local i = k // sectors
                local j = k % sectors
                k = k + 1
                local iStep = (i + 1) * toScale
                local offset = i * angOffset
                local radius = iStep * scale - halfRingMargin

                local startAngle = offset + j * toTheta
                local stopAngle = offset + (j + 1) * toTheta

                startAngle = startAngle + halfAngMargin
                stopAngle = stopAngle - halfAngMargin

                local curve = Curve2.arcSector(
                    startAngle, stopAngle,
                    radius,
                    thickness, -1.0,
                    xOrigin, yOrigin)

                AseUtilities.drawCurve2(
                    curve,
                    resolution,
                    useFill, fillClr,
                    useStroke, strokeClr,
                    brush, cel, layer)
            end
        end)

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