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

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = {}
    setmetatable(inst, AseUtilities)
    return inst
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
---@param lnColor table line color
---@param coColor table coordinate color
---@param fhColor table fore handle color
---@param rhColor table rear handle color
function AseUtilities.drawHandles2(
    curve,
    cel,
    layer,
    lnColor,
    coColor,
    fhColor,
    rhColor)

    local kns = curve.knots
    local knsLen = #kns
    for i = 1, knsLen, 1 do
        AseUtilities.drawKnot2(
            kns[i],
            cel,
            layer,
            lnColor,
            coColor,
            fhColor,
            rhColor)
    end
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot table knot
---@param cel table cel
---@param layer table layer
---@param lnColor table line color
---@param coColor table coordinate color
---@param fhColor table fore handle color
---@param rhColor table rear handle color
function AseUtilities.drawKnot2(
    knot,
    cel,
    layer,
    lnColor,
    coColor,
    fhColor,
    rhColor)

    -- #02A7EB, #EBE128, #EB1A40
    local lnClrVal = lnColor or Color(0xffafafaf)
    local rhClrVal = rhColor or Color(0xffeba702)
    local coClrVal = coColor or Color(0xff28e1eb)
    local fhClrVal = fhColor or Color(0xff401aeb)

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
            points = { coPt, rhPt },
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

---Mixes an origin and destination color
---in HSV by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The hue is interpolated in the furthest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param av number origin value
---@param aa number origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bv number destination value
---@param ba number destination alpha
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
---in HSV by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The hue is interpolated in the nearest
---direction.
---@param ah number origin hue
---@param as number origin saturation
---@param av number origin value
---@param aa number origin alpha
---@param bh number destination hue
---@param bs number destination saturation
---@param bv number destination value
---@param ba number destination alpha
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

---Mixes an origin and destination color
---by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The color channels should be unpacked and
---in the range [0, 255].
---@param ar number origin red
---@param ag number origin green
---@param ab number origin blue
---@param aa number origin alpha
---@param br number destination red
---@param bg number destination green
---@param bb number destination blue
---@param ba number destination alpha
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

---Mixes an origin and destination color
---by a factor. The factor is assumed to
---be in [0.0, 1.0], but the mix is unclamped.
---The color channels should be unpacked and
---in the range [0, 255].
---Smooths the factor.
---@param ar number origin red
---@param ag number origin green
---@param ab number origin blue
---@param aa number origin alpha
---@param br number destination red
---@param bg number destination green
---@param bb number destination blue
---@param ba number destination alpha
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

---Converts an unpacked hue, saturation, value and
---alpha channel to a hexadecimal integer.
---The hue should be in [0.0, 360.0].
---The saturation should be in [0.0, 1.0].
---The value should be in [0.0, 1.0].
---@param ch number hue
---@param cs number saturation
---@param cv number value
---@param ca number alpha
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