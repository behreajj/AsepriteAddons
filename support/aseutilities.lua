dofile("./clr.lua")
dofile("./curve2.lua")
dofile("./mesh2.lua")
dofile("./utilities.lua")
dofile("./vec2.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

AseUtilities.DEFAULT_PALETTE = {
    Color(255,   0,   0, 255),
    Color(255, 106,   0, 255),
    Color(255, 162,   0, 255),
    Color(255, 207,   0, 255),
    Color(255, 255,   0, 255),
    Color(129, 212,  26, 255),
    Color(  0, 169,  51, 255),
    Color( 21, 132, 102, 255),
    Color( 17,  89, 166, 255),
    Color( 60,  42, 146, 255),
    Color(105,  12, 133, 255),
    Color(170,   0,  85, 255),
    Color(  0,   0,   0, 255),
    Color(255, 255, 255, 255)
}

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = setmetatable({}, AseUtilities)
    return inst
end

---Converts an Aseprite Color object to a Clr.
---@param aseClr table Aseprite color
---@return table
function AseUtilities.aseColorToClr(aseClr)
    return Clr.new(
        0.00392156862745098 * aseClr.red,
        0.00392156862745098 * aseClr.green,
        0.00392156862745098 * aseClr.blue,
        0.00392156862745098 * aseClr.alpha)
end

---Converts a Clr to an Aseprite Color.
---@param clr table clr
---@return table
function AseUtilities.clrToAseColor(clr)
    return Color(
        math.tointeger(0.5 + 255.0 * clr.r),
        math.tointeger(0.5 + 255.0 * clr.g),
        math.tointeger(0.5 + 255.0 * clr.b),
        math.tointeger(0.5 + 255.0 * clr.a))
end

---Draws a curve in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param curve table curve
---@param resolution integer curve resolution
---@param useFill boolean use fill
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
function AseUtilities.drawCurve2(
    curve,
    resolution,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    local vres = 2
    if resolution > 2 then vres = resolution end

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
    local pts = {}
    local start = 2
    local prevKnot = kns[1]
    if isLoop then
        start = 1
        prevKnot = kns[knsLen]
    end

    for i = start, knsLen, 1 do
        local currKnot = kns[i]

        local coPrev = prevKnot.co
        local fhPrev = prevKnot.fh
        local rhNext = currKnot.rh
        local coNext = currKnot.co

        local v = Vec2.round(coPrev)
        table.insert(pts, Point(v.x, v.y))

        for j = 1, vres, 1 do
            v = Vec2.round(
                Vec2.bezierPoint(
                    coPrev, fhPrev,
                    rhNext, coNext,
                    j * toPercent))
            table.insert(pts, Point(v.x, v.y))
        end

        prevKnot = currKnot
    end

    -- Draw fill.
    if isLoop and useFill then
        app.transaction(function()
            app.useTool {
                tool = "contour",
                color = fillClr,
                brush = brsh,
                points = pts,
                cel = cel,
                layer = layer,
                freehandAlgorithm = 1 }
        end)
    end

    -- Draw stroke.
    if useStroke then
        app.transaction(function()
            local ptPrev = pts[1]
            local ptsLen = #pts
            if isLoop then
                ptPrev = pts[ptsLen]
            end

            for i = start, ptsLen, 1 do
                local ptCurr = pts[i]
                app.useTool {
                    tool = "line",
                    color = strokeClr,
                    brush = brsh,
                    points = { ptPrev, ptCurr },
                    cel = cel,
                    layer = layer,
                    freehandAlgorithm = 1 }
                ptPrev = ptCurr
            end
        end)
    end

    app.refresh()
end

---Draws the knot handles of a curve.
---Color arguments are optional.
---@param curve table curve
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawHandles2(
    curve, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    local kns = curve.knots
    local knsLen = #kns
    app.transaction(function()
        for i = 1, knsLen, 1 do
            AseUtilities.drawKnot2(
                kns[i], cel, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot table knot
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawKnot2(
    knot, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    -- #02A7EB, #EBE128, #EB1A40
    local lnClrVal = lnClr or Color(0xffafafaf)
    local rhClrVal = rhClr or Color(0xffeba702)
    local coClrVal = coClr or Color(0xff28e1eb)
    local fhClrVal = fhClr or Color(0xff401aeb)

    local lnBrush = Brush { size = 1 }
    local rhBrush = Brush { size = 4 }
    local coBrush = Brush { size = 6 }
    local fhBrush = Brush { size = 5 }

    local coRnd = Vec2.round(knot.co)
    local fhRnd = Vec2.round(knot.fh)
    local rhRnd = Vec2.round(knot.rh)

    local coPt = Point(coRnd.x, coRnd.y)
    local fhPt = Point(fhRnd.x, fhRnd.y)
    local rhPt = Point(rhRnd.x, rhRnd.y)

    app.transaction(function()
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = fhClrVal,
            brush = fhBrush,
            points = { fhPt },
            cel = cel,
            layer = layer }
    end)
end

---Draws a mesh in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param mesh table mesh
---@param useFill boolean use fill
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
function AseUtilities.drawMesh2(
    mesh,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    -- Convert Vec2s to Points.
    -- Round Vec2 for improved accuracy.
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    for i = 1, vsLen, 1 do
        local v = Vec2.round(vs[i])
        table.insert(pts, Point(v.x, v.y))
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    local ptsGrouped = {}
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        local ptsFace = {}
        for j = 1, fLen, 1 do
            table.insert(ptsFace, pts[f[j]])
        end
        table.insert(ptsGrouped, ptsFace)
    end

    -- Group fills into one transaction.
    if useFill then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                app.useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[i],
                    cel = cel,
                    layer = layer }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                local ptGroup = ptsGrouped[i]
                local ptgLen = #ptGroup
                local ptPrev = ptGroup[ptgLen]
                for j = 1, ptgLen, 1 do
                    local ptCurr = ptGroup[j]
                    app.useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        cel = cel,
                        layer = layer }
                    ptPrev = ptCurr
                end
            end
        end)
    end

    app.refresh()
end

---Returns an appropriate easing function
---based on string presets:
---"RGB", "HSL" or "HSV" easing modes;
---"LINEAR" or "SMOOTH" RGB functions;
---"NEAR" or "FAR" hue functions.
---@param easingMode string
---@param easingFuncRGB string
---@param easingFuncHue string
---@return function
function AseUtilities.easingFuncPresets(
    easingMode,
    easingFuncRGB,
    easingFuncHue)

    local easing = nil
    if easingMode == "HSV" then
        easing = Clr.mixHsva

        if easingFuncHue == "FAR" then
            easing = function(a, b, t)
                return Clr.mixHsva(
                    a, b, t,
                    function(x, y, z)
                        return Utilities.lerpAngleFar(
                            x, y, z, 1.0)
                    end)
            end
        end
    elseif easingMode == "HSL" then
        easing = Clr.mixHsla

        if easingFuncHue == "FAR" then
            easing = function(a, b, t)
                return Clr.mixHsla(
                    a, b, t,
                    function(x, y, z)
                        return Utilities.lerpAngleFar(
                            x, y, z, 1.0)
                    end)
            end
        end
    else
        easing = Clr.mixRgba

        if easingFuncRGB == "SMOOTH" then
            easing = function(a, b, t)
                return Clr.mixRgba(a, b,
                    t * t * (3.0 - (t + t)))
            end
        end
    end

    return easing

end

---Initializes a sprite and layer.
---Sets palette to the colors provided,
---or, if nil, a default set.
---@param wDefault integer default width
---@param hDefault integer default height
---@param layerName string layer name
---@param colors table array of colors
---@return table
function AseUtilities.initCanvas(
    wDefault,
    hDefault,
    layerName,
    colors)

    local clrs = AseUtilities.DEFAULT_PALETTE
    if colors and #colors > 0 then
        clrs = colors
    end

    local sprite = app.activeSprite
    local layer = nil

    if sprite == nil then
        sprite = Sprite(wDefault, hDefault)
        app.activeSprite = sprite
        layer = sprite.layers[1]
        local lenClrs = #clrs
        local pal = Palette(lenClrs)
        for i = 1, lenClrs, 1 do
            local clr = clrs[i]
            if clr then
                pal:setColor(i - 1, clr)
            end
        end
        sprite:setPalette(pal)
    else
        layer = sprite:newLayer()
    end

    layer.name = layerName or "Layer"
    return sprite
end

---Mixes an origin and destination color
---in HSL by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The hue is interpolated in the furthest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param al number origin lightness
---@param aa integer origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bl number destination lightness
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.lerpHslaFar(
    ah, as, al, aa,
    bh, bs, bl, ba, t)
    local u = 1.0 - t
    return AseUtilities.toHexHsla(
        Utilities.lerpAngleFar(ah, bh, t, 360.0),
        u * as + t * bs,
        u * al + t * bl,
        math.tointeger(u * aa + t * ba))
end

---Mixes an origin and destination color
---in HSL by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The hue is interpolated in the nearest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param al number origin lightness
---@param aa integer origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bl number destination lightness
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.lerpHslaNear(
    ah, as, al, aa,
    bh, bs, bl, ba, t)
    local u = 1.0 - t
    return AseUtilities.toHexHsla(
        Utilities.lerpAngleNear(ah, bh, t, 360.0),
        u * as + t * bs,
        u * al + t * bl,
        math.tointeger(u * aa + t * ba))
end

---Mixes an origin and destination color
---in HSV by a factor; returns an integer.
-- The factor is assumed to be in [0.0, 1.0],
-- but the mix is unclamped.
---The hue is interpolated in the furthest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param av number origin value
---@param aa integer origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bv number destination value
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.lerpHsvaFar(
    ah, as, av, aa,
    bh, bs, bv, ba, t)
    local u = 1.0 - t
    return AseUtilities.toHexHsva(
        Utilities.lerpAngleFar(ah, bh, t, 360.0),
        u * as + t * bs,
        u * av + t * bv,
        math.tointeger(u * aa + t * ba))
end

---Mixes an origin and destination color
---in HSV by a factor; returns an integer.
-- The factor is assumed to be in [0.0, 1.0],
-- but the mix is unclamped.
---The hue is interpolated in the nearest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param av number origin value
---@param aa integer origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bv number destination value
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.lerpHsvaNear(
    ah, as, av, aa,
    bh, bs, bv, ba, t)
    local u = 1.0 - t
    return AseUtilities.toHexHsva(
        Utilities.lerpAngleNear(ah, bh, t, 360.0),
        u * as + t * bs,
        u * av + t * bv,
        math.tointeger(u * aa + t * ba))
end

---Mixes between elements in a color array
---by a factor with linear RGB.
---@param arr table array of colors
---@param t number factor
---@return integer
function AseUtilities.lerpColorArr(arr, t)
    if t <= 0.0  then
        return arr[1].rgbaPixel
    end

    if t >= 1.0 then
        return arr[#arr].rgbaPixel
    end

    local tScaled = t * (#arr - 1)
    local i = math.tointeger(tScaled)
    local a = arr[1 + i]
    local b = arr[2 + i]
    return AseUtilities.lerpRgba(
        a.red, a.green, a.blue, a.alpha,
        b.red, b.green, b.blue, b.alpha,
        tScaled - i)
end

---Mixes an origin and destination color
---by a factor; returns an integer.
-- The factor is assumed to be in [0.0, 1.0],
-- but the mix is unclamped.
---The color channels should be unpacked and
---in the range [0, 255].
---@param ar integer origin red
---@param ag integer origin green
---@param ab integer origin blue
---@param aa integer origin alpha
---@param br integer destination red
---@param bg integer destination green
---@param bb integer destination blue
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.lerpRgba(
    ar, ag, ab, aa,
    br, bg, bb, ba, t)
    local u = 1.0 - t
    return app.pixelColor.rgba(
        math.tointeger(u * ar + t * br),
        math.tointeger(u * ag + t * bg),
        math.tointeger(u * ab + t * bb),
        math.tointeger(u * aa + t * ba))
end

---Converts an Aseprite palette to a table
---of Aseprite Colors. If the palette is nil
---returns a default table.
---@param pal table
---@return table
function AseUtilities.paletteToColorArr(pal)
    if pal then
        local clrs = {}
        local len = #pal
        for i = 1, len, 1 do
            clrs[i] = pal:getColor(i - 1)
        end
        return clrs
    else
        return AseUtilities.DEFAULT_PALETTE
    end
end

---Mixes an origin and destination color
---by a factor; returns an integer.
---The factor is assumed to be in [0.0, 1.0],
---but the mix is unclamped.
---The color channels should be unpacked and
---in the range [0, 255].
---Smooths the factor.
---@param ar integer origin red
---@param ag integer origin green
---@param ab integer origin blue
---@param aa integer origin alpha
---@param br integer destination red
---@param bg integer destination green
---@param bb integer destination blue
---@param ba integer destination alpha
---@param t number factor
---@return integer
function AseUtilities.smoothRgba(
    ar, ag, ab, aa,
    br, bg, bb, ba, t)
    return AseUtilities.lerpRgba(
        ar, ag, ab, aa,
        br, bg, bb, ba,
        t * t * (3.0 - (t + t)))
end

---Converts an unpacked hue, saturation, lightness
---and alpha channel to a hexadecimal integer.
---The hue should be in [0.0, 360.0].
---The saturation should be in [0.0, 1.0].
---The lightness should be in [0.0, 1.0].
---The alpha should be in [0, 255].
---@param ch number hue
---@param cs number saturation
---@param cl number lightness
---@param ca integer alpha
---@return integer
function AseUtilities.toHexHsla(ch, cs, cl, ca)
    if cl <= 0.0 then
        return app.pixelColor.rgba(
            0, 0, 0, ca)
    end

    if cl >= 1.0 then
        return app.pixelColor.rgba(
            255, 255, 255, ca)
    end

    if cs <= 0.0 then
        local l255 = math.tointeger(0.5 + 255.0 * cl)
        return app.pixelColor.rgba(
            l255, l255, l255, ca)
    end

    local scl = math.min(cs, 1.0)
    local q = cl + scl - cl * scl
    if cl < 0.5 then
        q = cl * (1.0 + scl)
    end
    local p = cl + cl - q
    local qnp6 = (q - p) * 6.0
    local hue1 = ch * 0.002777777777777778

    local r = p
    local rHue = (hue1 + 0.3333333333333333) % 1.0
    if rHue < 0.16666666666666667 then
        r = p + qnp6 * rHue
    elseif rHue < 0.5 then
        r = q;
    elseif rHue < 0.6666666666666667 then
        r = p + qnp6 * (0.6666666666666667 - rHue)
    end

    local g = p
    local gHue = hue1 % 1.0
    if gHue < 0.16666666666666667 then
        g = p + qnp6 * gHue
    elseif gHue < 0.5 then
        g = q;
    elseif gHue < 0.6666666666666667 then
        g = p + qnp6 * (0.6666666666666667 - gHue)
    end

    local b = p
    local bHue = (hue1 - 0.3333333333333333) % 1.0
    if bHue < 0.16666666666666667 then
        b = p + qnp6 * bHue
    elseif bHue < 0.5 then
        b = q;
    elseif bHue < 0.6666666666666667 then
        b = p + qnp6 * (0.6666666666666667 - bHue)
    end

    return app.pixelColor.rgba(
        math.tointeger(0.5 + 255.0 * r),
        math.tointeger(0.5 + 255.0 * g),
        math.tointeger(0.5 + 255.0 * b),
        ca)
end

---Converts an unpacked hue, saturation, value
---and alpha channel to a hexadecimal integer.
---The hue should be in [0.0, 360.0].
---The saturation should be in [0.0, 1.0].
---The value should be in [0.0, 1.0].
---The alpha should be in [0, 255].
---@param ch number hue
---@param cs number saturation
---@param cv number value
---@param ca integer alpha
---@return integer
function AseUtilities.toHexHsva(ch, cs, cv, ca)
    -- Bring hue into [0.0, 1.0] by dividing by 360.0.
    local h = ((ch * 0.002777777777777778) % 1.0) * 6.0

    local sector = math.tointeger(h)
    local tint1 = cv * (1.0 - cs)
    local tint2 = cv * (1.0 - cs * (h - sector))
    local tint3 = cv * (1.0 - cs * (1.0 + sector - h))

    if sector == 0 then
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint3),
            math.tointeger(0.5 + 255.0 * tint1),
            ca)
    elseif sector == 1 then
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * tint2),
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint1),
            ca)
    elseif sector == 2 then
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint3),
            ca)
    elseif sector == 3 then
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * tint2),
            math.tointeger(0.5 + 255.0 * cv),
            ca)
    elseif sector == 4 then
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * tint3),
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * cv),
            ca)
    else
        return app.pixelColor.rgba(
            math.tointeger(0.5 + 255.0 * cv),
            math.tointeger(0.5 + 255.0 * tint1),
            math.tointeger(0.5 + 255.0 * tint2),
            ca)
    end
end

return AseUtilities