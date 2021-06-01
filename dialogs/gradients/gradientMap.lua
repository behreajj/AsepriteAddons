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

                            -- Cache source colors.
                            local srcClrDict = {}
                            local srcItr = srcImg:pixels()
                            for srcClr in srcItr do
                                local hex = srcClr()
                                srcClrDict[hex] = true
                            end

                            local srcAlphaDict = {}

                            local lumDict = {}
                            local minLum = 1.0
                            local maxLum = 0.0
                            local stlLut = Utilities.STL_LUT

                            -- Cache luminosities and source alphas in dictionaries.
                            for hex, _ in pairs(srcClrDict) do

                                local sbi = hex >> 0x18 & 0xff
                                local sgi = hex >> 0x08 & 0xff
                                local sri = hex & 0xff

                                local lbi = stlLut[1 + sbi]
                                local lgi = stlLut[1 + sgi]
                                local lri = stlLut[1 + sri]

                                -- local lum = Clr.lumStandard(Clr.fromHex(hex))
                                local lum = 0.0008339189910613837 * lri
                                    + 0.002804584845905505 * lgi
                                    + 0.0002830647904840915 * lbi

                                if lum <= 0.0031308 then
                                    lum = lum * 12.92
                                else
                                    lum = (lum ^ 0.4166666666666667) * 1.055 - 0.055
                                end

                                if lum < minLum then minLum = lum end
                                if lum > maxLum then maxLum = lum end

                                lumDict[hex] = lum

                                srcAlphaDict[hex] = hex >> 0x18 & 0xff
                            end

                            -- Normalize range if requested.
                            local useNormalize = args.useNormalize
                            local rangeLum = maxLum - minLum
                            local invRangeLum = 1.0 / rangeLum
                            if useNormalize and rangeLum ~= 0 then
                                for hex, lum in pairs(lumDict) do
                                    lumDict[hex] =  (lum - minLum) * invRangeLum
                                end
                            end

                            -- Create target colors.
                            local trgClrDict = {}
                            local levels = args.quantization

                            -- Micro-optimization (apparently lua likes locals).
                            local min = math.min
                            local qu = Utilities.quantizeUnsigned
                            local tohex = Clr.toHex

                            for hex, _ in pairs(srcClrDict) do
                                local lum = lumDict[hex]
                                lum = qu(lum, levels)
                                local grayClr = tohex(easeFuncFinal(lum))

                                local aSrc = srcAlphaDict[hex]
                                local aTrg = (grayClr >> 0x18 & 0xff)

                                trgClrDict[hex] = min(aSrc, aTrg) << 0x18
                                | (0x00ffffff & grayClr)
                            end

                            -- Create target layer, cel, image.
                            local trgLyr = sprite:newLayer()
                            trgLyr.name = "Gradient Map"
                            local trgCel = sprite:newCel(trgLyr, srcCel.frame)
                            trgCel.position = srcCel.position
                            trgCel.image = srcImg:clone()
                            local trgImg = trgCel.image

                            -- Assign color from gradient function.
                            local trgItr = trgImg:pixels()
                            for trgClr in trgItr do
                                trgClr(trgClrDict[trgClr()])
                            end

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