dofile("./vec2.lua")
dofile("./vec3.lua")
dofile("./vec4.lua")
dofile("./mat3.lua")
dofile("./mesh2.lua")
dofile("./quaternion.lua")

Utilities = {}
Utilities.__index = Utilities

setmetatable(Utilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Houses utility methods not included in Lua.
---@return table
function Utilities.new()
    local inst = setmetatable({}, Utilities)
    return inst
end

---Forces an overflow wrap to make 64 bit
---integers behave like 32 bit integers.
---@param x integer the integer
---@return integer
function Utilities.int32Overflow(x)
    -- https://stackoverflow.com/questions/
    -- 300840/force-php-integer-overflow
    local y = x & 0xffffffff
    if y & 0x80000000 then
        return -((~y & 0xffffffff) + 1)
    else
        return y
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the furthest clockwise direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleFar(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5

    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 or (o < d and diff < halfRange) then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff > -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the nearest clockwise direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleNear(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5

    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Multiplies a matrix with a 2D curve.
---Changes the curve in place.
---@param a table matrix
---@param b table curve
---@return table
function Utilities.mulMat3Curve2(a, b)
    local kns = b.knots
    local knsLen = #kns
    for i = 1, knsLen, 1 do
        kns[i] = Utilities.mulMat3Knot2(a, kns[i])
    end
    return b
end

---Multiplies a matrix with a 2D knot.
---Changes the knot in place.
---@param a table matrix
---@param b table knot
---@return table
function Utilities.mulMat3Knot2(a, b)
    b.co = Utilities.mulMat3Point2(a, b.co)
    b.fh = Utilities.mulMat3Point2(a, b.fh)
    b.rh = Utilities.mulMat3Point2(a, b.rh)
    return b
end

---Multiplies a matrix with a 2D mesh.
---Changes the mesh in place.
---@param a table matrix
---@param b table mesh
---@return table
function Utilities.mulMat3Mesh2(a, b)
    local vs = b.vs
    local vsLen = #vs
    for i = 1, vsLen, 1 do
        vs[i] = Utilities.mulMat3Point2(a, vs[i])
    end
    return b
end

---Multiplies a Mat3 with a Vec2.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Point2(a, b)
    local w = a.m20 * b.x + a.m21 * b.y + a.m22
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec2.new(
            (a.m00 * b.x + a.m01 * b.y + a.m02) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m12) * wInv)
    else
        return Vec2.new(0.0, 0.0)
    end
end

---Multiplies a Mat4 with a Vec3.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat4Point3(a, b)
    local w = a.m30 * b.x + a.m31 * b.y + a.m33
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec3.new(
            (a.m00 * b.x + a.m01 * b.y + a.m03) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m13) * wInv,
            (a.m20 * b.x + a.m21 * b.y + a.m23) * wInv)
    else
        return Vec3.new(0.0, 0.0, 0.0)
    end
end

---Multiplies a Mat3 with a Vec3.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Vec3(a, b)
    return Vec3.new(
        a.m00 * b.x + a.m01 * b.y + a.m02 * b.z,
        a.m10 * b.x + a.m11 * b.y + a.m12 * b.z,
        a.m20 * b.x + a.m21 * b.y + a.m22 * b.z)
end

---Multiplies a Mat4 with a Vec4.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat4Vec4(a, b)
    return Vec4.new(
        a.m00 * b.x + a.m01 * b.y
      + a.m02 * b.z + a.m03 * b.w,
        a.m10 * b.x + a.m11 * b.y
      + a.m12 * b.z + a.m13 * b.w,
        a.m20 * b.x + a.m21 * b.y
      + a.m22 * b.z + a.m23 * b.w,
        a.m30 * b.x + a.m31 * b.y
      + a.m32 * b.z + a.m33 * b.w)
end

---Multiplies a Quaternion and a Vec3.
---The Vec3 is treated as a point, not as
---a pure quaternion.
---@param a table quaternion
---@param b table vector
---@return table
function Utilities.mulQuatVec3(a, b)
    local ai = a.imag
    local qw = a.real
    local qx = ai.x
    local qy = ai.y
    local qz = ai.z

    local iw = -qx * b.x - qy * b.y - qz * b.z
    local ix =  qw * b.x + qy * b.z - qz * b.y
    local iy =  qw * b.y + qz * b.x - qx * b.z
    local iz =  qw * b.z + qx * b.y - qy * b.x

    return Vec3.new(
        ix * qw + iz * qy - iw * qx - iy * qz,
        iy * qw + ix * qz - iw * qy - iz * qx,
        iz * qw + iy * qx - iw * qz - ix * qy)
end

---Promotes a Vec2 to a Vec3.
---The z component defaults to 0.0.
---@param a table vector
---@param z number z component
---@return table
function Utilities.promoteVec2ToVec3(a, z)
    local vz = z or 0.0
    return Vec3.new(a.x, a.y, vz)
end

---Promotes a Vec2 to a Vec4.
---The z component defaults to 0.0.
---The w component defaults to 0.0.
---@param a table vector
---@param z number z component
---@param w number w component
---@return table
function Utilities.promoteVec2ToVec4(a, z, w)
    local vz = z or 0.0
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, vz, vw)
end

---Promotes a Vec3 to a Vec4.
---The w component defaults to 0.0.
---@param a table vector
---@param w number w component
---@return table
function Utilities.promoteVec3ToVec4(a, w)
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, a.z, vw)
end

return Utilities