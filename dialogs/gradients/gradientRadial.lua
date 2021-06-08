dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local metrics = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI"
}

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    minRad = 0,
    maxRad = 100,
    distMetric = "EUCLIDEAN",
    minkExp = 2.0,
    quantization = 0,
    tweenOps = "PAIR",
    aColor = AseUtilities.DEFAULT_STROKE,
    bColor = AseUtilities.DEFAULT_FILL,
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local function chebDist(ax, ay, bx, by)
    return math.max(
        math.abs(bx - ax),
        math.abs(by - ay))
end

local function euclDist(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function manhDist(ax, ay, bx, by)
    return math.abs(bx - ax)
         + math.abs(by - ay)
end

local function minkDist(ax, ay, bx, by, c, d)
    return (math.abs(bx - ax) ^ c
          + math.abs(by - ay) ^ c)
          ^ d
end

local function distFuncFromPreset(distMetric, me)
    if distMetric == "CHEBYSHEV" then
        return chebDist
    elseif distMetric == "MANHATTAN" then
        return manhDist
    elseif distMetric == "MINKOWSKI" then
        local minkExp = 2.0
        local invMinkExp = 0.5

        if me ~= 0.0 then
            minkExp = me
            invMinkExp = 1.0 / minkExp
        end

        return function(ax, ay, bx, by)
            return minkDist(ax, ay, bx, by,
                minkExp, invMinkExp)
        end
    else
        return euclDist
    end
end

local dlg = Dialog { title = "Radial Gradient" }

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
    id = "minRad",
    label = "Radii %:",
    min = 0,
    max = 100,
    value = defaults.minRad
}

dlg:slider {
    id = "maxRad",
    min = 0,
    max = 100,
    value = defaults.maxRad
}

dlg:newrow { always = false }

dlg:combobox {
    id = "distMetric",
    label = "Metric:",
    option = defaults.distMetric,
    options = metrics,
    onchange = function()
        dlg:modify {
            id = "minkExp",
            visible = dlg.data.distMetric == "MINKOWSKI"
        }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "minkExp",
    label = "Exponent:",
    text = string.format("%.1f", defaults.minkExp),
    decimals = 6,
    visible = false
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
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = AseUtilities.initCanvas(
                64, 64, "Radial Gradient")
            if sprite.colorMode == ColorMode.RGB then

                local layer = sprite.layers[#sprite.layers]
                local frame = app.activeFrame or 1
                local cel = sprite:newCel(layer, frame)

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

                -- Choose distance metric based on preset.
                local distMetric = args.distMetric
                local minkExp = args.minkExp
                local distFunc = distFuncFromPreset(distMetric, minkExp)

                -- Validate minimum and maximum radii.
                local minRad = 0.01 * math.min(
                    args.minRad, args.maxRad)
                local maxRad = 0.01 * math.max(
                    args.minRad, args.maxRad)

                -- If radii are approximately equal, offset.
                if math.abs(maxRad - minRad) <= 0.000001 then
                    minRad = minRad - 0.01
                    maxRad = maxRad + 0.01
                end

                local diffRad = maxRad - minRad
                local linDenom = 1.0 / diffRad

                -- local wrapPreset = args.extension
                -- local wrapFunc = wrapFuncFromPreset(wrapPreset, minRad, maxRad)
                local levels = args.quantization

                -- Shift origin from [0, 100] to [0.0, 1.0].
                local xOrigin = 0.01 * args.xOrigin
                local yOrigin = 0.01 * args.yOrigin

                local w = sprite.width
                local h = sprite.height

                -- Convert from normalized to pixel size.
                local xOrigPx = xOrigin * w
                local yOrigPx = yOrigin * h

                -- Need a scalar to normalize distance to [0.0, 1.0]
                local normDist = 2.0 / (maxRad * distFunc(0.0, 0.0, w, h))

                local img = cel.image
                local iterator = img:pixels()
                local i = 0
                for elm in iterator do
                    local xPx = i % w
                    local yPx = i // w

                    local dst = distFunc(xPx, yPx, xOrigPx, yOrigPx)
                    local fac = dst * normDist
                    fac = math.max(0.0, math.min(1.0, fac))
                    fac = (fac - minRad) * linDenom
                    fac = Utilities.quantizeSigned(fac, levels)

                    elm(Clr.toHex(easeFuncFinal(fac)))
                    i = i + 1
                end

                app.refresh()
            else
                app.alert("Only RGB color mode is supported.")
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