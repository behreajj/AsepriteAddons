dofile("../../support/aseutilities.lua")
dofile("../../support/curve3.lua")
dofile("../../support/octree.lua")

local defaults = {
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    lchCh = true, -- L
    lchLh = true, -- c
    lchLc = true, -- h
    labab = false, -- L
    labLb = true, -- a
    labLa = true, -- b
    manifest = true,
    coverage = false,
    cvgSat = 100,
    cvgRad = 175,
    cvgCapacity = 16,
    contiguous = false,
    closeLoop = false,
    resolution = 48,
    bkgColor = Color(38, 38, 38, 255),
    txtColor = Color(255, 245, 215, 255),
    shdColor = Color(0, 0, 0, 255),
    pullFocus = false
}

local dlg = Dialog { title = "Palette Analysis" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType

        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.count
}

dlg:newrow { always = false }

dlg:check {
    id = "lchCh",
    label = "CIE LCH:",
    text = "Light",
    selected = defaults.lchCh,
}

dlg:check {
    id = "lchLh",
    text = "Chroma",
    selected = defaults.lchLh,
}

dlg:check {
    id = "lchLc",
    text = "Hue",
    selected = defaults.lchLc,
}

dlg:check {
    id = "labab",
    label = "CIE LAB:",
    text = "Light",
    selected = defaults.labab,
}

dlg:check {
    id = "labLb",
    text = "A",
    selected = defaults.labLb,
}

dlg:check {
    id = "labLa",
    text = "B",
    selected = defaults.labLa
}

dlg:check {
    id = "manifest",
    label = "Manifest:",
    selected = defaults.manifest
}

dlg:check {
    id = "coverage",
    label = "Coverage:",
    selected = defaults.coverage,
    onclick = function()
        local cvg = dlg.data.coverage
        dlg:modify{
            id = "cvgSat",
            visible = cvg
        }

        dlg:modify{
            id = "cvgRad",
            visible = cvg
        }

        dlg:modify{
            id = "cvgCapacity",
            visible = cvg
        }
    end
}

dlg:slider {
    id = "cvgSat",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.cvgSat,
    visible = defaults.coverage == true
}

dlg:slider {
    id = "cvgRad",
    label = "Radius:",
    min = 25,
    max = 250,
    value = defaults.cvgRad,
    visible = defaults.coverage == true
}

dlg:slider {
    id = "cvgCapacity",
    label = "Capacity:",
    min = 1,
    max = 32,
    value = defaults.cvgCapacity,
    visible = defaults.coverage == true
}

dlg:check {
    id = "contiguous",
    label = "Contiguous:",
    selected = defaults.contiguous,
    onclick = function()
        local contig = dlg.data.contiguous
        dlg:modify{
            id = "closedLoop",
            visible = contig
        }

        dlg:modify{
            id = "resolution",
            visible = contig
        }
    end
}

dlg:check {
    id = "closedLoop",
    label = "Closed Loop:",
    selected = defaults.closedLoop,
    visible = defaults.contiguous == true
}

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 0,
    max = 128,
    value = defaults.resolution,
    visible = defaults.contiguous == true
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = defaults.bkgColor
}

dlg:newrow { always = false }

dlg:color {
    id = "txtColor",
    label = "Text:",
    color = defaults.txtColor
}

dlg:newrow { always = false }

dlg:color {
    id = "shdColor",
    label = "Shadow:",
    color = defaults.shdColor,
    visible = true
}

dlg:newrow { always = false }

local function fill(image, hex)
    local iterator = image:pixels()
    for elm in iterator do
        elm(hex)
    end
end

local function drawHorizLine(image, x0, x1, y, hex)
    for x = x0, x1, 1 do
        image:drawPixel(x, y, hex)
    end
end

local function drawVertLine(image, x, y0, y1, hex)
    for y = y0, y1, 1 do
        image:drawPixel(x, y, hex)
    end
end

local function drawSwatch(image, x, y, w, h, hex)
    local lenn1 = (w * h) - 1
    for i = 0, lenn1, 1 do
        image:drawPixel(
            x + (i % w),
            y + (i // w),
            hex)
    end
end

local function drawCircleFill(image, xo, yo, r, hex)
    local rsq = r * r
    local r2 = r * 2
    local lenn1 = r2 * r2 - 1
    for i = 0, lenn1, 1 do
        local x = (i % r2) - r
        local y = (i // r2) - r
        if (x * x + y * y) < rsq then
        image:drawPixel(
            xo + x,
            yo + y,
            hex)
        end
    end
end

local function bresenham(image, clr, x0, y0, x1, y1)
    if x0 == x1 and y0 == y1 then return end
    local hex = clr or 0xffffffff
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local x = x0
    local y = y0
    local sx = 0
    local sy = 0

    if x0 < x1 then sx = 1 else sx = -1 end
    if y0 < y1 then sy = 1 else sy = -1 end

    local err = 0
    if dx > dy then err = dx // 2
    else err = -dy // 2 end
    local e2 = 0

    while true do
        -- print("(" .. x .. ", " .. y .. ")")
        image:drawPixel(x, y, hex)
        if x == x1 and y == y1 then break end
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

local function midPointCircleStroke(image, hex, xo, yo, radius)

    local x = radius
    local y = 0

    image:drawPixel(xo + radius, yo, hex)
    image:drawPixel(xo - radius, yo, hex)
    image:drawPixel(xo, yo + radius, hex)
    image:drawPixel(xo, yo - radius, hex)

    local p = 1 - radius
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

        image:drawPixel(xo + x, yo + y, hex)
        image:drawPixel(xo - x, yo + y, hex)
        image:drawPixel(xo + x, yo - y, hex)
        image:drawPixel(xo - x, yo - y, hex)

        if x ~= y then
            image:drawPixel(xo + y, yo + x, hex)
            image:drawPixel(xo - y, yo + x, hex)
            image:drawPixel(xo + y, yo - x, hex)
            image:drawPixel(xo - y, yo - x, hex)
        end
    end
end

local function strToCharArr(str)
    local chars = {}
    for i = 1, #str, 1 do
        chars[i] = str:sub(i, i)
    end
    return chars
end

local function drawHorizShd(
    lut, image, chars, fillHex, shadHex,
    x, y, gw, gh, scale)

    AseUtilities.drawStringHoriz(
        lut, image, chars, shadHex,
        x, y + 1, gw, gh, scale)
    AseUtilities.drawStringHoriz(
        lut, image, chars, fillHex,
        x, y, gw, gh, scale)
end

local function drawVertShd(
    lut, image, chars, fillHex, shadHex,
    x, y, gw, gh, scale)

    AseUtilities.drawStringVert(
        lut, image, chars, shadHex,
        x + 1, y, gw, gh, scale)
    AseUtilities.drawStringVert(
        lut, image, chars, fillHex,
        x, y, gw, gh, scale)
end

local function drawRadial(
    image, lut, gw, gh, margin, title,
    sectors, rings,
    rLabel, rMin, rMax,
    coords, dataHexes,
    txtHex, shdHex, dotRad,
    titleDisplScl, txtDisplScl)

    -- Cache global functions to local.
    local trunc = math.tointeger
    local strfmt = string.format
    local cos = math.cos
    local sin = math.sin

    local wImage = image.width
    local hImage = image.height

    local xCenter = wImage // 2
    local yCenter = hImage // 2

    -- Account for drop shadow offset
    local gwp1 = gw + 1
    -- local ghp1 = gh + 1

    -- Draw title.
    local titleChars = strToCharArr(title)
    local titleGlyphLen = #titleChars
    local titlePxHalfLen = (titleGlyphLen * gwp1 * titleDisplScl) // 2
    drawHorizShd(lut, image, titleChars, txtHex, shdHex,
    xCenter - titlePxHalfLen, margin, gw, gh, titleDisplScl)

    -- All numbers expected to be positive.
    local digLen = 3

    local marginScale = 0.85
    local maxDisplRad = marginScale * 0.5
        * (wImage - margin * 2)
        - digLen * gw
    local minDisplRad = 0.125 * maxDisplRad
        + digLen * gw

    -- Draw concentric rings.
    local iToStep = 1.0 / (rings - 1.0)
    for i = 0, rings - 1, 1 do
        local t = i * iToStep
        local u = 1.0 - t
        local displRad = u * maxDisplRad
                       + t * minDisplRad
        displRad = trunc(0.5 + displRad)

        midPointCircleStroke(
            image, txtHex,
            xCenter, yCenter, displRad)
    end

    -- Draw radial min and max label.
    local rMinStr = strfmt("%03d", trunc(rMin))
    rMinStr = rLabel .. "  " .. rMinStr
    local chars = strToCharArr(rMinStr)
    drawHorizShd(
        lut, image, chars,
        txtHex, shdHex,
        xCenter - (#rMinStr * gwp1 * txtDisplScl) // 2,
        yCenter - gh * txtDisplScl // 2,
        gw, gh, txtDisplScl)

    local rMaxStr = strfmt("%03d", trunc(rMax))
    chars = strToCharArr(rMaxStr)
    drawHorizShd(
        lut, image, chars,
        txtHex, shdHex,
        xCenter + maxDisplRad
            + gw * txtDisplScl * 2,
        yCenter - gh * txtDisplScl // 2,
        gw, gh, txtDisplScl)

    -- Draw labels and sector lines.
    local jToTheta = 6.283185307179586 / sectors
    local jToDeg = 360.0 / sectors
    local labelDisplRad = maxDisplRad * 1.122
    -- local degChar = utf8.char(176)
    for j = 0, sectors - 1 , 1 do
        local theta = j * jToTheta
        local cosTheta = cos(theta)
        local sinTheta = -sin(theta)

        local x0 = minDisplRad * cosTheta
        local y0 = minDisplRad * sinTheta
        local x1 = maxDisplRad * cosTheta
        local y1 = maxDisplRad * sinTheta

        x0 = x0 + xCenter
        y0 = y0 + yCenter
        x1 = x1 + xCenter
        y1 = y1 + yCenter

        x0 = trunc(0.5 + x0)
        y0 = trunc(0.5 + y0)
        x1 = trunc(0.5 + x1)
        y1 = trunc(0.5 + y1)

        bresenham(image, txtHex, x0, y0, x1, y1)

        -- Skip theta == 0 or 360 degrees.
        if j > 0 then
            local degrees = j * jToDeg
            degrees = trunc(0.5 + degrees)
            local degStr = strfmt("%03d", degrees)
            chars = strToCharArr(degStr)

            local xLabel = labelDisplRad * cosTheta
            local yLabel = labelDisplRad * sinTheta

            xLabel = xLabel + xCenter
            yLabel = yLabel + yCenter

            xLabel = xLabel - digLen * gw * txtDisplScl * 0.5
            yLabel = yLabel - gh * txtDisplScl * 0.5

            xLabel = trunc(0.5 + xLabel)
            yLabel = trunc(0.5 + yLabel)

            drawHorizShd(
                lut, image, chars,
                txtHex, shdHex,
                xLabel, yLabel,
                gw, gh, txtDisplScl)
        end
    end

    -- Draw swatches.
    local origDiff = rMax - rMin
    local displDiff = maxDisplRad - minDisplRad
    local denom = 0.0
    if origDiff ~= 0 then denom = 1.0 / origDiff end
    for k = 1, #coords, 1 do
        local coord = coords[k]

        local theta = coord.t
        local cosTheta = cos(theta)
        local sinTheta = -sin(theta)

        local origRad = coord.r
        local displRad = minDisplRad
            + displDiff * ((origRad - rMin) * denom)

        local x = xCenter + displRad * cosTheta
        local y = yCenter + displRad * sinTheta

        drawCircleFill(image, x, y, dotRad,
            dataHexes[k])
    end

end

local function drawScatter(
    image,
    lut, gw, gh,
    margin,
    title, xAxisLabel, yAxisLabel,
    pipCount,
    xMin, xMax, yMin, yMax,
    coords, dataHexes,
    txtHex, shdHex,
    dotRad, titleDisplScl, txtDisplScl)

    -- Cache global functions to local.
    local trunc = math.tointeger
    local strfmt = string.format

    local wImage = image.width
    local hImage = image.height

    -- Account for drop shadow offset
    local gwp1 = gw + 1
    local ghp1 = gh + 1

    -- A positive or negative sign,
    -- plus 3 digits
    local digLen = 4

    -- Draw title.
    local titleChars = strToCharArr(title)
    local titleGlyphLen = #titleChars
    local titlePxHalfLen = (titleGlyphLen * gwp1 * titleDisplScl) // 2
    local xImgCenter = wImage // 2
    drawHorizShd(lut, image, titleChars, txtHex, shdHex,
    xImgCenter - titlePxHalfLen, margin, gw, gh, titleDisplScl)

    local displayTop = margin + ghp1 * titleDisplScl + margin
    local displayRight = wImage - 1 - margin

    local xAxisPipsRight = displayRight - gwp1 * digLen * txtDisplScl

    -- TODO: Clean this up.
    local xAxisPipsTop = hImage - margin
        - ghp1 * txtDisplScl - margin -- x axis label
        - ghp1 * txtDisplScl-- horizontal pips

    local yAxisPipsBottom = xAxisPipsTop
        - ghp1 * txtDisplScl - margin -- one more up
    local yAxisPipsLeft = margin + ghp1 * txtDisplScl + margin
    local yRulex = yAxisPipsLeft + gwp1 * txtDisplScl * digLen + margin - 1
    local xAxisPipsLeft = yRulex + margin

    local yRuleBottom = xAxisPipsTop - margin - 1
    local xRuley = yRuleBottom

    local swatchHalf = dotRad // 2

    local displayLeft = yRulex + margin + margin + dotRad
    local displayBottom = xRuley - margin - swatchHalf - dotRad

    displayRight = displayRight - swatchHalf

    local pipToStep = 1.0 / (pipCount - 1.0)
    for i = 0, pipCount - 1, 1 do
        local t = i * pipToStep
        local u = 1.0 - t

        local x = u * xAxisPipsLeft
                + t * xAxisPipsRight
        x = trunc(0.5 + x)

        local y = u * displayTop
                + t * yAxisPipsBottom
        y = trunc(0.5 + y)

        local xPip = u * xMin
                   + t * xMax
        xPip = trunc(xPip)
        local xPipStr = strfmt("%+04d", xPip)
        local xPipChars = strToCharArr(xPipStr)
        drawHorizShd(
            lut, image, xPipChars,
            txtHex, shdHex,
            x, xAxisPipsTop,
            gw, gh, txtDisplScl)

        local yPip = u * yMax
                   + t * yMin
        yPip = trunc(yPip)
        local yPipStr = strfmt("%+04d", yPip)
        local yPipChars = strToCharArr(yPipStr)
        drawHorizShd(
            lut, image, yPipChars,
            txtHex, shdHex,
            yAxisPipsLeft, y,
            gw, gh, txtDisplScl)
    end

    -- Draw axes.
    drawHorizLine(image, yRulex, displayRight, xRuley, txtHex)
    drawVertLine(image, yRulex, displayTop, yRuleBottom, txtHex)

    -- Draw y axis label.
    local yLabelChars = strToCharArr(yAxisLabel)
    local yLabelGlyphLen = #yLabelChars
    local yLabelCenter = (displayTop + yRuleBottom) // 2
    local yPxHalfLen = (yLabelGlyphLen * gw * txtDisplScl) // 2
    drawVertShd(lut, image, yLabelChars, txtHex, shdHex,
        margin, yLabelCenter + yPxHalfLen, gw, gh, txtDisplScl)

    -- Draw x axis label.
    local xLabelChars = strToCharArr(xAxisLabel)
    local xLabelGlyphLen = #xLabelChars
    local xLabelCenter = (yRulex + displayRight) // 2
    local xPxHalfLen = (xLabelGlyphLen * gw * txtDisplScl) // 2
    drawHorizShd(lut, image, xLabelChars, txtHex, shdHex,
        xLabelCenter - xPxHalfLen,
        hImage - margin - ghp1 * txtDisplScl, gw, gh, txtDisplScl)

    -- Must map coordinates
    -- from original range
    -- to display range.
    local xDiffOrig = xMax - xMin
    local yDiffOrig = yMax - yMin
    local xDenom = 0.0
    local yDenom = 0.0
    if xDiffOrig ~= 0 then xDenom = 1.0 / xDiffOrig end
    if yDiffOrig ~= 0 then yDenom = 1.0 / yDiffOrig end
    local xScale = displayRight - displayLeft
    local yScale = displayTop - displayBottom

    -- Draw swatches.
    local lenCoords = #coords
    for i = 1, lenCoords, 1 do
        local coord = coords[i]
        local hex = dataHexes[i]

        local xReal = displayLeft + xScale * ((coord.x - xMin) * xDenom)
        local yReal = displayBottom + yScale * ((coord.y - yMin) * yDenom)

        xReal = trunc(0.5 + xReal) - swatchHalf
        yReal = trunc(0.5 + yReal) + swatchHalf

        drawCircleFill(image, xReal, yReal, dotRad, hex)
    end

end

dlg:button {
    id = "ok",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then

                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                local frame = app.activeFrame or 1

                -- Search for appropriate source palette.
                local srcPal = nil
                local palType = args.palType
                if palType == "FILE" then
                    local fp =  args.palFile
                    if fp and #fp > 0 then
                        srcPal = Palette { fromFile = fp }
                    end
                elseif palType == "PRESET" then
                    local pr = args.palPreset
                    if pr and #pr > 0 then
                        srcPal = Palette { fromResource = pr }
                    end
                else
                    srcPal = sprite.palettes[1]
                end

                if srcPal then

                    -- Localize character display constants.
                    local gw = 3
                    local gh = 5
                    local lut = Utilities.GLYPH_LUT

                    -- Unpack arguments.
                    local bkgHex = args.bkgColor.rgbaPixel
                    local txtHex = args.txtColor.rgbaPixel
                    local shdHex = args.shdColor.rgbaPixel
                    local dotRad = math.tointeger(0.5 +
                        math.min(sprite.width, sprite.height) / 52)
                    local pipCount = 5
                    local plotMargin = 2

                    -- No alpha allowed in text colors.
                    txtHex = 0xff000000 | txtHex
                    shdHex = 0xff000000 | shdHex

                    -- Clamp source palette to 256.
                    local startIndex = math.min(
                        #srcPal - 1,
                        args.startIndex)
                    local count = math.min(
                        256,
                        args.count,
                        #srcPal - startIndex)

                    -- Unique values only.
                    -- Alpha is masked out of hexadecimal values.
                    local hexDict = {}
                    for i = 0, count - 1, 1 do
                        local idx = startIndex + i
                        local aseColor = srcPal:getColor(idx)
                        local hex = 0xff000000 | aseColor.rgbaPixel
                        hexDict[hex] = idx
                    end

                    -- Store hexes and indices separately.
                    local hexes = {}
                    local indices = {}
                    local counter = 1
                    for key, value in pairs(hexDict) do
                        indices[counter] = value
                        hexes[counter] = key
                        counter = counter + 1
                    end

                    -- Sort.
                    table.sort(hexes,
                        function(a, b)
                            return hexDict[a] < hexDict[b]
                        end)
                    table.sort(indices)

                    -- Unpack unique entries to data for all displays.
                    local clrs = {}
                    local labs = {}
                    local lchs = {}

                    -- Find lab minimums and maximums.
                    local lMin = 999999
                    local aMin = 999999
                    local bMin = 999999
                    local cMin = 999999

                    local lMax = -999999
                    local aMax = -999999
                    local bMax = -999999
                    local cMax = -999999

                    for i = 1, #hexes, 1 do

                        local clr = Clr.fromHex(hexes[i])
                        local lab = Clr.rgbaToLab(clr)
                        local lch = Clr.labToLch(lab.l, lab.a, lab.b, lab.alpha)

                        if lab.l < lMin then lMin = lab.l end
                        if lab.a < aMin then aMin = lab.a end
                        if lab.b < bMin then bMin = lab.b end
                        if lch.c < cMin then cMin = lch.c end

                        if lab.l > lMax then lMax = lab.l end
                        if lab.a > aMax then aMax = lab.a end
                        if lab.b > bMax then bMax = lab.b end
                        if lch.c > cMax then cMax = lch.c end

                        labs[i] = lab
                        lchs[i] = lch
                        clrs[i] = clr
                    end

                    local manifest = args.manifest
                    if manifest then

                        -- Initialize layer.
                        local manifestLayer = sprite:newLayer()
                        manifestLayer.name = "Manifest"
                        local manifestCel = sprite:newCel(manifestLayer, frame)
                        local manifestImage = Image(768, math.max(256, sprite.height))
                        fill(manifestImage, bkgHex)

                        local brSizeHalf = 4
                        local brSize = brSizeHalf * 2
                        local rows = manifestImage.height // 9

                        local x = 2
                        local y = 2
                        for i = 1, #hexes, 1 do
                            local hex = hexes[i]
                            local index = indices[i]
                            drawSwatch(manifestImage,
                                x + 12, y, brSize, brSize,
                                hex)

                            local idxStr = string.format("%3d", index)
                            local chars = strToCharArr(idxStr)

                            drawHorizShd(
                                lut, manifestImage, chars,
                                txtHex, shdHex,
                                x, y + 1, gw, gh, 1)

                            local clr = clrs[i]
                            local hexStr = Clr.toHexWeb(clr)
                            chars = strToCharArr(hexStr)

                            drawHorizShd(
                                lut, manifestImage, chars,
                                txtHex, shdHex,
                                x + brSize + 13, y + 1, gw, gh, 1)

                            y = y + brSize + 1

                            if i % rows == 0 then
                                x = x + brSize + 44
                                y = 2
                            end
                        end

                        manifestCel.image = manifestImage
                    end

                    local labab = args.labab
                    if labab then
                        -- Initialize layer.
                        local lababLayer = sprite:newLayer()
                        lababLayer.name = "CIE.LAB.Lightness"
                        local lababCel = sprite:newCel(lababLayer, frame)
                        local lababImage = Image(sprite.width, sprite.height)
                        fill(lababImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #labs, 1 do
                            local lab = labs[i]
                            coords[i] = { x = lab.a, y = lab.b }
                        end

                        drawScatter(lababImage, lut, gw, gh, plotMargin,
                        "CIE LAB LIGHTNESS",
                        "GREEN TO RED",
                        "BLUE TO YELLOW",
                        pipCount, aMin, aMax, bMin, bMax,
                        coords, hexes,
                        txtHex, shdHex, dotRad, 2, 1)

                        lababCel.image = lababImage
                    end

                    local labLb = args.labLb
                    if labLb then

                        -- Initialize layer.
                        local labLbLayer = sprite:newLayer()
                        labLbLayer.name = "CIE.LAB.Green.Red"
                        local labLbCel = sprite:newCel(labLbLayer, frame)
                        local labLbImage = Image(sprite.width, sprite.height)
                        fill(labLbImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #labs, 1 do
                            local lab = labs[i]
                            coords[i] = { x = lab.b, y = lab.l }
                        end

                        drawScatter(labLbImage, lut, gw, gh, plotMargin,
                        "CIE LAB GREEN TO RED",
                        "BLUE TO YELLOW",
                        "LIGHTNESS",
                        pipCount, bMin, bMax, lMin, lMax,
                        coords, hexes,
                        txtHex, shdHex, dotRad, 2, 1)

                        labLbCel.image = labLbImage
                    end

                    local labLa = args.labLa
                    if labLa then

                        -- Initialize layer.
                        local labLaLayer = sprite:newLayer()
                        labLaLayer.name = "CIE.LAB.Blue.Yellow"
                        local labLaCel = sprite:newCel(labLaLayer, frame)
                        local labLaImage = Image(sprite.width, sprite.height)
                        fill(labLaImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #labs, 1 do
                            local lab = labs[i]
                            coords[i] = { x = lab.a, y = lab.l }
                        end

                        drawScatter(labLaImage, lut, gw, gh, plotMargin,
                        "CIE LAB BLUE TO YELLOW",
                        "GREEN TO RED",
                        "LIGHTNESS",
                        pipCount, aMin, aMax, lMin, lMax,
                        coords, hexes,
                        txtHex, shdHex, dotRad, 2, 1)

                        labLaCel.image = labLaImage
                    end

                    local lchLc = args.lchLc
                    if lchLc then
                        -- Initialize layer.
                        local lchLcLayer = sprite:newLayer()
                        lchLcLayer.name = "CIE.LCH.Hue"
                        local lchLcCel = sprite:newCel(lchLcLayer, frame)
                        local lchLcImage = Image(sprite.width, sprite.height)
                        fill(lchLcImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #lchs, 1 do
                            local lch = lchs[i]
                            coords[i] = { x = lch.c, y = lch.l }
                        end

                        drawScatter(lchLcImage, lut, gw, gh, 2,
                        "CIE LCH HUE",
                        "CHROMA",
                        "LIGHTNESS",
                        pipCount, cMin, cMax, lMin, lMax,
                        coords, hexes,
                        txtHex, shdHex, dotRad, 2, 1)

                        lchLcCel.image = lchLcImage
                    end

                    local lchLh = args.lchLh
                    if lchLh then
                        -- Initialize layer.
                        local lchLhLayer = sprite:newLayer()
                        lchLhLayer.name = "CIE.LCH.Chroma"
                        local lchLhCel = sprite:newCel(lchLhLayer, frame)
                        local lchLhImage = Image(sprite.width, sprite.height)
                        fill(lchLhImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #lchs, 1 do
                            local lch = lchs[i]
                            coords[i] = {
                                t = lch.h * 6.283185307179586,
                                r = lch.l }
                        end

                        drawRadial(
                            lchLhImage, lut, gw, gh, 2,
                            "CIE LCH CHROMA", 12, 6,
                            "LIGHT", lMin, lMax,
                            coords, hexes,
                            txtHex, shdHex, dotRad, 2, 1)

                        lchLhCel.image = lchLhImage
                    end

                    local lchCh = args.lchCh
                    if lchCh then
                        -- Initialize layer.
                        local lchChLayer = sprite:newLayer()
                        lchChLayer.name = "CIE.LCH.Lightness"
                        local lchChCel = sprite:newCel(lchChLayer, frame)
                        local lchChImage = Image(sprite.width, sprite.height)
                        fill(lchChImage, bkgHex)

                        -- Convert lab data to coordinates.
                        local coords = {}
                        for i = 1, #lchs, 1 do
                            local lch = lchs[i]
                            coords[i] = {
                                t = lch.h * 6.283185307179586,
                                r = lch.c }
                        end

                        drawRadial(
                            lchChImage, lut, gw, gh, 2,
                            "CIE LCH LIGHTNESS", 12, 6,
                            "CHROMA", cMin, cMax,
                            coords, hexes,
                            txtHex, shdHex, dotRad, 2, 1)

                        lchChCel.image = lchChImage
                    end

                    local coverage = args.coverage
                    if coverage then
                        local startTime = os.time()

                        local cvgSat = args.cvgSat * 0.01
                        local cvgRad = args.cvgRad
                        local cvgCapacity = args.cvgCapacity

                        -- Convert from labs to Vec3s.
                        local points = {}
                        for i = 1, #labs, 1 do
                            local lab = labs[i]
                            points[i] = Vec3.new(lab.a, lab.b, lab.l)
                        end

                        -- Create Octree.
                        local bounds = Bounds3.new(
                            Vec3.new(
                                aMin - 0.00001,
                                bMin - 0.00001,
                                lMin - 0.00001),
                            Vec3.new(
                                aMax + 0.00001,
                                bMax + 0.00001,
                                lMax + 0.00001))
                        local octree = Octree.new(bounds, cvgCapacity, 0)
                        Octree.insertAll(octree, points)

                        -- Initialize layer.
                        local cvgLayer = sprite:newLayer()
                        cvgLayer.name = "Coverage"
                        local cvgCel = sprite:newCel(cvgLayer, frame)

                        -- Create image.
                        local w = math.min(384, sprite.width)
                        local h = math.min(384, sprite.height)
                        cvgCel.position = Point(
                            (sprite.width - w) * 0.5,
                            (sprite.height - h) * 0.5)
                        local cvgImage = Image(w, h)
                        local pxlitr = cvgImage:pixels()
                        local i = 0

                        local xToNorm = 1.0 / w
                        local yToNorm = 1.0 / h

                        local hslaToRgba = Clr.hslaToRgba
                        local rgbaToLab = Clr.rgbaToLab
                        local labToRgba = Clr.labToRgba
                        local query = Octree.querySpherical
                        local toHex = Clr.toHex -- QUERY: use toHexUnchecked?

                        for elm in pxlitr do
                            local y = i // w
                            local x = i % w

                            local clr = hslaToRgba(
                                x * xToNorm,
                                cvgSat,
                                1.0 - y * yToNorm,
                                1.0)
                            local lab = rgbaToLab(clr)
                            local labpt = Vec3.new(lab.a, lab.b, lab.l)

                            local results = query(octree, labpt, cvgRad)
                            if #results > 1 then
                                local near = results[1]
                                local nearRgb = labToRgba(near.z, near.x, near.y, 1.0)
                                elm(toHex(nearRgb))
                            else
                                elm(0x00000000)
                            end

                            i = i + 1
                        end

                        cvgCel.image = cvgImage

                        local endTime = os.time()
                        local elapsed = os.difftime(endTime, startTime)
                        -- print("elapsed: " .. string.format("%d", elapsed))
                    end

                    local contiguous = args.contiguous
                    if contiguous then
                        local closedLoop = args.closedLoop
                        local resolution = args.resolution

                        local points = {}
                        for i = 1, #labs, 1 do
                            local lab = labs[i]
                            points[i] = Vec3.new(lab.a, lab.b, lab.l)
                        end

                        local curve = Curve3.fromPoints(closedLoop, points)

                        local sampledPoints = {}
                        local sampledHexes = {}
                        local iToStep = 1.0
                        if closedLoop then
                            iToStep = 1.0 / resolution
                        else
                            iToStep = 1.0 / (resolution - 1)
                        end

                        for i = 0, resolution, 1 do
                            local step = i * iToStep
                            local point = Curve3.eval(curve, step)
                            local clr = Clr.labToRgba(
                                point.z, point.x, point.y, 1.0)
                            local hex = Clr.toHex(clr)

                            local j = i + 1

                            -- Arbitrary 2D projection.
                            sampledPoints[j] = {
                                x = point.x,
                                y = point.y
                            }
                            sampledHexes[j] = hex
                        end

                        -- Initialize layer.
                        local contigLayer = sprite:newLayer()
                        contigLayer.name = "Contiguous"
                        local contigCel = sprite:newCel(contigLayer, frame)
                        local contigImage = Image(sprite.width, sprite.height)
                        fill(contigImage, bkgHex)

                        drawScatter(
                            contigImage, lut, gw, gh, plotMargin,
                            "CONTIGUOUS",
                            "GREEN TO RED",
                            "BLUE TO YELLOW",
                            pipCount, aMin, aMax, bMin, bMax,
                            sampledPoints, sampledHexes,
                            txtHex, shdHex, dotRad, 2, 1)

                        contigCel.image = contigImage

                    end

                else
                    app.alert("The source palette could not be found.")
                end

                -- Restore old color mode.
                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()

            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }