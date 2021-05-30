dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local defaults = {
    quantization = 0,
    normalize = false,
    tweenOps = "PAIR",
    aColor = Color(0, 0, 0, 255),
    bColor = Color(255, 255, 255, 255),
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local dlg = Dialog { title = "Gradient Map" }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization
}

dlg:newrow { always = false }

dlg:check {
    id = "useNormalize",
    label = "Normalize:",
    text = "Stretch Contrast",
    selected = defaults.normalize
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tweenOps",
    label = "Tween:",
    option = defaults.tweenOps,
    options = GradientUtilities.TWEEN_PRESETS,
    onchange = function()
        local isPair = dlg.data.tweenOps == "PAIR"
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
            id = "easingFuncHue",
            visible = md == "HSL" or md == "HSV"
        }

        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB" or md == "LINEAR_RGB"
        }
    end
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
            visible = md == "HSL" or md == "HSV"
        }
        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB" or md == "LINEAR_RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingFuncHue",
    label = "Easing:",
    option = defaults.easingFuncHue,
    options = GradientUtilities.HUE_EASING_PRESETS,
    visible = defaults.clrSpacePreset == "HSL"
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
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                if sprite.colorMode == ColorMode.RGB then
                    local srcCel = app.activeCel
                    if srcCel then
                        local srcImg = app.activeImage
                        if srcImg then

                            --Easing mode.
                            local tweenOps = args.tweenOps
                            local rgbPreset = args.easingFuncRGB
                            local huePreset = args.easingFuncHue
                            local clrSpacePreset = args.clrSpacePreset

                            local easeFuncFinal = nil
                            if tweenOps == "PALETTE" then

                                local pal = sprite.palettes[1]
                                local clrArr = AseUtilities.paletteToClrArr(pal)

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

                            -- Find alpha from source image.
                            local minLum = 1.0
                            local maxLum = 0.0
                            local lums = {}
                            local alphasSrc = {}

                            local i = 1
                            local srcItr = srcImg:pixels()
                            for srcClr in srcItr do
                                local hex = srcClr()

                                -- local b = (hex >> 0x10 & 0xff) * 0.00392156862745098
                                -- local g = (hex >> 0x08 & 0xff) * 0.00392156862745098
                                -- local r = (hex         & 0xff) * 0.00392156862745098

                                -- local lum = r * 0.21264934272065283
                                --           + g * 0.7151691357059038
                                --           + b * 0.07218152157344333

                                -- local lum = 10E-12 *
                                --      ((hex         & 0xff) *  83391899.0
                                --     + (hex >> 0x08 & 0xff) * 280458484.0
                                --     + (hex >> 0x10 & 0xff) *  28306479.0)

                                local lum = Clr.lumStandard(Clr.fromHex(hex))
                                if lum <= 0.0031308 then
                                    lum = lum * 12.92
                                else
                                    lum = (lum ^ 0.4166666666666667) * 1.055 - 0.055
                                end

                                if lum < minLum then minLum = lum end
                                if lum > maxLum then maxLum = lum end
                                lums[i] = lum
                                alphasSrc[i] = hex >> 0x18 & 0xff
                                i = i + 1
                            end

                            -- Create target layer, cel, image.
                            local trgLyr = sprite:newLayer()
                            trgLyr.name = "Gradient Map"
                            local trgCel = sprite:newCel(trgLyr, srcCel.frame)
                            trgCel.position = srcCel.position
                            trgCel.image = srcImg:clone()
                            local trgImg = trgCel.image

                            -- Normalize range if requested.
                            local useNormalize = args.useNormalize
                            local rangeLum = maxLum - minLum
                            if useNormalize and rangeLum ~= 0 then
                                local invRangeLum = 1.0 / rangeLum
                                for j = 1, #lums, 1 do
                                    lums[j] = (lums[j] - minLum) * invRangeLum
                                end
                            end

                            -- Assign color from gradient function.
                            i = 1
                            local levels = args.quantization
                            local trgItr = trgImg:pixels()
                            for trgClr in trgItr do
                                local lum = lums[i]
                                lum = Utilities.quantizeUnsigned(lum, levels)
                                local grayClr = Clr.toHex(easeFuncFinal(lum))

                                -- Take the minimum of source and target alpha.
                                local aTrg = (grayClr >> 0x18 & 0xff)
                                local hex = math.min(alphasSrc[i], aTrg) << 0x18
                                    | (0x00ffffff & grayClr)
                                trgClr(hex)
                                i = i + 1
                            end

                            -- TODO: Might be causing a problem in 1.3 beta?
                            -- app.activeLayer = srcLyr
                            -- app.activeCel = srcCel

                            app.refresh()
                        else
                            app.alert("There is no active image.")
                        end
                    else
                        app.alert("There is no active cel.")
                    end
                else
                    app.alert("Only RGB color mode is supported.")
                end
            else
                app.alert("There is no active sprite.")
            end
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