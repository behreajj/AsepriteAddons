dofile("./knot2.lua")

---@class Curve2
---@field public closedLoop boolean closed loop
---@field public knots table knots
---@field public name string name
Curve2 = {}
Curve2.__index = Curve2

setmetatable(Curve2, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a piecewise cubic Bezier curve.
---The first parameter specifies a closed loop
---if true. The second parameter should be
---a table of Knot2s.
---@param cl boolean closed loop
---@param knots Knot2[] knots
---@param name string|nil name
---@return Curve2
function Curve2.new(cl, knots, name)
    local inst = setmetatable({}, Curve2)
    inst.closedLoop = cl or false
    inst.knots = knots or {}
    inst.name = name or "Curve2"
    return inst
end

function Curve2:__len()
    return #self.knots
end

function Curve2:__tostring()
    return Curve2.toJson(self)
end

---Rotates this curve around the z axis by
---an angle in radians.
---@param radians number angle
---@return Curve2
function Curve2:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the z axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Curve2
function Curve2:rotateZInternal(cosa, sina)
    local knsLen = #self.knots
    local i = 0
    while i < knsLen do
        i = i + 1
        self.knots[i]:rotateZInternal(cosa, sina)
    end
    return self
end

---Scales this curve.
---Defaults to scale by a vector.
---@param v Vec2|number scalar
---@return Curve2
function Curve2:scale(v)
    if type(v) == "number" then
        return self:scaleNum(v)
    else
        return self:scaleVec2(v)
    end
end

---Scales this curve by a number.
---@param n number uniform scalar
---@return Curve2
function Curve2:scaleNum(n)
    if n ~= 0.0 then
        local knsLen = #self.knots
        local i = 0
        while i < knsLen do
            i = i + 1
            self.knots[i]:scaleNum(n)
        end
    end
    return self
end

---Scales this curve by a vector.
---@param v Vec2 nonuniform scalar
---@return Curve2
function Curve2:scaleVec2(v)
    if Vec2.all(v) then
        local knsLen = #self.knots
        local i = 0
        while i < knsLen do
            i = i + 1
            self.knots[i]:scaleVec2(v)
        end
    end
    return self
end

---Translates this curve by a vector.
---@param v Vec2 vector
---@return Curve2
function Curve2:translate(v)
    local knsLen = #self.knots
    local i = 0
    while i < knsLen do
        i = i + 1
        self.knots[i]:translate(v)
    end
    return self
end

---Creates a curve sector from a start to
---to a stop angle. The stroke defines the
---thickness. The offset is the relationship
---of the stroke to the spine.
---@param startAngle number start angle
---@param stopAngle number stop angle
---@param radius number radius
---@param stroke number stroke thickness
---@param offset number|nil stroke offset
---@param xOrigin number|nil origin x
---@param yOrigin number|nil origin y
---@return Curve2
function Curve2.arcSector(startAngle, stopAngle, radius, stroke, offset, xOrigin, yOrigin)
    -- Supply default arguments.
    local yoVerif = yOrigin or 0.0
    local xoVerif = xOrigin or 0.0
    local offVerif = offset or 0.0
    local strkVerif = stroke or 0.25
    local radVerif = radius or 0.5
    local edAngVerif = stopAngle or 1.5707963267949
    local stAngVerif = startAngle or 0.0

    -- Swap start and end angles.
    if edAngVerif < stAngVerif then
        local swap = edAngVerif
        edAngVerif = stAngVerif
        stAngVerif = swap
    end

    -- Verify proper ranges.
    offVerif = math.max(-1.0, math.min(1.0, offVerif))
    if math.abs(radVerif) < 0.000001 then
        radVerif = 0.5
    end

    -- Inner and outer edge of arc.
    local innerEdge = (radVerif - strkVerif)
        + strkVerif * (offVerif * 0.5 + 0.5)
    local outerEdge = innerEdge + strkVerif

    -- Calculate handle length.
    local arcLength = math.min(
        edAngVerif - stAngVerif, 6.2831853071796)
    local arcLen01 = arcLength * 0.1591549430919
    local knCtVerif = math.ceil(1 + 4 * arcLen01)
    local toStep = 1.0 / (knCtVerif - 1.0)
    local invKnCt = toStep * arcLen01
    local tanHalf = 1.33333333333333
        * math.tan(1.5707963267949 * invKnCt)

    -- Handles on inner edge travel in opposite
    -- direction, so innerMag is negative.
    local innerMag = -innerEdge * tanHalf
    local outerMag = outerEdge * tanHalf

    local kns = {}

    local cos = math.cos
    local sin = math.sin
    local len2n1 = knCtVerif + knCtVerif - 1
    for i = 0, len2n1, 1 do
        local j = i // 2
        local k = j + 1

        local t = j * toStep
        local u = 1.0 - t

        local a0 = u * stAngVerif + t * edAngVerif
        local a1 = u * edAngVerif + t * stAngVerif

        kns[k] = Knot2.fromPolarInternal(
            cos(a0), sin(a0),
            outerEdge, outerMag,
            xoVerif, yoVerif)

        kns[knCtVerif + k] = Knot2.fromPolarInternal(
            cos(a1), sin(a1),
            innerEdge, innerMag,
            xoVerif, yoVerif)
    end

    -- Flatten handles at start of arc.
    local firstOuter = kns[1]
    local lastInner = kns[#kns]
    local foCo = firstOuter.co
    local liCo = lastInner.co
    firstOuter.rh = Vec2.mixNum(
        foCo, liCo, 0.33333333333333)
    lastInner.fh = Vec2.mixNum(
        liCo, foCo, 0.33333333333333)

    -- Flatten handles at end of arc.
    local firstInner = kns[knCtVerif + 1]
    local lastOuter = kns[knCtVerif]
    local loCo = lastOuter.co
    local fiCo = firstInner.co
    lastOuter.fh = Vec2.mixNum(
        loCo, fiCo, 0.33333333333333)
    firstInner.rh = Vec2.mixNum(
        fiCo, loCo, 0.33333333333333)

    return Curve2.new(true, kns, "Arc")
end

---Creates a curve to approximate an ellipse.
---The radii default to 0.5.
---The origin defaults to (0.0, 0.0).
---@param xRadius number|nil horizontal radius
---@param yRadius number|nil vertical radius
---@param xOrigin number|nil x origin
---@param yOrigin number|nil y origin
---@return Curve2
function Curve2.ellipse(xRadius, yRadius, xOrigin, yOrigin)
    -- Supply default arguments.
    local cy = yOrigin or 0.0
    local cx = xOrigin or 0.0
    local ry = yRadius or 0.5
    local rx = xRadius or 0.5

    -- Validate radii.
    rx = math.max(0.000001, math.abs(rx))
    ry = math.max(0.000001, math.abs(ry))

    local right = cx + rx
    local top = cy + ry
    local left = cx - rx
    local bottom = cy - ry

    -- kappa := 4 * (math.sqrt(2) - 1) / 3
    local horizHandle = rx * 0.55228474983079
    local vertHandle = ry * 0.55228474983079

    local xHandlePos = cx + horizHandle
    local xHandleNeg = cx - horizHandle
    local yHandlePos = cy + vertHandle
    local yHandleNeg = cy - vertHandle

    return Curve2.new(true, {
        Knot2.new(
            Vec2.new(right, cy),
            Vec2.new(right, yHandlePos),
            Vec2.new(right, yHandleNeg)),
        Knot2.new(
            Vec2.new(cx, top),
            Vec2.new(xHandleNeg, top),
            Vec2.new(xHandlePos, top)),
        Knot2.new(
            Vec2.new(left, cy),
            Vec2.new(left, yHandleNeg),
            Vec2.new(left, yHandlePos)),
        Knot2.new(
            Vec2.new(cx, bottom),
            Vec2.new(xHandlePos, bottom),
            Vec2.new(xHandleNeg, bottom))
    }, "Ellipse")
end

---Evaluates a curve by a step in [0.0, 1.0].
---Returns a vector representing a point on the curve.
---@param curve Curve2 curve
---@param step number step
---@return Vec2
function Curve2.eval(curve, step)
    local t = step or 0.5
    local knots = curve.knots
    local knotLength = #knots
    local tScaled = 0.0
    local i = 0
    local a = nil
    local b = nil

    if curve.closedLoop then

        tScaled = (t % 1.0) * knotLength
        i = math.floor(tScaled)
        a = knots[1 + (i % knotLength)]
        b = knots[1 + ((i + 1) % knotLength)]

    else

        if t <= 0.0 or knotLength == 1 then
            return Curve2.evalFirst(curve)
        end

        if t >= 1.0 then
            return Curve2.evalLast(curve)
        end

        tScaled = t * (knotLength - 1)
        i = math.floor(tScaled)
        a = knots[1 + i]
        b = knots[2 + i]

    end

    local tsni = tScaled - i
    return Knot2.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot,
---returning a copy of the first knot coord.
---@param curve Curve2 curve
---@return Vec2
function Curve2.evalFirst(curve)
    local kFirst = curve.knots[1]
    local coFirst = kFirst.co
    return Vec2.new(coFirst.x, coFirst.y)
end

---Evaluates a curve at its last knot,
---returning a copy of the last knot coord.
---@param curve Curve2 curve
---@return Vec2
function Curve2.evalLast(curve)
    local kLast = curve.knots[#curve.knots]
    local coLast = kLast.co
    return Vec2.new(coLast.x, coLast.y)
end

---Creats a curve that approximates Bernoulli's
---lemniscate, i.e., an infinity loop.
---@return Curve2
function Curve2.infinity()
    return Curve2.new(true, {
        Knot2.new(
            Vec2.new(0.5, 0.0),
            Vec2.new(0.5, 0.1309615),
            Vec2.new(0.5, -0.1309615)),
        Knot2.new(
            Vec2.new(0.235709, 0.166627),
            Vec2.new(0.0505335, 0.114256),
            Vec2.new(0.361728, 0.2022675)),
        Knot2.new(
            Vec2.new(-0.235709, -0.166627),
            Vec2.new(-0.361728, -0.2022675),
            Vec2.new(-0.0505335, -0.114256)),
        Knot2.new(
            Vec2.new(-0.5, 0.0),
            Vec2.new(-0.5, 0.1309615),
            Vec2.new(-0.5, -0.1309615)),
        Knot2.new(
            Vec2.new(-0.235709, 0.166627),
            Vec2.new(-0.0505335, 0.114256),
            Vec2.new(-0.361728, 0.2022675)),
        Knot2.new(
            Vec2.new(0.235709, -0.166627),
            Vec2.new(0.361728, -0.2022675),
            Vec2.new(0.0505335, -0.114256))
    }, "Infinity")
end

---Creates a rectangle with rounded corners.
---Rounding may be either positive or negative.
---@param lbx number lower bound x
---@param lby number lower bound y
---@param ubx number upper bound x
---@param uby number upper bound y
---@param tl number rounding top left corner
---@param tr number rounding top right corner
---@param br number rounding bottom right corner
---@param bl number rounding bottom left corner
---@return Curve2
function Curve2.rect(lbx, lby, ubx, uby, tl, tr, br, bl)
    -- Validate edges.
    local lft = math.min(lbx, ubx)
    local rgt = math.max(lbx, ubx)
    local btm = math.min(lby, uby)
    local top = math.max(lby, uby)

    -- Protect against zero dimensions on w or h.
    local w = rgt - lft
    local h = top - btm
    local wInval = w < 0.000001
    local hInval = h < 0.000001
    if wInval and hInval then
        local cx = (lft + rgt) * 0.5
        local cy = (top + btm) * 0.5
        lft = cx - 0.5
        rgt = cx + 0.5
        btm = cy - 0.5
        top = cy + 0.5
    elseif wInval then
        local cx = (lft + rgt) * 0.5
        local hHalf = h * 0.5
        lft = cx - hHalf
        rgt = cx + hHalf
        w = h
    elseif hInval then
        local cy = (top + btm) * 0.5
        local wHalf = w * 0.5
        btm = cy - wHalf
        top = cy + wHalf
        h = w
    end

    -- If only one corner arg is provided, then
    -- set them all to that corner.
    local tlSign = 0.0
    if tl then tlSign = tl end
    local blSign = tlSign
    local brSign = tlSign
    local trSign = tlSign
    if bl and br and tl then
        blSign = bl
        brSign = br
        trSign = tr
    end

    -- Absolute corner rounding.
    -- Limit is half the short edge.
    local se = 0.5 * math.min(w, h)
    local vtl = math.min(se, math.abs(tlSign))
    local vbl = math.min(se, math.abs(blSign))
    local vbr = math.min(se, math.abs(brSign))
    local vtr = math.min(se, math.abs(trSign))

    -- Multipy by kappa.
    -- 4 * (math.sqrt(2) - 1) / 3
    local vtlk = vtl * 0.55228474983079
    local vblk = vbl * 0.55228474983079
    local vbrk = vbr * 0.55228474983079
    local vtrk = vtr * 0.55228474983079

    -- Edge handles are lerped by 1 / 3.
    local t = 0.33333333333333
    local u = 0.66666666666667

    -- Calculate insets.
    local lftIns0 = lft + vtl
    local topIns1 = top - vtl
    local btmIns1 = btm + vbl
    local lftIns1 = lft + vbl
    local rgtIns1 = rgt - vbr
    local btmIns0 = btm + vbr
    local topIns0 = top - vtr
    local rgtIns0 = rgt - vtr

    local kns = {}
    local cursor = 1

    -- Top left corner.
    if tlSign > 0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(lftIns0, top),
            Vec2.new(lftIns0 - vtlk, top),
            Vec2.new(u * lftIns0 + t * rgtIns0, top))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(lft, topIns1),
            Vec2.new(lft, u * topIns1 + t * btmIns1),
            Vec2.new(lft, topIns1 + vtlk))
        cursor = cursor + 1
    elseif tlSign < -0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(lftIns0, top),
            Vec2.new(lftIns0, top - vtlk),
            Vec2.new(u * lftIns0 + t * rgtIns0, top))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(lft, topIns1),
            Vec2.new(lft, u * topIns1 + t * btmIns1),
            Vec2.new(lft + vtlk, topIns1))
        cursor = cursor + 1
    else
        kns[cursor] = Knot2.new(
            Vec2.new(lft, top),
            Vec2.new(lft, u * top + t * btmIns1),
            Vec2.new(u * lft + t * rgtIns0, top))
        cursor = cursor + 1
    end

    -- Bottom left corner.
    if blSign > 0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(lft, btmIns1),
            Vec2.new(lft, btmIns1 - vblk),
            Vec2.new(lft, u * btmIns1 + t * topIns1))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(lftIns1, btm),
            Vec2.new(u * lftIns1 + t * rgtIns1, btm),
            Vec2.new(lftIns1 - vblk, btm))
        cursor = cursor + 1
    elseif blSign < -0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(lft, btmIns1),
            Vec2.new(lft + vblk, btmIns1),
            Vec2.new(lft, u * btmIns1 + t * topIns1))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(lftIns1, btm),
            Vec2.new(u * lftIns1 + t * rgtIns1, btm),
            Vec2.new(lftIns1, btm + vblk))
        cursor = cursor + 1
    else
        kns[cursor] = Knot2.new(
            Vec2.new(lft, btm),
            Vec2.new(u * lft + t * rgtIns1, btm),
            Vec2.new(lft, u * btm + t * topIns1))
        cursor = cursor + 1
    end

    -- Bottom right corner.
    if brSign > 0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(rgtIns1, btm),
            Vec2.new(rgtIns1 + vbrk, btm),
            Vec2.new(u * rgtIns1 + t * lftIns1, btm))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, btmIns0),
            Vec2.new(rgt, u * btmIns0 + t * topIns0),
            Vec2.new(rgt, btmIns0 - vbrk))
        cursor = cursor + 1
    elseif brSign < -0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(rgtIns1, btm),
            Vec2.new(rgtIns1, btm + vbrk),
            Vec2.new(u * rgtIns1 + t * lftIns1, btm))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, btmIns0),
            Vec2.new(rgt, u * btmIns0 + t * topIns0),
            Vec2.new(rgt - vbrk, btmIns0))
        cursor = cursor + 1
    else
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, btm),
            Vec2.new(rgt, u * btm + t * topIns0),
            Vec2.new(u * rgt + t * lftIns1, btm))
        cursor = cursor + 1
    end

    -- Top right corner.
    if trSign > 0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, topIns0),
            Vec2.new(rgt, topIns0 + vtrk),
            Vec2.new(rgt, u * topIns0 + t * btmIns0))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(rgtIns0, top),
            Vec2.new(u * rgtIns0 + t * lftIns0, top),
            Vec2.new(rgtIns0 + vtrk, top))
        cursor = cursor + 1
    elseif trSign < -0.0 then
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, topIns0),
            Vec2.new(rgt - vtrk, topIns0),
            Vec2.new(rgt, u * topIns0 + t * btmIns0))
        cursor = cursor + 1
        kns[cursor] = Knot2.new(
            Vec2.new(rgtIns0, top),
            Vec2.new(u * rgtIns0 + t * lftIns0, top),
            Vec2.new(rgtIns0, top - vtrk))
        cursor = cursor + 1
    else
        kns[cursor] = Knot2.new(
            Vec2.new(rgt, top),
            Vec2.new(u * rgt + t * lftIns0, top),
            Vec2.new(rgt, u * top + t * btmIns0))
        cursor = cursor + 1
    end

    return Curve2.new(true, kns, "Rectangle")
end

---Returns a JSON string of a curve.
---@param c Curve2 curve
---@return string
function Curve2.toJson(c)
    local str = "{\"name\":\""
    str = str .. c.name
    str = str .. "\",\"closedLoop\":"
    if c.closedLoop then
        str = str .. "true"
    else
        str = str .. "false"
    end
    str = str .. ",\"knots\":["

    local kns = c.knots
    local knsLen = #kns
    local strArr = {}
    local i = 0
    while i < knsLen do
        i = i + 1
        strArr[i] = Knot2.toJson(kns[i])
    end

    str = str .. table.concat(strArr, ",")
    str = str .. "]}"
    return str
end

return Curve2
