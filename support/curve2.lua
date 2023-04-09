dofile("./knot2.lua")

---@class Curve2
---@field public closedLoop boolean closed loop
---@field public knots Knot2[] knots
---@field public name string name
---@operator len(): integer
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
---@param name string? name
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

---Creates a curve to approximate an ellipse.
---The radii default to 0.5.
---The origin defaults to (0.0, 0.0).
---@param xRadius number? horizontal radius
---@param yRadius number? vertical radius
---@param xOrigin number? x origin
---@param yOrigin number? y origin
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
