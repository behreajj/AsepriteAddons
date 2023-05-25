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
function Vec4.new(x, y, z, w)
    local inst = setmetatable({}, Vec4)
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
function Vec4.all(v)
    return v.x ~= 0.0
        and v.y ~= 0.0
        and v.z ~= 0.0
        and v.w ~= 0.0
end

---Evaluates if any vector components are non-zero.
---@param v Vec4 vector
---@return boolean
function Vec4.any(v)
    return v.x ~= 0.0
        or v.y ~= 0.0
        or v.z ~= 0.0
        or v.w ~= 0.0
end

---Evaluates whether two vectors are, within a
---tolerance, approximately equal.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@param tol number? tolerance
---@return boolean
function Vec4.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
        and math.abs(b.z - a.z) <= eps
        and math.abs(b.w - a.w) <= eps
end

---Finds the ceiling of the vector.
---@param v Vec4 vector
---@return Vec4
function Vec4.ceil(v)
    return Vec4.new(
        math.ceil(v.x),
        math.ceil(v.y),
        math.ceil(v.z),
        math.ceil(v.w))
end

---A comparator method to sort vectors
---in a table according to their highest
---dimension first.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
function Vec4.comparator(a, b)
    if a.w < b.w then return true end
    if a.w > b.w then return false end
    if a.z < b.z then return true end
    if a.z > b.z then return false end
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand
---to the magnitude of the left. Both
---operands are assumed to be Vec4s. Where
---the sign of b is zero, the result is zero.
---Equivalent to multiplying the
---absolute value of a and the sign of b.
---@param a Vec4 magnitude
---@param b Vec4 sign
---@return Vec4
function Vec4.copySign(a, b)
    local cx = 0.0
    local axAbs = math.abs(a.x)
    if b.x < -0.0 then
        cx = -axAbs
    elseif b.x > 0.0 then
        cx = axAbs
    end

    local cy = 0.0
    local ayAbs = math.abs(a.y)
    if b.y < -0.0 then
        cy = -ayAbs
    elseif b.y > 0.0 then
        cy = ayAbs
    end

    local cz = 0.0
    local azAbs = math.abs(a.z)
    if b.z < -0.0 then
        cz = -azAbs
    elseif b.z > 0.0 then
        cz = azAbs
    end

    local cw = 0.0
    local awAbs = math.abs(a.w)
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
function Vec4.div(a, b)
    local cx = 0.0
    local cy = 0.0
    local cz = 0.0
    local cw = 0.0
    if b.x ~= 0.0 then cx = a.x / b.x end
    if b.y ~= 0.0 then cy = a.y / b.y end
    if b.z ~= 0.0 then cz = a.z / b.z end
    if b.w ~= 0.0 then cw = a.w / b.w end
    return Vec4.new(cx, cy, cz, cw)
end

---Finds the dot product between two vectors.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return number
function Vec4.dot(a, b)
    return a.x * b.x
        + a.y * b.y
        + a.z * b.z
        + a.w * b.w
end

---Evaluates whether two vectors are exactly
---equal. Checks for reference equality prior
---to value equality.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
function Vec4.equals(a, b)
    return rawequal(a, b)
        or Vec4.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly
---equal by component value.
---@param a Vec4 left comparisand
---@param b Vec4 right comparisand
---@return boolean
function Vec4.equalsValue(a, b)
    return a.w == b.w
        and a.z == b.z
        and a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param v Vec4 vector
---@return Vec4
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
function Vec4.floorDiv(a, b)
    local cx = 0.0
    local cy = 0.0
    local cz = 0.0
    local cw = 0.0
    if b.x ~= 0.0 then cx = a.x // b.x end
    if b.y ~= 0.0 then cy = a.y // b.y end
    if b.z ~= 0.0 then cz = a.z // b.z end
    if b.w ~= 0.0 then cw = a.w // b.w end
    return Vec4.new(cx, cy, cz, cw)
end

---Finds the fractional portion of of a vector.
---Subtracts the truncation of each component
---from itself, not the floor, unlike in GLSL.
---@param v Vec4 vector
---@return Vec4
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
function Vec4.hashCode(v)
    local xBits = string.unpack("i4",
        string.pack("f", v.x))
    local yBits = string.unpack("i4",
        string.pack("f", v.y))
    local zBits = string.unpack("i4",
        string.pack("f", v.z))
    local wBits = string.unpack("i4",
        string.pack("f", v.w))

    return (((84696351 ~ xBits)
        * 16777619 ~ yBits)
        * 16777619 ~ zBits)
        * 16777619 ~ wBits
end

---Finds the linear step between a left and
---right edge given a factor.
---@param edge0 Vec4 left edge
---@param edge1 Vec4 right edge
---@param x Vec4 factor
---@return Vec4
function Vec4.linearstep(edge0, edge1, x)
    local cx = 0.0
    local xDenom = edge1.x - edge0.x
    if xDenom ~= 0.0 then
        cx = math.min(1.0, math.max(0.0,
            (x.x - edge0.x) / xDenom))
    end

    local cy = 0.0
    local yDenom = edge1.y - edge0.y
    if yDenom ~= 0.0 then
        cy = math.min(1.0, math.max(0.0,
            (x.y - edge0.y) / yDenom))
    end

    local cz = 0.0
    local zDenom = edge1.z - edge0.z
    if zDenom ~= 0.0 then
        cz = math.min(1.0, math.max(0.0,
            (x.z - edge0.z) / zDenom))
    end

    local cw = 0.0
    local wDenom = edge1.w - edge0.w
    if wDenom ~= 0.0 then
        cw = math.min(1.0, math.max(0.0,
            (x.w - edge0.w) / wDenom))
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Finds a vector's magnitude, or length.
---@param v Vec4 vector
---@return number
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
function Vec4.min(a, b)
    return Vec4.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.min(a.z, b.z),
        math.min(a.w, b.w))
end

---Mixes two vectors together by a step.
---Defaults to mixing by a vector.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t Vec4|number step
---@return Vec4
function Vec4.mix(a, b, t)
    if type(t) == "number" then
        return Vec4.mixNum(a, b, t)
    end
    return Vec4.mixVec4(a, b, t)
end

---Mixes two vectors together by a step.
---The step is a number.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t number step
---@return Vec4
function Vec4.mixNum(a, b, t)
    local v = t or 0.5
    local u = 1.0 - v
    return Vec4.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y,
        u * a.z + v * b.z,
        u * a.w + v * b.w)
end

---Mixes two vectors together by a step.
---The step is a vector. Use in conjunction
---with step, linearstep and smoothstep.
---@param a Vec4 origin
---@param b Vec4 destination
---@param t Vec4 step
---@return Vec4
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
function Vec4.mod(a, b)
    local cx = a.x
    local cy = a.y
    local cz = a.z
    local cw = a.w
    if b.x ~= 0.0 then cx = a.x % b.x end
    if b.y ~= 0.0 then cy = a.y % b.y end
    if b.z ~= 0.0 then cz = a.z % b.z end
    if b.w ~= 0.0 then cw = a.w % b.w end
    return Vec4.new(cx, cy, cz, cw)
end

---Negates a vector.
---@param v Vec4 vector
---@return Vec4
function Vec4.negate(v)
    return Vec4.new(-v.x, -v.y, -v.z, -v.w)
end

---Evaluates if all vector components are zero.
---@param v Vec4 vector
---@return boolean
function Vec4.none(v)
    return v.x == 0.0
        and v.y == 0.0
        and v.z == 0.0
        and v.w == 0.0
end

---Divides a vector by its magnitude, such that it
---lies on the unit circle.
---@param v Vec4 vector
---@return Vec4
function Vec4.normalize(v)
    local mSq = v.x * v.x
        + v.y * v.y
        + v.z * v.z
        + v.w * v.w
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
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
function Vec4.pow(a, b)
    return Vec4.new(
        a.x ^ b.x,
        a.y ^ b.y,
        a.z ^ b.z,
        a.w ^ b.w)
end

---Reduces the granularity of a vector's components.
---@param v Vec4 vector
---@param levels integer levels
---@return Vec4
function Vec4.quantize(v, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec4.new(
            delta * math.floor(0.5 + v.x * levels),
            delta * math.floor(0.5 + v.y * levels),
            delta * math.floor(0.5 + v.z * levels),
            delta * math.floor(0.5 + v.w * levels))
    end
    return Vec4.new(v.x, v.y, v.z, v.w)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. If lower and upper
---bounds are not given, defaults to [-1.0, 1.0].
---@param lb Vec4? lower bound
---@param ub Vec4? upper bound
---@return Vec4
function Vec4.randomCartesian(lb, ub)
    local lval = lb or Vec4.new(-1.0, -1.0, -1.0, -1.0)
    local uval = ub or Vec4.new(1.0, 1.0, 1.0, 1.0)
    return Vec4.randomCartesianInternal(lval, uval)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. Does not validate
---upper or lower bounds.
---@param lb Vec4 lower bound
---@param ub Vec4 upper bound
---@return Vec4
function Vec4.randomCartesianInternal(lb, ub)
    local rx = math.random()
    local ry = math.random()
    local rz = math.random()
    local rw = math.random()

    return Vec4.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y,
        (1.0 - rz) * lb.z + rz * ub.z,
        (1.0 - rw) * lb.w + rw * ub.w)
end

---Rounds the vector by sign and fraction.
---@param v Vec4 left operand
---@return Vec4
function Vec4.round(v)
    local ix, fx = math.modf(v.x)
    if ix <= 0 and fx <= -0.5 then
        ix = ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        ix = ix + 1
    end

    local iy, fy = math.modf(v.y)
    if iy <= 0 and fy <= -0.5 then
        iy = iy - 1
    elseif iy >= 0 and fy >= 0.5 then
        iy = iy + 1
    end

    local iz, fz = math.modf(v.z)
    if iz <= 0 and fz <= -0.5 then
        iz = iz - 1
    elseif iz >= 0 and fz >= 0.5 then
        iz = iz + 1
    end

    local iw, fw = math.modf(v.w)
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
function Vec4.sign(v)
    local cx = 0.0
    if v.x < -0.0 then
        cx = -1.0
    elseif v.x > 0.0 then
        cx = 1.0
    end

    local cy = 0.0
    if v.y < -0.0 then
        cy = -1.0
    elseif v.y > 0.0 then
        cy = 1.0
    end

    local cz = 0.0
    if v.z < -0.0 then
        cz = -1.0
    elseif v.z > 0.0 then
        cz = 1.0
    end

    local cw = 0.0
    if v.w < -0.0 then
        cw = -1.0
    elseif v.w > 0.0 then
        cw = 1.0
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Finds the smooth step between a left and
---right edge given a factor.
---@param edge0 Vec4 left edge
---@param edge1 Vec4 right edge
---@param x Vec4 factor
---@return Vec4
function Vec4.smoothstep(edge0, edge1, x)
    local cx = 0.0
    local xDenom = edge1.x - edge0.x
    if xDenom ~= 0.0 then
        cx = math.min(1.0, math.max(0.0,
            (x.x - edge0.x) / xDenom))
        cx = cx * cx * (3.0 - (cx + cx))
    end

    local cy = 0.0
    local yDenom = edge1.y - edge0.y
    if yDenom ~= 0.0 then
        cy = math.min(1.0, math.max(0.0,
            (x.y - edge0.y) / yDenom))
        cy = cy * cy * (3.0 - (cy + cy))
    end

    local cz = 0.0
    local zDenom = edge1.z - edge0.z
    if zDenom ~= 0.0 then
        cz = math.min(1.0, math.max(0.0,
            (x.z - edge0.z) / zDenom))
        cz = cz * cz * (3.0 - (cz + cz))
    end

    local cw = 0.0
    local wDenom = edge1.w - edge0.w
    if wDenom ~= 0.0 then
        cw = math.min(1.0, math.max(0.0,
            (x.w - edge0.w) / wDenom))
        cw = cw * cw * (3.0 - (cw + cw))
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Finds the step between an edge and factor.
---@param edge Vec4 edge
---@param x Vec4 factor
---@return Vec4
function Vec4.step(edge, x)
    local cx = 1.0
    if x.x < edge.x then cx = 0.0 end

    local cy = 1.0
    if x.y < edge.y then cy = 0.0 end

    local cz = 1.0
    if x.z < edge.z then cz = 0.0 end

    local cw = 1.0
    if x.w < edge.w then cw = 0.0 end

    return Vec4.new(cx, cy, cz, cw)
end

---Subtracts the right vector from the left.
---@param a Vec4 left operand
---@param b Vec4 right operand
---@return Vec4
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
function Vec4.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f,\"z\":%.4f,\"w\":%.4f}",
        v.x, v.y, v.z, v.w)
end

---Truncates a vector's components.
---@param v Vec4 vector
---@return Vec4
function Vec4.trunc(v)
    return Vec4.new(
        v.x - math.fmod(v.x, 1.0),
        v.y - math.fmod(v.y, 1.0),
        v.z - math.fmod(v.z, 1.0),
        v.w - math.fmod(v.w, 1.0))
end

---Wraps a vector's components around a range
---defined by a lower and upper bound. If the
---range is invalid, the component is unchanged.
---@param v Vec4 vector
---@param lb Vec4 lower bound
---@param ub Vec4 upper bound
---@return Vec4
function Vec4.wrap(v, lb, ub)
    local cx = v.x
    local rx = ub.x - lb.x
    if rx ~= 0.0 then
        cx = v.x - rx * ((v.x - lb.x) // rx)
    end

    local cy = v.y
    local ry = ub.y - lb.y
    if ry ~= 0.0 then
        cy = v.y - ry * ((v.y - lb.y) // ry)
    end

    local cz = v.z
    local rz = ub.z - lb.z
    if rz ~= 0.0 then
        cz = v.z - rz * ((v.z - lb.z) // rz)
    end

    local cw = v.w
    local rw = ub.w - lb.w
    if rw ~= 0.0 then
        cw = v.w - rw * ((v.w - lb.w) // rw)
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Creates a right facing vector,
---(1.0, 0.0, 0.0, 0.0).
---@return Vec4
function Vec4.right()
    return Vec4.new(1.0, 0.0, 0.0, 0.0)
end

---Creates a forward facing vector,
---(0.0, 1.0, 0.0, 0.0).
---@return Vec4
function Vec4.forward()
    return Vec4.new(0.0, 1.0, 0.0, 0.0)
end

---Creates an up facing vector,
---(0.0, 0.0, 1.0, 0.0).
---@return Vec4
function Vec4.up()
    return Vec4.new(0.0, 0.0, 1.0, 0.0)
end

---Creates a left facing vector,
---(-1.0, 0.0, 0.0, 0.0).
---@return Vec4
function Vec4.left()
    return Vec4.new(-1.0, 0.0, 0.0, 0.0)
end

---Creates a back facing vector,
---(0.0, -1.0, 0.0, 0.0).
---@return Vec4
function Vec4.back()
    return Vec4.new(0.0, -1.0, 0.0, 0.0)
end

---Creates a down facing vector,
---(0.0, 0.0, -1.0, 0.0).
---@return Vec4
function Vec4.down()
    return Vec4.new(0.0, 0.0, -1.0, 0.0)
end

---Creates a vector with all components
---set to 1.0.
---@return Vec4
function Vec4.one()
    return Vec4.new(1.0, 1.0, 1.0, 1.0)
end

return Vec4