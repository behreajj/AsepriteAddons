dofile("./rgb.lua")
dofile("./lab.lua")

ColorUtilities = {}
ColorUtilities.__index = ColorUtilities

setmetatable(ColorUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Converts a color from linear RGB to SR LAB 2.
---Clamps the input color to [0.0, 1.0].
---@param c Rgb linear color
---@return Lab
---@nodiscard
function ColorUtilities.lRgbToSrLab2(c)
    return ColorUtilities.lRgbToSrLab2Internal(Rgb.clamp01(c))
end

---Converts a color from linear RGB to SR LAB 2.
---See Jan Behrens, https://www.magnetkern.de/srlab2.html .
---The alpha channel is unaffected by the transform.
---@param c Rgb linear color
---@return Lab
---@nodiscard
function ColorUtilities.lRgbToSrLab2Internal(c)
    local x = 0.32053 * c.r + 0.63692 * c.g + 0.04256 * c.b
    local y = 0.161987 * c.r + 0.756636 * c.g + 0.081376 * c.b
    local z = 0.017228 * c.r + 0.10866 * c.g + 0.874112 * c.b

    -- 216.0 / 24389.0 = 0.0088564516790356
    -- 24389.0 / 2700.0 = 9.032962962963
    x = x <= 0.0088564516790356 and x * 9.032962962963
        or (x ^ 0.33333333333333) * 1.16 - 0.16
    y = y <= 0.0088564516790356 and y * 9.032962962963
        or (y ^ 0.33333333333333) * 1.16 - 0.16
    z = z <= 0.0088564516790356 and z * 9.032962962963
        or (z ^ 0.33333333333333) * 1.16 - 0.16

    return Lab.new(
        37.095 * x + 62.9054 * y - 0.0008 * z,
        663.4684 * x - 750.5078 * y + 87.0328 * z,
        63.9569 * x + 108.4576 * y - 172.4152 * z,
        c.a)
end

---Converts an origin and destination color from sRGB to SR LAB 2,
---mixes the colors in LAB, then converts them back to sRGB.
---@param o Rgb origin
---@param d Rgb destination
---@param step? number step
---@return Rgb
---@nodiscard
function ColorUtilities.mixSrLab2(o, d, step)
    local t <const> = step or 0.5
    if t <= 0.0 then return Rgb.new(o.r, o.g, o.b, o.a) end
    if t >= 1.0 then return Rgb.new(d.r, d.g, d.b, d.a) end
    return ColorUtilities.mixSrLab2Internal(o, d, t)
end

---Converts an origin and destination color from sRGB to SR LAB 2,
---mixes the colors in LAB, then converts them back to sRGB.
---If either color is black, defaults to sRGB mix.
---@param o Rgb origin
---@param d Rgb destination
---@param step number step
---@return Rgb
---@nodiscard
function ColorUtilities.mixSrLab2Internal(o, d, step)
    -- Adverse side effect is black-to-white are also sRGB.
    -- if Rgb.isBlack(o) or Rgb.isBlack(d) then
    --     return Rgb.mixlRgbaInternal(o, d, step)
    -- end
    return ColorUtilities.srLab2TosRgb(
        Lab.mix(
            ColorUtilities.sRgbToSrLab2Internal(o),
            ColorUtilities.sRgbToSrLab2Internal(d),
            step))
end

---Converts an origin and destination color from sRGB to SR LCH,
---mixes the colors in LCH, then converts them back to sRGB.
---@param o Rgb origin
---@param d Rgb destination
---@param step number step
---@param hueFunc? fun(o: number, d: number, x: number): number hue function
---@return Rgb
---@nodiscard
function ColorUtilities.mixSrLch(o, d, step, hueFunc)
    local t <const> = step or 0.5
    if t <= 0.0 then return Rgb.new(o.r, o.g, o.b, o.a) end
    if t >= 1.0 then return Rgb.new(d.r, d.g, d.b, d.a) end

    local f = hueFunc
    if f == nil then
        ---@param oh number
        ---@param dh number
        ---@param x number
        ---@return number
        f = function(oh, dh, x)
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
    end

    return ColorUtilities.mixSrLchInternal(o, d, t, f)
end

---Converts an origin and destination color from sRGB to SR LCH,
---mixes the colors in LCH, then converts them back to sRGB.
---If either color is black, defaults to sRGB mix.
---@param o Rgb origin
---@param d Rgb destination
---@param step number step
---@param hueFunc fun(o: number, d: number, t: number): number hue function
---@return Rgb
---@nodiscard
function ColorUtilities.mixSrLchInternal(o, d, step, hueFunc)
    -- Adverse side effect is black-to-white are also sRGB.
    -- if Rgb.isBlack(o) or Rgb.isBlack(d) then
    --     return Rgb.mixlRgbaInternal(o, d, step)
    -- end
    return ColorUtilities.srLab2TosRgb(
        Lab.mixPolar(
            ColorUtilities.sRgbToSrLab2Internal(o),
            ColorUtilities.sRgbToSrLab2Internal(d),
            step,
            hueFunc))
end

---Converts a color from SR LAB 2 to linear RGB. See Jan Behrens,
---https://www.magnetkern.de/srlab2.html . The a and b components
---are unbounded but for sRGB, [-111.0, 111.0] suffice. For light,
---the expected range is [0.0, 100.0]. The alpha channel is
---unaffected by the transform.
---@param lab Lab lab color
---@return Rgb
---@nodiscard
function ColorUtilities.srLab2TolRgb(lab)
    local l01 <const> = lab.l * 0.01
    local x = l01 + 0.000904127 * lab.a + 0.000456344 * lab.b
    local y = l01 - 0.000533159 * lab.a - 0.000269178 * lab.b
    local z = l01 - 0.0058 * lab.b

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

    return Rgb.new(
        5.435679 * x - 4.599131 * y + 0.163593 * z,
        -1.16809 * x + 2.327977 * y - 0.159798 * z,
        0.03784 * x - 0.198564 * y + 1.160644 * z,
        lab.alpha)
end

---Converts a color from SR LAB 2 to standard RGB.
---sRGB color may be out of gamut.
---@param lab Lab lab color
---@return Rgb
---@nodiscard
function ColorUtilities.srLab2TosRgb(lab)
    return Rgb.lRgbTosRgbInternal(ColorUtilities.srLab2TolRgb(lab))
end

---Converts a color from SR LCH to standard RGB.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is unbounded, but expected to be in [0.0, 127.5].
---Hue is expected to be in [0.0, 1.0].
---sRGB color may be out of gamut.
---@param l number lightness
---@param c number chroma
---@param h number hue
---@param alpha number opacity
---@param tol? number gray tolerance
---@return Rgb
---@nodiscard
function ColorUtilities.srLchTosRgb(l, c, h, alpha, tol)
    return ColorUtilities.srLab2TosRgb(Lab.fromLch(l, c, h, alpha, tol))
end

---Converts a color from SR LCH to standard RGB.
---Does not validate arguments.
---sRGB color may be out of gamut.
---@param l number lightness
---@param c number chroma
---@param h number hue
---@param alpha number opacity
---@return Rgb
---@nodiscard
function ColorUtilities.srLchTosRgbInternal(l, c, h, alpha)
    return ColorUtilities.srLab2TosRgb(Lab.fromLchInternal(l, c, h, alpha))
end

---Converts a color from standard RGB to SR LAB 2.
---Clamps the input color to [0.0, 1.0].
---@param c Rgb standard color
---@return Lab
---@nodiscard
function ColorUtilities.sRgbToSrLab2(c)
    return ColorUtilities.sRgbToSrLab2Internal(Rgb.clamp01(c))
end

---Converts a color from standard RGB to SR LAB 2.
---@param c Rgb standard color
---@return Lab
---@nodiscard
function ColorUtilities.sRgbToSrLab2Internal(c)
    return ColorUtilities.lRgbToSrLab2Internal(Rgb.sRgbTolRgbInternal(c))
end

---Converts a color from standard RGB to SR LCH.
---Clamps the input color to [0.0, 1.0].
---@param c Rgb color
---@param tol? number gray tolerance
---@return { l: number, c: number, h: number, a: number }
---@nodiscard
function ColorUtilities.sRgbToSrLch(c, tol)
    return ColorUtilities.sRgbToSrLchInternal(Rgb.clamp01(c), tol)
end

---Converts a color from standard RGB to SR LCH.
---@param c Rgb color
---@param tol? number gray tolerance
---@return { l: number, c: number, h: number, a: number }
---@nodiscard
function ColorUtilities.sRgbToSrLchInternal(c, tol)
    return Lab.toLch(ColorUtilities.sRgbToSrLab2Internal(c), tol)
end

return ColorUtilities