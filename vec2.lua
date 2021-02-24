Vec2 = {}
Vec2.__index = Vec2

--- Constructs a new vector from two numbers.
---@param x number x component
---@param y number y component
---@return table
function Vec2:new(x, y)
    local inst = {}
    setmetatable(inst, Vec2)
    inst.x = x or 0.0
    inst.y = y or inst.x
    return inst
end

function Vec2:__add(b)
    return Vec2:add(self, b)
end

function Vec2:__div(b)
    return Vec2:div(self, b)
end

function Vec2:__idiv(b)
    return Vec2:floorDiv(self, b)
end

function Vec2:__mod(b)
    return Vec2:mod(self, b)
end

function Vec2:__mul(b)
    return Vec2:mul(self, b)
end

function Vec2:__pow(b)
    return Vec2:pow(self, b)
end

function Vec2:__sub(b)
    return Vec2:sub(self, b)
end

function Vec2:__tostring()
    return string.format(
        "{ x: %.4f, y: %.4f }",
        self.x,
        self.y)
end

function Vec2:__unm()
    return Vec2:negate(self)
end

--- Finds a vector's absolute value, component-wise.
---@param a table vector
---@return table
function Vec2:abs(a)
    return Vec2:new(
        math.abs(a.x),
        math.abs(a.y))
end

--- Evaluates if all vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec2:all(a)
    return a.x ~= 0.0 and a.y ~= 0.0
end

--- Finds the angle between two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:angleBetween(a, b)
    if Vec2:any(a) and Vec2:any(b) then
        return math.acos(Vec2:dot(a, b) /
            (Vec2:mag(a) * Vec2:mag(b)))
    else
        return 0.0
    end
end

--- Evaluates if any vector components are non-zero.
---@param a table left operand
---@return boolean
function Vec2:any(a)
    return a.x ~= 0.0 or a.y ~= 0.0
end

--- Finds the sum of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:add(a, b)
    return Vec2:new(
        a.x + b.x,
        a.y + b.y)
end

--- Evaluates whether two vectors are, within a
--- tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol any tolerance
---@return boolean
function Vec2:approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.x - a.x) <= eps
        and math.abs(b.y - a.y) <= eps
end

--- Finds the ceiling of the vector.
---@param a table left operand
---@return table
function Vec2:ceil(a)
    return Vec2:new(
        math.ceil(a.x),
        math.ceil(a.y))
end

--- Clamps a vector to a lower and upper bound
---@param a table left operand
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Vec2:clamp(a, lb, ub)
    return Vec2:new(
        math.min(math.max(a.x, lb.x), ub.x),
        math.min(math.max(a.y, lb.y), ub.y))
end

--- Finds the cross product of two vectors, z component.
---@param a table left operand
---@param b table right operand
---@return number
function Vec2:cross(a, b)
    return a.x * b.y - a.y * b.x
end

--- Finds the absolute difference between two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:diff(a, b)
    return Vec2:new(
        math.abs(a.x - b.x),
        math.abs(a.y - b.y))
end

--- Divides the left vector by the right, component-wise.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:div(a, b)
    local cx = 0.0
    local cy = 0.0
    if b.x ~= 0.0 then cx = a.x / b.x end
    if b.y ~= 0.0 then cy = a.y / b.y end
    return Vec2:new(cx, cy)
end

--- Finds the dot product between two vectors.
---@param a table left operand
---@param b table right operand
---@return number
function Vec2:dot(a, b)
    return a.x * b.x + a.y * b.y
end

--- Finds the floor of the vector.
---@param a table left operand
---@return table
function Vec2:floor(a)
    return Vec2:new(
        math.floor(a.x),
        math.floor(a.y))
end

--- Finds the floor division of two vectors.
---@param a table left operand
---@param b table left operand
---@return table
function Vec2:floorDiv(a, b)
    local cx = 0.0
    local cy = 0.0
    if b.x ~= 0.0 then cx = a.x // b.x end
    if b.y ~= 0.0 then cy = a.y // b.y end
    return Vec2:new(cx, cy)
end

--- Finds the remainder of the division of the left
--- operand by the right that rounds the quotient
--- towards zero.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:fmod(a, b)
    local cx = a.x
    local cy = a.y
    if b.x ~= 0.0 then cx = math.fmod(a.x, b.x) end
    if b.y ~= 0.0 then cy = math.fmod(a.y, b.y) end
    return Vec2:new(cx, cy)
end

--- Finds the fractional portion of of a vector.
---@param a table left operand
---@return table
function Vec2:fract(a)
    return Vec2:new(
        a.x - math.tointeger(a.x),
        a.y - math.tointeger(a.y))
end

--- Converts from polar to Cartesian coordinates.
--- The heading, or azimuth, is in radians.
--- The radius defaults to 1.0.
---@param heading number heading
---@param radius number radius
---@return table
function Vec2:fromPolar(heading, radius)
    local r = radius or 1.0
    return Vec2:new(
        r * math.cos(heading),
        r * math.sin(heading))
end

--- Finds a vector's heading.
--- Defaults to the signed heading.
---@param a table left operand
---@return number
function Vec2:heading(a)
    return Vec2:headingSigned(a)
end

--- Finds a vector's signed heading, in [-pi, pi].
---@param a table left operand
---@return number
function Vec2:headingSigned(a)
    return math.atan(a.y, a.x)
end

--- Finds a vector's unsigned heading, in [0.0, tau].
---@param a table left operand
---@return number
function Vec2:headingUnsigned(a)
    return math.atan(a.y, a.x) % 6.283185307179586
end

--- Limits a vector's magnitude to a scalar.
--- Returns a copy of the vector if it is beneath
--- the limit.
---@param a table the vector
---@param limit number the limit number
---@return table
function Vec2:limit(a, limit)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 and mSq > (limit * limit) then
        local mInv = limit / math.sqrt(mSq)
        return Vec2:new(
            a.x * mInv,
            a.y * mInv)
    end
    return Vec2:new(a.x, a.y)
end

--- Finds the linear step between a left and
--- right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
function Vec2:linearstep(edge0, edge1, x)

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

    return Vec2:new(cx, cy)
end

--- Finds a vector's magnitude, or length.
---@param a table left operand
---@return number
function Vec2:mag(a)
    return math.sqrt(a.x * a.x + a.y * a.y)
end

--- Finds a vector's magnitude squared.
---@param a table left operand
---@return number
function Vec2:magSq(a)
    return a.x * a.x + a.y * a.y
end

--- Finds the greater of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:max(a, b)
    return Vec2:new(
        math.max(a.x, b.x),
        math.max(a.y, b.y))
end

--- Finds the lesser of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:min(a, b)
    return Vec2:new(
        math.min(a.x, b.x),
        math.min(a.y, b.y))
end

--- Mixes two vectors together by a step.
---@param a table origin
---@param b table destination
---@param t table step
---@return table
function Vec2:mix(a, b, t)
   return Vec2:new(
        (1.0 - t.x) * a.x + t.x * b.x,
        (1.0 - t.y) * a.y + t.y * b.y)
end

--- Finds the remainder of floor division of two vectors.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:mod(a, b)
    local cx = a.x
    local cy = a.y
    if b.x ~= 0.0 then cx = a.x % b.x end
    if b.y ~= 0.0 then cy = a.y % b.y end
    return Vec2:new(cx, cy)
end

--- Multiplies two vectors component-wise.
--- A shortcut for multiplying a matrix and vector.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:mul(a, b)
    return Vec2:new(
        a.x * b.x,
        a.y * b.y)
end

--- Negates a vector.
---@param a table vector
---@return table
function Vec2:negate(a)
    return Vec2:new(-a.x, -a.y)
end

---Evaluates if no vector components are non-zero.
---@param a table
---@return boolean
function Vec2:none(a)
    return a.x == 0.0 and a.y == 0.0
end

--- Divides a vector by its magnitude, such that it
--- lies on the unit circle.
---@param a table vector
---@return table
function Vec2:normalize(a)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 then
        local mInv = 1.0 / math.sqrt(mSq)
        return Vec2:new(
            a.x * mInv,
            a.y * mInv)
    end
    return Vec2:new(0.0, 0.0)
end

--- Finds the perpendicular to a vector.
--- Defaults to the counter-clockwise direction.
---@param a table vector
---@return table
function Vec2:perpendicular(a)
    return Vec2:perpendicularCCW(a)
end

--- Finds the clockwise perpendicular to a vector.
---@param a table vector
---@return table
function Vec2:perpendicularCW(a)
    return Vec2:new(a.y, -a.x)
end

--- Finds the counter-clockwise perpendicular to
--- a vector.
---@param a table vector
---@return table
function Vec2:perpendicularCCW(a)
    return Vec2:new(-a.y, a.x)
end

--- Raises a vector to the power of another.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:pow(a, b)
    return Vec2:new(
        a.x ^ b.x,
        a.y ^ b.y)
end

--- Finds the scalar projection of the left
--- operand onto the right.
---@param a table left operand
---@param b table right operand
---@return number
function Vec2:projectScalar(a, b)
    local bSq = b.x * b.x + b.y * b.y
    if bSq > 0.0 then
        return Vec2:dot(a, b) / bSq
    else
        return 0.0
    end
end

--- Finds the vector projection of the left
--- operand onto the right.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:projectVector(a, b)
    return Vec2:scale(b, Vec2:projectScalar(a, b))
end

--- Reduces the granularity of a vector's components.
---@param a table vector
---@param levels number levels
---@return table
function Vec2:quantize(a, levels)
    if levels and levels > 1 then
        local delta = 1.0 / levels
        return Vec2:new(
            delta * math.floor(0.5 + a.x * levels),
            delta * math.floor(0.5 + a.y * levels))
    end
    return Vec2:new(a.x, a.y)
end

--- Rescales a vector to the target magnitude.
---@param a table vector
---@param b number magnitude
---@return table
function Vec2:rescale(a, b)
    local mSq = a.x * a.x + a.y * a.y
    if mSq > 0.0 then
        local bmInv = b / math.sqrt(mSq)
        return Vec2:new(
            a.x * bmInv,
            a.y * bmInv)
    end
    return Vec2:new(0.0, 0.0)
end

--- Rotates a vector by an angle in radians.
---@param a table left operand
---@param radians number angle
---@return table
function Vec2:rotateZ(a, radians)
    return Vec2:rotateZInternal(a,
        math.cos(radians),
        math.sin(radians))
end

--- Rotates a vector by the cosine and sine of an angle.
--- Used when rotating many vectors by the same angle.
---@param a table left operand
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Vec2:rotateZInternal(a, cosa, sina)
    return Vec2:new(
        cosa * a.x - sina * a.y,
        cosa * a.y + sina * a.x)
end

--- Scales a vector by a number.
---@param a table left operand
---@param b number right operand
---@return table
function Vec2:scale(a, b)
    return Vec2:new(a.x * b, a.y * b)
end

--- Finds the smooth step between a left and
--- right edge given a factor.
---@param edge0 table left edge
---@param edge1 table right edge
---@param x table factor
---@return table
function Vec2:smoothstep(edge0, edge1, x)
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

    return Vec2:new(
        cx * cx * (3.0 - (cx + cx)),
        cy * cy * (3.0 - (cy + cy)))
end

--- Finds the step between an edge and factor.
---@param edge table the edge
---@param x table the factor
---@return table
function Vec2:step(edge, x)
    local cx = 1.0
    local cy = 1.0

    if x.x < edge.x then cx = 0.0 end
    if x.y < edge.y then cy = 0.0 end

    return Vec2:new(cx, cy)
end

--- Subtracts the right vector from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Vec2:sub(a, b)
    return Vec2:new(
        a.x - b.x,
        a.y - b.y)
end

--- Converts a vector to polar coordinates.
--- Returns a table with 'heading' and 'radius'.
---@param a table vector
---@return table
function Vec2:toPolar(a)
    return {
        heading = Vec2:headingSigned(a),
        radius = Vec2:mag(a) }
end

--- Truncates a vector's components to integers.
---@param a table vector
---@return table
function Vec2:trunc(a)
    return Vec2:new(
        math.tointeger(a.x),
        math.tointeger(a.y))
end

-- create and use an Vec2
-- n = Vec2:new(3.12,4.45)
-- m = Vec2:new(1.0, 0.1)
-- print(Vec2:quantize(m, 8))
