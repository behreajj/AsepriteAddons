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
    Color(170,   0,  85, 255),
    Color(  0,   0,   0, 255),
    Color(255, 255, 255, 255)
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

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = setmetatable({}, AseUtilities)
    return inst
end

---Converts an Aseprite Color object to a Clr.
---@param aseClr table Aseprite color
---@return table
function AseUtilities.aseColorToClr(aseClr)
    return Clr.new(
        0.00392156862745098 * aseClr.red,
        0.00392156862745098 * aseClr.green,
        0.00392156862745098 * aseClr.blue,
        0.00392156862745098 * aseClr.alpha)
end

---Converts a Clr to an Aseprite Color.
---Clamps the Clr's channels to [0.0, 1.0] before
---they are converted.
---@param clr table clr
---@return table
function AseUtilities.clrToAseColor(clr)
    local r = clr.r
    local g = clr.g
    local b = clr.b
    local a = clr.a

    if r < 0.0 then
        r = 0.0
    elseif r > 1.0 then
        r = 1.0
    end

    if g < 0.0 then
        g = 0.0
    elseif g > 1.0 then
        g = 1.0
    end

    if b < 0.0 then
        b = 0.0
    elseif b > 1.0 then
        b = 1.0
    end

    if a < 0.0 then
        a = 0.0
    elseif a > 1.0 then
        a = 1.0
    end

    return Color(
        math.tointeger(0.5 + 255.0 * r),
        math.tointeger(0.5 + 255.0 * g),
        math.tointeger(0.5 + 255.0 * b),
        math.tointeger(0.5 + 255.0 * a))
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

    -- There is a noticeable issue with accuracy
    -- between this and the real number Clr version,
    -- particularly in the tuv > 0x1 case, where two
    -- alphas need to be blended. Subtracting one
    -- from tuv when it's >= 127 seems to
    -- alleviate the issue?

    local t = b >> 0x18 & 0xff
    if t > 0xfe then return b end
    if t > 0x7e then t = t + 1 end

    local bb = b >> 0x10 & 0xff
    local bg = b >> 0x08 & 0xff
    local br = b & 0xff

    local ab = a >> 0x10 & 0xff
    local ag = a >> 0x08 & 0xff
    local ar = a & 0xff

    local u = 0x100 - t
    local v = a >> 0x18 & 0xff
    local uv = (v * u) // 0xff
    local tuv = t + uv

    if tuv > 0xfe then
        -- TODO: This branch needs further testing.
        local denom = 0xff
        -- if uv > 0x7f then denom = 0x100 end
        local cr = (bb * t + ab * uv) // denom
        local cg = (bg * t + ag * uv) // denom
        local cb = (br * t + ar * uv) // denom
        if cr > 255 then cr = 255 elseif cr < 0 then cr = 0 end
        if cg > 255 then cg = 255 elseif cg < 0 then cg = 0 end
        if cb > 255 then cb = 255 elseif cb < 0 then cb = 0 end
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

---Draws a filled circle. Uses the Aseprite image
---instance method drawPixel. This means that the
---pixel changes will not be tracked as a transaction.
---@param image table Aseprite image
---@param xo number origin x
---@param yo number origin y
---@param r number radius
---@param hex number hexadecimal color
function AseUtilities.drawCircleFill(image, xo, yo, r, hex)
    local rsq = r * r
    local r2 = r * 2
    local lenn1 = r2 * r2 - 1
    for i = 0, lenn1, 1 do
        local x = (i % r2) - r
        local y = (i // r2) - r
        if (x * x + y * y) < rsq then
            local xLocal = xo + x
            local yLocal = yo + y
            local srcHex = image:getPixel(xLocal, yLocal)
            local trgHex = AseUtilities.blend(srcHex, hex)
            image:drawPixel(xLocal, yLocal, trgHex)
            -- image:drawPixel(xLocal, yLocal, hex)
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
    curve,
    resolution,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    local vres = 2
    if resolution > 2 then vres = resolution end

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
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

        local v = Vec2.round(coPrev)
        table.insert(pts, Point(v.x, v.y))

        for j = 1, vres, 1 do
            v = Vec2.round(
                Vec2.bezierPoint(
                    coPrev, fhPrev,
                    rhNext, coNext,
                    j * toPercent))
            table.insert(pts, Point(v.x, v.y))
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
---The glyph is to be represented as a binary matrix
---with a width and height, where 1 draws a pixel
---and zero does not, packed in to a number
---in row major order. The color is to be represented
---as a hexadecimal in AABBGGR order.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param image table image
---@param glyph number glyph
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
    for i = 0, lenn1, 1 do
        local shift = lenn1 - i
        local mark = (glyph >> shift) & 1
        if mark ~= 0 then
            image:drawPixel(
                x + (i % gw),
                y + (i // gw),
                hex)
        end
    end
end

---Draws a glyph to an image at a pixel scale;
---resizes the glyph according to nearest neighbor.
---The glyph is to be represented as a binary matrix
---with a width and height, where 1 draws a pixel
---and zero does not, packed in to a number
---in row major order. The color is to be represented
---as a hexadecimal in AABBGGR order.
---Operates on pixel by pixel level. Its use
---should not be mixed with app.useTool.
---@param image table image
---@param glyph number glyph
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
    for k = 0, lenTrgn1, 1 do
        local xTrg = k % dw
        local yTrg = k // dw

        local xSrc = trunc(xTrg * tx)
        local ySrc = trunc(yTrg * ty)
        local idxSrc = ySrc * gw + xSrc

        local shift = lenSrcn1 - idxSrc
        local mark = (glyph >> shift) & 1
        if mark ~= 0 then
            image:drawPixel(x + xTrg, y + yTrg, hex)
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

    local coRnd = Vec2.round(knot.co)
    local fhRnd = Vec2.round(knot.fh)
    local rhRnd = Vec2.round(knot.rh)

    local coPt = Point(coRnd.x, coRnd.y)
    local fhPt = Point(fhRnd.x, fhRnd.y)
    local rhPt = Point(rhRnd.x, rhRnd.y)

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
    for i = 1, vsLen, 1 do
        local v = Vec2.round(vs[i])
        -- table.insert(pts, Point(v.x, v.y))
        pts[i] = Point(v.x, v.y)
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
            -- table.insert(ptsFace, pts[f[j]])
            ptsFace[j] = pts[f[j]]
        end
        -- table.insert(ptsGrouped, ptsFace)
        ptsGrouped[i] = ptsFace
    end

    -- Group fills into one transaction.
    if useFill then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                app.useTool {
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
                    app.useTool {
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

            drawGlyph(image, glyph, hex, writeChar, writeLine, gw, gh, dw, dh)
            writeChar = writeChar + dw + scale
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
            drawGlyph(image, glyph, hex, writeLine, writeChar, gh, gw, dh, dw)
            writeChar = writeChar - dh + scale
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
---@return table
function AseUtilities.initCanvas(
    wDefault,
    hDefault,
    layerName,
    colors)

    local clrs = AseUtilities.DEFAULT_PAL_ARR
    if colors and #colors > 0 then
        clrs = colors
    end

    local sprite = app.activeSprite
    local layer = nil

    if sprite == nil then
        sprite = Sprite(wDefault, hDefault)
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

---Converts an Aseprite palette to a table
---of Aseprite Colors. If the palette is nil
---returns a default table.
---@param pal table Aseprite palette
---@param startIndex number start index
---@param count number sample count
---@return table
function AseUtilities.paletteToClrArr(pal, startIndex, count)
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
            table.insert(clrs, 1, Clr.black())
            clrs[3] = Clr.white()
        end

        return clrs
    else
        return { Clr.clearBlack(), Clr.white() }
    end
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

-- for i = 1, 10, 1 do
--     local aClr = Clr.random(
--         0, 100,
--         -110, 110,
--         -110, 110,
--         0.0, 1.0)
--     local aHex = Clr.toHex(aClr)

--     local bClr = Clr.random(
--         0, 100,
--         -110, 110,
--         -110, 110,
--         0.0, 1.0)
--     local bHex = Clr.toHex(bClr)

--     local cClr = Clr.blend(aClr, bClr)
--     local cHex = AseUtilities.blend(aHex, bHex)

--     print(cClr)
--     print(Clr.fromHex(cHex))

--     print(string.format("%08X", Clr.toHex(cClr)))
--     print(string.format("%08X\n", cHex))
-- end

return AseUtilities