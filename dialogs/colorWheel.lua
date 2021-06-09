dofile("../support/aseutilities.lua")

local representations = {
    "LCH",
    "S_RGB_HSL"
}

local rgbAxes = {
    "SATURATION",
    "LIGHTNESS"
}

local lchAxes = {
    "CHROMA",
    "LUMINANCE"
}

local defaults = {
    setPalette = true,
    sectors = 12,
    rings = 8,
    resolution = 32,

    representation = "LCH",
    rgbAxis = "LIGHTNESS",
    lchAxis = "LUMINANCE",

    rgbSatMin = 15,
    rgbSatMax = 100,
    rgbSatStable = 100,

    rgbLightMin = 15,
    rgbLightMax = 85,
    rgbLightStable = 50,

    lchChromaMin = 15,
    lchChromaMax = 85,
    lchChromaStable = 70,

    lchLumMin = 10,
    lchLumMax = 75,
    lchLumStable = 65,

    pullFocus = false
}

local dlg = Dialog { title = "Color Wheel" }

dlg:check {
    id = "setPalette",
    label = "Set Palette:",
    selected = defaults.setPalette,
}

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
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:combobox {
    id = "representation",
    label = "Wheel:",
    option = defaults.representation,
    options = representations,
    onchange = function()
        local whl = dlg.data.representation
        if whl == "S_RGB_HSL" then
            local axis = dlg.data.rgbAxis
            local satAxis = axis == "SATURATION"
            local lightAxis = axis == "LIGHTNESS"

            dlg:modify { id = "rgbAxis", visible = true }

            dlg:modify { id = "rgbSatMin", visible = satAxis }
            dlg:modify { id = "rgbSatMax", visible = satAxis }
            dlg:modify { id = "rgbSatStable", visible = not satAxis }

            dlg:modify { id = "rgbLightMin", visible = lightAxis }
            dlg:modify { id = "rgbLightMax", visible = lightAxis }
            dlg:modify { id = "rgbLightStable", visible = not lightAxis }

            dlg:modify { id = "lchAxis", visible = false }

            dlg:modify { id = "lchChromaMin", visible = false }
            dlg:modify { id = "lchChromaMax", visible = false }
            dlg:modify { id = "lchChromaStable", visible = false }

            dlg:modify { id = "lchLumMin", visible = false }
            dlg:modify { id = "lchLumMax", visible = false }
            dlg:modify { id = "lchLumStable", visible = false }
        else
            local axis = dlg.data.lchAxis
            local chromaAxis = axis == "CHROMA"
            local lumAxis = axis == "LUMINANCE"

            dlg:modify { id = "lchAxis", visible = true }

            dlg:modify { id = "lchChromaMin", visible = chromaAxis }
            dlg:modify { id = "lchChromaMax", visible = chromaAxis }
            dlg:modify { id = "lchChromaStable", visible = not chromaAxis }

            dlg:modify { id = "lchLumMin", visible = lumAxis }
            dlg:modify { id = "lchLumMax", visible = lumAxis }
            dlg:modify { id = "lchLumStable", visible = not lumAxis }

            dlg:modify { id = "rgbAxis", visible = false }

            dlg:modify { id = "rgbSatMin", visible = false }
            dlg:modify { id = "rgbSatMax", visible = false }
            dlg:modify { id = "rgbSatStable", visible = false }

            dlg:modify { id = "rgbLightMin", visible = false }
            dlg:modify { id = "rgbLightMax", visible = false }
            dlg:modify { id = "rgbLightStable", visible = false }
        end

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
        local axis = dlg.data.rgbAxis
        if axis == "SATURATION" then
            dlg:modify { id = "rgbSatMin", visible = true }
            dlg:modify { id = "rgbSatMax", visible = true }
            dlg:modify { id = "rgbLightStable", visible = true }

            dlg:modify { id = "rgbLightMin", visible = false }
            dlg:modify { id = "rgbLightMax", visible = false }
            dlg:modify { id = "rgbSatStable", visible = false }
        else
            dlg:modify { id = "rgbLightMin", visible = true }
            dlg:modify { id = "rgbLightMax", visible = true }
            dlg:modify { id = "rgbSatStable", visible = true }

            dlg:modify { id = "rgbSatMin", visible = false }
            dlg:modify { id = "rgbSatMax", visible = false }
            dlg:modify { id = "rgbLightStable", visible = false }
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rgbSatMin",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.rgbSatMin,
    visible = defaults.representation == "S_RGB_HSL"
        and defaults.rgbAxis == "SATURATION"
}

dlg:slider {
    id = "rgbSatMax",
    min = 0,
    max = 100,
    value = defaults.rgbSatMax,
    visible = defaults.representation == "S_RGB_HSL"
        and defaults.rgbAxis == "SATURATION"
}

dlg:newrow { always = false }

dlg:slider {
    id = "rgbSatStable",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.rgbSatStable,
    visible = defaults.representation == "S_RGB_HSL"
        and defaults.rgbAxis ~= "SATURATION"
}

dlg:newrow { always = false }

dlg:slider {
    id = "rgbLightMin",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.rgbLightMin,
    visible = defaults.representation == "S_RGB_HSL"
        and defaults.rgbAxis == "LIGHTNESS"
}

dlg:slider {
    id = "rgbLightMax",
    min = 0,
    max = 100,
    value = defaults.rgbLightMax,
    visible = defaults.representation == "S_RGB_HSL"
    and defaults.rgbAxis == "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "rgbLightStable",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.rgbLightStable,
    visible = defaults.representation == "S_RGB_HSL"
    and defaults.rgbAxis ~= "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "lchAxis",
    label = "Radius:",
    option = defaults.lchAxis,
    options = lchAxes,
    visible = defaults.representation == "LCH",
    onchange = function()
        local axis = dlg.data.lchAxis
        if axis == "CHROMA" then
            dlg:modify { id = "lchChromaMin", visible = true }
            dlg:modify { id = "lchChromaMax", visible = true }
            dlg:modify { id = "lchLumStable", visible = true }

            dlg:modify { id = "lchLumMin", visible = false }
            dlg:modify { id = "lchLumMax", visible = false }
            dlg:modify { id = "lchChromaStable", visible = false }
        else
            dlg:modify { id = "lchLumMin", visible = true }
            dlg:modify { id = "lchLumMax", visible = true }
            dlg:modify { id = "lchChromaStable", visible = true }

            dlg:modify { id = "lchChromaMin", visible = false }
            dlg:modify { id = "lchChromaMax", visible = false }
            dlg:modify { id = "lchLumStable", visible = false }
        end
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "lchLumMin",
    label = "Luminance:",
    text = string.format("%.0f", defaults.lchLumMin),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis == "LUMINANCE"
}

dlg:number {
    id = "lchLumMax",
    text = string.format("%.0f", defaults.lchLumMax),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis == "LUMINANCE"
}

dlg:newrow { always = false }

dlg:number {
    id = "lchLumStable",
    label = "Luminance:",
    text = string.format("%.0f", defaults.lchLumStable),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis ~= "LUMINANCE"
}

dlg:newrow { always = false }

dlg:number {
    id = "lchChromaMin",
    label = "Chroma:",
    text = string.format("%.0f", defaults.lchChromaMin),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis == "CHROMA"
}

dlg:number {
    id = "lchChromaMax",
    text = string.format("%.0f", defaults.lchChromaMax),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis == "CHROMA"
}

dlg:newrow { always = false }

dlg:number {
    id = "lchChromaStable",
    label = "Chroma:",
    text = string.format("%.0f", defaults.lchChromaStable),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.representation == "LCH"
        and defaults.lchAxis ~= "CHROMA"
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

            local xOrigin = sprite.width * 0.5
            local yOrigin = sprite.height * 0.5

            local toScale = 1.0 / (rings + 1.0)
            local toStep = 1.0 / (rings - 1.0)
            local toTheta = 6.283185307179586 / sectors

            local scale = 0.5 * math.min(sprite.width, sprite.height)
            local thickness = scale / rings
            local len2 = rings * sectors
            local len2n1 = len2 - 1

            local res = args.resolution
            local strokeClr = Color(0, 0, 0, 255)
            local brush = Brush(1)

            local representation = args.representation
            local rgbAxis = args.rgbAxis
            local lchAxis = args.lchAxis
            local min = math.min
            local max = math.max
            local cos = math.cos
            local sin = math.sin

            local rgbSatMin = 0.01 * args.rgbSatMin
            local rgbSatMax = 0.01 * args.rgbSatMax
            local rgbSatStable = 0.01 * args.rgbSatStable

            local rgbLightMin = 0.01 * args.rgbLightMin
            local rgbLightMax = 0.01 * args.rgbLightMax
            local rgbLightStable = 0.01 * args.rgbLightStable

            local lchChromaMin = args.lchChromaMin or defaults.lchChromaMin
            local lchChromaMax = args.lchChromaMax or defaults.lchChromaMax
            local lchChromaStable = args.lchChromaStable or defaults.lchChromaStable

            lchChromaMin = max(lchChromaMin, 0)
            lchChromaMax = min(lchChromaMax, 132)
            lchChromaStable = max(0, min(132, lchChromaStable))

            local lchLumMin = args.lchLumMin or defaults.lchLumMin
            local lchLumMax = args.lchLumMax or defaults.lchLumMax
            local lchLumStable = args.lchLumStable or defaults.lchLumStable

            lchLumMin = max(lchLumMin, 0)
            lchLumMax = min(lchLumMax, 100)
            lchLumStable = max(0, min(100, lchLumStable))

            local clrs = {}

            app.transaction(function ()
                for k = 0, len2n1, 1 do
                    local i = k // sectors
                    local j = k % sectors
                    local iStep1 = (i + 1) * toScale
                    local iStep0 = i * toStep
                    local radius = iStep1 * scale

                    local startAngle = (j - 0.5) * toTheta
                    local stopAngle = (j + 0.5) * toTheta
                    local hue = (1.0 - j / sectors) * 360

                    local curve = Curve2.arcSector(
                        startAngle, stopAngle,
                        radius,
                        thickness, 0.0,
                        xOrigin, yOrigin)

                    local fillClr = nil
                    if representation == "LCH" then
                        local h = 6.283185307179586 * (1.0 - j / sectors)
                        local c = lchChromaStable
                        local l = lchLumStable
                        if lchAxis == "CHROMA" then
                            c = (1.0 - iStep0) * lchChromaMin
                                      + iStep0 * lchChromaMax
                        else
                            l = (1.0 - iStep0) * lchLumMin
                                      + iStep0 * lchLumMax
                        end

                        local cosHue = cos(h)
                        local sinHue = sin(h)
                        local clr = Clr.labToRgba(l, c * cosHue, c * sinHue, 1.0)

                        if Clr.rgbIsInGamut(clr) then
                            clr = Clr.clamp01(clr)
                            fillClr = AseUtilities.clrToAseColor(clr)
                        else

                            -- Desaturate to bring into gamut,
                            -- effectively, excess is treated as blowout.
                            -- Get greedier as the search precedes be increasing
                            -- the search step as you go.
                            -- local satNew = c
                            -- local searchStep = 1.0
                            -- local limit = 10
                            -- local g = 0
                            -- while (g < limit) and (not Clr.rgbIsInGamut(clr)) do
                            --     satNew = satNew - searchStep
                            --     clr = Clr.labToRgba(l, satNew * cosHue, satNew * sinHue, 1.0)
                            --     g = g + 1
                            --     searchStep = searchStep + 1.0
                            -- end

                            clr = Clr.clamp01(clr)
                            fillClr = AseUtilities.clrToAseColor(clr)
                        end
                    else
                        if rgbAxis == "SATURATION" then
                            local sat = (1.0 - iStep0) * rgbSatMin
                                              + iStep0 * rgbSatMax

                            fillClr = Color {
                                h = hue,
                                s = sat,
                                l = rgbLightStable,
                                a = 255 }
                        else
                            local light = (1.0 - iStep0) * rgbLightMin
                                                + iStep0 * rgbLightMax

                            fillClr = Color {
                                h = hue,
                                s = rgbSatStable,
                                l = light,
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