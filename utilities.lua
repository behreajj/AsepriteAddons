dofile("./vec2.lua")
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

return Utilities