dofile("./clr.lua")
dofile("./curve2.lua")
dofile("./mesh2.lua")
dofile("./utilities.lua")
dofile("./vec2.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

AseUtilities.DEFAULT_FILL = Color(255, 245, 215, 255)

AseUtilities.DEFAULT_PAL_ARR = {
    Color(  0,   0,   0,   0),
    Color(  0,   0,   0, 255),
    Color(255, 255, 255, 255),
    Color(255,   0,   0, 255),
    Color(255, 106,   0, 255),
    Color(255, 162,   0, 255),
    Color(255, 207,   0, 255),
    Color(255, 255,   0, 255),
    Color(129, 212,  26, 255),
    Color(  0, 169,  51, 255),
    Color( 21, 132, 102, 255),
    Color( 17,  89, 166, 255),
    Color( 60,  42, 146, 255),
    Color(105,  12, 133, 255),
    Color(170,   0,  85, 255)
}

AseUtilities.DEFAULT_STROKE = Color(32, 32, 32, 255)

AseUtilities.DISPLAY_DECIMAL = 3

AseUtilities.GLYPH_ALIGN_HORIZ = {
    "CENTER",
    "LEFT",
    "RIGHT"
}

AseUtilities.GLYPH_ALIGN_VERT = {
    "BOTTOM",
    "CENTER",
    "TOP"
}

AseUtilities.EASING_MODES = {
    "HSL",
    "HSV",
    "PALETTE",
    "RGB"
}

AseUtilities.ORIENTATIONS = {
    "HORIZONTAL",
    "VERTICAL"
}

AseUtilities.PROJECTIONS = {
    "ORTHO",
    "PERSPECTIVE"
}

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = setmetatable({}, AseUtilities)
    return inst
end

---Copies an Aseprite Color object by sRGB
---channel values. This is to prevent accidental
---pass by reference. The Color constructor does
---no boundary checking for [0, 255]. If the flag
---is "UNBOUNDED", then the raw values are used.
---If the flag is "MODULAR," this will copy by
---hexadecimal value, and hence use modular
---arithmetic. For more info, See
---https://www.wikiwand.com/en/Modular_arithmetic .
---The default is saturation arithmetic.
---@param aseClr table Aseprite color
---@param flag string out of bounds interpretation
---@return table
function AseUtilities.aseColorCopy(aseClr, flag)
    if flag == "UNBOUNDED" then
        return Color(
            aseClr.red,
            aseClr.green,
            aseClr.blue,
            aseClr.alpha)
    elseif flag == "MODULAR" then
        return Color(aseClr.rgbaPixel)
    else
        return Color(
            math.max(0, math.min(255, aseClr.red)),
            math.max(0, math.min(255, aseClr.green)),
            math.max(0, math.min(255, aseClr.blue)),
            math.max(0, math.min(255, aseClr.alpha)))
    end
end

---Returns a string containing diagnostic information
---about an Aseprite Color object. Format lists the
---nearest palette index, the red, green, blue and
---alpha in unsigned byte range [0, 255], and a web
---friendly hexadecimal representation.
---@param aseColor table Aseprite color
---@return string
function AseUtilities.aseColorToString(aseColor)
    local r = aseColor.red
    local g = aseColor.green
    local b = aseColor.blue
    -- Index is meaningless, as it seems to include
    -- nearest color in palette index, is a real number,
    -- and it's not clear when it could be mutated or
    -- by whom.
    -- local idx = math.tointeger(aseColor.index)
    return string.format(
        "(%03d, %03d, %03d, %03d) #%06X",
        r, g, b,
        aseColor.alpha,
        r << 0x10 | g << 0x08 | b)
end

---Converts an Aseprite Color object to a Clr.
---Assumes that the Aseprite Color is in sRGB.
---Both Aseprite Color and Clr allow arguments
---to exceed the expected ranges, [0, 255] and
---[0.0, 1.0], respectively.
---@param aseClr table Aseprite color
---@return table
function AseUtilities.aseColorToClr(aseClr)
    return Clr.new(
        0.00392156862745098 * aseClr.red,
        0.00392156862745098 * aseClr.green,
        0.00392156862745098 * aseClr.blue,
        0.00392156862745098 * aseClr.alpha)
end

---Returns a string containing diagnostic information
---about an Aseprite Color object.
---@param pal table Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return string
function AseUtilities.asePaletteToString(pal, startIndex, count)
    local palLen = #pal

    local si = startIndex or 0
    si = math.min(palLen - 1, math.max(0, si))
    local vc = count or 256
    vc = math.min(palLen - si, math.max(2, vc)) - 1

    -- Using \r for carriage returns causes formatting bug.
    local str = ""
    for i = 0, vc, 1 do
        local palIdx = si + i
        str = str
            .. string.format("%03d. ", palIdx)
            .. AseUtilities.aseColorToString(
                pal:getColor(palIdx))
        if i < vc then
            str = str .. ",\n"
        end
    end

    return str
end

---Converts an Aseprite palette to a table
---of Aseprite Colors. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB.
---@param pal table Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return table
function AseUtilities.asePaletteToClrArr(pal, startIndex, count)
    if pal then
        local palLen = #pal

        local si = startIndex or 0
        si = math.min(palLen - 1, math.max(0, si))
        local vc = count or 256
        vc = math.min(palLen - si, math.max(2, vc))

        local clrs = {}
        local convert = AseUtilities.aseColorToClr
        for i = 0, vc - 1, 1 do
            clrs[1 + i] = convert(pal:getColor(si + i))
        end

        -- This is intended for gradient work, so it
        -- returns an array with a length greater than
        -- one no matter what.
        if #clrs == 1 then
            local a = clrs[1].a
            table.insert(clrs, 1, Clr.new(0.0, 0.0, 0.0, a))
            clrs[3] = Clr.new(1.0, 1.0, 1.0, a)
        end

        return clrs
    else
        return { Clr.clearBlack(), Clr.white() }
    end
end

---Converts an Aseprite palette to a table
---of hexadecimal integers. If the palette is nil
---returns a default table. Assumes palette
---is in sRGB.
---@param pal table Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return table
function AseUtilities.asePaletteToHexArr(pal, startIndex, count)
    if pal then
        local palLen = #pal

        local si = startIndex or 0
        si = math.min(palLen - 1, math.max(0, si))
        local vc = count or 256
        vc = math.min(palLen - si, math.max(2, vc))

        local hexes = {}
        for i = 0, vc - 1, 1 do
            -- Do you have to worry about overflow due to
            -- rgb being out of gamut? Doesn't seem so, even
            -- in cases of color profile transforms...
            local aseColor = pal:getColor(si + i)
            hexes[1 + i] = aseColor.rgbaPixel
        end

        if #hexes == 1 then
            local amsk = hexes[1] & 0xff000000
            table.insert(hexes, 1, amsk)
            hexes[3] = amsk | 0x00ffffff
        end
        return hexes
    else
        return { 0x00000000, 0xffffffff }
    end
end

---Blends together two hexadecimal colors.
---Premultiplies each color by its alpha prior
---to blending. Unpremultiplies the result.
---For more information,
---see https://www.w3.org/TR/compositing-1/ .
---@param a number backdrop color
---@param b number overlay color
---@return number
function AseUtilities.blend(a, b)

    local t = b >> 0x18 & 0xff
    if t > 0xfe then return b end
    local v = a >> 0x18 & 0xff
    if v < 0x01 then return b end

    local bb = b >> 0x10 & 0xff
    local bg = b >> 0x08 & 0xff
    local br = b & 0xff

    local ab = a >> 0x10 & 0xff
    local ag = a >> 0x08 & 0xff
    local ar = a & 0xff

    -- Experimented with subtracting
    -- from 0x100 instead of 0xff, due to 255/2
    -- not having a whole number middle, but 0xff
    -- lead to more accurate results.
    local u = 0xff - t
    if t > 0x7e then t = t + 1 end

    local uv = (v * u) // 0xff
    local tuv = t + uv

    if tuv > 0xfe then
        local cr = (bb * t + ab * uv) // 0xff
        local cg = (bg * t + ag * uv) // 0xff
        local cb = (br * t + ar * uv) // 0xff

        if cr > 0xff then cr = 0xff end
        if cg > 0xff then cg = 0xff end
        if cb > 0xff then cb = 0xff end
        return 0xff000000
            | cr << 0x10
            | cg << 0x08
            | cb
    elseif tuv > 0x1 then
        local tuvn1 = tuv
        if tuv > 0x7e then tuvn1 = tuv - 1 end
        return tuv << 0x18
            | ((bb * t + ab * uv) // tuvn1) << 0x10
            | ((bg * t + ag * uv) // tuvn1) << 0x08
            | ((br * t + ar * uv) // tuvn1)
    else
        return 0x00000000
    end
end

---Converts a Clr to an Aseprite Color.
---Assumes that source and target are in sRGB.
---Clamps the Clr's channels to [0.0, 1.0] before
---they are converted. Beware that this could return
---(255, 0, 0, 0) or (0, 255, 0, 0), which may be
---visually indistinguishable from - and confused
--- with - an alpha mask, (0, 0, 0, 0).
---@param clr table clr
---@return table
function AseUtilities.clrToAseColor(clr)
    local r = clr.r
    local g = clr.g
    local b = clr.b
    local a = clr.a

    if r < 0.0 then r = 0.0 elseif r > 1.0 then r = 1.0 end
    if g < 0.0 then g = 0.0 elseif g > 1.0 then g = 1.0 end
    if b < 0.0 then b = 0.0 elseif b > 1.0 then b = 1.0 end
    if a < 0.0 then a = 0.0 elseif a > 1.0 then a = 1.0 end

    return Color(
        math.tointeger(0.5 + 255.0 * r),
        math.tointeger(0.5 + 255.0 * g),
        math.tointeger(0.5 + 255.0 * b),
        math.tointeger(0.5 + 255.0 * a))
end

---Draws a line with Bresenham's algorithm.
---Uses the Aseprite image instance method
---drawPixel. This means that the pixel changes
---will not be tracked as a transaction.
---@param image table Aseprite image
---@param clr number hexadecimal color
---@param xo number origin x
---@param yo number origin y
---@param xd number destination x
---@param yd number destination y
function AseUtilities.drawLine(image, xo, yo, xd, yd, clr)
    if xo == xd and yo == yd then return end

    local dx = xd - xo
    local dy = yd - yo
    local x = xo
    local y = yo
    local sx = 0
    local sy = 0

    if xo < xd then
        sx = 1
    else
        sx = -1
        dx = -dx
    end

    if yo < yd then
        sy = 1
    else
        sy = -1
        dy = -dy
    end

    local err = 0
    if dx > dy then err = dx // 2
    else err = -dy // 2 end
    local e2 = 0
    local hex = clr or 0xffffffff
    local blend = AseUtilities.blend

    while true do
        -- print("(" .. x .. ", " .. y .. ")")

        -- image:drawPixel(x, y, hex)
        local srcHex = image:getPixel(x, y)
        local trgHex = blend(srcHex, hex)
        image:drawPixel(x, y, trgHex)

        if x == xd and y == yd then break end
        e2 = err
        if e2 > -dx then
            err = err - dy
            x = x + sx
        end

        if e2 < dy then
            err = err + dx
            y = y + sy
        end
    end
end

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image table Aseprite image
---@param xc number center x
---@param yc number center y
---@param r number radius
---@param hex number hexadecimal color
function AseUtilities.drawCircleFill(image, xc, yc, r, hex)
    local rsq = r * r
    local r2 = r * 2
    local lenn1 = r2 * r2 - 1
    local blend = AseUtilities.blend
    for i = 0, lenn1, 1 do
        local x = (i % r2) - r
        local y = (i // r2) - r
        if (x * x + y * y) < rsq then
            local xMark = xc + x
            local yMark = yc + y
            local srcHex = image:getPixel(xMark, yMark)
            local trgHex = blend(srcHex, hex)
            image:drawPixel(xMark, yMark, trgHex)
        end
    end
end

---Draws a circle with a 1 pixel stroke.
---Uses the Aseprite image instance method
---drawPixel. This means that the pixel
---changes will not be tracked as a transaction.
---@param image table Aseprite image
---@param xc number center x
---@param yc number center y
---@param r number radius
---@param hex number hexadecimal color
function AseUtilities.drawCircleStroke(image, xc, yc, r, hex)
    -- See for circle stroke with line thickness:
    -- https://stackoverflow.com/questions/27755514/circle-with-thickness-drawing-algorithm

    local x = r
    local y = 0

    local xcpr = xc + r
    local xcnr = xc - r
    local ycpr = yc + r
    local ycnr = yc - r

    local srcHex0 = image:getPixel(xcpr, yc)
    local srcHex1 = image:getPixel(xcnr, yc)
    local srcHex2 = image:getPixel(xc, ycpr)
    local srcHex3 = image:getPixel(xc, ycnr)

    local blend = AseUtilities.blend
    local trgHex0 = blend(srcHex0, hex)
    local trgHex1 = blend(srcHex1, hex)
    local trgHex2 = blend(srcHex2, hex)
    local trgHex3 = blend(srcHex3, hex)

    image:drawPixel(xcpr, yc, trgHex0)
    image:drawPixel(xcnr, yc, trgHex1)
    image:drawPixel(xc, ycpr, trgHex2)
    image:drawPixel(xc, ycnr, trgHex3)

    local p = 1 - r
    while x > y do
        y = y + 1
        if p <= 0 then
            p = p + 2 * y + 1
        else
            x = x - 1
            p = p + 2 * y - 2 * x + 1
        end

        if x < y then
            break
        end

        local xcpx = xc + x
        local xcnx = xc - x
        local ycpy = yc + y
        local ycny = yc - y

        srcHex0 = image:getPixel(xcpx, ycpy)
        srcHex1 = image:getPixel(xcnx, ycpy)
        srcHex2 = image:getPixel(xcpx, ycny)
        srcHex3 = image:getPixel(xcnx, ycny)

        trgHex0 = blend(srcHex0, hex)
        trgHex1 = blend(srcHex1, hex)
        trgHex2 = blend(srcHex2, hex)
        trgHex3 = blend(srcHex3, hex)

        image:drawPixel(xcpx, ycpy, trgHex0)
        image:drawPixel(xcnx, ycpy, trgHex1)
        image:drawPixel(xcpx, ycny, trgHex2)
        image:drawPixel(xcnx, ycny, trgHex3)

        if x ~= y then

            local xcpy = xc + y
            local xcny = xc - y
            local ycpx = yc + x
            local ycnx = yc - x

            srcHex0 = image:getPixel(xcpy, ycpx)
            srcHex1 = image:getPixel(xcny, ycpx)
            srcHex2 = image:getPixel(xcpy, ycnx)
            srcHex3 = image:getPixel(xcny, ycnx)

            trgHex0 = blend(srcHex0, hex)
            trgHex1 = blend(srcHex1, hex)
            trgHex2 = blend(srcHex2, hex)
            trgHex3 = blend(srcHex3, hex)

            image:drawPixel(xcpy, ycpx, trgHex0)
            image:drawPixel(xcny, ycpx, trgHex1)
            image:drawPixel(xcpy, ycnx, trgHex2)
            image:drawPixel(xcny, ycnx, trgHex3)
        end
    end
end

---Draws a curve in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param curve table curve
---@param resolution number curve resolution
---@param useFill boolean use fill
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
function AseUtilities.drawCurve2(
    curve, resolution,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)

    local vres = 2
    if resolution > 2 then vres = resolution end

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
    local toPoint = AseUtilities.vec2ToPoint
    local bezier = Vec2.bezierPoint
    local pts = {}
    local start = 2
    local prevKnot = kns[1]
    if isLoop then
        start = 1
        prevKnot = kns[knsLen]
    end

    for i = start, knsLen, 1 do
        local currKnot = kns[i]

        local coPrev = prevKnot.co
        local fhPrev = prevKnot.fh
        local rhNext = currKnot.rh
        local coNext = currKnot.co

        table.insert(pts, toPoint(coPrev))
        for j = 1, vres, 1 do
            table.insert(pts,
                toPoint(bezier(
                    coPrev, fhPrev,
                    rhNext,coNext,
                    j * toPercent)))
        end

        prevKnot = currKnot
    end

    -- Draw fill.
    if isLoop and useFill then
        app.transaction(function()
            app.useTool {
                tool = "contour",
                color = fillClr,
                brush = brsh,
                points = pts,
                cel = cel,
                layer = layer,
                freehandAlgorithm = 1 }
        end)
    end

    -- Draw stroke.
    if useStroke then
        app.transaction(function()
            local ptPrev = pts[1]
            local ptsLen = #pts
            if isLoop then
                ptPrev = pts[ptsLen]
            end

            for i = start, ptsLen, 1 do
                local ptCurr = pts[i]
                app.useTool {
                    tool = "line",
                    color = strokeClr,
                    brush = brsh,
                    points = { ptPrev, ptCurr },
                    cel = cel,
                    layer = layer,
                    freehandAlgorithm = 1 }
                ptPrev = ptCurr
            end
        end)
    end

    app.refresh()
end

---Draws a glyph at its native scale to an image.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image table image
---@param glyph table glyph
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
function AseUtilities.drawGlyph(
    image, glyph, hex,
    x, y, gw, gh)

    -- TODO: Return xCaret position?

    local lenn1 = gw * gh - 1
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop
    for i = 0, lenn1, 1 do
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

---Draws a glyph to an image at a pixel scale;
---resizes the glyph according to nearest neighbor.
---The color is to be represented in hexadecimal
---with AABBGGR order.
---Operates on pixels. This should not be used
---with app.useTool.
---@param image table image
---@param glyph table glyph
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param dw number display width
---@param dh number display height
function AseUtilities.drawGlyphNearest(
    image, glyph, hex,
    x, y, gw, gh, dw, dh)

    -- TODO: Return xCaret position?

    if gw == dw and gh == dh then
        return AseUtilities.drawGlyph(
            image, glyph, hex,
            x, y, gw, gh)
    end

    local lenTrgn1 = dw * dh - 1
    local lenSrcn1 = gw * gh - 1
    local tx = gw / dw
    local ty = gh / dh
    local trunc = math.tointeger
    local blend = AseUtilities.blend
    local glMat = glyph.matrix
    local glDrop = glyph.drop
    local ypDrop = y + glDrop * (dh / gh)
    for k = 0, lenTrgn1, 1 do
        local xTrg = k % dw
        local yTrg = k // dw

        local xSrc = trunc(xTrg * tx)
        local ySrc = trunc(yTrg * ty)
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

---Draws the knot handles of a curve.
---Color arguments are optional.
---@param curve table curve
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawHandles2(
    curve, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    local kns = curve.knots
    local knsLen = #kns
    app.transaction(function()
        for i = 1, knsLen, 1 do
            AseUtilities.drawKnot2(
                kns[i], cel, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot table knot
---@param cel table cel
---@param layer table layer
---@param lnClr table line color
---@param coClr table coordinate color
---@param fhClr table fore handle color
---@param rhClr table rear handle color
function AseUtilities.drawKnot2(
    knot, cel, layer,
    lnClr, coClr, fhClr, rhClr)

    -- #02A7EB, #EBE128, #EB1A40
    local lnClrVal = lnClr or Color(0xffafafaf)
    local rhClrVal = rhClr or Color(0xffeba702)
    local coClrVal = coClr or Color(0xff28e1eb)
    local fhClrVal = fhClr or Color(0xff401aeb)

    local lnBrush = Brush { size = 1 }
    local rhBrush = Brush { size = 4 }
    local coBrush = Brush { size = 6 }
    local fhBrush = Brush { size = 5 }

    local coPt = AseUtilities.vec2ToPoint(knot.co)
    local fhPt = AseUtilities.vec2ToPoint(knot.fh)
    local rhPt = AseUtilities.vec2ToPoint(knot.rh)

    app.transaction(function()
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            cel = cel,
            layer = layer }

        app.useTool {
            tool = "pencil",
            color = fhClrVal,
            brush = fhBrush,
            points = { fhPt },
            cel = cel,
            layer = layer }
    end)
end

---Draws a mesh in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param mesh table mesh
---@param useFill boolean use fill
---@param fillClr table fill color
---@param useStroke boolean use stroke
---@param strokeClr table stroke color
---@param brsh table brush
---@param cel table cel
---@param layer table layer
function AseUtilities.drawMesh2(
    mesh,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    -- Convert Vec2s to Points.
    -- Round Vec2 for improved accuracy.
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    local toPt = AseUtilities.vec2ToPoint
    for i = 1, vsLen, 1 do
        pts[i] = toPt(vs[i])
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    local ptsGrouped = {}
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        local ptsFace = {}
        for j = 1, fLen, 1 do
            ptsFace[j] = pts[f[j]]
        end
        ptsGrouped[i] = ptsFace
    end

    -- Group fills into one transaction.
    local useTool = app.useTool
    if useFill then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[i],
                    cel = cel,
                    layer = layer }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                local ptGroup = ptsGrouped[i]
                local ptgLen = #ptGroup
                local ptPrev = ptGroup[ptgLen]
                for j = 1, ptgLen, 1 do
                    local ptCurr = ptGroup[j]
                    useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        cel = cel,
                        layer = layer }
                    ptPrev = ptCurr
                end
            end
        end)
    end

    app.refresh()
end

---Draws an array of characters to an image
---horizontally according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image table image
---@param chars table characters table
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param scale number display scale
function AseUtilities.drawStringHoriz(
    lut, image, chars, hex,
    x, y, gw, gh, scale)

    local writeChar = x
    local writeLine = y
    local charLen = #chars
    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale
    local drawGlyph = AseUtilities.drawGlyphNearest
    local defGlyph = lut[' ']
    for i = 1, charLen, 1 do
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

---Draws an array of characters to an image
---vertically according to the coordinates.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param lut table glyph look up table
---@param image table image
---@param chars table characters table
---@param hex number hexadecimal color
---@param x number x top left corner
---@param y number y top left corner
---@param gw number glyph width
---@param gh number glyph height
---@param scale number display scale
function AseUtilities.drawStringVert(
    lut, image, chars, hex,
    x, y, gw, gh, scale)

    local writeChar = y
    local writeLine = x
    local charLen = #chars
    local dw = gw * scale
    local dh = gh * scale
    local scale2 = scale + scale
    local rotateCcw = AseUtilities.rotateGlyphCcw
    local drawGlyph = AseUtilities.drawGlyphNearest
    local defGlyph = lut[' ']
    for i = 1, charLen, 1 do
        local ch = chars[i]
        if ch == '\n' then
            writeLine = writeLine + dw + scale2
            writeChar = y
        else
            local glyph = lut[ch] or defGlyph
            glyph = rotateCcw(glyph, gw, gh)
            drawGlyph(
                image, glyph, hex,
                writeLine, writeChar,
                gh, gw, dh, dw)
            writeChar = writeChar - dh
        end
    end
end

---Returns an appropriate easing function
---based on string presets:
---"RGB", "HSL" or "HSV" easing modes.
---"LINEAR" or "SMOOTH" RGB functions.
---"NEAR" or "FAR" hue functions.
---@param easingMode string
---@param easingFuncRGB string
---@param easingFuncHue string
---@return function
function AseUtilities.easingFuncPresets(
    easingMode,
    easingFuncRGB,
    easingFuncHue)

    local easing = nil
    if easingMode == "HSV" then
        easing = Clr.mixHsva

        if easingFuncHue == "FAR" then
            easing = function(a, b, t)
                return Clr.mixHsvaInternal(
                    a, b, t,
                    function(x, y, z)
                        return Utilities.lerpAngleFar(
                            x, y, z, 1.0)
                    end)
            end
        end
    elseif easingMode == "HSL" then
        easing = Clr.mixHsla

        if easingFuncHue == "FAR" then
            easing = function(a, b, t)
                return Clr.mixHslaInternal(
                    a, b, t,
                    function(x, y, z)
                        return Utilities.lerpAngleFar(
                            x, y, z, 1.0)
                    end)
            end
        end
    else
        easing = Clr.mix

        if easingFuncRGB == "SMOOTH" then
            easing = function(a, b, t)
                return Clr.mix(a, b,
                    t * t * (3.0 - (t + t)))
            end
        end
    end

    return easing

end

---Initializes a sprite and layer.
---Sets palette to the colors provided,
---or, if nil, a default set.
---@param wDefault number default width
---@param hDefault number default height
---@param layerName string layer name
---@param colors table array of colors
---@param colorspace table color space
---@return table
function AseUtilities.initCanvas(
    wDefault,
    hDefault,
    layerName,
    colors,
    colorspace)

    -- TODO: Consider adding color space to calls
    -- to this function.

    local clrs = AseUtilities.DEFAULT_PAL_ARR
    if colors and #colors > 0 then
        clrs = colors
    end

    local sprite = app.activeSprite
    local layer = nil

    if sprite == nil then
        local wVal = 32
        local hVal = 32

        if wDefault and wDefault > 0 then wVal = wDefault end
        if hDefault and hDefault > 0 then hVal = hDefault end
        sprite = Sprite(wVal, hVal)
        if colorspace then
            sprite:assignColorSpace(colorspace)
        end

        app.activeSprite = sprite
        layer = sprite.layers[1]
        local lenClrs = #clrs
        local pal = Palette(lenClrs)
        for i = 1, lenClrs, 1 do
            local clr = clrs[i]
            if clr then
                pal:setColor(i - 1, clr)
            end
        end
        sprite:setPalette(pal)
    else
        layer = sprite:newLayer()
    end

    layer.name = layerName or "Layer"
    return sprite
end

---Rotates a glyph counter-clockwise.
---The glyph is to be represented as a binary matrix
---with a width and height, where 1 draws a pixel
---and zero does not, packed in to a number
---in row major order.
---@param gl number glyph
---@param w number width
---@param h number height
---@return number
function AseUtilities.rotateGlyphCcw(gl, w, h)
    local lenn1 = (w * h) - 1
    local wn1 = w - 1
    local vr = 0
    for i = 0, lenn1, 1 do
        local shift0 = lenn1 - i
        local bit = (gl >> shift0) & 1

        local x = i // w
        local y = wn1 - (i % w)
        local j = y * h + x
        local shift1 = lenn1 - j
        vr = vr | (bit << shift1)
    end
    return vr
end

---Converts a Vec2 to an Aseprite Point.
---@param a table vector
---@return table
function AseUtilities.vec2ToPoint(a)
    local cx = 0
    if a.x < -0.0 then
        cx = math.tointeger(a.x - 0.5)
    elseif a.x > 0.0 then
        cx = math.tointeger(a.x + 0.5)
    end

    local cy = 0
    if a.y < -0.0 then
        cy = math.tointeger(a.y - 0.5)
    elseif a.y > 0.0 then
        cy = math.tointeger(a.y + 0.5)
    end

    return Point(cx, cy)
end

return AseUtilities