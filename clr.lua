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

function Clr:__eq(b)
    return Clr.fromHex(self) == Clr.fromHex(b)
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

---Evaluates whether all color channels are 
---greater than zero.
---@param a table
---@return boolean
function Clr.all(a)
    return a.a > 0.0
       and a.b > 0.0
       and a.g > 0.0
       and a.r > 0.0
end

---Evaluates whether the color's alpha channel
---is greater than zero.
---@param a table
---@return boolean
function Clr.any(a)
    return a.a > 0.0
end

---Finds the bitwise and for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitAnd(a, b)
    return Clr.fromHex(Clr.toHex(a) & Clr.toHex(b))
end

---Finds the bitwise not for a color.
---@param a table left operand
---@return table
function Clr.bitNot(a)
    return Clr.fromHex(~Clr.toHex(a))
end

---Finds the bitwise inclusive or for two colors.
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

---Finds the bitwise exclusive or for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitXor(a, b)
    local x = Clr.toHex(a)
    local y = Clr.toHex(b)
    return Clr.fromHex((x | y) & ~(x & y))
end

---Clamps a color to a lower and upper bound
---@param a table left operand
---@param lb table lower bound
---@param ub table upper bound
---@return table
function Clr.clamp(a, lb, ub)
    return Clr.new(
        math.min(math.max(a.r, lb.r), ub.r),
        math.min(math.max(a.g, lb.g), ub.g),
        math.min(math.max(a.b, lb.b), ub.b),
        math.min(math.max(a.a, lb.a), ub.a))
end

---Clamps a color to [0.0, 1.0].
---@param a table left operand
---@return table
function Clr.clamp01(a)
    return Clr.new(
        math.min(math.max(a.r, 0.0), 1.0),
        math.min(math.max(a.g, 0.0), 1.0),
        math.min(math.max(a.b, 0.0), 1.0),
        math.min(math.max(a.a, 0.0), 1.0))
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

---Converts hue, saturation and value to a color.
---@param hue number hue
---@param sat number saturation
---@param val number value
---@param alpha number transparency
---@return table
function Clr.hsvaToRgba(hue, sat, val, alpha)
    local h = 6.0 * (hue % 1.0)
    local s = sat or 1.0
    local v = val or 1.0
    local a = alpha or 1.0

    local sector = math.tointeger(h)
    local tint1 = v * (1.0 - s)
    local tint2 = v * (1.0 - s * (h - sector))
    local tint3 = v * (1.0 - s * (1.0 + sector - h))

    if sector == 0 then
        return Clr.new(v, tint3, tint1, a)
    elseif sector == 1 then
        return Clr.new(tint2, v, tint1, a)
    elseif sector == 2 then
        return Clr.new(tint1, v, tint3, a)
    elseif sector == 3 then
        return Clr.new(tint1, tint2, v, a)
    elseif sector == 4 then
        return Clr.new(tint3, tint1, v, a)
    elseif sector == 5 then
        return Clr.new(v, tint1, tint2, a)
    else
        return Clr.new(1.0, 1.0, 1.0, a)
    end
end

---Evaluates whether the color's alpha channel
---is less than or equal to zero.
---@param a table
---@return boolean
function Clr.none(a)
    return a.a <= 0.0
end

---Reduces the granularity of a color's components.
---@param a table color
---@param levels integer levels
---@return table
function Clr.quantize(a, levels)
    if levels and levels > 1 and levels < 256 then
        local delta = 1.0 / levels
        return Clr.new(
            delta * math.floor(0.5 + a.r * levels),
            delta * math.floor(0.5 + a.g * levels),
            delta * math.floor(0.5 + a.b * levels),
            delta * math.floor(0.5 + a.a * levels))
    end
    return Clr.new(a.r, a.g, a.b, a.a)
end

---Converts RGBA channels to hue, saturation and value.
---The return table uses the keys h, s, v and a.
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number transparency
---@return table
function Clr.rgbaToHsva(red, green, blue, alpha)
    local bri = math.max(red, green, blue)
    local dlt = bri - math.min(red, green, blue)
    local hue = 0.0
    if dlt ~= 0.0 then
        if red == bri then
            hue = (green - blue) / dlt
        elseif green == bri then
            hue = 2.0 + (blue - red) / dlt
        else
            hue = 4.0 + (red - green) / dlt
        end

        hue = hue * 0.16666666666666667
        if hue < -0.0 then hue = hue + 1.0 end
    end
    local sat = 0.0
    if bri ~= 0.0 then sat = dlt / bri end
    local a = alpha or 1.0
    return { h = hue, s = sat, v = bri, a = a }
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