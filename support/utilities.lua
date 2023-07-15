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

---Look up table of linear to standard
---color space conversion.
Utilities.LTS_LUT = {
    0, 13, 22, 28, 34, 38, 42, 46, 50, 53, 56, 59, 61, 64, 66, 69,
    71, 73, 75, 77, 79, 81, 83, 85, 86, 88, 90, 92, 93, 95, 96, 98,
    99, 101, 102, 104, 105, 106, 108, 109, 110, 112, 113, 114, 115, 117, 118, 119,
    120, 121, 122, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136,
    137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 148, 149, 150, 151,
    152, 153, 154, 155, 155, 156, 157, 158, 159, 159, 160, 161, 162, 163, 163, 164,
    165, 166, 167, 167, 168, 169, 170, 170, 171, 172, 173, 173, 174, 175, 175, 176,
    177, 178, 178, 179, 180, 180, 181, 182, 182, 183, 184, 185, 185, 186, 187, 187,
    188, 189, 189, 190, 190, 191, 192, 192, 193, 194, 194, 195, 196, 196, 197, 197,
    198, 199, 199, 200, 200, 201, 202, 202, 203, 203, 204, 205, 205, 206, 206, 207,
    208, 208, 209, 209, 210, 210, 211, 212, 212, 213, 213, 214, 214, 215, 215, 216,
    216, 217, 218, 218, 219, 219, 220, 220, 221, 221, 222, 222, 223, 223, 224, 224,
    225, 226, 226, 227, 227, 228, 228, 229, 229, 230, 230, 231, 231, 232, 232, 233,
    233, 234, 234, 235, 235, 236, 236, 237, 237, 238, 238, 238, 239, 239, 240, 240,
    241, 241, 242, 242, 243, 243, 244, 244, 245, 245, 246, 246, 246, 247, 247, 248,
    248, 249, 249, 250, 250, 251, 251, 251, 252, 252, 253, 253, 254, 254, 255, 255
}

---Look up table of standard to linear
---color space conversion.
Utilities.STL_LUT = {
    0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7,
    8, 8, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 13,
    13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 17, 18, 18, 19, 19, 20,
    20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 27, 27, 28, 29, 29,
    30, 30, 31, 32, 32, 33, 34, 35, 35, 36, 37, 37, 38, 39, 40, 41,
    41, 42, 43, 44, 45, 45, 46, 47, 48, 49, 50, 51, 51, 52, 53, 54,
    55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    71, 72, 73, 74, 76, 77, 78, 79, 80, 81, 82, 84, 85, 86, 87, 88,
    90, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105, 107, 108, 109,
    111, 112, 114, 115, 116, 118, 119, 121, 122, 124, 125, 127, 128, 130, 131, 133,
    134, 136, 138, 139, 141, 142, 144, 146, 147, 149, 151, 152, 154, 156, 157, 159,
    161, 163, 164, 166, 168, 170, 171, 173, 175, 177, 179, 181, 183, 184, 186, 188,
    190, 192, 194, 196, 198, 200, 202, 204, 206, 208, 210, 212, 214, 216, 218, 220,
    222, 224, 226, 229, 231, 233, 235, 237, 239, 242, 244, 246, 248, 250, 253, 255
}

---Houses utility methods not included in Lua.
---@return table
function Utilities.new()
    local inst = setmetatable({}, Utilities)
    return inst
end

---Bisects an array of elements to find
---the appropriate index. Biases towards the right
---insert point. Should be used with sorted arrays.
---@generic T array type
---@generic U element type
---@param arr T[] array
---@param elm U query
---@param compare fun(a: U, b: T): boolean comparator
---@return integer
function Utilities.bisectRight(arr, elm, compare)
    local low = 0
    local high = #arr
    if high < 1 then return 1 end
    while low < high do
        local middle = (low + high) // 2
        local right = arr[1 + middle]
        if right and compare(elm, right) then
            high = middle
        else
            low = middle + 1
        end
    end
    return 1 + low
end

---Converts a dictionary to a sorted set.
---If a comparator is not provided, elements
---are sorted by their less than (<) operator.
---@generic K key
---@generic V value
---@param dict table<K, V> dictionary
---@param comp? fun(a: K, b: K): boolean
---@return K[]
function Utilities.dictToSortedSet(dict, comp)
    local orderedSet = {}
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
function Utilities.flatArr2(arr2)
    local flat = {}
    local lenOuter = #arr2
    local i = 0
    while i < lenOuter do
        i = i + 1
        local arr1 = arr2[i]
        local lenInner = #arr1
        local j = 0
        while j < lenInner do
            j = j + 1
            flat[#flat + 1] = arr1[j]
        end
    end
    return flat
end

---Flips a source pixel array horizontally.
---Changes the array in-place.
---@param source integer[] source pixels
---@param w integer image width
---@param h integer image height
---@return integer[]
function Utilities.flipPixelsHoriz(source, w, h)
    local wd2 = w // 2
    local wn1 = w - 1
    local len = wd2 * h
    local k = 0
    while k < len do
        local x = k % wd2
        local yw = w * (k // wd2)
        local idxSrc = 1 + x + yw
        local idxTrg = 1 + yw + wn1 - x
        local swap = source[idxSrc]
        source[idxSrc] = source[idxTrg]
        source[idxTrg] = swap
        k = k + 1
    end
    return source
end

---Flips a source pixel array vertically.
---Changes the array in-place.
---@param source integer[] source pixels
---@param w integer image width
---@param h integer image height
---@return integer[]
function Utilities.flipPixelsVert(source, w, h)
    local hd2 = h // 2
    local hn1 = h - 1
    local len = w * hd2
    local k = 0
    while k < len do
        local idxSrc = 1 + k
        local idxTrg = 1 + k % w
            + w * (hn1 - k // w)
        local swap = source[idxSrc]
        source[idxSrc] = source[idxTrg]
        source[idxTrg] = swap
        k = k + 1
    end
    return source
end

---Generates a random number with normal distribution.
---Based on the Box-Muller transform as described here:
---https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform
---@param sigma number? scalar
---@param mu number? offset
---@return number
function Utilities.gaussian(sigma, mu)
    local m = mu or 0.0
    local s = sigma or 1.0

    local u1 = 0.0
    repeat
        u1 = math.random()
    until (u1 > 0.000001)
    local u2 = math.random()

    local r = s * math.sqrt(-2.0 * math.log(u1))
    local x = r * math.cos(6.2831853071796 * u2) + m
    -- local y = r * math.sin(6.2831853071796 * u2) + m
    return x
end

---Finds the greatest common denominator
---between two positive integers.
---@param a integer antecedent term
---@param b integer consequent term
---@return integer
function Utilities.gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

---Converts an array of integers representing color
---in hexadecimal to a dictionary. The value in each
---entry is the first index where the color was found.
---When true, the flag specifies that all completely
---transparent colors are considered equal, not unique.
---@param hexes integer[] hexadecimal colors
---@param za boolean zero alpha
---@return table<integer, integer>
function Utilities.hexArrToDict(hexes, za)
    ---@type table<integer, integer>
    local dict = {}
    local lenHexes = #hexes
    local idxRead = 0
    local idxValue = 0
    while idxRead < lenHexes do
        idxRead = idxRead + 1
        local hex = hexes[idxRead]

        if za then
            local a = (hex >> 0x18) & 0xff
            if a < 1 then hex = 0x0 end
        end

        if not dict[hex] then
            idxValue = idxValue + 1
            dict[hex] = idxValue
        end
    end
    return dict
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the counter-clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleCcw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    if diff == 0.0 then return o end

    local u = 1.0 - t
    if o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the clockwise angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleCw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    if diff == 0.0 then return d end

    local u = 1.0 - t
    if o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the furthest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleFar(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 or (o < d and diff < halfRange) then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff > -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Unclamped linear interpolation from an origin angle
---to a destination by a factor, t, in [0.0, 1.0].
---The range defaults to 360.0 for degrees, but can be
---math.pi * 2.0 for radians.
---Uses the nearest angular direction.
---@param origin number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number range
---@return number
function Utilities.lerpAngleNear(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    if diff == 0.0 then return o end

    local u = 1.0 - t
    local halfRange = valRange * 0.5
    if o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Multiplies a Mat3 with a Curve2.
---Changes the curve in place.
---@param a Mat3 matrix
---@param b Curve2 curve
---@return Curve2
function Utilities.mulMat3Curve2(a, b)
    local kns = b.knots
    local knsLen = #kns
    local i = 0
    -- Knot is changed in place.
    while i < knsLen do
        i = i + 1
        Utilities.mulMat3Knot2(a, kns[i])
    end
    return b
end

---Multiplies a Mat3 with a Knot2.
---Changes the knot in place.
---@param a Mat3 matrix
---@param b Knot2 knot
---@return Knot2
function Utilities.mulMat3Knot2(a, b)
    b.co = Utilities.mulMat3Point2(a, b.co)
    b.fh = Utilities.mulMat3Point2(a, b.fh)
    b.rh = Utilities.mulMat3Point2(a, b.rh)
    return b
end

---Multiplies a Mat3 with a Mesh2.
---Changes the mesh in place.
---@param a Mat3 matrix
---@param b Mesh2 mesh
---@return Mesh2
function Utilities.mulMat3Mesh2(a, b)
    local vs = b.vs
    local vsLen = #vs
    local i = 0
    while i < vsLen do
        i = i + 1
        vs[i] = Utilities.mulMat3Point2(a, vs[i])
    end
    return b
end

---Multiplies a Mat3 with a Vec2.
---The vector is treated as a point.
---@param a Mat3 matrix
---@param b Vec2 vector
---@return Vec2
function Utilities.mulMat3Point2(a, b)
    local w = a.m20 * b.x + a.m21 * b.y + a.m22
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec2.new(
            (a.m00 * b.x + a.m01 * b.y + a.m02) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m12) * wInv)
    else
        return Vec2.new(0.0, 0.0)
    end
end

---Multiplies a Mat4 with a Curve3.
---Changes the curve in place.
---@param a Mat4 matrix
---@param b Curve3 curve
---@return Curve3
function Utilities.mulMat4Curve3(a, b)
    local kns = b.knots
    local knsLen = #kns
    local i = 0
    -- Knot is changed in place.
    while i < knsLen do
        i = i + 1
        Utilities.mulMat4Knot3(a, kns[i])
    end
    return b
end

---Multiplies a Mat4 with a Knot3.
---Changes the knot in place.
---@param a Mat4 matrix
---@param b Knot3 knot
---@return Knot3
function Utilities.mulMat4Knot3(a, b)
    b.co = Utilities.mulMat4Point3(a, b.co)
    b.fh = Utilities.mulMat4Point3(a, b.fh)
    b.rh = Utilities.mulMat4Point3(a, b.rh)
    return b
end

---Multiplies a Mat4 with a Vec3.
---The vector is treated as a point.
---@param a Mat4 matrix
---@param b Vec3 vector
---@return Vec3
function Utilities.mulMat4Point3(a, b)
    local w = a.m30 * b.x + a.m31 * b.y + a.m33
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec3.new(
            (a.m00 * b.x + a.m01 * b.y + a.m03) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m13) * wInv,
            (a.m20 * b.x + a.m21 * b.y + a.m23) * wInv)
    end
    return Vec3.new(0.0, 0.0, 0.0)
end

---Multiplies a Mat4 with a Vec4.
---@param a Mat4 matrix
---@param b Vec4 vector
---@return Vec4
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

---Finds the next power of 2 for a signed
---integer, i.e., multiplies the next power
---by the integer's sign. Returns zero
---if input is equal to zero.
---@param x integer input value
---@return integer
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

---Parses a string of integers separated
---by a comma. The integers may either be individual
---or ranges connected by a colon. For example,
---"1,5,10:15,7".
---
---Supplying the frame count ensures the range is not
---out of bounds. Defaults to an arbitrary large number.
---
---Returns an array of arrays. Inner arrays can hold
---duplicate frame indices,  as the user may intend for
---the same frame to appear in multiple groups.
---@param s string range string
---@param frameCount integer? number of frames
---@param offset integer? offset
---@return integer[][]
function Utilities.parseRangeStringOverlap(s, frameCount, offset)
    local offVerif = offset or 0
    local fcVerif = frameCount or 2147483647
    local strgmatch = string.gmatch

    -- Parse string by comma.
    ---@type integer[][]
    local arrOuter = {}
    local idxOuter = 0
    for token in strgmatch(s, "([^,]+)") do
        -- Parse string by hyphen.
        ---@type integer[]
        local edges = {}
        local idxEdges = 0
        for subtoken in strgmatch(token, "[^:]+") do
            local trial = tonumber(subtoken, 10)
            if trial then
                -- print(string.format("trial: %d", trial))
                idxEdges = idxEdges + 1
                edges[idxEdges] = trial - offVerif
            end
        end

        ---@type integer[]
        local arrInner = {}
        local idxInner = 0
        local lenEdges = #edges
        if lenEdges > 1 then
            -- print("lenEdges > 1")
            local origIdx = edges[1]
            local destIdx = edges[lenEdges]

            -- Edges of a range should be clamped to valid.
            origIdx = math.min(math.max(origIdx, 1), fcVerif)
            destIdx = math.min(math.max(destIdx, 1), fcVerif)

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
                idxInner = idxInner + 1
                arrInner[idxInner] = destIdx
                -- print("destIdx == origIdx")
                -- print(destIdx)
            end
        elseif lenEdges > 0 then
            -- Filter out unique numbers if invalid,
            -- don't bother to clamp them.
            local trial = edges[1]
            if trial >= 1
                and trial <= fcVerif then
                idxInner = idxInner + 1
                arrInner[idxInner] = edges[1]
                -- print("lenEdges > 0")
                -- print(edges[1])
            end
        end

        idxOuter = idxOuter + 1
        arrOuter[idxOuter] = arrInner
    end

    return arrOuter
end

---Parses a string of integers separated
---by a comma. The integers may either be individual
---or ranges connected by a hyphen. For example,
---"1,5,10:15,7".
---
---Supplying the frame count ensures the range is not
---out of bounds. Defaults to an arbitrary large number.
---
---Returns an ordered set of integers.
---@param s string range string
---@param frameCount integer? number of frames
---@param offset integer? offset
---@return integer[]
function Utilities.parseRangeStringUnique(s, frameCount, offset)
    local arr2 = Utilities.parseRangeStringOverlap(
        s, frameCount, offset)

    -- Convert 2D array to a dictionary.
    -- Use dummy true, not some idx scheme,
    -- because natural ordering is preferred.
    ---@type table<integer, boolean>
    local dict = {}
    local lenArr2 = #arr2
    local i = 0
    while i < lenArr2 do
        i = i + 1
        local arr1 = arr2[i]
        local lenArr1 = #arr1
        local j = 0
        while j < lenArr1 do
            j = j + 1
            dict[arr1[j]] = true
        end
    end

    return Utilities.dictToSortedSet(dict, nil)
end

---Prepends an alpha mask to a table of
---hexadecimal integers representing color.
---If the table already includes a mask,
---the input table is returned unchanged.
---If it contains a mask at another index,
---it is removed and placed at the start.
---Colors with zero alpha are not considered
---equal to an alpha mask.
---@param hexes integer[] colors
---@return integer[]
function Utilities.prependMask(hexes)
    if hexes[1] == 0x0 then return hexes end
    local cDict = Utilities.hexArrToDict(hexes, false)
    local maskIdx = cDict[0x0]
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

---Promotes a Vec2 to a Vec3.
---The z component defaults to 0.0.
---@param a Vec2 vector
---@param z number? z component
---@return Vec3
function Utilities.promoteVec2ToVec3(a, z)
    local vz = z or 0.0
    return Vec3.new(a.x, a.y, vz)
end

---Quantizes a signed number according
---to a number of levels. The quantization
---is centered about the range.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantizeSigned(a, levels)
    if levels ~= 0 then
        return Utilities.quantizeSignedInternal(
            a, levels, 1.0 / levels)
    end
    return a
end

---Quantizes a signed number according
---to a number of levels. The quantization
---is centered about the range.
---Internal helper function. Assumes that
---delta has been calculated as 1 / levels.
---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
function Utilities.quantizeSignedInternal(a, levels, delta)
    return math.floor(0.5 + a * levels) * delta
end

---Quantizes an unsigned number according
---to a number of levels. The quantization
---is based on the left edge.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantizeUnsigned(a, levels)
    if levels > 1 then
        return Utilities.quantizeUnsignedInternal(
            a, levels, 1.0 / (levels - 1.0))
    end
    return math.max(0.0, a)
end

---Quantizes an unsigned number according
---to a number of levels. The quantization
---is based on the left edge.
---Internal helper function. Assumes that
---delta has been calculated as 1 / (levels - 1).
---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
function Utilities.quantizeUnsignedInternal(a, levels, delta)
    return math.max(0.0,
        (math.ceil(a * levels) - 1.0) * delta)
end

---Reduces a ratio of positive integers
---to their smallest terms through division
---by their greatest common denominator.
---@param a integer antecedent term
---@param b integer consequent term
---@return integer
---@return integer
function Utilities.reduceRatio(a, b)
    local denom = Utilities.gcd(a, b)
    return a // denom, b // denom
end

---Resizes a source pixel array to new dimensions with
---nearest neighbor sampling. Performs no validation on
---target width or height. Creates a new pixel array.
---@param source integer[] source pixels
---@param wSrc integer original width
---@param hSrc integer original height
---@param wTrg integer resized width
---@param hTrg integer resized height
---@return integer[]
function Utilities.resizePixelsNearest(source, wSrc, hSrc, wTrg, hTrg)
    local floor = math.floor
    local tx = wSrc / wTrg
    local ty = hSrc / hTrg
    local len = wTrg * hTrg
    ---@type integer[]
    local target = {}
    local i = 0
    while i < len do
        local nx = floor((i % wTrg) * tx)
        local ny = floor((i // wTrg) * ty)
        i = i + 1
        target[i] = source[1 + ny * wSrc + nx]
    end
    return target
end

---Reverses a table used as an array.
---Useful for rotating an array of pixels 180 degrees.
---Changes the table in place.
---@generic T element
---@param t T[] input table
---@return T[]
function Utilities.reverseTable(t)
    -- https://programming-idioms.org/
    -- idiom/19/reverse-a-list/1314/lua
    local n = #t
    local i = 1
    while i < n do
        t[i], t[n] = t[n], t[i]
        -- These should stay as post-increment,
        -- otherwise a table of len 2 won't flip.
        i = i + 1
        n = n - 1
    end
    return t
end

---Rounds a number to an integer based on its relationship to
---0.5. Returns zero when the number cannot be determined
---to be either greater than or less than zero.
---@param x number real number
---@return integer
function Utilities.round(x)
    -- math.tointeger(-0.000001) = -1, so modf must be used.
    local ix, fx = math.modf(x)
    if ix <= 0 and fx <= -0.5 then
        return ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        return ix + 1
    end
    return ix
end

---Creates a new table from the source
---and shuffles it.
---@generic T element
---@param t T[] input table
---@return T[]
function Utilities.shuffle(t)
    -- https://stackoverflow.com/a/68486276
    local rng = math.random
    local s = {}

    local len = #t
    local h = 0
    while h < len do
        h = h + 1
        s[h] = t[h]
    end

    local i = len + 1
    while i > 2 do
        i = i - 1
        local j = rng(i)
        s[i], s[j] = s[j], s[i]
    end

    return s
end

---Converts a string to a table of characters.
---@param str string string
---@return string[]
function Utilities.stringToCharTable(str)
    -- For more on different methods, see
    -- https://stackoverflow.com/a/49222705
    local chars = {}
    local strsub = string.sub
    local lenStr = #str
    local i = 0
    while i < lenStr do
        i = i + 1
        chars[i] = strsub(str, i, i)
    end
    return chars
end

---Approximates a real number with a ratio of integers.
---Cycles determines the maximum iterations to search.
---Precision determines an early exit from the search.
---Returns a tuple with the antecedent and consequent.
---@param num number real number
---@param itrs integer? iterations
---@param precision number? precision
---@return integer
---@return integer
function Utilities.toRatio(num, itrs, precision)
    local sgnNum = 0
    if num == 0.0 then return 0, 0 end
    if num > 0.0 then sgnNum = 1 end
    if num < -0.0 then sgnNum = -1 end

    local cVerif = itrs or 10
    local pVerif = precision or 5e-4
    cVerif = math.max(1, math.abs(cVerif))
    pVerif = math.max(1e-10, math.abs(pVerif))

    local absNum = math.abs(num)
    local integer, fraction = math.modf(absNum)

    local a0 = integer
    local a1 = 1
    local b0 = 1
    local b1 = 0

    local counter = 0
    while fraction > pVerif and counter < cVerif do
        local newNum = 1.0 / fraction
        integer, fraction = math.modf(newNum)
        local t0 = a0
        a0 = integer * a0 + b0
        b0 = t0
        local t1 = a1
        a1 = integer * a1 + b1
        b1 = t1
        counter = counter + 1
    end

    return sgnNum * a0, a1
end

---Finds a point on the screen given a modelview,
---projection and 3D point.
---@param modelview Mat4 modelview
---@param projection Mat4 projection
---@param pt3 Vec3 point
---@param width number screen width
---@param height number screen height
---@return Vec3
function Utilities.toScreen(modelview, projection, pt3, width, height)
    -- Promote to homogenous coordinate.
    local pt4 = Vec4.new(pt3.x, pt3.y, pt3.z, 1.0)
    local mvpt4 = Utilities.mulMat4Vec4(modelview, pt4)
    local scr = Utilities.mulMat4Vec4(projection, mvpt4)

    local w = scr.w
    local x = scr.x
    local y = scr.y
    local z = scr.z

    -- Demote from homogenous coordinate.
    if w ~= 0.0 then
        local wInv = 1.0 / w
        x = x * wInv
        y = y * wInv
        z = z * wInv
    else
        return Vec3.new(0.0, 0.0, 0.0)
    end

    -- Convert from normalized coordinates to
    -- screen dimensions. Flip y axis. Retain
    -- z coordinate for purpose of depth sort.
    x = (width - 1) * (0.5 + 0.5 * x)
    y = (height - 1) * (0.5 - 0.5 * y)
    z = 0.5 + 0.5 * z

    return Vec3.new(x, y, z)
end

---Removes white spaces from the end,
---or right edge, of a table of characters.
---Mutates the table in place.
---@param chars string[] characters
---@return string[]
function Utilities.trimCharsFinal(chars)
    local tr = table.remove
    while chars[#chars] == ' ' do tr(chars) end
    return chars
end

---Removes white spaces from the start,
---or left edge, of a table of characters.
---Mutates the table in place.
---@param chars string[] characters
---@return string[]
function Utilities.trimCharsInitial(chars)
    local tr = table.remove
    while chars[1] == ' ' do tr(chars, 1) end
    return chars
end

---Finds the unique colors in a table of integers
---representing hexadecimal colors in the format
---AABBGGRR. When true, the flag specifies that all
---completely transparent colors are considered
---equal, not unique. The dictionary used to
---create the set is the second returned value.
---@param hexes integer[] color array
---@param za boolean all masks equal
---@return integer[]
---@return table<integer, integer>
function Utilities.uniqueColors(hexes, za)
    local dict = Utilities.hexArrToDict(hexes, za)
    ---@type integer[]
    local uniques = {}
    for k, v in pairs(dict) do
        uniques[v] = k
    end
    return uniques, dict
end

---Trims left and right ends of a string that
---holds a file name. Assumes file name does
---not include file extension or directory.
---Replaces the characters '\\', '/', ':',
---'*', '?', '"', '<', '>', '|', '.', '''
---and '`' with an underscore, '_'.
---@param filename string file name
---@return string
function Utilities.validateFilename(filename)
    local fileChars = Utilities.stringToCharTable(filename)
    Utilities.trimCharsInitial(fileChars)
    Utilities.trimCharsFinal(fileChars)
    local len = #fileChars
    local i = 0
    while i < len do
        i = i + 1
        local char = fileChars[i]
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

---Translates the elements in a pixel array by a vector,
---wrapping the elements that exceed its dimensions back
---to the beginning.
---@param source integer[] source pixels
---@param x integer x translation
---@param y integer y translation
---@param w integer image width
---@param h integer image height
---@return integer[]
function Utilities.wrapPixels(source, x, y, w, h)
    local len = #source
    local wrapped = {}
    local i = 0
    while i < len do
        local xSrc = ((i % w) - x) % w
        local ySrc = ((i // w) + y) % h
        i = i + 1
        wrapped[i] = source[1 + xSrc + ySrc * w]
    end
    return wrapped
end

return Utilities