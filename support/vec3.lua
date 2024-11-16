---@class Vec3
---@field public x number x component
---@field public y number y component
---@field public z number z component
---@operator add(Vec3): Vec3
---@operator div(Vec3): Vec3
---@operator idiv(Vec3): Vec3
---@operator len(): integer
---@operator mod(Vec3): Vec3
---@operator mul(Vec3|number): Vec3
---@operator pow(Vec3): Vec3
---@operator sub(Vec3): Vec3
---@operator unm(): Vec3
Vec3 = {}
Vec3.__index = Vec3

setmetatable(Vec3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new vector from three numbers.
---@param x number? x component
---@param y number? y component
---@param z number? z component
---@return Vec3
---@nodiscard
function Vec3.new(x, y, z)
    local inst <const> = setmetatable({}, Vec3)
    inst.x = x or 0.0
    inst.y = y or 0.0
    inst.z = z or 0.0
    return inst
end

function Vec3:__add(b)
    return Vec3.add(self, b)
end

function Vec3:__div(b)
    return Vec3.div(self, b)
end

function Vec3:__eq(b)
    return Vec3.equals(self, b)
end

function Vec3:__idiv(b)
    return Vec3.floorDiv(self, b)
end

function Vec3:__le(b)
    return Vec3.equals(self, b)
        or Vec3.comparator(self, b)
end

function Vec3:__len()
    return 3
end

function Vec3:__lt(b)
    return Vec3.comparator(self, b)
end

function Vec3:__mod(b)
    return Vec3.mod(self, b)
end

function Vec3:__mul(b)
    if type(b) == "number" then
        return Vec3.scale(self, b)
    elseif type(self) == "number" then
        return Vec3.scale(b, self)
    else
        return Vec3.hadamard(self, b)
    end
end

function Vec3:__pow(b)
    return Vec3.pow(self, b)
end

function Vec3:__sub(b)
    return Vec3.sub(self, b)
end

function Vec3:__tostring()
    return Vec3.toJson(self)
end

function Vec3:__unm()
    return Vec3.negate(self)
end

---Finds a vector's absolute value, component-wise.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.abs(v)
    return Vec3.new(
        math.abs(v.x),
        math.abs(v.y),
        math.abs(v.z))
end

---Finds the sum of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.add(a, b)
    return Vec3.new(
        a.x + b.x,
        a.y + b.y,
        a.z + b.z)
end

---Evaluates if all vector components are non-zero.
---@param v Vec3 vector
---@return boolean
---@nodiscard
function Vec3.all(v)
    return v.x ~= 0.0
        and v.y ~= 0.0
        and v.z ~= 0.0
end

---Evaluates if any vector components are non-zero.
---@param v Vec3 vector
---@return boolean
---@nodiscard
function Vec3.any(v)
    return v.x ~= 0.0
        or v.y ~= 0.0
        or v.z ~= 0.0
end

---Evaluates whether two vectors are, within a tolerance, approximately equal.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Vec3.approx(a, b, tol)
    local eps <const> = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
        and math.abs(b.z - a.z) <= eps
end

---Finds a vector's azimuth. Defaults to the signed azimuth.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.azimuth(v)
    return Vec3.azimuthSigned(v)
end

---Finds a vector's signed azimuth, in [-pi, pi].
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.azimuthSigned(v)
    return math.atan(v.y, v.x)
end

---Finds a vector's unsigned azimuth, in [0.0, tau].
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.azimuthUnsigned(v)
    return math.atan(v.y, v.x) % 6.2831853071796
end

---Finds a point on a cubic Bezier curve according to a step in [0.0, 1.0] .
---@param ap0 Vec3 anchor point 0
---@param cp0 Vec3 control point 0
---@param cp1 Vec3 control point 1
---@param ap1 Vec3 anchor point 1
---@param step number step
---@return Vec3
---@nodiscard
function Vec3.bezierPoint(ap0, cp0, cp1, ap1, step)
    local t <const> = step or 0.5
    if t <= 0.0 then
        return Vec3.new(ap0.x, ap0.y, ap0.z)
    end
    if t >= 1.0 then
        return Vec3.new(ap1.x, ap1.y, ap1.z)
    end

    local u <const> = 1.0 - t
    local tsq <const> = t * t
    local usq <const> = u * u
    local usq3t <const> = usq * (t + t + t)
    local tsq3u <const> = tsq * (u + u + u)
    local tcb <const> = tsq * t
    local ucb <const> = usq * u

    return Vec3.new(
        ap0.x * ucb + cp0.x * usq3t +
        cp1.x * tsq3u + ap1.x * tcb,
        ap0.y * ucb + cp0.y * usq3t +
        cp1.y * tsq3u + ap1.y * tcb,
        ap0.z * ucb + cp0.z * usq3t +
        cp1.z * tsq3u + ap1.z * tcb)
end

---Bisects an array of vectors to find the appropriate insertion point for a
---vector. Biases towards the right insert point. Should be used with sorted
---arrays.
---@param arr Vec3[] vectors array
---@param elm Vec3 vector
---@param compare? fun(a: Vec3, b: Vec3): boolean comparator
---@return integer
---@nodiscard
function Vec3.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    local f <const> = compare or Vec3.comparator
    while low < high do
        local middle <const> = (low + high) // 2
        local right <const> = arr[1 + middle]
        if right and f(elm, right) then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Finds the ceiling of the vector.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.ceil(v)
    return Vec3.new(
        math.ceil(v.x),
        math.ceil(v.y),
        math.ceil(v.z))
end

---A comparator method to sort vectors in a table according to their highest
---dimension first.
---@param a Vec3 left comparisand
---@param b Vec3 right comparisand
---@return boolean
---@nodiscard
function Vec3.comparator(a, b)
    if a.z < b.z then return true end
    if a.z > b.z then return false end
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand to the magnitude of the left. Both
---operands are assumed to be Vec3s. Where the sign of b is zero, the result is
---zero.
---@param a Vec3 magnitude
---@param b Vec3 sign
---@return Vec3
---@nodiscard
function Vec3.copySign(a, b)
    local cx, cy, cz = 0.0, 0.0, 0.0

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

    return Vec3.new(cx, cy, cz)
end

---Finds the cross product of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.cross(a, b)
    return Vec3.new(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x)
end

---Finds the distance between two vectors. Defaults to Euclidean distance.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return number
---@nodiscard
function Vec3.dist(a, b)
    return Vec3.distEuclidean(a, b)
end

---Finds the Euclidean distance between two vectors. Forms a sphere when
---plotted.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return number
---@nodiscard
function Vec3.distEuclidean(a, b)
    local dx <const> = b.x - a.x
    local dy <const> = b.y - a.y
    local dz <const> = b.z - a.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Finds the squared Euclidean distance between two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return number
---@nodiscard
function Vec3.distSq(a, b)
    local dx <const> = b.x - a.x
    local dy <const> = b.y - a.y
    local dz <const> = b.z - a.z
    return dx * dx + dy * dy + dz * dz
end

---Divides the left vector by the right, component-wise.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.div(a, b)
    return Vec3.new(
        b.x ~= 0.0 and a.x / b.x or 0.0,
        b.y ~= 0.0 and a.y / b.y or 0.0,
        b.z ~= 0.0 and a.z / b.z or 0.0)
end

---Finds the dot product between two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return number
---@nodiscard
function Vec3.dot(a, b)
    return a.x * b.x
        + a.y * b.y
        + a.z * b.z
end

---Evaluates whether two vectors are exactly equal. Checks for reference
---equality prior to value equality.
---@param a Vec3 left comparisand
---@param b Vec3 right comparisand
---@return boolean
---@nodiscard
function Vec3.equals(a, b)
    return rawequal(a, b)
        or Vec3.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly equal by component value.
---@param a Vec3 left comparisand
---@param b Vec3 right comparisand
---@return boolean
---@nodiscard
function Vec3.equalsValue(a, b)
    return a.z == b.z
        and a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.floor(v)
    return Vec3.new(
        math.floor(v.x),
        math.floor(v.y),
        math.floor(v.z))
end

---Finds the floor division of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.floorDiv(a, b)
    return Vec3.new(
        b.x ~= 0.0 and a.x // b.x or 0.0,
        b.y ~= 0.0 and a.y // b.y or 0.0,
        b.z ~= 0.0 and a.z // b.z or 0.0)
end

---Finds the fractional portion of of a vector. Subtracts the truncation of
---each component from itself, not the floor, unlike in GLSL.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.fract(v)
    return Vec3.new(
        math.fmod(v.x, 1.0),
        math.fmod(v.y, 1.0),
        math.fmod(v.z, 1.0))
end

---Creates a vector from an azimuth (or yaw), inclination (or pitch) and radius.
---Expects the inclination to be a signed value between -pi / 2 and pi / 2. The
---poles are upright in a Z-Up coordinate system.
---@param azimuth number azimuth, yaw, theta
---@param inclination number inclination, pitch, phi
---@param radius number? radius, rho
---@return Vec3
---@nodiscard
function Vec3.fromSpherical(azimuth, inclination, radius)
    local a <const> = azimuth or 0.0
    local i <const> = inclination or 0.0
    local r <const> = radius or 1.0
    return Vec3.fromSphericalInternal(
        math.cos(a), math.sin(a),
        math.cos(i), math.sin(i), r)
end

---Creates a vector from the cosine and sine of azimuth and inclination.
---Multiplies by the radius.
---@param cosAzim number azimuth cosine
---@param sinAzim number azimuth sine
---@param cosIncl number inclination cosine
---@param sinIncl number inclination sine
---@param radius number radius
---@return Vec3
---@nodiscard
function Vec3.fromSphericalInternal(
    cosAzim, sinAzim,
    cosIncl, sinIncl,
    radius)
    local rhoCosIncl <const> = radius * cosIncl
    return Vec3.new(
        rhoCosIncl * cosAzim,
        rhoCosIncl * sinAzim,
        radius * sinIncl)
end

---Creates a one-dimensional table of vectors arranged in a Cartesian grid from
---the lower to the upper bound. Both bounds are vectors.
---@param cols integer columns
---@param rows integer rows
---@param layers integer layers
---@param lb Vec3 lower bound
---@param ub Vec3 upper bound
---@return Vec3[]
---@nodiscard
function Vec3.gridCartesian(cols, rows, layers, lb, ub)
    local ubVrf <const> = ub or Vec3.new(1.0, 1.0, 1.0)
    local lbVrf <const> = lb or Vec3.new(-1.0, -1.0, -1.0)

    local lVrf = layers or 2
    local rVrf = rows or 2
    local cVrf = cols or 2

    if lVrf < 2 then lVrf = 2 end
    if rVrf < 2 then rVrf = 2 end
    if cVrf < 2 then cVrf = 2 end

    local lbx <const> = lbVrf.x
    local lby <const> = lbVrf.y
    local lbz <const> = lbVrf.z

    local ubx <const> = ubVrf.x
    local uby <const> = ubVrf.y
    local ubz <const> = ubVrf.z

    local hToStep <const> = 1.0 / (lVrf - 1.0)
    local iToStep <const> = 1.0 / (rVrf - 1.0)
    local jToStep <const> = 1.0 / (cVrf - 1.0)

    ---@type Vec3[]
    local result <const> = {}
    local rcVrf <const> = rVrf * cVrf
    local length <const> = lVrf * rcVrf

    local k = 0
    while k < length do
        local h <const> = k // rcVrf
        local m <const> = k - h * rcVrf

        local hStep <const> = h * hToStep
        local iStep <const> = (m // cVrf) * iToStep
        local jStep <const> = (m % cVrf) * jToStep

        k = k + 1
        result[k] = Vec3.new(
            (1.0 - jStep) * lbx + jStep * ubx,
            (1.0 - iStep) * lby + iStep * uby,
            (1.0 - hStep) * lbz + hStep * ubz)
    end

    return result
end

---Multiplies two vectors component-wise.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.hadamard(a, b)
    return Vec3.new(
        a.x * b.x,
        a.y * b.y,
        a.z * b.z)
end

---Finds an integer hash code for a vector.
---@param v Vec3 vector
---@return integer
---@nodiscard
function Vec3.hashCode(v)
    local xBits <const> = string.unpack("i4", string.pack("f", v.x))
    local yBits <const> = string.unpack("i4", string.pack("f", v.y))
    local zBits <const> = string.unpack("i4", string.pack("f", v.z))
    return ((84696351 ~ xBits) * 16777619 ~ yBits) * 16777619 ~ zBits
end

---Finds the vector's inclination. Defaults to signed inclination.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.inclination(v)
    return Vec3.inclinationSigned(v)
end

---Finds the vector's signed inclination.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.inclinationSigned(v)
    return 1.5707963267949 - Vec3.inclinationUnsigned(v)
end

---Finds the vector's unsigned inclination.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.inclinationUnsigned(v)
    local mSq <const> = v.x * v.x + v.y * v.y + v.z * v.z
    if mSq > 0.0 then
        return math.acos(v.z / math.sqrt(mSq))
    end
    return 1.5707963267949
end

---Inserts a vector into a table so as to maintain sorted order. Biases toward
---the right insertion point. Returns true if the unique vector was inserted.
---@param arr Vec3[] vectors array
---@param elm Vec3 vector
---@param compare? fun(a: Vec3, b: Vec3): boolean comparator
---@return boolean
function Vec3.insortRight(arr, elm, compare)
    local i <const> = Vec3.bisectRight(arr, elm, compare)
    local dupe <const> = arr[i - 1]
    if dupe and Vec3.equals(dupe, elm) then
        return false
    end
    table.insert(arr, i, elm)
    return true
end

---Finds a vector's magnitude, or length.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.mag(v)
    return math.sqrt(
        v.x * v.x
        + v.y * v.y
        + v.z * v.z)
end

---Finds a vector's magnitude squared.
---@param v Vec3 vector
---@return number
---@nodiscard
function Vec3.magSq(v)
    return v.x * v.x
        + v.y * v.y
        + v.z * v.z
end

---Finds the greater of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.max(a, b)
    return Vec3.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        math.max(a.z, b.z))
end

---Finds the lesser of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.min(a, b)
    return Vec3.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.min(a.z, b.z))
end

---Mixes two vectors together by a step. Defaults to mixing by a vector.
---@param a Vec3 origin
---@param b Vec3 destination
---@param t Vec3|number step
---@return Vec3
---@nodiscard
function Vec3.mix(a, b, t)
    if type(t) == "number" then
        return Vec3.mixNum(a, b, t)
    end
    return Vec3.mixVec3(a, b, t)
end

---Mixes two vectors together by a step. The step is a number.
---@param a Vec3 origin
---@param b Vec3 destination
---@param t number? step
---@return Vec3
---@nodiscard
function Vec3.mixNum(a, b, t)
    local v <const> = t or 0.5
    local u <const> = 1.0 - v
    return Vec3.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y,
        u * a.z + v * b.z)
end

---Mixes two vectors together by a step. The step is a vector.
---@param a Vec3 origin
---@param b Vec3 destination
---@param t Vec3 step
---@return Vec3
---@nodiscard
function Vec3.mixVec3(a, b, t)
    return Vec3.new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y,
        (1.0 - t.z) * a.z + t.z * b.z)
end

---Finds the remainder of floor division of two vectors.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.mod(a, b)
    return Vec3.new(
        b.x ~= 0.0 and a.x % b.x or a.x,
        b.y ~= 0.0 and a.y % b.y or a.y,
        b.z ~= 0.0 and a.z % b.z or a.z)
end

---Negates a vector.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.negate(v)
    return Vec3.new(-v.x, -v.y, -v.z)
end

---Evaluates if all vector components are zero.
---@param v Vec3 vector
---@return boolean
---@nodiscard
function Vec3.none(v)
    return v.x == 0.0
        and v.y == 0.0
        and v.z == 0.0
end

---Divides a vector by its magnitude, such that it lies on the unit circle.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.normalize(v)
    local mSq <const> = v.x * v.x + v.y * v.y + v.z * v.z
    if mSq > 0.0 then
        local mInv <const> = 1.0 / math.sqrt(mSq)
        return Vec3.new(
            v.x * mInv,
            v.y * mInv,
            v.z * mInv)
    end
    return Vec3.new(0.0, 0.0, 0.0)
end

---Raises a vector to the power of another.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.pow(a, b)
    return Vec3.new(
        a.x ^ b.x,
        a.y ^ b.y,
        a.z ^ b.z)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---If lower and upper bounds are not given, defaults to [-1.0, 1.0].
---@param lb Vec3? lower bound
---@param ub Vec3? upper bound
---@return Vec3
---@nodiscard
function Vec3.randomCartesian(lb, ub)
    local lVrf <const> = lb or Vec3.new(-1.0, -1.0, -1.0)
    local uVrf <const> = ub or Vec3.new(1.0, 1.0, 1.0)
    return Vec3.randomCartesianInternal(lVrf, uVrf)
end

---Creates a random point in Cartesian space given a lower and an upper bound.
---Does not validate upper or lower bounds.
---@param lb Vec3 lower bound
---@param ub Vec3 upper bound
---@return Vec3
---@nodiscard
function Vec3.randomCartesianInternal(lb, ub)
    local rx <const> = math.random()
    local ry <const> = math.random()
    local rz <const> = math.random()

    return Vec3.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y,
        (1.0 - rz) * lb.z + rz * ub.z)
end

---Rotates a vector around an axis by an angle in radians. Validates the axis
---to see if it is of unit length. Defaults to rotateZ.
---@param a Vec3 vector
---@param radians number angle
---@param axis Vec3 rotation axis
---@return Vec3
---@nodiscard
function Vec3.rotate(a, radians, axis)
    if axis and Vec3.any(axis) then
        return Vec3.rotateInternal(a,
            math.cos(radians), math.sin(radians),
            Vec3.normalize(axis))
    end
    return Vec3.rotateZ(a, radians)
end

---Rotates a vector around the x axis by an angle in radians.
---@param a Vec3 vector
---@param radians number angle
---@return Vec3
---@nodiscard
function Vec3.rotateX(a, radians)
    return Vec3.rotateXInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the y axis by an angle in radians.
---@param a Vec3 vector
---@param radians number angle
---@return Vec3
---@nodiscard
function Vec3.rotateY(a, radians)
    return Vec3.rotateYInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the z axis by an angle in radians.
---@param a Vec3 vector
---@param radians number angle
---@return Vec3
---@nodiscard
function Vec3.rotateZ(a, radians)
    return Vec3.rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around an axis by an angle in radians. The axis is assumed
---to be of unit length.
---@param a Vec3 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@param axis Vec3 axis
---@return Vec3
---@nodiscard
function Vec3.rotateInternal(a, cosa, sina, axis)
    local xAxis <const> = axis.x
    local yAxis <const> = axis.y
    local zAxis <const> = axis.z

    local complCos <const> = 1.0 - cosa
    local xyCompl <const> = complCos * xAxis * yAxis
    local xzCompl <const> = complCos * xAxis * zAxis
    local yzCompl <const> = complCos * yAxis * zAxis

    local xSin <const> = sina * xAxis
    local ySin <const> = sina * yAxis
    local zSin <const> = sina * zAxis

    return Vec3.new(
        (complCos * xAxis * xAxis + cosa) * a.x +
        (xyCompl - zSin) * a.y +
        (xzCompl + ySin) * a.z,

        (xyCompl + zSin) * a.x +
        (complCos * yAxis * yAxis + cosa) * a.y +
        (yzCompl - xSin) * a.z,

        (xzCompl - ySin) * a.x +
        (yzCompl + xSin) * a.y +
        (complCos * zAxis * zAxis + cosa) * a.z)
end

---Rotates a vector around the x axis by the cosine and sine of an angle. Used
---when rotating many vectors by the same angle.
---@param a Vec3 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Vec3
---@nodiscard
function Vec3.rotateXInternal(a, cosa, sina)
    return Vec3.new(
        a.x,
        cosa * a.y - sina * a.z,
        cosa * a.z + sina * a.y)
end

---Rotates a vector around the y axis by the cosine and sine of an angle. Used
---when rotating many vectors by the same angle.
---@param a Vec3 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Vec3
---@nodiscard
function Vec3.rotateYInternal(a, cosa, sina)
    return Vec3.new(
        cosa * a.x + sina * a.z,
        a.y,
        cosa * a.z - sina * a.x)
end

---Rotates a vector around the z axis by the cosine and sine of an angle. Used
---when rotating many vectors by the same angle.
---@param a Vec3 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Vec3
---@nodiscard
function Vec3.rotateZInternal(a, cosa, sina)
    return Vec3.new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x,
        a.z)
end

---Rounds the vector by sign and fraction.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.round(v)
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

    return Vec3.new(ix, iy, iz)
end

---Scales a vector, left, by a number, right.
---@param a Vec3 left operand
---@param b number right operand
---@return Vec3
---@nodiscard
function Vec3.scale(a, b)
    return Vec3.new(
        a.x * b,
        a.y * b,
        a.z * b)
end

---Finds the sign of a vector by component.
---@param v Vec3 left operand
---@return Vec3
---@nodiscard
function Vec3.sign(v)
    return Vec3.new(
        v.x < -0.0 and -1.0 or v.x > 0.0 and 1.0 or 0.0,
        v.y < -0.0 and -1.0 or v.y > 0.0 and 1.0 or 0.0,
        v.z < -0.0 and -1.0 or v.z > 0.0 and 1.0 or 0.0)
end

---Subtracts the right vector from the left.
---@param a Vec3 left operand
---@param b Vec3 right operand
---@return Vec3
---@nodiscard
function Vec3.sub(a, b)
    return Vec3.new(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z)
end

---Returns a JSON string of a vector.
---@param v Vec3 vector
---@return string
---@nodiscard
function Vec3.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f,\"z\":%.4f}",
        v.x, v.y, v.z)
end

---Converts a vector to spherical coordinates. Returns a table with 'radius',
---'azimuth' and 'inclination'.
---@param v Vec3 vector
---@return { radius: number, azimuth: number, inclination: number }
---@nodiscard
function Vec3.toSpherical(v)
    return {
        radius = Vec3.mag(v),
        azimuth = Vec3.azimuthSigned(v),
        inclination = Vec3.inclinationSigned(v)
    }
end

---Truncates a vector's components.
---@param v Vec3 vector
---@return Vec3
---@nodiscard
function Vec3.trunc(v)
    return Vec3.new(
        v.x - math.fmod(v.x, 1.0),
        v.y - math.fmod(v.y, 1.0),
        v.z - math.fmod(v.z, 1.0))
end

---Creates a forward facing vector, (0.0, 1.0, 0.0).
---@return Vec3
---@nodiscard
function Vec3.forward()
    return Vec3.new(0.0, 1.0, 0.0)
end

---Creates an up facing vector, (0.0, 0.0, 1.0).
---@return Vec3
---@nodiscard
function Vec3.up()
    return Vec3.new(0.0, 0.0, 1.0)
end

return Vec3