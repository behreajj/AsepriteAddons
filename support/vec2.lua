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
function Vec2.new(x, y)
    local inst = setmetatable({}, Vec2)
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
function Vec2.abs(v)
    return Vec2.new(
        math.abs(v.x),
        math.abs(v.y))
end

---Finds the sum of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.add(a, b)
    return Vec2.new(
        a.x + b.x,
        a.y + b.y)
end

---Evaluates if all vector components are non-zero.
---@param v Vec2 vector
---@return boolean
function Vec2.all(v)
    return v.x ~= 0.0 and v.y ~= 0.0
end

---Finds the angle between two vectors. If either
---vector has no magnitude, returns zero. Uses the
---formula acos(dot(a, b) / (mag(a) * mag(b))).
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.angleBetween(a, b)
    local aSq = a.x * a.x + a.y * a.y
    if aSq > 0.0 then
        local bSq = b.x * b.x + b.y * b.y
        if bSq > 0.0 then
            return math.acos(
                (a.x * b.x + a.y * b.y)
                / (math.sqrt(aSq) * math.sqrt(bSq)))
        end
    end
    return 0.0
end

---Evaluates if any vector components are non-zero.
---@param v Vec2 vector
---@return boolean
function Vec2.any(v)
    return v.x ~= 0.0 or v.y ~= 0.0
end

---Evaluates whether two vectors are, within a
---tolerance, approximately equal.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@param tol number? tolerance
---@return boolean
function Vec2.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
end

---Finds a point on a cubic Bezier curve
---according to a step in [0.0, 1.0] .
---@param ap0 Vec2 anchor point 0
---@param cp0 Vec2 control point 0
---@param cp1 Vec2 control point 1
---@param ap1 Vec2 anchor point 1
---@param step number step
---@return Vec2
function Vec2.bezierPoint(ap0, cp0, cp1, ap1, step)
    local t = step or 0.5
    if t <= 0.0 then return Vec2.new(ap0.x, ap0.y) end
    if t >= 1.0 then return Vec2.new(ap1.x, ap1.y) end

    local u = 1.0 - t
    local tsq = t * t
    local usq = u * u
    local usq3t = usq * (t + t + t)
    local tsq3u = tsq * (u + u + u)
    local tcb = tsq * t
    local ucb = usq * u

    return Vec2.new(
        ap0.x * ucb + cp0.x * usq3t +
        cp1.x * tsq3u + ap1.x * tcb,
        ap0.y * ucb + cp0.y * usq3t +
        cp1.y * tsq3u + ap1.y * tcb)
end

---Bisects an array of vectors to find
---the appropriate insertion point for
---a vector. Biases towards the right insert
---point. Should be used with sorted arrays.
---@param arr Vec2[] vectors array
---@param elm Vec2 vector
---@param compare function? comparator
---@return integer
function Vec2.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    local f = compare or Vec2.comparator
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
---@param v Vec2 vector
---@return Vec2
function Vec2.ceil(v)
    return Vec2.new(
        math.ceil(v.x),
        math.ceil(v.y))
end

---A comparator method to sort vectors
---in a table according to their highest
---dimension first.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
function Vec2.comparator(a, b)
    if a.y < b.y then return true end
    if a.y > b.y then return false end
    return a.x < b.x
end

---Copies the sign of the right operand to
---the magnitude of the left. Both operands
---are assumed to be Vec2s. Where the sign of
---b is zero, the result is zero.
---@param a Vec2 magnitude
---@param b Vec2 sign
---@return Vec2
function Vec2.copySign(a, b)
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

    return Vec2.new(cx, cy)
end

---Finds the cross product of two vectors, z component.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.cross(a, b)
    return a.x * b.y - a.y * b.x
end

---Finds the absolute difference between two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.diff(a, b)
    return Vec2.new(
        math.abs(a.x - b.x),
        math.abs(a.y - b.y))
end

---Finds the distance between two vectors.
---Defaults to Euclidean distance.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.dist(a, b)
    return Vec2.distEuclidean(a, b)
end

---Finds the Chebyshev distance between two vectors.
---Forms a square when plotted.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.distChebyshev(a, b)
    return math.max(
        math.abs(b.x - a.x),
        math.abs(b.y - a.y))
end

---Finds the Euclidean distance between two vectors.
---Forms a circle when plotted.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.distEuclidean(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

---Finds the Manhattan distance between two vectors.
---Forms a diamond when plotted.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.distManhattan(a, b)
    return math.abs(b.x - a.x)
        + math.abs(b.y - a.y)
end

---Finds the Minkowski distance between two vectors.
---When the exponent is 1, returns Manhattan distance.
---When the exponent is 2, returns Euclidean distance.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@param c number exponent
---@return number
function Vec2.distMinkowski(a, b, c)
    local d = c or 2.0
    if d ~= 0.0 then
        return (math.abs(b.x - a.x) ^ d
            + math.abs(b.y - a.y) ^ d)
            ^ (1.0 / d)
    end
    return 0.0
end

---Finds the squared Euclidean distance between
---two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.distSq(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return dx * dx + dy * dy
end

---Divides the left vector by the right, component-wise.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.div(a, b)
    local cx = 0.0
    local cy = 0.0
    if b.x ~= 0.0 then cx = a.x / b.x end
    if b.y ~= 0.0 then cy = a.y / b.y end
    return Vec2.new(cx, cy)
end

---Finds the dot product between two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.dot(a, b)
    return a.x * b.x + a.y * b.y
end

---Evaluates whether two vectors are exactly
---equal. Checks for reference equality prior
---to value equality.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
function Vec2.equals(a, b)
    return rawequal(a, b)
        or Vec2.equalsValue(a, b)
end

---Evaluates whether two vectors are exactly
---equal by component value.
---@param a Vec2 left comparisand
---@param b Vec2 right comparisand
---@return boolean
function Vec2.equalsValue(a, b)
    return a.y == b.y
        and a.x == b.x
end

---Finds the floor of the vector.
---@param v Vec2 vector
---@return Vec2
function Vec2.floor(v)
    return Vec2.new(
        math.floor(v.x),
        math.floor(v.y))
end

---Finds the floor division of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.floorDiv(a, b)
    local cx = 0.0
    local cy = 0.0
    if b.x ~= 0.0 then cx = a.x // b.x end
    if b.y ~= 0.0 then cy = a.y // b.y end
    return Vec2.new(cx, cy)
end

---Finds the fractional portion of of a vector.
---Subtracts the truncation of each component
---from itself, not the floor, unlike in GLSL.
---@param v Vec2 vector
---@return Vec2
function Vec2.fract(v)
    return Vec2.new(
        math.fmod(v.x, 1.0),
        math.fmod(v.y, 1.0))
end

---Converts from polar to Cartesian coordinates.
---The heading, or azimuth, is in radians.
---The radius defaults to 1.0.
---@param heading number heading, theta
---@param radius number? radius, rho
---@return Vec2
function Vec2.fromPolar(heading, radius)
    local r = radius or 1.0
    return Vec2.new(
        r * math.cos(heading),
        r * math.sin(heading))
end

---Multiplies two vectors component-wise.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.hadamard(a, b)
    return Vec2.new(
        a.x * b.x,
        a.y * b.y)
end

---Finds a signed integer hash code for a vector.
---@param v Vec2 vector
---@return integer
function Vec2.hashCode(v)
    local xBits = string.unpack("i4",
        string.pack("f", v.x))
    local yBits = string.unpack("i4",
        string.pack("f", v.y))
    local hsh = (84696351 ~ xBits) * 16777619 ~ yBits

    -- QUERY: Use another string pack/unpack instead?
    local hshInt = hsh & 0xffffffff
    if hshInt & 0x80000000 then
        return -((~hshInt & 0xffffffff) + 1)
    else
        return hshInt
    end
end

---Finds a vector's heading.
---Defaults to the signed heading.
---@param v Vec2 vector
---@return number
function Vec2.heading(v)
    return Vec2.headingSigned(v)
end

---Finds a vector's signed heading, in [-pi, pi].
---@param v Vec2 vector
---@return number
function Vec2.headingSigned(v)
    return math.atan(v.y, v.x)
end

---Finds a vector's unsigned heading, in [0.0, tau].
---@param v Vec2 vector
---@return number
function Vec2.headingUnsigned(v)
    return math.atan(v.y, v.x) % 6.2831853071796
end

---Inserts a vector into a table so as to
---maintain sorted order. Biases toward the right
---insertion point. Returns true if the unique
---vector was inserted; false if not.
---@param arr Vec2[] vectors array
---@param elm Vec2 vector
---@param compare function comparator
---@return boolean
function Vec2.insortRight(arr, elm, compare)
    local i = Vec2.bisectRight(arr, elm, compare)
    local dupe = arr[i - 1]
    if dupe and Vec2.equals(dupe, elm) then
        return false
    end
    table.insert(arr, i, elm)
    return true
end

---Finds the linear step between a left and
---right edge given a factor.
---@param edge0 Vec2 left edge
---@param edge1 Vec2 right edge
---@param x Vec2 factor
---@return Vec2
function Vec2.linearstep(edge0, edge1, x)
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

    return Vec2.new(cx, cy)
end

---Finds a vector's magnitude, or length.
---@param v Vec2 vector
---@return number
function Vec2.mag(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

---Finds a vector's magnitude squared.
---@param v Vec2 vector
---@return number
function Vec2.magSq(v)
    return v.x * v.x + v.y * v.y
end

---Finds the greater of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.max(a, b)
    return Vec2.new(
        math.max(a.x, b.x),
        math.max(a.y, b.y))
end

---Finds the lesser of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.min(a, b)
    return Vec2.new(
        math.min(a.x, b.x),
        math.min(a.y, b.y))
end

---Mixes two vectors together by a step.
---Defaults to mixing by a vector.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t Vec2|number step
---@return Vec2
function Vec2.mix(a, b, t)
    if type(t) == "number" then
        return Vec2.mixNum(a, b, t)
    end
    return Vec2.mixVec2(a, b, t)
end

---Mixes two vectors together by a step.
---The step is a number.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t number step
---@return Vec2
function Vec2.mixNum(a, b, t)
    local v = t or 0.5
    local u = 1.0 - v
    return Vec2.new(
        u * a.x + v * b.x,
        u * a.y + v * b.y)
end

---Mixes two vectors together by a step.
---The step is a vector. Use in conjunction
---with step, linearstep and smoothstep.
---@param a Vec2 origin
---@param b Vec2 destination
---@param t Vec2 step
---@return Vec2
function Vec2.mixVec2(a, b, t)
    return Vec2.new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y)
end

---Finds the remainder of floor division of two vectors.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.mod(a, b)
    local cx = a.x
    local cy = a.y
    if b.x ~= 0.0 then cx = a.x % b.x end
    if b.y ~= 0.0 then cy = a.y % b.y end
    return Vec2.new(cx, cy)
end

---Negates a vector.
---@param v Vec2 vector
---@return Vec2
function Vec2.negate(v)
    return Vec2.new(-v.x, -v.y)
end

---Evaluates if all vector components are zero.
---@param v Vec2 vector
---@return boolean
function Vec2.none(v)
    return v.x == 0.0 and v.y == 0.0
end

---Divides a vector by its magnitude, such that it
---lies on the unit circle.
---@param v Vec2 vector
---@return Vec2
function Vec2.normalize(v)
    local mSq = v.x * v.x + v.y * v.y
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Vec2.new(
            v.x * mInv,
            v.y * mInv)
    end
    return Vec2.new(0.0, 0.0)
end

---Finds the perpendicular to a vector.
---Defaults to the counter-clockwise direction.
---@param v Vec2 vector
---@return Vec2
function Vec2.perpendicular(v)
    return Vec2.perpendicularCcw(v)
end

---Finds the counter-clockwise perpendicular to
---a vector.
---@param v Vec2 vector
---@return Vec2
function Vec2.perpendicularCcw(v)
    return Vec2.new(-v.y, v.x)
end

---Finds the clockwise perpendicular to a vector.
---@param v Vec2 vector
---@return Vec2
function Vec2.perpendicularCw(v)
    return Vec2.new(v.y, -v.x)
end

---Raises a vector to the power of another.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.pow(a, b)
    return Vec2.new(
        a.x ^ b.x,
        a.y ^ b.y)
end

---Finds the scalar projection of the left
---operand onto the right.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return number
function Vec2.projectScalar(a, b)
    local bSq = b.x * b.x + b.y * b.y
    if bSq > 0.0 then
        return (a.x * b.x + a.y * b.y) / bSq
    end
    return 0.0
end

---Finds the vector projection of the left
---operand onto the right.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.projectVector(a, b)
    return Vec2.scale(b, Vec2.projectScalar(a, b))
end

---Reduces the granularity of a vector's components.
---@param v Vec2 vector
---@param levels integer levels
---@return Vec2
function Vec2.quantize(v, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec2.new(
            delta * math.floor(0.5 + v.x * levels),
            delta * math.floor(0.5 + v.y * levels))
    end
    return Vec2.new(v.x, v.y)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. If lower and upper
---bounds are not given, defaults to [-1.0, 1.0].
---@param lb Vec2? lower bound
---@param ub Vec2? upper bound
---@return Vec2
function Vec2.randomCartesian(lb, ub)
    local lval = lb or Vec2.new(-1.0, -1.0)
    local uval = ub or Vec2.new(1.0, 1.0)
    return Vec2.randomCartesianInternal(lval, uval)
end

---Creates a random point in Cartesian space given
---a lower and an upper bound. Does not validate
---upper or lower bounds.
---@param lb Vec2 lower bound
---@param ub Vec2 upper bound
---@return Vec2
function Vec2.randomCartesianInternal(lb, ub)
    local rx = math.random()
    local ry = math.random()

    return Vec2.new(
        (1.0 - rx) * lb.x + rx * ub.x,
        (1.0 - ry) * lb.y + ry * ub.y)
end

---Remaps a vector from an origin range to
---a destination range. For invalid origin
---ranges, the component remains unchanged.
---@param v Vec2 vector
---@param lbOrigin Vec2 origin lower bound
---@param ubOrigin Vec2 origin upper bound
---@param lbDest Vec2 destination lower bound
---@param ubDest Vec2 destination upper bound
---@return Vec2
function Vec2.remap(v, lbOrigin, ubOrigin, lbDest, ubDest)
    local mx = v.x
    local my = v.y

    local xDenom = ubOrigin.x - lbOrigin.x
    local yDenom = ubOrigin.y - lbOrigin.y

    if xDenom ~= 0.0 then
        mx = lbDest.x + (ubDest.x - lbDest.x)
            * ((mx - lbOrigin.x) / xDenom)
    end

    if yDenom ~= 0.0 then
        my = lbDest.y + (ubDest.y - lbDest.y)
            * ((my - lbOrigin.y) / yDenom)
    end

    return Vec2.new(mx, my)
end

---Rescales a vector to the target magnitude.
---@param a Vec2 vector
---@param b number magnitude
---@return Vec2
function Vec2.rescale(a, b)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 then
        local bmInv = b / math.sqrt(mSq)
        return Vec2.new(
            a.x * bmInv,
            a.y * bmInv)
    end
    return Vec2.new(0.0, 0.0)
end

---Rotates a vector by an angle in radians
---around the x axis. For use in 2.5D.
---@param a Vec2 vector
---@param radians number angle
---@return Vec2
function Vec2.rotateX(a, radians)
    local cr = math.cos(radians)
    return Vec2.rotateXInternal(a, cr)
end

---Rotates a vector by the cosine of an angle.
---Used when rotating many vectors by the same angle.
---@param a Vec2 vector
---@param cosa number cosine of the angle
---@return Vec2
function Vec2.rotateXInternal(a, cosa)
    return Vec2.new(a.x, a.y * cosa)
end

---Rotates a vector by an angle in radians
---around the y axis. For use in 2.5D.
---@param a Vec2 vector
---@param radians number angle
---@return Vec2
function Vec2.rotateY(a, radians)
    local cr = math.cos(radians)
    return Vec2.rotateYInternal(a, cr)
end

---Rotates a vector by the cosine of an angle.
---Used when rotating many vectors by the same angle.
---@param a Vec2 vector
---@param cosa number cosine of the angle
---@return Vec2
function Vec2.rotateYInternal(a, cosa)
    return Vec2.new(a.x * cosa, a.y)
end

---Rotates a vector by an angle in radians
---around the z axis.
---@param a Vec2 vector
---@param radians number angle
---@return Vec2
function Vec2.rotateZ(a, radians)
    return Vec2.rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

---Rotates a vector by the cosine and sine of an angle.
---Used when rotating many vectors by the same angle.
---@param a Vec2 vector
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Vec2
function Vec2.rotateZInternal(a, cosa, sina)
    return Vec2.new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x)
end

---Rounds a vector according to its sign.
---@param v Vec2 vector
---@return Vec2
function Vec2.round(v)
    local ix, fx = math.modf(v.x)
    if ix <= 0 and fx <= -0.5 then ix = ix - 1
    elseif ix >= 0 and fx >= 0.5 then ix = ix + 1 end

    local iy, fy = math.modf(v.y)
    if iy <= 0 and fy <= -0.5 then iy = iy - 1
    elseif iy >= 0 and fy >= 0.5 then iy = iy + 1 end

    return Vec2.new(ix, iy)
end

---Scales a vector, left, by a number, right.
---@param a Vec2 left operand
---@param b number right operand
---@return Vec2
function Vec2.scale(a, b)
    return Vec2.new(a.x * b, a.y * b)
end

---Finds the sign of a vector by component.
---@param v Vec2 vector
---@return Vec2
function Vec2.sign(v)
    local cx = 0.0
    if v.x < -0.0 then cx = -1.0
    elseif v.x > 0.0 then cx = 1.0
    end

    local cy = 0.0
    if v.y < -0.0 then cy = -1.0
    elseif v.y > 0.0 then cy = 1.0
    end

    return Vec2.new(cx, cy)
end

---Finds the smooth step between a left and
---right edge given a factor.
---@param edge0 Vec2 left edge
---@param edge1 Vec2 right edge
---@param x Vec2 factor
---@return Vec2
function Vec2.smoothstep(edge0, edge1, x)
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

    return Vec2.new(cx, cy)
end

---Finds the step between an edge and factor.
---@param edge Vec2 edge
---@param x Vec2 factor
---@return Vec2
function Vec2.step(edge, x)
    local cx = 1.0
    if x.x < edge.x then cx = 0.0 end

    local cy = 1.0
    if x.y < edge.y then cy = 0.0 end

    return Vec2.new(cx, cy)
end

---Subtracts the right vector from the left.
---@param a Vec2 left operand
---@param b Vec2 right operand
---@return Vec2
function Vec2.sub(a, b)
    return Vec2.new(
        a.x - b.x,
        a.y - b.y)
end

---Returns a JSON string of a vector.
---@param v Vec2 vector
---@return string
function Vec2.toJson(v)
    return string.format(
        "{\"x\":%.4f,\"y\":%.4f}",
        v.x, v.y)
end

---Converts a vector to polar coordinates.
---Returns a table with 'radius' and 'heading'.
---@param v Vec2 vector
---@return { radius: number, heading: number }
function Vec2.toPolar(v)
    return {
        radius = Vec2.mag(v),
        heading = Vec2.headingSigned(v)
    }
end

---Truncates a vector's components to integers.
---@param v Vec2 vector
---@return Vec2
function Vec2.trunc(v)
    local ix, _ = math.modf(v.x)
    local iy, _ = math.modf(v.y)
    return Vec2.new(ix, iy)
end

---Wraps a vector's components around a range
---defined by a lower and upper bound. If the
---range is invalid, the component is unchanged.
---@param v Vec2 vector
---@param lb Vec2 lower bound
---@param ub Vec2 upper bound
---@return Vec2
function Vec2.wrap(v, lb, ub)
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

    return Vec2.new(cx, cy)
end

---Creates a right facing vector, (1.0, 0.0).
---@return Vec2
function Vec2.right()
    return Vec2.new(1.0, 0.0)
end

---Creates a forward facing vector, (0.0, 1.0).
---@return Vec2
function Vec2.forward()
    return Vec2.new(0.0, 1.0)
end

---Creates a left facing vector, (-1.0, 0.0).
---@return Vec2
function Vec2.left()
    return Vec2.new(-1.0, 0.0)
end

---Creates a back facing vector, (0.0, -1.0).
---@return Vec2
function Vec2.back()
    return Vec2.new(0.0, -1.0)
end

---Creates a vector with all components
---set to 1.0.
---@return Vec2
function Vec2.one()
    return Vec2.new(1.0, 1.0)
end

return Vec2