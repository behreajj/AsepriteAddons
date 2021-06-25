dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local defaults = {
    xOrigin = 0,
    yOrigin = 50,
    xDest = 100,
    yDest = 50,
    quantization = 0,
    tweenOps = "PAIR",
    startIndex = 0,
    count = 256,
    aColor = AseUtilities.DEFAULT_STROKE,
    bColor = AseUtilities.DEFAULT_FILL,
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local dlg = Dialog { title = "Linear Gradient" }

dlg:slider {
    id = "xOrigin",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrigin
}

dlg:slider {
    id = "yOrigin",
    min = 0,
    max = 100,
    value = defaults.yOrigin
}

dlg:newrow { always = false }

dlg:slider {
    id = "xDest",
    label = "Dest %:",
    min = 0,
    max = 100,
    value = defaults.xDest
}

dlg:slider {
    id = "yDest",
    min = 0,
    max = 100,
    value = defaults.yDest
}

dlg:newrow { always = false }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tweenOps",
    label = "Tween:",
    option = defaults.tweenOps,
    options = GradientUtilities.TWEEN_PRESETS,
    onchange = function()
        local isPair = dlg.data.tweenOps == "PAIR"
        local isPalette = dlg.data.tweenOps == "PALETTE"
        local md = dlg.data.clrSpacePreset

        dlg:modify {
            id = "aColor",
            visible = isPair
        }

        dlg:modify {
            id = "bColor",
            visible = isPair
        }

        dlg:modify {
            id = "startIndex",
            visible = isPalette
        }

        dlg:modify {
            id = "count",
            visible = isPalette
        }

        dlg:modify {
            id = "easingFuncHue",
            visible = md == "CIE_LCH"
                or md == "HSL"
                or md == "HSV"
        }

        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB"
                or md == "LINEAR_RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:slider{
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:slider{
    id = "count",
    label = "Count:",
    min = 3,
    max = 256,
    value = defaults.count,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor,
    visible = defaults.tweenOps == "PAIR"
}

dlg:color {
    id = "bColor",
    color = defaults.bColor,
    visible = defaults.tweenOps == "PAIR"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = GradientUtilities.CLR_SPC_PRESETS,
    visible = defaults.tweenOps == "PAIR",
    onchange = function()
        local md = dlg.data.clrSpacePreset
        dlg:modify {
            id = "easingFuncHue",
            visible = md == "CIE_LCH"
                or md == "HSL"
                or md == "HSV"
        }
        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB"
                or md == "LINEAR_RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingFuncHue",
    label = "Easing:",
    option = defaults.easingFuncHue,
    options = GradientUtilities.HUE_EASING_PRESETS,
    visible = defaults.clrSpacePreset == "CIE_LCH"
        or defaults.clrSpacePreset == "HSL"
        or defaults.clrSpacePreset == "HSV"
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "Easing:",
    option = defaults.easingFuncRGB,
    options = GradientUtilities.RGB_EASING_PRESETS,
    visible = defaults.clrSpacePreset == "S_RGB"
        or defaults.clrSpacePreset == "LINEAR_RGB"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        local clrSpacePreset = args.clrSpacePreset
        local sprite = AseUtilities.initCanvas(
            64, 64, "Gradient.Linear")
        if sprite.colorMode == ColorMode.RGB then
            local layer = sprite.layers[#sprite.layers]
            local frame = app.activeFrame or 1
            local cel = sprite:newCel(layer, frame)

            --Easing mode.
            local tweenOps = args.tweenOps
            local rgbPreset = args.easingFuncRGB
            local huePreset = args.easingFuncHue

            local easeFuncFinal = nil
            if tweenOps == "PALETTE" then

                local startIndex = args.startIndex
                local count = args.count
                local pal = sprite.palettes[1]
                local clrArr = AseUtilities.paletteToClrArr(
                    pal, startIndex, count)

                local pairFunc = GradientUtilities.clrSpcFuncFromPreset(
                    clrSpacePreset,
                    rgbPreset,
                    huePreset)

                easeFuncFinal = function(t)
                    return Clr.mixArr(clrArr, t, pairFunc)
                end
            else
                local aColorAse = args.aColor
                local bColorAse = args.bColor

                local aClr = AseUtilities.aseColorToClr(aColorAse)
                local bClr = AseUtilities.aseColorToClr(bColorAse)

                local pairFunc = GradientUtilities.clrSpcFuncFromPreset(
                    clrSpacePreset,
                    rgbPreset,
                    huePreset)

                easeFuncFinal = function(t)
                    return pairFunc(aClr, bClr, t)
                end
            end

            local w = sprite.width
            local h = sprite.height

            local xOrigin = 0.01 * args.xOrigin
            local yOrigin = 0.01 * args.yOrigin
            local xDest = 0.01 * args.xDest
            local yDest = 0.01 * args.yDest

            local xOrPx = xOrigin * w
            local yOrPx = yOrigin * h
            local xDsPx = xDest * w
            local yDsPx = yDest * h

            local bx = xOrPx - xDsPx
            local by = yOrPx - yDsPx
            local bbInv = 1.0 / math.max(0.000001,
                bx * bx + by * by)

            local levels = args.quantization

            local img = cel.image
            local iterator = img:pixels()
            local i = 0
            for elm in iterator do
                local xPx = i % w
                local yPx = i // w

                local cx = xOrPx - xPx
                local cy = yOrPx - yPx

                local cb = (cx * bx + cy * by) * bbInv

                -- Unsigned quantize will already clamp to
                -- 0.0 minimum.
                local fac = Utilities.quantizeUnsigned(
                    cb, levels)
                fac = math.min(1.0, fac)

                elm(Clr.toHex(easeFuncFinal(fac)))
                i = i + 1
            end

            app.refresh()
        else
            app.alert("Only RGB color mode is supported.")
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