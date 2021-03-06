dofile("./vec2.lua")
dofile("./mesh2.lua")
dofile("./utilities.lua")

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

---Draws a mesh in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param mesh table
---@param useFill boolean
---@param fillClr table
---@param useStroke boolean
---@param strokeClr table
---@param brsh table
---@param cel table
---@param layer table
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