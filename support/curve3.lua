dofile("./knot3.lua")

---@class Curve3
---@field public closedLoop boolean closed loop
---@field public knots Knot3[] knots
---@field public name string name
---@operator len(): integer
Curve3 = {}
Curve3.__index = Curve3

setmetatable(Curve3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a piecewise cubic Bezier curve. The first parameter specifies a
---closed loop if true. The second parameter should be a table of Knot3s.
---@param cl boolean closed loop
---@param knots Knot3[] knots
---@param name string? name
---@return Curve3
---@nodiscard
function Curve3.new(cl, knots, name)
    local inst <const> = setmetatable({}, Curve3)
    inst.closedLoop = cl or false
    inst.knots = knots or {}
    inst.name = name or "Curve3"
    return inst
end

function Curve3:__len()
    return #self.knots
end

function Curve3:__tostring()
    return Curve3.toJson(self)
end

---Evaluates a curve by a step in [0.0, 1.0]. Returns a vector representing a
---point on the curve.
---@param curve Curve3 curve
---@param step number step
---@return Vec3
---@nodiscard
function Curve3.eval(curve, step)
    local t <const> = step or 0.5
    local knots <const> = curve.knots
    local knotLength <const> = #knots
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
            return Curve3.evalFirst(curve)
        end

        if t >= 1.0 then
            return Curve3.evalLast(curve)
        end

        tScaled = t * (knotLength - 1)
        i = math.floor(tScaled)
        a = knots[1 + i]
        b = knots[2 + i]
    end

    local tsni <const> = tScaled - i
    return Knot3.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot, returns a copy of the first knot coord.
---@param curve Curve3 curve
---@return Vec3
---@nodiscard
function Curve3.evalFirst(curve)
    local kFirst <const> = curve.knots[1]
    local coFirst <const> = kFirst.co
    return Vec3.new(
        coFirst.x,
        coFirst.y,
        coFirst.z)
end

---Evaluates a curve at its last knot, returns a copy of the last knot coord.
---@param curve Curve3 curve
---@return Vec3
---@nodiscard
function Curve3.evalLast(curve)
    local kLast <const> = curve.knots[#curve.knots]
    local coLast <const> = kLast.co
    return Vec3.new(
        coLast.x,
        coLast.y,
        coLast.z)
end

---Converts a set of points on a Catmull-Rom spline to a Bezier curve. The
---default tightness is 0.0. There must be at least 4 points in the array.
---@param closedLoop boolean closed loop flag
---@param points Vec3[] array of points
---@param tightness number? curve tightness
---@param name string? curve name
---@return Curve3
---@nodiscard
function Curve3.fromCatmull(closedLoop, points, tightness, name)
    local ptsLen = #points
    if ptsLen < 2 then
        return Curve3.new(false, {}, name)
    elseif ptsLen < 3 then
        return Curve3.fromCatmull(false, {
            points[1], points[1],
            points[2], points[2]
        }, tightness, name)
    elseif ptsLen < 4 then
        return Curve3.fromCatmull(false, {
            points[1], points[1],
            points[2],
            points[3], points[3]
        }, tightness, name)
    end

    local ptsLast = ptsLen - 1
    local knotCount = 0

    local valPts = points
    if closedLoop then
        if Vec3.approx(
                points[1],
                points[ptsLen]) then
            valPts = {}
            for i = 1, ptsLast, 1 do
                valPts[i] = points[i]
            end

            ptsLen = #valPts
            ptsLast = ptsLen - 1
        end

        knotCount = ptsLen
    else
        valPts = {}
        local oldLen <const> = #points
        local i = 0
        while i < oldLen do
            i = i + 1
            valPts[i] = points[i]
        end

        if not Vec3.approx(
                points[1],
                points[2]) then
            table.insert(valPts, 1, points[1])
        end

        if not Vec3.approx(
                points[#points],
                points[#points - 1]) then
            table.insert(valPts, points[#points])
        end

        ptsLen = #valPts
        ptsLast = ptsLen - 1
        knotCount = ptsLen - 2
    end

    ---@type Knot3[]
    local kns <const> = {}
    local firstKnot <const> = Knot3.new(
        valPts[2],
        valPts[2],
        valPts[2])
    kns[1] = firstKnot

    local valTight <const> = tightness or 0.0
    for i = 0, knotCount - 2, 1 do
        local i1 = i + 1
        local i2 = i + 2
        local i3 = i + 3

        if closedLoop then
            i1 = i1 % ptsLen
            i2 = i2 % ptsLen
            i3 = i3 % ptsLen
        elseif i3 > ptsLast then
            i3 = ptsLast
        end

        local nextKnot <const> = Knot3.new(
            valPts[1 + i2],
            valPts[1 + i2],
            valPts[1 + i2])
        kns[2 + i] = nextKnot

        Knot3.fromSegCatmull(
            valPts[1 + i],
            valPts[1 + i1],
            valPts[1 + i2],
            valPts[1 + i3],
            valTight,
            kns[1 + i],
            nextKnot)
    end

    if closedLoop then
        Knot3.fromSegCatmull(
            valPts[ptsLen],
            valPts[1],
            valPts[2],
            valPts[3],
            valTight,
            kns[#kns],
            firstKnot)
    else
        firstKnot.co = Vec3.new(
            valPts[2].x,
            valPts[2].y,
            valPts[2].z)
        firstKnot:mirrorHandlesForward()
        kns[#kns]:mirrorHandlesBackward()
    end

    return Curve3.new(closedLoop, kns, name)
end

---Creates a curve from a series of points. Smoothes the fore and rear handles
---of knots.
---@param closedLoop boolean closed loop
---@param points Vec3[] points array
---@param name string? curve name
---@return Curve3
---@nodiscard
function Curve3.fromPoints(closedLoop, points, name)
    -- If a closed loop has similar start and
    -- stop points, then skip the last point.
    local len <const> = #points
    local last = len
    if closedLoop and Vec3.approx(
            points[1], points[len]) then
        last = len - 1
    end

    ---@type Knot3[]
    local kns <const> = {}
    local i = 0
    while i < last do
        i = i + 1
        local pt <const> = points[i]
        kns[i] = Knot3.new(
            Vec3.new(pt.x, pt.y, pt.z),
            Vec3.new(pt.x, pt.y, pt.z),
            Vec3.new(pt.x, pt.y, pt.z))
    end

    local crv <const> = Curve3.new(closedLoop, kns, name)
    if len < 3 then
        return Curve3.straightHandles(crv)
    else
        return Curve3.smoothHandles(crv)
    end
end

---Adjusts knot handles so as to create a smooth, continuous curve.
---@param target Curve3
---@return Curve3
function Curve3.smoothHandles(target)
    local knots <const> = target.knots
    local knotCount <const> = #knots
    if knotCount < 3 then return target end

    local carry = Vec3.new(0.0, 0.0, 0.0)
    local knFirst <const> = knots[1]

    if target.closedLoop then
        local knPrev = knots[knotCount]
        local knCurr = knFirst
        for i = 2, knotCount, 1 do
            local knNext <const> = knots[i]
            carry = Knot3.smoothHandlesInternal(
                knPrev, knCurr, knNext, carry)
            knPrev = knCurr
            knCurr = knNext
        end
        carry = Knot3.smoothHandlesInternal(
            knPrev, knCurr, knFirst, carry)
    else
        local knPrev = knFirst
        local knCurr = knots[2]

        carry = Knot3.smoothHandlesFirstInternal(
            knPrev, knCurr, carry)
        Knot3.mirrorHandlesForward(knCurr)

        for i = 3, knotCount, 1 do
            local knNext <const> = knots[i]
            carry = Knot3.smoothHandlesInternal(
                knPrev, knCurr, knNext, carry)
            knPrev = knCurr
            knCurr = knNext
        end

        carry = Knot3.smoothHandlesLastInternal(
            knPrev, knCurr, carry)
        Knot3.mirrorHandlesBackward(knCurr)
    end

    return target
end

---Straightens the fore and rear handles of a curve's knots so they are
---collinear with its coordinates.
---@param target Curve3
---@return Curve3
function Curve3.straightHandles(target)
    local knots <const> = target.knots
    local knotCount <const> = #knots
    if knotCount < 2 then return target end

    for i = 2, knotCount, 1 do
        local knPrev <const> = knots[i - 1]
        local knNext <const> = knots[i]
        knPrev.fh = Vec3.mixNum(
            knPrev.co, knNext.co,
            0.33333333333333)
        knNext.rh = Vec3.mixNum(
            knNext.co, knPrev.co,
            0.33333333333333)
    end

    local knFirst <const> = knots[1]
    local knLast <const> = knots[knotCount]
    if target.closedLoop then
        knFirst.rh = Vec3.mixNum(
            knFirst.co, knLast.co,
            0.33333333333333)
        knLast.fh = Vec3.mixNum(
            knLast.co, knFirst.co,
            0.33333333333333)
    else
        Knot3.mirrorHandlesForward(knFirst)
        Knot3.mirrorHandlesBackward(knLast)
    end

    return target
end

---Returns a JSON string of a curve.
---@param c Curve3 curve
---@return string
---@nodiscard
function Curve3.toJson(c)
    ---@type string[]
    local knotStrArr <const> = {}
    local kns <const> = c.knots
    local knsLen <const> = #kns
    local i = 0
    while i < knsLen do
        i = i + 1
        knotStrArr[i] = Knot3.toJson(kns[i])
    end

    return string.format(
        "{\"name\":\"%s\",\"closedLoop\":%s,\"knots\":[%s]}",
        c.name,
        c.closedLoop and "true" or "false",
        table.concat(knotStrArr, ","))
end

return Curve3