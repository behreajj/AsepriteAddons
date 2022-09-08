dofile("./vec3.lua")

---@class Knot3
---@field fh Vec3 fore handle
---@field co Vec3 coordinate
---@field rh Vec3 rear handle
Knot3 = {}
Knot3.__index = Knot3

setmetatable(Knot3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new Bezier knot from a coordinate,
---fore handle and rear handle. All are Vec3s passed
---by reference.
---@param co table coordinate
---@param fh table fore handle
---@param rh table rear handle
---@return Knot3
function Knot3.new(co, fh, rh)
    local inst = setmetatable({}, Knot3)
    inst.co = co or Vec3.new(0.0, 0.0, 0.0)
    inst.fh = fh or Vec3.new(
        inst.co.x + 0.000001,
        inst.co.y,
        inst.co.z)
    inst.rh = rh or (inst.co - (inst.fh - inst.co))
    return inst
end

function Knot3:__tostring()
    return Knot3.toJson(self)
end

---Aligns the knot's handles.
---@return Knot3
function Knot3:alignHandles()
    return self:alignHandlesForward()
end

---Aligns the knot's fore handle to its
---rear handle while preserving magnitude.
---@return Knot3
function Knot3:alignHandlesBackward()
    local rDir = Vec3.sub(self.rh, self.co)
    local rMagSq = Vec3.magSq(rDir)
    if rMagSq > 0.0 then
        self.fh = Vec3.sub(self.co,
            Vec3.scale(rDir,
                Vec3.dist(self.fh, self.co)
                / math.sqrt(rMagSq)))
    end
    return self
end

---Aligns the knot's rear handle to its
---fore handle while preserving magnitude.
---@return Knot3
function Knot3:alignHandlesForward()
    local fDir = Vec3.sub(self.fh, self.co)
    local fMagSq = Vec3.magSq(fDir)
    if fMagSq > 0.0 then
        self.rh = Vec3.sub(self.co,
            Vec3.scale(fDir,
                Vec3.dist(self.rh, self.co)
                / math.sqrt(fMagSq)))
    end
    return self
end

---Mirrors the knot's handles.
---@return Knot3
function Knot3:mirrorHandles()
    return self:mirrorHandlesForward()
end

---Sets the fore handle to mirror
---the rear handle.
---@return Knot3
function Knot3:mirrorHandlesBackward()
    self.fh = Vec3.sub(self.co, Vec3.sub(self.rh, self.co))
    return self
end

---Sets the rear handle to mirror
---the fore handle.
---@return Knot3
function Knot3:mirrorHandlesForward()
    self.rh = Vec3.sub(self.co, Vec3.sub(self.fh, self.co))
    return self
end

---Reverses the knots direction by swapping
---its fore and rear handles.
---@return Knot3
function Knot3:reverse()
    local temp = self.fh
    self.fh = self.rh
    self.rh = temp
    return self
end

---Rotates this knot around the x axis by
---an angle in radians.
---@param radians number angle
---@return Knot3
function Knot3:rotateX(radians)
    return self:rotateXInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this knot around the x axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Knot3
function Knot3:rotateXInternal(cosa, sina)
    self.co = Vec3.rotateXInternal(self.co, cosa, sina)
    self.fh = Vec3.rotateXInternal(self.fh, cosa, sina)
    self.rh = Vec3.rotateXInternal(self.rh, cosa, sina)
    return self
end

---Rotates this knot around the y axis by
---an angle in radians.
---@param radians number angle
---@return Knot3
function Knot3:rotateY(radians)
    return self:rotateYInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this knot around the y axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Knot3
function Knot3:rotateYInternal(cosa, sina)
    self.co = Vec3.rotateYInternal(self.co, cosa, sina)
    self.fh = Vec3.rotateYInternal(self.fh, cosa, sina)
    self.rh = Vec3.rotateYInternal(self.rh, cosa, sina)
    return self
end

---Rotates this knot around the z axis by
---an angle in radians.
---@param radians number angle
---@return Knot3
function Knot3:rotateZ(radians)
    return self:rotateZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Rotates this knot around the z axis by
---the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Knot3
function Knot3:rotateZInternal(cosa, sina)
    self.co = Vec3.rotateZInternal(self.co, cosa, sina)
    self.fh = Vec3.rotateZInternal(self.fh, cosa, sina)
    self.rh = Vec3.rotateZInternal(self.rh, cosa, sina)
    return self
end

---Scales this knot.
---Defaults to scale by a Vec3.
---@param v Vec3|number scalar
---@return Knot3
function Knot3:scale(v)
    if type(v) == "number" then
        return self:scaleNum(v)
    else
        return self:scaleVec3(v)
    end
end

---Scales this knot by a number.
---@param n number uniform scalar
---@return Knot3
function Knot3:scaleNum(n)
    self.co = Vec3.scale(self.co, n)
    self.fh = Vec3.scale(self.fh, n)
    self.rh = Vec3.scale(self.rh, n)
    return self
end

---Scales this knot by a vector.
---@param v Vec3 nonuniform scalar
---@return Knot3
function Knot3:scaleVec3(v)
    self.co = Vec3.hadamard(self.co, v)
    self.fh = Vec3.hadamard(self.fh, v)
    self.rh = Vec3.hadamard(self.rh, v)
    return self
end

---Translates this knot by a Vec3.
---@param v Vec3 vector
---@return Knot3
function Knot3:translate(v)
    self.co = Vec3.add(self.co, v)
    self.fh = Vec3.add(self.fh, v)
    self.rh = Vec3.add(self.rh, v)
    return self
end

---Evaluates a point between two knots
---given an origin, destination and step.
---@param a Knot3 origin knot
---@param b Knot3 destination knot
---@param step number step
---@return Vec3
function Knot3.bezierPoint(a, b, step)
    return Vec3.bezierPoint(
        a.co, a.fh,
        b.rh, b.co,
        step)
end

---Gets the knot's fore handle as a direction.
---@param knot Knot3 knot
---@return Vec3
function Knot3.foreDir(knot)
    return Vec3.normalize(Knot3.foreVec(knot))
end

---Gets the knot's fore handle magnitude.
---@param knot Knot3
---@return number
function Knot3.foreMag(knot)
    return Vec3.dist(knot.fh, knot.co)
end

---Gets the knot's rear handle as a vector.
---@param knot Knot3 knot
---@return Vec3
function Knot3.foreVec(knot)
    return Vec3.sub(knot.fh, knot.co)
end

---Sets two knots from a segment of a Catmull-Rom
---curve. The default curve tightness is 0.0. Assumes
---that the previous knot's coordinate is set to a
---prior anchor point.
---
---The previous knot's fore handle,
---the next knot's rear handle and the next knot's
---coordinate are set by this function.
---@param prevAnchor Vec3 previous anchor point
---@param currAnchor Vec3 current anchor point
---@param nextAnchor Vec3 next anchor point
---@param advAnchor Vec3 advance anchor point
---@param tightness number curve tightness
---@param prevKnot Knot3 previous knot
---@param nextKnot Knot3 next knot
---@return Knot3
function Knot3.fromSegCatmull(prevAnchor, currAnchor, nextAnchor, advAnchor, tightness, prevKnot, nextKnot)
    if math.abs(tightness - 1.0) <= 0.000001 then
        return Knot3.fromSegLinear(
            nextAnchor, prevKnot, nextKnot)
    end

    local fac = (tightness - 1.0) * 0.16666666666667

    prevKnot.fh = Vec3.sub(currAnchor,
        Vec3.scale(Vec3.sub(
            nextAnchor, prevAnchor), fac))
    nextKnot.rh = Vec3.add(nextAnchor,
        Vec3.scale(Vec3.sub(
            advAnchor, currAnchor), fac))
    nextKnot.co = Vec3.new(
        nextAnchor.x,
        nextAnchor.y,
        nextAnchor.z)

    return nextKnot
end

---Sets a knot from a line segment. Assumes that
---the previous knot's coordinate is set to the
---first anchor point.
---
---The previous knot's fore handle,
---the next knot's rear handle and the next knot's
---coordinate are set by this function.
---@param nextAnchor Vec3 next anchor point
---@param prevKnot Knot3 previous knot
---@param nextKnot Knot3 next knot
---@return Knot3
function Knot3.fromSegLinear(nextAnchor, prevKnot, nextKnot)
    nextKnot.co = Vec3.new(
        nextAnchor.x,
        nextAnchor.y,
        nextAnchor.z)

    local prevCoord = prevKnot.co
    local nextCoord = nextKnot.co

    prevKnot.fh = Vec3.new(
        prevCoord.x * 0.66666666666667
        + nextCoord.x * 0.33333333333333,
        prevCoord.y * 0.66666666666667
        + nextCoord.y * 0.33333333333333,
        prevCoord.z * 0.66666666666667
        + nextCoord.z * 0.33333333333333)

    nextKnot.rh = Vec3.new(
        nextCoord.x * 0.66666666666667
        + prevCoord.x * 0.33333333333333,
        nextCoord.y * 0.66666666666667
        + prevCoord.y * 0.33333333333333,
        nextCoord.z * 0.66666666666667
        + prevCoord.z * 0.33333333333333)

    return nextKnot
end

---Sets two knots from a segment of a quadratic curve.
---Assumes that the previous knot's coordinate is set to
---the first anchor point.
---
---The previous knot's fore handle, the next knot's rear
---handle and the next knot's coordinate are set by
---this function.
---@param control Vec3 control point
---@param nextAnchor Vec3 next anchor point
---@param prevKnot Knot3 previous knot
---@param nextKnot Knot3 next knot
---@return Knot3
function Knot3.fromSegQuadratic(control, nextAnchor, prevKnot, nextKnot)
    nextKnot.co = Vec3.new(
        nextAnchor.x,
        nextAnchor.y,
        nextAnchor.z)

    local xMid = control.x * 0.66666666666667
    local yMid = control.y * 0.66666666666667
    local zMid = control.z * 0.66666666666667

    local prevCo = prevKnot.co
    prevKnot.fh = Vec3.new(
        xMid + prevCo.x * 0.33333333333333,
        yMid + prevCo.y * 0.33333333333333,
        zMid + prevCo.z * 0.33333333333333)
    nextKnot.rh = Vec3.new(
        xMid + nextAnchor.x * 0.33333333333333,
        yMid + nextAnchor.y * 0.33333333333333,
        zMid + nextAnchor.z * 0.33333333333333)

    return nextKnot
end

---Gets the knot's rear handle as a direction.
---@param knot Knot3 knot
---@return Vec3
function Knot3.rearDir(knot)
    return Vec3.normalize(Knot3.rearVec(knot))
end

---Gets the knot's rear handle magnitude.
---@param knot Knot3
---@return number
function Knot3.rearMag(knot)
    return Vec3.dist(knot.rh, knot.co)
end

---Gets the knot's rear handle as a vector.
---@param knot Knot3 knot
---@return Vec3
function Knot3.rearVec(knot)
    return Vec3.sub(knot.rh, knot.co)
end

---Smoothes the handles of a knot with
---reference to a previous and next knot.
---An internal helper function.
---Returns a new carry vector.
---@param prev Knot3 previous knot
---@param curr Knot3 current knot
---@param next Knot3 next knot
---@param carry Vec3 temporary vector
---@return Vec3
function Knot3.smoothHandlesInternal(prev, curr, next, carry)
    local coCurr = curr.co
    local coPrev = prev.co
    local coNext = next.co

    local xRear = coPrev.x - coCurr.x
    local yRear = coPrev.y - coCurr.y
    local zRear = coPrev.z - coCurr.z

    local xFore = coNext.x - coCurr.x
    local yFore = coNext.y - coCurr.y
    local zFore = coNext.z - coCurr.z

    local bmSq = xRear * xRear
        + yRear * yRear
        + zRear * zRear
    local bmInv = 0.0
    if bmSq > 0.0 then
        bmInv = 1.0 / math.sqrt(bmSq)
    end

    local fmSq = xFore * xFore
        + yFore * yFore
        + zFore * zFore
    local fmInv = 0.0
    if fmSq > 0.0 then
        fmInv = 1.0 / math.sqrt(fmSq)
    end

    local xDir = carry.x + xRear * bmInv - xFore * fmInv
    local yDir = carry.y + yRear * bmInv - yFore * fmInv
    local zDir = carry.z + zRear * bmInv - zFore * fmInv

    local rescl = 0.0
    local dmSq = xDir * xDir
        + yDir * yDir
        + zDir * zDir
    if dmSq > 0.0 then
        rescl = 1.0 / (3.0 * math.sqrt(dmSq))
    end

    local xCarry = xDir * rescl
    local yCarry = yDir * rescl
    local zCarry = zDir * rescl

    local bMag = bmSq * bmInv;
    curr.rh = Vec3.new(
        coCurr.x + bMag * xCarry,
        coCurr.y + bMag * yCarry,
        coCurr.z + bMag * zCarry)

    local fMag = fmSq * fmInv
    curr.fh = Vec3.new(
        coCurr.x - fMag * xCarry,
        coCurr.y - fMag * yCarry,
        coCurr.z - fMag * zCarry)

    return Vec3.new(xCarry, yCarry, zCarry)
end

---Smooths the fore handle of the first knot
---in an open curve.
---An internal helper function.
---Returns a new carry vector.
---@param curr Knot3 current knot
---@param next Knot3 next knot
---@param carry Vec3 temporary vector
---@return Vec3
function Knot3.smoothHandlesFirstInternal(curr, next, carry)
    local coCurr = curr.co
    local coNext = next.co

    local xRear = -coCurr.x
    local yRear = -coCurr.y
    local zRear = -coCurr.z

    local xFore = coNext.x + xRear
    local yFore = coNext.y + yRear
    local zFore = coNext.z + zRear

    local bmSq = xRear * xRear
        + yRear * yRear
        + zRear * zRear
    local bmInv = 0.0
    if bmSq > 0.0 then
        bmInv = 1.0 / math.sqrt(bmSq)
    end

    local fmSq = xFore * xFore
        + yFore * yFore
        + zFore * zFore
    local fmInv = 0.0
    if fmSq > 0.0 then
        fmInv = 1.0 / math.sqrt(fmSq)
    end

    local xDir = carry.x + xRear * bmInv - xFore * fmInv
    local yDir = carry.y + yRear * bmInv - yFore * fmInv
    local zDir = carry.z + zRear * bmInv - zFore * fmInv

    local rescl = 0.0
    local dmSq = xDir * xDir
        + yDir * yDir
        + zDir * zDir
    if dmSq > 0.0 then
        rescl = 1.0 / (3.0 * math.sqrt(dmSq))
    end

    local xCarry = xDir * rescl
    local yCarry = yDir * rescl
    local zCarry = zDir * rescl

    local fMag = fmSq * fmInv
    curr.fh = Vec3.new(
        coCurr.x - fMag * xCarry,
        coCurr.y - fMag * yCarry,
        coCurr.z - fMag * zCarry)

    return Vec3.new(xCarry, yCarry, zCarry)
end

---Smooths the rear handle of the last knot
---in an open curve.
---An internal helper function.
---Returns a new carry vector.
---@param prev Knot3 previous knot
---@param curr Knot3 current knot
---@param carry Vec3 temporary vector
---@return Vec3
function Knot3.smoothHandlesLastInternal(prev, curr, carry)
    local coCurr = curr.co
    local coPrev = prev.co

    local xFore = -coCurr.x
    local yFore = -coCurr.y
    local zFore = -coCurr.z

    local xRear = coPrev.x + xFore
    local yRear = coPrev.y + yFore
    local zRear = coPrev.z + zFore

    local bmSq = xRear * xRear
        + yRear * yRear
        + zRear * zRear
    local bmInv = 0.0
    if bmSq > 0.0 then
        bmInv = 1.0 / math.sqrt(bmSq)
    end

    local fmSq = xFore * xFore
        + yFore * yFore
        + zFore * zFore
    local fmInv = 0.0
    if fmSq > 0.0 then
        fmInv = 1.0 / math.sqrt(fmSq)
    end

    local xDir = carry.x + xRear * bmInv - xFore * fmInv
    local yDir = carry.y + yRear * bmInv - yFore * fmInv
    local zDir = carry.z + zRear * bmInv - zFore * fmInv

    local rescl = 0.0
    local dmSq = xDir * xDir
        + yDir * yDir
        + zDir * zDir
    if dmSq > 0.0 then
        rescl = 1.0 / (3.0 * math.sqrt(dmSq))
    end

    local xCarry = xDir * rescl
    local yCarry = yDir * rescl
    local zCarry = zDir * rescl

    local bMag = bmSq * bmInv
    curr.rh = Vec3.new(
        coCurr.x + bMag * xCarry,
        coCurr.y + bMag * yCarry,
        coCurr.z + bMag * zCarry)

    return Vec3.new(xCarry, yCarry, zCarry)
end

---Returns a JSON string of a knot.
---@param knot Knot3 knot
---@return string
function Knot3.toJson(knot)
    return string.format(
        "{\"co\":%s,\"fh\":%s,\"rh\":%s}",
        Vec3.toJson(knot.co),
        Vec3.toJson(knot.fh),
        Vec3.toJson(knot.rh))
end

return Knot3
