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

---The maximum value on the green-magenta axis in SR LAB 2
---for a color converted from standard RGB.
Lab.SR_A_MAX = 104.49946

---The minimum value on the green-magenta axis in SR LAB 2
---for a color converted from standard RGB.
Lab.SR_A_MIN = -82.955986

---The maximum value on the blue-yellow axis in SR LAB 2
---for a color converted from standard RGB.
Lab.SR_B_MAX = 95.18662

---The minimum value on the blue-yellow axis in SR LAB 2
---for a color converted from standard RGB.
Lab.SR_B_MIN = -110.8078

---Arbitrary hue assigned to lighter grays in SR LCH
---conversion functions.
Lab.SR_HUE_LIGHT = 0.30922841685655

---Arbitrary hue assigned to darker grays in SR LCH
---conversion functions.
Lab.SR_HUE_SHADOW = 0.80922841685655

---Maximum chroma of a color in SR LCH that is in gamut
---in standard RGB.
Lab.SR_MAX_CHROMA = 119.07602046756

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
    return Lab.toHexWrap64(self) == Lab.toHexWrap64(d)
end

function Lab:__le(d)
    return Lab.toHexWrap64(self) <= Lab.toHexWrap64(d)
end

function Lab:__len()
    return 4
end

function Lab:__lt(d)
    return Lab.toHexWrap64(self) < Lab.toHexWrap64(d)
end

function Lab:__tostring()
    return Lab.toJson(self)
end

---Bisects an array of colors to find the appropriate insertion
---point for a color. Biases towards the right insert point.
---Should be used with sorted arrays.
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

---A comparator method to sort colors in a table.
---@param o Lab left comparisand
---@param d Lab right comparisand
---@return boolean
---@nodiscard
function Lab.comparator(o, d)
    if o.alpha < d.alpha then return true end
    if o.alpha > d.alpha then return false end
    if o.l < d.l then return true end
    if o.l > d.l then return false end
    if o.a < d.a then return true end
    if o.a > d.a then return false end
    return o.b < d.b
end

---Finds the cylindrical distance between two colors.
---Lightness is treated as the z axis.
---@param o Lab origin color
---@param d Lab destination color
---@return number
---@nodiscard
function Lab.distCylindrical(o, d)
    local ca <const> = d.a - o.a
    local cb <const> = d.b - o.b
    return math.abs(d.l - o.l)
        + math.sqrt(ca * ca + cb * cb)
end

---Clamps a color to expected range, usually to prepare it
---for conversion to a hexadecimal integer. Lightness is
---clamped to [0.0, 100.0], a and b to [-127.5, 127.5],
---alpha to [0.0, 1.0].
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

---Evaluates whether two color are exactly equal.
---Checks for reference equality prior to value equality.
---@param o Lab left comparisand
---@param d Lab right comparisand
---@return boolean
---@nodiscard
function Lab.equals(o, d)
    return rawequal(o, d)
        or Lab.equalsValue(o, d)
end

---Evaluates whether two color are exactly equal by component
---real number value.
---@param o Lab left comparisand
---@param d Lab right comparisand
---@return boolean
---@nodiscard
function Lab.equalsValue(o, d)
    return o.l == d.l
        and o.a == d.a
        and o.b == d.b
        and o.alpha == d.alpha
end

---Converts from a hexadecimal representation of a color stored as
---0xTTTTLLLLAAAABBBB.
---@param c integer hexadecimal color
---@return Lab
---@nodiscard
function Lab.fromHexTlab64(c)
    local t16 <const> = c >> 0x30 & 0xffff
    local l16 <const> = c >> 0x20 & 0xffff
    local a16 <const> = c >> 0x10 & 0xffff
    local b16 <const> = c & 0xffff

    return Lab.new(
        l16 / 655.35,
        (a16 - 0x8000) / 257.0,
        (b16 - 0x8000) / 257.0,
        t16 / 65535.0)
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

---Creates an array of 2 LAB colors at analogous hues from the key.
---The hues are positive and negative 30 degrees away.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonyAnalogous(o)
    local lAna <const> = (o.l * 2.0 + 50.0) / 3.0

    local cos30 <const> = 0.86602540378444
    local sin30 <const> = 0.5
    local a30 <const> = cos30 * o.a - sin30 * o.b
    local b30 <const> = cos30 * o.b + sin30 * o.a

    local cos330 <const> = 0.86602540378444
    local sin330 <const> = -0.5
    local a330 <const> = cos330 * o.a - sin330 * o.b
    local b330 <const> = cos330 * o.b + sin330 * o.a

    return {
        Lab.new(lAna, a30, b30, o.alpha),
        Lab.new(lAna, a330, b330, o.alpha)
    }
end

---Creates an array of 1 LAB color complementary to the key.
---The hue is 180 degrees away, or the negation of the key a and b.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonyComplement(o)
    return { Lab.new(100.0 - o.l, -o.a, -o.b, o.alpha) }
end

---Creates an array of 2 LAB colors at split hues from the key.
---The hues are 150 and 210 degrees away.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonySplit(o)
    local lSpl <const> = (250.0 - o.l * 2.0) / 3.0

    local cos150 <const> = -0.86602540378444
    local sin150 <const> = 0.5
    local a150 <const> = cos150 * o.a - sin150 * o.b
    local b150 <const> = cos150 * o.b + sin150 * o.a

    local cos210 <const> = -0.86602540378444
    local sin210 <const> = -0.5
    local a210 <const> = cos210 * o.a - sin210 * o.b
    local b210 <const> = cos210 * o.b + sin210 * o.a

    return {
        Lab.new(lSpl, a150, b150, o.alpha),
        Lab.new(lSpl, a210, b210, o.alpha)
    }
end

---Creates an array of 3 LAB colors at square hues from the key.
---The hues are 90, 180 and 270 degrees away.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonySquare(o)
    return {
        Lab.new(50.0, -o.b, o.a, o.alpha),
        Lab.new(100.0 - o.l, -o.a, -o.b, o.alpha),
        Lab.new(50.0, o.b, -o.a, o.alpha),
    }
end

---Creates an array of 3 LAB colors at tetradic hues from the key.
---The hues are 120, 180 and 300 degrees away.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonyTetradic(o)
    local lTri <const> = (200.0 - o.l) / 3.0
    local lCmp <const> = 100.0 - o.l
    local lTet <const> = (100.0 + o.l) / 3.0

    local cos120 <const> = -0.5
    local sin120 <const> = 0.86602540378444
    local a120 <const> = cos120 * o.a - sin120 * o.b
    local b120 <const> = cos120 * o.b + sin120 * o.a

    local cos300 <const> = 0.5
    local sin300 <const> = -0.86602540378444
    local a300 <const> = cos300 * o.a - sin300 * o.b
    local b300 <const> = cos300 * o.b + sin300 * o.a

    return {
        Lab.new(lTri, a120, b120, o.alpha),
        Lab.new(lCmp, -o.a, -o.b, o.alpha),
        Lab.new(lTet, a300, b300, o.alpha),
    }
end

---Creates an array of 2 LAB colors at triadic hues from the key.
---The hues are positive and negative 120 degrees away.
---@param o Lab key color
---@return Lab[]
---@nodiscard
function Lab.harmonyTriadic(o)
    local lTri <const> = (200.0 - o.l) / 3.0

    local cos120 <const> = -0.5
    local sin120 <const> = 0.86602540378444
    local a120 <const> = cos120 * o.a - sin120 * o.b
    local b120 <const> = cos120 * o.b + sin120 * o.a

    local cos240 <const> = -0.5
    local sin240 <const> = -0.86602540378444
    local a240 <const> = cos240 * o.a - sin240 * o.b
    local b240 <const> = cos240 * o.b + sin240 * o.a

    return {
        Lab.new(lTri, a120, b120, o.alpha),
        Lab.new(lTri, a240, b240, o.alpha),
    }
end

---Inserts a color into a table so as to maintain sorted order.
---Biases toward the right insertion point.
---Returns true if the unique color was inserted.
---@param arr Lab[] colors array
---@param elm Lab color
---@param compare? fun(a: Lab, b: Lab): boolean comparator
---@return boolean
function Lab.insortRight(arr, elm, compare)
    local i <const> = Lab.bisectRight(arr, elm, compare)
    local dupe <const> = arr[i - 1]
    if dupe and Lab.equals(dupe, elm) then
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

---Mixes two colors by a step using polar coordinates.
---If either color is gray, then defaults to linear mix.
---The mix is unclamped.
---@param o Lab origin
---@param d Lab destination
---@param step number step
---@param hueFunc fun(o: number, d: number, t: number): number hue function
---@return Lab
---@nodiscard
function Lab.mixPolar(o, d, step, hueFunc)
    local ocsq <const> = o.a * o.a + o.b * o.b
    if ocsq < 0.02 then return Lab.mix(o, d, step) end

    local dcsq <const> = d.a * d.a + d.b * d.b
    if dcsq < 0.02 then return Lab.mix(o, d, step) end

    local t <const> = step or 0.5
    local u <const> = 1.0 - t
    local tau <const> = math.pi + math.pi

    local cc <const> = u * math.sqrt(ocsq)
        + t * math.sqrt(dcsq)
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

---Generates a random color.
---@param lMin number lightness minimum
---@param lMax number lightness maximum
---@return Lab
---@nodiscard
function Lab.random(lMin, lMax)
    local rl <const> = math.random()
    local ra <const> = math.random()
    local rb <const> = math.random()

    local lMinVerif <const> = lMin or 5.0
    local lMaxVerif <const> = lMax or 95.0

    return Lab.new(
        (1.0 - rl) * lMinVerif + rl * lMaxVerif,
        (1.0 - ra) * Lab.SR_A_MIN + ra * Lab.SR_A_MAX,
        (1.0 - rb) * Lab.SR_B_MIN + rb * Lab.SR_B_MAX,
        1.0)
end

---Converts from a color to a 64 bit hexadecimal integer.
---Channels are packed in 0xTTTTLLLLAAAABBB order.
---Ensures that color values are valid.
---@param o Lab color
---@return integer
---@nodiscard
function Lab.toHexSat64(o)
    return Lab.toHexWrap64(Lab.clamp(o))
end

---Converts from a color to a 64 bit hexadecimal integer.
---@param o Lab color
---@return integer
---@nodiscard
function Lab.toHexWrap64(o)
    local t16 <const> = math.floor(o.alpha * 65535.0 + 0.5)
    local l16 <const> = math.floor(o.l * 655.35 + 0.5)
    local a16 <const> = 0x8000 + math.floor(o.a * 257.0)
    local b16 <const> = 0x8000 + math.floor(o.b * 257.0)

    return t16 << 0x30 | l16 << 0x20 | a16 << 0x10 | b16
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

    local chromasq <const> = o.a * o.a + o.b * o.b
    local c = 0.0
    local h = 0.0

    if chromasq < (vTol * vTol) then
        if o.l <= 0.0 then
            h = Lab.SR_HUE_SHADOW
        elseif o.l >= 100.0 then
            h = Lab.SR_HUE_LIGHT
        else
            local fac <const> = o.l * 0.01
            h = (1.0 - fac) * Lab.SR_HUE_SHADOW
                + fac * (1.0 + Lab.SR_HUE_LIGHT)
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