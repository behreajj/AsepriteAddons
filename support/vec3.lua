Vec3 = {}
Vec3.__index = Vec3

setmetatable(Vec3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new vector from two numbers.
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
    return self.x == b.x
       and self.y == b.y
       and self.z == b.z
end

function Vec3:__idiv(b)
    return Vec3.floorDiv(self, b)
end

function Vec3:__le(b)
    return self.x <= b.x
       and self.y <= b.y
       and self.z <= b.z
end

function Vec3:__len()
    return 3
end

function Vec3:__lt(b)
    return self.x < b.x
       and self.y < b.y
       and self.z < b.z
end

function Vec3:__mod(b)
    return Vec3.mod(self, b)
end

function Vec3:__mul(b)
    return Vec3.mul(self, b)
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

---Finds the angle between two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.angleBetween(a, b)
    if Vec3.any(a) and Vec3.any(b) then
        return math.acos(Vec3.dot(a, b) /
            (Vec3.mag(a) * Vec3.mag(b)))
    else
        return 0.0
    end
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
---@param tol number tolerance
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
    return math.atan(a.y, a.x) % 6.283185307179586
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

---Finds the ceiling of the vector.
---@param a table left operand
---@return table
function Vec3.ceil(a)
    return Vec3.new(
        math.ceil(a.x),
        math.ceil(a.y),
        math.ceil(a.z))
end

---Clamps a vector to a lower and upper bound
---@param a table left operand
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec3.clamp(a, lb, ub)
    return Vec3.new(
        math.min(math.max(a.x, lb.x), ub.x),
        math.min(math.max(a.y, lb.y), ub.y),
        math.min(math.max(a.z, lb.z), ub.z))
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
---Forms a square pattern when plotted.
---@param a table left operand
---@param b table right operand
---@return number
function Vec3.distChebyshev(a, b)
    return math.max(
        math.abs(a.x - b.x),
        math.abs(a.y - b.y),
        math.abs(a.z - b.z))
end

---Finds the Euclidean distance between two vectors.
---Forms a circle when plotted.
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
---Forms a diamond when plotted.
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
---@param a table left operand
---@return table
function Vec3.fract(a)
    return Vec3.new(
        a.x - math.tointeger(a.x),
        a.y - math.tointeger(a.y),
        a.z - math.tointeger(a.z))
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
    local mSq = a.x * a.x + a.y * a.y + a.z * a.z
    if mSq > 0.0 then
        return math.asin(a.z / math.sqrt(mSq))
    else
        return 0.0
    end
end

---Finds the vector's unsigned inclination.
---@param a table left operand
---@return number
function Vec3.inclinationUnsigned(a)
    return Vec3.inclinationSigned(a) % 6.283185307179586
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
---@param t any step
---@return table
function Vec3.mix(a, b, t)
    return Vec3.mixByVec3(a, b, t)
end

---Mixes two vectors together by a step.
---The step is a number.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Vec3.mixByNumber(a, b, t)
    local v = t or 0.5
    local u = 1.0 - v
    return Vec3.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y,
        u * a.z + v * b.z)
end

---Mixes two vectors together by a step.
---The step is a vector; use in conjunction
---with step, linearstep and smoothstep.
---@param a table origin
---@param b table destination
---@param t table step
---@return table
function Vec3.mixByVec3(a, b, t)
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

---Multiplies two vectors component-wise.
---A shortcut for multiplying a matrix and vector.
---@param a table left operand
---@param b table right operand
---@return table
function Vec3.mul(a, b)
    return Vec3.new(
        a.x * b.x,
        a.y * b.y,
        a.z * b.z)
end

---Negates a vector.
---@param a table vector
---@return table
function Vec3.negate(a)
    return Vec3.new(-a.x, -a.y, -a.z)
end

---Evaluates if no vector components are non-zero.
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
---a lower and an upper bound.
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec3.randomCartesian(lb, ub)
    local rx = math.random()
    local ry = math.random()
    local rz = math.random()

    return Vec3.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y,
        (1.0 - rz) * lb.z + rz * ub.z)
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

---Rotates a vector around the x axis by an angle
---in radians.
---@param a table left operand
---@param radians number angle
---@return table
function Vec3.rotateX(a, radians)
    return Vec3.rotateXInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the y axis by an angle
---in radians.
---@param a table left operand
---@param radians number angle
---@return table
function Vec3.rotateY(a, radians)
    return Vec3.rotateYInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the z axis by an angle
---in radians.
---@param a table left operand
---@param radians number angle
---@return table
function Vec3.rotateZ(a, radians)
    return Vec3.rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector around the x axis by the cosine
---and sine of an angle. Used when rotating many
---vectors by the same angle.
---@param a table left operand
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
---@param a table left operand
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
---@param a table left operand
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

    return Vec3.new(cx, cy, cz)
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

    return Vec3.new(
        cx * cx * (3.0 - (cx + cx)),
        cy * cy * (3.0 - (cy + cy)),
        cz * cz * (3.0 - (cz + cz)))
end

---Finds the step between an edge and factor.
---@param edge table the edge
---@param x table the factor
---@return table
function Vec3.step(edge, x)
    local cx = 1.0
    local cy = 1.0
    local cz = 1.0

    if x.x < edge.x then cx = 0.0 end
    if x.y < edge.y then cy = 0.0 end
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

---Truncates a vector's components to integers.
---@param a table vector
---@return table
function Vec3.trunc(a)
    return Vec3.new(
        math.tointeger(a.x),
        math.tointeger(a.y),
        math.tointeger(a.z))
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