---@class Vec4
---@field public x number x component
---@field public y number y component
---@field public z number z component
---@field public w number w component
---@operator add(Vec4): Vec4
---@operator div(Vec4): Vec4
---@operator idiv(Vec4): Vec4
---@operator len(): integer
---@operator mod(Vec4): Vec4
---@operator mul(Vec4|number): Vec4
---@operator pow(Vec4): Vec4
---@operator sub(Vec4): Vec4
---@operator unm(): Vec4
Vec4 = {}
Vec4.__index = Vec4

setmetatable(Vec4, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new vector from four numbers.
---@param x number? x component
---@param y number? y component
---@param z number? z component
---@param w number? w component
---@return Vec4
---@nodiscard
function Vec4.new(x, y, z, w)
    local inst <const> = setmetatable({}, Vec4)
    inst.x = x or 0.0
    inst.y = y or 0.0
    inst.z = z or 0.0
    inst.w = w or 0.0
    return inst
end

function Vec4:__add(b)
    return Vec4.add(self, b)
end

function Vec4:__div(b)
    return Vec4.div(self, b)
end

function Vec4:__eq(b)
    return Vec4.equals(self, b)
end

function Vec4:__idiv(b)
    return Vec4.floorDiv(self, b)
end

function Vec4:__le(b)
    return Vec4.equals(self, b)
        or Vec4.comparator(self, b)
end

function Vec4:__len()
    return 4
end

function Vec4:__lt(b)
    return Vec4.comparator(self, b)
end

function Vec4:__mod(b)
    return Vec4.mod(self, b)
end

function Vec4:__mul(b)
    if type(b) == "number" then
        return Vec4.scale(self, b)
    elseif type(self) == "number" then
        return Vec4.scale(b, self)
    else
        return Vec4.hadamard(self, b)
    end
end

function Vec4:__pow(b)
    return Vec4.pow(self, b)
end

function Vec4:__sub(b)
    return Vec4.sub(self, b)
end

function Vec4:__tostring()
    return Vec4.toJson(self)
end

function Vec4:__unm()
    return Vec4.negate(self)
end

---Finds a vector's absolute value, component-wise.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.abs(v)
    return Vec4.new(
        math.abs(v.x),
        math.abs(v.y),
        math.abs(v.z),
        math.abs(v.w))
end

---Finds the sum of two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.add(a, b)
    return Vec4.new(
        a.x + b.x,
        a.y + b.y,
        a.z + b.z,
        a.w + b.w)
end

---Evaluates if all vector components are non-zero.
---@param v Vec4 vector
---@return boolean
---@nodiscard
function Vec4.all(v)
    return v.x ~= 0.0
        and v.y ~= 0.0
        and v.z ~= 0.0
        and v.w ~= 0.0
end

---Evaluates if any vector components are non-zero.
---@param v Vec4 vector
---@return boolean
---@nodiscard
function Vec4.any(v)
    return v.x ~= 0.0
        or v.y ~= 0.0
        or v.z ~= 0.0
        or v.w ~= 0.0
end

---Evaluates whether two vectors are, within a tolerance, approximately equal.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Vec4.approx(a, b, tol)
    local eps <const> = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
        and math.abs(b.z - a.z) <= eps
        and math.abs(b.w - a.w) <= eps
end

---Finds the ceiling of the vector.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.ceil(v)
    return Vec4.new(
        math.ceil(v.x),
        math.ceil(v.y),
        math.ceil(v.z),
        math.ceil(v.w))
end

---A comparator method to sort vectors in a table according to their highest
---dimension first.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
---@nodiscard
function Vec4.comparator(a, b)
    if a.w < b.w then return true end
    if a.w > b.w then return false end
    if a.z < b.z then return true end
    if a.z > b.z then return false end
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand to the magnitude of the left. Both
---operands are assumed to be Vec4s. Where the sign of b is zero, the result is
---zero.
---@param a Vec4 magnitude
---@param b Vec4 sign
---@return Vec4
---@nodiscard
function Vec4.copySign(a, b)
    local cx, cy, cz, cw = 0.0, 0.0, 0.0, 0.0

    local axAbs <const> = math.abs(a.x)
    if b.x < -0.0 then
        cx = -axAbs
    elseif b.x > 0.0 then
        cx = axAbs
    end

    local ayAbs <const> = math.abs(a.y)
    if b.y < -0.0 then
        cy = -ayAbs
    elseif b.y > 0.0 then
        cy = ayAbs
    end

    local azAbs <const> = math.abs(a.z)
    if b.z < -0.0 then
        cz = -azAbs
    elseif b.z > 0.0 then
        cz = azAbs
    end

    local awAbs <const> = math.abs(a.w)
    if b.w < -0.0 then
        cw = -awAbs
    elseif b.w > 0.0 then
        cw = awAbs
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Divides the left vector by the right, component-wise.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.div(a, b)
    return Vec4.new(
        b.x ~= 0.0 and a.x / b.x or 0.0,
        b.y ~= 0.0 and a.y / b.y or 0.0,
        b.z ~= 0.0 and a.z / b.z or 0.0,
        b.w ~= 0.0 and a.w / b.w or 0.0)
end

---Finds the dot product between two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return number
---@nodiscard
function Vec4.dot(a, b)
    return a.x * b.x
        + a.y * b.y
        + a.z * b.z
        + a.w * b.w
end

---Evaluates whether two vectors are exactly equal. Checks for reference
---equality prior to value equality.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
---@nodiscard
function Vec4.equals(a, b)
    return rawequal(a, b)
        or Vec4.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly equal by component value.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
---@nodiscard
function Vec4.equalsValue(a, b)
    return a.w == b.w
        and a.z == b.z
        and a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.floor(v)
    return Vec4.new(
        math.floor(v.x),
        math.floor(v.y),
        math.floor(v.z),
        math.floor(v.w))
end

---Finds the floor division of two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.floorDiv(a, b)
    return Vec4.new(
        b.x ~= 0.0 and a.x // b.x or 0.0,
        b.y ~= 0.0 and a.y // b.y or 0.0,
        b.z ~= 0.0 and a.z // b.z or 0.0,
        b.w ~= 0.0 and a.w // b.w or 0.0)
end

---Finds the fractional portion of of a vector. Subtracts the truncation of
---each component from itself, not the floor, unlike in GLSL.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.fract(v)
    return Vec4.new(
        math.fmod(v.x, 1.0),
        math.fmod(v.y, 1.0),
        math.fmod(v.z, 1.0),
        math.fmod(v.w, 1.0))
end

---Multiplies two vectors component-wise.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.hadamard(a, b)
    return Vec4.new(
        a.x * b.x,
        a.y * b.y,
        a.z * b.z,
        a.w * b.w)
end

---Finds an integer hash code for a vector.
---@param v Vec4 vector
---@return integer
---@nodiscard
function Vec4.hashCode(v)
    local xBits <const> = string.unpack("i4", string.pack("f", v.x))
    local yBits <const> = string.unpack("i4", string.pack("f", v.y))
    local zBits <const> = string.unpack("i4", string.pack("f", v.z))
    local wBits <const> = string.unpack("i4", string.pack("f", v.w))
    return (((84696351 ~ xBits) * 16777619 ~ yBits) * 16777619 ~ zBits)
        * 16777619 ~ wBits
end

---Finds a vector's magnitude, or length.
---@param v Vec4 vector
---@return number
---@nodiscard
function Vec4.mag(v)
    return math.sqrt(
        v.x * v.x
        + v.y * v.y
        + v.z * v.z
        + v.w * v.w)
end

---Finds a vector's magnitude squared.
---@param v Vec4 vector
---@return number
---@nodiscard
function Vec4.magSq(v)
    return v.x * v.x
        + v.y * v.y
        + v.z * v.z
        + v.w * v.w
end

---Finds the greater of two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.max(a, b)
    return Vec4.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        math.max(a.z, b.z),
        math.max(a.w, b.w))
end

---Finds the lesser of two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.min(a, b)
    return Vec4.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.min(a.z, b.z),
        math.min(a.w, b.w))
end

---Mixes two vectors together by a step. Defaults to mixing by a vector.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t Vec4|number step
---@return Vec4
---@nodiscard
function Vec4.mix(a, b, t)
    if type(t) == "number" then
        return Vec4.mixNum(a, b, t)
    end
    return Vec4.mixVec4(a, b, t)
end

---Mixes two vectors together by a step.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t number? step
---@return Vec4
---@nodiscard
function Vec4.mixNum(a, b, t)
    local v <const> = t or 0.5
    local u <const> = 1.0 - v
    return Vec4.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y,
        u * a.z + v * b.z,
        u * a.w + v * b.w)
end

---Mixes two vectors together by a step. The step is a vector.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t Vec4 step
---@return Vec4
---@nodiscard
function Vec4.mixVec4(a, b, t)
    return Vec4.new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y,
        (1.0 - t.z) * a.z + t.z * b.z,
        (1.0 - t.w) * a.w + t.w * b.w)
end

---Finds the remainder of floor division of two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.mod(a, b)
    return Vec4.new(
        b.x ~= 0.0 and a.x % b.x or a.x,
        b.y ~= 0.0 and a.y % b.y or a.y,
        b.z ~= 0.0 and a.z % b.z or a.z,
        b.w ~= 0.0 and a.w % b.w or a.w)
end

---Negates a vector.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.negate(v)
    return Vec4.new(-v.x, -v.y, -v.z, -v.w)
end

---Evaluates if all vector components are zero.
---@param v Vec4 vector
---@return boolean
---@nodiscard
function Vec4.none(v)
    return v.x == 0.0
        and v.y == 0.0
        and v.z == 0.0
        and v.w == 0.0
end

---Divides a vector by its magnitude, such that it lies on the unit circle.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.normalize(v)
    local mSq <const> = v.x * v.x
        + v.y * v.y
        + v.z * v.z
        + v.w * v.w
    if mSq > 0.0 then
        local mInv <const> = 1.0 / math.sqrt(mSq)
        return Vec4.new(
            v.x * mInv,
            v.y * mInv,
            v.z * mInv,
            v.w * mInv)
    end
    return Vec4.new(0.0, 0.0, 0.0, 0.0)
end

---Raises a vector to the power of another.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.pow(a, b)
    return Vec4.new(
        a.x ^ b.x,
        a.y ^ b.y,
        a.z ^ b.z,
        a.w ^ b.w)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---If lower and upper bounds are not given, defaults to [-1.0, 1.0].
---@param lb Vec4? lower bound
---@param ub Vec4? upper bound
---@return Vec4
---@nodiscard
function Vec4.randomCartesian(lb, ub)
    local lVrf <const> = lb or Vec4.new(-1.0, -1.0, -1.0, -1.0)
    local uVrf <const> = ub or Vec4.new(1.0, 1.0, 1.0, 1.0)
    return Vec4.randomCartesianInternal(lVrf, uVrf)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---Does not validate upper or lower bounds.
---@param lb Vec4 lower bound
---@param ub Vec4 upper bound
---@return Vec4
---@nodiscard
function Vec4.randomCartesianInternal(lb, ub)
    local rx <const> = math.random()
    local ry <const> = math.random()
    local rz <const> = math.random()
    local rw <const> = math.random()

    return Vec4.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y,
        (1.0 - rz) * lb.z + rz * ub.z,
        (1.0 - rw) * lb.w + rw * ub.w)
end

---Rounds the vector by sign and fraction.
---@param v Vec4 left operand
---@return Vec4
---@nodiscard
function Vec4.round(v)
    local ix, fx <const> = math.modf(v.x)
    if ix <= 0 and fx <= -0.5 then
        ix = ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        ix = ix + 1
    end

    local iy, fy <const> = math.modf(v.y)
    if iy <= 0 and fy <= -0.5 then
        iy = iy - 1
    elseif iy >= 0 and fy >= 0.5 then
        iy = iy + 1
    end

    local iz, fz <const> = math.modf(v.z)
    if iz <= 0 and fz <= -0.5 then
        iz = iz - 1
    elseif iz >= 0 and fz >= 0.5 then
        iz = iz + 1
    end

    local iw, fw <const> = math.modf(v.w)
    if iw <= 0 and fw <= -0.5 then
        iw = iw - 1
    elseif iw >= 0 and fw >= 0.5 then
        iw = iw + 1
    end

    return Vec4.new(ix, iy, iz, iw)
end

---Scales a vector, left, by a number, right.
---@param a Vec4 left operand
---@param b number right operand
---@return Vec4
---@nodiscard
function Vec4.scale(a, b)
    return Vec4.new(
        a.x * b,
        a.y * b,
        a.z * b,
        a.w * b)
end

---Finds the sign of a vector by component.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.sign(v)
    return Vec4.new(
        v.x < -0.0 and -1.0 or v.x > 0.0 and 1.0 or 0.0,
        v.y < -0.0 and -1.0 or v.y > 0.0 and 1.0 or 0.0,
        v.z < -0.0 and -1.0 or v.z > 0.0 and 1.0 or 0.0,
        v.w < -0.0 and -1.0 or v.w > 0.0 and 1.0 or 0.0)
end

---Subtracts the right vector from the left.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
---@nodiscard
function Vec4.sub(a, b)
    return Vec4.new(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z,
        a.w - b.w)
end

---Returns a JSON string of a vector.
---@param v Vec4 vector
---@return string
---@nodiscard
function Vec4.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f,\"z\":%.4f,\"w\":%.4f}",
        v.x, v.y, v.z, v.w)
end

---Truncates a vector's components.
---@param v Vec4 vector
---@return Vec4
---@nodiscard
function Vec4.trunc(v)
    return Vec4.new(
        v.x - math.fmod(v.x, 1.0),
        v.y - math.fmod(v.y, 1.0),
        v.z - math.fmod(v.z, 1.0),
        v.w - math.fmod(v.w, 1.0))
end

return Vec4