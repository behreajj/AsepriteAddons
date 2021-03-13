dofile("./vec2.lua")
dofile("./vec3.lua")
dofile("./mat3.lua")

Utilities = {}
Utilities.__index = Utilities

setmetatable(Utilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Houses utility methods not included in Lua.
---@return table
function Utilities.new()
    local inst = {}
    setmetatable(inst, Utilities)
    return inst
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

---Multiplies a matrix with a vector.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Vec2(a, b)
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

---Promotes a Vec2 to a Vec3.
---@param a table vector 2
---@return table
function Utilities.promoteVec2ToVec3(a)
    return Vec3.new(a.x, a.y, 0.0)
end

return Utilities