---@class Rgb
---@field public r number red channel
---@field public g number green channel
---@field public b number blue channel
---@field public a number opacity
---@operator len(): integer
Rgb = {}
Rgb.__index = Rgb

setmetatable(Rgb, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Constructs a new color from red, green, blue and opacity channels. The
---expected range is [0.0, 1.0], however, to accomodate other color spaces,
---these bounds are not checked by the constructor.
---@param r number red channel
---@param g number green channel
---@param b number blue channel
---@param a? number opacity
---@return Rgb
---@nodiscard
function Rgb.new(r, g, b, a)
    local inst <const> = setmetatable({}, Rgb)
    inst.a = a or 1.0
    inst.b = b or 1.0
    inst.g = g or 1.0
    inst.r = r or 1.0
    return inst
end

function Rgb:__eq(b)
    return Rgb.bitEq(self, b)
end

function Rgb:__le(b)
    return Rgb.toHex(self) <= Rgb.toHex(b)
end

function Rgb:__len()
    return 4
end

function Rgb:__lt(b)
    return Rgb.toHex(self) < Rgb.toHex(b)
end

function Rgb:__tostring()
    return Rgb.toJson(self)
end

---Returns true if the alpha channel is within the range [0.0, 1.0].
---@param c Rgb color
---@param tol? number tolerance
---@return boolean
---@nodiscard
function Rgb.alphaIsInGamut(c, tol)
    local eps <const> = tol or 0.0
    return c.a >= -eps and c.a <= (1.0 + eps)
end

---Evaluates whether two colors have equal red, green, blue and alpha channels
---when considered as 32 bit integers where overflow is clamped to [0, 255].
---@param a Rgb left comparisand
---@param b Rgb right comparisand
---@return boolean
---@nodiscard
function Rgb.bitEq(a, b)
    return Rgb.bitEqAlpha(a, b) and Rgb.bitEqRgb(a, b)
end

---Evaluates whether two colors have equal alpha when considered as a byte
---where overflow is clamped to [0, 255].
---@param a Rgb left comparisand
---@param b Rgb right comparisand
---@return boolean
---@nodiscard
function Rgb.bitEqAlpha(a, b)
    -- This is used by the == operator, so defaults are in case b is not a clr.
    local ba = b.a
    if not ba then return false end
    local aa = a.a
    if aa < 0.0 then aa = 0.0 elseif aa > 1.0 then aa = 1.0 end
    if ba < 0.0 then ba = 0.0 elseif ba > 1.0 then ba = 1.0 end
    return math.floor(aa * 255.0 + 0.5) == math.floor(ba * 255.0 + 0.5)
end

---Evaluates whether two colors have equal red, green and blue channels when
---considered as 24 bit integers where overflow is clamped to [0, 255].
---@param a Rgb left comparisand
---@param b Rgb right comparisand
---@return boolean
---@nodiscard
function Rgb.bitEqRgb(a, b)
    -- This is used by the == operator, so defaults are in case b is not a clr.
    local bb = b.b
    if not bb then return false end
    local ab = a.b
    if ab < 0.0 then ab = 0.0 elseif ab > 1.0 then ab = 1.0 end
    if bb < 0.0 then bb = 0.0 elseif bb > 1.0 then bb = 1.0 end
    if math.floor(ab * 255.0 + 0.5) ~= math.floor(bb * 255.0 + 0.5) then
        return false
    end

    local bg = b.g
    if not bg then return false end
    local ag = a.g
    if ag < 0.0 then ag = 0.0 elseif ag > 1.0 then ag = 1.0 end
    if bg < 0.0 then bg = 0.0 elseif bg > 1.0 then bg = 1.0 end
    if math.floor(ag * 255.0 + 0.5) ~= math.floor(bg * 255.0 + 0.5) then
        return false
    end

    local br = b.r
    if not br then return false end
    local ar = a.r
    if ar < 0.0 then ar = 0.0 elseif ar > 1.0 then ar = 1.0 end
    if br < 0.0 then br = 0.0 elseif br > 1.0 then br = 1.0 end
    if math.floor(ar * 255.0 + 0.5) ~= math.floor(br * 255.0 + 0.5) then
        return false
    end

    return true
end

---Clamps a color to [0.0, 1.0].
---@param c Rgb color
---@return Rgb
---@nodiscard
function Rgb.clamp01(c)
    return Rgb.new(
        math.min(math.max(c.r, 0.0), 1.0),
        math.min(math.max(c.g, 0.0), 1.0),
        math.min(math.max(c.b, 0.0), 1.0),
        math.min(math.max(c.a, 0.0), 1.0))
end

---Converts from a hexadecimal representation of a color stored as 0xAABBGGRR.
---@param c integer hexadecimal color
---@return Rgb
---@nodiscard
function Rgb.fromHexAbgr32(c)
    return Rgb.new(
        (c & 0xff) / 255.0,
        (c >> 0x08 & 0xff) / 255.0,
        (c >> 0x10 & 0xff) / 255.0,
        (c >> 0x18 & 0xff) / 255.0)
end

---Converts from a hexadecimal representation of a grayscale stored as 0xAAVV.
---@param c integer hexadecimal color
---@return Rgb
---@nodiscard
function Rgb.fromHexAv16(c)
    local v <const> = (c & 0xff) / 255.0
    return Rgb.new(v, v, v,
        (c >> 0x08 & 0xff) / 255.0)
end

---Converts from a web-friendly hexadecimal string, such as #AABBCC, to a color.
---@param hexstr string web string
---@return Rgb
---@nodiscard
function Rgb.fromHexWeb(hexstr)
    local s = hexstr

    -- Remove prefix.
    if string.sub(s, 1, 1) == '#' then
        s = string.sub(s, 2)
    end

    local sn <const> = tonumber(s, 16)
    if sn then
        local lens <const> = #s
        if lens == 6 then
            return Rgb.new(
                (sn >> 0x10 & 0xff) / 255.0,
                (sn >> 0x08 & 0xff) / 255.0,
                (sn & 0xff) / 255.0,
                1.0)
        elseif lens == 4 then
            -- Assume RGB565.
            return Rgb.new(
                (sn >> 0xb & 0x1f) / 31.0,
                (sn >> 0x5 & 0x3f) / 63.0,
                (sn & 0x1f) / 31.0,
                1.0)
        elseif lens == 3 then
            return Rgb.new(
                (sn >> 0x8 & 0xf) / 15.0,
                (sn >> 0x4 & 0xf) / 15.0,
                (sn & 0xf) / 15.0,
                1.0)
        end
    end

    return Rgb.new(0.0, 0.0, 0.0, 0.0)
end

---Creates a one-dimensional table of colors arranged in a Cartesian grid from
---(0.0, 0.0, 0.0) to (1.0, 1.0, 1.0), representing standard RGB. Red changes
---across columns, green across rows and blue across layers.
---@param cols integer columns, red
---@param rows integer rows, green
---@param layers integer layers, blue
---@param alpha number opacity
---@return Rgb[]
---@nodiscard
function Rgb.gridsRgb(cols, rows, layers, alpha)
    -- Default arguments.
    local aVrf = alpha or 1.0
    local lVrf = layers or 2
    local rVrf = rows or 2
    local cVrf = cols or 2

    -- Validate arguments.
    -- TODO: Update to allow rows, columns and layers to be 1 wide
    -- then use an offset?
    aVrf = math.min(math.max(aVrf, 0.0), 1.0)
    lVrf = math.min(math.max(lVrf, 2), 256)
    rVrf = math.min(math.max(rVrf, 2), 256)
    cVrf = math.min(math.max(cVrf, 2), 256)

    local hToStep <const> = 1.0 / (lVrf - 1.0)
    local iToStep <const> = 1.0 / (rVrf - 1.0)
    local jToStep <const> = 1.0 / (cVrf - 1.0)

    ---@type Rgb[]
    local result <const> = {}
    local rcVrf <const> = rVrf * cVrf
    local length <const> = lVrf * rcVrf

    local k = 0
    while k < length do
        local h <const> = k // rcVrf
        local m <const> = k - h * rcVrf
        local i <const> = m // cVrf
        local j <const> = m % cVrf

        k = k + 1
        result[k] = Rgb.new(
            j * jToStep,
            i * iToStep,
            h * hToStep,
            aVrf)
    end

    return result
end

---Evaluates whether a color is black.
---Does not check alpha channel.
---@param c Rgb
---@return boolean
function Rgb.isBlack(c)
    return c.r < 0.000001
        and c.g < 0.000001
        and c.b < 0.000001
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param c Rgb linear color
---@return Rgb
---@nodiscard
function Rgb.lRgbTosRgb(c)
    return Rgb.lRgbTosRgbInternal(Rgb.clamp01(c))
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param c Rgb linear color
---@return Rgb
---@nodiscard
function Rgb.lRgbTosRgbInternal(c)
    local sr <const> = c.r
    local sg <const> = c.g
    local sb <const> = c.b

    -- 1.0 / 2.4 = 0.41666666666667
    return Rgb.new(
        sr <= 0.0031308 and sr * 12.92
        or (sr ^ 0.41666666666667) * 1.055 - 0.055,
        sg <= 0.0031308 and sg * 12.92
        or (sg ^ 0.41666666666667) * 1.055 - 0.055,
        sb <= 0.0031308 and sb * 12.92
        or (sb ^ 0.41666666666667) * 1.055 - 0.055,
        c.a)
end

---Mixes two colors by a step. Defaults to the fastest algorithm,
---i.e., applies linear interpolation to each channel with no
---color space transformation.
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mix(o, d, t)
    return Rgb.mixlRgb(o, d, t)
end

---Mixes two colors in RGBA space by a step. Assumes that the colors
---are in linear space. Clamps the step to [0.0, 1.0].
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mixlRgb(o, d, t)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Rgb.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Rgb.new(d.r, d.g, d.b, d.a)
    end
    return Rgb.mixlRgbaInternal(o, d, u)
end

---Mixes two colors in RGBA space by a step. Assumes that the colors
---are in linear space.
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mixlRgbaInternal(o, d, t)
    local u <const> = 1.0 - t
    return Rgb.new(
        u * o.r + t * d.r,
        u * o.g + t * d.g,
        u * o.b + t * d.b,
        u * o.a + t * d.a)
end

---Mixes two colors that represent normals used in dynamic lighting.
---Uses spherical linear interpolation, geometric formula.
---See https://en.wikipedia.org/wiki/Slerp . Colors should be
---in standard RGB.
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mixNormal(o, d, t)
    local ox = o.r + o.r - 1.0
    local oy = o.g + o.g - 1.0
    local oz = o.b + o.b - 1.0
    local omsq <const> = ox * ox + oy * oy + oz * oz
    if omsq > 0.0 then
        local omInv <const> = 1.0 / math.sqrt(omsq)
        ox = ox * omInv
        oy = oy * omInv
        oz = oz * omInv
    end

    local u <const> = t or 0.5
    if u <= 0.0 then
        return Rgb.new(
            ox * 0.5 + 0.5,
            oy * 0.5 + 0.5,
            oz * 0.5 + 0.5, o.a)
    end

    local dx = d.r + d.r - 1.0
    local dy = d.g + d.g - 1.0
    local dz = d.b + d.b - 1.0
    local dmsq <const> = dx * dx + dy * dy + dz * dz
    if dmsq > 0.0 then
        local dmInv <const> = 1.0 / math.sqrt(omsq)
        dx = dx * dmInv
        dy = dy * dmInv
        dz = dz * dmInv
    end

    if u >= 1.0 then
        return Rgb.new(
            dx * 0.5 + 0.5,
            dy * 0.5 + 0.5,
            dz * 0.5 + 0.5, d.a)
    end

    local odDot <const> = math.min(math.max(
        ox * dx + oy * dy + oz * dz,
        -0.999999), 0.999999)
    local omega <const> = math.acos(odDot)
    local omSin <const> = math.sin(omega)
    local omSinInv = 1.0
    if omSin ~= 0.0 then omSinInv = 1.0 / omSin end
    local v <const> = 1.0 - u
    local oFac <const> = math.sin(v * omega) * omSinInv
    local dFac <const> = math.sin(u * omega) * omSinInv

    local cx <const> = oFac * ox + dFac * dx
    local cy <const> = oFac * oy + dFac * dy
    local cz <const> = oFac * oz + dFac * dz
    local ca <const> = v * o.a + u * d.a
    local cmsq <const> = cx * cx + cy * cy + cz * cz
    if cmsq > 0.0 then
        local cmInv <const> = 0.5 / math.sqrt(cmsq)
        return Rgb.new(
            cx * cmInv + 0.5,
            cy * cmInv + 0.5,
            cz * cmInv + 0.5, ca)
    end
    return Rgb.new(0.5, 0.5, 0.5, ca)
end

---Mixes two colors in RGBA space by a step. Converts the colors
---from standard to linear, interpolates, then converts from linear
---to standard. Clamps the step to [0.0, 1.0].
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mixsRgb(o, d, t)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Rgb.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Rgb.new(d.r, d.g, d.b, d.a)
    end
    return Rgb.mixsRgbInternal(o, d, u)
end

---Mixes two colors in RGBA space by a step. Converts the colors
---from standard to linear, interpolates, then converts from linear
---to standard.
---@param o Rgb origin
---@param d Rgb destination
---@param t number step
---@return Rgb
---@nodiscard
function Rgb.mixsRgbInternal(o, d, t)
    return Rgb.lRgbTosRgbInternal(
        Rgb.mixlRgbaInternal(
            Rgb.sRgbTolRgbInternal(o),
            Rgb.sRgbTolRgbInternal(d), t))
end

---Returns true if the red, green and blue channels are within the range
---[0.0, 1.0].
---@param c Rgb color
---@param tol? number tolerance
---@return boolean
---@nodiscard
function Rgb.rgbIsInGamut(c, tol)
    local eps <const> = tol or 0.0
    return (c.r >= -eps and c.r <= (1.0 + eps))
        and (c.g >= -eps and c.g <= (1.0 + eps))
        and (c.b >= -eps and c.b <= (1.0 + eps))
end

---Returns true if all color channels are within the range [0.0, 1.0].
---@param c Rgb color
---@param tol? number tolerance
---@return boolean
---@nodiscard
function Rgb.rgbaIsInGamut(c, tol)
    return Rgb.alphaIsInGamut(c, tol) and Rgb.rgbIsInGamut(c, tol)
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param c Rgb color
---@return Rgb
---@nodiscard
function Rgb.sRgbTolRgb(c)
    return Rgb.sRgbTolRgbInternal(Rgb.clamp01(c))
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param c Rgb color
---@return Rgb
---@nodiscard
function Rgb.sRgbTolRgbInternal(c)
    local lr <const> = c.r
    local lg <const> = c.g
    local lb <const> = c.b

    -- 1.0 / 12.92 = 0.077399380804954
    -- 1.0 / 1.055 = 0.9478672985782
    return Rgb.new(
        lr <= 0.04045 and lr * 0.077399380804954
        or ((lr + 0.055) * 0.9478672985782) ^ 2.4,
        lg <= 0.04045 and lg * 0.077399380804954
        or ((lg + 0.055) * 0.9478672985782) ^ 2.4,
        lb <= 0.04045 and lb * 0.077399380804954
        or ((lb + 0.055) * 0.9478672985782) ^ 2.4,
        c.a)
end

---Converts from a color to a 32 bit hexadecimal integer.
---Channels are packed in 0xAABBGGRR order.
---Ensures that color channels are in gamut, within the range [0.0, 1.0].
---@param c Rgb color
---@return integer
---@nodiscard
function Rgb.toHex(c)
    return Rgb.toHexUnchecked(Rgb.clamp01(c))
end

---Converts an array of colors to an array of 32 bit hexadecimal integers.
---Channels are packed in 0xAABBGGRR order.
---Ensures that color channels are in gamut, within the range [0.0, 1.0].
---@param rgbs Rgb[] colors array
---@return integer[]
---@nodiscard
function Rgb.toHexArr(rgbs)
    local abgr32s <const> = {}
    local len <const> = #rgbs
    local i = 0
    while i < len do
        i = i + 1
        abgr32s[i] = Rgb.toHex(rgbs[i])
    end
    return abgr32s
end

---Converts an array of colors to an array of 32 bit hexadecimal integers.
---Channels are packed in 0xAABBGGRR order.
---@param rgbs Rgb[] colors array
---@return integer[]
---@nodiscard
function Rgb.toHexArrUnchecked(rgbs)
    local abgr32s <const> = {}
    local len <const> = #rgbs
    local i = 0
    while i < len do
        i = i + 1
        abgr32s[i] = Rgb.toHexUnchecked(rgbs[i])
    end
    return abgr32s
end

---Converts from a color to a 32 bit hexadecimal integer.
---Channels are packed in 0xAABBGGRR order.
---@param c Rgb color
---@return integer
---@nodiscard
function Rgb.toHexUnchecked(c)
    return math.floor(c.a * 255.0 + 0.5) << 0x18
        | math.floor(c.b * 255.0 + 0.5) << 0x10
        | math.floor(c.g * 255.0 + 0.5) << 0x08
        | math.floor(c.r * 255.0 + 0.5)
end

---Converts from a color to a web-friendly hexadecimal string. Channels are
---packed in RRGGBB order. Does not prepend a hashtag ('#').
---Ensures that color channels are in gamut, within the range [0.0, 1.0].
---@param c Rgb color
---@return string
---@nodiscard
function Rgb.toHexWeb(c)
    return Rgb.toHexWebUnchecked(Rgb.clamp01(c))
end

---Converts from a color to a web-friendly hexadecimal string.
---Channels are packed in RRGGBB order.
---Does not prepend a hashtag ('#').
---@param c Rgb color
---@return string
---@nodiscard
function Rgb.toHexWebUnchecked(c)
    return string.format("%06X",
        math.floor(c.r * 255.0 + 0.5) << 0x10
        | math.floor(c.g * 255.0 + 0.5) << 0x08
        | math.floor(c.b * 255.0 + 0.5))
end

---Returns a JSON string of a color.
---@param c Rgb color
---@return string
---@nodiscard
function Rgb.toJson(c)
    return string.format(
        "{\"r\":%.4f,\"g\":%.4f,\"b\":%.4f,\"a\":%.4f}",
        c.r, c.g, c.b, c.a)
end

return Rgb