dofile("./vec3.lua")

Quaternion = {}
Quaternion.__index = Quaternion

setmetatable(Quaternion, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new quaternion.
---Defaults to passing the vector by value.
---@param real number real
---@param imag table imaginary
---@return table
function Quaternion.new(real, imag)
    return Quaternion.newByVal(real, imag)
end

---Constructs a new quaternion.
---The imaginary vector is assigned by reference.
---@param real number real
---@param imag table imaginary
---@return table
function Quaternion.newByRef(real, imag)
    local inst = setmetatable({}, Quaternion)
    inst.real = real or 1.0
    inst.imag = imag or Vec3.new(0.0, 0.0, 0.0)
    return inst
end

---Constructs a new quaternion.
---The imaginary vector is copied by value.
---@param real number real
---@param imag table imaginary
---@return table
function Quaternion.newByVal(real, imag)
    local inst = setmetatable({}, Quaternion)
    inst.real = real or 1.0
    inst.imag = Vec3.new(imag.x, imag.y, imag.z)
        or Vec3.new(0.0, 0.0, 0.0)
    return inst
end

function Quaternion:__add(b)
    return Quaternion.add(self, b)
end

function Quaternion:__div(b)
    return Quaternion.div(self, b)
end

function Quaternion:__eq(b)
    return self.real == b.real
       and self.imag == b.imag
end

function Quaternion:__len()
    return 4
end

function Quaternion:__mul(b)
    return Quaternion.mul(self, b)
end

function Quaternion:__sub(b)
    return Quaternion.sub(self, b)
end

function Quaternion:__tostring()
    return Quaternion.toJson(self)
end

function Quaternion:__unm()
    return Quaternion.negate(self)
end

---Finds the sum of two quaternions.
---@param a table left operand
---@param b table right operand
---@return table
function Quaternion.add(a, b)
    local ai = a.imag
    local bi = b.imag
    return Quaternion.newByRef(
        a.real + b.real,
        Vec3.new(
            ai.x + bi.x,
            ai.y + bi.y,
            ai.z + bi.z))
end

---Evaluates whether two quaternions are,
---within a tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol number tolerance
---@return boolean
function Quaternion.approx(a, b, tol)
    local ai = a.imag
    local bi = b.imag
    local eps = tol or 0.000001
    return math.abs(b.real - a.real) <= eps
       and math.abs(bi.x - ai.x) <= eps
       and math.abs(bi.y - ai.y) <= eps
       and math.abs(bi.z - ai.z) <= eps
end

---Finds the conjugate of a quaternion.
---@param a table left operand
---@return table
function Quaternion.conj(a)
    local ai = a.imag
    return Quaternion.newByRef(
        a.real,
        Vec3.new(-ai.x, -ai.y, -ai.z))
end

---Divides the left quaternion by the right.
---@param a table left operand
---@param b table right operand
---@return table
function Quaternion.div(a, b)
    local bi = b.imag
    local bw = b.real
    local bx = bi.x
    local by = bi.y
    local bz = bi.z

    local bmSq = bw * bw + bx * bx + by * by + bz * bz
    if bmSq ~= 0.0 then
        local bmSqInv = 1.0 / bmSq
        local bwInv = bw * bmSqInv
        local bxInv = -bx * bmSqInv
        local byInv = -by * bmSqInv
        local bzInv = -bz * bmSqInv

        local ai = a.imag
        local aw = a.real

        return Quaternion.newByRef(
            aw * bwInv - ai.x * bxInv - ai.y * byInv - ai.z * bzInv,
            Vec3.new(
                ai.x * bwInv + aw * bxInv + ai.y * bzInv - ai.z * byInv,
                ai.y * bwInv + aw * byInv + ai.z * bxInv - ai.x * bzInv,
                ai.z * bwInv + aw * bzInv + ai.x * byInv - ai.y * bxInv))
    else
        return Quaternion.identity()
    end
end

---Finds the dot product between two quaternions.
---@param a table left operand
---@param b table right operand
---@return number
function Quaternion.dot(a, b)
    local ai = a.imag
    local bi = b.imag
    return a.real * b.real
        + ai.x * bi.x
        + ai.y * bi.y
        + ai.z * bi.z
end

---Finds the inverse of a quaternion.
---@param a table left operand
---@return table
function Quaternion.inverse(a)
    local ai = a.imag
    local mSq = a.real * a.real
        + ai.x * ai.x
        + ai.y * ai.y
        + ai.z * ai.z
    if mSq ~= 0.0 then
        local mSqInv = 1.0 / mSq
        return Quaternion.newByRef(
            a.real * mSqInv,
            Vec3.new(
                -ai.x * mSqInv,
                -ai.y * mSqInv,
                -ai.z * mSqInv))
    else
        return Quaternion.identity()
    end
end

---Finds a quaternion's magnitude, or length.
---@param a table left operand
---@return number
function Quaternion.mag(a)
    local ai = a.imag
    return math.sqrt(
        a.real * a.real
        + ai.x * ai.x
        + ai.y * ai.y
        + ai.z * ai.z)
end

---Finds a quaternion's magnitude squared.
---@param a table left operand
---@return number
function Quaternion.magSq(a)
    local ai = a.imag
    return a.real * a.real
        + ai.x * ai.x
        + ai.y * ai.y
        + ai.z * ai.z
end

---Multiplies two quaternions.
---Multiplication is not commutative.
---@param a table left operand
---@param b table right operand
---@return table
function Quaternion.mul(a, b)
    local ai = a.imag
    local bi = b.imag
    local aw = a.real
    local bw = b.real

    return Quaternion.newByRef(
        aw * bw - (ai.x * bi.x + ai.y * bi.y + ai.z * bi.z),
        Vec3.new(
            ai.x * bw + aw * bi.x + ai.y * bi.z - ai.z * bi.y,
            ai.y * bw + aw * bi.y + ai.z * bi.x - ai.x * bi.z,
            ai.z * bw + aw * bi.z + ai.x * bi.y - ai.y * bi.x))
end

---Negates a quaternion
---@param a table quaternion
---@return table
function Quaternion.negate(a)
    local ai = a.imag
    return Quaternion.newByRef(
        -a.real,
        Vec3.new(-ai.x, -ai.y, -ai.z))
end

---Divides a quaternion by its magnitude so
---that it is a versor on the unit hypersphere.
---@param a table quaternion
---@return table
function Quaternion.normalize(a)
    local ai = a.imag
    local mSq = a.real * a.real
        + ai.x * ai.x
        + ai.y * ai.y
        + ai.z * ai.z
    if mSq ~= 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Quaternion.newByRef(
            a.real * mInv,
            Vec3.new(
                ai.x * mInv,
                ai.y * mInv,
                ai.z * mInv))
    else
        return Quaternion.identity()
    end
end

---Creates a random quaternion.
---@return table
function Quaternion.random()
    local t0 = math.random() * 6.283185307179586
    local t1 = math.random() * 6.283185307179586
    local r1 = math.random()
    local x0 = math.sqrt(1.0 - r1)
    local x1 = math.sqrt(r1)
    return Quaternion.newByRef(
        x0 * math.sin(t0),
        Vec3.new(
            x0 * math.cos(t0),
            x1 * math.sin(t1),
            x1 * math.cos(t1)))
end

---Rotates a quaternion around the x axis by an angle
---in radians.
---@param q table quaternion
---@param radians number angle
---@return table
function Quaternion.rotateX(q, radians)
    local half = 0.5 * math.fmod(radians, 6.283185307179586)
    return Quaternion.rotateXInternal(
        q, math.cos(half), math.sin(half))
end

---Rotates a quaternion around the y axis by an angle
---in radians.
---@param q table quaternion
---@param radians number angle
---@return table
function Quaternion.rotateY(q, radians)
    local half = 0.5 * math.fmod(radians, 6.283185307179586)
    return Quaternion.rotateYInternal(
        q, math.cos(half), math.sin(half))
end

---Rotates a quaternion around the z axis by an angle
---in radians.
---@param q table quaternion
---@param radians number angle
---@return table
function Quaternion.rotateZ(q, radians)
    local half = 0.5 * math.fmod(radians, 6.283185307179586)
    return Quaternion.rotateZInternal(
        q, math.cos(half), math.sin(half))
end

---Rotates a quaternion around the x axis.
---Internal helper that takes cosine and sine of
---half the angle.
---@param q table quaternion
---@param cosah number cosine of half angle
---@param sinah number sine of half angle
---@return table
function Quaternion.rotateXInternal(q, cosah, sinah)
    local i = q.imag
    return Quaternion.newByRef(
        cosah * q.real - sinah * i.x,
        Vec3.new(
            cosah * i.x + sinah * q.real,
            cosah * i.y + sinah * i.z,
            cosah * i.z - sinah * i.y))
end

---Rotates a quaternion around the y axis.
---Internal helper that takes cosine and sine of
---half the angle.
---@param q table quaternion
---@param cosah number cosine of half angle
---@param sinah number sine of half angle
---@return table
function Quaternion.rotateYInternal(q, cosah, sinah)
    local i = q.imag
    return Quaternion.newByRef(
        cosah * q.real - sinah * i.y,
        Vec3.new(
            cosah * i.x - sinah * i.z,
            cosah * i.y + sinah * q.real,
            cosah * i.z + sinah * i.x))
end

---Rotates a quaternion around the z axis.
---Internal helper that takes cosine and sine of
---half the angle.
---@param q table quaternion
---@param cosah number cosine of half angle
---@param sinah number sine of half angle
---@return table
function Quaternion.rotateZInternal(q, cosah, sinah)
    local i = q.imag
    return Quaternion.newByRef(
        cosah * q.real - sinah * i.z,
        Vec3.new(
            cosah * i.x + sinah * i.y,
            cosah * i.y - sinah * i.x,
            cosah * i.z + sinah * q.real))
end

---Scales a quaternion, left, by a number, right.
---@param a table left operand
---@param b number right operand
---@return table
function Quaternion.scale(a, b)
    if b ~= 0.0 then
        local ai = a.imag
        return Quaternion.newByRef(
            a.real * b,
            Vec3.new(
                ai.x * b,
                ai.y * b,
                ai.z * b))
    else
        return Quaternion.identity()
    end
end

---Subtracts the right quaternion from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Quaternion.sub(a, b)
    local ai = a.imag
    local bi = b.imag
    return Quaternion.newByRef(
        a.real - b.real,
        Vec3.new(
            ai.x - bi.x,
            ai.y - bi.y,
            ai.z - bi.z))
end

---Returns a JSON string of a quaternion.
---@param q table quaternion
---@return string
function Quaternion.toJson(q)
    return string.format(
        "{\"real\":%.4f,\"imag\":%s}",
        q.real,
        Vec3.toJson(q.imag))
end

---Returns the identity quaternion,
---(1.0, 0.0, 0.0, 0.0).
---@return table
function Quaternion.identity()
    return Quaternion.newByRef(
        1.0, Vec3.new(0.0, 0.0, 0.0))
end

return Quaternion