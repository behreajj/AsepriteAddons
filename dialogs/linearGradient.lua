dofile("../support/aseutilities.lua")

local easingModes = { "RGB", "HSL", "HSV" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hueEasing = { "NEAR", "FAR" }

local defaults = {
    xOrigin = 0,
    yOrigin = 50,
    xDest = 100,
    yDest = 50,
    quantization = 0,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR"
}

local dlg = Dialog { title = "Linear Gradient" }

dlg:slider {
    id = "xOrigin",
    label = "Origin X %:",
    min = 0,
    max = 100,
    value = defaults.xOrigin
}

dlg:slider {
    id = "yOrigin",
    label = "Origin Y %:",
    min = 0,
    max = 100,
    value = defaults.yOrigin
}

dlg:slider {
    id = "xDest",
    label = "Dest X %:",
    min = 0,
    max = 100,
    value = defaults.xDest
}

dlg:slider {
    id = "yDest",
    label = "Dest Y %:",
    min = 0,
    max = 100,
    value = defaults.yDest
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
    label = "Hue Easing:",
    option = defaults.easingFuncHue,
    options = hueEasing
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "RGB Easing:",
    option = defaults.easingFuncRGB,
    options = rgbEasing
}

local function createLinear(
    sprite, img,
    xOrigin, yOrigin,
    xDest, yDest,
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

    local xOrPx = xOrigin * w
    local yOrPx = yOrigin * h

    local xDsPx = xDest * w
    local yDsPx = yDest * h

    local bx = xOrPx - xDsPx
    local by = yOrPx - yDsPx
    local bbInv = 1.0 / math.max(0.000001,
        bx * bx + by * by)

    -- Choose channels and easing based on color mode.
    local a0 = 0
    local a1 = 0
    local a2 = 0
    local a3 = 255

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 255

    local easing = AseUtilities.lerpRgba

    if easingMode == "HSV" then

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

    -- Get image iterator.
    local iterator = img:pixels()
    local i = 0

    for elm in iterator do
        local xPx = i % w
        local yPx = i // w

        if useQuantize then
            xPx = xPx * wInv
            yPx = yPx * hInv

            xPx = delta * math.floor(xPx * levels)
            yPx = delta * math.floor(yPx * levels)

            xPx = xPx * w
            yPx = yPx * h
        end

        local cx = xOrPx - xPx
        local cy = yOrPx - yPx

        -- dot(c, b) / dot(b, b)
        local cb = (cx * bx + cy * by) * bbInv
        local fac = math.max(0.0, math.min(1.0, cb))

        elm(easing(
            a0, a1, a2, a3,
            b0, b1, b2, b3,
            fac))

        i = i + 1
    end
end

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
                256, 32, "Linear Gradient")
            local layer = sprite.layers[#sprite.layers]
            local cel = sprite:newCel(layer, 1)

            createLinear(
                sprite,
                cel.image,
                0.01 * args.xOrigin,
                0.01 * args.yOrigin,
                0.01 * args.xDest,
                0.01 * args.yDest,
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