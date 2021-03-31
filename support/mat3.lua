Mat3 = {}
Mat3.__index = Mat3

setmetatable(Mat3, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a row major 3x3 matrix from numbers.
---Intended for use as a 2D affine transform.
---@param m00 number row 0, col 0 right x
---@param m01 number row 0, col 1 forward x
---@param m02 number row 0, col 2 translation x
---@param m10 number row 1, col 0 right y
---@param m11 number row 1, col 1 forward y
---@param m12 number row 1, col 2 translation y
---@param m20 number row 2, col 0 right z
---@param m21 number row 2, col 1 forward z
---@param m22 number row 2, col 2 translation z
---@return table
function Mat3.new(
    m00, m01, m02,
    m10, m11, m12,
    m20, m21, m22)
    local inst = setmetatable({}, Mat3)

    inst.m00 = m00 or 1.0
    inst.m01 = m01 or 0.0
    inst.m02 = m02 or 0.0

    inst.m10 = m10 or 0.0
    inst.m11 = m11 or 1.0
    inst.m12 = m12 or 0.0

    inst.m20 = m20 or 0.0
    inst.m21 = m21 or 0.0
    inst.m22 = m22 or 1.0

    return inst
end

function Mat3:__add(b)
    return Mat3.add(self, b)
end

function Mat3:__div(b)
    return Mat3.div(self, b)
end

function Mat3:__len()
    return 9
end

function Mat3:__mul(b)
    return Mat3.mul(self, b)
end

function Mat3:__sub(b)
    return Mat3.sub(self, b)
end

function Mat3:__tostring()
    return Mat3.toJson(self)
end

function Mat3:__unm()
    return Mat3.negate(self)
end

---Finds the sum of two matrices.
---@param a table left operand
---@param b table right operand
---@return table
function Mat3.add(a, b)
    return Mat3.new(
        a.m00 + b.m00, a.m01 + b.m01, a.m02 + b.m02,
        a.m10 + b.m10, a.m11 + b.m11, a.m12 + b.m12,
        a.m20 + b.m20, a.m21 + b.m21, a.m22 + b.m22)
end

---Evaluates whether two matrices are, within a
---tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol number tolerance
---@return boolean
function Mat3.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.m00 - a.m00) <= eps
        and math.abs(b.m01 - a.m01) <= eps
        and math.abs(b.m02 - a.m02) <= eps
        and math.abs(b.m10 - a.m10) <= eps
        and math.abs(b.m11 - a.m11) <= eps
        and math.abs(b.m12 - a.m12) <= eps
        and math.abs(b.m20 - a.m20) <= eps
        and math.abs(b.m21 - a.m21) <= eps
        and math.abs(b.m22 - a.m22) <= eps
end

---Multiplies the left operand and the inverse of the right.
---@param a table left operand
---@param b table right operand
---@return table
function Mat3.div(a, b)
    return Mat3.mul(a, Mat3.inverse(b))
end

---Finds the matrix determinant.
---@param a table matrix
---@return number
function Mat3.determinant(a)
    return a.m00 * (a.m22 * a.m11 - a.m12 * a.m21) +
           a.m01 * (a.m12 * a.m20 - a.m22 * a.m10) +
           a.m02 * (a.m21 * a.m10 - a.m11 * a.m20)
end

---Constructs a matrix from an angle in radians.
---@param radians number angle
---@return table
function Mat3.fromRotZ(radians)
    return Mat3.fromRotZInternal(
        math.cos(radians),
        math.sin(radians))
end

---Constructs a matrix from the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return table
function Mat3.fromRotZInternal(cosa, sina)
    return Mat3.new(
        cosa, -sina, 0.0,
        sina,  cosa, 0.0,
         0.0,   0.0, 1.0)
end

---Constructs a matrix from a nonuniform scale.
---@param width number width
---@param depth number depth
---@return table
function Mat3.fromScale(width, depth)
    local w = 1.0
    if width and width ~= 0.0 then
        w = width
    end

    local d = w
    if depth and depth ~= 0.0 then
        d = depth
    end

    return Mat3.new(
          w, 0.0, 0.0,
        0.0,   d, 0.0,
        0.0, 0.0, 1.0)
end

---Creates a skew matrix on the x axis.
---@param radians number angle
---@return table
function Mat3.fromShearX(radians)
    return Mat3.new(
        1.0, math.tan(radians), 0.0,
        0.0,               1.0, 0.0,
        0.0,               0.0, 1.0)
end

---Creates a skew matrix on the y axis.
---@param radians number angle
---@return table
function Mat3.fromShearY(radians)
    return Mat3.new(
                      1.0, 0.0, 0.0,
        math.tan(radians), 1.0, 0.0,
                      0.0, 0.0, 1.0)
end

---Constructs a matrix from a translation.
---@param x number x
---@param y number y
---@return table
function Mat3.fromTranslation(x, y)
    return Mat3.new(
        1.0, 0.0,   x,
        0.0, 1.0,   y,
        0.0, 0.0, 1.0)
end

---Finds the matrix inverse.
---Returns the identity if not possible.
---@param a table matrix
---@return table
function Mat3.inverse(a)
    local b01 = a.m22 * a.m11 - a.m12 * a.m21
    local b11 = a.m12 * a.m20 - a.m22 * a.m10
    local b21 = a.m21 * a.m10 - a.m11 * a.m20
    local det = a.m00 * b01 + a.m01 * b11 + a.m02 * b21
    if det ~= 0.0 then
        local detInv = 1.0 / det
        return Mat3.new(
            b01 * detInv,
            (a.m02 * a.m21 - a.m22 * a.m01) * detInv,
            (a.m12 * a.m01 - a.m02 * a.m11) * detInv,
            b11 * detInv,
            (a.m22 * a.m00 - a.m02 * a.m20) * detInv,
            (a.m02 * a.m10 - a.m12 * a.m00) * detInv,
            b21 * detInv,
            (a.m01 * a.m20 - a.m21 * a.m00) * detInv,
            (a.m11 * a.m00 - a.m01 * a.m10) * detInv)
    else
        return Mat3.identity()
    end
end

---Finds the product of two matrices.
---@param a table left operand
---@param b table right operand
---@return table
function Mat3.mul(a, b)
    return Mat3.new(
        a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20,
        a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21,
        a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
        a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20,
        a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21,
        a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
        a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20,
        a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21,
        a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22)
end

---Negates a matrix.
---@param a table matrix
---@return table
function Mat3.negate(a)
    return Mat3.new(
        -a.m00, -a.m01, -a.m02,
        -a.m10, -a.m11, -a.m12,
        -a.m20, -a.m21, -a.m22)
end

---Subtracts the right matrix from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Mat3.sub(a, b)
    return Mat3.new(
        a.m00 - b.m00, a.m01 - b.m01, a.m02 - b.m02,
        a.m10 - b.m10, a.m11 - b.m11, a.m12 - b.m12,
        a.m20 - b.m20, a.m21 - b.m21, a.m22 - b.m22)
end

---Returns a JSON string of a matrix.
---@param a table matrix
---@return string
function Mat3.toJson(a)
    local m0 = string.format(
        "{\"m00\":%.4f,\"m01\":%.4f,\"m02\":%.4f,",
        a.m00, a.m01, a.m02)
    local m1 = string.format(
        "\"m10\":%.4f,\"m11\":%.4f,\"m12\":%.4f,",
        a.m10, a.m11, a.m12)
    local m2 = string.format(
        "\"m20\":%.4f,\"m21\":%.4f,\"m22\":%.4f}",
        a.m20, a.m21, a.m22)
    return m0 .. m1 .. m2
end

---Transposes a matrix's columns and rows.
---@param a table matrix
---@return table
function Mat3.transpose(a)
    return Mat3.new(
        a.m00, a.m10, a.m20,
        a.m01, a.m11, a.m21,
        a.m02, a.m12, a.m22)
end

---Creates the identity matrix.
---@return table
function Mat3.identity()
    return Mat3.new(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0)
end

return Mat3