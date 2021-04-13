dofile("../support/aseutilities.lua")

local easingModes = { "HSL" , "HSV", "PALETTE", "RGB" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hsvEasing = { "FAR", "NEAR" }
local metrics = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI"
}

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    maxRad = 100,
    distMetric = "EUCLIDEAN",
    minkExp = 2.0,
    quantization = 0,
    bias = 1.0,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR"
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

local function createRadial(
    sprite,
    img,
    xOrigin, yOrigin,
    maxRad,
    distFunc,
    quantLvl,
    bias,
    aColor, bColor,
    easingMode, easingPreset)

    local w = sprite.width
    local h = sprite.height

    local useQuantize = quantLvl > 0.0
    local delta = 1.0
    local levels = 1.0
    if useQuantize then
        levels = quantLvl
        delta = 1.0 / levels
    end

    local xOrigPx = xOrigin * w
    local yOrigPx = yOrigin * h

    -- Corners look bad with Chebyshev and Manhattan?
    local normDist = 2.0 / (maxRad * distFunc(0.0, 0.0, w, h))

    -- See https://github.com/aseprite/aseprite/issues/2613
    local valBias = 1.0
    if bias and bias ~= 0.0 then
        valBias = bias
    end

    local a0 = 0
    local a1 = 0
    local a2 = 0
    local a3 = 0

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 0

    local easing = function(t) return 0xffffffff end
    if easingMode and easingMode == "HSV" then

        a0 = aColor.hsvHue
        a1 = aColor.hsvSaturation
        a2 = aColor.hsvValue
        a3 = aColor.alpha

        b0 = bColor.hsvHue
        b1 = bColor.hsvSaturation
        b2 = bColor.hsvValue
        b3 = bColor.alpha

        if easingPreset and easingPreset == "FAR" then
            easing = function(t)
                return AseUtilities.lerpHsvaFar(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        else
            easing = function(t)
                return AseUtilities.lerpHsvaNear(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        end

    elseif easingMode == "HSL" then

        a0 = aColor.hslHue
        a1 = aColor.hslSaturation
        a2 = aColor.hslLightness
        a3 = aColor.alpha

        b0 = bColor.hslHue
        b1 = bColor.hslSaturation
        b2 = bColor.hslLightness
        b3 = bColor.alpha

        if easingPreset and easingPreset == "FAR" then
            easing = function(t)
                return AseUtilities.lerpHslaFar(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        else
            easing = function(t)
                return AseUtilities.lerpHslaNear(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        end

    elseif easingMode == "PALETTE" then

        local clrs = AseUtilities.paletteToColorArr(
            sprite.palettes[1])
        easing = function(t)
            return AseUtilities.lerpColorArr(
                clrs, t)
        end

    else

        a0 = aColor.red
        a1 = aColor.green
        a2 = aColor.blue
        a3 = aColor.alpha

        b0 = bColor.red
        b1 = bColor.green
        b2 = bColor.blue
        b3 = bColor.alpha

        if easingPreset and easingPreset == "SMOOTH" then
            easing = function(t)
                return AseUtilities.smoothRgba(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        else
            easing = function(t)
                return AseUtilities.lerpRgba(
                    a0, a1, a2, a3,
                    b0, b1, b2, b3, t)
            end
        end

    end

    local iterator = img:pixels()
    local i = 0

    for elm in iterator do
        local xPx = i % w
        local yPx = i // w

        local dst = distFunc(xPx, yPx, xOrigPx, yOrigPx)
        local fac = dst * normDist

        fac = math.min(1.0, math.max(0.0, fac))
        fac = fac ^ valBias

        if useQuantize then
            fac = delta * math.floor(0.5 + fac * levels)
        end

        elm(easing(fac))

        i = i + 1
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
    id = "maxRad",
    label = "Max Radius:",
    min = 1,
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
    decimals = 5,
    visible = false
}

dlg:newrow { always = false }

dlg:number {
    id = "bias",
    label = "Bias:",
    text = string.format("%.1f", defaults.bias),
    decimals = 5
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
    id = "easingMode",
    label = "Easing Mode:",
    option = defaults.easingMode,
    options = easingModes,
    onchange = function()
        local md = dlg.data.easingMode
        local showColors = md ~= "PALETTE"
        dlg:modify {
            id = "aColor",
            visible = showColors
        }
        dlg:modify {
            id = "bColor",
            visible = showColors
        }
        dlg:modify {
            id = "easingFuncHue",
            visible = md == "HSL" or md == "HSV"
        }
        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingFuncHue",
    label = "Easing:",
    option = defaults.easingFuncHue,
    options = hsvEasing,
    visible = false
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "Easing:",
    option = defaults.easingFuncRGB,
    options = rgbEasing
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor
}

dlg:color {
    id = "bColor",
    color = defaults.bColor
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local easingFunc = args.easingFuncRGB
            if args.easingMode == "HSV" then
                easingFunc = args.easingFuncHue
            elseif args.easingMode == "HSL" then
                easingFunc = args.easingFuncHue
            end

            local sprite = AseUtilities.initCanvas(
                64, 64, "Radial Gradient")
            local layer = sprite.layers[#sprite.layers]
            local cel = sprite:newCel(layer, 1)

            local distFunc = euclDist
            local distMetric = args.distMetric
            if distMetric == "CHEBYSHEV" then
                distFunc = chebDist
            elseif distMetric == "MANHATTAN" then
                distFunc = manhDist
            elseif distMetric == "MINKOWSKI" then
                local minkExp = 2.0
                local invMinkExp = 0.5
                if args.minkExp ~= 0.0 then
                    minkExp = args.minkExp
                    invMinkExp = 1.0 / minkExp
                end

                distFunc = function(ax, ay, bx, by)
                    return minkDist(ax, ay, bx, by,
                        minkExp, invMinkExp)
                end
            end

            createRadial(
                sprite,
                cel.image,
                0.01 * args.xOrigin,
                0.01 * args.yOrigin,
                0.01 * args.maxRad,
                distFunc,
                args.quantization,
                args.bias,
                args.aColor,
                args.bColor,
                args.easingMode,
                easingFunc)

            app.refresh()
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