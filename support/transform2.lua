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

---Flips the transform's scale on the
---horizontal axis.
function Transform2:flipX()
    self.scale.x = -self.scale.x
    return self
end

---Flips the transform's scale on the
---vertical axis.
function Transform2:flipY()
    self.scale.y = -self.scale.y
    return self
end

---Moves a transform by a vector.
---@param v table vector
---@return table
function Transform2:moveBy(v)
    return self:moveGlobal(v)
end

---Moves a transform by a vector
---in global space.
---@param v table vector
---@return table
function Transform2:moveGlobal(v)
    self.translation = Vec2.add(
        self.translation, v)
    return self
end

---Moves a transform by a vector
---in local space.
---@param v table vector
---@return table
function Transform2:moveByLocal(v)
    self.translation = Vec2.add(
        self.translation,
        Vec2.rotateZ(v, self.rotation))
    return self
end

---Moves a transform to a location by a step.
---If no step is given, defaults to 1.0.
---@param loc table location
---@param step number step
---@return table
function Transform2:moveTo(loc, step)
    local t = step or 1.0

    if t >= 1.0 then
        self.translation = Vec2.new(loc.x, loc.y)
        return self
    end

    if t <= 0.0 then
        return self
    end

    self.translation = Vec2.mixByNumber(
        self.translation, loc, t)
    return self
end

---Rotates a transform to a rotation by a step.
---If no step is given, defaults to 1.0.
---@param ang number rotation
---@param step number step
---@return table
function Transform2:rotateTo(ang, step)
    local t = step or 1.0
    local tau = 6.283185307179586

    if t >= 1.0 then
        self.rotation = ang % tau
        return self
    end

    if t <= 0.0 then
        self.rotation = self.rotation % tau
        return self
    end

    local o = self.rotation % tau
    local d = ang % tau
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        self.rotation = o
    elseif o < d and diff > math.pi then
        self.rotation = (u * (o + tau) + t * d) % tau
    elseif o > d and diff < -math.pi then
        self.rotation = (u * o + t * (d + tau)) % tau
    else
        self.rotation = u * o + t * d
    end

    return self
end

---Rotates a transform around the z axis.
---@param ang number the angle
function Transform2:rotateZ(ang)
    self.rotation = (self.rotation + ang) % 6.283185307179586
    return self
end

---Scales a transform. Defaults to
---nonuniform scaling by a vector.
---@param v table scalar
---@return table
function Transform2:scaleBy(v)
    return self:scaleByNonuniform(v)
end

---Scales a transform by a number.
---@param v number uniform scalar
---@return table
function Transform2:scaleByUniform(v)
    self.scale = Vec2.scale(self.scale, v)
    return self
end

---Moves a transform by a vector.
---@param v table nonuniform scalar
---@return table
function Transform2:scaleByNonuniform(v)
    self.scale = Vec2.mul(self.scale, v)
    return self
end

---Scales a transform to a scale.
---Defaults to nonuniform scaling.
---@param v table scalar
---@param step number step
---@return table
function Transform2:scaleTo(v, step)
    return self:scaleToNonuniform(v, step)
end

---Scales a transform to a nonuniform scale
---held in a Vec2 by a step. If no step is
---given, defaults to 1.0.
---@param scl table scale
---@param step number step
---@return table
function Transform2:scaleToNonuniform(scl, step)
    local t = step or 1.0

    if t >= 1.0 then
        self.scale = Vec2.new(scl.x, scl.y)
        return self
    end

    if t <= 0.0 then
        return self
    end

    self.scale = Vec2.mixByNumber(
        self.scale, scl, t)
    return self
end

---Scales a transform to a uniform scale
---held in a number by a step. If no step is
---given, defaults to 1.0.
---@param scl number scale
---@param step number step
---@return table
function Transform2:scaleToUniform(scl, step)
    local t = step or 1.0

    if t >= 1.0 then
        self.scale = Vec2.new(scl, scl)
        return self
    end

    if t <= 0.0 then
        return self
    end

    self.scale = Vec2.mixByNumber(
        self.scale,
        Vec2.new(scl, scl), t)
    return self
end

---Gets the transform's axes.
---Returns a table with keys "forward" and "right."
---@param tr table transform
---@return table
function Transform2.getAxes(tr)
    local r = Vec2.fromPolar(tr.rotation, 1.0)
    local f = Vec2.perpendicularCcw(r)
    return { forward = f, right = r }
end

---Gets the transform's forward axis.
---@param tr table transform
---@return table
function Transform2.getForward(tr)
    return Vec2.perpendicularCcw(
        Vec2.fromPolar(tr.rotation, 1.0));
end

---Gets the transform's right axis.
---@param tr table transform
---@return table
function Transform2.getRight(tr)
    return Vec2.fromPolar(tr.rotation, 1.0)
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