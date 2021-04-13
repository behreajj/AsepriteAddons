dofile("../support/aseutilities.lua")

local easingModes = { "HSL", "HSV", "PALETTE", "RGB" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hueEasing = { "FAR", "NEAR" }

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    angle = 90,
    cw = false,
    quantization = 0,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR"
}

local function createConic(
    sprite, img,
    xOrigin, yOrigin,
    angle, cw,
    quantLvl,
    aColor, bColor,
    easingMode, easingPreset)

    local w = sprite.width
    local h = sprite.height

    local shortEdge = math.min(w, h)
    local longEdge = math.max(w, h)

    -- Compensate for image aspect ratio.
    local wInv = 1.0
    local hInv = 1.0 / h
    local xOriginNorm = xOrigin or 0.0
    local yOriginNorm = yOrigin or 0.0

    local useQuantize = quantLvl > 0.0
    local delta = 1.0
    local levels = 1.0
    if useQuantize then
        levels = quantLvl
        delta = 1.0 / levels
    end

    if shortEdge == longEdge then
        wInv = 1.0 / w
    elseif w == shortEdge then
        local aspect = (shortEdge / longEdge)
        wInv = aspect / w
        xOriginNorm = xOriginNorm * aspect
    elseif h == shortEdge then
        local aspect = (longEdge / shortEdge)
        wInv = aspect / w
        xOriginNorm = xOriginNorm * aspect
    end

    -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
    local xOriginSigned = xOriginNorm + xOriginNorm - 1.0
    local yOriginSigned = 1.0 - (yOriginNorm + yOriginNorm)

    -- Validate angle.
    local ang = 0.0
    if angle then ang = angle % 6.283185307179586 end

    -- Choose channels and easing based on color mode.
    local a0 = 0
    local a1 = 0
    local a2 = 0
    local a3 = 255

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 255

    local easing = function(t) return 0xffffffff end
    if easingMode == "HSV" then

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

    -- Get image iterator.
    local iterator = img:pixels()
    local i = 0

    for elm in iterator do

        -- Convert from array index to Cartesian coordinates.
        local xPoint = i % w
        local yPoint = i // w

        -- Bring coordinates into range [0.0, 1.0].
        local xNorm = xPoint * wInv
        local yNorm = yPoint * hInv

        -- Bring coordinates from [0.0, 1.0] to [-1.0, 1.0].
        local xSigned = xNorm + xNorm - 1.0
        local ySigned = 1.0 - (yNorm + yNorm)

        -- Subtract the origin.
        local xOffset = xSigned - xOriginSigned
        local yOffset = ySigned - yOriginSigned
        if cw then yOffset = -yOffset end

        -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
        local angleSigned = math.atan(yOffset, xOffset) - ang

        -- Bring angle into range [-0.5, 0.5]. Divide by 2 * math.pi.
        local angleNormed = angleSigned * 0.15915494309189535

        -- Bring angle into range [0.0, 1.0] by subtracting floor.
        -- Alternatively, use angleNormed % 1.0.
        local fac = angleNormed - math.floor(angleNormed)

        if useQuantize then
            fac = delta * math.floor(0.5 + fac * levels)
        end

        -- Set element to integer composite.
        elm(easing(fac))

        i = i + 1
    end
end

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
    options = hueEasing,
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
                64, 64, "Conic Gradient")
            local layer = sprite.layers[#sprite.layers]
            local cel = sprite:newCel(layer, 1)

            -- TODO: Option to animate?
            createConic(
                sprite,
                cel.image,
                0.01 * args.xOrigin,
                0.01 * args.yOrigin,
                math.rad(args.angle),
                args.cw,
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