dofile("./knot3.lua")

Curve3 = {}
Curve3.__index = Curve3

setmetatable(Curve3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new vector from two numbers.
---@param cl boolean closed loop
---@param knots number knots
---@param name string name
---@return table
function Curve3.new(cl, knots, name)
    local inst = setmetatable({}, Curve3)
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

---Rotates this curve around the x axis by
---an angle in radians.
---@param radians number angle
---@return table
function Curve3:rotateX(radians)
    return self:rotateXInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the x axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Curve3:rotateXInternal(cosa, sina)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:rotateXInternal(cosa, sina)
    end
    return self
end

---Rotates this curve around the y axis by
---an angle in radians.
---@param radians number angle
---@return table
function Curve3:rotateY(radians)
    return self:rotateYInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the y axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Curve3:rotateYInternal(cosa, sina)
    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        self.knots[i]:rotateYInternal(cosa, sina)
    end
    return self
end

---Rotates this curve around the z axis by
---an angle in radians.
---@param radians number angle
---@return table
function Curve3:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this curve around the z axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Curve3:rotateZInternal(cosa, sina)
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
function Curve3:scale(v)
    return self:scaleVec3(v)
end

---Scales this curve by a number.
---@param n table uniform scalar
---@return table
function Curve3:scaleNum(n)
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
function Curve3:scaleVec3(v)
    if Vec3.all(v) then
        local knsLen = #self.knots
        for i = 1, knsLen, 1 do
            self.knots[i]:scaleVec3(v)
        end
    end
    return self
end

---Translates this curve by a vector.
---@param v table vector
---@return table
function Curve3:translate(v)
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
function Curve3.eval(curve, step)
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
            return Curve3.evalFirst(curve)
        end

        if t >= 1.0 then
            return Curve3.evalLast(curve)
        end

        tScaled = t * (knotLength - 1)
        i = math.tointeger(tScaled)
        a = knots[1 + i]
        b = knots[2 + i]

    end

    -- Eval tangent as well, return table?
    -- Or rename to evalPoint and make separate
    -- function for tangent?
    local tsni = tScaled - i
    return Knot3.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot,
---returning a copy of the first knot coord.
---@param curve table the curve
---@return table
function Curve3.evalFirst(curve)
    local kFirst = curve.knots[1]
    return Vec3.new(
        kFirst.co.x,
        kFirst.co.y,
        kFirst.co.z)
end

---Evaluates a curve at its last knot,
---returning a copy of the last knot coord.
---@param curve table the curve
---@return table
function Curve3.evalLast(curve)
    local kLast = curve.knots[#curve.knots]
    return Vec3.new(
        kLast.co.x,
        kLast.co.y,
        kLast.co.z)
end

---Converts a set of points on a Catmull-Rom spline
---to a Bezier curve. The default tightness is 0.0.
---There must be at least 4 points in the array.
---@param closedLoop boolean closed loop flag
---@param points table array of points
---@param tightness number curve tightness
---@return table
function Curve3.fromCatmull(closedLoop, points, tightness)

    local ptsLen = #points
    if ptsLen < 2 then
        return Curve3.new()
    elseif ptsLen < 3 then
        return Curve3.fromCatmull(false, {
            points[1], points[1],
            points[2], points[2]
        }, tightness)
    elseif ptsLen < 4 then
        return Curve3.fromCatmull(false, {
            points[1], points[1],
            points[2],
            points[3], points[3]
        }, tightness)
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
        for i = 1, #points, 1 do
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

    local kns = {}
    local firstKnot = Knot3.new(
        valPts[2],
        valPts[2],
        valPts[2])
    kns[1] = firstKnot

    local valTight = tightness or 0.0
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

        local nextKnot = Knot3.new(
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

    return Curve3.new(closedLoop, kns, "Curve3")
end

---Creates a curve from a series of points.
---Smoothes the fore and rear handles of knots.
---@param closedLoop boolean closed loop
---@param points table points array
---@return table
function Curve3.fromPoints(closedLoop, points)
    local kns = {}

    local valPts = points
    if closedLoop
        and Vec3.approx(
            points[1],
            points[#points]) then

        valPts = {}
        for i = 1, #points - 1, 1 do
            valPts[i] = points[i]
        end
    end

    --TODO: Use knot from line seg instead?
    local len = #valPts
    for i = 1, len, 1 do
        local pt = valPts[i]
        kns[i] = Knot3.new(Vec3.new(pt.x, pt.y, pt.z))
    end
    local crv = Curve3.new(closedLoop, kns, "Curve3")
    Curve3.smoothHandles(crv)
    return crv
end

---Adjusts knot handles so as to create
---a smooth, continuous curve.
---@param target table
function Curve3.smoothHandles(target)
    local knots = target.knots
    local knotLength = #knots
    if knotLength < 3 then return target end

    local carry = Vec3.new(0.0, 0.0, 0.0)
    local first = knots[1]

    if target.closedLoop then
        local prev = knots[knotLength]
        local curr = first
        for i = 2, knotLength, 1 do
            local next = knots[i]
            Knot3.smoothHandlesInternal(
                prev, curr, next, carry)
            prev = curr
            curr = next
        end
        Knot3.smoothHandlesInternal(
            prev, curr, first, carry)
    else
        local prev = first
        local curr = knots[2]

        Knot3.smoothHandlesFirstInternal(
            prev, curr, carry)
        Knot3.mirrorHandlesForward(curr)

        for i = 3, knotLength, 1 do
            local next = knots[i]
            Knot3.smoothHandlesInternal(
                prev, curr, next, carry)
            prev = curr
            curr = next
        end

        Knot3.smoothHandlesLastInternal(
            prev, curr, carry)
        Knot3.mirrorHandlesBackward(curr)
    end

    return target
end

---Returns a JSON string of a curve.
---@param c table curve
---@return string
function Curve3.toJson(c)
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
    for i = 1, knsLen, 1 do
        str = str .. Knot3.toJson(kns[i])
        if i < knsLen then str = str .. "," end
    end

    str = str .. "]}"
    return str
end

return Curve3