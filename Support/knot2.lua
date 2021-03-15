dofile("./vec2.lua")

Knot2 = {}
Knot2.__index = Knot2

setmetatable(Knot2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new Bezier knot from a coordinate,
---fore handle and rear handle. All are Vec2s passed
---by reference.
---@param co table coordinate
---@param fh table fore handle
---@param rh table rear handle
---@return table
function Knot2.new(co, fh, rh)
    local inst = {}
    setmetatable(inst, Knot2)
    inst.co = co or Vec2.new(0.0, 0.0)
    inst.fh = fh or Vec2.new(inst.co.x + 0.000001, inst.co.y)
    inst.rh = rh or (inst.co + (inst.fh - inst.co))
    return inst
end

function Knot2:__tostring()
    return string.format(
        "{ co: %s, fh: %s, rh: %s}",
        self.co, self.fh, self.rh)
end

return Knot2