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
---@param name? string name
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

---Creates an array of curves that contain a hexagon grid.
---@param rings integer number of rings
---@param cellRadius number radius of each hexagon cell
---@param cellMargin number margin between each hexagon cell
---@param rounding number percentage by which to round corners
---@return Curve2[]
function Curve2.gridHex(rings, cellRadius, cellMargin, rounding)
    local verifRings <const> = rings > 1 and rings or 1
    local verifRad <const> = math.max(0.000001, cellRadius or 0.5)
    local verifMargin <const> = math.max(0.0, cellMargin or 0.0)
    local verifRounding <const> = rounding or 0.0

    local isStraight <const> = verifRounding <= 0.0
    local isCircle <const> = verifRounding >= 1.0
    local sqrt3 <const> = 1.7320508075688772
    local extent <const> = sqrt3 * verifRad
    local rad1_5 <const> = verifRad * 1.5
    local padRad <const> = math.max(0.000001, verifRad - verifMargin)
    local halfExt <const> = extent * 0.5
    local halfRad <const> = padRad * 0.5
    local radRt3_2 <const> = sqrt3 * halfRad
    local oneThird <const> = 1.0 / 3.0
    local iMax <const> = verifRings - 1
    local iMin <const> = -iMax

    local k <const> = 0.5522847498307936 -- 1.0 / (3.0 ^ 0.5)
    local handleFac <const> = k * 1.1547005383792515

    ---@type Curve2[]
    local curves <const> = {}
    local lenCurves = 0

    local i = iMin - 1
    while i < iMax do
        i = i + 1
        local jMin = iMin
        local jMax = iMax
        if i < 0 then jMin = jMin - i end
        if i > 0 then jMax = jMax - i end
        local iExt <const> = i * extent

        local j = jMin - 1
        while j < jMax do
            j = j + 1
            local x <const> = iExt + j * halfExt
            local y <const> = j * rad1_5

            local left <const> = x - radRt3_2
            local right <const> = x + radRt3_2
            local top <const> = y + halfRad
            local bottom <const> = y - halfRad

            ---@type Vec2[]
            local vs <const> = {
                Vec2.new(x, y + padRad),
                Vec2.new(left, top),
                Vec2.new(left, bottom),
                Vec2.new(x, y - padRad),
                Vec2.new(right, bottom),
                Vec2.new(right, top)
            }

            ---@type Knot2[]
            local kns <const> = {}
            if isStraight then
                local idxCurr = 0
                while idxCurr < 6 do
                    local idxPrev <const> = (idxCurr - 1) % 6
                    local idxNext <const> = (idxCurr + 1) % 6

                    local vPrev <const> = vs[1 + idxPrev]
                    local vCurr <const> = vs[1 + idxCurr]
                    local vNext <const> = vs[1 + idxNext]

                    kns[1 + idxCurr] = Knot2.new(
                        vCurr,
                        Vec2.mixNum(vCurr, vNext, oneThird),
                        Vec2.mixNum(vCurr, vPrev, oneThird))

                    idxCurr = idxCurr + 1
                end
            else
                ---@type Vec2[]
                local midPoints <const> = {}
                local mpIdx = 0
                while mpIdx < 6 do
                    local mpIdxNext <const> = (mpIdx + 1) % 6
                    local vCurr <const> = vs[1 + mpIdx]
                    local vNext <const> = vs[1 + mpIdxNext]
                    midPoints[1 + mpIdx] = Vec2.mixNum(vCurr, vNext, 0.5)

                    mpIdx = mpIdx + 1
                end

                if isCircle then
                    local knIdxCurr = 0
                    while knIdxCurr < 6 do
                        local vIdxNext <const> = (knIdxCurr + 1) % 6
                        local vPrev <const> = vs[1 + knIdxCurr]
                        local vNext <const> = vs[1 + vIdxNext]
                        local co <const> = midPoints[1 + knIdxCurr]

                        kns[1 + knIdxCurr] = Knot2.new(
                            co,
                            Vec2.mixNum(co, vNext, handleFac),
                            Vec2.mixNum(co, vPrev, handleFac))

                        knIdxCurr = knIdxCurr + 1
                    end
                else
                    local knIdxCurr = 0
                    while knIdxCurr < 12 do
                        local vIdxCurr <const> = knIdxCurr // 2
                        local vIdxPrev <const> = (vIdxCurr - 1) % 6
                        local vIdxNext <const> = (vIdxCurr + 1) % 6

                        local vCurr <const> = vs[1 + vIdxCurr]
                        local vPrev <const> = vs[1 + vIdxPrev]
                        local vNext <const> = vs[1 + vIdxNext]

                        local mpCurr <const> = midPoints[1 + vIdxCurr]
                        local mpPrev <const> = midPoints[1 + vIdxPrev]

                        local isEven <const> = knIdxCurr % 2 ~= 1
                        if isEven then
                            local coCurr <const> = Vec2.mixNum(vCurr, mpPrev, verifRounding)
                            local coPrev <const> = Vec2.mixNum(vPrev, mpPrev, verifRounding)
                            kns[1 + knIdxCurr] = Knot2.new(
                                coCurr,
                                Vec2.mixNum(coCurr, vCurr, handleFac),
                                Vec2.mixNum(coCurr, coPrev, oneThird))
                        else
                            local coCurr <const> = Vec2.mixNum(vCurr, mpCurr, verifRounding)
                            local coNext <const> = Vec2.mixNum(vNext, mpCurr, verifRounding)
                            kns[1 + knIdxCurr] = Knot2.new(
                                coCurr,
                                Vec2.mixNum(coCurr, coNext, oneThird),
                                Vec2.mixNum(coCurr, vCurr, handleFac))
                        end

                        knIdxCurr = knIdxCurr + 1
                    end
                end
            end

            local curve <const> = Curve2.new(true, kns, "Hexagon")
            lenCurves = lenCurves + 1
            curves[lenCurves] = curve
        end
    end

    return curves
end

---Creates an array containing points on a polyline that are approximately
---equidistant. Depends on the results of the arcLength method.
---@param curve Curve2 curve
---@param totalLength number curve length
---@param arcLengths number[] cumulative lengths
---@param sampleCount? integer sample count
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