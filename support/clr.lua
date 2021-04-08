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
    local inst = setmetatable({}, Clr)
    inst.a = a or 1.0
    inst.b = b or 1.0
    inst.g = g or 1.0
    inst.r = r or 1.0
    return inst
end

function Clr:__add(b)
    return Clr.add(self, b)
end

function Clr:__band(b)
    return Clr.bitAnd(self, b)
end

function Clr:__bnot()
    return Clr.bitNot(self)
end

function Clr:__bor(b)
    return Clr.bitOr(self, b)
end

function Clr:__bxor(b)
    return Clr.bitXor(self, b)
end

function Clr:__eq(b)
    return Clr.fromHex(self) == Clr.fromHex(b)
end

function Clr:__le(b)
    return Clr.fromHex(self) < Clr.fromHex(b)
end

function Clr:__len()
    return 4
end

function Clr:__lt(b)
    return Clr.fromHex(self) <= Clr.fromHex(b)
end

function Clr:__mul(b)
    return Clr.mul(self, b)
end

function Clr:__shl(b)
    return Clr.bitShiftLeft(self, Clr.toHex(b))
end

function Clr:__shr(b)
    return Clr.bitShiftRight(self, Clr.toHex(b))
end

function Clr:__sub(b)
    return Clr.sub(self, b)
end

function Clr:__tostring()
    return Clr.toJson(self)
end

---Adds two colors, including alpha.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.add(a, b)
    return Clr.new(
        math.min(1.0, math.max(0.0,
            a.r + b.r)),
        math.min(1.0, math.max(0.0,
            a.g + b.g)),
        math.min(1.0, math.max(0.0,
            a.b + b.b)),
        math.min(1.0, math.max(0.0,
            a.a + b.a)))
end

---Evaluates whether all color channels are 
---greater than zero.
---@param a table color
---@return boolean
function Clr.all(a)
    return a.a > 0.0
       and a.b > 0.0
       and a.g > 0.0
       and a.r > 0.0
end

---Evaluates whether the color's alpha channel
---is greater than zero.
---@param a table color
---@return boolean
function Clr.any(a)
    return a.a > 0.0
end

---Finds the bitwise and (&) for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitAnd(a, b)
    return Clr.fromHex(Clr.toHex(a) & Clr.toHex(b))
end

---Finds the bitwise not (~) for a color.
---@param a table left operand
---@return table
function Clr.bitNot(a)
    return Clr.fromHex(~Clr.toHex(a))
end

---Finds the bitwise inclusive or (|) for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitOr(a, b)
    return Clr.fromHex(Clr.toHex(a) | Clr.toHex(b))
end

---Rotates a color left by a number of places.
---Use 8, 16, 24 for complete channel rotations.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitRotateLeft(a, places)
    local x = Clr.toHex(a)
    return Clr.fromHex(
        (x << places) |
        (x >> (-places & 0x1f)))
end

---Rotates a color right by a number of places.
---Use 8, 16, 24 for complete channel rotations.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitRotateRight(a, places)
    local x = Clr.toHex(a)
    return Clr.fromHex(
        (x >> places) |
        (x << (-places & 0x1f)))
end

---Shifts a color left (<<) by a number of places.
---Use 8, 16, 24 for complete channel shifts.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitShiftLeft(a, places)
    return Clr.fromHex(Clr.toHex(a) << places)
end

---Shifts a color right (>>) by a number of places.
---Use 8, 16, 24 for complete channel shifts.
---@param a table left operand
---@param places integer shift
---@return table
function Clr.bitShiftRight(a, places)
    return Clr.fromHex(Clr.toHex(a) >> places)
end

---Finds the bitwise exclusive or (~) for two colors.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.bitXor(a, b)
    return Clr.fromHex(Clr.toHex(a) ~ Clr.toHex(b))
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

---Converts from a direction to a color.
---Normalizes the direction internally.
---For use when creating normal maps.
---@param x number x coordinate
---@param y number y coordinate
---@param z number z coordinate
---@return table
function Clr.fromDir(x, y, z)
    local xv = x or 0.0
    local yv = y or 0.0
    local zv = z or 0.0
    local msq = xv * xv + yv * yv + zv * zv
    if msq ~= 0.0 then
        local minv = 1.0 / math.sqrt(msq)
        return Clr.new(
            0.5 + 0.5 * (xv * minv),
            0.5 + 0.5 * (yv * minv),
            0.5 + 0.5 * (zv * minv),
            1.0)
    else
        return Clr.new(0.5, 0.5, 0.5, 1.0)
    end
end

---Converts from a hexadecimal representation
---of a color stored as 0xAABBGGRR.
---@param c integer hexadecimal color
---@return table
function Clr.fromHex(c)
    return Clr.new(
        (c         & 0xff) * 0.00392156862745098,
        (c >> 0x08 & 0xff) * 0.00392156862745098,
        (c >> 0x10 & 0xff) * 0.00392156862745098,
        (c >> 0x18 & 0xff) * 0.00392156862745098)
end

---Converts hue, saturation and lightness to a color.
---@param hue number hue
---@param sat number saturation
---@param light number lightness
---@param alpha number transparency
---@return table
function Clr.hslaToRgba(hue, sat, light, alpha)

    local l = light or 1.0
    local a = alpha or 1.0

    if l <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, a)
    end

    if l >= 1.0 then
        return Clr.new(1.0, 1.0, 1.0, a)
    end

    local s = sat or 1.0
    if s <= 0.0 then
        return Clr.new(l, l, l, a)
    end

    local q = l + s - l * s
    if l < 0.5 then q = l * (1.0 + s) end
    local p = l + l - q
    local qnp6 = (q - p) * 6.0

    local h = hue or 0.0

    local r = p
    local rHue = (h + 0.3333333333333333) % 1.0
    if rHue < 0.16666666666666667 then
        r = p + qnp6 * rHue
    elseif rHue < 0.5 then
        r = q;
    elseif rHue < 0.6666666666666667 then
        r = p + qnp6 * (0.6666666666666667 - rHue)
    end

    local g = p
    local gHue = h % 1.0
    if gHue < 0.16666666666666667 then
        g = p + qnp6 * gHue
    elseif gHue < 0.5 then
        g = q;
    elseif gHue < 0.6666666666666667 then
        g = p + qnp6 * (0.6666666666666667 - gHue)
    end

    local b = p
    local bHue = (h - 0.3333333333333333) % 1.0
    if bHue < 0.16666666666666667 then
        b = p + qnp6 * bHue
    elseif bHue < 0.5 then
        b = q;
    elseif bHue < 0.6666666666666667 then
        b = p + qnp6 * (0.6666666666666667 - bHue)
    end

    return Clr.new(r, g, b, a)
end

---Converts hue, saturation and value to a color.
---@param hue number hue
---@param sat number saturation
---@param val number value
---@param alpha number transparency
---@return table
function Clr.hsvaToRgba(hue, sat, val, alpha)
    local h = hue or 0.0
    local s = sat or 1.0
    local v = val or 1.0
    local a = alpha or 1.0

    h = 6.0 * (h % 1.0)
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

---Finds the relative luminance of the color.
---https://www.wikiwand.com/en/Relative_luminance
---according to recommendation 709.
---@param a table color
---@return number
function Clr.luminance(a)
    return 0.2126 * a.r
         + 0.7152 * a.g
         + 0.0722 * a.b
end

---Finds the maximum, or lightest, color.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.max(a, b)
    return Clr.new(
        math.min(math.max(a.r, b.r, 0.0), 1.0),
        math.min(math.max(a.g, b.g, 0.0), 1.0),
        math.min(math.max(a.b, b.b, 0.0), 1.0),
        math.min(math.max(a.a, b.a, 0.0), 1.0))
end

---Finds the minimum, or darkest, color.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.min(a, b)
    return Clr.new(
        math.max(math.min(a.r, b.r, 1.0), 0.0),
        math.max(math.min(a.g, b.g, 1.0), 0.0),
        math.max(math.min(a.b, b.b, 1.0), 0.0),
        math.max(math.min(a.a, b.a, 1.0), 0.0))
end

---Mixes two colors in HSLA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---If it is nil, nearest is the default.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHsla(a, b, t, hueFunc)
    local u = t or 0.5

    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end

    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end

    local aHsla = Clr.rgbaToHsla(a.r, a.g, a.b, a.a)
    local bHsla = Clr.rgbaToHsla(b.r, b.g, b.b, b.a)

    local hueTrg = 0.0
    local v = 1.0 - u
    if hueFunc then
        hueTrg = hueFunc(aHsla.h, bHsla.h, u)
    else
        local o = aHsla.h
        local d = bHsla.h
        local diff = d - o
        if diff ~= 0.0 then
            if o < d and diff > 0.5 then
                hueTrg = (v * (o + 1.0) + u * d) % 1.0
            elseif o > d and diff < -0.5 then
                hueTrg = (v * o + u * (d + 1.0)) % 1.0
            else
                hueTrg = v * o + u * d
            end
        end
    end

    return Clr.hslaToRgba(
        hueTrg,
        v * aHsla.s + u * bHsla.s,
        v * aHsla.l + u * bHsla.l,
        v * aHsla.a + u * bHsla.a)
end

---Mixes two colors in HSVA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---If it is nil, nearest is the default.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHsva(a, b, t, hueFunc)
    local u = t or 0.5

    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end

    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end

    local aHsva = Clr.rgbaToHsva(a.r, a.g, a.b, a.a)
    local bHsva = Clr.rgbaToHsva(b.r, b.g, b.b, b.a)

    local hueTrg = 0.0
    local v = 1.0 - u
    if hueFunc then
        hueTrg = hueFunc(aHsva.h, bHsva.h, u)
    else
        local o = aHsva.h
        local d = bHsva.h
        local diff = d - o
        if diff ~= 0.0 then
            if o < d and diff > 0.5 then
                hueTrg = (v * (o + 1.0) + u * d) % 1.0
            elseif o > d and diff < -0.5 then
                hueTrg = (v * o + u * (d + 1.0)) % 1.0
            else
                hueTrg = v * o + u * d
            end
        end
    end

    return Clr.hsvaToRgba(
        hueTrg,
        v * aHsva.s + u * bHsva.s,
        v * aHsva.v + u * bHsva.v,
        v * aHsva.a + u * bHsva.a)
end

---Mixes two colors in RGBA space by a step.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixRgba(a, b, t)
    local u = t or 0.5

    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end

    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end

    local v = 1.0 - u
    return Clr.new(
        v * a.r + u * b.r,
        v * a.g + u * b.g,
        v * a.b + u * b.b,
        v * a.a + u * b.a)
end

---Multiplies two colors, including alpha.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.mul(a, b)
    return Clr.new(
        math.min(1.0, math.max(0.0,
            a.r * b.r)),
        math.min(1.0, math.max(0.0,
            a.g * b.g)),
        math.min(1.0, math.max(0.0,
            a.b * b.b)),
        math.min(1.0, math.max(0.0,
            a.a * b.a)))
end

---Evaluates whether the color's alpha channel
---is less than or equal to zero.
---@param a table color
---@return boolean
function Clr.none(a)
    return a.a <= 0.0
end

---Multiplies a color's red, green and blue
---channels by its alpha channel.
---@param a table color
---@return table
function Clr.preMul(a)
    return Clr.new(
        a.r * a.a,
        a.g * a.a,
        a.b * a.a,
        a.a)
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

---Converts RGBA channels to hue, saturation and lightness.
---The return table uses the keys h, s, l and a.
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number transparency
---@return table
function Clr.rgbaToHsla(red, green, blue, alpha)
    local mx = math.max(red, green, blue)
    local mn = math.min(red, green, blue)
    local sum = mx + mn
    local light = sum * 0.5
    local a = alpha or 1.0
    if mx == mn then
        return { h = 0.0, s = 0.0, l = light, a = a }
    else
        local diff = mx - mn
        local sat = diff / sum
        if light > 0.5 then sat = diff / (2.0 - sum) end

        local hue = 0.0
        if mx == red then
            hue = (green - blue) / diff
            if green < blue then
                hue = hue + 6.0
            end
        elseif mx == green then
            hue = 2.0 + (blue - red) / diff
        elseif mx == blue then
            hue = 4.0 + (red - green) / diff
        end

        hue = hue * 0.16666666666666667
        return { h = hue, s = sat, l = light, a = a }
    end
end

---Converts RGBA channels to hue, saturation and value.
---The return table uses the keys h, s, v and a.
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number transparency
---@return table
function Clr.rgbaToHsva(red, green, blue, alpha)
    local mx = math.max(red, green, blue)
    local mn = math.min(red, green, blue)
    local diff = mx - mn
    local hue = 0.0
    if diff ~= 0.0 then
        if red == mx then
            hue = (green - blue) / diff
            if green < blue then
                hue = hue + 6.0
            end
        elseif green == mx then
            hue = 2.0 + (blue - red) / diff
        else
            hue = 4.0 + (red - green) / diff
        end

        hue = hue * 0.16666666666666667
    end
    local sat = 0.0
    if mx ~= 0.0 then sat = diff / mx end
    local a = alpha or 1.0
    return { h = hue, s = sat, v = mx, a = a }
end

---Subtracts two colors, including alpha.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.sub(a, b)
    return Clr.new(
        math.min(1.0, math.max(0.0,
            a.r - b.r)),
        math.min(1.0, math.max(0.0,
            a.g - b.g)),
        math.min(1.0, math.max(0.0,
            a.b - b.b)),
        math.min(1.0, math.max(0.0,
            a.a - b.a)))
end

---Converts from a color to a hexadecimal integer;
---channels are packed in 0xAABBGGRR order.
---@param c table color
---@return integer
function Clr.toHex(c)
    return math.tointeger(c.a * 0xff + 0.5) << 0x18
         | math.tointeger(c.b * 0xff + 0.5) << 0x10
         | math.tointeger(c.g * 0xff + 0.5) << 0x08
         | math.tointeger(c.r * 0xff + 0.5)
end

---Converts from a color to a web-friendly hexadecimal
---string; channels are packed in #RRGGBB order.
---@param c table color
---@return string
function Clr.toHexWeb(c)
    return "#" .. string.format("%X",
        math.tointeger(c.r * 0xff + 0.5) << 0x10
      | math.tointeger(c.g * 0xff + 0.5) << 0x08
      | math.tointeger(c.b * 0xff + 0.5))
end

---Returns a JSON string of a color.
---@param c table color
---@return string
function Clr.toJson(c)
    return string.format(
        "{\"r\":%.4f,\"g\":%.4f,\"b\":%.4f,\"a\":%.4f}",
        c.r, c.g, c.b, c.a)
end

---Creates a red color.
---@return table
function Clr.red()
    return Clr.new(1.0, 0.0, 0.0, 1.0)
end

---Creates a green color.
---@return table
function Clr.green()
    return Clr.new(0.0, 1.0, 0.0, 1.0)
end

---Creates a blue color.
---@return table
function Clr.blue()
    return Clr.new(0.0, 0.0, 1.0, 1.0)
end

---Creates a cyan color.
---@return table
function Clr.cyan()
    return Clr.new(0.0, 1.0, 1.0, 1.0)
end

---Creates a magenta color.
---@return table
function Clr.magenta()
    return Clr.new(1.0, 0.0, 1.0, 1.0)
end

---Creates a yellow color.
---@return table
function Clr.yellow()
    return Clr.new(1.0, 1.0, 0.0, 1.0)
end

---Creates a black color.
---@return table
function Clr.black()
    return Clr.new(0.0, 0.0, 0.0, 1.0)
end

---Creates a white color.
---@return table
function Clr.white()
    return Clr.new(1.0, 1.0, 1.0, 1.0)
end

---Creates a transparent black color.
---@return table
function Clr.clearBlack()
    return Clr.new(0.0, 0.0, 0.0, 0.0)
end

---Creates a transparent white color.
---@return table
function Clr.clearWhite()
    return Clr.new(1.0, 1.0, 1.0, 0.0)
end

return Clr