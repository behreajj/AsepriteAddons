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
    inst.mn = Vec3.new(mn.x, mn.y, mn.z)
        or Vec3.new(-0.5, -0.5, -0.5)
    inst.mx = Vec3.new(mx.x, mx.y, mx.z)
        or Vec3.new(0.5, 0.5, 0.5)
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
        Vec3.add(b.min, b.max), 0.5)
end

---Evaluates whether a point is within the
---bounding volume, including the bounds's
---edges. A Vec3 is returned, where each
---component is 1.0 if true, 0.0 if false.
function Bounds3.containsInclusive(b, v)
    local x = 0.0
    local y = 0.0
    local z = 0.0

    if v.x >= b.min.x and v.x <= b.max.x then
        x = 1.0
    end
    if v.y >= b.min.y and v.y <= b.max.y then
        y = 1.0
    end
    if v.z >= b.min.z and v.z <= b.max.z then
        z = 1.0
    end

    return Vec3.new(x, y, z)
end

---Finds the extent of the bounds.
---Returns a Vec3 representing a
---non uniform scale.
---@param b table bound
---@return table
function Bounds3.extent(b)
    return Vec3.diff(b.max, b.min)
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

---Splits a bounding volume into octants
---according to three factors in the range
---[0.0, 1.0]. The factor on the x axis
---governs the vertical split. On the y axis,
---the horizontal split. On the z axis, the
---depth split.
---@param xFac number vertical factor
---@param yFac number horizontal vector
---@param zFac number depth factor
---@param bbl table back bottom left
---@param bbr table back bottom right
---@param btl table back top left
---@param btr table back top right
---@param fbl table front bottom left
---@param fbr table front bottom right
---@param ftl table front top left
---@param ftr table front top right
function Bounds3.splitInternal(
    b,
    xFac, yFac, zFac,
    bbl, bbr, btl, btr,
    fbl, fbr, ftl, ftr)
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

    bbl.mn = Vec3.new(bMin.x, bMin.y, bMin.z)
    bbr.mn = Vec3.new(     x, bMin.y, bMin.z)
    btl.mn = Vec3.new(bMin.x,      y, bMin.z)
    btr.mn = Vec3.new(     x,      y, bMin.z)
    fbl.mn = Vec3.new(bMin.x, bMin.y,      z)
    fbr.mn = Vec3.new(     x, bMin.y,      z)
    ftl.mn = Vec3.new(bMin.x,      y,      z)
    ftr.mn = Vec3.new(     x,      y,      z)

    bbl.mx = Vec3.new(     x,      y,      z)
    bbr.mx = Vec3.new(bMax.x,      y,      z)
    btl.mx = Vec3.new(     x, bMax.y,      z)
    btr.mx = Vec3.new(bMax.x, bMax.y,      z)
    fbl.mx = Vec3.new(     x,      y, bMax.z)
    fbr.mx = Vec3.new(bMax.x,      y, bMax.z)
    ftl.mx = Vec3.new(     x, bMax.y, bMax.z)
    ftr.mx = Vec3.new(bMax.x, bMax.y, bMax.z)

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