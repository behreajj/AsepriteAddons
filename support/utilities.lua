dofile("./vec2.lua")
dofile("./vec3.lua")
dofile("./vec4.lua")
dofile("./curve2.lua")
dofile("./curve3.lua")
dofile("./mat3.lua")
dofile("./mat4.lua")
dofile("./mesh2.lua")

Utilities = {}
Utilities.__index = Utilities

setmetatable(Utilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Houses utility methods not included in Lua.
---@return table
function Utilities.new()
    local inst <const> = setmetatable({}, Utilities)
    return inst
end

---Bisects an array of elements to find the appropriate index. Biases towards
---the right insert point. Should be used with sorted arrays.
---@generic T array type
---@generic U element type
---@param arr T[] array
---@param elm U query
---@param compare fun(a: U, b: T): boolean comparator
---@return integer
---@nodiscard
function Utilities.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    while low < high do
        local middle <const> = (low + high) // 2
        local right <const> = arr[1 + middle]
        if right and compare(elm, right) then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Concatenates an array of bytes into a string. Performs no validation on
---array elements; they are assumed to be in [0, 255].
---@param source integer[]
---@return string
---@nodiscard
function Utilities.bytesArrToString(source)
    ---@type string[]
    local chars <const> = {}
    local len <const> = #source
    local strchar <const> = string.char
    local i = 0
    while i < len do
        i = i + 1
        chars[i] = strchar(source[i])
    end
    return table.concat(chars)
end

---Generates a checker pattern. For creating backgrounds
---onto which images with alpha may be blit. The colors
---should be integers with matching bytes per pixel to
---the image.
---@param wImg integer image width
---@param hImg integer image height
---@param bpp integer bits per pixel
---@param wCheck integer checker width
---@param hCheck integer checker height
---@param aColor integer first checker hex
---@param bColor integer second checker hex
---@return string
function Utilities.checker(
    wImg, hImg, bpp, wCheck, hCheck, aColor, bColor)
    ---@type string[]
    local checkered <const> = {}
    local lenTrg <const> = wImg * hImg
    local fmtStr <const> = "<I" .. bpp
    local strpack <const> = string.pack
    local i = 0
    while i < lenTrg do
        local x <const> = i // wImg
        local y <const> = i % wImg
        local c = bColor
        if (((x // wCheck) + (y // hCheck)) % 2) ~= 1 then
            c = aColor
        end
        checkered[1 + i] = strpack(fmtStr, c)
        i = i + 1
    end
    return table.concat(checkered)
end

---Converts a dictionary to a sorted set. If a comparator is not provided,
---elements are sorted by their less than operator.
---@generic K key
---@generic V value
---@param dict table<K, V> dictionary
---@param comp? fun(a: K, b: K): boolean
---@return K[]
---@nodiscard
function Utilities.dictToSortedSet(dict, comp)
    local orderedSet <const> = {}
    local osCursor = 0
    for k, _ in pairs(dict) do
        osCursor = osCursor + 1
        orderedSet[osCursor] = k
    end
    -- Sort handles nil comparator function.
    table.sort(orderedSet, comp)
    return orderedSet
end

---Flattens an array of arrays to a 1D array.
---@generic T element
---@param arr2 T[][] array of arrays
---@return T[]
---@nodiscard
function Utilities.flatArr2(arr2)
    local flat <const> = {}
    local lenFlat = 0
    local lenOuter <const> = #arr2
    local i = 0
    while i < lenOuter do
        i = i + 1
        local arr1 <const> = arr2[i]
        local lenInner <const> = #arr1
        local j = 0
        while j < lenInner do
            j = j + 1
            lenFlat = lenFlat + 1
            flat[lenFlat] = arr1[j]
        end
    end
    return flat
end

---Transposes an image's bytes and flips them horizontally and vertically.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.flipPixelsAll(source, w, h, bpp)
    ---@type string[]
    local transposed <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h
    local wn1 <const> = w - 1
    local hn1 <const> = h - 1

    local i = 0
    while i < len do
        local y <const> = i // w
        local x <const> = i % w
        -- You could multiply wn1 * h before the loop then just x * h within?
        local j <const> = 1 + (wn1 - x) * h + hn1 - y
        local ibpp <const> = i * bpp
        transposed[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(transposed)
end

---Flips an image's bytes horizontally.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.flipPixelsX(source, w, h, bpp)
    ---@type string[]
    local flipped <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h
    local wn1 <const> = w - 1

    local i = 0
    while i < len do
        local j <const> = 1 + (i // w) * w + wn1 - (i % w)
        local ibpp <const> = i * bpp
        flipped[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(flipped)
end

---Flips an image's bytes vertically.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.flipPixelsY(source, w, h, bpp)
    ---@type string[]
    local flipped <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h
    local hn1 <const> = h - 1

    local i = 0
    while i < len do
        local y <const> = i // w
        local x <const> = i % w
        -- You could multiply hn1 * w before the loop then just y * w within?
        local j <const> = 1 + (hn1 - y) * w + x
        local ibpp <const> = i * bpp
        flipped[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(flipped)
end

---Hashes a string to a signed 64 bit integer based on the Fowler Noll Vo method.
---See https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
---and https://softwareengineering.stackexchange.com/q/49550 .
---@param s string string
---@return integer
---@nodiscard
function Utilities.fnvHash(s)
    -- This is intended for use with unsigned 64 bit integers,
    -- but Lua is limited to signed, which changes hash outcomes.
    local strbyte <const> = string.byte
    local len <const> = #s

    local h = 0xcbf29ce484222325
    local i = 0
    while i < len do
        i = i + 1
        h = h ~ strbyte(s, i)
        h = h * 0x100000001b3
    end
    return h
end

---Gets a pixel from an image's bytes, formatted as a string.
---Clamps coordinates to the image's boundaries.
---@param source string image bytes
---@param x integer x coordinate
---@param y integer y coordinate
---@param w integer image width
---@param h integer image height
---@param bpp integer bytes per pixel
---@param defaultValue string default value
---@return string
---@nodiscard
function Utilities.getPixelClamp(
    source, x, y, w, h, bpp, defaultValue)
    local xc <const> = math.min(math.max(x, 0), w - 1)
    local yc <const> = math.min(math.max(y, 0), h - 1)
    local ibpp <const> = (yc * w + xc) * bpp
    return string.sub(source, 1 + ibpp, bpp + ibpp)
end

---Gets a pixel from an image's bytes, formatted as a string.
---Out of bounds coordinates return the default value, usually the image's
---transparent color packed as a string acccording to the number of bytes per
---pixel, 4 for RGB, 2 for gray, etc.
---@param source string image bytes
---@param x integer x coordinate
---@param y integer y coordinate
---@param w integer image width
---@param h integer image height
---@param bpp integer bytes per pixel
---@param defaultValue string default value
---@return string
---@nodiscard
function Utilities.getPixelOmit(
    source, x, y, w, h, bpp, defaultValue)
    if x >= 0 and x < w
        and y >= 0 and y < h then
        local ibpp <const> = (y * w + x) * bpp
        return string.sub(source, 1 + ibpp, bpp + ibpp)
    end
    return defaultValue
end

---Gets a pixel from an image's bytes, formatted as a string.
---Out of bounds coordinates are wrapped around the edges.
---@param source string image bytes
---@param x integer x coordinate
---@param y integer y coordinate
---@param w integer image width
---@param h integer image height
---@param bpp integer bytes per pixel
---@param defaultValue string default value
---@return string
---@nodiscard
function Utilities.getPixelWrap(
    source, x, y, w, h, bpp, defaultValue)
    local xfm <const> = x % w
    local yfm <const> = y % h
    local ibpp <const> = (yfm * w + xfm) * bpp
    return string.sub(source, 1 + ibpp, bpp + ibpp)
end

---Generates a random number with normal distribution. Based on the Box-Muller
---transform as described here:
---https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform .
---@param sigma number? scalar
---@param mu number? offset
---@return number
---@nodiscard
function Utilities.gaussian(sigma, mu)
    local m <const> = mu or 0.0
    local s <const> = sigma or 1.0

    local u1 = 0.0
    repeat
        u1 = math.random()
    until (u1 > 0.000001)
    local u2 <const> = math.random()

    local r <const> = s * math.sqrt(-2.0 * math.log(u1))
    local x <const> = r * math.cos(6.2831853071796 * u2) + m
    -- local y = r * math.sin(6.2831853071796 * u2) + m
    return x
end

---Finds the greatest common denominator between two positive integers.
---@param a integer antecedent term
---@param b integer consequent term
---@return integer
---@nodiscard
function Utilities.gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

---Converts an array of integers representing color in hexadecimal to a
---dictionary. The value in each entry is the first index where the color was
---found. When true, the flag specifies that all completely transparent colors
---are considered equal, not unique.
---@param hexes integer[] hexadecimal colors
---@param za boolean zero alpha
---@return table<integer, integer>
---@nodiscard
function Utilities.hexArrToDict(hexes, za)
    ---@type table<integer, integer>
    local dict <const> = {}
    local lenHexes <const> = #hexes
    local idxRead = 0
    local idxValue = 0
    while idxRead < lenHexes do
        idxRead = idxRead + 1
        local hex = hexes[idxRead]

        if za then
            local a <const> = (hex >> 0x18) & 0xff
            if a < 1 then hex = 0x0 end
        end

        if not dict[hex] then
            idxValue = idxValue + 1
            dict[hex] = idxValue
        end
    end
    return dict
end

---Unclamped linear interpolation from an origin angle to a destination by a
---factor in [0.0, 1.0]. The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians. Uses the counter-clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
function Utilities.lerpAngleCcw(origin, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = origin % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return o end

    local u <const> = 1.0 - t
    if o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle to a destination by a
---factor in [0.0, 1.0]. The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians. Uses the clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
function Utilities.lerpAngleCw(origin, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = origin % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return d end

    local u <const> = 1.0 - t
    if o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle to a destination by a
---factor in [0.0, 1.0]. The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians. Uses the furthest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
function Utilities.lerpAngleFar(origin, dest, t, range)
    local valRange <const> = range or 360.0
    local halfRange <const> = valRange * 0.5
    local o <const> = origin % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    local u <const> = 1.0 - t

    if diff == 0.0 or (o < d and diff < halfRange) then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff > -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle to a destination by a
---factor in [0.0, 1.0]. The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians. Uses the nearest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
function Utilities.lerpAngleNear(origin, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = origin % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return o end

    local u <const> = 1.0 - t
    local halfRange <const> = valRange * 0.5
    if o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Multiplies a Mat3 with a Mesh2. Changes the mesh in place.
---@param a Mat3 matrix
---@param b Mesh2 mesh
---@return Mesh2
function Utilities.mulMat3Mesh2(a, b)
    local vs <const> = b.vs
    local vsLen <const> = #vs
    local i = 0
    while i < vsLen do
        i = i + 1
        vs[i] = Utilities.mulMat3Point2(a, vs[i])
    end
    return b
end

---Multiplies a Mat3 with a Vec2. The vector is treated as a point.
---@param a Mat3 matrix
---@param b Vec2 vector
---@return Vec2
---@nodiscard
function Utilities.mulMat3Point2(a, b)
    local w <const> = a.m20 * b.x + a.m21 * b.y + a.m22
    if w ~= 0.0 then
        local wInv <const> = 1.0 / w
        return Vec2.new(
            (a.m00 * b.x + a.m01 * b.y + a.m02) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m12) * wInv)
    else
        return Vec2.new(0.0, 0.0)
    end
end

---Multiplies a Mat4 with a Vec4.
---@param a Mat4 matrix
---@param b Vec4 vector
---@return Vec4
---@nodiscard
function Utilities.mulMat4Vec4(a, b)
    return Vec4.new(
        a.m00 * b.x + a.m01 * b.y
        + a.m02 * b.z + a.m03 * b.w,
        a.m10 * b.x + a.m11 * b.y
        + a.m12 * b.z + a.m13 * b.w,
        a.m20 * b.x + a.m21 * b.y
        + a.m22 * b.z + a.m23 * b.w,
        a.m30 * b.x + a.m31 * b.y
        + a.m32 * b.z + a.m33 * b.w)
end

---Finds the next power of 2 for a signed integer, i.e., multiplies the next
---power by the integer's sign. Returns zero if input is equal to zero.
---@param x integer input value
---@return integer
---@nodiscard
function Utilities.nextPowerOf2(x)
    if x ~= 0 then
        local xSgn = 1
        local xAbs = x
        if x < 0 then
            xAbs = -x
            xSgn = -1
        end
        local p = 1
        while p < xAbs do
            p = p << 1
        end
        return p * xSgn
    end
    return 0
end

---Parses a string of integers separated by a comma. The integers may either be
---individual or ranges connected by a colon. For example, "1,5,10:15,7".
---
---Supplying the frame count ensures the range is not out of bounds. Defaults
---to an arbitrary large number.
---
---Returns an array of arrays. Inner arrays can hold duplicate frame indices,
---as the user may intend for the same frame to appear in multiple groups.
---@param s string range string
---@param maxIdx integer? maximum index
---@param offset integer? offset
---@return integer[][]
---@nodiscard
function Utilities.parseRangeStringOverlap(s, maxIdx, offset)
    -- This could use an arbitrary min and max index, inclusive, instead of a
    -- max length, but it doesn't help for tile sets anyway, because the empty
    -- zero index counts as zero, regardless of the Tileset.baseIndex.
    local mnIdxVerif <const> = 1
    local mxIdxVerif <const> = maxIdx or 2147483647
    local offVerif <const> = offset or 0

    local strgmatch <const> = string.gmatch
    local min <const> = math.min
    local max <const> = math.max

    -- Parse string by comma.
    ---@type integer[][]
    local arrOuter <const> = {}
    local idxOuter = 0
    for token in strgmatch(s, "([^,]+)") do
        -- Parse string by colon.
        ---@type integer[]
        local edges <const> = {}
        local idxEdges = 0
        for subtoken in strgmatch(token, "[^:]+") do
            local trial <const> = tonumber(subtoken, 10)
            if trial then
                -- print(string.format("trial: %d", trial))
                idxEdges = idxEdges + 1
                edges[idxEdges] = trial - offVerif
            end
        end

        ---@type integer[]
        local arrInner <const> = {}
        local idxInner = 0
        local lenEdges <const> = #edges
        if lenEdges > 1 then
            -- print("lenEdges > 1")
            local origIdx = edges[1]
            local destIdx = edges[lenEdges]

            -- Edges of a range should be clamped to valid.
            origIdx = min(max(origIdx, mnIdxVerif), mxIdxVerif)
            destIdx = min(max(destIdx, mnIdxVerif), mxIdxVerif)

            if destIdx < origIdx then
                -- print("destIdx < origIdx")
                local j = origIdx + 1
                while j > destIdx do
                    j = j - 1
                    idxInner = idxInner + 1
                    arrInner[idxInner] = j
                    -- print(j)
                end
            elseif destIdx > origIdx then
                -- print("destIdx > origIdx")
                local j = origIdx - 1
                while j < destIdx do
                    j = j + 1
                    idxInner = idxInner + 1
                    arrInner[idxInner] = j
                    -- print(j)
                end
            else
                -- print("destIdx == origIdx")
                -- print(destIdx)
                idxInner = idxInner + 1
                arrInner[idxInner] = destIdx
            end
        elseif lenEdges > 0 then
            -- Filter out unique numbers if invalid, don't bother clamping.
            local trial <const> = edges[1]
            if trial >= mnIdxVerif and trial <= mxIdxVerif then
                idxInner = idxInner + 1
                arrInner[idxInner] = trial
                -- print("lenEdges > 0")
                -- print(trial)
            end
        end

        idxOuter = idxOuter + 1
        arrOuter[idxOuter] = arrInner
    end

    return arrOuter
end

---Parses a string of integers separated by a comma. The integers may either be
---individual or ranges connected by a colon. For example, "1,5,10:15,7".
---
---Supplying the frame count ensures the range is not out of bounds. Defaults
---to an arbitrary large number.
---
---Returns an ordered set of integers.
---@param s string range string
---@param maxIdx integer? maximum index
---@param offset integer? offset
---@return integer[]
---@nodiscard
function Utilities.parseRangeStringUnique(s, maxIdx, offset)
    local arr2 <const> = Utilities.parseRangeStringOverlap(
        s, maxIdx, offset)

    -- Convert 2D array to a dictionary.
    -- Use dummy true, not some idx scheme,
    -- because natural ordering is preferred.
    ---@type table<integer, boolean>
    local dict <const> = {}
    local lenArr2 <const> = #arr2
    local i = 0
    while i < lenArr2 do
        i = i + 1
        local arr1 <const> = arr2[i]
        local lenArr1 <const> = #arr1
        local j = 0
        while j < lenArr1 do
            j = j + 1
            dict[arr1[j]] = true
        end
    end

    return Utilities.dictToSortedSet(dict, nil)
end

---Prepends an alpha mask to a table of hexadecimal integers representing color.
---If the table already includes a mask, the input table is returned unchanged.
---If it contains a mask at another index, it is removed and placed at the
---start. Colors with zero alpha are not considered equal to an alpha mask.
---@param hexes integer[] colors
---@return integer[]
function Utilities.prependMask(hexes)
    if hexes[1] == 0x0 then return hexes end
    local cDict <const> = Utilities.hexArrToDict(hexes, false)
    local maskIdx <const> = cDict[0x0]
    if maskIdx then
        if maskIdx > 1 then
            table.remove(hexes, maskIdx)
            table.insert(hexes, 1, 0x0)
        end
    else
        table.insert(hexes, 1, 0x0)
    end
    return hexes
end

---Quantizes a signed number according to a number of levels. The quantization
---is centered about the range.
---@param a number value
---@param levels number levels
---@return number
---@nodiscard
function Utilities.quantizeSigned(a, levels)
    if levels ~= 0 then
        return Utilities.quantizeSignedInternal(
            a, levels, 1.0 / levels)
    end
    return a
end

---Quantizes a signed number according to a number of levels. The quantization
---is centered about the range. Internal helper function. Assumes that delta
---has been calculated as 1 / levels.
---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
---@nodiscard
function Utilities.quantizeSignedInternal(a, levels, delta)
    return math.floor(0.5 + a * levels) * delta
end

---Quantizes an unsigned number according to a number of levels. The
---quantization is based on the left edge.
---@param a number value
---@param levels number levels
---@return number
---@nodiscard
function Utilities.quantizeUnsigned(a, levels)
    if levels > 1 then
        return Utilities.quantizeUnsignedInternal(
            a, levels, 1.0 / (levels - 1.0))
    end
    return math.max(0.0, a)
end

---Quantizes an unsigned number according to a number of levels. The
---quantization is based on the left edge. Internal helper function. Assumes
---that delta has been calculated as 1 / (levels - 1).
---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
---@nodiscard
function Utilities.quantizeUnsignedInternal(a, levels, delta)
    return math.max(0.0, (math.ceil(a * levels) - 1.0) * delta)
end

---Reduces a ratio of positive integers to their smallest terms through
---division by their greatest common denominator.
---@param a integer antecedent term
---@param b integer consequent term
---@return integer
---@return integer
---@nodiscard
function Utilities.reduceRatio(a, b)
    local denom <const> = Utilities.gcd(a, b)
    return a // denom, b // denom
end

---Resizes a source pixel array to new dimensions with nearest neighbor
---sampling. Performs no validation on target width or height. Creates a new
---pixel array. Not intended for use when upscaling images on export.
---@param source string source pixels
---@param wSrc integer original width
---@param hSrc integer original height
---@param wTrg integer resized width
---@param hTrg integer resized height
---@param bpp integer bytes per pixel
---@param alphaIndex integer alpha index
---@return string
---@nodiscard
function Utilities.resizePixelsNearest(
    source, wSrc, hSrc, wTrg, hTrg, bpp, alphaIndex)
    ---@type string[]
    local resized <const> = {}

    local floor <const> = math.floor
    local strsub <const> = string.sub

    local tx <const> = wTrg > 0
        and wSrc / wTrg or 0.0
    local ty <const> = hTrg > 0
        and hSrc / hTrg or 0.0

    local zeroStr <const> = string.pack("<I" .. bpp, alphaIndex)
    local lenTrg <const> = wTrg * hTrg
    local i = 0
    while i < lenTrg do
        local trgHex = zeroStr
        local xTrgf <const> = (i % wTrg) * tx
        local yTrgf <const> = (i // wTrg) * ty
        local xTrgi <const> = floor(xTrgf)
        local yTrgi <const> = floor(yTrgf)
        if yTrgi >= 0 and yTrgi < hSrc
            and xTrgi >= 0 and xTrgi < wSrc then
            local jBpp <const> = (yTrgi * wSrc + xTrgi) * bpp
            trgHex = strsub(source, 1 + jBpp, bpp + jBpp)
        end

        i = i + 1
        resized[i] = trgHex
    end

    return table.concat(resized)
end

---Reverses a table used as an array. Useful for rotating an array of pixels
---180 degrees. Changes the table in place.
---@generic T element
---@param t T[] input table
---@return T[]
function Utilities.reverseTable(t)
    -- https://programming-idioms.org/idiom/19/reverse-a-list/1314/lua
    local n = #t
    local i = 1
    while i < n do
        t[i], t[n] = t[n], t[i]
        -- Post-increment, otherwise a table of len 2 won't flip.
        i = i + 1
        n = n - 1
    end
    return t
end

---Rotates an image's bytes 90 degrees counter clockwise.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.rotatePixels90(source, w, h, bpp)
    ---@type string[]
    local rotated <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h
    local lennh <const> = w * h - h

    local i = 0
    while i < len do
        local j <const> = 1 + lennh + (i // w) - (i % w) * h
        local ibpp <const> = i * bpp
        rotated[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(rotated)
end

---Rotates an image's bytes 180 degrees.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.rotatePixels180(source, w, h, bpp)
    ---@type string[]
    local rotated <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h

    local i = 0
    while i < len do
        local j <const> = len - i
        local ibpp <const> = i * bpp
        rotated[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(rotated)
end

---Rotates an image's bytes 270 degrees counter clockwise.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.rotatePixels270(source, w, h, bpp)
    ---@type string[]
    local rotated <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h
    local hn1 <const> = h - 1

    local i = 0
    while i < len do
        local j <const> = 1 + (i % w) * h + hn1 - (i // w)
        local ibpp <const> = i * bpp
        rotated[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(rotated)
end

---Rotates an image's bytes by an angle around the x axis.
---The angle is given as a pre calculated cosine and sine.
---Returns the byte string, the width and height of the rotated image.
---If the rotated image's height is zero, then returns width x 1 pixels.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param cosa number cosine of angle
---@param sina number sine of angle
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string rotated
---@return integer wTrg
---@return integer hTrg
function Utilities.rotatePixelsX(
    source, wSrc, hSrc, cosa, sina, bpp, alphaIndex)
    local hTrgSigned <const> = Utilities.round(cosa * hSrc)
    if hTrgSigned == 0 then
        ---@type string[]
        local rotated <const> = {}
        local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)
        local i = 0
        while i < wSrc do
            i = i + 1
            rotated[i] = alphaStr
        end
        return table.concat(rotated), wSrc, 1
    end

    local hTrgAbs <const> = math.abs(hTrgSigned)
    local resized = Utilities.resizePixelsNearest(
        source, wSrc, hSrc, wSrc, hTrgAbs, bpp, alphaIndex)
    if hTrgSigned < 0 then
        resized = Utilities.flipPixelsY(resized, wSrc, hTrgAbs, bpp)
    end
    return resized, wSrc, hTrgAbs
end

---Rotates an image's bytes by an angle around the y axis.
---The angle is given as a pre calculated cosine and sine.
---Returns the byte string, the width and height of the rotated image.
---If the rotated image's width is zero, then returns 1 x height pixels.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param cosa number cosine of angle
---@param sina number sine of angle
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string rotated
---@return integer wTrg
---@return integer hTrg
function Utilities.rotatePixelsY(
    source, wSrc, hSrc, cosa, sina, bpp, alphaIndex)
    local wTrgSigned <const> = Utilities.round(cosa * wSrc)
    if wTrgSigned == 0 then
        ---@type string[]
        local rotated <const> = {}
        local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)
        local i = 0
        while i < hSrc do
            i = i + 1
            rotated[i] = alphaStr
        end
        return table.concat(rotated), 1, hSrc
    end

    local wTrgAbs <const> = math.abs(wTrgSigned)
    local resized = Utilities.resizePixelsNearest(
        source, wSrc, hSrc, wTrgAbs, hSrc, bpp, alphaIndex)
    if wTrgSigned < 0 then
        resized = Utilities.flipPixelsX(resized, wTrgAbs, hSrc, bpp)
    end
    return resized, wTrgAbs, hSrc
end

---Rotates an image's bytes by an angle counter clockwise around the z axis.
---The angle is given as a pre calculated cosine and sine.
---Returns the byte string, the width and height of the rotated image.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param cosa number cosine of angle
---@param sina number sine of angle
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string rotated
---@return integer wTrg
---@return integer hTrg
function Utilities.rotatePixelsZ(
    source, wSrc, hSrc, cosa, sina, bpp, alphaIndex)
    ---@type string[]
    local rotated <const> = {}
    local strsub <const> = string.sub
    local round <const> = Utilities.round

    local absCosa <const> = math.abs(cosa)
    local absSina <const> = math.abs(sina)
    local wTrgf <const> = hSrc * absSina + wSrc * absCosa
    local hTrgf <const> = hSrc * absCosa + wSrc * absSina
    local wTrgi <const> = math.ceil(wTrgf)
    local hTrgi <const> = math.ceil(hTrgf)
    local lenTrg <const> = wTrgi * hTrgi
    local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)

    local xSrcCenter <const> = wSrc * 0.5
    local ySrcCenter <const> = hSrc * 0.5
    local xTrgCenter <const> = wTrgf * 0.5
    local yTrgCenter <const> = hTrgf * 0.5

    local i = 0
    while i < lenTrg do
        local xSgnf <const> = (i % wTrgi) - xTrgCenter
        local ySgnf <const> = (i // wTrgi) - yTrgCenter
        local xRotf <const> = cosa * xSgnf - sina * ySgnf
        local yRotf <const> = cosa * ySgnf + sina * xSgnf
        local xSrci <const> = round(xSrcCenter + xRotf)
        local ySrci <const> = round(ySrcCenter + yRotf)
        if ySrci >= 0 and ySrci < hSrc
            and xSrci >= 0 and xSrci < wSrc then
            local jbpp <const> = (ySrci * wSrc + xSrci) * bpp
            rotated[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        else
            rotated[1 + i] = alphaStr
        end
        i = i + 1
    end

    return table.concat(rotated), wTrgi, hTrgi
end

---Rounds a number to an integer based on its relationship to 0.5. Returns zero
---when the number cannot be determined to be either greater than or less than
---zero.
---@param x number real number
---@return integer
---@nodiscard
function Utilities.round(x)
    local ix <const>, fx <const> = math.modf(x)
    if ix <= 0 and fx <= -0.5 then
        return ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        return ix + 1
    end
    return ix
end

---Segments a one dimensional array of integers into a two dimensional array
---based on sequential elements. Assumes that the input array has been sorted
---and contains only unique integers.
---@param arr integer[]
---@return integer[][]
function Utilities.sequential(arr)
    local lenArr <const> = #arr
    if lenArr <= 0 then return { {} } end

    ---@type integer[][]
    local seqs <const> = {}
    local lenSeqs = 0
    local start = 0
    local i = 1
    while i <= lenArr do
        if i == lenArr or (arr[1 + i] ~= (arr[i] + 1)) then
            local seqStart <const> = arr[1 + start]
            local seqEnd <const> = arr[i]
            local seqLen <const> = 1 + seqEnd - seqStart
            ---@type integer[]
            local seq <const> = {}
            local j = 0
            while j < seqLen do
                j = j + 1
                seq[j] = arr[start + j]
            end
            lenSeqs = lenSeqs + 1
            seqs[lenSeqs] = seq
            start = i
        end
        i = i + 1
    end

    return seqs
end

---Skews an image's bytes by a tangent on the x axis.
---The angle is given as a pre calculated tangent.
---Returns the byte string, the width and height of the rotated image.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param tana number tangent of angle
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string rotated
---@return integer wTrg
---@return integer hTrg
function Utilities.skewPixelsX(
    source, wSrc, hSrc, tana, bpp, alphaIndex)
    ---@type string[]
    local skewed <const> = {}
    local strsub <const> = string.sub
    local round <const> = Utilities.round

    local absTan <const> = math.abs(tana)
    local wTrgf <const> = wSrc + absTan * hSrc
    local wTrgi <const> = math.ceil(wTrgf)
    local xDiff <const> = (wSrc - wTrgf) * 0.5
    local lenTrg <const> = wTrgi * hSrc
    local ySrcCenter <const> = hSrc * 0.5
    local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)

    local i = 0
    while i < lenTrg do
        local ySrci <const> = i // wTrgi
        local xSrcf <const> = xDiff + (i % wTrgi)
            + tana * (ySrci - ySrcCenter)
        local xSrci <const> = round(xSrcf)
        if xSrci >= 0 and xSrci < wSrc then
            local jbpp <const> = (ySrci * wSrc + xSrci) * bpp
            skewed[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        else
            skewed[1 + i] = alphaStr
        end
        i = i + 1
    end

    return table.concat(skewed), wTrgi, hSrc
end

---Skews an image's bytes horizontally by an integer rise. The run specifies
---the number of pixels to skip on the y axis for each rise. Assumes both rise
---and run are non zero.
---Returns the byte string, the width and height of the rotated image.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param rise integer rise, or step
---@param run integer run, or skip
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string skewed
---@return integer wTrg
---@return integer hTrg
function Utilities.skewPixelsXInt(
    source, wSrc, hSrc, rise, run, bpp, alphaIndex)
    ---@type string[]
    local skewed <const> = {}
    local strsub <const> = string.sub

    local absRun <const> = math.abs(run)
    local sgnRise <const> = run < 0 and -rise or rise
    local hn1Run <const> = (hSrc - 1) // absRun
    local offset <const> = sgnRise < 0 and 0 or hn1Run * sgnRise
    local wTrg <const> = wSrc + hn1Run * math.abs(sgnRise)
    local lenTrg <const> = wTrg * hSrc
    local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)

    local i = 0
    while i < lenTrg do
        local yTrg <const> = i // wTrg
        local shift <const> = sgnRise * (yTrg // absRun)
        local xSrc <const> = (i % wTrg) + shift - offset
        if xSrc >= 0 and xSrc < wSrc then
            local jbpp <const> = (yTrg * wSrc + xSrc) * bpp
            skewed[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        else
            skewed[1 + i] = alphaStr
        end
        i = i + 1
    end

    return table.concat(skewed), wTrg, hSrc
end

---Skews an image's bytes by a tangent on the y axis.
---The angle is given as a pre calculated tangent.
---Returns the byte string, the width and height of the rotated image.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param tana number tangent of angle
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string rotated
---@return integer wTrg
---@return integer hTrg
function Utilities.skewPixelsY(
    source, wSrc, hSrc, tana, bpp, alphaIndex)
    ---@type string[]
    local skewed <const> = {}
    local strsub <const> = string.sub
    local round <const> = Utilities.round

    local absTan <const> = math.abs(tana)
    local hTrgf <const> = hSrc + absTan * wSrc
    local hTrgi <const> = math.ceil(hTrgf)
    local yDiff <const> = (hSrc - hTrgf) * 0.5
    local lenTrg <const> = wSrc * hTrgi
    local xSrcCenter <const> = wSrc * 0.5
    local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)

    local i = 0
    while i < lenTrg do
        local xSrci <const> = i % wSrc
        local ySrcf <const> = yDiff + (i // wSrc)
            + tana * (xSrci - xSrcCenter)
        local ySrci <const> = round(ySrcf)
        if ySrci >= 0 and ySrci < hSrc then
            local jbpp <const> = (ySrci * wSrc + xSrci) * bpp
            skewed[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        else
            skewed[1 + i] = alphaStr
        end
        i = i + 1
    end

    return table.concat(skewed), wSrc, hTrgi
end

---Skews an image's bytes vertically by an integer rise. The run specifies
---the number of pixels to skip on the x axis for each rise. Assumes both rise
---and run are non zero.
---Returns the byte string, the width and height of the rotated image.
---@param source string source bytes
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param rise integer rise, or step
---@param run integer run, or skip
---@param bpp integer bits per pixel
---@param alphaIndex integer alpha index
---@return string skewed
---@return integer wTrg
---@return integer hTrg
function Utilities.skewPixelsYInt(
    source, wSrc, hSrc, rise, run, bpp, alphaIndex)
    ---@type string[]
    local skewed <const> = {}
    local strsub <const> = string.sub

    local absRun <const> = math.abs(run)
    local sgnRise <const> = run < 0 and -rise or rise
    local wn1Run <const> = (wSrc - 1) // absRun
    local offset <const> = sgnRise < 0 and 0 or wn1Run * sgnRise
    local hTrg <const> = hSrc + wn1Run * math.abs(sgnRise)
    local lenTrg <const> = wSrc * hTrg
    local alphaStr <const> = string.pack("<I" .. bpp, alphaIndex)

    local i = 0
    while i < lenTrg do
        local xTrg <const> = i % wSrc
        local shift <const> = sgnRise * (xTrg // absRun)
        local ySrc <const> = (i // wSrc) + shift - offset
        if ySrc >= 0 and ySrc < hSrc then
            local jbpp <const> = (ySrc * wSrc + xTrg) * bpp
            skewed[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        else
            skewed[1 + i] = alphaStr
        end
        i = i + 1
    end

    return table.concat(skewed), wSrc, hTrg
end

---Decomposes a string containing byte data into an array of integers.
---@param source string
---@return integer[]
---@nodiscard
function Utilities.stringToByteArr(source)
    ---@type integer[]
    local arr <const> = {}
    local len <const> = #source
    local strbyte <const> = string.byte
    local i = 0
    while i < len do
        i = i + 1
        arr[i] = strbyte(source, i, i)
    end
    return arr
end

---Decomposes a string to an array of characters.
---@param str string string
---@return string[]
---@nodiscard
function Utilities.stringToCharArr(str)
    ---@type string[]
    local chars <const> = {}
    local lenChars = 0
    local utf8codes <const> = utf8.codes
    local utf8char <const> = utf8.char
    for _, c in utf8codes(str) do
        lenChars = lenChars + 1
        chars[lenChars] = utf8char(c)
    end
    return chars
end

---Finds a point on the screen given a modelview, projection and 3D point.
---@param modelview Mat4 modelview
---@param projection Mat4 projection
---@param pt3 Vec3 point
---@param width number screen width
---@param height number screen height
---@return Vec3
---@nodiscard
function Utilities.toScreen(modelview, projection, pt3, width, height)
    -- Promote to homogenous coordinate.
    local pt4 <const> = Vec4.new(pt3.x, pt3.y, pt3.z, 1.0)
    local mvpt4 <const> = Utilities.mulMat4Vec4(modelview, pt4)
    local scr <const> = Utilities.mulMat4Vec4(projection, mvpt4)
    local x, y, z, w <const> = 0.0, 0.0, 0.0, scr.w

    -- Demote from homogenous coordinate.
    if w ~= 0.0 then
        local wInv <const> = 1.0 / w
        x = scr.x * wInv
        y = scr.y * wInv
        z = scr.z * wInv
    end

    -- Convert from normalized coordinates to screen dimensions. Flip y axis.
    -- Retain z coordinate for purpose of depth sort.
    x = (width - 1) * (0.5 + 0.5 * x)
    y = (height - 1) * (0.5 - 0.5 * y)
    z = 0.5 + 0.5 * z

    return Vec3.new(x, y, z)
end

---Transposes an image's bytes.
---@param source string source bytes
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.transposePixels(source, w, h, bpp)
    ---@type string[]
    local transposed <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h

    local i = 0
    while i < len do
        local j <const> = 1 + (i % w) * h + (i // w)
        local ibpp <const> = i * bpp
        transposed[j] = strsub(source, 1 + ibpp, bpp + ibpp)
        i = i + 1
    end

    return table.concat(transposed)
end

---Removes white spaces from the end, or right edge, of a table of characters.
---Mutates the table in place.
---@param chars string[] characters
---@return string[]
function Utilities.trimCharsFinal(chars)
    local tr <const> = table.remove
    while chars[#chars] == ' ' do tr(chars) end
    return chars
end

---Removes white spaces from the start, or left edge, of a table of characters.
---Mutates the table in place.
---@param chars string[] characters
---@return string[]
function Utilities.trimCharsInitial(chars)
    local tr <const> = table.remove
    while chars[1] == ' ' do tr(chars, 1) end
    return chars
end

---Finds the unique colors in a table of integers representing hexadecimal
---colors in the format AABBGGRR. When true, the flag specifies that all
---completely transparent colors are considered equal, not unique. The
---dictionary used to create the set is the second returned value.
---@param hexes integer[] color array
---@param za boolean all masks equal
---@return integer[]
---@return table<integer, integer>
function Utilities.uniqueColors(hexes, za)
    local dict <const> = Utilities.hexArrToDict(hexes, za)
    ---@type integer[]
    local uniques <const> = {}
    for k, v in pairs(dict) do uniques[v] = k end
    return uniques, dict
end

---Trims left and right ends of a string that holds a file name. Assumes file
---name does not include file extension or directory. Replaces the characters
---'\\', '/', ':', '*', '?', '"', '<', '>', '|', '.', ''' and '`' with an
---underscore, '_'.
---@param filename string file name
---@return string
---@nodiscard
function Utilities.validateFilename(filename)
    local fileChars <const> = Utilities.stringToCharArr(filename)
    Utilities.trimCharsInitial(fileChars)
    Utilities.trimCharsFinal(fileChars)
    local len <const> = #fileChars
    local i = 0
    while i < len do
        i = i + 1
        local char <const> = fileChars[i]
        if char == '\\' or char == '`'
            or char == '/' or char == ':'
            or char == '*' or char == '?'
            or char == '\"' or char == '\''
            or char == '<' or char == '>'
            or char == '|' or char == '.' then
            fileChars[i] = '_'
        end
    end
    return table.concat(fileChars)
end

---Translates an image's bytes by a vector, wrapping elements that exceed its
---dimensions back to the beginning.
---@param source string source bytes
---@param xt integer x translation
---@param yt integer y translation
---@param w integer image width
---@param h integer image height
---@param bpp integer bits per pixel
---@return string
---@nodiscard
function Utilities.wrapPixels(source, xt, yt, w, h, bpp)
    ---@type string[]
    local wrapped <const> = {}
    local strsub <const> = string.sub
    local len <const> = w * h

    local i = 0
    while i < len do
        local xShift <const> = (i % w - xt) % w
        local yShift <const> = (i // w + yt) % h
        local jbpp <const> = (yShift * w + xShift) * bpp
        wrapped[1 + i] = strsub(source, 1 + jbpp, bpp + jbpp)
        i = i + 1
    end

    return table.concat(wrapped)
end

return Utilities