Clr = {}
Clr.__index = Clr

setmetatable(Clr, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Constructs a new color from red, green
---blue and transparency channels in [0.0, 1.0].
---@param r number red channel
---@param g number green channel
---@param b number blue channel
---@param a number transparency
---@return table
function Clr.new(r, g, b, a)
    local inst = {}
    setmetatable(inst, Clr)
    inst.r = r or 1.0
    inst.g = g or 1.0
    inst.b = b or 1.0
    inst.a = a or 1.0
    return inst
end

function Clr:__band(b)
    return Clr.bitAnd(self, b)
end

function Clr:__bor(b)
    return Clr.bitOr(self, b)
end

function Clr:__bnot()
    return Clr.bitNot(self)
end

function Clr:__bxor(b)
    return Clr.bitXor(self, b)
end

function Clr:__len()
    return 4
end

function Clr:__shl(b)
    return Clr.bitShiftLeft(self, Clr.toHex(b))
end

function Clr:__shr(b)
    return Clr.bitShiftRight(self, Clr.toHex(b))
end

function Clr:__tostring()
    return string.format(
        "{ r: %.4f, g: %.4f, b: %.4f, a: %.4f }",
        self.r, self.g, self.b, self.a)
end

--- Finds the bitwise and for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitAnd(a, b)
    return Clr.fromHex(Clr.toHex(a) & Clr.toHex(b))
end

--- Finds the bitwise not for a color.
---@param a table left operand
---@return table
function Clr.bitNot(a)
    return Clr.fromHex(~Clr.toHex(a))
end

--- Finds the bitwise inclusive or for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitOr(a, b)
    return Clr.fromHex(Clr.toHex(a) | Clr.toHex(b))
end

---Shifts a color left by a number of places.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitShiftLeft(a, places)
    local p = places or 8
    return Clr.fromHex(Clr.toHex(a) << p)
end

---Shifts a color right by a number of places.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitShiftRight(a, places)
    local p = places or 8
    return Clr.fromHex(Clr.toHex(a) >> p)
end

--- Finds the bitwise exclusive or for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitXor(a, b)
    -- TODO: Will this eval to power or xor?
    return Clr.fromHex(Clr.toHex(a) ^ Clr.toHex(b))
end

---Converts from a hexadecimal representation
---of a color stored as 0xAABBGGRR.
---@param c integer hexadecimal color
---@return table
function Clr.fromHex(c)
    return Clr.new(
        (c         & 0xff) * 0.00392156862745098,
        (c >>  0x8 & 0xff) * 0.00392156862745098,
        (c >> 0x10 & 0xff) * 0.00392156862745098,
        (c >> 0x18 & 0xff) * 0.00392156862745098)
end

---Converts from a color to a hexadecimal integer;
---channels are packed in 0xAABBGGRR order.
---@param c table
---@return integer
function Clr.toHex(c)
    return math.tointeger(c.a * 0xff + 0.5) << 0x18
         | math.tointeger(c.b * 0xff + 0.5) << 0x10
         | math.tointeger(c.g * 0xff + 0.5) <<  0x8
         | math.tointeger(c.r * 0xff + 0.5)
end

return Clr