dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    angle = 90,
    cw = false,
    isCyclic = false,
    quantization = 0,
    tweenOps = "PAIR",
    startIndex = 0,
    count = 256,
    aColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    bColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local dlg = Dialog { title = "Conic Gradient" }

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
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:newrow { always = false }

dlg:check {
    id = "cw",
    label = "Flip Y:",
    selected = defaults.cw
}

dlg:newrow { always = false }

dlg:check {
    id = "isCyclic",
    label = "Cyclic:",
    selected = defaults.isCyclic
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
        local args = dlg.data

        -- These need to be cached prior to the potential
        -- creation of a new sprite, otherwise color chosen
        -- by palette index will be incorrect.
        local aColorAse = args.aColor or defaults.aColor
        local bColorAse = args.bColor or defaults.bColor
        local aClr = AseUtilities.aseColorToClr(aColorAse)
        local bClr = AseUtilities.aseColorToClr(bColorAse)

        local clrSpacePreset = args.clrSpacePreset or defaults.clrSpacePreset
        local sprite = AseUtilities.initCanvas(
            64, 64, "Gradient.Conic." .. clrSpacePreset)

        -- TODO: Refactor to use early return.
        if sprite.colorMode == ColorMode.RGB then

            -- Cache methods.
            local atan2 = math.atan
            local max = math.max
            local min = math.min
            local toHex = Clr.toHex
            local isCyclic = args.isCyclic

            local wrap = 0.0
            local toFac = 0.0
            local quantize = nil
            if isCyclic then
                quantize = Utilities.quantizeSigned
                wrap = 6.2831853071796
                toFac = 0.1591549430919
            else
                quantize = Utilities.quantizeUnsigned
                -- 361 degrees * 180 degrees / pi radians
                -- wrap = 6.300638599699529
                -- toFac = 0.15871407067335824
                wrap = 6.2831853071796
                toFac = 0.1591549430919
            end

            local layer = sprite.layers[#sprite.layers]
            local frame = app.activeFrame or sprite.frames[1]

            -- Easing mode.
            local tweenOps = args.tweenOps or defaults.tweenOps
            local rgbPreset = args.easingFuncRGB or defaults.easingFuncRGB
            local huePreset = args.easingFuncHue or defaults.easingFuncHue

            local easeFuncFinal = nil
            if tweenOps == "PALETTE" then

                local startIndex = args.startIndex or defaults.startIndex
                local count = args.count or defaults.count

                local palettes = sprite.palettes
                local lenPalettes = #palettes
                local actFrIdx = 1
                if app.activeFrame then
                    actFrIdx = app.activeFrame.frameNumber
                    if actFrIdx > lenPalettes then actFrIdx = 1 end
                end
                local pal = palettes[actFrIdx]

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
                local pairFunc = GradientUtilities.clrSpcFuncFromPreset(
                    clrSpacePreset,
                    rgbPreset,
                    huePreset)

                easeFuncFinal = function(t)
                    return pairFunc(aClr, bClr, t)
                end
            end

            local wn1 = max(1.0, sprite.width - 1.0)
            local hn1 = max(1.0, sprite.height - 1.0)

            local aspect = wn1 / hn1
            local wInv = aspect / wn1
            local hInv = 1.0 / hn1

            -- Shift origin from [0, 100] to [0.0, 1.0].
            local xOrigin = 0.01 * args.xOrigin
            local yOrigin = 0.01 * args.yOrigin
            local xOriginNorm = xOrigin * aspect
            local yOriginNorm = yOrigin

            -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
            local xOriginSigned = xOriginNorm + xOriginNorm - 1.0
            local yOriginSigned = 1.0 - (yOriginNorm + yOriginNorm)

            local angDegrees = args.angle or defaults.angle
            local angRadians = angDegrees * 0.017453292519943
            local cw = 1.0
            if args.cw then cw = -1.0 end
            local levels = args.quantization or defaults.quantization

            local selection = AseUtilities.getSelection(sprite)
            local selBounds = selection.bounds
            local xCel = selBounds.x
            local yCel = selBounds.y
            local image = Image(selBounds.width, selBounds.height)
            local iterator = image:pixels()
            for elm in iterator do
                local x = elm.x + xCel
                local y = elm.y + yCel
                -- if selection:contains(x, y) then

                -- Bring coordinates into range [0.0, 1.0].
                local xNorm = x * wInv
                local yNorm = y * hInv

                -- Bring coordinates from [0.0, 1.0] to [-1.0, 1.0].
                local xSigned = xNorm + xNorm - 1.0
                local ySigned = 1.0 - (yNorm + yNorm)

                -- Subtract the origin.
                local xOffset = xSigned - xOriginSigned
                local yOffset = cw * (ySigned - yOriginSigned)

                -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
                local angleSigned = atan2(yOffset, xOffset) - angRadians

                -- Depending on whether this is cyclic or not,
                -- will need to wrap by 360 degrees or 361, so
                -- factor will be in [0.0, 1.0) vs [0.0, 1.0].
                local angleWrapped = angleSigned % wrap

                -- Divide by tau to bring into factor.
                -- local fac = min(1.0, angleWrapped * toFac)
                local fac = angleWrapped * toFac

                fac = quantize(fac, levels)
                elm(toHex(easeFuncFinal(fac)))
                -- end
            end

            sprite:newCel(layer, frame, image, Point(xCel, yCel))
            app.refresh()
        else
            app.alert("Only RGB color mode is supported.")
        end
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
