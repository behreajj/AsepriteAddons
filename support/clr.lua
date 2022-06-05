Clr = {}
Clr.__index = Clr

setmetatable(Clr, {
    __call = function(cls, ...)
        return cls.new(...)
    end })

---Constructs a new color from red, green
---blue and transparency channels.
---The expected range is [0.0, 1.0], however,
---to accomodate other color spaces, these
---bounds are not checked by the constructor.
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

---Arbitrary hue assigned to lighter grays
---in hue conversion functions.
Clr.HSL_HUE_LIGHT = 48.0 / 360.0

---Arbitrary hue assigned to darker grays
---in hue conversion functions.
Clr.HSL_HUE_SHADOW = 255.0 / 360.0

---Arbitrary hue assigned to lighter grays
---in LCh conversion functions.
Clr.LCH_HUE_LIGHT = 99.0 / 360.0

---Arbitrary hue assigned to darker grays
---in LCh conversion functions.
Clr.LCH_HUE_SHADOW = 308.0 / 360.0

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
    return Clr.bitEq(self, b)
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

function Clr:__tostring()
    return Clr.toJson(self)
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

---Returns true if the alpha channel is within
---the range [0.0, 1.0].
---@param a table color
---@param tol number tolerance
---@return boolean
function Clr.alphaIsInGamut(a, tol)
    local eps = tol or 0.0
    return a.a >= -eps and a.a <= (1.0 + eps)
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

---Evaluates whether two colors have equal red,
---green, blue and alpha channels when considered
---as 32 bit integers where overflow is clamped
---to [0, 255].
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Clr.bitEq(a, b)
    return Clr.bitEqAlpha(a, b)
        and Clr.bitEqRgb(a, b)
end

---Evaluates whether two colors have equal alpha
---when considered as a byte where overflow is
---clamped to [0, 255].
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Clr.bitEqAlpha(a, b)
    -- This is used by the == operator, so defaults
    -- are in case b is a non-color object.
    local ba = b.a
    if not ba then return false end
    local aa = a.a
    if aa < 0.0 then aa = 0.0 elseif aa > 1.0 then aa = 1.0 end
    if ba < 0.0 then ba = 0.0 elseif ba > 1.0 then ba = 1.0 end
    return math.tointeger(0.5 + aa * 0xff)
        == math.tointeger(0.5 + ba * 0xff)
end

---Evaluates whether two colors have equal red,
---green and blue channels when considered as
---24 bit integers where overflow is clamped
---to [0, 255].
---@param a table left comparisand
---@param b table right comparisand
---@return boolean
function Clr.bitEqRgb(a, b)
    -- This is used by the == operator, so defaults
    -- are in case b is a non-color object.
    local bb = b.b
    if not bb then return false end
    local ab = a.b
    if ab < 0.0 then ab = 0.0 elseif ab > 1.0 then ab = 1.0 end
    if bb < 0.0 then bb = 0.0 elseif bb > 1.0 then bb = 1.0 end
    if math.tointeger(0.5 + ab * 0xff)
        ~= math.tointeger(0.5 + bb * 0xff) then
        return false
    end

    local bg = b.g
    if not bg then return false end
    local ag = a.g
    if ag < 0.0 then ag = 0.0 elseif ag > 1.0 then ag = 1.0 end
    if bg < 0.0 then bg = 0.0 elseif bg > 1.0 then bg = 1.0 end
    if math.tointeger(0.5 + ag * 0xff)
        ~= math.tointeger(0.5 + bg * 0xff) then
        return false
    end

    local br = b.r
    if not br then return false end
    local ar = a.r
    if ar < 0.0 then ar = 0.0 elseif ar > 1.0 then ar = 1.0 end
    if br < 0.0 then br = 0.0 elseif br > 1.0 then br = 1.0 end
    if math.tointeger(0.5 + ar * 0xff)
        ~= math.tointeger(0.5 + br * 0xff) then
        return false
    end

    return true
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

---Blends two colors together by their alpha.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---@param a table source color
---@param b table destination color
---@return table
function Clr.blend(a, b)
    return Clr.blendInternal(
        Clr.clamp01(a),
        Clr.clamp01(b))
end

---Blends two colors together by their alpha.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---Does not check to see if color channels
---are in gamut. For more information,
---see https://www.w3.org/TR/compositing-1/ .
---@param a table source color
---@param b table destination color
---@return table
function Clr.blendInternal(a, b)
    local t = b.a
    local u = 1.0 - t
    local v = a.a
    local uv = v * u
    local tuv = t + uv
    if tuv >= 1.0 then
        return Clr.new(
            b.r * t + a.r * uv,
            b.g * t + a.g * uv,
            b.b * t + a.b * uv,
            1.0)
    elseif tuv > 0.0 then
        local tuvInv = 1.0 / tuv
        return Clr.new(
            (b.r * t + a.r * uv) * tuvInv,
            (b.g * t + a.g * uv) * tuvInv,
            (b.b * t + a.b * uv) * tuvInv,
            tuv)
    else
        return Clr.new(0.0, 0.0, 0.0, 0.0)
    end
end

---Clamps a color to [0.0, 1.0].
---@param a table left operand
---@return table
function Clr.clamp01(a)
    local cr = a.r or 0.0
    if cr < 0.0 then cr = 0.0
    elseif cr > 1.0 then cr = 1.0 end

    local cg = a.g or 0.0
    if cg < 0.0 then cg = 0.0
    elseif cg > 1.0 then cg = 1.0 end

    local cb = a.b or 0.0
    if cb < 0.0 then cb = 0.0
    elseif cb > 1.0 then cb = 1.0 end

    local ca = a.a or 0.0
    if ca < 0.0 then ca = 0.0
    elseif ca > 1.0 then ca = 1.0 end

    return Clr.new(cr, cg, cb, ca)
end

---Converts from a hexadecimal representation
---of a color stored as 0xAABBGGRR.
---@param c number hexadecimal color
---@return table
function Clr.fromHex(c)
    return Clr.new(
        (c & 0xff) * 0.003921568627451,
        (c >> 0x08 & 0xff) * 0.003921568627451,
        (c >> 0x10 & 0xff) * 0.003921568627451,
        (c >> 0x18 & 0xff) * 0.003921568627451)
end

---Converts an array of hexadecimal values to
---an array of colors.
---@param arr table hexadecimal array
---@return table
function Clr.fromHexArray(arr)
    local len = #arr
    local result = {}
    local i = 0
    while i < len do
        i = i + 1
        result[i] = Clr.fromHex(arr[i])
    end
    return result
end

---Converts from a web-friendly hexadecimal
---string, such as #AABBCC, to a color.
---@param hexstr string web string
---@return table
function Clr.fromHexWeb(hexstr)
    local s = hexstr

    -- Remove prefix.
    if string.sub(s, 1, 1) == '#' then
        s = string.sub(s, 2)
    end

    -- Account for #abc.
    if #s == 3 then
        local r = string.sub(s, 1, 1)
        local g = string.sub(s, 2, 2)
        local b = string.sub(s, 3, 3)
        s = r .. r .. g .. g .. b .. b
    end

    -- tonumber may return fail.
    local sn = tonumber(s, 16)
    if sn then
        -- Append opaque alpha.
        return Clr.fromHex(0xff000000 | sn)
    end
    return Clr.clearBlack()
end

---Creates a one-dimensional table of colors
---arranged as a UV Sphere where HSL is mapped
---to inclination, hue is mapped to azimuth and
---saturation is mapped to radius.
---@param longitudes number longitudes or hues
---@param latitudes number latitudes or lumas
---@param layers number layers or saturations
---@param satMin number minimum saturation
---@param satMax number maximum saturation
---@param alpha number transparency
---@return table
function Clr.gridHsl(
    longitudes, latitudes, layers,
    satMin, satMax,
    alpha)

    -- Default arguments.
    local aVal = alpha or 1.0
    local vsMax = satMax or 1.0
    local vsMin = satMin or 0.1
    local vLayers = layers or 1
    local vLats = latitudes or 16
    local vLons = longitudes or 32

    -- Validate.
    if aVal < 0.003921568627451 then
        aVal = 0.003921568627451
    elseif aVal > 1.0 then
        aVal = 1.0
    end
    if vLons < 3 then vLons = 3 end
    if vLats < 3 then vLats = 3 end
    if vLayers < 1 then vLayers = 1 end

    vsMax = math.min(1.0, math.max(0.000001, vsMax))
    vsMin = math.min(1.0, math.max(0.000001, vsMin))
    vsMax = math.max(vsMin, vsMax)
    local oneLayer = vLayers == 1
    if oneLayer then
        vsMin = vsMax
    else
        vsMin = math.min(vsMin, vsMax)
    end

    local toPrc = 1.0
    if not oneLayer then
        toPrc = 1.0 / (vLayers - 1.0)
    end
    local toLgt = 1.0 / (vLats + 1.0)
    local toHue = 1.0 / vLons

    local len2 = vLats * vLons
    local len3 = vLayers * len2

    local result = {}
    local k = 0
    while k < len3 do
        local h = k // len2
        local m = k - h * len2

        local hue = (m % vLons) * toHue

        local prc = h * toPrc
        local sat = (1.0 - prc) * vsMin + prc * vsMax

        -- Smooth step approximates sine wave.
        local lgt = ((m // vLons) + 1.0) * toLgt
        lgt = lgt * lgt * (3.0 - (lgt + lgt))

        k = k + 1
        result[k] = Clr.hslaTosRgba(
            hue, sat, lgt, aVal)
    end

    return result
end

---Creates a one-dimensional table of colors
---arranged in a Cartesian grid from (0.0, 0.0, 0.0)
---to (1.0, 1.0, 1.0), representing the standard
---RGB color space.
---@param cols number columns
---@param rows number rows
---@param layers number layers
---@param alpha number transparency
---@return table
function Clr.gridsRgb(cols, rows, layers, alpha)

    -- Default arguments.
    local aVal = alpha or 1.0
    local lVal = layers or 2
    local rVal = rows or 2
    local cVal = cols or 2

    -- Validate arguments.
    if aVal < 0.003921568627451 then
        aVal = 0.003921568627451
    elseif aVal > 1.0 then
        aVal = 1.0
    end

    if lVal < 2 then lVal = 2
    elseif lVal > 256 then lVal = 256 end
    if rVal < 2 then rVal = 2
    elseif rVal > 256 then rVal = 256 end
    if cVal < 2 then cVal = 2
    elseif cVal > 256 then cVal = 256 end

    local hToStep = 1.0 / (lVal - 1.0)
    local iToStep = 1.0 / (rVal - 1.0)
    local jToStep = 1.0 / (cVal - 1.0)

    local rcVal = rVal * cVal
    local length = lVal * rcVal
    local result = {}

    local k = 0
    while k < length do
        local h = k // rcVal
        local m = k - h * rcVal
        local i = m // cVal
        local j = m % cVal

        k = k + 1
        result[k] = Clr.new(
            j * jToStep,
            i * iToStep,
            h * hToStep,
            aVal)
    end

    return result
end

---Converts hue, saturation and lightness to a color.
---@param hue number hue
---@param sat number saturation
---@param light number lightness
---@param alpha number transparency
---@return table
function Clr.hslaTosRgba(hue, sat, light, alpha)
    local a = alpha or 1.0

    local l = light or 1.0
    if l <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, a)
    elseif l >= 1.0 then
        return Clr.new(1.0, 1.0, 1.0, a)
    end

    local s = sat or 1.0
    if s <= 0.0 then
        return Clr.new(l, l, l, a)
    elseif s >= 1.0 then
        s = 1.0
    end

    local q = 0.0
    if l < 0.5 then
        q = l * (1.0 + s)
    else
        q = l + s - l * s
    end

    local p = l + l - q
    local qnp6 = (q - p) * 6.0

    local h = hue or 0.0

    local r = p
    local rHue = (h + 0.33333333333333) % 1.0
    if rHue < 0.16666666666667 then
        r = p + qnp6 * rHue
    elseif rHue < 0.5 then
        r = q
    elseif rHue < 0.66666666666667 then
        r = p + qnp6 * (0.66666666666667 - rHue)
    end

    local g = p
    local gHue = h % 1.0
    if gHue < 0.16666666666667 then
        g = p + qnp6 * gHue
    elseif gHue < 0.5 then
        g = q
    elseif gHue < 0.66666666666667 then
        g = p + qnp6 * (0.66666666666667 - gHue)
    end

    local b = p
    local bHue = (h - 0.33333333333333) % 1.0
    if bHue < 0.16666666666667 then
        b = p + qnp6 * bHue
    elseif bHue < 0.5 then
        b = q
    elseif bHue < 0.66666666666667 then
        b = p + qnp6 * (0.66666666666667 - bHue)
    end

    return Clr.new(r, g, b, a)
end

---Converts hue, saturation and value to a color.
---@param hue number hue
---@param sat number saturation
---@param val number value
---@param alpha number transparency
---@return table
function Clr.hsvaTosRgba(hue, sat, val, alpha)
    local a = alpha or 1.0

    local v = val or 1.0
    if v <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, a)
    elseif v >= 1.0 then
        v = 1.0
    end

    local s = sat or 1.0
    if s <= 0.0 then
        return Clr.new(v, v, v, a)
    elseif s >= 1.0 then
        s = 1.0
    end

    local h = hue or 0.0
    h = h % 1.0
    h = 6.0 * h
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

---Converts a color from CIE LAB to CIE LCH.
---Returns a table with the keys l, c, h, a.
---The a stands for the alpha. Neither alpha nor
---lightness are affected by the transformation.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 135.0].
---Hue is expected to be in [0.0, 1.0].
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number alpha channel
---@param tol number grayscale tolerance
---@return table
function Clr.labToLch(l, a, b, alpha, tol)
    -- 0.00004 is the square chroma for #FFFFFF.
    local vTol = 0.007072
    if tol then vTol = tol end

    local chromasq = a * a + b * b
    local chroma = 0.0
    local hue = 0.0

    if chromasq < (vTol * vTol) then
        local fac = l * 0.01
        if fac < 0.0 then fac = 0.0
        elseif fac > 1.0 then fac = 1.0 end
        hue = (1.0 - fac) * Clr.LCH_HUE_SHADOW
            + fac * (1.0 + Clr.LCH_HUE_LIGHT)
    else
        hue = math.atan(b, a) * 0.1591549430919
        chroma = math.sqrt(chromasq)
    end

    if hue ~= 1.0 then hue = hue % 1.0 end
    return {
        l = l,
        c = chroma,
        h = hue,
        a = alpha or 1.0 }
end

---Converts a color from CIE LAB to standard RGB.
---The alpha channel is unaffected by the transform.
---The a and b components are unbounded but for sRGB
---[-110.0, 110.0] suffice. For light, the expected
---range is [0.0, 100.0].
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number alpha channel
---@return table
function Clr.labTosRgba(l, a, b, alpha)
    local xyz = Clr.labToXyz(l, a, b, alpha)
    return Clr.xyzaTosRgba(xyz.x, xyz.y, xyz.z, xyz.a)
end

---Converts a color from CIE LAB to CIE XYZ.
---Assumes D65 illuminant, CIE 1931 2 degrees referents.
---The return table uses the keys x, y, z and a.
---The alpha channel is unaffected by the transform.
---See https://www.wikiwand.com/en/CIELAB_color_space
---and http://www.easyrgb.com/en/math.php.
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number alpha channel
---@return table
function Clr.labToXyz(l, a, b, alpha)
    -- D65, CIE 1931 2 degrees
    -- 95.047, 100.0, 108.883
    -- 16.0 / 116.0 = 0.13793103448276
    -- 1.0 / 116.0 = 0.0086206896551724
    -- 1.0 / 7.787 = 0.1284175110118

    local vy = (l + 16.0) * 0.0086206896551724
    local vx = a * 0.002 + vy
    local vz = vy - b * 0.005

    local vye3 = vy * vy * vy
    if vye3 > 0.008856 then
        vy = vye3
    else
        vy = (vy - 0.13793103448276) * 0.1284175110118
    end

    local vxe3 = vx * vx * vx
    if vxe3 > 0.008856 then
        vx = vxe3
    else
        vx = (vx - 0.13793103448276) * 0.1284175110118
    end

    local vze3 = vz * vz * vz
    if vze3 > 0.008856 then
        vz = vze3
    else
        vz = (vz - 0.13793103448276) * 0.1284175110118
    end

    local aVerif = alpha or 1.0
    return {
        x = vx * 0.95047,
        y = vy,
        z = vz * 1.08883,
        a = aVerif }
end

---Converts a color from CIE LCH to CIE LAB.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 135.0].
---Hue is expected to be in [0.0, 1.0].
---Neither alpha nor lightness are affected by the
---transformation.
---@param l number lightness
---@param c number chromaticity
---@param h number hue in degrees
---@param a number alpha channel
---@param tol number gray tolerance
---@return table
function Clr.lchToLab(l, c, h, a, tol)
    -- Return early cannot be done here because
    -- saturated colors are still possible at light = 0
    -- and light = 100.
    local lVal = l or 0.0
    if lVal < 0.0 then
        lVal = 0.0
    elseif lVal > 100.0 then
        lVal = 100.0
    end

    local vTol = 0.00005
    if tol then vTol = tol end

    local cVal = c or 0.0
    if cVal < vTol then cVal = 0.0 end
    local hVal = h % 1.0
    local aVal = a or 1.0
    return Clr.lchToLabInternal(lVal, cVal, hVal, aVal)
end

---Converts a color from CIE LCH to CIE LAB.
---Does not validate arguments for defaults or
---out-of-bounds.
---@param l number lightness
---@param c number chromaticity
---@param h number hue in degrees
---@param a number alpha channel
---@return table
function Clr.lchToLabInternal(l, c, h, a)
    local hRad = h * 6.2831853071796
    return {
        l = l,
        a = c * math.cos(hRad),
        b = c * math.sin(hRad),
        alpha = a }
end

---Converts a color from CIE LCH to standard RGB.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 135.0].
---Hue is expected to be in [0.0, 1.0].
---@param l number lightness
---@param c number chromaticity
---@param h number hue in degrees
---@param a number alpha channel
---@param tol number grayscale tolerance
---@return table
function Clr.lchTosRgba(l, c, h, a, tol)
    local x = Clr.lchToLab(l, c, h, a, tol)
    return Clr.labTosRgba(x.l, x.a, x.b, x.alpha)
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param a table color
---@return table
function Clr.lRgbaTosRgba(a)
    return Clr.lRgbaTosRgbaInternal(Clr.clamp01(a))
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param a table color
---@return table
function Clr.lRgbaTosRgbaInternal(a)
    -- 1.0 / 2.4 = 0.41666666666667

    local sr = a.r
    if sr <= 0.0031308 then
        sr = sr * 12.92
    else
        sr = (sr ^ 0.41666666666667) * 1.055 - 0.055
    end

    local sg = a.g
    if sg <= 0.0031308 then
        sg = sg * 12.92
    else
        sg = (sg ^ 0.41666666666667) * 1.055 - 0.055
    end

    local sb = a.b
    if sb <= 0.0031308 then
        sb = sb * 12.92
    else
        sb = (sb ^ 0.41666666666667) * 1.055 - 0.055
    end

    return Clr.new(sr, sg, sb, a.a)
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
function Clr.lRgbaToXyzInternal(red, green, blue, alpha)
    local aVerif = alpha or 1.0
    return {
        x = 0.41241084648854 * red
            + 0.35758456785295 * green
            + 0.18045380393361 * blue,

        y = 0.21264934272065 * red
            + 0.7151691357059 * green
            + 0.072181521573443 * blue,

        z = 0.01933175842915 * red
            + 0.11919485595098 * green
            + 0.95039003405034 * blue,

        a = aVerif }
end

---Finds the relative luminance of a color.
---Assumes the color is in sRGB.
---@param c table color
---@return number
function Clr.luminance(c)
    return Clr.lumsRgb(c)
end

---Finds the relative luminance of a linear color,
---https://www.wikiwand.com/en/Relative_luminance,
---according to recommendation 709.
---@param c table color
---@return number
function Clr.lumlRgb(c)
    return c.r * 0.21264934272065
        + c.g * 0.7151691357059
        + c.b * 0.072181521573443
end

---Finds the relative luminance of a sRGB color,
---https://www.wikiwand.com/en/Relative_luminance,
---according to recommendation 709.
---@param c table color
---@return number
function Clr.lumsRgb(c)
    return Clr.lumlRgb(Clr.sRgbaTolRgbaInternal(c))
end

---Mixes two colors by a step.
---Defaults to the fastest algorithm, i.e.,
---applies linear interpolation to each channel
---with no color space transformation.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mix(a, b, t)
    return Clr.mixlRgba(a, b, t)
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
        return Clr.clamp01(a)
    end
    if u >= 1.0 then
        return Clr.clamp01(b)
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

    return Clr.mixHslaInternal(
        Clr.clamp01(a), Clr.clamp01(b), u, f)
end

---Mixes two colors in HSLA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---If one color's saturation is near zero and
---the other's is not, the former will adopt
---the hue of the latter.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHslaInternal(a, b, t, hueFunc)
    local aHsla = Clr.sRgbaToHslaInternal(a.r, a.g, a.b, a.a)
    local bHsla = Clr.sRgbaToHslaInternal(b.r, b.g, b.b, b.a)

    local aSat = aHsla.s
    local bSat = bHsla.s

    if aSat <= 0.000001 or bSat <= 0.000001 then
        return Clr.mixlRgbaInternal(a, b, t)
    end

    local u = 1.0 - t
    return Clr.hslaTosRgba(
        hueFunc(aHsla.h, bHsla.h, t),
        u * aSat + t * bSat,
        u * aHsla.l + t * bHsla.l,
        u * aHsla.a + t * bHsla.a)
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
        return Clr.clamp01(a)
    end
    if u >= 1.0 then
        return Clr.clamp01(b)
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

    return Clr.mixHsvaInternal(
        Clr.clamp01(a), Clr.clamp01(b), u, f)
end

---Mixes two colors in HSVA space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---If one color's saturation is near zero and
---the other's is not, the former will adopt
---the hue of the latter.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixHsvaInternal(a, b, t, hueFunc)
    local aHsva = Clr.sRgbaToHsvaInternal(a.r, a.g, a.b, a.a)
    local bHsva = Clr.sRgbaToHsvaInternal(b.r, b.g, b.b, b.a)

    local aSat = aHsva.s
    local bSat = bHsva.s

    if aSat <= 0.000001 or bSat <= 0.000001 then
        return Clr.mixlRgbaInternal(a, b, t)
    end

    local u = 1.0 - t
    return Clr.hsvaTosRgba(
        hueFunc(aHsva.h, bHsva.h, t),
        u * aSat + t * bSat,
        u * aHsva.v + t * bHsva.v,
        u * aHsva.a + t * bHsva.a)
end

---Mixes two colors in CIE LAB space by a step,
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

---Mixes two colors in CIE LAB space by a step,
---then converts the result to a sRGB color.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixLabInternal(a, b, t)
    local u = 1.0 - t
    local aLab = Clr.sRgbaToLab(a)
    local bLab = Clr.sRgbaToLab(b)
    return Clr.labTosRgba(
        u * aLab.l + t * bLab.l,
        u * aLab.a + t * bLab.a,
        u * aLab.b + t * bLab.b,
        u * aLab.alpha + t * bLab.alpha)
end

---Mixes two colors in LCH space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---The step is clamped to [0.0, 1.0].
---The hue function defaults to near.
---@param a table origin
---@param b table destination
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixLch(a, b, t, hueFunc)
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

    return Clr.mixLchInternal(a, b, u, f)
end

---Mixes two colors in LCH space by a step.
---The hue function should accept an origin,
---destination and factor, all numbers.
---If one color's chroma is near zero and the
---other's is not, the former will adopt the
---hue of the latter.
---@param a table origin
---@param b table color
---@param t number step
---@param hueFunc function hue function
---@return table
function Clr.mixLchInternal(a, b, t, hueFunc)
    local aLab = Clr.sRgbaToLab(a)
    local aa = aLab.a
    local ab = aLab.b
    local acsq = aa * aa + ab * ab

    local bLab = Clr.sRgbaToLab(b)
    local ba = bLab.a
    local bb = bLab.b
    local bcsq = ba * ba + bb * bb

    local u = 1.0 - t
    if acsq < 0.00005 or bcsq < 0.00005 then
        return Clr.labTosRgba(
            u * aLab.l + t * bLab.l,
            u * aa + t * ba,
            u * ab + t * bb,
            u * aLab.alpha + t * bLab.alpha)
    else
        local aChr = math.sqrt(acsq)
        local aHue = math.atan(ab, aa) * 0.1591549430919
        aHue = aHue % 1.0

        local bChr = math.sqrt(bcsq)
        local bHue = math.atan(bb, ba) * 0.1591549430919
        bHue = bHue % 1.0

        return Clr.lchTosRgba(
            u * aLab.l + t * bLab.l,
            u * aChr + t * bChr,
            hueFunc(aHue, bHue, t),
            u * aLab.alpha + t * bLab.alpha,
            0.00005)
    end
end

---Mixes two colors in RGBA space by a step.
---Assumes that the colors are in linear space.
---Clamps the step to [0.0, 1.0].
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixlRgba(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixlRgbaInternal(a, b, u)
end

---Mixes two colors in RGBA space by a step.
---Assumes that the colors are in linear space.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixlRgbaInternal(a, b, t)
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
function Clr.mixsRgba(a, b, t)
    local u = t or 0.5
    if u <= 0.0 then
        return Clr.new(a.r, a.g, a.b, a.a)
    end
    if u >= 1.0 then
        return Clr.new(b.r, b.g, b.b, b.a)
    end
    return Clr.mixsRgbaInternal(a, b, u)
end

---Mixes two colors in RGBA space by a step.
---Converts the colors from standard to linear,
---interpolates, then converts from linear
---to standard.
---@param a table origin
---@param b table destination
---@param t number step
---@return table
function Clr.mixsRgbaInternal(a, b, t)
    return Clr.lRgbaTosRgbaInternal(
        Clr.mixlRgbaInternal(
            Clr.sRgbaTolRgbaInternal(a),
            Clr.sRgbaTolRgbaInternal(b), t))
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
    local aXyz = Clr.sRgbaToXyz(a)
    local bXyz = Clr.sRgbaToXyz(b)
    return Clr.xyzaTosRgba(
        u * aXyz.x + t * bXyz.x,
        u * aXyz.y + t * bXyz.y,
        u * aXyz.z + t * bXyz.z,
        u * aXyz.a + t * bXyz.a)
end

---Evaluates whether the color's alpha channel
---is less than or equal to zero.
---@param c table color
---@return boolean
function Clr.none(c)
    return c.a <= 0.0
end

---Multiplies a color's red, green and blue
---channels by its alpha channel.
---@param c table color
---@return table
function Clr.premul(c)
    if c.a <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, 0.0)
    elseif c.a >= 1.0 then
        return Clr.new(c.r, c.g, c.b, 1.0)
    else
        return Clr.new(
            c.r * c.a,
            c.g * c.a,
            c.b * c.a,
            c.a)
    end
end

---Reduces the granularity of a color's components
---in sRGB. Uses signed quantization, as the color
---may be out of gamut.
---@param c table color
---@param levels number levels
---@return table
function Clr.quantize(c, levels)
    if levels and levels > 0 and levels < 256 then
        local delta = 1.0 / levels
        return Clr.quantizeInternal(
            c, levels, delta,
            levels, delta,
            levels, delta,
            levels, delta)
    end
    return Clr.new(c.r, c.g, c.b, c.a)
end

---Reduces the granularity of a color's components
---in sRGB. Uses signed quantization, as the color
---may be out of gamut.
---Internal helper function.
---Assumes that levels are within [1, 255] and the
---inverse of levels has already been calculated.
---@param c table color
---@param rLevels number red levels
---@param rDelta number red inverse
---@param gLevels number green levels
---@param gDelta number green inverse
---@param bLevels number blue levels
---@param bDelta number blue inverse
---@param aLevels number alpha levels
---@param aDelta number alpha inverse
---@return table
function Clr.quantizeInternal(
    c, rLevels, rDelta,
    gLevels, gDelta,
    bLevels, bDelta,
    aLevels, aDelta)

    return Clr.new(
        rDelta * math.floor(0.5 + c.r * rLevels),
        gDelta * math.floor(0.5 + c.g * gLevels),
        bDelta * math.floor(0.5 + c.b * bLevels),
        aDelta * math.floor(0.5 + c.a * aLevels))
end

---Creates a random color in CIE LAB space,
---converts it to sRGB, then clips to gamut.
---@param dark number light lower bound
---@param light number light upper bound
---@param green number a lower bound
---@param red number a upper bound
---@param blue number b lower bound
---@param yellow number b upper bound
---@param trns number alpha lower bound
---@param opaque number alpha upper bound
---@return table
function Clr.random(
    dark, light,
    green, red,
    blue, yellow,
    trns, opaque)

    local lMin = dark or 0.0
    local lMax = light or 100.0
    local aMin = green or -110.0
    local aMax = red or 110.0
    local bMin = blue or -110.0
    local bMax = yellow or 110.0
    local alphaMin = trns or 1.0
    local alphaMax = opaque or 1.0

    local lt = math.random()
    local at = math.random()
    local bt = math.random()
    local pt = math.random()

    return Clr.clamp01(Clr.labTosRgba(
        (1.0 - lt) * lMin + lt * lMax,
        (1.0 - at) * aMin + at * aMax,
        (1.0 - bt) * bMin + bt * bMax,
        (1.0 - pt) * alphaMin + pt * alphaMax))
end

---Returns true if the red, green and blue
---channels are within the range [0.0, 1.0].
---@param c table color
---@param tol number tolerance
---@return boolean
function Clr.rgbIsInGamut(c, tol)
    local eps = tol or 0.0
    return (c.r >= -eps and c.r <= (1.0 + eps))
        and (c.g >= -eps and c.g <= (1.0 + eps))
        and (c.b >= -eps and c.b <= (1.0 + eps))
end

---Returns true if all color channels are
---within the range [0.0, 1.0].
---@param c table color
---@param tol number tolerance
---@return boolean
function Clr.rgbaIsInGamut(c, tol)
    return Clr.alphaIsInGamut(c, tol)
        and Clr.rgbIsInGamut(c, tol)
end

---Converts a color to hue, saturation and value.
---The return table uses the keys h, s, l and a
---with values in the range [0.0, 1.0].
---@param c table color
---@return table
function Clr.sRgbaToHsla(c)
    local cl = Clr.clamp01(c)
    return Clr.sRgbaToHslaInternal(cl.r, cl.g, cl.b, cl.a)
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
function Clr.sRgbaToHslaInternal(red, green, blue, alpha)
    local gbmx = blue
    if green > blue then gbmx = green end
    local gbmn = blue
    if green < blue then gbmn = green end

    local mx = red
    if gbmx > red then mx = gbmx end
    local mn = red
    if gbmn < red then mn = gbmn end

    local sum = mx + mn
    local diff = mx - mn
    local light = 0.5 * sum

    if light < 0.003921568627451 then
        -- Black (epsilon is 1.0 / 255.0).
        return {
            h = Clr.HSL_HUE_SHADOW,
            s = 0.0,
            l = 0.0,
            a = alpha }
    elseif light > 0.99607843137255 then
        -- White (epsilon is 245.0 / 255.0).
        return {
            h = Clr.HSL_HUE_LIGHT,
            s = 0.0,
            l = 1.0,
            a = alpha }
    elseif diff < 0.003921568627451 then
        -- Gray.
        local hue = (1.0 - light) * Clr.HSL_HUE_SHADOW
            + light * (1.0 + Clr.HSL_HUE_LIGHT)
        if hue ~= 1.0 then hue = hue % 1.0 end
        return {
            h = hue,
            s = 0.0,
            l = light,
            a = alpha }
    else
        -- Find hue.
        local hue = 0.0
        if math.abs(mx - red) <= 0.003921568627451 then
            hue = (green - blue) / diff
            if green < blue then hue = hue + 6.0 end
        elseif math.abs(mx - green) <= 0.003921568627451 then
            hue = 2.0 + (blue - red) / diff
        else
            hue = 4.0 + (red - green) / diff
        end
        hue = hue * 0.16666666666667

        -- Find saturation.
        local sat = 0.0
        if light > 0.5 then
            sat = diff / (2.0 - sum)
        else
            sat = diff / sum
        end

        return {
            h = hue,
            s = sat,
            l = light,
            a = alpha }
    end
end

---Converts a color to hue, saturation and value.
---The return table uses the keys h, s, v and a
---with values in the range [0.0, 1.0].
---@param c table color
---@return table
function Clr.sRgbaToHsva(c)
    local cl = Clr.clamp01(c)
    return Clr.sRgbaToHsvaInternal(cl.r, cl.g, cl.b, cl.a)
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
function Clr.sRgbaToHsvaInternal(red, green, blue, alpha)
    -- Find maximum color channel.
    local gbmx = blue
    if green > blue then gbmx = green end
    local mx = red
    if gbmx > red then mx = gbmx end

    if mx < 0.003921568627451 then
        -- Black.
        return {
            h = Clr.HSL_HUE_SHADOW,
            s = 0.0,
            v = 0.0,
            a = alpha }
    else
        -- Find minimum color channel.
        local gbmn = blue
        if green < blue then gbmn = green end
        local mn = red
        if gbmn < red then mn = gbmn end

        -- Find difference between max and min.
        local diff = mx - mn
        if diff < 0.003921568627451 then
            local light = 0.5 * (mx + mn)
            if light > 0.99607843137255 then
                -- White.
                return {
                    h = Clr.HSL_HUE_LIGHT,
                    s = 0.0,
                    v = 1.0,
                    a = alpha }
            else
                -- Gray.
                -- Day is assumed to be less than shade in
                -- terms of angle, so one is added to lerp
                -- in proper angular direction.
                local hue = (1.0 - light) * Clr.HSL_HUE_SHADOW
                    + light * (1.0 + Clr.HSL_HUE_LIGHT)
                if hue ~= 1.0 then hue = hue % 1.0 end
                return {
                    h = hue,
                    s = 0.0,
                    v = mx,
                    a = alpha }
            end
        else
            -- Saturated color.
            local hue = 0.0
            if math.abs(mx - red) <= 0.003921568627451 then
                hue = (green - blue) / diff
                if green < blue then hue = hue + 6.0 end
            elseif math.abs(mx - green) <= 0.003921568627451 then
                hue = 2.0 + (blue - red) / diff
            else
                hue = 4.0 + (red - green) / diff
            end
            hue = hue * 0.16666666666667

            local sat = diff / mx

            return {
                h = hue,
                s = sat,
                v = mx,
                a = alpha }
        end
    end
end

---Converts a color from standard RGB to CIE LAB.
---The return table uses the keys l, a, b and alpha.
---The alpha channel is unaffected by the transform.
---@param c table color
---@return table
function Clr.sRgbaToLab(c)
    local xyz = Clr.sRgbaToXyz(c)
    return Clr.xyzToLab(xyz.x, xyz.y, xyz.z, xyz.a)
end

---Converts a color from standard RGB to CIE LCH.
---The return table uses the keys l, c, h and a.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 135.0].
---Hue is expected to be in [0.0, 1.0].
---The alpha channel is unaffected by the transform.
---@param c table color
---@param tol number gray tolerance
---@return table
function Clr.sRgbaToLch(c, tol)
    local lab = Clr.sRgbaToLab(c)
    return Clr.labToLch(lab.l, lab.a, lab.b, lab.alpha, tol)
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param c table color
---@return table
function Clr.sRgbaTolRgba(c)
    return Clr.sRgbaTolRgbaInternal(Clr.clamp01(c))
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param c table color
---@return table
function Clr.sRgbaTolRgbaInternal(c)
    -- 1.0 / 12.92 = 0.077399380804954
    -- 1.0 / 1.055 = 0.9478672985782

    local lr = c.r
    if lr <= 0.04045 then
        lr = lr * 0.077399380804954
    else
        lr = ((lr + 0.055) * 0.9478672985782) ^ 2.4
    end

    local lg = c.g
    if lg <= 0.04045 then
        lg = lg * 0.077399380804954
    else
        lg = ((lg + 0.055) * 0.9478672985782) ^ 2.4
    end

    local lb = c.b
    if lb <= 0.04045 then
        lb = lb * 0.077399380804954
    else
        lb = ((lb + 0.055) * 0.9478672985782) ^ 2.4
    end

    return Clr.new(lr, lg, lb, c.a)
end

---Converts a color from standard RGB to CIE XYZ.
---The return table uses the keys x, y, z and a.
---The alpha channel is unaffected by the transform.
---@param c table color
---@return table
function Clr.sRgbaToXyz(c)
    local l = Clr.sRgbaTolRgbaInternal(c)
    return Clr.lRgbaToXyzInternal(l.r, l.g, l.b, l.a)
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
    return math.tointeger(0.5 + c.a * 0xff) << 0x18
        | math.tointeger(0.5 + c.b * 0xff) << 0x10
        | math.tointeger(0.5 + c.g * 0xff) << 0x08
        | math.tointeger(0.5 + c.r * 0xff)
end

---Converts from a color to a web-friendly hexadecimal
---string. Channels are packed in RRGGBB order. Does
---not prepend a hashtag ('#').
---Ensures that color values are valid, in [0.0, 1.0].
---@param c table color
---@return string
function Clr.toHexWeb(c)
    return Clr.toHexWebUnchecked(Clr.clamp01(c))
end

---Converts from a color to a web-friendly hexadecimal
---string. Channels are packed in RRGGBB order. Does
---not prepend a hashtag ('#').
---@param c table color
---@return string
function Clr.toHexWebUnchecked(c)
    return string.format("%06X",
        math.tointeger(0.5 + c.r * 0xff) << 0x10
        | math.tointeger(0.5 + c.g * 0xff) << 0x08
        | math.tointeger(0.5 + c.b * 0xff))
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
---@param c table color
---@return table
function Clr.unpremul(c)
    if c.a <= 0.0 then
        return Clr.new(0.0, 0.0, 0.0, 0.0)
    elseif c.a >= 1.0 then
        return Clr.new(c.x, c.y, c.z, 1.0)
    else
        local aInv = 1.0 / c.a
        return Clr.new(
            c.r * aInv,
            c.g * aInv,
            c.b * aInv,
            c.a)
    end
end

---Converts a color from CIE XYZ to CIE LAB.
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
    -- 100.0 / 95.047 = 1.0521110608436
    -- 100.0 / 108.883 = 0.9184170164304805
    -- 16.0 / 116.0 = 0.13793103448276

    local vx = x * 1.0521110608436
    if vx > 0.008856 then
        vx = vx ^ 0.33333333333333
    else
        vx = 7.787 * vx + 0.13793103448276
    end

    local vy = y
    if vy > 0.008856 then
        vy = vy ^ 0.33333333333333
    else
        vy = 7.787 * vy + 0.13793103448276
    end

    local vz = z * 0.9184170164304805
    if vz > 0.008856 then
        vz = vz ^ 0.33333333333333
    else
        vz = 7.787 * vz + 0.13793103448276
    end

    local aVerif = alpha or 1.0
    return {
        l = 116.0 * vy - 16.0,
        a = 500.0 * (vx - vy),
        b = 200.0 * (vy - vz),
        alpha = aVerif }
end

---Converts a color from CIE XYZ to linear RGB.
---The alpha channel is unaffected by the transform.
---@param x number x channel
---@param y number y channel
---@param z number z channel
---@param alpha number alpha channel
---@return table
function Clr.xyzaTolRgba(x, y, z, alpha)
    local aVerif = alpha or 1.0
    return Clr.new(
        3.2408123988953 * x
        - 1.5373084456298 * y
        - 0.49858652290697 * z,

        -0.96924301700864 * x
        + 1.8759663029086 * y
        + 0.041555030856686 * z,

        0.055638398436113 * x
        - 0.20400746093241 * y
        + 1.0571295702861 * z,

        aVerif)
end

---Converts a color from CIE XYZ to standard RGB.
---The alpha channel is unaffected by the transform.
---@param x number x channel
---@param y number y channel
---@param z number z channel
---@param alpha number alpha channel
---@return table
function Clr.xyzaTosRgba(x, y, z, alpha)
    return Clr.lRgbaTosRgbaInternal(
        Clr.xyzaTolRgba(x, y, z, alpha))
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
