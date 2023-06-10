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

---Calculates the arc length of a curve. Does so
---by creating a number of sampled points, then
---accumulating the lengths between a current and
---previous point. Returns the summed length and
---an array of cumulative lengths
---@param curve Curve2 curve
---@param sampleCount number sample count
---@return number totalLength curve length
---@return number[] arcLengths cumulative lengths
function Curve2.arcLength(curve, sampleCount)
    --https://openprocessing.org/sketch/669242
    local countVrf = sampleCount or 256
    countVrf = math.max(1, countVrf)
    local countVrfp1 = countVrf + 1
    local hToFac = 1.0 / countVrf

    ---@type Vec2[]
    local points = {}

    local h = 0
    while h < countVrfp1 do
        local hFac = h * hToFac
        h = h + 1
        points[h] = Curve2.eval(curve, hFac)
    end

    ---@type number[]
    local arcLengths = {}
    local totalLength = 0.0
    local i = 1
    while i < countVrfp1 do
        local prev = points[i]
        local curr = points[i + 1]
        local d = Vec2.dist(curr, prev)
        totalLength = totalLength + d
        arcLengths[i] = totalLength
        i = i + 1
    end
    return totalLength, arcLengths
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

---Creates an array containing points on a
---polyline that are approximately equidistant.
---Depends on the results of the arcLength method.
---@param curve Curve2 curve
---@param totalLength number curve length
---@param arcLengths number[] cumulative lengths
---@param sampleCount integer? sample count
---@return Vec2[]
function Curve2.paramPoints(
    curve,
    totalLength,
    arcLengths,
    sampleCount)
    local countVrf = sampleCount or 256
    countVrf = math.max(1, countVrf)

    ---@type Vec2[]
    local result = {}
    local cl = curve.closedLoop
    local first = 2
    if cl then first = 1 end
    local toLength = totalLength / sampleCount
    local lenArcLengths = #arcLengths
    local toParam = 1.0 / (lenArcLengths - 1)

    if not cl then
        result[1] = Curve2.evalFirst(curve)
    end

    local i = first
    while i < countVrf do
        local request = i * toLength

        -- This cannot use utilities method as
        -- that would create a circular dependency.
        local low = 0
        local high = lenArcLengths
        if high >= 1 then
            while low < high do
                local middle = (low + high) // 2
                local right = arcLengths[1 + middle]
                if right and request < right then
                    high = middle
                else
                    low = middle + 1
                end
            end
        end

        local param = low * toParam
        local point = Curve2.eval(curve, param)
        result[#result + 1] = point

        i = i + 1
    end

    if not cl then
        result[#result + 1] = Curve2.evalLast(curve)
    end

    return result
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