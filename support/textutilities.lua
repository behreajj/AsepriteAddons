dofile("./aseutilities.lua")
dofile("./glyph.lua")

TextUtilities = {}
TextUtilities.__index = TextUtilities

setmetatable(TextUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Text horizontal alignment.
TextUtilities.GLYPH_ALIGN_HORIZ = {
    "CENTER",
    "LEFT",
    "RIGHT"
}

---Text vertical alignment.
TextUtilities.GLYPH_ALIGN_VERT = {
    "BOTTOM",
    "CENTER",
    "TOP"
}

---Glyph height.
TextUtilities.GLYPH_HEIGHT = 8

---Glyph width.
TextUtilities.GLYPH_WIDTH = 8

---Glyph look up table. Glyphs occupy
---an 8 x 8 grid, where 1 represents
---a mark and 0 represents empty.
TextUtilities.GLYPH_LUT = {
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

---Draws a glyph at its native scale to an image.
---The color is to be represented as an rgba integer.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image Image image
---@param glyph Glyph glyph
---@param hex integer rgba integer
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
function TextUtilities.drawGlyph(
    image, glyph, hex, x, y, gw, gh)
    local lenn1 = gw * gh - 1
    local blend = AseUtilities.blendRgba
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop

    local i = -1
    while i < lenn1 do
        i = i + 1
        local shift = lenn1 - i
        local mark = (glMat >> shift) & 1
        if mark ~= 0 then
            local xMark = x + (i % gw)
            local yMark = ypDrop + (i // gw)
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws a glyph to an image at a pixel scale.
---Resizes the glyph according to nearest neighbor.
---The color is to be represented as an rgba integer.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image Image image
---@param glyph Glyph glyph
---@param hex integer rgba integer
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
---@param dw integer display width
---@param dh integer display height
function TextUtilities.drawGlyphNearest(
    image, glyph, hex,
    x, y, gw, gh, dw, dh)
    if gw == dw and gh == dh then
        return TextUtilities.drawGlyph(
            image, glyph, hex,
            x, y, gw, gh)
    end

    local lenTrgn1 = dw * dh - 1
    local lenSrcn1 = gw * gh - 1
    local tx = gw / dw
    local ty = gh / dh
    local floor = math.floor
    local blend = AseUtilities.blendRgba
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = floor(y + glDrop * (dh / gh))
    local i = -1
    while i < lenTrgn1 do
        i = i + 1
        local xTrg = i % dw
        local yTrg = i // dw

        local xSrc = floor(xTrg * tx)
        local ySrc = floor(yTrg * ty)
        local idxSrc = ySrc * gw + xSrc

        local shift = lenSrcn1 - idxSrc
        local mark = (glMat >> shift) & 1
        if mark ~= 0 then
            local xMark = x + xTrg
            local yMark = ypDrop + yTrg
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws an array of characters to an image
---according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image Image image
---@param chars string[] characters table
---@param hex integer rgba integer
---@param x integer x top left corner
---@param y integer y top left corner
---@param gw integer glyph width
---@param gh integer glyph height
---@param scale integer display scale
function TextUtilities.drawString(
    lut, image, chars, hex, x, y, gw, gh, scale)
    local writeChar = x
    local writeLine = y
    local charLen = #chars
    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale
    local drawGlyph = TextUtilities.drawGlyphNearest
    local defGlyph = lut[' ']
    local i = 0
    while i < charLen do
        i = i + 1
        local ch = chars[i]
        -- print(ch)
        if ch == '\n' then
            writeLine = writeLine + dh + scale2
            writeChar = x
        else
            local glyph = lut[ch] or defGlyph
            -- print(glyph)

            drawGlyph(
                image, glyph, hex,
                writeChar, writeLine,
                gw, gh, dw, dh)
            writeChar = writeChar + dw
        end
    end
end

---Breaks a long string into multiple lines according
---to a character-per-line limit. The limit should be
---in the range 16 to 120. The delimiter inserted into
---a string is '\n'.
---@param srcStr string source string
---@param limit integer? character limit per line
---@return string
function TextUtilities.lineWrapString(srcStr, limit)
    -- TODO: Is this used anywhere?
    local chars2d = TextUtilities.lineWrapStringToChars(
        srcStr, limit)
    local len2d = #chars2d
    local i = 0
    ---@type string[]
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
---@param limit integer? character limit per line
---@return string[][]
function TextUtilities.lineWrapStringToChars(srcStr, limit)
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
        while i < flatCharLen do
            i = i + 1
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
                        while j > lastSpace do
                            j = j - 1
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

return TextUtilities