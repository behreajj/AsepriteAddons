dofile("./vec3.lua")

Bounds3 = {}
Bounds3.__index = Bounds3

setmetatable(Bounds3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new axis aligned bounding box
---(AABB) for a 3D volume, represented by a
---minimum and maximum coordinate.
---Defaults to passing vectors by value.
---@param mn table lower bound
---@param mx table upper bound
---@return table
function Bounds3.new(mn, mx)
    return Bounds3.newByVal(mn, mx)
end

---Constructs a new axis aligned bounding box
---(AABB) for a 3D volume, represented by a
---minimum and maximum coordinate. Vectors
---are assigned by reference.
---@param mn table lower bound
---@param mx table upper bound
---@return table
function Bounds3.newByRef(mn, mx)
    local inst = setmetatable({}, Bounds3)
    inst.mn = mn or Vec3.new(-0.5, -0.5, -0.5)
    inst.mx = mx or Vec3.new(0.5, 0.5, 0.5)
    return inst
end

---Constructs a new axis aligned bounding box
---(AABB) for a 3D volume, represented by a
---minimum and maximum coordinate. Vectors
---are copied by value.
---@param mn table lower bound
---@param mx table upper bound
---@return table
function Bounds3.newByVal(mn, mx)
    local inst = setmetatable({}, Bounds3)

    inst.mn = nil
    if mn then
        inst.mn = Vec3.new(mn.x, mn.y, mn.z)
    else
        inst.mn = Vec3.new(-0.5, -0.5, -0.5)
    end

    inst.mx = nil
    if mx then
        inst.mx = Vec3.new(mx.x, mx.y, mx.z)
    else
        inst.mx = Vec3.new(0.5, 0.5, 0.5)
    end

    return inst
end

function Bounds3:__le(b)
    return Bounds3.center(self) <= Bounds3.center(b)
end

function Bounds3:__lt(b)
    return Bounds3.center(self) < Bounds3.center(b)
end

function Bounds3:__tostring()
    return Bounds3.toJson(self)
end

---Returns true if the bounds minimum and
---maximum corner are unequal in all three
---dimensions; i.e., the bounds is valid.
---@param b table bounds
---@return boolean
function Bounds3.all(b)
    local mn = b.mn
    local mx = b.mx
    return math.abs(mx.x - mn.x) > 0.000001
       and math.abs(mx.y - mn.y) > 0.000001
       and math.abs(mx.z - mn.z) > 0.000001
end

---Returns true if the bounds minimum and
---maximum corner are unequal in at least
---one dimension.
---@param b table bounds
---@return boolean
function Bounds3.any(b)
    local mn = b.mn
    local mx = b.mx
    return math.abs(mx.x - mn.x) > 0.000001
       or math.abs(mx.y - mn.y) > 0.000001
       or math.abs(mx.z - mn.z) > 0.000001
end

---Finds the center of a bounding box.
---Returns a Vec3.
---@param b table bounds
---@return table
function Bounds3.center(b)
    return Vec3.mixNum(b.mn, b.mx, 0.5)
end

---Evaluates whether a point is within the
---bounds, lower bounds inclusive, upper
---bounds exclusive.
---@param b table bounds
---@param pt table point
---@return boolean
function Bounds3.containsInclExcl(b, pt)
    local mn = b.mn
    local mx = b.mx
    return (pt.x >= mn.x and pt.x < mx.x)
        and (pt.y >= mn.y and pt.y < mx.y)
        and (pt.z >= mn.z and pt.z < mx.z)
end

---Finds the extent of the bounds.
---Returns a Vec3 representing a
---non uniform scale.
---@param b table bounds
---@return table
function Bounds3.extent(b)
    return Vec3.diff(b.mx, b.mn)
end

---Creates a bounding box from a center
---and the volume's extent. Both the center
---and extent should be Vec3s.
---@param center table center
---@param extent table extent
---@return table
function Bounds3.fromCenterExtent(center, extent)
    local halfExtent = Vec3.scale(extent, 0.5)
    return Bounds3.newByRef(
        Vec3.sub(center, halfExtent),
        Vec3.add(center, halfExtent))
end

---Creates a bounding box that encompasses
---a table of Vec3s.
---@param points table points
---@return table
function Bounds3.fromPoints(points)
    local lbx = 2147483647
    local lby = 2147483647
    local lbz = 2147483647

    local ubx = -2147483648
    local uby = -2147483648
    local ubz = -2147483648

    local len = #points
    for i = 1, len, 1 do
        local p = points[i]

        if p.x < lbx then lbx = p.x end
        if p.x > ubx then ubx = p.x end
        if p.y < lby then lby = p.y end
        if p.y > uby then uby = p.y end
        if p.z < lbz then lbz = p.z end
        if p.z > ubz then ubz = p.z end
    end

    return Bounds3.newByRef(
        Vec3.new(
            lbx - 0.000002,
            lby - 0.000002,
            lbz - 0.000002),
        Vec3.new(
            ubx + 0.000002,
            uby + 0.000002,
            ubz + 0.000002))
end

---Evaluates whether two bounding volumes intersect.
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Bounds3.intersectsBounds(a, b)
    return a.mx.z > b.mn.z
        or a.mn.z < b.mx.z
        or a.mx.y > b.mn.y
        or a.mn.y < b.mx.y
        or a.mx.x > b.mn.x
        or a.mn.x < b.mx.x
end

---Evaluates whether a bounding box intersects
---a sphere. The sphere is defined as a Vec3 center
---and a number radius.
---@param a table bounds
---@param center table sphere center
---@param radius number sphere radius
---@return boolean
function Bounds3.intersectsSphere(a, center, radius)
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

    local zd = 0.0
    if center.z < a.mn.z then
        zd = center.z - a.mn.z
    elseif center.z > a.mx.z then
        zd = center.z - a.mx.z
    end

    return (xd * xd + yd * yd + zd * zd) < (radius * radius)
end

---Returns true if the bounds minimum and
---maximum corner are approximately equal,
---i.e., the bounds has no volume.
---@param b table bounds
---@return boolean
function Bounds3.none(b)
    return Vec3.approx(b.mn, b.mx, 0.000001);
end

---Splits a bounding box into octants
---according to three factors in the range
---[0.0, 1.0]. The factor on the x axis
---governs the vertical split. On the y axis,
---the horizontal split. On the z axis, the
---depth split.
---@param b table bounds
---@param xFac number vertical factor
---@param yFac number horizontal vector
---@param zFac number depth factor
---@param bsw table back south west octant
---@param bse table back south east octant
---@param bnw table back north west octant
---@param bne table back north east octant
---@param fsw table front south west octant
---@param fse table front south east octant
---@param fnw table front north west octant
---@param fne table front north east octant
---@return table
function Bounds3.splitInternal(
    b, xFac, yFac, zFac,
    bsw, bse, bnw, bne,
    fsw, fse, fnw, fne)

    local bMn = b.mn
    local bMx = b.mx

    local x = (1.0 - xFac) * bMn.x + xFac * bMx.x
    local y = (1.0 - yFac) * bMn.y + yFac * bMx.y
    local z = (1.0 - zFac) * bMn.z + zFac * bMx.z

    bsw.mn = Vec3.new(bMn.x, bMn.y, bMn.z)
    bse.mn = Vec3.new(    x, bMn.y, bMn.z)
    bnw.mn = Vec3.new(bMn.x,     y, bMn.z)
    bne.mn = Vec3.new(    x,     y, bMn.z)
    fsw.mn = Vec3.new(bMn.x, bMn.y,     z)
    fse.mn = Vec3.new(    x, bMn.y,     z)
    fnw.mn = Vec3.new(bMn.x,     y,     z)
    fne.mn = Vec3.new(    x,     y,     z)

    bsw.mx = Vec3.new(    x,     y,     z)
    bse.mx = Vec3.new(bMx.x,     y,     z)
    bnw.mx = Vec3.new(    x, bMx.y,     z)
    bne.mx = Vec3.new(bMx.x, bMx.y,     z)
    fsw.mx = Vec3.new(    x,     y, bMx.z)
    fse.mx = Vec3.new(bMx.x,     y, bMx.z)
    fnw.mx = Vec3.new(    x, bMx.y, bMx.z)
    fne.mx = Vec3.new(bMx.x, bMx.y, bMx.z)
end

---Returns a JSON string of the bounds.
---@param b table bounds
---@return string
function Bounds3.toJson(b)
    return "{\"mn\":"
        .. Vec3.toJson(b.mn)
        .. ",\"mx\":"
        .. Vec3.toJson(b.mx)
        .. "}"
end

---Returns a bounds with the dimensions
---of the CIE LAB color space. Intended
---for use with an octree containing
---points of color.
---@return table
function Bounds3.cieLab()
    return Bounds3.newByRef(
        Vec3.new(-110.0, -110.0,  -1.0),
        Vec3.new( 110.0,  110.0, 101.0))
end

---Returns a bounds containing a signed
---unit cube in Cartesian coordinates, from
---[-1.0, 1.0].
---@return table
function Bounds3.unitCubeSigned()
    return Bounds3.newByRef(
        Vec3.new(-1.000002, -1.000002, -1.000002),
        Vec3.new( 1.000002,  1.000002,  1.000002))
end

---Returns a bounds containing an unsigned
---unit cube in Cartesian coordinates, from
---[0.0, 1.0].
---@return table
function Bounds3.unitCubeUnsigned()
    return Bounds3.newByRef(
        Vec3.new(-0.000002, -0.000002, -0.000002),
        Vec3.new( 1.000002,  1.000002,  1.000002))
end

return Bounds3