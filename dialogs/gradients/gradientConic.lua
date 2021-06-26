dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    angle = 90,
    cw = false,
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
    label = "Chirality:",
    text = "Flip y axis.",
    selected = defaults.cw
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
            64, 64, "Gradient.Conic")
        if sprite.colorMode == ColorMode.RGB then

            local atan2 = math.atan

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

            local aspect = w / h
            local wInv = aspect / w
            local hInv = 1.0 / h

            -- Shift origin from [0, 100] to [0.0, 1.0].
            local xOrigin = 0.01 * args.xOrigin
            local yOrigin = 0.01 * args.yOrigin
            local xOriginNorm = xOrigin * aspect
            local yOriginNorm = yOrigin

            -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
            local xOriginSigned = xOriginNorm + xOriginNorm - 1.0
            local yOriginSigned = 1.0 - (yOriginNorm + yOriginNorm)

            local angRadians = math.rad(args.angle)
            local cw = 1.0
            if args.cw then cw = -1.0 end
            local levels = args.quantization

            local img = cel.image
            local iterator = img:pixels()
            for elm in iterator do

                -- Bring coordinates into range [0.0, 1.0].
                local xNorm = elm.x * wInv
                local yNorm = elm.y * hInv

                -- Bring coordinates from [0.0, 1.0] to [-1.0, 1.0].
                local xSigned = xNorm + xNorm - 1.0
                local ySigned = 1.0 - (yNorm + yNorm)

                -- Subtract the origin.
                local xOffset = xSigned - xOriginSigned
                local yOffset = cw * (ySigned - yOriginSigned)

                -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
                local angleSigned = atan2(yOffset, xOffset) - angRadians

                -- Bring angle into range [-0.5, 0.5]. Divide by 2 * math.pi.
                local angleNormed = angleSigned * 0.15915494309189535

                -- Bring angle into range [0.0, 1.0] by subtracting floor.
                -- Alternatively, use angleNormed % 1.0.
                local fac = angleNormed % 1.0

                fac = Utilities.quantizeUnsigned(fac, levels)

                elm(Clr.toHex(easeFuncFinal(fac)))
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