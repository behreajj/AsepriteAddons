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

function Bounds3:__tostring()
    return Bounds3.toJson(self)
end

---Finds the center of a bounding box.
---Returns a Vec3.
---@param b table bound
---@return table
function Bounds3.center(b)
    return Vec3.scale(
        Vec3.add(b.mn, b.mx), 0.5)
end

---Evaluates whether a point is within the
---bounding volume, lower bounds inclusive,
---upper bounds exclusive.
---@param b table
---@param pt table
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
---@param b table bound
---@return table
function Bounds3.extent(b)
    return Vec3.diff(b.mx, b.mn)
end

---Creates a bounding volume from a center
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

---Evaluates whether two bounding volumes intersect.
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Bounds3.intersectsBounds(a, b)
    return a.max.x > b.min.x
        or a.min.x < b.max.x
        or a.max.y > b.min.y
        or a.min.y < b.max.y
        or a.max.z > b.min.z
        or a.min.z < b.max.z
end

---Evaluates whether a bounding volume intersects
---a sphere. The sphere is defined as a Vec3 center
---and a number radius.
---@param a table bounds
---@param center table sphere center
---@param radius number sphere radius
---@return boolean
function Bounds3.intersectsSphere(a, center, radius)

    local aMin = a.mn
    local aMax = a.mx

    local xDist = 0.0
    local yDist = 0.0
    local zDist = 0.0

    if center.x < aMin.x then
        xDist = center.x - aMin.x
    elseif center.x > (center.x - aMax.x) then
        xDist = aMax.x
    end

    if center.y < aMin.y then
        yDist = center.y - aMin.y
    elseif center.y > (center.y - aMax.y) then
        yDist = aMax.y
    end

    if center.z < aMin.z then
        zDist = center.z - aMin.z
    elseif center.z > (center.z - aMax.z) then
        zDist = aMax.z
    end

    local dsq = xDist * xDist
              + yDist * yDist
              + zDist * zDist
    local rsq = radius * radius
    return dsq < rsq
end

---Splits a bounding volume into octants
---according to three factors in the range
---[0.0, 1.0]. The factor on the x axis
---governs the vertical split. On the y axis,
---the horizontal split. On the z axis, the
---depth split.
---@param xFac number vertical factor
---@param yFac number horizontal vector
---@param zFac number depth factor
---@param bsw table back south west
---@param bse table back south east
---@param bnw table back north west
---@param bne table back north east
---@param fsw table front south west
---@param fse table front south east
---@param fnw table front north west
---@param fne table front north east
function Bounds3.splitInternal(
    b, xFac, yFac, zFac,
    bsw, bse, bnw, bne,
    fsw, fse, fnw, fne)

    local bMin = b.mn
    local bMax = b.mx

    local tx = math.min(math.max(
        xFac, 0.000001), 0.999999)
    local ty = math.min(math.max(
        yFac, 0.000001), 0.999999)
    local tz = math.min(math.max(
        zFac, 0.000001), 0.999999)

    local x = ( 1.0 - tx ) * bMin.x + tx * bMax.x
    local y = ( 1.0 - ty ) * bMin.y + ty * bMax.y
    local z = ( 1.0 - tz ) * bMin.z + tz * bMax.z

    bsw.mn = Vec3.new(bMin.x, bMin.y, bMin.z)
    bse.mn = Vec3.new(     x, bMin.y, bMin.z)
    bnw.mn = Vec3.new(bMin.x,      y, bMin.z)
    bne.mn = Vec3.new(     x,      y, bMin.z)
    fsw.mn = Vec3.new(bMin.x, bMin.y,      z)
    fse.mn = Vec3.new(     x, bMin.y,      z)
    fnw.mn = Vec3.new(bMin.x,      y,      z)
    fne.mn = Vec3.new(     x,      y,      z)

    bsw.mx = Vec3.new(     x,      y,      z)
    bse.mx = Vec3.new(bMax.x,      y,      z)
    bnw.mx = Vec3.new(     x, bMax.y,      z)
    bne.mx = Vec3.new(bMax.x, bMax.y,      z)
    fsw.mx = Vec3.new(     x,      y, bMax.z)
    fse.mx = Vec3.new(bMax.x,      y, bMax.z)
    fnw.mx = Vec3.new(     x, bMax.y, bMax.z)
    fne.mx = Vec3.new(bMax.x, bMax.y, bMax.z)

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

---Finds the volume of the bounds.
---@param b table bounds
---@return number
function Bounds3.volume(b)
    local dff = Vec3.diff(b.mx, b.mn)
    return dff.x * dff.y * dff.z
end

return Bounds3