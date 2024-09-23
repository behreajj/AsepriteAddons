---@class Mat3
---@field public m00 number row 0, col 0 right x
---@field public m01 number row 0, col 1 forward x
---@field public m02 number row 0, col 2 translation x
---@field public m10 number row 1, col 0 right y
---@field public m11 number row 1, col 1 forward y
---@field public m12 number row 1, col 2 translation y
---@field public m20 number row 2, col 0 right z
---@field public m21 number row 2, col 1 forward z
---@field public m22 number row 2, col 2 translation z
---@operator add(Mat3): Mat3
---@operator div(Mat3): Mat3
---@operator len(): integer
---@operator mul(Mat3): Mat3
---@operator sub(Mat3): Mat3
---@operator unm(): Mat3
Mat3 = {}
Mat3.__index = Mat3

setmetatable(Mat3, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

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
---@return Mat3
---@nodiscard
function Mat3.new(
    m00, m01, m02,
    m10, m11, m12,
    m20, m21, m22)
    local inst <const> = setmetatable({}, Mat3)

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
---@param a Mat3 left operand
---@param b Mat3 right operand
---@return Mat3
---@nodiscard
function Mat3.add(a, b)
    return Mat3.new(
        a.m00 + b.m00, a.m01 + b.m01, a.m02 + b.m02,
        a.m10 + b.m10, a.m11 + b.m11, a.m12 + b.m12,
        a.m20 + b.m20, a.m21 + b.m21, a.m22 + b.m22)
end

---Multiplies the left operand and the inverse of the right.
---@param a Mat3 left operand
---@param b Mat3 right operand
---@return Mat3
---@nodiscard
function Mat3.div(a, b)
    return Mat3.mul(a, Mat3.inverse(b))
end

---Finds the matrix determinant.
---@param m Mat3 matrix
---@return number
---@nodiscard
function Mat3.determinant(m)
    return m.m00 * (m.m22 * m.m11 - m.m12 * m.m21) +
        m.m01 * (m.m12 * m.m20 - m.m22 * m.m10) +
        m.m02 * (m.m21 * m.m10 - m.m11 * m.m20)
end

---Constructs a matrix from an angle in radians.
---@param radians number angle
---@return Mat3
---@nodiscard
function Mat3.fromRotZ(radians)
    return Mat3.fromRotZInternal(math.cos(radians), math.sin(radians))
end

---Constructs a matrix from the cosine and sine of an angle.
---@param cosa number cosine of the angle
---@param sina number sine of the angle
---@return Mat3
---@nodiscard
function Mat3.fromRotZInternal(cosa, sina)
    return Mat3.new(
        cosa, -sina, 0.0,
        sina, cosa, 0.0,
        0.0, 0.0, 1.0)
end

---Constructs a matrix from a nonuniform scale.
---@param width number width
---@param depth number depth
---@return Mat3
---@nodiscard
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
        0.0, d, 0.0,
        0.0, 0.0, 1.0)
end

---Constructs a matrix from a translation.
---@param x number translation x
---@param y number translation y
---@return Mat3
---@nodiscard
function Mat3.fromTranslation(x, y)
    return Mat3.new(
        1.0, 0.0, x,
        0.0, 1.0, y,
        0.0, 0.0, 1.0)
end

---Finds the matrix inverse. Returns the identity if not possible.
---@param a Mat3 matrix
---@return Mat3
---@nodiscard
function Mat3.inverse(a)
    local b01 <const> = a.m22 * a.m11 - a.m12 * a.m21
    local b11 <const> = a.m12 * a.m20 - a.m22 * a.m10
    local b21 <const> = a.m21 * a.m10 - a.m11 * a.m20
    local det <const> = a.m00 * b01 + a.m01 * b11 + a.m02 * b21
    if det ~= 0.0 then
        local detInv <const> = 1.0 / det
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
---@param a Mat3 left operand
---@param b Mat3 right operand
---@return Mat3
---@nodiscard
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
---@param m Mat3 matrix
---@return Mat3
---@nodiscard
function Mat3.negate(m)
    return Mat3.new(
        -m.m00, -m.m01, -m.m02,
        -m.m10, -m.m11, -m.m12,
        -m.m20, -m.m21, -m.m22)
end

---Subtracts the right matrix from the left.
---@param a Mat3 left operand
---@param b Mat3 right operand
---@return Mat3
---@nodiscard
function Mat3.sub(a, b)
    return Mat3.new(
        a.m00 - b.m00, a.m01 - b.m01, a.m02 - b.m02,
        a.m10 - b.m10, a.m11 - b.m11, a.m12 - b.m12,
        a.m20 - b.m20, a.m21 - b.m21, a.m22 - b.m22)
end

---Returns a JSON string of a matrix.
---@param a Mat3 matrix
---@return string
---@nodiscard
function Mat3.toJson(a)
    local m0 <const> = string.format(
        "{\"m00\":%.4f,\"m01\":%.4f,\"m02\":%.4f,",
        a.m00, a.m01, a.m02)
    local m1 <const> = string.format(
        "\"m10\":%.4f,\"m11\":%.4f,\"m12\":%.4f,",
        a.m10, a.m11, a.m12)
    local m2 <const> = string.format(
        "\"m20\":%.4f,\"m21\":%.4f,\"m22\":%.4f}",
        a.m20, a.m21, a.m22)
    return m0 .. m1 .. m2
end

---Creates the identity matrix.
---@return Mat3
---@nodiscard
function Mat3.identity()
    return Mat3.new(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0)
end

return Mat3