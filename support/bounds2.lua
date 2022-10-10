dofile("./vec2.lua")

---@class Bounds2
---@field mn Vec2 lower bound
---@field mx Vec2 upper bound
Bounds2 = {}
Bounds2.__index = Bounds2

setmetatable(Bounds2, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new axis aligned bounding box
---(AABB) for a 2D area, represented by a
---minimum and maximum coordinate.
---Defaults to passing vectors by value.
---@param mn Vec2|number lower bound
---@param mx Vec2|number upper bound
---@return Bounds2
function Bounds2.new(mn, mx)
    return Bounds2.newByVal(mn, mx)
end

---Constructs a new axis aligned bounding box
---(AABB) for a 2D area, represented by a
---minimum and maximum coordinate. Vectors
---are assigned by reference.
---@param mn Vec2 lower bound
---@param mx Vec2 upper bound
---@return Bounds2
function Bounds2.newByRef(mn, mx)
    local inst = setmetatable({}, Bounds2)
    inst.mn = mn or Vec2.new(-0.5, -0.5)
    inst.mx = mx or Vec2.new(0.5, 0.5)
    return inst
end

---Constructs a new axis aligned bounding box
---(AABB) for a 2D area, represented by a
---minimum and maximum coordinate. Vectors
---are copied by value.
---@param mn Vec2|number lower bound
---@param mx Vec2|number upper bound
---@return Bounds2
function Bounds2.newByVal(mn, mx)
    local inst = setmetatable({}, Bounds2)

    inst.mn = nil
    if mn then
        if type(mn) == "number" then
            inst.mn = Vec2.new(mn, mn)
        else
            inst.mn = Vec2.new(mn.x, mn.y)
        end
    else
        inst.mn = Vec2.new(-0.5, -0.5)
    end

    inst.mx = nil
    if mx then
        if type(mx) == "number" then
            inst.mx = Vec2.new(mx, mx)
        else
            inst.mx = Vec2.new(mx.x, mx.y)
        end
    else
        inst.mx = Vec2.new(0.5, 0.5)
    end

    return inst
end

function Bounds2:__le(b)
    return Bounds2.center(self) <= Bounds2.center(b)
end

function Bounds2:__lt(b)
    return Bounds2.center(self) < Bounds2.center(b)
end

function Bounds2:__tostring()
    return Bounds2.toJson(self)
end

---Returns true if the bounds minimum and
---maximum corner are unequal in all three
---dimensions; i.e., the bounds is valid.
---@param b Bounds2 bounds
---@return boolean
function Bounds2.all(b)
    local mn = b.mn
    local mx = b.mx
    return math.abs(mx.x - mn.x) > 0.000001
        and math.abs(mx.y - mn.y) > 0.000001
end

---Returns true if the bounds minimum and
---maximum corner are unequal in at least
---one dimension.
---@param b Bounds2 bounds
---@return boolean
function Bounds2.any(b)
    local mn = b.mn
    local mx = b.mx
    return math.abs(mx.x - mn.x) > 0.000001
        or math.abs(mx.y - mn.y) > 0.000001
end

---Finds the center of a bounding box.
---Returns a Vec2.
---@param b Bounds2 bounds
---@return Vec2
function Bounds2.center(b)
    return Vec2.mixNum(b.mn, b.mx, 0.5)
end

---Evaluates whether a point is within the
---bounds, lower bounds inclusive, upper
---bounds exclusive.
---@param b Bounds2 bounds
---@param pt Vec2 point
---@return boolean
function Bounds2.containsInclExcl(b, pt)
    local mn = b.mn
    local mx = b.mx
    return (pt.x >= mn.x and pt.x < mx.x)
        and (pt.y >= mn.y and pt.y < mx.y)
end

---Finds the extent of the bounds.
---Returns a Vec2 representing a
---non uniform scale.
---@param b Bounds2 bounds
---@return Vec2
function Bounds2.extent(b)
    return Vec2.diff(b.mx, b.mn)
end

---Creates a bounding box from a center
---and an extent.
---@param center Vec2 center
---@param extent Vec2 extent
---@return Bounds2
function Bounds2.fromCenterExtent(center, extent)
    local halfExtent = Vec2.scale(extent, 0.5)
    return Bounds2.newByRef(
        Vec2.sub(center, halfExtent),
        Vec2.add(center, halfExtent))
end

---Creates a bounding box that encompasses
---a table of Vec2s.
---@param points table points
---@return Bounds2
function Bounds2.fromPoints(points)
    local len = #points
    if len < 1 then
        return Bounds2.unitSquareSigned()
    end

    local lbx = 2147483647
    local lby = 2147483647

    local ubx = -2147483648
    local uby = -2147483648

    local i = 0
    while i < len do
        i = i + 1
        local p = points[i]

        if p.x < lbx then lbx = p.x end
        if p.x > ubx then ubx = p.x end
        if p.y < lby then lby = p.y end
        if p.y > uby then uby = p.y end
    end

    return Bounds2.newByRef(
        Vec2.new(
            lbx - 0.000002,
            lby - 0.000002),
        Vec2.new(
            ubx + 0.000002,
            uby + 0.000002))
end

---Evaluates whether two bounding volumes intersect.
---@param a Bounds2 left comparisand
---@param b Bounds2 right comparisand
---@return boolean
function Bounds2.intersectsBounds(a, b)
    return a.mx.y > b.mn.y
        or a.mn.y < b.mx.y
        or a.mx.x > b.mn.x
        or a.mn.x < b.mx.x
end

---Evaluates whether a bounding box intersects
---a circle.
---@param a Bounds2 bounds
---@param center Vec2 circle center
---@param radius number circle radius
---@return boolean
function Bounds2.intersectsCircle(a, center, radius)
    return Bounds2.intersectsCircleInternal(
        a, center, radius * radius)
end

---Evaluates whether a bounding box intersects
---a circle. Internal helper function for quadtrees,
---as it assumes that the squared-radius has already
---been calculated.
---@param a Bounds2 bounds
---@param center Vec2 circle center
---@param rsq number circle radius, squared
---@return boolean
function Bounds2.intersectsCircleInternal(a, center, rsq)
    local xd = 0.0
    if center.x < a.mn.x then
        xd = center.x - a.mn.x
    elseif center.x > a.mx.x then
        xd = center.x - a.mx.x
    end

    local yd = 0.0
    if center.y < a.mn.y then
        yd = center.y - a.mn.y
    elseif center.y > a.mx.y then
        yd = center.y - a.mx.y
    end

    return (xd * xd + yd * yd) < rsq
end

---Returns true if the bounds minimum and
---maximum corner are approximately equal,
---i.e., the bounds has no area.
---@param b Bounds2 bounds
---@return boolean
function Bounds2.none(b)
    return Vec2.approx(b.mn, b.mx, 0.000001);
end

---Splits a bounding box into quadrants
---according to two factors in the range
---[0.0, 1.0]. The factor on the x axis
---governs the vertical split. On the y axis,
---the horizontal split.
---@param b Bounds2 bounds
---@param xFac number vertical factor
---@param yFac number horizontal factor
---@param sw Bounds2 south west quadrant
---@param se Bounds2 south east quadrant
---@param nw Bounds2 north west quadrant
---@param ne Bounds2 north east quadrant
function Bounds2.splitInternal(b, xFac, yFac, sw, se, nw, ne)
    local bMn = b.mn
    local bMx = b.mx

    local x = (1.0 - xFac) * bMn.x + xFac * bMx.x
    local y = (1.0 - yFac) * bMn.y + yFac * bMx.y

    sw.mn = Vec2.new(bMn.x, bMn.y)
    se.mn = Vec2.new(x, bMn.y)
    nw.mn = Vec2.new(bMn.x, y)
    ne.mn = Vec2.new(x, y)

    sw.mx = Vec2.new(x, y)
    se.mx = Vec2.new(bMx.x, y)
    nw.mx = Vec2.new(x, bMx.y)
    ne.mx = Vec2.new(bMx.x, bMx.y)
end

---Returns a JSON string of the bounds.
---@param b Bounds2 bounds
---@return string
function Bounds2.toJson(b)
    return "{\"mn\":"
        .. Vec2.toJson(b.mn)
        .. ",\"mx\":"
        .. Vec2.toJson(b.mx)
        .. "}"
end

---Returns a bounds containing a signed
---unit square in Cartesian coordinates, from
---[-1.0, 1.0].
---@return Bounds2
function Bounds2.unitSquareSigned()
    return Bounds2.newByRef(
        Vec2.new(-1.000002, -1.000002),
        Vec2.new(1.000002, 1.000002))
end

---Returns a bounds containing an unsigned
---unit square in Cartesian coordinates, from
---[0.0, 1.0].
---@return Bounds2
function Bounds2.unitSquareUnsigned()
    return Bounds2.newByRef(
        Vec2.new(-0.000002, -0.000002),
        Vec2.new(1.000002, 1.000002))
end

return Bounds2
