Vec4 = {}
Vec4.__index = Vec4

setmetatable(Vec4, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new vector from four numbers.
---@param x number x component
---@param y number y component
---@param z number z component
---@param w number w component
---@return table
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
    return self.w == b.w
       and self.z == b.z
       and self.y == b.y
       and self.x == b.x
end

function Vec4:__idiv(b)
    return Vec4.floorDiv(self, b)
end

function Vec4:__le(b)
    return self.w <= b.w
       and self.z <= b.z
       and self.y <= b.y
       and self.x <= b.x
end

function Vec4:__len()
    return 4
end

function Vec4:__lt(b)
    return self.w < b.w
       and self.z < b.z
       and self.y < b.y
       and self.x < b.x
end

function Vec4:__mod(b)
    return Vec4.mod(self, b)
end

function Vec4:__mul(b)
    if type(b) == "number" then
        return Vec4.scale(self, b)
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
---@param a table vector
---@return table
function Vec4.abs(a)
    return Vec4.new(
        math.abs(a.x),
        math.abs(a.y),
        math.abs(a.z),
        math.abs(a.w))
end

---Finds the sum of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.add(a, b)
    return Vec4.new(
        a.x + b.x,
        a.y + b.y,
        a.z + b.z,
        a.w + b.w)
end

---Evaluates if all vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec4.all(a)
    return a.x ~= 0.0
       and a.y ~= 0.0
       and a.z ~= 0.0
       and a.w ~= 0.0
end

---Evaluates if any vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec4.any(a)
    return a.x ~= 0.0
        or a.y ~= 0.0
        or a.z ~= 0.0
        or a.w ~= 0.0
end

---Evaluates whether two vectors are, within a
---tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol number tolerance
---@return boolean
function Vec4.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
       and math.abs(b.y - a.y) <= eps
       and math.abs(b.z - a.z) <= eps
       and math.abs(b.w - a.w) <= eps
end

---Finds a point on a cubic Bezier curve
---according to a step in [0.0, 1.0] .
---@param ap0 table anchor point 0
---@param cp0 table control point 0
---@param cp1 table control point 1
---@param ap1 table anchor point 1
---@param step number step
---@return table
function Vec4.bezierPoint(ap0, cp0, cp1, ap1, step)
    local t = step or 0.5
    if t <= 0.0 then
        return Vec4.new(ap0.x, ap0.y, ap0.z, ap0.w)
    end
    if t >= 1.0 then
        return Vec4.new(ap1.x, ap1.y, ap1.z, ap1.w)
    end

    local u = 1.0 - t
    local tsq = t * t
    local usq = u * u
    local usq3t = usq * (t + t + t)
    local tsq3u = tsq * (u + u + u)
    local tcb = tsq * t
    local ucb = usq * u

    return Vec4.new(
        ap0.x * ucb + cp0.x * usq3t +
        cp1.x * tsq3u + ap1.x * tcb,
        ap0.y * ucb + cp0.y * usq3t +
        cp1.y * tsq3u + ap1.y * tcb,
        ap0.z * ucb + cp0.z * usq3t +
        cp1.z * tsq3u + ap1.z * tcb,
        ap0.w * ucb + cp0.w * usq3t +
        cp1.w * tsq3u + ap1.w * tcb)
end

---Finds the ceiling of the vector.
---@param a table left operand
---@return table
function Vec4.ceil(a)
    return Vec4.new(
        math.ceil(a.x),
        math.ceil(a.y),
        math.ceil(a.z),
        math.ceil(a.w))
end

---Copies the sign of the right operand
---to the magnitude of the left. Both
---operands are assumed to be Vec4s. Where
---the sign of b is zero, the result is zero.
---Equivalent to multiplying the
---absolute value of a and the sign of b.
---@param a table magnitude
---@param b table sign
---@return table
function Vec4.copySign(a, b)
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

    local cw = 0.0
    local awAbs = math.abs(a.w)
    if b.w < -0.0 then cw = -awAbs
    elseif b.w > 0.0 then cw = awAbs
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Finds the absolute difference between two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.diff(a, b)
    return Vec4.new(
        math.abs(a.x - b.x),
        math.abs(a.y - b.y),
        math.abs(a.z - b.z),
        math.abs(a.w - b.w))
end

---Finds the distance between two vectors.
---Defaults to Euclidean distance.
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.dist(a, b)
    return Vec4.distEuclidean(a, b)
end

---Finds the Chebyshev distance between two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.distChebyshev(a, b)
    return math.max(
        math.abs(b.x - a.x),
        math.abs(b.y - a.y),
        math.abs(b.z - a.z),
        math.abs(b.w - a.w))
end

---Finds the Euclidean distance between two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.distEuclidean(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local dw = b.w - a.w
    return math.sqrt(dx * dx
                   + dy * dy
                   + dz * dz
                   + dw * dw)
end

---Finds the Manhattan distance between two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.distManhattan(a, b)
    return math.abs(b.x - a.x)
         + math.abs(b.y - a.y)
         + math.abs(b.z - a.z)
         + math.abs(b.w - a.w)
end

---Finds the Minkowski distance between two vectors.
---When the exponent is 1, returns Manhattan distance.
---When the exponent is 2, returns Euclidean distance.
---@param a table left operand
---@param b table right operand
---@param c number exponent
---@return number
function Vec4.distMinkowski(a, b, c)
    local d = c or 2.0
    if d ~= 0.0 then
        return (math.abs(b.x - a.x) ^ d
              + math.abs(b.y - a.y) ^ d
              + math.abs(b.z - a.z) ^ d
              + math.abs(b.w - a.w) ^ d)
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
function Vec4.distSq(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local dw = b.w - a.w
    return dx * dx
         + dy * dy
         + dz * dz
         + dw * dw
end

---Divides the left vector by the right, component-wise.
---@param a table left operand
---@param b table right operand
---@return table
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
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.dot(a, b)
    return a.x * b.x
         + a.y * b.y
         + a.z * b.z
         + a.w * b.w
end

---Finds the floor of the vector.
---@param a table left operand
---@return table
function Vec4.floor(a)
    return Vec4.new(
        math.floor(a.x),
        math.floor(a.y),
        math.floor(a.z),
        math.floor(a.w))
end

---Finds the floor division of two vectors.
---@param a table left operand
---@param b table left operand
---@return table
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

---Finds the remainder of the division of the left
---operand by the right that rounds the quotient
---towards zero.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.fmod(a, b)
    local cx = a.x
    local cy = a.y
    local cz = a.z
    local cw = a.w
    if b.x ~= 0.0 then cx = math.fmod(a.x, b.x) end
    if b.y ~= 0.0 then cy = math.fmod(a.y, b.y) end
    if b.z ~= 0.0 then cz = math.fmod(a.z, b.z) end
    if b.w ~= 0.0 then cw = math.fmod(a.w, b.w) end
    return Vec4.new(cx, cy, cz, cw)
end

---Finds the fractional portion of of a vector.
---Subtracts the truncation of each component
---from itself, not the floor, unlike in GLSL.
---@param a table left operand
---@return table
function Vec4.fract(a)
    return Vec4.new(
        a.x - math.tointeger(a.x),
        a.y - math.tointeger(a.y),
        a.z - math.tointeger(a.z),
        a.w - math.tointeger(a.w))
end

---Creates a one-dimensional table of vectors
---arranged in a Cartesian grid from the lower
---to the upper bound. Both bounds are vectors.
---@param cols number columns
---@param rows number rows
---@param layers number layers
---@param strata number strata
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec4.gridCartesian(cols, rows, layers, strata, lb, ub)
    local ubVal = ub or Vec4.new(1.0, 1.0, 1.0, 1.0)
    local lbVal = lb or Vec4.new(-1.0, -1.0, -1.0, -1.0)

    local sVal = strata or 2
    local lVal = layers or 2
    local rVal = rows or 2
    local cVal = cols or 2

    if sVal < 2 then sVal = 2 end
    if lVal < 2 then lVal = 2 end
    if rVal < 2 then rVal = 2 end
    if cVal < 2 then cVal = 2 end

    local lbx = lbVal.x
    local lby = lbVal.y
    local lbz = lbVal.z
    local lbw = lbVal.w

    local ubx = ubVal.x
    local uby = ubVal.y
    local ubz = ubVal.z
    local ubw = ubVal.w

    local gToStep = 1.0 / (sVal - 1.0)
    local hToStep = 1.0 / (lVal - 1.0)
    local iToStep = 1.0 / (rVal - 1.0)
    local jToStep = 1.0 / (cVal - 1.0)

    local rcVal = rVal * cVal
    local lrcVal = lVal * rcVal
    local length = sVal * lrcVal - 1
    local result = {}

    for k = 0, length, 1 do
        local g = k // lrcVal
        local m = k - g * lrcVal
        local h = m // rcVal
        local n = m - h * rcVal

        local gStep = g * gToStep
        local hStep = h * hToStep
        local iStep = (n // cVal) * iToStep
        local jStep = (n % cVal) * jToStep

        result[1 + k] = Vec4.new(
            (1.0 - jStep) * lbx + jStep * ubx,
            (1.0 - iStep) * lby + iStep * uby,
            (1.0 - hStep) * lbz + hStep * ubz,
            (1.0 - gStep) * lbw + gStep * ubw)
    end

    return result
end

---Multiplies two vectors component-wise.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.hadamard(a, b)
    return Vec4.new(
        a.x * b.x,
        a.y * b.y,
        a.z * b.z,
        a.w * b.w)
end

---Finds a signed integer hash code for a vector.
---@param a table vector
---@return integer
function Vec4.hashCode(a)
    local xBits = string.unpack("i4",
        string.pack("f", a.x))
    local yBits = string.unpack("i4",
        string.pack("f", a.y))
    local zBits = string.unpack("i4",
        string.pack("f", a.z))
    local wBits = string.unpack("i4",
        string.pack("f", a.w))

    local hsh = (((84696351 ~ xBits)
        * 16777619 ~ yBits)
        * 16777619 ~ zBits)
        * 16777619 ~ wBits

    local hshInt = hsh & 0xffffffff
    if hshInt & 0x80000000 then
        return -((~hshInt & 0xffffffff) + 1)
    else
        return hshInt
    end
end

---Limits a vector's magnitude to a scalar.
---Returns a copy of the vector if it is beneath
---the limit.
---@param a table the vector
---@param limit number the limit number
---@return table
function Vec4.limit(a, limit)
    local mSq = a.x * a.x
              + a.y * a.y
              + a.z * a.z
              + a.w * a.w
    if mSq > 0.0 and mSq > (limit * limit) then
        local mInv = limit / math.sqrt(mSq)
        return Vec4.new(
            a.x * mInv,
            a.y * mInv,
            a.z * mInv,
            a.w * mInv)
    end
    return Vec4.new(a.x, a.y, a.z, a.w)
end

---Finds the linear step between a left and
---right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
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
---@param a table left operand
---@return number
function Vec4.mag(a)
    return math.sqrt(
          a.x * a.x
        + a.y * a.y
        + a.z * a.z
        + a.w * a.w)
end

---Finds a vector's magnitude squared.
---@param a table left operand
---@return number
function Vec4.magSq(a)
    return a.x * a.x
         + a.y * a.y
         + a.z * a.z
         + a.w * a.w
end

---Finds the greater of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.max(a, b)
    return Vec4.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y),
        math.max(a.z, b.z),
        math.max(a.w, b.w))
end

---Finds the lesser of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.min(a, b)
    return Vec4.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.min(a.z, b.z),
        math.min(a.w, b.w))
end

---Mixes two vectors together by a step.
---Defaults to mixing by a vector.
---@param a table origin
---@param b table destination
---@param t any step
---@return table
function Vec4.mix(a, b, t)
    if type(t) == "number" then
        return Vec4.mixNum(a, b, t)
    else
        return Vec4.mixVec2(a, b, t)
    end
end

---Mixes two vectors together by a step.
---The step is a number.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
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
---@param a table origin
---@param b table destination
---@param t table step
---@return table
function Vec4.mixVec4(a, b, t)
    return Vec4.new(
         (1.0 - t.x) * a.x + t.x * b.x,
         (1.0 - t.y) * a.y + t.y * b.y,
         (1.0 - t.z) * a.z + t.z * b.z,
         (1.0 - t.w) * a.w + t.w * b.w)
end

---Finds the remainder of floor division of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
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
---@param a table vector
---@return table
function Vec4.negate(a)
    return Vec4.new(-a.x, -a.y, -a.z, -a.w)
end

---Evaluates if all vector components are zero.
---@param a table
---@return boolean
function Vec4.none(a)
    return a.x == 0.0
       and a.y == 0.0
       and a.z == 0.0
       and a.w == 0.0
end

---Divides a vector by its magnitude, such that it
---lies on the unit circle.
---@param a table vector
---@return table
function Vec4.normalize(a)
    local mSq = a.x * a.x
              + a.y * a.y
              + a.z * a.z
              + a.w * a.w
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Vec4.new(
            a.x * mInv,
            a.y * mInv,
            a.z * mInv,
            a.w * mInv)
    end
    return Vec4.new(0.0, 0.0, 0.0, 0.0)
end

---Raises a vector to the power of another.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.pow(a, b)
    return Vec4.new(
        a.x ^ b.x,
        a.y ^ b.y,
        a.z ^ b.z,
        a.w ^ b.w)
end

---Finds the scalar projection of the left
---operand onto the right.
---@param a table left operand
---@param b table right operand
---@return number
function Vec4.projectScalar(a, b)
    local bSq = b.x * b.x
              + b.y * b.y
              + b.z * b.z
              + b.w * b.w
    if bSq > 0.0 then
        return (a.x * b.x
              + a.y * b.y
              + a.z * b.z
              + a.w * b.w) / bSq
    else
        return 0.0
    end
end

---Finds the vector projection of the left
---operand onto the right.
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.projectVector(a, b)
    return Vec4.scale(b, Vec4.projectScalar(a, b))
end

---Reduces the granularity of a vector's components.
---@param a table vector
---@param levels integer levels
---@return table
function Vec4.quantize(a, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec4.new(
            delta * math.floor(0.5 + a.x * levels),
            delta * math.floor(0.5 + a.y * levels),
            delta * math.floor(0.5 + a.z * levels),
            delta * math.floor(0.5 + a.w * levels))
    end
    return Vec4.new(a.x, a.y, a.z, a.w)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. If lower and upper
---bounds are not given, defaults to [-1.0, 1.0].
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec4.randomCartesian(lb, ub)
    local lval = lb or Vec4.new(-1.0, -1.0, -1.0, -1.0)
    local uval = ub or Vec4.new(1.0, 1.0, 1.0, 1.0)
    return Vec4.randomCartesianInternal(lval, uval)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. Does not validate
---upper or lower bounds.
---@param lb table lower bound
---@param ub table upper bound
---@return table
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

---Remaps a vector from an origin range to
---a destination range. For invalid origin
---ranges, the component remains unchanged.
---@param v table vector
---@param lbOrigin table origin lower bound
---@param ubOrigin table origin upper bound
---@param lbDest table destination lower bound
---@param ubDest table destination upper bound
---@return table
function Vec4.remap(v, lbOrigin, ubOrigin, lbDest, ubDest)
    local mx = v.x
    local my = v.y
    local mz = v.z
    local mw = v.w

    local xDenom = ubOrigin.x - lbOrigin.x
    local yDenom = ubOrigin.y - lbOrigin.y
    local zDenom = ubOrigin.z - lbOrigin.z
    local wDenom = ubOrigin.w - lbOrigin.w

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

    if wDenom ~= 0.0 then
        mw = lbDest.w + (ubDest.w - lbDest.w)
            * ((mw - lbOrigin.w) / wDenom)
    end

    return Vec4.new(mx, my, mz, mw)
end

---Rescales a vector to the target magnitude.
---@param a table vector
---@param b number magnitude
---@return table
function Vec4.rescale(a, b)
    local mSq = a.x * a.x
              + a.y * a.y
              + a.z * a.z
              + a.w * a.w
    if mSq > 0.0 then
        local bmInv = b / math.sqrt(mSq)
        return Vec4.new(
            a.x * bmInv,
            a.y * bmInv,
            a.z * bmInv,
            a.w * bmInv)
    end
    return Vec4.new(0.0, 0.0, 0.0, 0.0)
end

---Rounds the vector by sign and fraction.
---@param a table left operand
---@return table
function Vec4.round(a)
    local cx = 0.0
    if a.x < -0.0 then
        cx = math.tointeger(a.x - 0.5)
    elseif a.x > 0.0 then
        cx = math.tointeger(a.x + 0.5)
    end

    local cy = 0.0
    if a.y < -0.0 then
        cy = math.tointeger(a.y - 0.5)
    elseif a.y > 0.0 then
        cy = math.tointeger(a.y + 0.5)
    end

    local cz = 0.0
    if a.z < -0.0 then
        cz = math.tointeger(a.z - 0.5)
    elseif a.z > 0.0 then
        cz = math.tointeger(a.z + 0.5)
    end

    local cw = 0.0
    if a.w < -0.0 then
        cw = math.tointeger(a.w - 0.5)
    elseif a.w > 0.0 then
        cw = math.tointeger(a.w + 0.5)
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Scales a vector, left, by a number, right.
---@param a table left operand
---@param b number right operand
---@return table
function Vec4.scale(a, b)
    return Vec4.new(
        a.x * b,
        a.y * b,
        a.z * b,
        a.w * b)
end

---Finds the sign of a vector by component.
---@param a table left operand
---@return table
function Vec4.sign(a)
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

    local cw = 0.0
    if a.w < -0.0 then cw = -1.0
    elseif a.w > 0.0 then cw = 1.0
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Finds the smooth step between a left and
---right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
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
---@param edge table the edge
---@param x table the factor
---@return table
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
---@param a table left operand
---@param b table right operand
---@return table
function Vec4.sub(a, b)
    return Vec4.new(
        a.x - b.x,
        a.y - b.y,
        a.z - b.z,
        a.w - b.w)
end

---Returns a JSON string of a vector.
---@param v table vector
---@return string
function Vec4.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f,\"z\":%.4f,\"w\":%.4f}",
        v.x, v.y, v.z, v.w)
end

---Truncates a vector's components to integers.
---@param a table vector
---@return table
function Vec4.trunc(a)
    return Vec4.new(
        math.tointeger(a.x),
        math.tointeger(a.y),
        math.tointeger(a.z),
        math.tointeger(a.w))
end

---Wraps a vector's components around a range
---defined by a lower and upper bound. If the
---range is invalid, the component is unchanged.
---@param a table vector
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec4.wrap(a, lb, ub)
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

    local cw = a.w
    local rw = ub.w - lb.w
    if rw ~= 0.0 then
        cw = a.w - rw * ((a.w - lb.w) // rw)
    end

    return Vec4.new(cx, cy, cz, cw)
end

---Creates a right facing vector,
---(1.0, 0.0, 0.0, 0.0).
---@return table
function Vec4.right()
    return Vec4.new(1.0, 0.0, 0.0, 0.0)
end

---Creates a forward facing vector,
---(0.0, 1.0, 0.0, 0.0).
---@return table
function Vec4.forward()
    return Vec4.new(0.0, 1.0, 0.0, 0.0)
end

---Creates an up facing vector,
---(0.0, 0.0, 1.0, 0.0).
---@return table
function Vec4.up()
    return Vec4.new(0.0, 0.0, 1.0, 0.0)
end

---Creates a left facing vector,
---(-1.0, 0.0, 0.0, 0.0).
---@return table
function Vec4.left()
    return Vec4.new(-1.0, 0.0, 0.0, 0.0)
end

---Creates a back facing vector,
---(0.0, -1.0, 0.0, 0.0).
---@return table
function Vec4.back()
    return Vec4.new(0.0, -1.0, 0.0, 0.0)
end

---Creates a down facing vector,
---(0.0, 0.0, -1.0, 0.0).
---@return table
function Vec4.down()
    return Vec4.new(0.0, 0.0, -1.0, 0.0)
end

---Creates a vector with all components
---set to 1.0.
---@return table
function Vec4.one()
    return Vec4.new(1.0, 1.0, 1.0, 1.0)
end

return Vec4