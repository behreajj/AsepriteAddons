dofile("../support/aseutilities.lua")

-- Supported easing modes as presented in dialog.
-- Analogous to enumerations.
local easingModes = { "RGB", "HSV" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hsvEasing = { "NEAR", "FAR" }

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    angle = 90,
    cw = false,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHSV = "NEAR"
}

local function createConic(
    sprite,
    img,
    xOrigin, yOrigin,
    angle, cw,
    aColor, bColor,
    easingMode, easingFunc)

    local w = sprite.width
    local h = sprite.height

    local shortEdge = math.min(w, h)
    local longEdge = math.max(w, h)

    -- Compensate for image aspect ratio.
    local wInv = 1.0
    local hInv = 1.0 / h
    local xOriginNorm = xOrigin or 0.0
    local yOriginNorm = yOrigin or 0.0

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
    local a3 = 0

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 0

    local easing = AseUtilities.lerpRgba

    if easingMode and easingMode == "HSV" then
        a0 = aColor.hue
        a1 = aColor.saturation
        a2 = aColor.value
        a3 = aColor.alpha

        b0 = bColor.hue
        b1 = bColor.saturation
        b2 = bColor.value
        b3 = bColor.alpha

        if easingFunc and easingFunc == "FAR" then
            easing = AseUtilities.lerpHsvaFar
        else
            easing = AseUtilities.lerpHsvaNear
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

        -- Set element to integer composite.
        elm(easing(
            a0, a1, a2, a3,
            b0, b1, b2, b3,
            fac))

        i = i + 1
    end
end

local dlg = Dialog { title = "Conic Gradient" }

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

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:check {
    id = "cw",
    label = "Chirality:",
    text = "Flip y axis.",
    selected = defaults.cw
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
    id = "easingFuncHSV",
    label = "HSV Easing:",
    option = defaults.easingFuncHSV,
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
                easingFunc = args.easingFuncHSV
            end

            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local layer = sprite:newLayer()
            layer.name = "Conic Gradient"
            local cel = sprite:newCel(layer, 1)

            createConic(
                sprite,
                cel.image,
                0.01 * args.xOrigin,
                0.01 * args.yOrigin,
                math.rad(args.angle),
                args.cw,
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