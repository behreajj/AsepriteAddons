dofile("../support/aseutilities.lua")

local easingModes = { "RGB", "HSL" , "HSV" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hsvEasing = { "NEAR", "FAR" }
local metrics = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI" }

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    -- minRad = 0,
    maxRad = 100,
    distMetric = "EUCLIDEAN",
    minkExp = 2.0,
    quantization = 0,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR"
}


local function createRadial(
    sprite,
    img,
    xOrigin, yOrigin,
    -- minRad,
    maxRad,
    distFunc,
    quantLvl,
    aColor, bColor,
    easingMode, easingFunc)

    local w = sprite.width
    local h = sprite.height

    local useQuantize = quantLvl > 0.0
    local delta = 1.0
    local levels = 1.0
    local wInv = 1.0
    local hInv = 1.0
    if useQuantize then
        levels = quantLvl
        delta = 1.0 / levels
        wInv = 1.0 / w
        hInv = 1.0 / h
    end

    local a0 = 0
    local a1 = 0
    local a2 = 0
    local a3 = 0

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 0

    local easing = AseUtilities.lerpRgba

    local xOrigPx = xOrigin * w
    local yOrigPx = yOrigin * h

    -- TODO: Test is maxRad in the numerator or denom?
    local normDist = 2.0 / (maxRad * distFunc(0.0, 0.0, w, h))

    if easingMode and easingMode == "HSV" then

        a0 = aColor.hsvHue
        a1 = aColor.hsvSaturation
        a2 = aColor.hsvValue
        a3 = aColor.alpha

        b0 = bColor.hsvHue
        b1 = bColor.hsvSaturation
        b2 = bColor.hsvValue
        b3 = bColor.alpha

        if easingFunc and easingFunc == "FAR" then
            easing = AseUtilities.lerpHsvaFar
        else
            easing = AseUtilities.lerpHsvaNear
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

        if easingFunc and easingFunc == "FAR" then
            easing = AseUtilities.lerpHslaFar
        else
            easing = AseUtilities.lerpHslaNear
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

        if easingFunc and easingFunc == "SMOOTH" then
            easing = AseUtilities.smoothRgba
        end

    end

    local iterator = img:pixels()
    local i = 0

    for elm in iterator do
        local xPx = i % w
        local yPx = i // w

        if useQuantize then
            xPx = xPx * wInv
            yPx = yPx * hInv

            xPx = delta * math.floor(0.5 + xPx * levels)
            yPx = delta * math.floor(0.5 + yPx * levels)

            xPx = xPx * w
            yPx = yPx * h
        end

        local dst = distFunc(xPx, yPx, xOrigPx, yOrigPx)
        local fac = dst * normDist
        fac = math.min(1.0, math.max(0.0, fac))
        elm(easing(
            a0, a1, a2, a3,
            b0, b1, b2, b3,
            fac))

        i = i + 1
    end

end

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

local function minkDist(ax, ay, bx, by, c)
    return (math.abs(bx - ax) ^ c
          + math.abs(by - ay) ^ c)
          ^ (1.0 / c)
end

local dlg = Dialog { title = "Radial Gradient" }

dlg:slider {
    id = "xOrigin",
    label = "Origin X:",
    min = 0,
    max = 100,
    value = defaults.xOrigin
}

dlg:slider {
    id = "yOrigin",
    label = "Origin Y:",
    min = 0,
    max = 100,
    value = defaults.yOrigin
}

-- https://github.com/aseprite/aseprite/issues/2613
-- dlg:slider {
--     id = "minRad",
--     label = "Min Radius:",
--     min = 0,
--     max = 99,
--     value = defaults.minRad
-- }

dlg:slider {
    id = "maxRad",
    label = "Max Radius:",
    min = 1,
    max = 100,
    value = defaults.maxRad
}

dlg:combobox {
    id = "distMetric",
    label = "Metric:",
    option = defaults.distMetric,
    options = metrics
}

dlg:number {
    id = "minkExp",
    label = "Minkowski Power:",
    text = string.format("%.1f", defaults.minkExp),
    decimals = 5
}

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization
}

dlg:color {
    id = "aColor",
    label = "Color A:",
    color = defaults.aColor
}

dlg:color {
    id = "bColor",
    label = "Color B:",
    color = defaults.bColor
}

dlg:combobox {
    id = "easingMode",
    label = "Easing Mode:",
    option = defaults.easingMode,
    options = easingModes
}

dlg:combobox {
    id = "easingFuncHue",
    label = "HSV Easing:",
    option = defaults.easingFuncHue,
    options = hsvEasing
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "RGB Easing:",
    option = defaults.easingFuncRGB,
    options = rgbEasing
}

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

            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local layer = sprite:newLayer()
            layer.name = "Conic Gradient"
            local cel = sprite:newCel(layer, 1)

            local distFunc = euclDist
            local distMetric = args.distMetric
            if distMetric == "CHEBYSHEV" then
                distFunc = chebDist
            elseif distMetric == "MANHATTAN" then
                distFunc = manhDist
            elseif distMetric == "MINKOWSKI" then
                local minkExp = 2.0
                if args.minkExp ~= 0.0 then
                    minkExp = args.minkExp
                end

                distFunc = function(ax, ay, bx, by)
                    return minkDist(ax, ay, bx, by, minkExp)
                end
            end

            createRadial(
                sprite,
                cel.image,
                0.01 * args.xOrigin,
                0.01 * args.yOrigin,
                -- 0.01 * args.minRad,
                0.01 * args.maxRad,
                distFunc,
                args.quantization,
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