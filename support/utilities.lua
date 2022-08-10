dofile("./vec2.lua")
dofile("./vec3.lua")
dofile("./vec4.lua")
dofile("./bounds2.lua")
dofile("./curve2.lua")
dofile("./mat3.lua")
dofile("./mat4.lua")
dofile("./mesh2.lua")
dofile("./quaternion.lua")
dofile("./glyph.lua")

Utilities = {}
Utilities.__index = Utilities

setmetatable(Utilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Glyph look up table. Glyphs occupy
---an 8 x 8 grid, where 1 represents
---a mark and 0 represents empty.
Utilities.GLYPH_LUT = {
    [' '] = Glyph.new(' ', 0, 0),
    ['!'] = Glyph.new('!', 1736164113350932496, 0),
    ['"'] = Glyph.new('"', 2893606741050654720, 0),
    ['#'] = Glyph.new('#', 11395512391958528, 0),
    ['$'] = Glyph.new('$', 1169898204994762768, 0),
    ['%'] = Glyph.new('%', 8981488584378098978, 0),
    ['&'] = Glyph.new('&', 4053310240682034232, 0),
    ['\''] = Glyph.new('\'', 1731642852816977920, 0),
    ['('] = Glyph.new('(', 2323928052423213088, 0),
    [')'] = Glyph.new(')', 288795533752009220, 0),
    ['*'] = Glyph.new('*', 4596200532606976, 0),
    ['+'] = Glyph.new('+', 4521724658843648, 0),
    [','] = Glyph.new(',', 1574920, 0),
    ['-'] = Glyph.new('-', 532575944704, 0),
    ['.'] = Glyph.new('.', 1579008, 0),
    ['/'] = Glyph.new('/', 289365106780807200, 0),

    ['0'] = Glyph.new('0', 1739555093715621888, 0),
    ['1'] = Glyph.new('1', 583224982331988992, 0),
    ['2'] = Glyph.new('2', 4324586061027097600, 0),
    ['3'] = Glyph.new('3', 4036355804662872064, 0),
    ['4'] = Glyph.new('4', 2604246324710999040, 0),
    ['5'] = Glyph.new('5', 4332498283667929088, 0),
    ['6'] = Glyph.new('6', 1738424881661614080, 0),
    ['7'] = Glyph.new('7', 4324585974724038656, 0),
    ['8'] = Glyph.new('8', 1739555042176014336, 0),
    ['9'] = Glyph.new('9', 1739555058816915456, 0),
    [':'] = Glyph.new(':', 26491359860736, 0),
    [';'] = Glyph.new(';', 26491359860744, 0),
    ['<'] = Glyph.new('<', 580999811718711296, 0),
    ['='] = Glyph.new('=', 136341522219008, 0),
    ['>'] = Glyph.new('>', 1155177711124615168, 0),
    ['?'] = Glyph.new('?', 4054440365960200208, 0),

    ['@'] = Glyph.new('@', 4342201927465582652, 0),
    ['A'] = Glyph.new('A', 1164255564608586752, 0),
    ['B'] = Glyph.new('B', 8666126866299779072, 0),
    ['C'] = Glyph.new('C', 4341540685485194240, 0),
    ['D'] = Glyph.new('D', 8666126642961479680, 0),
    ['E'] = Glyph.new('E', 4332498266959657984, 0),
    ['F'] = Glyph.new('F', 4332498266959650816, 0),
    ['G'] = Glyph.new('G', 4053310360940460032, 0),
    ['H'] = Glyph.new('H', 4919131993507382272, 0),
    ['I'] = Glyph.new('I', 4039746526926354432, 0),
    ['J'] = Glyph.new('J', 4325716272676876288, 0),
    ['K'] = Glyph.new('K', 4920270967496262656, 0),
    ['L'] = Glyph.new('L', 2314885530818460672, 0),
    ['M'] = Glyph.new('M', -9023337257158671872, 0),
    ['N'] = Glyph.new('N', 4783476233180692992, 0),
    ['O'] = Glyph.new('O', 4342105843085491200, 0),

    ['P'] = Glyph.new('P', 8666126866232393728, 0),
    ['Q'] = Glyph.new('Q', 4342105843086015496, 0),
    ['R'] = Glyph.new('R', 8666126866501354496, 0),
    ['S'] = Glyph.new('S', 4341540650114906112, 0),
    ['T'] = Glyph.new('T', 8939662921505443840, 0),
    ['U'] = Glyph.new('U', 4919131752989211648, 0),
    ['V'] = Glyph.new('V', 4919131752987365376, 0),
    ['W'] = Glyph.new('W', -7885078839348148224, 0),
    ['X'] = Glyph.new('X', 4919100742855574528, 0),
    ['Y'] = Glyph.new('Y', 4919131631854292992, 0),
    ['Z'] = Glyph.new('Z', 9097838629918768640, 0),
    ['['] = Glyph.new('[', 8088535575457448048, 0),
    ['\\'] = Glyph.new('\\', 2314867869508699140, 0),
    [']'] = Glyph.new(']', 1009371474131288590, 0),
    ['^'] = Glyph.new('^', 1164255270465961984, 0),
    ['_'] = Glyph.new('_', 126, 0),

    ['`'] = Glyph.new('`', 2314867869373956096, 0),
    ['a'] = Glyph.new('a', 26405931072512, 0),
    ['b'] = Glyph.new('b', 2314885633965045760, 0),
    ['c'] = Glyph.new('c', 26543437125632, 0),
    ['d'] = Glyph.new('d', 289360794970496000, 0),
    ['e'] = Glyph.new('e', 26543839517696, 0),
    ['f'] = Glyph.new('f', 869212561056206848, 0),
    ['g'] = Glyph.new('g', 1883670230183986232, 2),
    ['h'] = Glyph.new('h', 2314885633965040640, 0),
    ['i'] = Glyph.new('i', 4503806055299072, 0),
    ['j'] = Glyph.new('j', 576469582890936336, 1),
    ['k'] = Glyph.new('k', 2314885565447153664, 0),
    ['l'] = Glyph.new('l', 1157442765409224704, 0),
    ['m'] = Glyph.new('m', 57493678606848, 0),
    ['n'] = Glyph.new('n', 61727876326400, 0),
    ['o'] = Glyph.new('o', 26543504234496, 0),

    ['p'] = Glyph.new('p', 1739555179547598848, 2),
    ['q'] = Glyph.new('q', 1883670229782905404, 2),
    ['r'] = Glyph.new('r', 26543436865536, 0),
    ['s'] = Glyph.new('s', 26526120949760, 0),
    ['t'] = Glyph.new('t', 4569639314000896, 0),
    ['u'] = Glyph.new('u', 39737643768832, 0),
    ['v'] = Glyph.new('v', 48550984028160, 0),
    ['w'] = Glyph.new('w', 161158224168960, 0),
    ['x'] = Glyph.new('x', 44152534870016, 0),
    ['y'] = Glyph.new('y', 10172836669032464, 1),
    ['z'] = Glyph.new('z', 30941079675960, 0),
    ['{'] = Glyph.new('{', 1738424915953983512, 0),
    ['|'] = Glyph.new('|', 1157442765409226768, 0),
    ['}'] = Glyph.new('}', 6922050254083723360, 0),
    ['~'] = Glyph.new('~', 7248543600252813312, 0)
}

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

---Converts a dictionary to a sorted set.
---If a comparator is not provided, elements
---are sorted by their less than (<) operator.
---@param dict table dictionary
---@param comparator function|nil comparator function
---@return table
function Utilities.dictToSortedSet(dict, comparator)
    local orderedSet = {}
    local osCursor = 0
    for k, _ in pairs(dict) do
        osCursor = osCursor + 1
        orderedSet[osCursor] = k
    end
    -- Sort handles nil comparator function.
    table.sort(orderedSet, comparator)
    return orderedSet
end

---Finds the unsigned distance between two angles.
---The range defaults to 360.0 for degrees, but can
---be math.pi * 2.0 for radians.
---@param a number left operand
---@param b number right operand
---@param range number range
---@return number
function Utilities.distAngleUnsigned(a, b, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5
    return halfRange - math.abs(math.abs(
        (b % valRange) - (a % valRange))
        - halfRange)
end

---Flips a source pixel array horizontally.
---Changes the array in-place.
---@param source table source pixels
---@param w integer image width
---@param h integer image height
---@return table
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
---@param source table source pixels
---@param w integer image width
---@param h integer image height
---@return table
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
---@param hexes table hexadecimal colors
---@param za boolean zero alpha
---@return table
function Utilities.hexArrToDict(hexes, za)
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

---Forces an overflow wrap to make 64 bit
---integers behave like 32 bit integers.
---@param x integer the integer
---@return integer
function Utilities.int32Overflow(x)
    -- https://stackoverflow.com/questions/
    -- 300840/force-php-integer-overflow
    local y = x & 0xffffffff
    if y & 0x80000000 then
        return -((~y & 0xffffffff) + 1)
    else
        return y
    end
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
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
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
    local u = 1.0 - t

    if diff == 0.0 then
        return d
    elseif o < d then
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
    local halfRange = valRange * 0.5
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---Breaks a long string into multiple lines according
---to a character-per-line limit. The limit should be
---in the range 16 to 120. The delimiter inserted into
---a string is '\n'.
---@param srcStr string source string
---@param limit integer|nil character limit per line
---@return string
function Utilities.lineWrapString(srcStr, limit)
    local chars2d = Utilities.lineWrapStringToChars(
        srcStr, limit)
    local len2d = #chars2d
    local i = 0
    local strArrs = {}
    local concat = table.concat
    while i < len2d do
        i = i + 1
        strArrs[i] = concat(chars2d[i])
    end
    return concat(strArrs, '\n')
end

---Breaks a long string into multiple lines according
---to a character-per-line limit. The limit should be
---in the range 16 to 120. Tries to find the last space
---to use as a breaking point; breaks by character for
---low limits or long words. Returns a table of tables;
---each inner table contains characters representing a
---line of text. Tabs are treated as spaces.
---@param srcStr string source string
---@param limit integer|nil character limit per line
---@return table
function Utilities.lineWrapStringToChars(srcStr, limit)
    if srcStr and #srcStr > 0 then

        local insert = table.insert
        local remove = table.remove
        local trimLeft = Utilities.trimCharsInitial
        local trimRight = Utilities.trimCharsFinal

        local valLimit = limit or 80
        if valLimit < 16 then valLimit = 16 end
        if valLimit > 120 then valLimit = 120 end

        local charTally = 0
        local result = {}
        local currLine = {}
        local lastSpace = 0

        local flatChars = Utilities.stringToCharTable(srcStr)
        local flatCharLen = #flatChars
        local prevChar = flatChars[flatCharLen]

        local i = 0
        while i < flatCharLen do i = i + 1
            local currChar = flatChars[i]
            if currChar == '\n' or currChar == '\r' then
                if #currLine < 1 then currLine = { '' } end
                insert(result, currLine)
                currLine = {}
                charTally = 0
                lastSpace = 0
            else
                insert(currLine, currChar)
                local currLnLen = #currLine

                if currChar == ' '
                    or currChar == '\t' then
                    lastSpace = #currLine
                elseif currChar == '-'
                    and prevChar == '-' then
                    -- Handle case where double hyphen is used as
                    -- a substitute for em dash.
                    lastSpace = #currLine + 1
                end

                if charTally < valLimit then
                    charTally = charTally + 1
                else
                    -- Trace back to last space.
                    -- The greater than half the char length condition
                    -- is to handle problematic words like
                    -- "supercalifragilisticexpialidocious".
                    local excess = {}
                    if lastSpace > 0 and lastSpace > currLnLen // 2 then
                        local j = currLnLen + 1
                        while j > lastSpace do j = j - 1
                            insert(excess, 1, remove(currLine, j))
                        end
                    end

                    trimLeft(excess)

                    trimRight(currLine)
                    trimLeft(currLine)

                    -- Append current line, create new one.
                    if #currLine < 1 then currLine = { '' } end
                    insert(result, currLine)
                    currLine = {}
                    charTally = 0
                    lastSpace = 0

                    -- Consume excess.
                    local excLen = #excess
                    while charTally < excLen do
                        charTally = charTally + 1
                        insert(currLine, excess[charTally])
                    end
                end
            end
            prevChar = currChar
        end

        -- Consume remaining lines.
        if #currLine > 0 then
            insert(result, currLine)
        end

        return result
    else
        return { { '' } }
    end
end

---Multiplies a matrix with a 2D curve.
---Changes the curve in place.
---@param a table matrix
---@param b table curve
---@return table
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

---Multiplies a matrix with a 2D knot.
---Changes the knot in place.
---@param a table matrix
---@param b table knot
---@return table
function Utilities.mulMat3Knot2(a, b)
    b.co = Utilities.mulMat3Point2(a, b.co)
    b.fh = Utilities.mulMat3Point2(a, b.fh)
    b.rh = Utilities.mulMat3Point2(a, b.rh)
    return b
end

---Multiplies a matrix with a 2D mesh.
---Changes the mesh in place.
---@param a table matrix
---@param b table mesh
---@return table
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
---@param a table matrix
---@param b table vector
---@return table
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

---Multiplies a matrix with a 3D curve.
---Changes the curve in place.
---@param a table matrix
---@param b table curve
---@return table
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

---Multiplies a matrix with a 3D knot.
---Changes the knot in place.
---@param a table matrix
---@param b table knot
---@return table
function Utilities.mulMat4Knot3(a, b)
    b.co = Utilities.mulMat4Point3(a, b.co)
    b.fh = Utilities.mulMat4Point3(a, b.fh)
    b.rh = Utilities.mulMat4Point3(a, b.rh)
    return b
end

---Multiplies a Mat4 with a Vec3.
---The vector is treated as a point.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat4Point3(a, b)
    local w = a.m30 * b.x + a.m31 * b.y + a.m33
    if w ~= 0.0 then
        local wInv = 1.0 / w
        return Vec3.new(
            (a.m00 * b.x + a.m01 * b.y + a.m03) * wInv,
            (a.m10 * b.x + a.m11 * b.y + a.m13) * wInv,
            (a.m20 * b.x + a.m21 * b.y + a.m23) * wInv)
    else
        return Vec3.new(0.0, 0.0, 0.0)
    end
end

---Multiplies a Mat3 with a Vec3.
---@param a table matrix
---@param b table vector
---@return table
function Utilities.mulMat3Vec3(a, b)
    return Vec3.new(
        a.m00 * b.x + a.m01 * b.y + a.m02 * b.z,
        a.m10 * b.x + a.m11 * b.y + a.m12 * b.z,
        a.m20 * b.x + a.m21 * b.y + a.m22 * b.z)
end

---Multiplies a Mat4 with a Vec4.
---@param a table matrix
---@param b table vector
---@return table
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

---Multiplies a Quaternion and a Vec3.
---The Vec3 is treated as a point, not as
---a pure quaternion.
---@param a table quaternion
---@param b table vector
---@return table
function Utilities.mulQuatVec3(a, b)
    local ai = a.imag
    local qw = a.real
    local qx = ai.x
    local qy = ai.y
    local qz = ai.z

    local iw = -qx * b.x - qy * b.y - qz * b.z
    local ix = qw * b.x + qy * b.z - qz * b.y
    local iy = qw * b.y + qz * b.x - qx * b.z
    local iz = qw * b.z + qx * b.y - qy * b.x

    return Vec3.new(
        ix * qw + iz * qy - iw * qx - iy * qz,
        iy * qw + ix * qz - iw * qy - iz * qx,
        iz * qw + iy * qx - iw * qz - ix * qy)
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

---Parses a string of positive integers separated
---by a comma. The integers may either be individual
---or ranges connected by a hyphen. For example,
---"1,5,10-15,7".
---
---Supplying the frame count ensures the range is not
---out of bounds. Defaults to an arbitrary large number.
---
---Returns an array of arrays. Inner arrays can hold
---duplicate frame indices,  as the user may intend for
---the same frame to appear in multiple groups.
---@param s string range string
---@param frameCount integer|nil number of frames
---@return table
function Utilities.parseRangeStringOverlap(s, frameCount)
    local fcVerif = frameCount or 2147483647
    local strgmatch = string.gmatch

    -- Parse string by comma.
    local arrOuter = {}
    local idxOuter = 0
    for token in strgmatch(s, "([^,]+)") do
        -- Parse string by hyphen.
        local edges = {}
        local idxEdges = 0
        for subtoken in strgmatch(token, "[^-]+") do
            local trial = tonumber(subtoken, 10)
            if trial
                and trial > 0
                and trial <= fcVerif then

                idxEdges = idxEdges + 1
                edges[idxEdges] = trial
            end
        end

        local arrInner = {}
        local idxInner = 0
        local lenEdges = #edges
        if lenEdges > 1 then
            local origIdx = edges[1]
            local destIdx = edges[lenEdges]

            if destIdx < origIdx then
                local j = origIdx + 1
                while j > destIdx do
                    j = j - 1
                    idxInner = idxInner + 1
                    arrInner[idxInner] = j
                end
            elseif destIdx > origIdx then
                local j = origIdx - 1
                while j < destIdx do
                    j = j + 1
                    idxInner = idxInner + 1
                    arrInner[idxInner] = j
                end
            else
                idxInner = idxInner + 1
                arrInner[idxInner] = destIdx
            end

        elseif lenEdges > 0 then
            idxInner = idxInner + 1
            arrInner[idxInner] = 1
        end

        idxOuter = idxOuter + 1
        arrOuter[idxOuter] = arrInner
    end

    return arrOuter
end

---Parses a string of positive integers separated
---by a comma. The integers may either be individual
---or ranges connected by a hyphen. For example,
---"1,5,10-15,7".
---
---Supplying the frame count ensures the range is not
---out of bounds. Defaults to an arbitrary large number.
---
---Returns an ordered set of integers.
---@param s string range string
---@param frameCount integer|nil number of frames
---@return table
function Utilities.parseRangeStringUnique(s, frameCount)
    local arr2 = Utilities.parseRangeStringOverlap(
        s, frameCount)

    -- Convert 2D array to a dictionary.
    -- Use dummy true, not some idx scheme,
    -- because natural ordering is preferred.
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
---@param hexes table
---@return table
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

---Promotes a Knot2 to a Knot3.
---All z components default to 0.0
---@param a table knot
---@return table
function Utilities.promoteKnot2ToKnot3(a)
    return Knot3.new(
        Utilities.promoteVec2ToVec3(a.co, 0.0),
        Utilities.promoteVec2ToVec3(a.fh, 0.0),
        Utilities.promoteVec2ToVec3(a.rh, 0.0))
end

---Promotes a Vec2 to a Vec3.
---The z component defaults to 0.0.
---@param a table vector
---@param z number|nil z component
---@return table
function Utilities.promoteVec2ToVec3(a, z)
    local vz = z or 0.0
    return Vec3.new(a.x, a.y, vz)
end

---Promotes a Vec2 to a Vec4.
---The z component defaults to 0.0.
---The w component defaults to 0.0.
---@param a table vector
---@param z number|nil z component
---@param w number|nil w component
---@return table
function Utilities.promoteVec2ToVec4(a, z, w)
    local vz = z or 0.0
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, vz, vw)
end

---Promotes a Vec3 to a Vec4.
---The w component defaults to 0.0.
---@param a table vector
---@param w number|nil w component
---@return table
function Utilities.promoteVec3ToVec4(a, w)
    local vw = w or 0.0
    return Vec4.new(a.x, a.y, a.z, vw)
end

---Quantizes a number.
---Defaults to signed quantization.
---@param a number value
---@param levels number levels
---@return number
function Utilities.quantize(a, levels)
    return Utilities.quantizeSigned(a, levels)
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
    else
        return a
    end
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
    else
        return math.max(0.0, a)
    end
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
---@param source table source pixels
---@param wSrc integer original width
---@param hSrc integer original height
---@param wTrg integer resized width
---@param hTrg integer resized height
---@return table
function Utilities.resizePixelsNearest(source, wSrc, hSrc, wTrg, hTrg)
    local floor = math.floor
    local tx = wSrc / wTrg
    local ty = hSrc / hTrg
    local len = wTrg * hTrg
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
---@param t table input table
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

---Given a source pixel array, creates a new array with
---the elements rotated 90 degrees counter-clockwise.
---@param source table source pixels
---@param w integer image width
---@param h integer image height
---@return table
function Utilities.rotatePixels90(source, w, h)
    local len = #source
    local lennh = len - h
    local rotated = {}
    local i = 0
    while i < len do
        rotated[1 + lennh + (i // w) - (i % w) * h] = source[1 + i]
        i = i + 1
    end
    return rotated
end

---Given a source pixel array, creates a new array with
---the elements rotated 270 degrees counter-clockwise.
---@param source table source pixels
---@param w integer image width
---@param h integer image height
---@return table
function Utilities.rotatePixels270(source, w, h)
    local len = #source
    local hn1 = h - 1
    local rotated = {}
    local i = 0
    while i < len do
        rotated[1 + (i % w) * h + hn1 - (i // w)] = source[1 + i]
        i = i + 1
    end
    return rotated
end

---Rounds a number to an integer based on its relationship to
---0.5. Returns zero when the number cannot be determined
---to be either greater than or less than zero.
---@param x number real number
---@return integer
function Utilities.round(x)
    -- math.tointeger(-0.00001) = -1, so modf must be used.
    local ix, fx = math.modf(x)
    if ix <= 0 and fx <= -0.5 then
        return ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        return ix + 1
    else
        return ix
    end
end

---Creates a new table from the source
---and shuffles it.
---@param t table input table
---@return table
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
---@param str string the string
---@return table
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

---Finds a point on the screen given a modelview,
---projection and 3D point.
---@param modelview table modelview
---@param projection table projection
---@param pt3 table point
---@param width number screen width
---@param height number screen height
---@return table
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
    x = width * (0.5 + 0.5 * x)
    y = height * (0.5 - 0.5 * y)
    z = 0.5 + 0.5 * z

    return Vec3.new(x, y, z)
end

---Removes white spaces from the end,
---or right edge, of a table of characters.
---Mutates the table in place.
---@param chars table
---@return table
function Utilities.trimCharsFinal(chars)
    local tr = table.remove
    while chars[#chars] == ' ' do tr(chars) end
    return chars
end

---Removes white spaces from the start,
---or left edge, of a table of characters.
---Mutates the table in place.
---@param chars table
---@return table
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
---@param hexes table color array
---@param za boolean all masks equal
---@return table
---@return table
function Utilities.uniqueColors(hexes, za)
    local dict = Utilities.hexArrToDict(hexes, za)
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
---@param filename string
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
---@param source table source pixels
---@param x integer x translation
---@param y integer y translation
---@param w integer image width
---@param h integer image height
function Utilities.wrapPixels(source, x, y, w, h)
    local len = #source
    local wrapped = {}
    local i = 0
    while i < len do
        local xm = ((i % w) - x) % w
        local ym = ((i // w) + y) % h
        i = i + 1
        wrapped[i] = source[1 + xm + ym * w]
    end
    return wrapped
end

return Utilities