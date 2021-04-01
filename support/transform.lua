dofile("./vec2.lua")

Transform2 = {}
Transform2.__index = Transform2

setmetatable(Transform2, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new transform from translation,
---rotation and scale. Translation and scale
---are Vec2s; rotation is a number, in radians.
---@param t table translation
---@param r number rotation
---@param s table scale
---@return table
function Transform2.new(t, r, s)
    local inst = setmetatable({}, Transform2)
    inst.translation = t or Vec2.new(0.0, 0.0)
    inst.rotation = r or 0.0
    inst.scale = s or Vec2.new(1.0, 1.0)
    return inst
end

function Transform2:__tostring()
    return Transform2.toJson(self)
end

---Moves a transform to a location by a step.
---If no step is given, defaults to 1.0.
---@param loc table location
---@param step number step
---@return table
function Transform2:moveTo(loc, step)
    local t = step or 1.0

    if t <= 0.0 then
        return self
    end

    if t >= 1.0 then
        self.translation = Vec2.new(loc.x, loc.y)
        return self
    end

    self.translation = Vec2.mixByNumber(
        self.translation, loc, t)
    return self
end

function Transform2:rotateTo(ang, step)
    local t = step or 1.0

    if t <= 0.0 then
        return self
    end

    if t >= 1.0 then
        self.rotation = ang % 6.283185307179586
        return self
    end

    -- TODO: Lerp Near

    return self
end

---Scales a transform to a nonuniform scale
---held in Vec2 by a step. If no step is
---given, defaults to 1.0.
---@param scl table scale
---@param step number step
---@return table
function Transform2:scaleTo(scl, step)
    local t = step or 1.0

    if t <= 0.0 then
        return self
    end

    if t >= 1.0 then
        self.scale = Vec2.new(scl.x, scl.y)
        return self
    end

    self.scale = Vec2.mixByNumber(
        self.scale, scl, t)
    return self
end

---Returns a JSON string of a transform.
---@param tr table transform
---@return string
function Transform2.toJson(tr)
    return "{\"translation\":"
        .. Vec2.toJson(tr.translation)
        .. ",\"rotation\":"
        .. string.format("%.4f", tr.rotation)
        .. ",\"scale\":"
        .. Vec2.toJson(tr.scale)
        .. "}"
end

---Returns the identity transform.
---@return table
function Transform2.identity()
    return Transform2.new(
        Vec2.new(0.0, 0.0), 0.0,
        Vec2.new(1.0, 1.0))
end

return Transform2