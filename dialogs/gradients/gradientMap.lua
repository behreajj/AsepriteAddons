dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    quantization = 0,
    normalize = false,
    tweenOps = "PAIR",
    startIndex = 0,
    count = 256,
    aColor = Color(0, 0, 0, 255),
    bColor = Color(255, 255, 255, 255),
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local dlg = Dialog { title = "Gradient Map" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
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

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:slider {
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
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local sprite = app.activeSprite
        if not sprite then
            app.alert("There is no active sprite.")
            return
        end

        if sprite.colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert("There is no active layer.")
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local levels = args.quantization or defaults.quantization
        local useNormalize = args.useNormalize
        local tweenOps = args.tweenOps or defaults.tweenOps
        local rgbPreset = args.easingFuncRGB or defaults.easingFuncRGB
        local huePreset = args.easingFuncHue or defaults.easingFuncHue
        local clrSpacePreset = args.clrSpacePreset or defaults.clrSpacePreset

        local easeFuncFinal = nil
        if tweenOps == "PALETTE" then

            local startIndex = args.startIndex
            local count = args.count
            local pal = sprite.palettes[1]
            local clrArr = AseUtilities.asePaletteToClrArr(
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

        -- Cache methods and tables used in loop.
        local stlLut = Utilities.STL_LUT
        local lRgbToXyz = Clr.lRgbaToXyzInternal
        local xyzToLab = Clr.xyzToLab
        local abs = math.abs
        local min = math.min
        local qu = Utilities.quantizeUnsigned
        local tohex = Clr.toHex

        -- Find frames from target.
        local frames = {}
        if target == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                frames[1] = activeFrame
            end
        elseif target == "RANGE" then
            local appRange = app.range
            local rangeFrames = appRange.frames
            local rangeFramesLen = #rangeFrames
            for i = 1, rangeFramesLen, 1 do
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = sprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.s
        local trgLyr = sprite:newLayer()
        if srcLayer.opacity then
            trgLyr.opacity = srcLayer.opacity
        end
        trgLyr.name = "Gradient.Map." .. clrSpacePreset
        if useNormalize then
            trgLyr.name = trgLyr.name .. ".Contrast"
        end

        local framesLen = #frames
        app.transaction(function()
            for i = 1, framesLen, 1 do
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image

                    -- Cache source colors.
                    local srcClrDict = {}
                    local srcItr = srcImg:pixels()
                    for srcClr in srcItr do
                        srcClrDict[srcClr()] = true
                    end

                    local srcAlphaDict = {}
                    local lumDict = {}
                    local minLum = 1.0
                    local maxLum = 0.0

                    -- Cache luminosities and source alphas in dictionaries.
                    for hex, _ in pairs(srcClrDict) do
                        local sai = hex >> 0x18 & 0xff
                        local lum = 0.0
                        if sai > 0 then
                            local sbi = hex >> 0x10 & 0xff
                            local sgi = hex >> 0x08 & 0xff
                            local sri = hex & 0xff

                            if sbi == sgi and sbi == sri and sri == sgi then
                                lum = sbi * 0.00392156862745098
                            else
                                -- Convert to linear via look up table.
                                local lbi = stlLut[1 + sbi]
                                local lgi = stlLut[1 + sgi]
                                local lri = stlLut[1 + sri]

                                local xyz = lRgbToXyz(
                                    lri * 0.00392156862745098,
                                    lgi * 0.00392156862745098,
                                    lbi * 0.00392156862745098,
                                    1.0)
                                local lab = xyzToLab(xyz.x, xyz.y, xyz.z, 1.0)

                                lum = lab.l * 0.01
                            end

                            if lum < minLum then minLum = lum end
                            if lum > maxLum then maxLum = lum end
                        end
                        lumDict[hex] = lum
                        srcAlphaDict[hex] = sai
                    end

                    -- Normalize range if requested.
                    -- A color disc with uniform perceptual luminance
                    -- generated by Okhsl has a range of about 0.069.
                    local rangeLum = abs(maxLum - minLum)
                    if useNormalize and rangeLum > 0.07 then
                        local invRangeLum = 1.0 / rangeLum
                        for hex, lum in pairs(lumDict) do
                            if (hex & 0xff000000) ~= 0 then
                                lumDict[hex] = (lum - minLum) * invRangeLum
                            else
                                lumDict[hex] = 0.0
                            end
                        end
                    end

                    local trgClrDict = {}
                    for hex, _ in pairs(srcClrDict) do
                        local lum = lumDict[hex]
                        lum = qu(lum, levels)
                        local grayClr = tohex(easeFuncFinal(lum))

                        local aSrc = srcAlphaDict[hex]
                        local aTrg = (grayClr >> 0x18 & 0xff)

                        trgClrDict[hex] = min(aSrc, aTrg) << 0x18
                            | (0x00ffffff & grayClr)
                    end

                    -- Create cel.
                    local trgCel = sprite:newCel(trgLyr, srcCel.frame)
                    trgCel.position = srcCel.position
                    trgCel.image = srcImg:clone()
                    trgCel.opacity = srcCel.opacity

                    -- Assign color from gradient function.
                    local trgImg = trgCel.image
                    local trgItr = trgImg:pixels()
                    for trgClr in trgItr do
                        trgClr(trgClrDict[trgClr()])
                    end
                end
            end
        end)

        app.refresh()
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