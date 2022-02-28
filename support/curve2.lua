dofile("./vec2.lua")
dofile("./knot2.lua")

Curve2 = {}
Curve2.__index = Curve2

setmetatable(Curve2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a piecewise cubic Bezier curve.
---The first parameter specifies a closed loop
---if true. The second parameter should be
---a table of Knot2s.
---@param cl boolean closed loop
---@param knots table knots
---@param name string name
---@return table
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
---@return table
function Curve2:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the z axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Curve2:rotateZInternal(cosa, sina)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:rotateZInternal(cosa, sina)
    end
    return self
end

---Scales this curve.
---Defaults to scale by a vector.
---@param v table scalar
---@return table
function Curve2:scale(v)
    return self:scaleVec2(v)
end

---Scales this curve by a number.
---@param n table uniform scalar
---@return table
function Curve2:scaleNum(n)
    if n ~= 0.0 then
        local knsLen = #self.knots
        for i = 1, knsLen, 1 do
            self.knots[i]:scaleNum(n)
        end
    end
    return self
end

---Scales this curve by a vector.
---@param v table nonuniform scalar
---@return table
function Curve2:scaleVec2(v)
    if Vec2.all(v) then
        local knsLen = #self.knots
        for i = 1, knsLen, 1 do
            self.knots[i]:scaleVec2(v)
        end
    end
    return self
end

---Translates this curve by a vector.
---@param v table vector
---@return table
function Curve2:translate(v)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:translate(v)
    end
    return self
end

---Evaluates a curve by a step in [0.0, 1.0].
---Returns a vector representing a point on the curve.
---@param curve table curve
---@param step number step
---@return table
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
        i = math.tointeger(tScaled)
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
        i = math.tointeger(tScaled)
        a = knots[1 + i]
        b = knots[2 + i]

    end

    -- TODO: Return a tuple (separate by comma),
    -- with bezierTangent being second value?
    local tsni = tScaled - i
    return Knot2.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot,
---returning a copy of the first knot coord.
---@param curve table the curve
---@return table
function Curve2.evalFirst(curve)
    local kFirst = curve.knots[1]
    local coFirst = kFirst.co
    return Vec2.new(coFirst.x, coFirst.y)
end

---Evaluates a curve at its last knot,
---returning a copy of the last knot coord.
---@param curve table the curve
---@return table
function Curve2.evalLast(curve)
    local kLast = curve.knots[#curve.knots]
    local coLast = kLast.co
    return Vec2.new(coLast.x, coLast.y)
end

---Creates a curve sector from a start to
---to a stop angle. The stroke defines the
---thickness. The offset is the relationship
---of the stroke to the spine.
---@param startAngle number start angle
---@param stopAngle number stop angle
---@param radius number radius
---@param stroke number stroke thickness
---@param offset number stroke offset
---@return table
function Curve2.arcSector(
    startAngle,
    stopAngle,
    radius,
    stroke,
    offset,
    xOrigin,
    yOrigin)

    -- Supply default arguments.
    local yoVerif = yOrigin or 0.0
    local xoVerif = xOrigin or 0.0
    local offVerif = offset or 0.0
    local strkVerif = stroke or 0.25
    local radVerif = radius or 0.5
    local edAngVerif = stopAngle or 1.5707963267948966
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
        edAngVerif - stAngVerif,
        6.283185307179586)
    local arcLen01 = arcLength * 0.15915494309189535
    local knCtVerif = math.ceil(1 + 4 * arcLen01)
    local toStep = 1.0 / (knCtVerif - 1.0)
    local invKnCt = toStep * arcLen01
    local tanHalf = 1.3333333333333333
        * math.tan(1.5707963267948966 * invKnCt)

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
        foCo, liCo, 0.3333333333333333)
    lastInner.fh = Vec2.mixNum(
        liCo, foCo, 0.3333333333333333)

    -- Flatten handles at end of arc.
    local firstInner = kns[knCtVerif + 1]
    local lastOuter = kns[knCtVerif]
    local loCo = lastOuter.co
    local fiCo = firstInner.co
    lastOuter.fh = Vec2.mixNum(
        loCo, fiCo, 0.3333333333333333)
    firstInner.rh = Vec2.mixNum(
        fiCo, loCo, 0.3333333333333333)

    return Curve2.new(true, kns, "Arc")
end

---Creates a curve to approximate an ellipse.
---@param xRadius number
---@param yRadius number
---@param xOrigin number
---@param yOrigin number
---@return table
function Curve2.ellipse(
    xRadius,
    yRadius,
    xOrigin,
    yOrigin)

    -- Supply default arguments.
    local ry = yRadius or 0.5
    local rx = xRadius or 0.5
    local cy = yOrigin or 0.0
    local cx = xOrigin or 0.0

    -- Validate radii.
    rx = math.max(0.000001, math.abs(rx))
    ry = math.max(0.000001, math.abs(ry))

    local right = cx + rx
    local top = cy + ry
    local left = cx - rx
    local bottom = cy - ry

    -- kappa := 4 * (math.sqrt(2) - 1) / 3
    local horizHandle = rx * 0.5522847498307936
    local vertHandle = ry * 0.5522847498307936

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

---Creats a curve that approximates Bernoulli's
---lemniscate, i.e., an infinity loop.
---@return table
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

---Creates a polygon with rounded corners.
---Rounding is a factor expected to be in the
---range [0.0, 1.0].
---@param sectors number number of sides
---@param rounding number corner rounding
function Curve2.polygon(sectors, rounding)
    -- Real expected range is in [0, 1/3].
    -- A range of [0, 0.5] causes problems
    -- with overlapping knot coordinates
    -- and straight edge handles.
    local vRound = 0.16666666666666666
    if rounding then
        vRound = math.min(math.max(
            rounding, 0.000005), 0.999995) / 3.0
    end

    -- Radius of 0.5 is assumed.
    local vRad = 0.5
    local vSect = 3
    if sectors and sectors > 3 then
        vSect = sectors
    end

    -- Create corners.
    -- It is wasteful to create this array,
    -- but the alternative would be to calc
    -- sine and cosine of three angles.
    local vs = {}
    local vSectn1 = vSect - 1
    local toTheta = 6.283185307179586 / vSect
    for i = 0, vSectn1, 1 do
        local theta = i * toTheta
        vs[1 + i] = Vec2.fromPolar(theta, vRad)
    end

    -- t is factor for straight edge handle easing.
    -- k is factor for corner handle easing.
    -- kappa is 4 * (math.sqrt(2) - 1) / 3 for
    -- 4 knots on a Bezier circle, so multiply
    -- by number of corners instead.
    local t = 0.3333333333333333 - 0.5 * vRound

    -- TODO: Kappa becomes ineffective when the
    -- number of sides is greater than 8.
    local k = 0.1380711874576984 * vSect

    -- There are 2 knots for every corner.
    local kns = {}
    for i = 0, vSectn1, 1 do
        local h = (i - 1) % vSect
        local j = (i + 1) % vSect

        local vPrev = vs[1 + h]
        local vCurr = vs[1 + i]
        local vNext = vs[1 + j]

        -- Knot coordinates before and after corner.
        local coFore = Vec2.mixNum(vCurr, vPrev, vRound)
        local coAft = Vec2.mixNum(vCurr, vNext, vRound)

        -- Straight edge handles.
        local rhFore = Vec2.mixNum(coFore, vPrev, t)
        local fhAft = Vec2.mixNum(coAft, vNext, t)

        -- Corner handles.
        local fhFore = Vec2.mixNum(coFore, vCurr, k)
        local rhAft = Vec2.mixNum(coAft, vCurr, k)

        kns[1 + i + i] = Knot2.new(coFore, fhFore, rhFore)
        kns[2 + i + i] = Knot2.new(coAft, fhAft, rhAft)
    end

    local name = "Polygon"
    if vSect == 3 then name = "Triangle"
    elseif vSect == 4 then name = "Quadrilateral"
    elseif vSect == 5 then name = "Pentagon"
    elseif vSect == 6 then name = "Hexagon"
    elseif vSect == 7 then name = "Heptagon"
    elseif vSect == 8 then name = "Octagon"
    elseif vSect == 9 then name = "Enneagon"
    end

    return Curve2.new(true, kns, name)
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
function Curve2.rect(
    lbx, lby, ubx, uby,
    tl, tr, br, bl)

    -- Validate corners.
    local lft = math.min(lbx, ubx)
    local rgt = math.max(lbx, ubx)
    local btm = math.min(lby, uby)
    local top = math.max(lby, uby)

    -- Validate corner insetting.
    local limit = 0.5 * math.min(rgt - lft, top - btm)
    local vtl = 0.000001
    if tl then
        vtl = math.min(limit, math.max(0.000001, math.abs(tl)))
    end

    -- If only one corner arg is provided, then
    -- set them all to that corner.
    local vtr = vtl
    local vbr = vtl
    local vbl = vtl
    if tr and br and bl then
        vtr = math.min(limit, math.max(0.000001, math.abs(tr)))
        vbr = math.min(limit, math.max(0.000001, math.abs(br)))
        vbl = math.min(limit, math.max(0.000001, math.abs(bl)))
    end

    -- Calculate insets.
    local btmIns0 = btm + vbr
    local topIns0 = top - vtr
    local rgtIns0 = rgt - vtr
    local lftIns0 = lft + vtl
    local topIns1 = top - vtl
    local btmIns1 = btm + vbl
    local lftIns1 = lft + vbl
    local rgtIns1 = rgt - vbr

    local t = 0.3333333333333333
    local u = 0.6666666666666667

    -- Bottom edge.
    local k7 = Knot2.new(
        Vec2.new(lftIns1, btm),
        Vec2.new(u * lftIns1 + t * rgtIns1, btm),
        Vec2.new(0.0, 0.0))
    local k0 = Knot2.new(
        Vec2.new(rgtIns1, btm),
        Vec2.new(0.0, 0.0),
        Vec2.new(u * rgtIns1 + t * lftIns1, btm))

    -- Right edge.
    local k1 = Knot2.new(
        Vec2.new(rgt, btmIns0),
        Vec2.new(rgt, u * btmIns0 + t * topIns0),
        Vec2.new(0.0, 0.0))
    local k2 = Knot2.new(
        Vec2.new(rgt, topIns0),
        Vec2.new(0.0, 0.0),
        Vec2.new(rgt, u * topIns0 + t * btmIns0))

    -- Top edge.
    local k3 = Knot2.new(
        Vec2.new(rgtIns0, top),
        Vec2.new(u * rgtIns0 + t * lftIns0, top),
        Vec2.new(0.0, 0.0))
    local k4 = Knot2.new(
        Vec2.new(lftIns0, top),
        Vec2.new(0.0, 0.0),
        Vec2.new(u * lftIns0 + t * rgtIns0, top))

    -- Left edge.
    local k5 = Knot2.new(
        Vec2.new(lft, topIns1),
        Vec2.new(lft, u * topIns1 + t * btmIns1),
        Vec2.new(0.0, 0.0))
    local k6 = Knot2.new(
        Vec2.new(lft, btmIns1),
        Vec2.new(0.0, 0.0),
        Vec2.new(lft, u * btmIns1 + t * topIns1))

    local rgt23 = u * rgt
    local btm23 = u * btm
    local top23 = u * top
    local lft23 = u * lft

    local rgt13 = t * rgt
    local btm13 = t * btm
    local top13 = t * top
    local lft13 = t * lft

    -- Bottom Right corner.
    local k0fh = k0.fh
    local k1rh = k1.rh
    if br > 0.0 then
        k0fh.x = t * rgtIns1 + rgt23
        k0fh.y = btm
        k1rh.x = rgt
        k1rh.y = t * btmIns0 + btm23
    else
        k0fh.x = rgtIns1
        k0fh.y = btm13 + u * btmIns0
        k1rh.x = rgt13 + u * rgtIns1
        k1rh.y = btmIns0
    end

    -- Top Right corner.
    local k2fh = k2.fh
    local k3rh = k3.rh
    if tr > 0.0 then
        k2fh.x = rgt
        k2fh.y = t * topIns0 + top23
        k3rh.x = t * rgtIns0 + rgt23
        k3rh.y = top
    else
        k2fh.x = rgt13 + u * rgtIns0
        k2fh.y = topIns0
        k3rh.x = rgtIns0
        k3rh.y = top13 + u * topIns0
    end

    -- Top Left corner.
    local k4fh = k4.fh
    local k5rh = k5.rh
    if tl > 0.0 then
        k4fh.x = t * lftIns0 + lft23
        k4fh.y = top
        k5rh.x = lft
        k5rh.y = t * topIns1 + top23
    else
        k4fh.x = lftIns0
        k4fh.y = top13 + u * topIns1
        k5rh.x = lft13 + u * lftIns0
        k5rh.y = topIns1
    end

    -- Bottom Left corner.
    local k6fh = k6.fh
    local k7rh = k7.rh
    if bl > 0.0 then
        k6fh.x = lft
        k6fh.y = t * btmIns1 + btm23
        k7rh.x = t * lftIns1 + lft23
        k7rh.y = btm
    else
        k6fh.x = lft13 + u * lftIns1
        k6fh.y = btmIns1
        k7rh.x = lftIns1
        k7rh.y = btm13 + u * btmIns1
    end

    return Curve2.new(true, {
        k0, k1, k2, k3, k4, k5, k6, k7
        }, "Rectangle")
end

---Returns a JSON string of a curve.
---@param c table curve
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
    for i = 1, knsLen, 1 do
        strArr[i] = Knot2.toJson(kns[i])
    end

    str = str .. table.concat(strArr, ",")
    str = str .. "]}"
    return str
end

return Curve2