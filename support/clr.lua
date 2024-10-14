---@class Clr
---@field public r number red channel
---@field public g number green channel
---@field public b number blue channel
---@field public a number opacity
---@operator len(): integer
Clr = {}
Clr.__index = Clr

setmetatable(Clr, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Arbitrary hue assigned to lighter grays in SR LCH conversion functions.
Clr.SR_LCH_HUE_LIGHT = 0.306391

---Arbitrary hue assigned to darker grays in SR LCH conversion functions.
Clr.SR_LCH_HUE_SHADOW = 0.874676

---Maximum chroma of a color in SR LCH that is in gamut in standard RGB.
Clr.SR_LCH_MAX_CHROMA = 119.07602046756

---Constructs a new color from red, green, blue and opacity channels. The
---expected range is [0.0, 1.0], however, to accomodate other color spaces,
---these bounds are not checked by the constructor.
---@param r number red channel
---@param g number green channel
---@param b number blue channel
---@param a number? opacity
---@return Clr
---@nodiscard
function Clr.new(r, g, b, a)
    local inst <const> = setmetatable({}, Clr)
    inst.a = a or 1.0
    inst.b = b or 1.0
    inst.g = g or 1.0
    inst.r = r or 1.0
    return inst
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

---Returns true if the alpha channel is within the range [0.0, 1.0].
---@param c Clr color
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Clr.alphaIsInGamut(c, tol)
    local eps <const> = tol or 0.0
    return c.a >= -eps and c.a <= (1.0 + eps)
end

---Evaluates whether two colors have equal red, green, blue and alpha channels
---when considered as 32 bit integers where overflow is clamped to [0, 255].
---@param a Clr left comparisand
---@param b Clr right comparisand
---@return boolean
---@nodiscard
function Clr.bitEq(a, b)
    return Clr.bitEqAlpha(a, b) and Clr.bitEqRgb(a, b)
end

---Evaluates whether two colors have equal alpha when considered as a byte
---where overflow is clamped to [0, 255].
---@param a Clr left comparisand
---@param b Clr right comparisand
---@return boolean
---@nodiscard
function Clr.bitEqAlpha(a, b)
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
---@param a Clr left comparisand
---@param b Clr right comparisand
---@return boolean
---@nodiscard
function Clr.bitEqRgb(a, b)
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

---Blends two colors together by their alpha. Premultiplies each color by its
---alpha prior to blending. Unpremultiplies the result.
---@param a Clr source
---@param b Clr destination
---@return Clr
---@nodiscard
function Clr.blend(a, b)
    return Clr.blendInternal(Clr.clamp01(a), Clr.clamp01(b))
end

---Blends two colors together by their alpha. Premultiplies each color by its
---alpha prior to blending. Unpremultiplies the result. Does not check to see
---if color channels are in gamut. For more information, see
---https://www.w3.org/TR/compositing-1/ .
---@param a Clr source
---@param b Clr destination
---@return Clr
---@nodiscard
function Clr.blendInternal(a, b)
    -- TODO: This is used by only gradientOutline.
    -- Replace this with AseUtilities.blendRgbaChar?
    local t <const> = b.a
    local u <const> = 1.0 - t
    local v <const> = a.a
    local uv <const> = v * u
    local tuv <const> = t + uv
    if tuv >= 1.0 then
        return Clr.new(
            b.r * t + a.r * uv,
            b.g * t + a.g * uv,
            b.b * t + a.b * uv,
            1.0)
    elseif tuv > 0.0 then
        local tuvInv <const> = 1.0 / tuv
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
---@param c Clr color
---@return Clr
---@nodiscard
function Clr.clamp01(c)
    return Clr.new(
        math.min(math.max(c.r, 0.0), 1.0),
        math.min(math.max(c.g, 0.0), 1.0),
        math.min(math.max(c.b, 0.0), 1.0),
        math.min(math.max(c.a, 0.0), 1.0))
end

---Converts from a hexadecimal representation of a color stored as 0xAABBGGRR.
---@param c integer hexadecimal color
---@return Clr
---@nodiscard
function Clr.fromHexAbgr32(c)
    return Clr.new(
        (c & 0xff) / 255.0,
        (c >> 0x08 & 0xff) / 255.0,
        (c >> 0x10 & 0xff) / 255.0,
        (c >> 0x18 & 0xff) / 255.0)
end

---Converts from a hexadecimal representation of a grayscale stored as 0xAAVV.
---@param c integer hexadecimal color
---@return Clr
---@nodiscard
function Clr.fromHexAv16(c)
    local v <const> = (c & 0xff) / 255.0
    return Clr.new(v, v, v,
        (c >> 0x08 & 0xff) / 255.0)
end

---Converts from a web-friendly hexadecimal string, such as #AABBCC, to a color.
---@param hexstr string web string
---@return Clr
---@nodiscard
function Clr.fromHexWeb(hexstr)
    local s = hexstr

    -- Remove prefix.
    if string.sub(s, 1, 1) == '#' then
        s = string.sub(s, 2)
    end

    local sn <const> = tonumber(s, 16)
    if sn then
        local lens <const> = #s
        if lens == 6 then
            return Clr.new(
                (sn >> 0x10 & 0xff) / 255.0,
                (sn >> 0x08 & 0xff) / 255.0,
                (sn & 0xff) / 255.0,
                1.0)
        elseif lens == 4 then
            -- Assume RGB565.
            return Clr.new(
                (sn >> 0xb & 0x1f) / 31.0,
                (sn >> 0x5 & 0x3f) / 63.0,
                (sn & 0x1f) / 31.0,
                1.0)
        elseif lens == 3 then
            return Clr.new(
                (sn >> 0x8 & 0xf) / 15.0,
                (sn >> 0x4 & 0xf) / 15.0,
                (sn & 0xf) / 15.0,
                1.0)
        end
    end

    return Clr.new(0.0, 0.0, 0.0, 0.0)
end

---Creates a one-dimensional table of colors arranged in a Cartesian grid from
---(0.0, 0.0, 0.0) to (1.0, 1.0, 1.0), representing standard RGB.
---@param cols integer columns
---@param rows integer rows
---@param layers integer layers
---@param alpha number opacity
---@return Clr[]
---@nodiscard
function Clr.gridsRgb(cols, rows, layers, alpha)
    -- Default arguments.
    local aVrf = alpha or 1.0
    local lVrf = layers or 2
    local rVrf = rows or 2
    local cVrf = cols or 2

    -- Validate arguments.
    aVrf = math.min(math.max(aVrf, 0.003921568627451), 1.0)
    lVrf = math.min(math.max(lVrf, 2), 256)
    rVrf = math.min(math.max(rVrf, 2), 256)
    cVrf = math.min(math.max(cVrf, 2), 256)

    local hToStep <const> = 1.0 / (lVrf - 1.0)
    local iToStep <const> = 1.0 / (rVrf - 1.0)
    local jToStep <const> = 1.0 / (cVrf - 1.0)

    ---@type Clr[]
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
        result[k] = Clr.new(
            j * jToStep,
            i * iToStep,
            h * hToStep,
            aVrf)
    end

    return result
end

---Converts a color from linear RGB to SR Lab 2.
---The return table uses the keys l, a, b and alpha.
---Clamps the input color to [0.0, 1.0].
---@param c Clr linear color
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.lRgbToSrLab2(c)
    return Clr.lRgbToSrLab2Internal(Clr.clamp01(c))
end

---Converts a color from linear RGB to SR Lab 2.
---See Jan Behrens, https://www.magnetkern.de/srlab2.html .
---The return table uses the keys l, a, b and alpha.
---The alpha channel is unaffected by the transform.
---@param c Clr linear color
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.lRgbToSrLab2Internal(c)
    local r <const> = c.r
    local g <const> = c.g
    local b <const> = c.b

    local x = 0.32053 * r + 0.63692 * g + 0.04256 * b
    local y = 0.161987 * r + 0.756636 * g + 0.081376 * b
    local z = 0.017228 * r + 0.10866 * g + 0.874112 * b

    -- 216.0 / 24389.0 = 0.0088564516790356
    -- 24389.0 / 2700.0 = 9.032962962963
    x = x <= 0.0088564516790356 and x * 9.032962962963
        or (x ^ 0.33333333333333) * 1.16 - 0.16
    y = y <= 0.0088564516790356 and y * 9.032962962963
        or (y ^ 0.33333333333333) * 1.16 - 0.16
    z = z <= 0.0088564516790356 and z * 9.032962962963
        or (z ^ 0.33333333333333) * 1.16 - 0.16

    return {
        l = 37.095 * x + 62.9054 * y - 0.0008 * z,
        a = 663.4684 * x - 750.5078 * y + 87.0328 * z,
        b = 63.9569 * x + 108.4576 * y - 172.4152 * z,
        alpha = c.a
    }
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param c Clr linear color
---@return Clr
---@nodiscard
function Clr.lRgbTosRgb(c)
    return Clr.lRgbTosRgbInternal(Clr.clamp01(c))
end

---Converts a color from linear RGB to standard RGB (sRGB).
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param c Clr linear color
---@return Clr
---@nodiscard
function Clr.lRgbTosRgbInternal(c)
    local sr <const> = c.r
    local sg <const> = c.g
    local sb <const> = c.b

    -- 1.0 / 2.4 = 0.41666666666667
    return Clr.new(
        sr <= 0.0031308 and sr * 12.92
        or (sr ^ 0.41666666666667) * 1.055 - 0.055,
        sg <= 0.0031308 and sg * 12.92
        or (sg ^ 0.41666666666667) * 1.055 - 0.055,
        sb <= 0.0031308 and sb * 12.92
        or (sb ^ 0.41666666666667) * 1.055 - 0.055,
        c.a)
end

---Mixes two colors by a step. Defaults to the fastest algorithm, i.e., applies
---linear interpolation to each channel with no color space transformation.
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mix(o, d, t)
    return Clr.mixlRgb(o, d, t)
end

---Mixes two colors in RGBA space by a step. Assumes that the colors are in
---linear space. Clamps the step to [0.0, 1.0].
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixlRgb(o, d, t)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Clr.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Clr.new(d.r, d.g, d.b, d.a)
    end
    return Clr.mixlRgbaInternal(o, d, u)
end

---Mixes two colors in RGBA space by a step. Assumes that the colors are in
---linear space.
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixlRgbaInternal(o, d, t)
    local u <const> = 1.0 - t
    return Clr.new(
        u * o.r + t * d.r,
        u * o.g + t * d.g,
        u * o.b + t * d.b,
        u * o.a + t * d.a)
end

---Mixes two colors that represent normals used in dynamic lighting. Uses
---spherical linear interpolation, geometric formula. See
---https://en.wikipedia.org/wiki/Slerp . Colors should be in standard RGB.
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixNormal(o, d, t)
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
        return Clr.new(
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
        return Clr.new(
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
        return Clr.new(
            cx * cmInv + 0.5,
            cy * cmInv + 0.5,
            cz * cmInv + 0.5, ca)
    end
    return Clr.new(0.5, 0.5, 0.5, ca)
end

---Mixes two colors in RGBA space by a step. Converts the colors from standard
---to linear, interpolates, then converts from linear to standard. Clamps the
---step to [0.0, 1.0].
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixsRgb(o, d, t)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Clr.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Clr.new(d.r, d.g, d.b, d.a)
    end
    return Clr.mixsRgbInternal(o, d, u)
end

---Mixes two colors in RGBA space by a step. Converts the colors from standard
---to linear, interpolates, then converts from linear to standard.
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixsRgbInternal(o, d, t)
    return Clr.lRgbTosRgbInternal(
        Clr.mixlRgbaInternal(
            Clr.sRgbTolRgbInternal(o),
            Clr.sRgbTolRgbInternal(d), t))
end

---Mixes two colors in SR LAB 2 by a step, then converts the result to sRGB.
---Clamps the step to [0.0, 1.0].
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixSrLab2(o, d, t)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Clr.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Clr.new(d.r, d.g, d.b, d.a)
    end
    return Clr.mixSrLab2Internal(o, d, u)
end

---Mixes two colors in SR LAB 2 by a step, then converts the result to sRGB.
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@return Clr
---@nodiscard
function Clr.mixSrLab2Internal(o, d, t)
    local u <const> = 1.0 - t
    local oLab <const> = Clr.sRgbToSrLab2(o)
    local dLab <const> = Clr.sRgbToSrLab2(d)
    return Clr.srLab2TosRgb(
        u * oLab.l + t * dLab.l,
        u * oLab.a + t * dLab.a,
        u * oLab.b + t * dLab.b,
        u * oLab.alpha + t * dLab.alpha)
end

---Mixes two colors in SR LCH by a step. The hue function should accept an
---origin, destination and factor, all numbers. The hue function defaults to
---nearest. The step is clamped to [0.0, 1.0].
---@param o Clr origin
---@param d Clr destination
---@param t number step
---@param hueFunc? fun(o: number, d: number, t: number): number hue function
---@return Clr
---@nodiscard
function Clr.mixSrLch(o, d, t, hueFunc)
    local u <const> = t or 0.5
    if u <= 0.0 then
        return Clr.new(o.r, o.g, o.b, o.a)
    end
    if u >= 1.0 then
        return Clr.new(d.r, d.g, d.b, d.a)
    end

    local f <const> = hueFunc or function(oh, dh, x)
        local diff <const> = dh - oh
        if diff ~= 0.0 then
            local y <const> = 1.0 - x
            if oh < dh and diff > 0.5 then
                return (y * (oh + 1.0) + x * dh) % 1.0
            elseif oh > dh and diff < -0.5 then
                return (y * oh + x * (dh + 1.0)) % 1.0
            else
                return y * oh + x * dh
            end
        else
            return oh
        end
    end

    return Clr.mixSrLchInternal(o, d, u, f)
end

---Mixes two colors in SR LCH by a step. The hue function should accept an
---origin, destination and factor, all numbers.
---@param o Clr origin
---@param d Clr color
---@param t number step
---@param hueFunc fun(o: number, d: number, t: number): number hue function
---@return Clr
---@nodiscard
function Clr.mixSrLchInternal(o, d, t, hueFunc)
    local oLab <const> = Clr.sRgbToSrLab2(o)
    local oa <const> = oLab.a
    local ob <const> = oLab.b
    local ocsq <const> = oa * oa + ob * ob
    local oIsGray <const> = ocsq < 0.00005

    local dLab <const> = Clr.sRgbToSrLab2(d)
    local da <const> = dLab.a
    local db <const> = dLab.b
    local dcsq <const> = da * da + db * db
    local dIsGray <const> = dcsq < 0.00005

    local u <const> = 1.0 - t
    if oIsGray or dIsGray then
        return Clr.srLab2TosRgb(
            u * oLab.l + t * dLab.l,
            u * oa + t * da,
            u * ob + t * db,
            u * oLab.alpha + t * dLab.alpha)
    else
        local oChr <const> = math.sqrt(ocsq)
        local oHue <const> = (math.atan(ob, oa) * 0.1591549430919) % 1.0

        local dChr <const> = math.sqrt(dcsq)
        local dHue <const> = (math.atan(db, da) * 0.1591549430919) % 1.0

        return Clr.srLchTosRgb(
            u * oLab.l + t * dLab.l,
            u * oChr + t * dChr,
            hueFunc(oHue, dHue, t),
            u * oLab.alpha + t * dLab.alpha,
            0.00005)
    end
end

---Returns true if the red, green and blue channels are within the range
---[0.0, 1.0].
---@param c Clr color
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Clr.rgbIsInGamut(c, tol)
    local eps <const> = tol or 0.0
    return (c.r >= -eps and c.r <= (1.0 + eps))
        and (c.g >= -eps and c.g <= (1.0 + eps))
        and (c.b >= -eps and c.b <= (1.0 + eps))
end

---Returns true if all color channels are within the range [0.0, 1.0].
---@param c Clr color
---@param tol number? tolerance
---@return boolean
---@nodiscard
function Clr.rgbaIsInGamut(c, tol)
    return Clr.alphaIsInGamut(c, tol) and Clr.rgbIsInGamut(c, tol)
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Clamps the input color to [0.0, 1.0].
---Does not transform the alpha channel.
---@param c Clr color
---@return Clr
---@nodiscard
function Clr.sRgbTolRgb(c)
    return Clr.sRgbTolRgbInternal(Clr.clamp01(c))
end

---Converts a color from standard RGB (sRGB) to linear RGB.
---Does not transform the alpha channel.
---See https://www.wikiwand.com/en/SRGB.
---@param c Clr color
---@return Clr
---@nodiscard
function Clr.sRgbTolRgbInternal(c)
    local lr <const> = c.r
    local lg <const> = c.g
    local lb <const> = c.b

    -- 1.0 / 12.92 = 0.077399380804954
    -- 1.0 / 1.055 = 0.9478672985782
    return Clr.new(
        lr <= 0.04045 and lr * 0.077399380804954
        or ((lr + 0.055) * 0.9478672985782) ^ 2.4,
        lg <= 0.04045 and lg * 0.077399380804954
        or ((lg + 0.055) * 0.9478672985782) ^ 2.4,
        lb <= 0.04045 and lb * 0.077399380804954
        or ((lb + 0.055) * 0.9478672985782) ^ 2.4,
        c.a)
end

---Converts a color from standard RGB to SR Lab 2.
---Clamps the input color to [0.0, 1.0].
---The return table uses the keys l, a, b and alpha.
---The green to red axis is a.
---The blue to yellow axis is b.
---@param c Clr linear color
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.sRgbToSrLab2(c)
    return Clr.sRgbToSrLab2Internal(Clr.clamp01(c))
end

---Converts a color from standard RGB to SR Lab 2.
---The return table uses the keys l, a, b and alpha.
---The green to red axis is a.
---The blue to yellow axis is b.
---@param c Clr color
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.sRgbToSrLab2Internal(c)
    return Clr.lRgbToSrLab2Internal(Clr.sRgbTolRgbInternal(c))
end

---Converts a color from standard RGB to SR LCH.
---The return table uses the keys l, c, h and a.
---The alpha channel is unaffected by the transform.
---@param c Clr color
---@param tol number? gray tolerance
---@return { l: number, c: number, h: number, a: number }
---@nodiscard
function Clr.sRgbToSrLch(c, tol)
    local lab <const> = Clr.sRgbToSrLab2(c)
    return Clr.srLab2ToSrLch(lab.l, lab.a, lab.b, lab.alpha, tol)
end

---Converts a color from SR Lab 2 to linear RGB. See Jan Behrens,
---https://www.magnetkern.de/srlab2.html . The a and b components are unbounded
---but for sRGB [-111.0, 111.0] suffice. For light, the expected range is
---[0.0, 100.0]. The alpha channel is unaffected by the transform.
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number opacity
---@return Clr
---@nodiscard
function Clr.srLab2TolRgb(l, a, b, alpha)
    local l01 <const> = l * 0.01
    local x = l01 + 0.000904127 * a + 0.000456344 * b
    local y = l01 - 0.000533159 * a - 0.000269178 * b
    local z = l01 - 0.0058 * b

    -- 2700.0 / 24389.0 = 0.11070564598795
    -- 1.0 / 1.16 = 0.86206896551724
    if x <= 0.08 then
        x = x * 0.11070564598795
    else
        x = (x + 0.16) * 0.86206896551724
        x = x * x * x
    end

    if y <= 0.08 then
        y = y * 0.11070564598795
    else
        y = (y + 0.16) * 0.86206896551724
        y = y * y * y
    end

    if z <= 0.08 then
        z = z * 0.11070564598795
    else
        z = (z + 0.16) * 0.86206896551724
        z = z * z * z
    end

    local aVrf <const> = alpha or 1.0
    return Clr.new(
        5.435679 * x - 4.599131 * y + 0.163593 * z,
        -1.16809 * x + 2.327977 * y - 0.159798 * z,
        0.03784 * x - 0.198564 * y + 1.160644 * z,
        aVrf)
end

---Converts a color from SR Lab 2 to standard RGB.
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number opacity
---@return Clr
---@nodiscard
function Clr.srLab2TosRgb(l, a, b, alpha)
    return Clr.lRgbTosRgbInternal(Clr.srLab2TolRgb(l, a, b, alpha))
end

---Converts a color from SR Lab 2 to SR LCH.
---Returns a table with the keys l, c, h, a.
---Neither alpha nor lightness are affected by the transformation.
---@param l number lightness
---@param a number a, green to red
---@param b number b, blue to yellow
---@param alpha number opacity
---@param tol number? gray tolerance
---@return { l: number, c: number, h: number, a: number }
---@nodiscard
function Clr.srLab2ToSrLch(l, a, b, alpha, tol)
    -- 0.00004 is the square chroma for white.
    local vTol = 0.007072
    if tol then vTol = tol end

    local chromasq <const> = a * a + b * b
    local c = 0.0
    local h = 0.0

    if chromasq < (vTol * vTol) then
        local fac <const> = math.min(math.max(
            l * 0.01, 0.0), 1.0)
        h = (1.0 - fac) * Clr.SR_LCH_HUE_SHADOW
            + fac * (1.0 + Clr.SR_LCH_HUE_LIGHT)
    else
        h = math.atan(b, a) * 0.1591549430919
        c = math.sqrt(chromasq)
    end

    if h ~= 1.0 then h = h % 1.0 end
    local aVrf <const> = alpha or 1.0
    return { l = l, c = c, h = h, a = aVrf }
end

---Converts a color from SR LCH to standard RGB.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 120.0].
---Hue is expected to be in [0.0, 1.0].
---@param l number lightness
---@param c number chromaticity
---@param h number hue
---@param a number opacity
---@param tol number? gray tolerance
---@return Clr
---@nodiscard
function Clr.srLchTosRgb(l, c, h, a, tol)
    local lab <const> = Clr.srLchToSrLab2(l, c, h, a, tol)
    return Clr.srLab2TosRgb(lab.l, lab.a, lab.b, lab.alpha)
end

---Converts a color from SR LCH to SR Lab 2.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is expected to be in [0.0, 120.0].
---Hue is expected to be in [0.0, 1.0].
---@param l number lightness
---@param c number chromaticity
---@param h number hue
---@param a number opacity
---@param tol number? gray tolerance
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.srLchToSrLab2(l, c, h, a, tol)
    -- Return early cannot be done here because
    -- saturated colors are still possible at
    -- light = 0 and light = 100.
    local lVrf = l or 0.0
    lVrf = math.min(math.max(lVrf, 0.0), 100.0)

    local vTol = 0.00005
    if tol then vTol = tol end

    local cVrf = c or 0.0
    if cVrf < vTol then cVrf = 0.0 end
    local hVrf <const> = h % 1.0
    local aVrf <const> = a or 1.0
    return Clr.srLchToSrLab2Internal(
        lVrf, cVrf, hVrf, aVrf)
end

---Converts a color from SR LCH to SR Lab 2. Does not validate arguments for
---defaults or out of bounds.
---@param l number lightness
---@param c number chromaticity
---@param h number hue
---@param a number opacity
---@return { l: number, a: number, b: number, alpha: number }
---@nodiscard
function Clr.srLchToSrLab2Internal(l, c, h, a)
    local hRad <const> = h * 6.2831853071796
    return {
        l = l,
        a = c * math.cos(hRad),
        b = c * math.sin(hRad),
        alpha = a
    }
end

---Converts from a color to a hexadecimal integer. Channels are packed in
---0xAABBGGRR order. Ensures that color values are valid, in [0.0, 1.0].
---@param c Clr color
---@return integer
---@nodiscard
function Clr.toHex(c)
    return Clr.toHexUnchecked(Clr.clamp01(c))
end

---Converts from a color to a hexadecimal integer. Channels are packed in
---0xAABBGGRR order.
---@param c Clr color
---@return integer
---@nodiscard
function Clr.toHexUnchecked(c)
    return math.floor(c.a * 255.0 + 0.5) << 0x18
        | math.floor(c.b * 255.0 + 0.5) << 0x10
        | math.floor(c.g * 255.0 + 0.5) << 0x08
        | math.floor(c.r * 255.0 + 0.5)
end

---Converts from a color to a web-friendly hexadecimal string. Channels are
---packed in RRGGBB order. Does not prepend a hashtag ('#'). Ensures that color
---values are valid, in [0.0, 1.0].
---@param c Clr color
---@return string
---@nodiscard
function Clr.toHexWeb(c)
    return Clr.toHexWebUnchecked(Clr.clamp01(c))
end

---Converts from a color to a web-friendly hexadecimal string. Channels are
---packed in RRGGBB order. Does not prepend a hashtag ('#').
---@param c Clr color
---@return string
---@nodiscard
function Clr.toHexWebUnchecked(c)
    return string.format("%06X",
        math.floor(c.r * 255.0 + 0.5) << 0x10
        | math.floor(c.g * 255.0 + 0.5) << 0x08
        | math.floor(c.b * 255.0 + 0.5))
end

---Returns a JSON string of a color.
---@param c Clr color
---@return string
---@nodiscard
function Clr.toJson(c)
    return string.format(
        "{\"r\":%.4f,\"g\":%.4f,\"b\":%.4f,\"a\":%.4f}",
        c.r, c.g, c.b, c.a)
end

return Clr