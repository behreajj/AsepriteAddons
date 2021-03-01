local easingModes = {
    "RGB", "HSV"
}

local rgbEasing = {
    "LINEAR", "SMOOTH"
}

local hsvEasing = {
    "NEAR", "FAR"
}

local defaults = {
    xOrigin = 0,
    yOrigin = 0,
    angle = 90,
    cw = false,
    aColor = Color(32, 32, 32, 255),
    bColor = Color(255, 245, 215, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHSV = "NEAR"
}

local function toHexRGBA(cr, cg, cb, ca)
    -- '|' is bitwise or.
    -- '<<' is bitwise shift left.
    -- RGBA are already in [0, 255].
    return ca << 0x18
         | cb << 0x10
         | cg << 0x8
         | cr
end

local function toHexHSVA(ch, cs, cv, ca)
    -- hue is in [0, 360].
    -- sat is in [0.0, 1.0].
    -- val is in [0.0, 1.0].

    -- Bring hue into [0.0, 1.0] by dividing by 360.0.
    local h = ((ch * 0.002777777777777778) % 1.0) * 6.0

    local sector = math.tointeger(h)
    local tint1 = cv * (1.0 - cs)
    local tint2 = cv * (1.0 - cs * (h - sector))
    local tint3 = cv * (1.0 - cs * (1.0 + sector - h))

    if sector == 0 then
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint3),
            math.tointeger(0.5 + 255.0 * tint1),
            ca)
    elseif sector == 1 then
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * tint2),
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint1),
            ca)
    elseif sector == 2 then
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint3),
            ca)
    elseif sector == 3 then
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * tint2),
            math.tointeger(0.5 + 255.0 * cv),
            ca)
    elseif sector == 4 then
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * tint3),
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * cv),
            ca)
    else
        return toHexRGBA(
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * tint2),
            ca)
    end
end

local function lerpRGB(ar, ag, ab, aa, br, bg, bb, ba, t)
    local u = 1.0 - t
    return toHexRGBA(
        math.tointeger(u * ar + t * br),
        math.tointeger(u * ag + t * bg),
        math.tointeger(u * ab + t * bb),
        math.tointeger(u * aa + t * ba))
end

local function smoothRGB(ar, ag, ab, aa, br, bg, bb, ba, t)
    return lerpRGB(ar, ag, ab, aa, br, bg, bb, ba,
        t * t * (3.0 - (t + t)))
end

local function lerpAngleNear(origin, dest, t)
    local o = origin % 360.0
    local d = dest % 360.0
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > 180.0 then
        return (u * (o + 360.0) + t * d) % 360.0
    elseif o > d and diff < -180.0 then
        return (u * o + t * (d + 360.0)) % 360.0
    else
        return u * o + t * d
    end
end

local function lerpAngleFar(origin, dest, t)
    local o = origin % 360.0
    local d = dest % 360.0
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 or (o < d and diff < 180.0) then
        return (u * (o + 360.0) + t * d) % 360.0
    elseif o > d and diff > -180.0 then
        return (u * o + t * (d + 360.0)) % 360.0
    else
        return u * o + t * d
    end
end

local function lerpHSVFar(ah, as, av, aa, bh, bs, bv, ba, t)
    local u = 1.0 - t
    return toHexHSVA(
        lerpAngleFar(ah, bh, t),
        u * as + t * bs,
        u * av + t * bv,
        math.tointeger(u * aa + t * ba))
end

local function lerpHSVNear(ah, as, av, aa, bh, bs, bv, ba, t)
    local u = 1.0 - t
    return toHexHSVA(
        lerpAngleNear(ah, bh, t),
        u * as + t * bs,
        u * av + t * bv,
        math.tointeger(u * aa + t * ba))
end

local function create_conic(
    w, h,
    xOrigin, yOrigin,
    angle, cw,
    aColor, bColor,
    easingMode, easingFunc)

    -- Create new layer.
    local sprite = app.activeSprite
    local layer = sprite:newLayer()
    layer.name = "Gradient"
    local cel = sprite:newCel(layer, 1)

    local shortEdge = math.min(w, h)
    local longEdge = math.max(w, h)

    -- Compensate for image aspect ratio.
    local wInv = 1.0
    local hInv = 1.0 / (h - 1.0)
    if shortEdge == longEdge then
        wInv = 1.0 / (w - 1.0)
    elseif w == shortEdge then
        wInv = (shortEdge / longEdge) / (w - 1.0)
    elseif h == shortEdge then
        wInv = (longEdge / shortEdge) / (w - 1.0)
    end

    -- Bring origin into range [0.0, 1.0].
    local xOriginNorm = xOrigin * wInv
    local yOriginNorm = yOrigin * hInv

    -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
    local xOriginSigned = xOriginNorm + xOriginNorm - 1.0
    local yOriginSigned = 1.0 - (yOriginNorm + yOriginNorm)

    -- Convert from degrees to radians (multiply by math.pi / 180.0).
    local angleRadians = math.rad(angle)

    -- Choose channels and easing based on color mode.
    local a0 = 0
    local a1 = 0
    local a2 = 0
    local a3 = 0

    local b0 = 0
    local b1 = 0
    local b2 = 0
    local b3 = 0

    local easing = lerpRGB

    if easingMode == "HSV" then
        a0 = aColor.hue
        a1 = aColor.saturation
        a2 = aColor.value
        a3 = aColor.alpha

        b0 = bColor.hue
        b1 = bColor.saturation
        b2 = bColor.value
        b3 = bColor.alpha

        if easingFunc == "FAR" then
            easing = lerpHSVFar
        else
            easing = lerpHSVNear
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

        if easingFunc == "SMOOTH" then
            easing = smoothRGB
        end

    end

    -- Get image, get its iterator.
    local img = app.activeImage
    local iterator = img:pixels()
    local i = 0

    for elm in iterator do

        -- Convert from array index to Cartesian coordinates.
        local xPoint = i % w
        local yPoint = i / w

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
        local angleSigned = math.atan(yOffset, xOffset) - angleRadians

        -- Bring angle into range [-0.5, 0.5]. Divide by 2 * math.pi.
        local angleNormed = angleSigned * 0.15915494309189535

        -- Bring angle into range [0.0, 1.0] by subtracting floor.
        -- Alternatively, use angleNormed % 1.0.
        local t = angleNormed - math.floor(angleNormed)

        -- Set element to integer composite.
        elm(easing(
            a0, a1, a2, a3,
            b0, b1, b2, b3,
            t))

        i = i + 1
    end
end

local dlg = Dialog{
    title="Conic Gradient"}

dlg:slider{
    id="xOrigin",
    label="Origin X:",
    min=0,
    max=app.activeSprite.width,
    value=defaults.xOrigin}

dlg:slider{
    id="yOrigin",
    label="Origin Y:",
    min=0,
    max=app.activeSprite.height,
    value=defaults.yOrigin}

dlg:slider{
    id="angle",
    label="Angle:",
    min=0,
    max=360,
    value=defaults.angle}

dlg:check{
    id="cw",
    label="Chirality: ",
    text="Flip y axis.",
    selected=defaults.cw}

dlg:color{
    id="aColor",
    label="Color A: ",
    color=defaults.aColor}

dlg:color{
    id="bColor",
    label="Color B: ",
    color=defaults.bColor}

dlg:combobox{
    id="easingMode",
    label="Easing Mode: ",
    option=defaults.easingMode,
    options=easingModes}

dlg:combobox{
    id="easingFuncHSV",
    label="HSV Easing: ",
    option=defaults.easingFuncHSV,
    options=hsvEasing}

dlg:combobox{
    id="easingFuncRGB",
    label="RGB Easing: ",
    option=defaults.easingFuncRGB,
    options=rgbEasing}

dlg:button{
    id="ok",
    text="OK",
    focus=true,
    onclick=function()
        local args = dlg.data

        local easingFunc = args.easingFuncRGB
        if args.easingMode == "HSV" then
            easingFunc = args.easingFuncHSV
        end

        create_conic(
            app.activeSprite.width,
            app.activeSprite.height,
            args.xOrigin,
            args.yOrigin,
            args.angle,
            args.cw,
            args.aColor,
            args.bColor,
            args.easingMode,
            easingFunc)

        app.refresh()
    end}

dlg:button{
    id="cancel",
    text="CANCEL",
    onclick=function()
        dlg:close()
    end}

dlg:show{wait=false}