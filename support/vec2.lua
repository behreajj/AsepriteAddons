---@class Vec2
---@field public x number x component
---@field public y number y component
---@operator add(Vec2): Vec2
---@operator div(Vec2): Vec2
---@operator idiv(Vec2): Vec2
---@operator len(): integer
---@operator mod(Vec2): Vec2
---@operator mul(Vec2|number): Vec2
---@operator pow(Vec2): Vec2
---@operator sub(Vec2): Vec2
---@operator unm(): Vec2
Vec2 = {}
Vec2.__index = Vec2

setmetatable(Vec2, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new vector from two numbers.
---@param x number? x component
---@param y number? y component
---@return Vec2
---@nodiscard
function Vec2.new(x, y)
    local inst <const> = setmetatable({}, Vec2)
    inst.x = x or 0.0
    inst.y = y or 0.0
    return inst
end

function Vec2:__add(b)
    return Vec2.add(self, b)
end

function Vec2:__div(b)
    return Vec2.div(self, b)
end

function Vec2:__eq(b)
    return Vec2.equals(self, b)
end

function Vec2:__idiv(b)
    return Vec2.floorDiv(self, b)
end

function Vec2:__le(b)
    return Vec2.equals(self, b)
        or Vec2.comparator(self, b)
end

function Vec2:__len()
    return 2
end

function Vec2:__lt(b)
    return Vec2.comparator(self, b)
end

function Vec2:__mod(b)
    return Vec2.mod(self, b)
end

function Vec2:__mul(b)
    if type(b) == "number" then
        return Vec2.scale(self, b)
    elseif type(self) == "number" then
        return Vec2.scale(b, self)
    else
        return Vec2.hadamard(self, b)
    end
end

function Vec2:__pow(b)
    return Vec2.pow(self, b)
end

function Vec2:__sub(b)
    return Vec2.sub(self, b)
end

function Vec2:__tostring()
    return Vec2.toJson(self)
end

function Vec2:__unm()
    return Vec2.negate(self)
end

---Finds a vector's absolute value, component-wise.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.abs(v)
    return Vec2.new(
        math.abs(v.x),
        math.abs(v.y))
end

---Finds the sum of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.add(a, b)
    return Vec2.new(
        a.x + b.x,
        a.y + b.y)
end

---Evaluates if all vector components are non-zero.
---@param v Vec2 vector
---@return boolean
---@nodiscard
function Vec2.all(v)
    return v.x ~= 0.0 and v.y ~= 0.0
end

---Evaluates if any vector components are non-zero.
---@param v Vec2 vector
---@return boolean
---@nodiscard
function Vec2.any(v)
    return v.x ~= 0.0 or v.y ~= 0.0
end

---Evaluates whether two vectors are, within a tolerance, approximately equal.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Vec2.approx(a, b, tol)
    local eps <const> = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
end

---Finds a point on a cubic Bezier curve according to a step in [0.0, 1.0] .
---@param ap0 Vec2 anchor point 0
---@param cp0 Vec2 control point 0
---@param cp1 Vec2 control point 1
---@param ap1 Vec2 anchor point 1
---@param step number step
---@return Vec2
---@nodiscard
function Vec2.bezierPoint(ap0, cp0, cp1, ap1, step)
    local t <const> = step or 0.5
    if t <= 0.0 then return Vec2.new(ap0.x, ap0.y) end
    if t >= 1.0 then return Vec2.new(ap1.x, ap1.y) end

    local u <const> = 1.0 - t
    local tsq <const> = t * t
    local usq <const> = u * u
    local usq3t <const> = usq * (t + t + t)
    local tsq3u <const> = tsq * (u + u + u)
    local tcb <const> = tsq * t
    local ucb <const> = usq * u

    return Vec2.new(
        ap0.x * ucb + cp0.x * usq3t +
        cp1.x * tsq3u + ap1.x * tcb,
        ap0.y * ucb + cp0.y * usq3t +
        cp1.y * tsq3u + ap1.y * tcb)
end

---Finds the ceiling of the vector.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.ceil(v)
    return Vec2.new(
        math.ceil(v.x),
        math.ceil(v.y))
end

---A comparator method to sort vectors in a table according to their highest
---dimension first.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
---@nodiscard
function Vec2.comparator(a, b)
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand to the magnitude of the left. Both
---operands are assumed to be Vec2s. Where the sign of b is zero, the result is
---zero.
---@param a Vec2 magnitude
---@param b Vec2 sign
---@return Vec2
---@nodiscard
function Vec2.copySign(a, b)
    local cx, cy = 0.0, 0.0

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

    return Vec2.new(cx, cy)
end

---Returns the z component of the cross product between two vectors. The x and
---y components of the cross between 2D vectors are always zero.
---@param a Vec2
---@param b Vec2
---@return number
---@nodiscard
function Vec2.cross(a, b)
    return a.x * b.y - a.y * b.x
end

---Finds the distance between two vectors. Defaults to Euclidean distance.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
---@nodiscard
function Vec2.dist(a, b)
    return Vec2.distEuclidean(a, b)
end

---Finds the Euclidean distance between two vectors. Forms a circle when
---plotted.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
---@nodiscard
function Vec2.distEuclidean(a, b)
    local dx <const> = b.x - a.x
    local dy <const> = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

---Finds the squared Euclidean distance between two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
---@nodiscard
function Vec2.distSq(a, b)
    local dx <const> = b.x - a.x
    local dy <const> = b.y - a.y
    return dx * dx + dy * dy
end

---Divides the left vector by the right, component-wise.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.div(a, b)
    return Vec2.new(
        b.x ~= 0.0 and a.x / b.x or 0.0,
        b.y ~= 0.0 and a.y / b.y or 0.0)
end

---Finds the dot product between two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
---@nodiscard
function Vec2.dot(a, b)
    return a.x * b.x + a.y * b.y
end

---Evaluates whether two vectors are exactly equal. Checks for reference
---equality prior to value equality.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
---@nodiscard
function Vec2.equals(a, b)
    return rawequal(a, b)
        or Vec2.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly equal by component value.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
---@nodiscard
function Vec2.equalsValue(a, b)
    return a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.floor(v)
    return Vec2.new(
        math.floor(v.x),
        math.floor(v.y))
end

---Finds the floor division of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.floorDiv(a, b)
    return Vec2.new(
        b.x ~= 0.0 and a.x // b.x or 0.0,
        b.y ~= 0.0 and a.y // b.y or 0.0)
end

---Finds the fractional portion of of a vector. Subtracts the truncation of
---each component from itself, not the floor, unlike in GLSL.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.fract(v)
    return Vec2.new(
        math.fmod(v.x, 1.0),
        math.fmod(v.y, 1.0))
end

---Converts from polar to Cartesian coordinates. The heading, or azimuth, is in
---radians. The radius defaults to 1.0.
---@param heading number heading, theta
---@param radius number? radius, rho
---@return Vec2
---@nodiscard
function Vec2.fromPolar(heading, radius)
    local r <const> = radius or 1.0
    return Vec2.new(
        r * math.cos(heading),
        r * math.sin(heading))
end

---Multiplies two vectors component-wise.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.hadamard(a, b)
    return Vec2.new(
        a.x * b.x,
        a.y * b.y)
end

---Finds an integer hash code for a vector.
---@param v Vec2 vector
---@return integer
---@nodiscard
function Vec2.hashCode(v)
    -- https://stackoverflow.com/questions/300840/force-php-integer-overflow
    -- https://readafterwrite.wordpress.com/2017/03/23/floating-point-keys-in-lua/
    local xBits <const> = string.unpack("i4", string.pack("f", v.x))
    local yBits <const> = string.unpack("i4", string.pack("f", v.y))
    return (84696351 ~ xBits) * 16777619 ~ yBits
end

---Finds a vector's heading. Defaults to the signed heading.
---@param v Vec2 vector
---@return number
---@nodiscard
function Vec2.heading(v)
    return Vec2.headingSigned(v)
end

---Finds a vector's signed heading, in [-pi, pi].
---@param v Vec2 vector
---@return number
---@nodiscard
function Vec2.headingSigned(v)
    return math.atan(v.y, v.x)
end

---Finds a vector's unsigned heading, in [0.0, tau].
---@param v Vec2 vector
---@return number
---@nodiscard
function Vec2.headingUnsigned(v)
    return math.atan(v.y, v.x) % 6.2831853071796
end

---Finds a vector's magnitude, or length.
---@param v Vec2 vector
---@return number
---@nodiscard
function Vec2.mag(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

---Finds a vector's magnitude squared.
---@param v Vec2 vector
---@return number
---@nodiscard
function Vec2.magSq(v)
    return v.x * v.x + v.y * v.y
end

---Finds the greater of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.max(a, b)
    return Vec2.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y))
end

---Finds the lesser of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.min(a, b)
    return Vec2.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y))
end

---Mixes two vectors together by a step. Defaults to mixing by a vector.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t Vec2|number step
---@return Vec2
---@nodiscard
function Vec2.mix(a, b, t)
    if type(t) == "number" then
        return Vec2.mixNum(a, b, t)
    end
    return Vec2.mixVec2(a, b, t)
end

---Mixes two vectors together by a step. The step is a number.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t number? step
---@return Vec2
---@nodiscard
function Vec2.mixNum(a, b, t)
    local v <const> = t or 0.5
    local u <const> = 1.0 - v
    return Vec2.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y)
end

---Mixes two vectors together by a step. The step is a vector.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t Vec2 step
---@return Vec2
---@nodiscard
function Vec2.mixVec2(a, b, t)
    return Vec2.new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y)
end

---Finds the remainder of floor division of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.mod(a, b)
    return Vec2.new(
        b.x ~= 0.0 and a.x % b.x or a.x,
        b.y ~= 0.0 and a.y % b.y or a.y)
end

---Negates a vector.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.negate(v)
    return Vec2.new(-v.x, -v.y)
end

---Evaluates if all vector components are zero.
---@param v Vec2 vector
---@return boolean
---@nodiscard
function Vec2.none(v)
    return v.x == 0.0 and v.y == 0.0
end

---Divides a vector by its magnitude, such that it lies on the unit circle.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.normalize(v)
    local mSq <const> = v.x * v.x + v.y * v.y
    if mSq > 0.0 then
        local mInv <const> = 1.0 / math.sqrt(mSq)
        return Vec2.new(
            v.x * mInv,
            v.y * mInv)
    end
    return Vec2.new(0.0, 0.0)
end

---Finds the perpendicular to a vector. Defaults to the counter clockwise
---direction.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.perpendicular(v)
    return Vec2.perpendicularCcw(v)
end

---Finds the counter-clockwise perpendicular to a vector.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.perpendicularCcw(v)
    return Vec2.new(-v.y, v.x)
end

---Finds the clockwise perpendicular to a vector.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.perpendicularCw(v)
    return Vec2.new(v.y, -v.x)
end

---Raises a vector to the power of another.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.pow(a, b)
    return Vec2.new(
        a.x ^ b.x,
        a.y ^ b.y)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---If lower and upper bounds are not given, defaults to [-1.0, 1.0].
---@param lb Vec2? lower bound
---@param ub Vec2? upper bound
---@return Vec2
---@nodiscard
function Vec2.randomCartesian(lb, ub)
    local lVrf <const> = lb or Vec2.new(-1.0, -1.0)
    local uVrf <const> = ub or Vec2.new(1.0, 1.0)
    return Vec2.randomCartesianInternal(lVrf, uVrf)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---Does not validate upper or lower bounds.
---@param lb Vec2 lower bound
---@param ub Vec2 upper bound
---@return Vec2
---@nodiscard
function Vec2.randomCartesianInternal(lb, ub)
    local rx <const> = math.random()
    local ry <const> = math.random()

    return Vec2.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y)
end

---Rotates a vector by an angle in radians around the z axis.
---@param a Vec2 vector
---@param radians number angle
---@return Vec2
---@nodiscard
function Vec2.rotateZ(a, radians)
    return Vec2.rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector by the cosine and sine of an angle. Used when rotating many
---vectors by the same angle.
---@param a Vec2 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Vec2
---@nodiscard
function Vec2.rotateZInternal(a, cosa, sina)
    return Vec2.new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x)
end

---Rounds a vector according to its sign.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.round(v)
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

    return Vec2.new(ix, iy)
end

---Scales a vector, left, by a number, right.
---@param a Vec2 left operand
---@param b number right operand
---@return Vec2
---@nodiscard
function Vec2.scale(a, b)
    return Vec2.new(a.x * b, a.y * b)
end

---Finds the sign of a vector by component.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.sign(v)
    return Vec2.new(
        v.x < -0.0 and -1.0 or v.x > 0.0 and 1.0 or 0.0,
        v.y < -0.0 and -1.0 or v.y > 0.0 and 1.0 or 0.0)
end

---Subtracts the right vector from the left.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
---@nodiscard
function Vec2.sub(a, b)
    return Vec2.new(
        a.x - b.x,
        a.y - b.y)
end

---Returns a JSON string of a vector.
---@param v Vec2 vector
---@return string
---@nodiscard
function Vec2.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f}",
        v.x, v.y)
end

---Converts a vector to polar coordinates. Returns a table with 'radius' and
---'heading'.
---@param v Vec2 vector
---@return { radius: number, heading: number }
---@nodiscard
function Vec2.toPolar(v)
    return {
        radius = Vec2.mag(v),
        heading = Vec2.headingSigned(v)
    }
end

---Truncates a vector's components.
---@param v Vec2 vector
---@return Vec2
---@nodiscard
function Vec2.trunc(v)
    return Vec2.new(
        v.x - math.fmod(v.x, 1.0),
        v.y - math.fmod(v.y, 1.0))
end

return Vec2