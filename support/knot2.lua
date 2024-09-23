dofile("./vec2.lua")

---@class Knot2
---@field public fh Vec2 fore handle
---@field public co Vec2 coordinate
---@field public rh Vec2 rear handle
Knot2 = {}
Knot2.__index = Knot2

setmetatable(Knot2, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new Bezier knot from a coordinate, fore handle and rear handle.
---All are Vec2s passed by reference.
---@param co Vec2 coordinate
---@param fh Vec2 fore handle
---@param rh Vec2 rear handle
---@return Knot2
---@nodiscard
function Knot2.new(co, fh, rh)
    local inst <const> = setmetatable({}, Knot2)
    inst.co = co or Vec2.new(0.0, 0.0)
    inst.fh = fh or Vec2.new(inst.co.x + 0.000001, inst.co.y)
    inst.rh = rh or (inst.co - (inst.fh - inst.co))
    return inst
end

function Knot2:__tostring()
    return Knot2.toJson(self)
end

---Aligns the knot's handles.
---@return Knot2
function Knot2:alignHandles()
    return self:alignHandlesForward()
end

---Aligns the knot's fore handle to its rear handle while preserving magnitude.
---@return Knot2
function Knot2:alignHandlesBackward()
    local rDir <const> = Vec2.sub(self.rh, self.co)
    local rMagSq <const> = Vec2.magSq(rDir)
    if rMagSq > 0.0 then
        self.fh = Vec2.sub(
            self.co, Vec2.scale(rDir,
                Vec2.dist(self.fh, self.co)
                / math.sqrt(rMagSq)))
    end
    return self
end

---Aligns the knot's rear handle to its fore handle while preserving magnitude.
---@return Knot2
function Knot2:alignHandlesForward()
    local fDir <const> = Vec2.sub(self.fh, self.co)
    local fMagSq <const> = Vec2.magSq(fDir)
    if fMagSq > 0.0 then
        self.rh = Vec2.sub(
            self.co, Vec2.scale(fDir,
                Vec2.dist(self.rh, self.co)
                / math.sqrt(fMagSq)))
    end
    return self
end

---Mirrors the knot's handles.
---@return Knot2
function Knot2:mirrorHandles()
    return self:mirrorHandlesForward()
end

---Sets the fore handle to mirror the rear handle.
---@return Knot2
function Knot2:mirrorHandlesBackward()
    self.fh = Vec2.sub(self.co, Vec2.sub(self.rh, self.co))
    return self
end

---Sets the rear handle to mirror the fore handle.
---@return Knot2
function Knot2:mirrorHandlesForward()
    self.rh = Vec2.sub(self.co, Vec2.sub(self.fh, self.co))
    return self
end

---Reverses the knots direction by swapping its fore and rear handles.
---@return Knot2
function Knot2:reverse()
    local temp <const> = self.fh
    self.fh = self.rh
    self.rh = temp
    return self
end

---Rotates this knot around the z axis by an angle in radians.
---@param radians number angle
---@return Knot2
function Knot2:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this knot around the z axis by the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Knot2
function Knot2:rotateZInternal(cosa, sina)
    self.co = Vec2.rotateZInternal(
        self.co, cosa, sina)
    self.fh = Vec2.rotateZInternal(
        self.fh, cosa, sina)
    self.rh = Vec2.rotateZInternal(
        self.rh, cosa, sina)
    return self
end

---Scales this knot. Defaults to scale by a vector.
---@param v Vec2|number scalar
---@return Knot2
function Knot2:scale(v)
    if type(v) == "number" then
        return self:scaleNum(v)
    else
        return self:scaleVec2(v)
    end
end

---Scales this knot by a number.
---@param n number uniform scalar
---@return Knot2
function Knot2:scaleNum(n)
    self.co = Vec2.scale(self.co, n)
    self.fh = Vec2.scale(self.fh, n)
    self.rh = Vec2.scale(self.rh, n)
    return self
end

---Scales this knot by a vector.
---@param v Vec2 nonuniform scalar
---@return Knot2
function Knot2:scaleVec2(v)
    self.co = Vec2.hadamard(self.co, v)
    self.fh = Vec2.hadamard(self.fh, v)
    self.rh = Vec2.hadamard(self.rh, v)
    return self
end

---Translates this knot by a vector.
---@param v Vec2 vector
---@return Knot2
function Knot2:translate(v)
    self.co = Vec2.add(self.co, v)
    self.fh = Vec2.add(self.fh, v)
    self.rh = Vec2.add(self.rh, v)
    return self
end

---Evaluates a point between two knots given an origin, destination and step.
---@param a Knot2 origin knot
---@param b Knot2 destination knot
---@param step number step
---@return Vec2
---@nodiscard
function Knot2.bezierPoint(a, b, step)
    return Vec2.bezierPoint(a.co, a.fh, b.rh, b.co, step)
end

---Returns a JSON string of a knot.
---@param knot Knot2 knot
---@return string
---@nodiscard
function Knot2.toJson(knot)
    return string.format(
        "{\"co\":%s,\"fh\":%s,\"rh\":%s}",
        Vec2.toJson(knot.co),
        Vec2.toJson(knot.fh),
        Vec2.toJson(knot.rh))
end

return Knot2