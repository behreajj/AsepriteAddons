---@class Lab
---@field public l number lightness, in [0.0, 100.0]
---@field public a number green to magenta
---@field public b number blue to yellow
---@field public alpha number opacity, in [0.0, 1.0]
---@operator len(): integer
Lab = {}
Lab.__index = Lab

setmetatable(Lab, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Arbitrary hue assigned to lighter grays in SR LCH conversion functions.
Lab.SR_LCH_HUE_LIGHT = 0.306391

---Arbitrary hue assigned to darker grays in SR LCH conversion functions.
Lab.SR_LCH_HUE_SHADOW = 0.874676

---Maximum chroma of a color in SR LCH that is in gamut in standard RGB.
Lab.SR_LCH_MAX_CHROMA = 119.07602046756

---Constructs a new color from lightness, a, b and alpha channels.
---The expected range for lightness is [0.0, 100.0].
---The expected range for alpha is [0.0, 1.0].
---The a and b axes are unbounded.
---@param l number lightness, in [0.0, 100.0]
---@param a number green to magenta
---@param b number blue to yellow
---@param alpha? number opacity, in [0.0, 1.0]
---@return Lab
---@nodiscard
function Lab.new(l, a, b, alpha)
    local inst <const> = setmetatable({}, Lab)
    inst.alpha = alpha or 1.0
    inst.b = b or 0.0
    inst.a = a or 0.0
    inst.l = l or 100.0
    return inst
end

function Lab:__eq(d)
    return Lab.toHexWrap(self) == Lab.toHexWrap(d)
end

function Lab:__le(d)
    return Lab.toHexWrap(self) <= Lab.toHexWrap(d)
end

function Lab:__len()
    return 4
end

function Lab:__lt(d)
    return Lab.toHexWrap(self) < Lab.toHexWrap(d)
end

function Lab:__tostring()
    return Lab.toJson(self)
end

---Bisects an array of colors to find the appropriate insertion point for a
---color. Biases towards the right insert point. Should be used with sorted
---arrays.
---@param arr Lab[] colors array
---@param elm Lab color
---@param compare? fun(a: Lab, b: Lab): boolean comparator
---@return integer
---@nodiscard
function Lab.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    local f <const> = compare or Lab.comparator
    while low < high do
        local middle <const> = (low + high) // 2
        local right <const> = arr[1 + middle]
        if right and f(elm, right) then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Finds the chroma of a color.
---@param o Lab color
---@return number
---@nodiscard
function Lab.chroma(o)
    return math.sqrt(o.a * o.a + o.b * o.b)
end

---Finds the chroma squared of a color.
---@param o Lab color
---@return number
---@nodiscard
function Lab.chromaSq(o)
    return o.a * o.a + o.b * o.b
end

---A comparator method to sort colors in a table.
---@param o Lab left comparisand
---@param d Lab right comparisand
---@return boolean
---@nodiscard
function Lab.comparator(o, d)
    -- This is sorted with a color's place in a octree in mind,
    -- where l corresponds to z, b to y, a to x.
    if o.l < d.l then return true end
    if o.l > d.l then return false end
    if o.b < d.b then return true end
    if o.b > d.b then return false end
    if o.a < d.a then return true end
    if o.a > d.a then return false end
    return o.alpha < d.alpha
end

---Finds the distance between two colors.
---Alpha's contribution is based on its scalar, which defaults to 0.0.
---@param o Lab origin color
---@param d Lab destination color
---@param alphaScalar? number alpha scalar
---@return number
---@nodiscard
function Lab.dist(o, d, alphaScalar)
    return Lab.distCylindrical(o, d, alphaScalar)
end

---Finds the cylindrical distance between two colors.
---Lightness is treated as the z axis.
---Alpha's contribution is based on its scalar, which defaults to 0.0.
---@param o Lab origin color
---@param d Lab destination color
---@param alphaScalar? number alpha scalar
---@return number
---@nodiscard
function Lab.distCylindrical(o, d, alphaScalar)
    local ca <const> = d.a - o.a
    local cb <const> = d.b - o.b
    local ts <const> = alphaScalar or 0.0
    return math.abs(ts * (d.alpha - o.alpha))
        + math.abs(d.l - o.l)
        + math.sqrt(ca * ca + cb * cb)
end

---Finds the spherical distance between two colors.
---Lightness is treated as the z axis.
---Alpha's contribution is based on its scalar, which defaults to 0.0.
---@param o Lab origin color
---@param d Lab destination color
---@param alphaScalar? number alpha scalar
---@return number
---@nodiscard
function Lab.distSpherical(o, d, alphaScalar)
    local ts <const> = alphaScalar or 0.0
    local ct <const> = ts * (d.alpha - o.alpha)
    local cl <const> = d.l - o.l
    local ca <const> = d.a - o.a
    local cb <const> = d.b - o.b
    return math.sqrt(ct * ct + cl * cl + ca * ca + cb * cb)
end

---Clamps a color to expected range, usually to prepare it for conversion to
---a hexadecimal integer. Lightness is clamped to [0.0, 100.0], a and b to
---[-127.5, 127.5], alpha to [0.0, 1.0].
---@param o Lab color
---@return Lab
---@nodiscard
function Lab.clamp(o)
    return Lab.new(
        math.min(math.max(o.l, 0.0), 100.0),
        math.min(math.max(o.a, -127.5), 127.5),
        math.min(math.max(o.b, -127.5), 127.5),
        math.min(math.max(o.alpha, 0.0), 1.0))
end

---Converts a color from LCH, a cylindrical representation, to LAB.
---Lightness is expected to be in [0.0, 100.0].
---Chroma is unbounded, but expected to be in [0.0, 127.5].
---Hue is expected to be in [0.0, 1.0].
---@param l number lightness
---@param c number chroma
---@param h number hue
---@param alpha number opacity
---@param tol? number gray tolerance
---@return Lab
---@nodiscard
function Lab.fromLch(l, c, h, alpha, tol)
    -- Return early cannot be done here because
    -- saturated colors are still possible at
    -- light = 0 and light = 100.
    local lVrf = l or 0.0
    lVrf = math.min(math.max(lVrf, 0.0), 100.0)

    local vTol = 0.00005
    if tol then vTol = tol end

    local cVrf = c or 0.0
    if cVrf < vTol then cVrf = 0.0 end
    local hVrf = h or 0.0
    hVrf = hVrf % 1.0
    local tVrf <const> = alpha or 1.0
    return Lab.fromLchInternal(
        lVrf, cVrf, hVrf, tVrf)
end

---Converts a color from LCH, a cylindrical representation, to LAB.
---Does not validate arguments for defaults or out of bounds.
---@param l number lightness
---@param c number chroma
---@param h number hue
---@param alpha? number opacity
---@return Lab
---@nodiscard
function Lab.fromLchInternal(l, c, h, alpha)
    local hRad <const> = h * 6.2831853071796
    return Lab.new(
        l,
        c * math.cos(hRad),
        c * math.sin(hRad),
        alpha or 1.0)
end

---Finds a color's hue.
---Returns zero if the color's chroma is zero.
---@param o Lab color
---@return number
---@nodiscard
function Lab.hue(o)
    local hueSigned <const> = math.atan(o.b, o.a)
    local tau <const> = math.pi + math.pi
    local hueUnsigned <const> = hueSigned < 0.0
        and hueSigned + tau
        or hueSigned
    return hueUnsigned / tau
end

---Inserts a color  into a table so as to maintain sorted order. Biases toward
---the right insertion point. Returns true if the unique color was inserted.
---@param arr Lab[] colors array
---@param elm Lab color
---@param compare? fun(a: Lab, b: Lab): boolean comparator
---@return boolean
function Lab.insortRight(arr, elm, compare)
    local i <const> = Lab.bisectRight(arr, elm, compare)
    local dupe <const> = arr[i - 1]
    if dupe
        and (Lab.toHexWrap(dupe) == Lab.toHexWrap(elm)) then
        return false
    end
    table.insert(arr, i, elm)
    return true
end

---Mixes two colors by a step. The mix is unclamped.
---@param o Lab origin
---@param d Lab destination
---@param step? number step
---@return Lab
---@nodiscard
function Lab.mix(o, d, step)
    local t <const> = step or 0.5
    local u <const> = 1.0 - t
    return Lab.new(
        u * o.l + t * d.l,
        u * o.a + t * d.a,
        u * o.b + t * d.b,
        u * o.alpha + t * d.alpha)
end

---Mixes two colors by a step using polar coordinates. The mix is unclamped.
---If either color is gray, then defaults to linear mix.
---@param o Lab origin
---@param d Lab destination
---@param step number step
---@param hueFunc fun(o: number, d: number, t: number): number hue function
---@return Lab
---@nodiscard
function Lab.mixPolar(o, d, step, hueFunc)
    local ocsq <const> = Lab.chromaSq(o)
    if ocsq < 0.00001 then return Lab.mix(o, d, step) end

    local dcsq <const> = Lab.chromaSq(d)
    if dcsq < 0.00001 then return Lab.mix(o, d, step) end

    local t <const> = step or 0.5
    local u <const> = 1.0 - t

    local cc <const> = u * math.sqrt(ocsq)
        + t * math.sqrt(dcsq)
    local tau <const> = math.pi + math.pi
    local ch <const> = tau * hueFunc(
        math.atan(o.b, o.a) / tau,
        math.atan(d.b, d.a) / tau,
        t)

    return Lab.new(
        u * o.l + t * d.l,
        cc * math.cos(ch),
        cc * math.sin(ch),
        u * o.alpha + t * d.alpha)
end

---Converts from a color to a hexadecimal integer. Channels are packed in
---0xTTTTLLLLAAAABBB order. Ensures that color values are valid.
---@param o Lab color
---@return integer
---@nodiscard
function Lab.toHexSat(o)
    return Lab.toHexWrap(Lab.clamp(o))
end

---Converts from a color to a hexadecimal integer.
---@param o Lab color
---@return integer
---@nodiscard
function Lab.toHexWrap(o)
    local t16 <const> = math.floor(o.alpha * 65535.0 + 0.5)
    local l16 <const> = math.floor(o.l * 655.35 + 0.5)
    local a16 <const> = 0x8000 + math.floor(o.a * 257.0)
    local b16 <const> = 0x8000 + math.floor(o.b * 257.0)

    -- Prefer an order that matches priorities of octree.
    -- return t16 << 0x30 | l16 << 0x20 | a16 << 0x10 | b16
    return l16 << 0x30 | b16 << 0x20 | a16 << 0x10 | t16
end

---Converts a color from SR LAB 2 to SR LCH.
---@param o Lab color
---@param tol? number gray tolerance
---@return { l: number, c: number, h: number, a: number }
---@nodiscard
function Lab.toLch(o, tol)
    -- 0.00004 is the square chroma for white.
    local vTol = 0.007072
    if tol then vTol = tol end

    local chromasq <const> = Lab.chromaSq(o)
    local c = 0.0
    local h = 0.0

    if chromasq < (vTol * vTol) then
        if o.l <= 0.0 then
            h = Lab.SR_LCH_HUE_SHADOW
        elseif o.l >= 100.0 then
            h = Lab.SR_LCH_HUE_LIGHT
        else
            local fac <const> = o.l * 0.01
            h = (1.0 - fac) * Lab.SR_LCH_HUE_SHADOW
                + fac * (1.0 + Lab.SR_LCH_HUE_LIGHT)
            h = h % 1.0
        end
    else
        c = math.sqrt(chromasq)
        h = math.atan(o.b, o.a) / (math.pi + math.pi)
        h = h % 1.0
    end

    return { l = o.l, c = c, h = h, a = o.alpha }
end

---Returns a JSON string of a color.
---@param o Lab color
---@return string
---@nodiscard
function Lab.toJson(o)
    return string.format(
        "{\"l\":%.4f,\"a\":%.4f,\"b\":%.4f,\"alpha\":%.4f}",
        o.l, o.a, o.b, o.alpha)
end

return Lab