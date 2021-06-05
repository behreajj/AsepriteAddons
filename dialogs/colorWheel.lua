dofile("../support/aseutilities.lua")

local representations = {
    "LCH",
    "S_RGB_HSL"
}

local rgbAxes = {
    "HSL_SATURATION",
    "HSL_LIGHTNESS"
}

local lchAxes = {
    "CHROMATICITY",
    "LIGHTNESS"
}

local defaults = {
    sectors = 12,
    rings = 8,
    representation = "LCH",
    rgbAxis = "HSL_LIGHTNESS",
    lchAxis = "LIGHTNESS",
    angMargin = 4,
    ringMargin = 12,
    resolution = 32,
    setPalette = true,
    pullFocus = false
}

local dlg = Dialog { title = "Color Wheel" }

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

dlg:combobox {
    id = "representation",
    label = "Wheel:",
    option = defaults.representation,
    options = representations,
    onchange = function()
        local whl = dlg.data.representation
        dlg:modify {
            id = "rgbAxis",
            visible = whl == "S_RGB_HSL"
        }

        dlg:modify {
            id = "lchAxis",
            visible = whl == "LCH"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "rgbAxis",
    label = "Radius:",
    option = defaults.rgbAxis,
    options = rgbAxes,
    visible = defaults.representation == "S_RGB_HSL",
    onchange = function()
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "lchAxis",
    label = "Radius:",
    option = defaults.lchAxis,
    options = lchAxes,
    visible = defaults.representation == "LCH",
    onchange = function()
    end
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
    text = string.format("%.1f", defaults.ringMargin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:check {
    id = "setPalette",
    label = "Set Palette:",
    selected = defaults.setPalette,
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = AseUtilities.initCanvas(
                512, 512, "Color.Wheel")

            local oldMode = sprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local layer = sprite.layers[#sprite.layers]
            local frame = app.activeFrame or 1
            local cel = sprite:newCel(layer, frame)

            local sectors = args.sectors
            local rings = args.rings
            local angMargin = math.rad(args.angMargin)
            local ringMargin = args.ringMargin or defaults.ringMargin

            local xOrigin = sprite.width * 0.5
            local yOrigin = sprite.height * 0.5

            local toScale = 1.0 / (rings + 1.0)
            local toTheta = 6.283185307179586 / sectors
            local halfAngMargin = angMargin * 0.5
            local halfRingMargin = ringMargin * 0.5

            local scale = 0.5 * math.min(sprite.width, sprite.height)
            local thickness = scale / rings - halfRingMargin
            local len2 = rings * sectors
            local len2n1 = len2 - 1

            local res = args.resolution
            local strokeClr = Color(0, 0, 0, 255)
            local brush = Brush(1)

            local representation = args.representation
            local rgbAxis = args.rgbAxis
            local lchAxis = args.lchAxis
            local cos = math.cos
            local sin = math.sin

            local clrs = {}

            app.transaction(function ()
                for k = 0, len2n1, 1 do
                    local i = k // sectors
                    local j = k % sectors
                    local iStep = (i + 1) * toScale
                    local radius = iStep * scale - halfRingMargin

                    local startAngle = (j + 0.5) * toTheta
                    local stopAngle = (j + 1.5) * toTheta
                    local hue = (1.0 - j / sectors) * 360

                    startAngle = startAngle + halfAngMargin
                    stopAngle = stopAngle - halfAngMargin

                    local curve = Curve2.arcSector(
                        startAngle, stopAngle,
                        radius,
                        thickness, 0.0,
                        xOrigin, yOrigin)

                    local fillClr = nil
                    if representation == "LCH" then
                        local h = 6.283185307179586 * (1.0 - j / sectors)
                        local c = 100.0
                        local l = 67.0
                        if lchAxis == "CHROMATICITY" then
                            c = 100.0 * (i + 1) / rings
                            l = 67.0
                        else
                            c = 85.0
                            l = 100.0 * (i + 1) / rings
                        end

                        local a = c * cos(h)
                        local b = c * sin(h)

                        local clr = Clr.labToRgba(l, a, b, 1.0)
                        clr = Clr.clamp01(clr)
                        fillClr = AseUtilities.clrToAseColor(clr)
                    else
                        if rgbAxis == "HSL_SATURATION" then
                            fillClr = Color {
                                h = hue,
                                s = (i + 1) / rings,
                                l = 0.5,
                                a = 255 }
                        else
                            -- Add fudge factor to lightness.
                            local l = (i + 1) / (rings + 1.0)
                            local f = i / (rings - 1.0)
                            l = (1.0 - f) * (l ^ 1.25) + f * l
                            fillClr = Color {
                                h = hue,
                                s = 1.0,
                                l = l,
                                a = 255 }
                        end
                    end

                    clrs[1 + (j * rings + i)] = fillClr

                    AseUtilities.drawCurve2(
                        curve,
                        res,
                        true, fillClr,
                        false, strokeClr,
                        brush, cel, layer)
                end
            end)

            if args.setPalette then
                local pal = Palette(len2)
                for k = 0, len2n1, 1 do
                    pal:setColor(k, clrs[1 + k])
                end

                sprite:setPalette(pal)
            end

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()
        else
            app.alert("Dialog arguments are invalid.")
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