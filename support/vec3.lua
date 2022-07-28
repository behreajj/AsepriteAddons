Vec3 = {}
Vec3.__index = Vec3

setmetatable(Vec3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new vector from three numbers.
---@param x number x component
---@param y number y component
---@param z number z component
---@return table
function Vec3.new(x, y, z)
    local inst = setmetatable({}, Vec3)
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
---@param a table vector
---@return table
function Vec3.abs(a)
    return Vec3.new(
        math.abs(a.x),
        math.abs(a.y),
        math.abs(a.z))
end

---Finds the sum of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.add(a, b)
    return Vec3.new(
        a.x + b.x,
        a.y + b.y,
        a.z + b.z)
end

---Evaluates if all vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec3.all(a)
    return a.x ~= 0.0
        and a.y ~= 0.0
        and a.z ~= 0.0
end

---Finds the angle between two vectors. If either
---vector has no magnitude, returns zero. Uses the
---formula acos(dot(a, b) / (mag(a) * mag(b))).
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.angleBetween(a, b)
    local aSq = a.x * a.x + a.y * a.y + a.z * a.z
    if aSq > 0.0 then
        local bSq = b.x * b.x + b.y * b.y + b.z * b.z
        if bSq > 0.0 then
            return math.acos(
                (a.x * b.x + a.y * b.y + a.z * b.z)
                / (math.sqrt(aSq) * math.sqrt(bSq)))
        end
    end
    return 0.0
end

---Evaluates if any vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec3.any(a)
    return a.x ~= 0.0
        or a.y ~= 0.0
        or a.z ~= 0.0
end

---Evaluates whether two vectors are, within a
---tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol number|nil tolerance
---@return boolean
function Vec3.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
        and math.abs(b.z - a.z) <= eps
end

---Finds a vector's azimuth.
---Defaults to the signed azimuth.
---@param a table left operand
---@return number
function Vec3.azimuth(a)
    return Vec3.azimuthSigned(a)
end

---Finds a vector's signed azimuth, in [-pi, pi].
---@param a table left operand
---@return number
function Vec3.azimuthSigned(a)
    return math.atan(a.y, a.x)
end

---Finds a vector's unsigned azimuth, in [0.0, tau].
---@param a table left operand
---@return number
function Vec3.azimuthUnsigned(a)
    return math.atan(a.y, a.x) % 6.2831853071796
end

---Finds a point on a cubic Bezier curve
---according to a step in [0.0, 1.0] .
---@param ap0 table anchor point 0
---@param cp0 table control point 0
---@param cp1 table control point 1
---@param ap1 table anchor point 1
---@param step number step
---@return table
function Vec3.bezierPoint(ap0, cp0, cp1, ap1, step)
    local t = step or 0.5
    if t <= 0.0 then
        return Vec3.new(ap0.x, ap0.y, ap0.z)
    end
    if t >= 1.0 then
        return Vec3.new(ap1.x, ap1.y, ap1.z)
    end

    local u = 1.0 - t
    local tsq = t * t
    local usq = u * u
    local usq3t = usq * (t + t + t)
    local tsq3u = tsq * (u + u + u)
    local tcb = tsq * t
    local ucb = usq * u

    return Vec3.new(
        ap0.x * ucb + cp0.x * usq3t +
        cp1.x * tsq3u + ap1.x * tcb,
        ap0.y * ucb + cp0.y * usq3t +
        cp1.y * tsq3u + ap1.y * tcb,
        ap0.z * ucb + cp0.z * usq3t +
        cp1.z * tsq3u + ap1.z * tcb)
end

---Bisects an array of vectors to find
---the appropriate insertion point for
---a vector. Biases towards the right insert
---point. Should be used with sorted arrays.
---@param arr table vectors array
---@param elm table vector
---@param compare function|nil comparator
---@return integer
function Vec3.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    local f = compare or Vec3.comparator
    while low < high do
        local middle = (low + high) // 2
        local right = arr[1 + middle]
        if right and f(elm, right) then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Finds the ceiling of the vector.
---@param a table left operand
---@return table
function Vec3.ceil(a)
    return Vec3.new(
        math.ceil(a.x),
        math.ceil(a.y),
        math.ceil(a.z))
end

---A comparator method to sort vectors
---in a table according to their highest
---dimension first.
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Vec3.comparator(a, b)
    if a.z < b.z then return true end
    if a.z > b.z then return false end
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand to
---the magnitude of the left. Both operands
---are assumed to be Vec3s. Where the sign of
---b is zero, the result is zero.
---@param a table magnitude
---@param b table sign
---@return table
function Vec3.copySign(a, b)
    local cx = 0.0
    local axAbs = math.abs(a.x)
    if b.x < -0.0 then cx = -axAbs
    elseif b.x > 0.0 then cx = axAbs
    end

    local cy = 0.0
    local ayAbs = math.abs(a.y)
    if b.y < -0.0 then cy = -ayAbs
    elseif b.y > 0.0 then cy = ayAbs
    end

    local cz = 0.0
    local azAbs = math.abs(a.z)
    if b.z < -0.0 then cz = -azAbs
    elseif b.z > 0.0 then cz = azAbs
    end

    return Vec3.new(cx, cy, cz)
end

---Finds the cross product of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.cross(a, b)
    return Vec3.new(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x)
end

---Finds the absolute difference between two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.diff(a, b)
    return Vec3.new(
        math.abs(a.x - b.x),
        math.abs(a.y - b.y),
        math.abs(a.z - b.z))
end

---Finds the distance between two vectors.
---Defaults to Euclidean distance.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.dist(a, b)
    return Vec3.distEuclidean(a, b)
end

---Finds the Chebyshev distance between two vectors.
---Forms a cube when plotted.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.distChebyshev(a, b)
    return math.max(
        math.abs(b.x - a.x),
        math.abs(b.y - a.y),
        math.abs(b.z - a.z))
end

---Finds the Euclidean distance between two vectors.
---Forms a sphere when plotted.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.distEuclidean(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Finds the Manhattan distance between two vectors.
---Forms an octahedron when plotted.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.distManhattan(a, b)
    return math.abs(b.x - a.x)
        + math.abs(b.y - a.y)
        + math.abs(b.z - a.z)
end

---Finds the Minkowski distance between two vectors.
---When the exponent is 1, returns Manhattan distance.
---When the exponent is 2, returns Euclidean distance.
---@param a table left operand
---@param b table right operand
---@param c number exponent
---@return number
function Vec3.distMinkowski(a, b, c)
    local d = c or 2.0
    if d ~= 0.0 then
        return (math.abs(b.x - a.x) ^ d
            + math.abs(b.y - a.y) ^ d
            + math.abs(b.z - a.z) ^ d)
            ^ (1.0 / d)
    else
        return 0.0
    end
end

---Finds the squared Euclidean distance between
---two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.distSq(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    return dx * dx + dy * dy + dz * dz
end

---Divides the left vector by the right, component-wise.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.div(a, b)
    local cx = 0.0
    local cy = 0.0
    local cz = 0.0
    if b.x ~= 0.0 then cx = a.x / b.x end
    if b.y ~= 0.0 then cy = a.y / b.y end
    if b.z ~= 0.0 then cz = a.z / b.z end
    return Vec3.new(cx, cy, cz)
end

---Finds the dot product between two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.dot(a, b)
    return a.x * b.x
        + a.y * b.y
        + a.z * b.z
end

---Evaluates whether two vectors are exactly
---equal. Checks for reference equality prior
---to value equality.
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Vec3.equals(a, b)
    return rawequal(a, b)
        or Vec3.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly
---equal by component value.
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Vec3.equalsValue(a, b)
    return a.z == b.z
        and a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param a table left operand
---@return table
function Vec3.floor(a)
    return Vec3.new(
        math.floor(a.x),
        math.floor(a.y),
        math.floor(a.z))
end

---Finds the floor division of two vectors.
---@param a table left operand
---@param b table left operand
---@return table
function Vec3.floorDiv(a, b)
    local cx = 0.0
    local cy = 0.0
    local cz = 0.0
    if b.x ~= 0.0 then cx = a.x // b.x end
    if b.y ~= 0.0 then cy = a.y // b.y end
    if b.z ~= 0.0 then cz = a.z // b.z end
    return Vec3.new(cx, cy, cz)
end

---Finds the remainder of the division of the left
---operand by the right that rounds the quotient
---towards zero.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.fmod(a, b)
    local cx = a.x
    local cy = a.y
    local cz = a.z
    if b.x ~= 0.0 then cx = math.fmod(a.x, b.x) end
    if b.y ~= 0.0 then cy = math.fmod(a.y, b.y) end
    if b.z ~= 0.0 then cz = math.fmod(a.z, b.z) end
    return Vec3.new(cx, cy, cz)
end

---Finds the fractional portion of of a vector.
---Subtracts the truncation of each component
---from itself, not the floor, unlike in GLSL.
---@param a table left operand
---@return table
function Vec3.fract(a)
    return Vec3.new(
        math.fmod(a.x, 1.0),
        math.fmod(a.y, 1.0),
        math.fmod(a.z, 1.0))
end

---Creates a vector from an azimuth (or yaw),
---inclination (or pitch) and radius. Expects the
---inclination to be a signed value between -pi / 2
---and pi / 2. The poles are upright in a Z-Up
---coordinate system.
---@param azimuth number
---@param inclination number
---@param radius number
---@return table
function Vec3.fromSpherical(azimuth, inclination, radius)

    local a = azimuth or 0.0
    local i = inclination or 0.0
    local r = radius or 1.0

    return Vec3.fromSphericalInternal(
        math.cos(a), math.sin(a),
        math.cos(i), math.sin(i), r)
end

---Creates a vector from the cosine and sine
---of azimuth and inclination. Multiplies by
---the radius.
---@param cosAzim number azimuth cosine
---@param sinAzim number azimuth sine
---@param cosIncl number inclination cosine
---@param sinIncl number inclination sine
---@param radius number radius
---@return table
function Vec3.fromSphericalInternal(cosAzim, sinAzim, cosIncl, sinIncl, radius)

    local rhoCosIncl = radius * cosIncl
    return Vec3.new(
        rhoCosIncl * cosAzim,
        rhoCosIncl * sinAzim,
        radius * sinIncl)
end

---Creates a one-dimensional table of vectors
---arranged in a Cartesian grid from the lower
---to the upper bound. Both bounds are vectors.
---@param cols number columns
---@param rows number rows
---@param layers number layers
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec3.gridCartesian(cols, rows, layers, lb, ub)
    local ubVal = ub or Vec3.new(1.0, 1.0, 1.0)
    local lbVal = lb or Vec3.new(-1.0, -1.0, -1.0)

    local lVal = layers or 2
    local rVal = rows or 2
    local cVal = cols or 2

    if lVal < 2 then lVal = 2 end
    if rVal < 2 then rVal = 2 end
    if cVal < 2 then cVal = 2 end

    local lbx = lbVal.x
    local lby = lbVal.y
    local lbz = lbVal.z

    local ubx = ubVal.x
    local uby = ubVal.y
    local ubz = ubVal.z

    local hToStep = 1.0 / (lVal - 1.0)
    local iToStep = 1.0 / (rVal - 1.0)
    local jToStep = 1.0 / (cVal - 1.0)

    local result = {}
    local rcVal = rVal * cVal
    local length = lVal * rcVal
    local k = 0
    while k < length do
        local h = k // rcVal
        local m = k - h * rcVal

        local hStep = h * hToStep
        local iStep = (m // cVal) * iToStep
        local jStep = (m % cVal) * jToStep

        k = k + 1
        result[k] = Vec3.new(
            (1.0 - jStep) * lbx + jStep * ubx,
            (1.0 - iStep) * lby + iStep * uby,
            (1.0 - hStep) * lbz + hStep * ubz)
    end

    return result
end

---Creates a one-dimensional table of vectors
---arranged in a spherical grid. The table
---is ordered by layers, latitudes, then
---longitudes. If poles are included, they are
---appended at the end of the table.
---@param longitudes number longitudes or azimuths
---@param latitudes number latitudes or inclinations
---@param layers number layers or radii
---@param radiusMin number minimum radius
---@param radiusMax number maximum radius
function Vec3.gridSpherical(longitudes, latitudes, layers, radiusMin, radiusMax)

    -- Cache methods.
    local cos = math.cos
    local sin = math.sin
    local max = math.max
    local min = math.min

    -- Assign default arguments.
    local vrMax = radiusMax or 0.5
    local vrMin = radiusMin or 0.5
    local vLayers = layers or 1
    local vLats = latitudes or 16
    local vLons = longitudes or 32

    -- Validate.
    if vLons < 3 then vLons = 3 end
    if vLats < 3 then vLats = 3 end
    if vLayers < 1 then vLayers = 1 end

    vrMax = max(0.000001, vrMin, vrMax)
    local oneLayer = vLayers == 1
    if oneLayer then
        vrMin = vrMax
    else
        vrMin = max(0.000001, min(vrMin, vrMax))
    end

    local toPrc = 1.0
    if not oneLayer then
        toPrc = 1.0 / (vLayers - 1.0)
    end
    local toIncl = 3.1415926535898 / (vLats + 1.0)
    local toAzim = 6.2831853071796 / vLons

    local len2 = vLats * vLons
    local len3 = vLayers * len2

    local k = 0
    local result = {}
    while k < len3 do
        local h = k // len2
        local m = k - h * len2
        local i = m // vLons
        local j = m % vLons

        local prc = h * toPrc
        local radius = (1.0 - prc) * vrMin
            + prc * vrMax

        local incl = 1.5707963267949 - (i + 1.0) * toIncl
        local rhoCosIncl = radius * cos(incl)
        local rhoSinIncl = radius * sin(incl)

        local azim = j * toAzim
        local cosAzim = cos(azim)
        local sinAzim = sin(azim)

        k = k + 1
        result[k] = Vec3.new(
            rhoCosIncl * cosAzim,
            rhoCosIncl * sinAzim,
            -rhoSinIncl)
    end

    return result
end

---Multiplies two vectors component-wise.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.hadamard(a, b)
    return Vec3.new(
        a.x * b.x,
        a.y * b.y,
        a.z * b.z)
end

---Finds a signed integer hash code for a vector.
---@param a table vector
---@return integer
function Vec3.hashCode(a)
    local xBits = string.unpack("i4",
        string.pack("f", a.x))
    local yBits = string.unpack("i4",
        string.pack("f", a.y))
    local zBits = string.unpack("i4",
        string.pack("f", a.z))

    local hsh = ((84696351 ~ xBits)
        * 16777619 ~ yBits)
        * 16777619 ~ zBits

    local hshInt = hsh & 0xffffffff
    if hshInt & 0x80000000 then
        return -((~hshInt & 0xffffffff) + 1)
    else
        return hshInt
    end
end

---Finds the vector's inclination.
---Defaults to signed inclination.
---@param a table left operand
---@return number
function Vec3.inclination(a)
    return Vec3.inclinationSigned(a)
end

---Finds the vector's signed inclination.
---@param a table left operand
---@return number
function Vec3.inclinationSigned(a)
    return 1.5707963267949 - Vec3.inclinationUnsigned(a)
end

---Finds the vector's unsigned inclination.
---@param a table left operand
---@return number
function Vec3.inclinationUnsigned(a)
    local mSq = a.x * a.x + a.y * a.y + a.z * a.z
    if mSq > 0.0 then
        return math.acos(a.z / math.sqrt(mSq))
    end
    return 1.5707963267949
end

---Inserts a vector into a table so as to
---maintain sorted order. Biases toward the right
---insertion point. Returns true if the unique
---vector was inserted; false if not.
---@param arr table vectors array
---@param elm table vector
---@param compare function comparator
---@return boolean
function Vec3.insortRight(arr, elm, compare)
    local i = Vec3.bisectRight(arr, elm, compare)
    local dupe = arr[i - 1]
    if dupe and Vec3.equals(dupe, elm) then
        return false
    end
    table.insert(arr, i, elm)
    return true
end

---Limits a vector's magnitude to a scalar.
---Returns a copy of the vector if it is beneath
---the limit.
---@param a table the vector
---@param limit number the limit number
---@return table
function Vec3.limit(a, limit)
    local mSq = a.x * a.x + a.y * a.y + a.z * a.z
    if mSq > 0.0 and mSq > (limit * limit) then
        local mInv = limit / math.sqrt(mSq)
        return Vec3.new(
            a.x * mInv,
            a.y * mInv,
            a.z * mInv)
    end
    return Vec3.new(a.x, a.y, a.z)
end

---Finds the linear step between a left and
---right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
function Vec3.linearstep(edge0, edge1, x)
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

    return Vec3.new(cx, cy, cz)
end

---Finds a vector's magnitude, or length.
---@param a table left operand
---@return number
function Vec3.mag(a)
    return math.sqrt(
        a.x * a.x
        + a.y * a.y
        + a.z * a.z)
end

---Finds a vector's magnitude squared.
---@param a table left operand
---@return number
function Vec3.magSq(a)
    return a.x * a.x
        + a.y * a.y
        + a.z * a.z
end

---Finds the greater of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.max(a, b)
    return Vec3.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        math.max(a.z, b.z))
end

---Finds the lesser of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.min(a, b)
    return Vec3.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.min(a.z, b.z))
end

---Mixes two vectors together by a step.
---Defaults to mixing by a vector.
---@param a table origin
---@param b table destination
---@param t number|table step
---@return table
function Vec3.mix(a, b, t)
    if type(t) == "number" then
        return Vec3.mixNum(a, b, t)
    else
        return Vec3.mixVec2(a, b, t)
    end
end

---Mixes two vectors together by a step.
---The step is a number.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Vec3.mixNum(a, b, t)
    local v = t or 0.5
    local u = 1.0 - v
    return Vec3.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y,
        u * a.z + v * b.z)
end

---Mixes two vectors together by a step.
---The step is a vector. Use in conjunction
---with step, linearstep and smoothstep.
---@param a table origin
---@param b table destination
---@param t table step
---@return table
function Vec3.mixVec3(a, b, t)
    return Vec3.new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y,
        (1.0 - t.z) * a.z + t.z * b.z)
end

---Finds the remainder of floor division of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.mod(a, b)
    local cx = a.x
    local cy = a.y
    local cz = a.z
    if b.x ~= 0.0 then cx = a.x % b.x end
    if b.y ~= 0.0 then cy = a.y % b.y end
    if b.z ~= 0.0 then cz = a.z % b.z end
    return Vec3.new(cx, cy, cz)
end

---Negates a vector.
---@param a table vector
---@return table
function Vec3.negate(a)
    return Vec3.new(-a.x, -a.y, -a.z)
end

---Evaluates if all vector components are zero.
---@param a table
---@return boolean
function Vec3.none(a)
    return a.x == 0.0
        and a.y == 0.0
        and a.z == 0.0
end

---Divides a vector by its magnitude, such that it
---lies on the unit circle.
---@param a table vector
---@return table
function Vec3.normalize(a)
    local mSq = a.x * a.x + a.y * a.y + a.z * a.z
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Vec3.new(
            a.x * mInv,
            a.y * mInv,
            a.z * mInv)
    end
    return Vec3.new(0.0, 0.0, 0.0)
end

---Raises a vector to the power of another.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.pow(a, b)
    return Vec3.new(
        a.x ^ b.x,
        a.y ^ b.y,
        a.z ^ b.z)
end

---Finds the scalar projection of the left
---operand onto the right.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.projectScalar(a, b)
    local bSq = b.x * b.x + b.y * b.y + b.z * b.z
    if bSq > 0.0 then
        return (a.x * b.x
            + a.y * b.y
            + a.z * b.z) / bSq
    else
        return 0.0
    end
end

---Finds the vector projection of the left
---operand onto the right.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.projectVector(a, b)
    return Vec3.scale(b, Vec3.projectScalar(a, b))
end

---Reduces the granularity of a vector's components.
---@param a table vector
---@param levels integer levels
---@return table
function Vec3.quantize(a, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec3.new(
            delta * math.floor(0.5 + a.x * levels),
            delta * math.floor(0.5 + a.y * levels),
            delta * math.floor(0.5 + a.z * levels))
    end
    return Vec3.new(a.x, a.y, a.z)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. If lower and upper
---bounds are not given, defaults to [-1.0, 1.0].
---@param lb table|nil lower bound
---@param ub table|nil upper bound
---@return table
function Vec3.randomCartesian(lb, ub)
    local lval = lb or Vec3.new(-1.0, -1.0, -1.0)
    local uval = ub or Vec3.new(1.0, 1.0, 1.0)
    return Vec3.randomCartesianInternal(lval, uval)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. Does not validate
---upper or lower bounds.
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec3.randomCartesianInternal(lb, ub)
    local rx = math.random()
    local ry = math.random()
    local rz = math.random()

    return Vec3.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y,
        (1.0 - rz) * lb.z + rz * ub.z)
end

---Remaps a vector from an origin range to
---a destination range. For invalid origin
---ranges, the component remains unchanged.
---@param v table vector
---@param lbOrigin table origin lower bound
---@param ubOrigin table origin upper bound
---@param lbDest table destination lower bound
---@param ubDest table destination upper bound
---@return table
function Vec3.remap(v, lbOrigin, ubOrigin, lbDest, ubDest)
    local mx = v.x
    local my = v.y
    local mz = v.z

    local xDenom = ubOrigin.x - lbOrigin.x
    local yDenom = ubOrigin.y - lbOrigin.y
    local zDenom = ubOrigin.z - lbOrigin.z

    if xDenom ~= 0.0 then
        mx = lbDest.x + (ubDest.x - lbDest.x)
            * ((mx - lbOrigin.x) / xDenom)
    end

    if yDenom ~= 0.0 then
        my = lbDest.y + (ubDest.y - lbDest.y)
            * ((my - lbOrigin.y) / yDenom)
    end

    if zDenom ~= 0.0 then
        mz = lbDest.z + (ubDest.z - lbDest.z)
            * ((mz - lbOrigin.z) / zDenom)
    end

    return Vec3.new(mx, my, mz)
end

---Rescales a vector to the target magnitude.
---@param a table vector
---@param b number magnitude
---@return table
function Vec3.rescale(a, b)
    local mSq = a.x * a.x + a.y * a.y + a.z * a.z
    if mSq > 0.0 then
        local bmInv = b / math.sqrt(mSq)
        return Vec3.new(
            a.x * bmInv,
            a.y * bmInv,
            a.z * bmInv)
    end
    return Vec3.new(0.0, 0.0, 0.0)
end

---Rotates a vector around an axis by an angle
---in radians. Validates the axis to see if it is
---of unit length. Defaults to rotateZ.
---@param a table vector
---@param radians number angle
---@param axis table
---@return table
function Vec3.rotate(a, radians, axis)
    if axis and Vec3.any(axis) then
        return Vec3.rotateInternal(a,
            math.cos(radians), math.sin(radians),
            Vec3.normalize(axis))
    else
        return Vec3.rotateZ(a, radians)
    end
end

---Rotates a vector around the x axis by an angle
---in radians.
---@param a table vector
---@param radians number angle
---@return table
function Vec3.rotateX(a, radians)
    return Vec3.rotateXInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the y axis by an angle
---in radians.
---@param a table vector
---@param radians number angle
---@return table
function Vec3.rotateY(a, radians)
    return Vec3.rotateYInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the z axis by an angle
---in radians.
---@param a table vector
---@param radians number angle
---@return table
function Vec3.rotateZ(a, radians)
    return Vec3.rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around an axis by an angle
---in radians. The axis is assumed to be of unit
---length.
---@param a table vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@param axis table axis
---@return table
function Vec3.rotateInternal(a, cosa, sina, axis)
    local xAxis = axis.x
    local yAxis = axis.y
    local zAxis = axis.z

    local complCos = 1.0 - cosa
    local xyCompl = complCos * xAxis * yAxis
    local xzCompl = complCos * xAxis * zAxis
    local yzCompl = complCos * yAxis * zAxis

    local xSin = sina * xAxis
    local ySin = sina * yAxis
    local zSin = sina * zAxis

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

---Rotates a vector around the x axis by the cosine
---and sine of an angle. Used when rotating many
---vectors by the same angle.
---@param a table vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Vec3.rotateXInternal(a, cosa, sina)
    return Vec3.new(
        a.x,
        cosa * a.y - sina * a.z,
        cosa * a.z + sina * a.y)
end

---Rotates a vector around the y axis by the cosine
---and sine of an angle. Used when rotating many
---vectors by the same angle.
---@param a table vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Vec3.rotateYInternal(a, cosa, sina)
    return Vec3.new(
        cosa * a.x + sina * a.z,
        a.y,
        cosa * a.z - sina * a.x)
end

---Rotates a vector around the z axis by the cosine
---and sine of an angle. Used when rotating many
---vectors by the same angle.
---@param a table vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Vec3.rotateZInternal(a, cosa, sina)
    return Vec3.new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x,
        a.z)
end

---Rounds the vector by sign and fraction.
---@param a table left operand
---@return table
function Vec3.round(a)
    local iz, fz = math.modf(a.z)
    if iz <= 0 and fz <= -0.5 then iz = iz - 1
    elseif iz >= 0 and fz >= 0.5 then iz = iz + 1 end

    local iy, fy = math.modf(a.y)
    if iy <= 0 and fy <= -0.5 then iy = iy - 1
    elseif iy >= 0 and fy >= 0.5 then iy = iy + 1 end

    local ix, fx = math.modf(a.x)
    if ix <= 0 and fx <= -0.5 then ix = ix - 1
    elseif ix >= 0 and fx >= 0.5 then ix = ix + 1 end

    return Vec3.new(ix, iy, iz)
end

---Scales a vector, left, by a number, right.
---@param a table left operand
---@param b number right operand
---@return table
function Vec3.scale(a, b)
    return Vec3.new(
        a.x * b,
        a.y * b,
        a.z * b)
end

---Finds the sign of a vector by component.
---@param a table left operand
---@return table
function Vec3.sign(a)
    local cx = 0.0
    if a.x < -0.0 then cx = -1.0
    elseif a.x > 0.0 then cx = 1.0
    end

    local cy = 0.0
    if a.y < -0.0 then cy = -1.0
    elseif a.y > 0.0 then cy = 1.0
    end

    local cz = 0.0
    if a.z < -0.0 then cz = -1.0
    elseif a.z > 0.0 then cz = 1.0
    end

    return Vec3.new(cx, cy, cz)
end

---Finds the smooth step between a left and
---right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
function Vec3.smoothstep(edge0, edge1, x)
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

    return Vec3.new(cx, cy, cz)
end

---Finds the step between an edge and factor.
---@param edge table the edge
---@param x table the factor
---@return table
function Vec3.step(edge, x)
    local cx = 1.0
    if x.x < edge.x then cx = 0.0 end

    local cy = 1.0
    if x.y < edge.y then cy = 0.0 end

    local cz = 1.0
    if x.z < edge.z then cz = 0.0 end

    return Vec3.new(cx, cy, cz)
end

---Subtracts the right vector from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.sub(a, b)
    return Vec3.new(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z)
end

---Returns a JSON string of a vector.
---@param v table vector
---@return string
function Vec3.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f,\"z\":%.4f}",
        v.x, v.y, v.z)
end

---Converts a vector to spherical coordinates.
---Returns a table with 'radius', 'azimuth' and
---'inclination'.
---@param a table vector
---@return table
function Vec3.toSpherical(a)
    return {
        radius = Vec3.mag(a),
        azimuth = Vec3.azimuthSigned(a),
        inclination = Vec3.inclinationSigned(a)
    }
end

---Truncates a vector's components to integers.
---@param a table vector
---@return table
function Vec3.trunc(a)
    local iz, _ = math.modf(a.z)
    local iy, _ = math.modf(a.y)
    local ix, _ = math.modf(a.x)
    return Vec3.new(ix, iy, iz)
end

---Wraps a vector's components around a range
---defined by a lower and upper bound. If the
---range is invalid, the component is unchanged.
---@param a table vector
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec3.wrap(a, lb, ub)
    local cx = a.x
    local rx = ub.x - lb.x
    if rx ~= 0.0 then
        cx = a.x - rx * ((a.x - lb.x) // rx)
    end

    local cy = a.y
    local ry = ub.y - lb.y
    if ry ~= 0.0 then
        cy = a.y - ry * ((a.y - lb.y) // ry)
    end

    local cz = a.z
    local rz = ub.z - lb.z
    if rz ~= 0.0 then
        cz = a.z - rz * ((a.z - lb.z) // rz)
    end

    return Vec3.new(cx, cy, cz)
end

---Creates a right facing vector,
---(1.0, 0.0, 0.0).
---@return table
function Vec3.right()
    return Vec3.new(1.0, 0.0, 0.0)
end

---Creates a forward facing vector,
---(0.0, 1.0, 0.0).
---@return table
function Vec3.forward()
    return Vec3.new(0.0, 1.0, 0.0)
end

---Creates an up facing vector,
---(0.0, 0.0, 1.0).
---@return table
function Vec3.up()
    return Vec3.new(0.0, 0.0, 1.0)
end

---Creates a left facing vector,
---(-1.0, 0.0, 0.0).
---@return table
function Vec3.left()
    return Vec3.new(-1.0, 0.0, 0.0)
end

---Creates a back facing vector,
---(0.0, -1.0, 0.0).
---@return table
function Vec3.back()
    return Vec3.new(0.0, -1.0, 0.0)
end

---Creates a down facing vector,
---(0.0, 0.0, -1.0).
---@return table
function Vec3.down()
    return Vec3.new(0.0, 0.0, -1.0)
end

---Creates a vector with all components
---set to 1.0.
---@return table
function Vec3.one()
    return Vec3.new(1.0, 1.0, 1.0)
end

return Vec3
