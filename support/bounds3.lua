dofile("./vec3.lua")

---@class Bounds3
---@field public mn Vec3 lower bound
---@field public mx Vec3 upper bound
Bounds3 = {}
Bounds3.__index = Bounds3

setmetatable(Bounds3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Defaults to passing vectors
---by value.
---@param mn Vec3|number lower bound
---@param mx Vec3|number upper bound
---@return Bounds3
---@nodiscard
function Bounds3.new(mn, mx)
    return Bounds3.newByVal(mn, mx)
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are assigned by
---reference.
---@param mn Vec3 lower bound
---@param mx Vec3 upper bound
---@return Bounds3
---@nodiscard
function Bounds3.newByRef(mn, mx)
    local inst <const> = setmetatable({}, Bounds3)
    inst.mn = mn or Vec3.new(-0.5, -0.5, -0.5)
    inst.mx = mx or Vec3.new(0.5, 0.5, 0.5)
    return inst
end

---Constructs a new axis aligned bounding box (AABB) for a 3D volume,
---represented by a minimum and maximum coordinate. Vectors are copied by value.
---@param mn Vec3|number lower bound
---@param mx Vec3|number upper bound
---@return Bounds3
---@nodiscard
function Bounds3.newByVal(mn, mx)
    local inst <const> = setmetatable({}, Bounds3)

    inst.mn = nil
    if mn then
        if type(mn) == "number" then
            inst.mn = Vec3.new(mn, mn, mn)
        else
            inst.mn = Vec3.new(mn.x, mn.y, mn.z)
        end
    else
        inst.mn = Vec3.new(-0.5, -0.5, -0.5)
    end

    inst.mx = nil
    if mx then
        if type(mx) == "number" then
            inst.mx = Vec3.new(mx, mx, mx)
        else
            inst.mx = Vec3.new(mx.x, mx.y, mx.z)
        end
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

---Finds the center of a bounding box. Returns a Vec3.
---@param b Bounds3 bounds
---@return Vec3
---@nodiscard
function Bounds3.center(b)
    return Vec3.mixNum(b.mn, b.mx, 0.5)
end

---Evaluates whether a point is within the bounds, lower bounds inclusive, upper
---bounds exclusive.
---@param b Bounds3 bounds
---@param pt Vec3 point
---@return boolean
---@nodiscard
function Bounds3.containsInclExcl(b, pt)
    local mn <const> = b.mn
    local mx <const> = b.mx
    return (pt.x >= mn.x and pt.x < mx.x)
        and (pt.y >= mn.y and pt.y < mx.y)
        and (pt.z >= mn.z and pt.z < mx.z)
end

---Evaluates whether a bounding box intersects a sphere.
---@param a Bounds3 bounds
---@param center Vec3 sphere center
---@param radius number sphere radius
---@return boolean
---@nodiscard
function Bounds3.intersectsSphere(a, center, radius)
    return Bounds3.intersectsSphereInternal(
        a, center, radius * radius)
end

---Evaluates whether a bounding box intersects a sphere. Internal helper
---function for octrees, as it assumes that the squared-radius has already been
---calculated.
---@param a Bounds3 bounds
---@param center Vec3 sphere center
---@param rsq number sphere radius, squared
---@return boolean
---@nodiscard
function Bounds3.intersectsSphereInternal(a, center, rsq)
    local xd, yd, zd = 0.0, 0.0, 0.0

    if center.x < a.mn.x then
        xd = center.x - a.mn.x
    elseif center.x > a.mx.x then
        xd = center.x - a.mx.x
    end

    if center.y < a.mn.y then
        yd = center.y - a.mn.y
    elseif center.y > a.mx.y then
        yd = center.y - a.mx.y
    end

    if center.z < a.mn.z then
        zd = center.z - a.mn.z
    elseif center.z > a.mx.z then
        zd = center.z - a.mx.z
    end

    return (xd * xd + yd * yd + zd * zd) < rsq
end

---Splits a bounding box into octants according to three factors in the range
---[0.0, 1.0]. The factor on the x axis governs the vertical split. On the y
---axis, the horizontal split. On the z axis, the depth split.
---@param b Bounds3 bounds
---@param xFac number vertical factor
---@param yFac number horizontal vector
---@param zFac number depth factor
---@param bsw Bounds3 back south west octant
---@param bse Bounds3 back south east octant
---@param bnw Bounds3 back north west octant
---@param bne Bounds3 back north east octant
---@param fsw Bounds3 front south west octant
---@param fse Bounds3 front south east octant
---@param fnw Bounds3 front north west octant
---@param fne Bounds3 front north east octant
function Bounds3.splitInternal(
    b, xFac, yFac, zFac,
    bsw, bse, bnw, bne, fsw, fse, fnw, fne)
    local bMn <const> = b.mn
    local bMx <const> = b.mx

    local x <const> = (1.0 - xFac) * bMn.x + xFac * bMx.x
    local y <const> = (1.0 - yFac) * bMn.y + yFac * bMx.y
    local z <const> = (1.0 - zFac) * bMn.z + zFac * bMx.z

    bsw.mn = Vec3.new(bMn.x, bMn.y, bMn.z)
    bse.mn = Vec3.new(x, bMn.y, bMn.z)
    bnw.mn = Vec3.new(bMn.x, y, bMn.z)
    bne.mn = Vec3.new(x, y, bMn.z)
    fsw.mn = Vec3.new(bMn.x, bMn.y, z)
    fse.mn = Vec3.new(x, bMn.y, z)
    fnw.mn = Vec3.new(bMn.x, y, z)
    fne.mn = Vec3.new(x, y, z)

    bsw.mx = Vec3.new(x, y, z)
    bse.mx = Vec3.new(bMx.x, y, z)
    bnw.mx = Vec3.new(x, bMx.y, z)
    bne.mx = Vec3.new(bMx.x, bMx.y, z)
    fsw.mx = Vec3.new(x, y, bMx.z)
    fse.mx = Vec3.new(bMx.x, y, bMx.z)
    fnw.mx = Vec3.new(x, bMx.y, bMx.z)
    fne.mx = Vec3.new(bMx.x, bMx.y, bMx.z)
end

---Returns a JSON string of the bounds.
---@param b Bounds3 bounds
---@return string
---@nodiscard
function Bounds3.toJson(b)
    return string.format(
        "{\"mn\":%s,\"mx\":%s}",
        Vec3.toJson(b.mn),
        Vec3.toJson(b.mx))
end

---Returns a bounds with the dimensions of the CIE LAB or SR LAB 2 color spaces.
---Intended for use with an octree containing points of color.
---@return Bounds3
---@nodiscard
function Bounds3.lab()
    return Bounds3.newByRef(
        Vec3.new(-111.0, -111.0, -1.0),
        Vec3.new(111.0, 111.0, 101.0))
end

---Returns a bounds containing a signed unit cube in Cartesian coordinates,
---from [-1.0, 1.0].
---@return Bounds3
---@nodiscard
function Bounds3.unitCubeSigned()
    return Bounds3.newByRef(
        Vec3.new(-1.000002, -1.000002, -1.000002),
        Vec3.new(1.000002, 1.000002, 1.000002))
end

---Returns a bounds containing an unsigned unit cube in Cartesian coordinates,
---from [0.0, 1.0].
---@return Bounds3
---@nodiscard
function Bounds3.unitCubeUnsigned()
    return Bounds3.newByRef(
        Vec3.new(-0.000002, -0.000002, -0.000002),
        Vec3.new(1.000002, 1.000002, 1.000002))
end

return Bounds3