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

---Constructs a piecewise cubic Bezier curve. The first parameter specifies a
---closed loop if true. The second parameter should be a table of Knot2s.
---@param cl boolean closed loop
---@param knots Knot2[] knots
---@param name string? name
---@return Curve2
---@nodiscard
function Curve2.new(cl, knots, name)
    local inst <const> = setmetatable({}, Curve2)
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

---Calculates the arc length of a curve. Does so by creating a number of
---sampled points, then accumulating the lengths between a current and previous
---point. Returns the summed length and an array of cumulative lengths
---@param curve Curve2 curve
---@param sampleCount number sample count
---@return number totalLength curve length
---@return number[] arcLengths cumulative lengths
function Curve2.arcLength(curve, sampleCount)
    -- Old p5js implementation:
    -- https://openprocessing.org/sketch/669242
    local countVrf = sampleCount or 256
    countVrf = math.max(1, countVrf)
    local countVrfp1 <const> = countVrf + 1
    local hToFac <const> = 1.0 / countVrf

    ---@type Vec2[]
    local points <const> = {}

    local h = 0
    while h < countVrfp1 do
        local hFac <const> = h * hToFac
        h = h + 1
        points[h] = Curve2.eval(curve, hFac)
    end

    ---@type number[]
    local arcLengths <const> = {}
    local totLen = 0.0
    local i = 1
    while i < countVrfp1 do
        local prev <const> = points[i]
        local curr <const> = points[i + 1]
        totLen = totLen + Vec2.dist(curr, prev)
        arcLengths[i] = totLen
        i = i + 1
    end
    return totLen, arcLengths
end

---Evaluates a curve by a step in [0.0, 1.0]. Returns a vector representing a
---point on the curve.
---@param curve Curve2 curve
---@param step number step
---@return Vec2
---@nodiscard
function Curve2.eval(curve, step)
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

    local tsni <const> = tScaled - i
    return Knot2.bezierPoint(a, b, tsni)
end

---Evaluates a curve at its first knot, returns a copy of the first knot coord.
---@param curve Curve2 curve
---@return Vec2
---@nodiscard
function Curve2.evalFirst(curve)
    local kFirst <const> = curve.knots[1]
    local coFirst <const> = kFirst.co
    return Vec2.new(coFirst.x, coFirst.y)
end

---Evaluates a curve at its last knot, returns a copy of the last knot coord.
---@param curve Curve2 curve
---@return Vec2
---@nodiscard
function Curve2.evalLast(curve)
    local kLast <const> = curve.knots[#curve.knots]
    local coLast <const> = kLast.co
    return Vec2.new(coLast.x, coLast.y)
end

---Creates an array containing points on a polyline that are approximately
---equidistant. Depends on the results of the arcLength method.
---@param curve Curve2 curve
---@param totalLength number curve length
---@param arcLengths number[] cumulative lengths
---@param sampleCount integer? sample count
---@return Vec2[]
---@nodiscard
function Curve2.paramPoints(
    curve, totalLength,
    arcLengths, sampleCount)
    local countVrf = sampleCount or 256
    countVrf = math.max(1, countVrf)

    ---@type Vec2[]
    local result <const> = {}
    local cl <const> = curve.closedLoop
    local first = 2
    if cl then first = 1 end
    local toLength <const> = totalLength / sampleCount
    local lenArcLengths <const> = #arcLengths
    local toParam <const> = 1.0 / (lenArcLengths - 1)

    if not cl then
        result[1] = Curve2.evalFirst(curve)
    end

    local i = first
    while i < countVrf do
        local request <const> = i * toLength

        -- This cannot use utilities method as
        -- that would create a circular dependency.
        local low = 0
        local high = lenArcLengths
        if high >= 1 then
            while low < high do
                local middle <const> = (low + high) // 2
                local right <const> = arcLengths[1 + middle]
                if right and request < right then
                    high = middle
                else
                    low = middle + 1
                end
            end
        end

        local param <const> = low * toParam
        local point <const> = Curve2.eval(curve, param)
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
---@nodiscard
function Curve2.toJson(c)
    ---@type string[]
    local knotStrArr <const> = {}
    local kns <const> = c.knots
    local knsLen <const> = #kns
    local i = 0
    while i < knsLen do
        i = i + 1
        knotStrArr[i] = Knot2.toJson(kns[i])
    end

    return string.format(
        "{\"name\":\"%s\",\"closedLoop\":%s,\"knots\":[%s]}",
        c.name,
        c.closedLoop and "true" or "false",
        table.concat(knotStrArr, ","))
end

return Curve2