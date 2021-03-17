dofile("./knot2.lua")

Curve2 = {}
Curve2.__index = Curve2

setmetatable(Curve2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new vector from two numbers.
---@param cl number closed loop
---@param knots number knots
---@return table
function Curve2.new(cl, knots, name)
    local inst = {}
    setmetatable(inst, Curve2)
    inst.closedLoop = cl or false
    inst.knots = knots or {}
    inst.name = name or "Curve2"
    return inst
end

function Curve2:__len()
    return #self.knots
end

function Curve2:__tostring()
    local str = "{ name: \""
    str = str .. self.name
    str = str .. "\", closedLoop: "
    if self.closedLoop then
        str = str .. "true"
    else
        str = str .. "false"
    end
    str = str .. ", knots: [ "

    local knsLen = #self.knots
    for i = 1, knsLen, 1 do
        str = str .. tostring(self.knots[i])
        if i < knsLen then str = str .. ", " end
    end

    str = str .. " ] }"
    return str
end

---Gets the first knot in the curve.
---@return table
function Curve2:getFirst()
    return self.knots[1]
end

---Gets the last knot in the curve.
---@return table
function Curve2:getLast()
    return self.knots[#self.knots]
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

    local tsni = tScaled - i
    return Knot2.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot,
---returning a copy of the first knot coord.
---@param curve table the curve
---@return table
function Curve2.evalFirst(curve)
    local kFirst = curve.knots[1]
    return Vec2.new(kFirst.co.x, kFirst.co.y)
end

---Evaluates a curve at its last knot,
---returning a copy of the last knot coord.
---@param curve table the curve
---@return table
function Curve2.evalLast(curve)
    local kLast = curve.knots[#curve.knots]
    return Vec2.new(kLast.co.x, kLast.co.y)
end

return Curve2