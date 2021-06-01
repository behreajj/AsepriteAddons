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
    return Clr.toHex(self) == Clr.toHex(b)
end

function Clr:__le(b)
    return Clr.toHex(self) <= Clr.toHex(b)
end

function Clr:__len()
    return 4
end

function Clr:__lt(b)
    return Clr.toHex(self) < Clr.toHex(b)
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
    return Clr.clamp01(Clr.addUnchecked(a, b))
end

---Adds two colors, including alpha.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.addUnchecked(a, b)
    return Clr.new(
        a.r + b.r,
        a.g + b.g,
        a.b + b.b,
        a.a + b.a)
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
---@param places number shift
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
---@param places number shift
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
---@param places number shift
---@return table
function Clr.bitShiftLeft(a, places)
    return Clr.fromHex(Clr.toHex(a) << places)
end

---Shifts a color right (>>) by a number of places.
---Use 8, 16, 24 for complete channel shifts.
---@param a table left operand
---@param places number shift
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
    if msq > 0.0 then
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
---@param c number hexadecimal color
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
        r = q
    elseif rHue < 0.6666666666666667 then
        r = p + qnp6 * (0.6666666666666667 - rHue)
    end

    local g = p
    local gHue = h % 1.0
    if gHue < 0.16666666666666667 then
        g = p + qnp6 * gHue
    elseif gHue < 0.5 then
        g = q
    elseif gHue < 0.6666666666666667 then
        g = p + qnp6 * (0.6666666666666667 - gHue)
    end

    local b = p
    local bHue = (h - 0.3333333333333333) % 1.0
    if bHue < 0.16666666666666667 then
        b = p + qnp6 * bHue
    elseif bHue < 0.5 then
        b = q
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

---Converts a color from CIE L*a*b* to standard RGB.
---The alpha channel is unaffected by the transform.
---@param l number perceptual lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number alpha channel
---@return table
function Clr.labToRgba(l, a, b, alpha)
    local xyz = Clr.labToXyz(l, a, b, alpha)
    return Clr.xyzToRgba(xyz.x, xyz.y, xyz.z, xyz.a)
end

---Converts a color from CIE L*a*b* to CIE XYZ.
---Assumes D65 illuminant, CIE 1931 2 degrees referents.
---The return table uses the keys x, y, z and a.
---The alpha channel is unaffected by the transform.
---See https://www.wikiwand.com/en/CIELAB_color_space
---and http://www.easyrgb.com/en/math.php.
---@param l number perceptual lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number alpha channel
---@return table
function Clr.labToXyz(l, a, b, alpha)
    -- D65, CIE 1931 2 degrees
    -- 95.047, 100.0, 108.883
    -- 16.0 / 116.0 = 0.13793103448275862
    -- 1.0 / 116.0 = 0.008620689655172414
    -- 1.0 / 7.787 = 0.12841751101180157

    local vy = (l + 16.0) * 0.008620689655172414
    local vx = a * 0.002 + vy
    local vz = vy - b * 0.005

    local vye3 = vy * vy * vy
    if vye3 > 0.008856 then
        vy = vye3
    else
        vy = (vy - 0.13793103448275862) * 0.12841751101180157
    end

    local vxe3 = vx * vx * vx
    if vxe3 > 0.008856 then
        vx = vxe3
    else
        vx = (vx - 0.13793103448275862) * 0.12841751101180157
    end

    local vze3 = vz * vz * vz
    if vze3 > 0.008856 then
        vz = vze3
    else
        vz = (vz - 0.13793103448275862) * 0.12841751101180157
    end

    local aVerif = alpha or 1.0
    return {
        x = vx * 0.95047,
        y = vy,
        z = vz * 1.08883,
        a = aVerif }
end

---Converts a color from linear RGB to standard RGB (sRGB).
---See https://www.wikiwand.com/en/SRGB.
---Does not transform the alpha channel.
---@param a table color
---@return table
function Clr.linearToStandard(a)

    -- 1.0 / 2.4 = 0.4166666666666667

    local sr = a.r
    if sr <= 0.0031308 then
        sr = sr * 12.92
    else
        sr = (sr ^ 0.4166666666666667) * 1.055 - 0.055
    end

    local sg = a.g
    if sg <= 0.0031308 then
        sg = sg * 12.92
    else
        sg = (sg ^ 0.4166666666666667) * 1.055 - 0.055
    end

    local sb = a.b
    if sb <= 0.0031308 then
        sb = sb * 12.92
    else
        sb = (sb ^ 0.4166666666666667) * 1.055 - 0.055
    end

    return Clr.new(sr, sg, sb, a.a)
end

---Finds the relative luminance of a color.
---Assumes the color is in sRGB.
---@param a table color
---@return number
function Clr.luminance(a)
    return Clr.lumStandard(a)
end

---Finds the relative luminance of a linear color,
---https://www.wikiwand.com/en/Relative_luminance,
---according to recommendation 709.
---@param a table color
---@return number
function Clr.lumLinear(a)
    return 0.21264934272065283 * a.r
         + 0.7151691357059038 * a.g
         + 0.07218152157344333 * a.b
end

---Finds the relative luminance of a sRGB color,
---https://www.wikiwand.com/en/Relative_luminance,
---according to recommendation 709.
---@param a table color
---@return number
function Clr.lumStandard(a)
    return Clr.lumLinear(
        Clr.standardToLinear(a))
end

---Finds the maximum, or lightest, color.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.max(a, b)
    return Clr.clamp01(Clr.maxUnchecked(a, b))
end

---Finds the maximum, or lightest, color.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.maxUnchecked(a, b)
    return Clr.new(
        math.max(a.r, b.r),
        math.max(a.g, b.g),
        math.max(a.b, b.b),
        math.max(a.a, b.a))
end

---Finds the minimum, or darkest, color.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.min(a, b)
    return Clr.clamp01(Clr.minUnchecked(a, b))
end

---Finds the minimum, or darkest, color.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.minUnchecked(a, b)
    return Clr.new(
        math.min(a.r, b.r),
        math.min(a.g, b.g),
        math.min(a.b, b.b),
        math.min(a.a, b.a))
end

---Mixes two colors by a step.
---Defaults to the fastest algorithm, i.e.,
---applies linear interpolation to each channel
---with no transformation.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mix(a, b, t)
    return Clr.mixRgbaLinear(a, b, t)
end

---Mixes colors in an array by a step.
---@param arr table array
---@param t number step
---@param func function easing function
---@return table
function Clr.mixArr(arr, t, func)
    local u = t or 0.5
    local lenArr = #arr
    if u <= 0.0 or lenArr == 1 then
        local src = arr[1]
        return Clr.new(src.r, src.g, src.b, src.a)
    end

    if u >= 1.0 then
        local src = arr[lenArr]
        return Clr.new(src.r, src.g, src.b, src.a)
    end

    local uScaled = u * (lenArr - 1.0)
    local i = math.tointeger(uScaled)
    local v = uScaled - i
    local f = func or Clr.mixRgbaLinearInternal
    return f(arr[1 + i], arr[2 + i], v)
end

---Mixes two colors in HSLA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---The step is clamped to [0.0, 1.0].
---The hue function defaults to near.
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

    local f = hueFunc or function(o, d, x)
        local diff = d - o
        if diff ~= 0.0 then
            local y = 1.0 - x
            if o < d and diff > 0.5 then
                return (y * (o + 1.0) + x * d) % 1.0
            elseif o > d and diff < -0.5 then
                return (y * o + x * (d + 1.0)) % 1.0
            else
                return y * o + x * d
            end
        else
            return o
        end
    end

    return Clr.mixHslaInternal(a, b, u, f)
end

---Mixes two colors in HSLA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHslaInternal(a, b, t, hueFunc)
    local aHsva = Clr.rgbaToHsla(a)
    local bHsva = Clr.rgbaToHsla(b)
    local u = 1.0 - t
    return Clr.hslaToRgba(
        hueFunc(aHsva.h, bHsva.h, t),
        u * aHsva.s + t * bHsva.s,
        u * aHsva.l + t * bHsva.l,
        u * aHsva.a + t * bHsva.a)
end


---Mixes two colors in HSVA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---The step is clamped to [0.0, 1.0].
---The hue function defaults to near.
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

    local f = hueFunc or function(o, d, x)
        local diff = d - o
        if diff ~= 0.0 then
            local y = 1.0 - x
            if o < d and diff > 0.5 then
                return (y * (o + 1.0) + x * d) % 1.0
            elseif o > d and diff < -0.5 then
                return (y * o + x * (d + 1.0)) % 1.0
            else
                return y * o + x * d
            end
        else
            return o
        end
    end

    return Clr.mixHsvaInternal(a, b, u, f)
end

---Mixes two colors in HSVA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHsvaInternal(a, b, t, hueFunc)
    local aHsva = Clr.rgbaToHsva(a)
    local bHsva = Clr.rgbaToHsva(b)
    local u = 1.0 - t
    return Clr.hsvaToRgba(
        hueFunc(aHsva.h, bHsva.h, t),
        u * aHsva.s + t * bHsva.s,
        u * aHsva.v + t * bHsva.v,
        u * aHsva.a + t * bHsva.a)
end

---Mixes two colors in CIE L*a*b* space by a step,
---then converts the result to a sRGB color.
---Clamps the step to [0.0, 1.0].
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixLab(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixLabInternal(a, b, u)
end

---Mixes two colors in CIE L*a*b* space by a step,
---then converts the result to a sRGB color.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixLabInternal(a, b, t)
    local u = 1.0 - t
    local aLab = Clr.rgbaToLab(a)
    local bLab = Clr.rgbaToLab(b)
    return Clr.labToRgba(
        u * aLab.l + t * bLab.l,
        u * aLab.a + t * bLab.a,
        u * aLab.b + t * bLab.b,
        u * aLab.alpha + t * bLab.alpha)
end

---Mixes two colors in RGBA space by a step.
---Assumes that the colors are in linear space.
---Clamps the step to [0.0, 1.0].
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixRgbaLinear(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixRgbaLinearInternal(a, b, u)
end

---Mixes two colors in RGBA space by a step.
---Assumes that the colors are in linear space.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixRgbaLinearInternal(a, b, t)
    local u = 1.0 - t
    return Clr.new(
        u * a.r + t * b.r,
        u * a.g + t * b.g,
        u * a.b + t * b.b,
        u * a.a + t * b.a)
end

---Mixes two colors in RGBA space by a step.
---Converts the colors from standard to linear,
---interpolates, then converts from linear
---to standard. Clamps the step to [0.0, 1.0].
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixRgbaStandard(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixRgbaStandardInternal(a, b, u)
end

---Mixes two colors in RGBA space by a step.
---Converts the colors from standard to linear,
---interpolates, then converts from linear
---to standard.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixRgbaStandardInternal(a, b, t)
    return Clr.linearToStandard(
        Clr.mixRgbaLinearInternal(
        Clr.standardToLinear(a),
        Clr.standardToLinear(b), t))
end

---Mixes two colors in CIE XYZ space by a step,
---then converts the result to a sRGB color.
---Clamps the step to [0.0, 1.0].
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixXyz(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixXyzInternal(a, b, u)
end

---Mixes two colors in CIE XYZ space by a step,
---then converts the result to a sRGB color.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixXyzInternal(a, b, t)
    local u = 1.0 - t
    local aXyz = Clr.rgbaToXyz(a)
    local bXyz = Clr.rgbaToXyz(b)
    return Clr.xyzToRgba(
        u * aXyz.x + t * bXyz.x,
        u * aXyz.y + t * bXyz.y,
        u * aXyz.z + t * bXyz.z,
        u * aXyz.a + t * bXyz.a)
end

---Multiplies two colors, including alpha.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.mul(a, b)
    return Clr.clamp01(Clr.mulUnchecked(a, b))
end

---Multiplies two colors, including alpha.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.mulUnchecked(a, b)
    return Clr.new(
        a.r * b.r,
        a.g * b.g,
        a.b * b.b,
        a.a * b.a)
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
function Clr.premul(a)
    if a.a <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, 0.0)
    elseif a.a >= 1.0 then
        return Clr.new(a.r, a.g, a.b, 1.0)
    else
        return Clr.new(
            a.r * a.a,
            a.g * a.a,
            a.b * a.a,
            a.a)
    end
end

---Reduces the granularity of a color's components.
---Performs no color conversion, so sRGB is assumed.
---@param a table color
---@param levels number levels
---@return table
function Clr.quantize(a, levels)
    -- TODO: Unsigned quantize instead?
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

---Converts a color to hue, saturation and value.
---The return table uses the keys h, s, l and a
---with values in the range [0.0, 1.0].
---@param a table color
---@return table
function Clr.rgbaToHsla(a)
    return Clr.rgbaToHslaInternal(a.r, a.g, a.b, a.a)
end

---Converts RGBA channels to hue, saturation and lightness.
---Assumes each channel is in the range [0.0, 1.0].
---The return table uses the keys h, s, l and a.
---Return values are also in the range [0.0, 1.0].
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number transparency
---@return table
function Clr.rgbaToHslaInternal(red, green, blue, alpha)
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

---Converts a color to hue, saturation and value.
---The return table uses the keys h, s, v and a
---with values in the range [0.0, 1.0].
---@param a table color
---@return table
function Clr.rgbaToHsva(a)
    return Clr.rgbaToHsvaInternal(a.r, a.g, a.b, a.a)
end

---Converts RGBA channels to hue, saturation and value.
---Assumes each channel is in the range [0.0, 1.0].
---The return table uses the keys h, s, v and a.
---Return values are also in the range [0.0, 1.0].
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number transparency
---@return table
function Clr.rgbaToHsvaInternal(red, green, blue, alpha)
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

---Converts a color from standard RGB to CIE L*a*b*.
---The return table uses the keys l, a, b and alpha.
---The alpha channel is unaffected by the transform.
---@param a table color
---@return table
function Clr.rgbaToLab(a)
    local xyz = Clr.rgbaToXyz(a)
    return Clr.xyzToLab(xyz.x, xyz.y, xyz.z, xyz.a)
end

---Converts a color from standard RGB to CIE XYZ.
---The return table uses the keys x, y, z and a.
---The alpha channel is unaffected by the transform.
---@param a table color
---@return table
function Clr.rgbaToXyz(a)
    local l = Clr.standardToLinear(a)
    return Clr.rgbaLinearToXyzInternal(l.r, l.g, l.b, l.a)
end

---Converts a color from linear RGBA to CIE XYZ.
---Assumes each channel is in the range [0.0, 1.0].
---The return table uses the keys x, y, z and a.
---The alpha channel is unaffected by the transform.
---@param red number red channel
---@param green number green channel
---@param blue number blue channel
---@param alpha number alpha channel
---@return table
function Clr.rgbaLinearToXyzInternal(red, green, blue, alpha)
    local aVerif = alpha or 1.0
    return {
        x = 0.4124108464885388   * red
          + 0.3575845678529519   * green
          + 0.18045380393360833  * blue,

        y = 0.21264934272065283  * red
          + 0.7151691357059038   * green
          + 0.07218152157344333  * blue,

        z = 0.019331758429150258 * red
          + 0.11919485595098397  * green
          + 0.9503900340503373   * blue,

        a = aVerif }
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---See https://www.wikiwand.com/en/SRGB.
---Does not transform the alpha channel.
---@param a table color
---@return table
function Clr.standardToLinear(a)

    -- 1.0 / 12.92 = 0.07739938080495357
    -- 1.0 / 1.055 = 0.9478672985781991

    local lr = a.r
    if lr <= 0.04045 then
        lr = lr * 0.07739938080495357
    else
        lr = ((lr + 0.055) * 0.9478672985781991) ^ 2.4
    end

    local lg = a.g
    if lg <= 0.04045 then
        lg = lg * 0.07739938080495357
    else
        lg = ((lg + 0.055) * 0.9478672985781991) ^ 2.4
    end

    local lb = a.b
    if lb <= 0.04045 then
        lb = lb * 0.07739938080495357
    else
        lb = ((lb + 0.055) * 0.9478672985781991) ^ 2.4
    end

    return Clr.new(lr, lg, lb, a.a)
end

---Subtracts two colors, including alpha.
---Clamps the result to [0.0, 1.0].
---@param a table left operand
---@param b table right operand
---@return table
function Clr.sub(a, b)
    return Clr.clamp01(Clr.subUnchecked(a, b))
end

---Subtracts two colors, including alpha.
---@param a table left operand
---@param b table right operand
---@return table
function Clr.subUnchecked(a, b)
    return Clr.new(
        a.r + b.r,
        a.g + b.g,
        a.b + b.b,
        a.a + b.a)
end

---Converts from a color to a hexadecimal integer.
---Channels are packed in 0xAABBGGRR order.
---Ensures that color values are valid, in [0.0, 1.0].
---@param c table color
---@return number
function Clr.toHex(c)
    return Clr.toHexUnchecked(Clr.clamp01(c))
end

---Converts from a color to a hexadecimal integer.
---Channels are packed in 0xAABBGGRR order.
---@param c table color
---@return number
function Clr.toHexUnchecked(c)
    return math.tointeger(c.a * 0xff + 0.5) << 0x18
         | math.tointeger(c.b * 0xff + 0.5) << 0x10
         | math.tointeger(c.g * 0xff + 0.5) << 0x08
         | math.tointeger(c.r * 0xff + 0.5)
end

---Converts from a color to a web-friendly hexadecimal
---string. Channels are packed in #RRGGBB order.
---Ensures that color values are valid, in [0.0, 1.0].
---@param c table color
---@return string
function Clr.toHexWeb(c)
    return Clr.toHexWebUnchecked(Clr.clamp01(c))
end

---Converts from a color to a web-friendly hexadecimal
---string. Channels are packed in #RRGGBB order.
---@param c table color
---@return string
function Clr.toHexWebUnchecked(c)
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

---Divides a color's red, green and blue
---channels by its alpha channel, reversing
---the premultiply operation.
---@param a table color
---@return table
function Clr.unpremul(a)
    if a.a <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, 0.0)
    elseif a.a >= 1.0 then
        return Clr.new(a.x, a.y, a.z, 1.0)
    else
        local aInv = 1.0 / a.a
        return Clr.new(
            a.r * aInv,
            a.g * aInv,
            a.b * aInv,
            a.a)
    end
end

---Converts a color from CIE XYZ to CIE L*a*b*.
---Assumes D65 illuminant, CIE 1931 2 degrees referents.
---The return table uses the keys l, a, b and alpha.
---The alpha channel is unaffected by the transform.
---See https://www.wikiwand.com/en/CIELAB_color_space
---and http://www.easyrgb.com/en/math.php.
---@param x number x channel
---@param y number y channel
---@param z number z channel
---@param alpha number alpha channel
---@return table
function Clr.xyzToLab(x, y, z, alpha)
    -- D65, CIE 1931 2 degrees
    -- 95.047, 100.0, 108.883
    -- 100.0 / 95.047 = 1.0521110608435826
    -- 100.0 / 108.883 = 0.9184170164304805
    -- 16.0 / 116.0 = 0.13793103448275862

    local vx = x * 1.0521110608435826
    if vx > 0.008856 then
        vx = vx ^ 0.3333333333333333
    else
        vx = 7.787 * vx + 0.13793103448275862
    end

    local vy = y
    if vy > 0.008856 then
        vy = vy ^ 0.3333333333333333
    else
        vy = 7.787 * vy + 0.13793103448275862
    end

    local vz = z * 0.9184170164304805
    if vz > 0.008856 then
        vz = vz ^ 0.3333333333333333
    else
        vz = 7.787 * vz + 0.13793103448275862
    end

    local aVerif = alpha or 1.0
    return {
        l = 116.0 * vy - 16.0,
        a = 500.0 * (vx - vy),
        b = 200.0 * (vy - vz),
        alpha = aVerif }
end

---Converts a color from CIE XYZ to standard RGB.
---The alpha channel is unaffected by the transform.
---@param x number x channel
---@param y number y channel
---@param z number z channel
---@param alpha number alpha channel
---@return table
function Clr.xyzToRgba(x, y, z, alpha)
    return Clr.linearToStandard(
        Clr.xyzaToRgbaLinear(x, y, z, alpha))
end

---Converts a color from CIE XYZ to linear RGB.
---The alpha channel is unaffected by the transform.
---@param x number x channel
---@param y number y channel
---@param z number z channel
---@param alpha number alpha channel
---@return table
function Clr.xyzaToRgbaLinear(x, y, z, alpha)
    local aVerif = alpha or 1.0
    return Clr.new(
          3.240812398895283    * x
        - 1.5373084456298136   * y
        - 0.4985865229069666   * z,

         -0.9692430170086407   * x
        + 1.8759663029085742   * y
        + 0.04155503085668564  * z,

          0.055638398436112804 * x
        - 0.20400746093241362  * y
        + 1.0571295702861434   * z,

        aVerif)
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