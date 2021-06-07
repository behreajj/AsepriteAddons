dofile("../../support/aseutilities.lua")

local dlg = Dialog { title = "Palette Analysis" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = "ACTIVE",
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

dlg:check {
    id = "manifest",
    label = "Manifest:",
    selected = true,
}

dlg:check {
    id = "labab",
    label = "CIE LAB Lightness:",
    selected = true,
}

dlg:check {
    id = "labLb",
    label = "CIE LAB Red Green:",
    selected = true,
}

dlg:check {
    id = "labLa",
    label = "CIE LAB Blue Yellow:",
    selected = true,
}

dlg:newrow { always = false }

dlg:color{
    id = "txtColor",
    label = "Text:",
    color = Color(255, 245, 215, 255)
}

dlg:newrow { always = false }

dlg:check{
    id = "useShadow",
    label = "Drop Shadow:",
    selected = true,
    onclick = function()
        dlg:modify{
            id = "shdColor",
            visible = dlg.data.useShadow
        }
    end
}

dlg:newrow { always = false }

dlg:color{
    id = "shdColor",
    label = "Shadow:",
    color = Color(0, 0, 0, 255),
    visible = true
}

dlg:newrow { always = false }

dlg:color{
    id = "bkgColor",
    label = "Background:",
    color = Color(38, 38, 38, 255)
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

local function drawGraph(
    image,
    lut,
    gw, gh,
    margin,
    title,
    xAxisLabel,
    yAxisLabel,
    pipCount,
    xMin,
    xMax,
    yMin,
    yMax,
    coords,
    dataHexes,
    txtHex,
    shdHex,
    swatchSize)

    -- Cache global functions to local.
    local trunc = math.tointeger
    local strfmt = string.format

    local wImage = image.width
    local hImage = image.height

    -- Account for drop shadow offset
    local gwp1 = gw + 1
    local ghp1 = gh + 1

    local titleDisplScl = 2
    local txtDisplScl = 1

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

    local swatchHalf = swatchSize // 2

    local displayLeft = yRulex + margin + swatchHalf + 1
    local displayBottom = xRuley - margin - swatchHalf - swatchSize

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

        drawSwatch(image, xReal, yReal, swatchSize, swatchSize, hex)
    end

end

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
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

                    -- No alpha allowed in text colors.
                    txtHex = 0xff000000 | txtHex
                    shdHex = 0xff000000 | shdHex

                    -- Clamp source palette to 256.
                    local srcPalLen = math.min(256, #srcPal)

                    -- Unpack source palette to universally used data.
                    local aseColors = {}
                    local clrs = {}
                    local labs = {}
                    local hexes = {}

                    -- Find lab minimums and maximums.
                    local lMin = 999999
                    local aMin = 999999
                    local bMin = 999999

                    local lMax = -999999
                    local aMax = -999999
                    local bMax = -999999

                    for i = 1, srcPalLen, 1 do
                        local aseColor = srcPal:getColor(i - 1)
                        local clr = AseUtilities.aseColorToClr(aseColor)
                        local lab = Clr.rgbaToLab(clr)
                        local hex = Clr.toHex(clr)

                        if lab.l < lMin then lMin = lab.l end
                        if lab.a < aMin then aMin = lab.a end
                        if lab.b < bMin then bMin = lab.b end

                        if lab.l > lMax then lMax = lab.l end
                        if lab.a > aMax then aMax = lab.a end
                        if lab.b > bMax then bMax = lab.b end

                        aseColors[i] = aseColor
                        clrs[i] = clr
                        labs[i] = lab
                        hexes[i] = hex
                    end

                    local manifest = args.manifest
                    if manifest then

                        -- Initialize layer.
                        local manifestLayer = sprite:newLayer()
                        manifestLayer.name = "Manifest"
                        local manifestCel = sprite:newCel(manifestLayer, frame)
                        local manifestLayer = Image(768, math.max(256, sprite.height))
                        fill(manifestLayer, bkgHex)

                        local brSizeHalf = 4
                        local brSize = brSizeHalf * 2
                        local rows = manifestLayer.height // 9

                        local x = 2
                        local y = 2
                        for i = 1, srcPalLen, 1 do
                            local hex = hexes[i]
                            drawSwatch(manifestLayer,
                                x + 12, y, brSize, brSize,
                                hex)

                            local idxStr = string.format("%3d", i - 1)
                            local chars = strToCharArr(idxStr)

                            drawHorizShd(
                                lut, manifestLayer, chars,
                                txtHex, shdHex,
                                x, y + 1, gw, gh, 1)

                            local clr = clrs[i]
                            local hexStr = Clr.toHexWeb(clr)
                            chars = strToCharArr(hexStr)

                            drawHorizShd(
                                lut, manifestLayer, chars,
                                txtHex, shdHex,
                                x + brSize + 13, y + 1, gw, gh, 1)

                            y = y + brSize + 1

                            if i % rows == 0 then
                                x = x + brSize + 44
                                y = 2
                            end
                        end

                        manifestCel.image = manifestLayer
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

                        drawGraph(lababImage, lut, gw, gh, 2,
                        "CIE LAB LIGHTNESS",
                        "GREEN TO RED",
                        "BLUE TO YELLOW",
                        5, aMin, aMax, bMin, bMax,
                        coords, hexes,
                        txtHex, shdHex, 6)

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

                        drawGraph(labLbImage, lut, gw, gh, 2,
                        "CIE LAB GREEN TO RED",
                        "BLUE TO YELLOW",
                        "LIGHTNESS",
                        5, bMin, bMax, lMin, lMax,
                        coords, hexes,
                        txtHex, shdHex, 6)

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

                        drawGraph(labLaImage, lut, gw, gh, 2,
                        "CIE LAB BLUE TO YELLOW",
                        "GREEN TO RED",
                        "LIGHTNESS",
                        5, aMin, aMax, lMin, lMax,
                        coords, hexes,
                        txtHex, shdHex, 6)

                        labLaCel.image = labLaImage
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