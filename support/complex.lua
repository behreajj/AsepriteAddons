Complex = {}
Complex.__index = Complex

setmetatable(Complex, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new complex number.
---@param real number real
---@param imag number imaginary
---@return table
function Complex.new(real, imag)
    local inst = setmetatable({}, Complex)
    inst.real = real or 0.0
    inst.imag = imag or 0.0
    return inst
end

function Complex:__add(b)
    return Complex.add(self, b)
end

function Complex:__div(b)
    return Complex.div(self, b)
end

function Complex:__eq(b)
    return self.real == b.real
       and self.imag == b.imag
end

function Complex:__len()
    return 2
end

function Complex:__mul(b)
    return Complex.mul(self, b)
end

function Complex:__pow(b)
    return Complex.powComplex(self, b)
end

function Complex:__sub(b)
    return Complex.sub(self, b)
end

function Complex:__tostring()
    return Complex.toJson(self)
end

function Complex:__unm()
    return Complex.negate(self)
end

---Finds a complex number's absolute.
---@param z table complex number
---@return number
function Complex.abs(z)
    return math.sqrt(
        z.real * z.real
      + z.imag * z.imag)
end

---Finds a complex number's absolute squared.
---@param z table complex number
---@return number
function Complex.absSq(z)
    return z.real * z.real
         + z.imag * z.imag
end

---Finds the sum of complex numbers.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.add(a, b)
    return Complex.new(
        a.real + b.real,
        a.imag + b.imag)
end

---Evaluates whether two complex numbers are,
---within a tolerance, approximately equal.
---@param a table left operand
---@param b table right operand
---@param tol number tolerance
---@return boolean
function Complex.approx(a, b, tol)
    local eps = tol or 0.000001
    return math.abs(b.real - a.real) <= eps
       and math.abs(b.imag - a.imag) <= eps
end

---Finds the conjugate of a complex number.
---@param z table left operand
---@return table
function Complex.conj(z)
    return Complex.new(z.real, -z.imag)
end

---Divides one complex number by another.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.div(a, b)
    local br = b.real
    local bi = b.imag
    local bAbsSq = br * br + bi * bi
    if bAbsSq ~= 0.0 then
        local bInvAbsSq = 1.0 / bAbsSq
        local cReal = br * bInvAbsSq
        local cImag = -bi * bInvAbsSq
        return Complex.new(
            a.real * cReal - a.imag * cImag,
            a.real * cImag + a.imag * cReal)
    else
        return Complex.new(0.0, 0.0)
    end
end

---Finds Euler's number, e, raised to a
---complex number
---@param z table right operand
---@return table
function Complex.exp(z)
    local rd = math.exp(z.real)
    local phid = z.imag
    return Complex.new(
        rd * math.cos(phid),
        rd * math.sin(phid))
end

---Finds the inverse, or reciprocal, of the
---complex number.
---@param z table left operand
---@return table
function Complex.inverse(z)
    local zr = z.real
    local zi = z.imag
    local absSq = zr * zr + zi * zi
    if absSq ~= 0.0 then
        local invAbsSq = 1.0 / absSq
        return Complex.new(
             zr * invAbsSq,
            -zi * invAbsSq)
    else
        return Complex.new(0.0, 0.0)
    end
end

---Finds the complex logarithm.
---@param z table left operand
---@return table
function Complex.log(z)
    local zr = z.real
    local zi = z.imag
    return Complex.new(
        math.log(math.sqrt(zr * zr + zi * zi)),
        math.atan2(zi, zr))
end

---Finds the mobius transformation for z. See
---https://www.wikiwand.com/en/M%C3%B6bius_transformation
---@param a table constant
---@param b table constant
---@param c table constant
---@param d table constant
---@param z table variable
---@return table
function Complex.mobius(a, b, c, d, z)
    local czdr = c.real * z.real - c.imag * z.imag + d.real
    local czdi = c.real * z.imag + c.imag * z.real + d.imag
    local mSq = czdr * czdr + czdi * czdi;
    if mSq ~= 0.0 then
        local azbr = a.real * z.real - a.imag * z.imag + b.real
        local azbi = a.real * z.imag + a.imag * z.real + b.imag
        local mSqInv = 1.0 / mSq
        local czdrInv = czdr * mSqInv
        local czdiInv = -czdi * mSqInv
        return Complex.new(
            azbr * czdrInv - azbi * czdiInv,
            azbr * czdiInv + azbi * czdrInv)
    else
        return Complex.new(0.0, 0.0)
    end
end

---Multiplies two complex numbers.
---Multiplication is not commutative.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.mul(a, b)
    return Complex.new(
        a.real * b.real - a.imag * b.imag,
        a.real * b.imag + a.imag * b.real)
end

---Negates a complex number
---@param a table left operand
---@return table
function Complex.negate(a)
    return Complex.new(-a.real, -a.imag)
end

---Finds the phase of a complex number.
---@param z table left operand
---@return number
function Complex.phase(z)
    return math.atan(z.imag, z.real)
end

---Converts a complex number to polar coordinates.
---Returns a table with 'r' and 'phi'.
---@param z table left operand
---@return table
function Complex.polar(z)
    return {
        r = Complex.phase(z),
        phi = Complex.abs(z) }
end

---Raises a left operand to the power of the right.
---Defaults to complex-complex exponentiation.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.pow(a, b)
    return Complex.powComplex(a, b)
end

---Raises a complex number to the power of another.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.powComplex(a, b)
    local ar = a.real
    local ai = a.imag
    local br = b.real
    local bi = b.imag

    local logReal = math.log(math.sqrt(ar * ar + ai * ai))
    local logImag = math.atan(ai, ar)
    local rd = math.exp(br * logReal - bi * logImag)
    local phid = br * logImag + bi * logReal

    return Complex.new(
        rd * math.cos(phid),
        rd * math.sin(phid))
end

---Raises a complex number to the power of a number.
---@param a table left operand
---@param b number right operand
---@return table
function Complex.powNumber(a, b)
    local ar = a.real
    local ai = a.imag

    local rd = math.exp(b * math.log(
        math.sqrt(ar * ar + ai * ai)))
    local phid = b * math.atan(ai, ar)

    return Complex.new(
        rd * math.cos(phid),
        rd * math.sin(phid))
end

---Converts from polar to rectilinear coordinates.
---@param r number radius
---@param phi number angle in radians
---@return table
function Complex.rect(r, phi)
    return Complex.new(
        r * math.cos(phi),
        r * math.sin(phi))
end

---Scales a complex number, left, by a number,
---right.
---@param a table left operand
---@param b number right operand
---@return table
function Complex.scale(a, b)
    return Complex.new(a.real * b, a.imag * b)
end

---Subtracts the right complex number
---from the left.
---@param a table left operand
---@param b table right operand
---@return table
function Complex.sub(a, b)
    return Complex.new(
        a.real - b.real,
        a.imag - b.imag)
end

---Returns a JSON string of a complex
---number.
---@param z table complex number
---@return string
function Complex.toJson(z)
    return string.format(
        "{\"real\":%.4f,\"imag\":%.4f}",
        z.real, z.imag)
end

return Complex