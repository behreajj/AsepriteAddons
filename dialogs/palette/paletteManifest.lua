dofile("../../support/aseutilities.lua")

local palOptions = { "ACTIVE", "FILE", "PRESET" }
local grayHues = { "OMIT", "SHADING", "ZERO" }
local sortOptions = { "CHROMA", "HUE", "INDEX", "LUMA" }

local defaults = {
    title = "Manifest",
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    sortPreset = "INDEX",
    txtColor = Color(255, 245, 215, 255),
    shdColor = Color(0, 0, 0, 235),
    hdrTxtColor = Color(215, 183, 121, 255),
    hdrBkgColor = Color(40, 40, 40, 235),
    hdrRepeatRate = 16,
    bkgColor =  Color(16, 16, 16, 255),
    rowColor0 = Color(24, 24, 24, 235),
    rowColor1 = Color(32, 32, 32, 235),
    idxDisplay = true,
    hexDisplay = true,
    alphaDisplay = false,
    rgbDisplay = false,
    labDisplay = false,
    lchDisplay = true,
    grayHue = "OMIT",
    pullFocus = false
}

local function drawCharsHorizShd(
    lut, image, chars, fillHex, shadHex,
    x, y, gw, gh, scale)

    AseUtilities.drawStringHoriz(
        lut, image, chars, shadHex,
        x, y + 1, gw, gh, scale)
    AseUtilities.drawStringHoriz(
        lut, image, chars, fillHex,
        x, y, gw, gh, scale)
end

local function drawSwatch(image, hex, x, y, w, h)
    local lenn1 = (w * h) - 1
    for i = 0, lenn1, 1 do
        image:drawPixel(
            x + (i % w),
            y + (i // w),
            hex)
    end
end

local function reverse(t)
    -- https://programming-idioms.org/
    -- idiom/19/reverse-a-list/1314/lua
    local n = #t
    local i = 1
    while i < n do
        t[i], t[n] = t[n], t[i]
        i = i + 1
        n = n - 1
    end
end

local function round(x)
    if x < -0.000001 then
        return math.tointeger(x - 0.5)
    end
    if x > 0.000001 then
        return math.tointeger(x + 0.5)
    end
    return 0
end

local function strToCharArr(str)
    local chars = {}
    for i = 1, #str, 1 do
        chars[i] = str:sub(i, i)
    end
    return chars
end

local dlg = Dialog { title = "Palette Manifest" }

dlg:entry {
    id = "title",
    label = "Title:",
    text = defaults.title,
    focus = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palOptions,
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
    filetypes = { "aseprite", "gpl", "pal" },
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.palType == "PRESET"
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

dlg:combobox {
    id = "sortPreset",
    label = "Sort:",
    option = defaults.sortPreset,
    options = sortOptions
}

dlg:combobox {
    id = "ascDesc",
    option = "ASCENDING",
    options = {"ASCENDING", "DESCENDING"}
}

dlg:newrow { always = false }

dlg:check {
    id = "idxDisplay",
    label = "Display:",
    text = "Index",
    selected = defaults.idxDisplay
}

dlg:check {
    id = "hexDisplay",
    text = "Hex",
    selected = defaults.hexDisplay
}

dlg:check {
    id = "alphaDisplay",
    text = "Alpha",
    selected = defaults.alphaDisplay
}

dlg:newrow { always = false }

dlg:check {
    id = "rgbDisplay",
    text = "sRGB",
    selected = defaults.rgbDisplay
}

dlg:check {
    id = "labDisplay",
    text = "LAB",
    selected = defaults.labDisplay
}

dlg:check {
    id = "lchDisplay",
    text = "LCH",
    selected = defaults.lchDisplay,
    onclick = function()
        dlg:modify {
            id = "grayHue",
            visible = dlg.data.lchDisplay
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "grayHue",
    label = "Gray Hue:",
    option = defaults.grayHue,
    options = grayHues,
    visible = defaults.lchDisplay == true
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
    color = defaults.shdColor
}

dlg:newrow { always = false }

dlg:color {
    id = "hdrTxtColor",
    label = "Header Text:",
    color = defaults.hdrTxtColor
}

dlg:newrow { always = false }

dlg:color {
    id = "hdrBkgColor",
    label = "Header Bkg:",
    color = defaults.hdrBkgColor
}

dlg:newrow { always = false }

dlg:slider {
    id = "hdrRepeatRate",
    label = "Frequency:",
    min = 0,
    max = 128,
    value = defaults.hdrRepeatRate
}

dlg:newrow { always = false }

dlg:color {
    id = "rowColor0",
    label = "Row:",
    color = defaults.rowColor0
}

dlg:color {
    id = "rowColor1",
    color = defaults.rowColor1
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = defaults.bkgColor
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

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
        elseif palType == "ACTIVE" and app.activeSprite then
            local activeProfile = app.activeSprite.colorSpace
            app.activeSprite:convertColorSpace(ColorSpace{ sRGB = true })
            srcPal = app.activeSprite.palettes[1]
            app.activeSprite:convertColorSpace(activeProfile)
        end

        if srcPal then
            local strfmt = string.format
            local trunc = math.tointeger
            local min = math.min
            local rgbToLab = Clr.sRgbaToLab
            local labToLch = Clr.labToLch
            local toHexWeb = Clr.toHexWebUnchecked
            local aseToClr = AseUtilities.aseColorToClr

            local startIndex = args.startIndex or defaults.startIndex
            local count = args.count or defaults.count

            local txtColor = args.txtColor or defaults.txtColor
            local shdColor = args.shdColor or defaults.shdColor
            local hdrTxtColor = args.hdrTxtColor or defaults.hdrTxtColor
            local hdrBkgColor = args.hdrBkgColor or defaults.hdrBkgColor
            local bkgColor = args.bkgColor or defaults.bkgColor
            local row0Color = args.row0Color or defaults.rowColor0
            local row1Color = args.row1Color or defaults.rowColor1
            local grayHue = args.grayHue or defaults.grayHue

            local idxDisplay = args.idxDisplay
            local hexDisplay = args.hexDisplay
            local alphaDisplay = args.alphaDisplay
            local rgbDisplay = args.rgbDisplay
            local labDisplay = args.labDisplay
            local lchDisplay = args.lchDisplay

            local lumDisplay = lchDisplay or labDisplay

            local srcPalLen = #srcPal
            startIndex = min(srcPalLen - 1, startIndex)
            count = min(256, count, srcPalLen - startIndex)

            local palData = {}
            for i = 0, count - 1, 1 do
                local idx = startIndex + i
                local aseColor = srcPal:getColor(idx)
                local clr = aseToClr(aseColor)
                local lab = rgbToLab(clr)
                local lch = labToLch(
                    lab.l, lab.a, lab.b, lab.alpha)

                local palEntry = {
                    a = lab.a,
                    ase = aseColor,
                    b = lab.b,
                    chroma = lch.c,
                    hex =  0xff000000 | aseColor.rgbaPixel,
                    hexWebStr = toHexWeb(clr),
                    hue = lch.h * 360.0,
                    idx = idx,
                    lum = lab.l
                }

                if alphaDisplay then
                    palEntry.alpha = aseColor.alpha
                end

                if rgbDisplay then
                    palEntry.red = aseColor.red
                    palEntry.green = aseColor.green
                    palEntry.blue = aseColor.blue
                end

                palData[1 + i] = palEntry
            end

            local sortPreset = args.sortPreset or defaults.sortPreset
            if sortPreset == "CHROMA" then
                local f = function(a, b)
                    return a.chroma < b.chroma
                end
                table.sort(palData, f)
            elseif sortPreset == "HUE" then
                local f = function(a, b)
                    if a.chroma < 1 and b.chroma < 1 then
                        return a.lum < b.lum
                    elseif a.chroma < 1 then
                        return true
                    elseif b.chroma < 1 then
                        return false
                    end

                    -- Epsilon is guesswork.
                    local diff = b.hue - a.hue
                    if math.abs(diff) < 0.275 then
                        return a.lum < b.lum
                    end

                    return a.hue < b.hue
                end
                table.sort(palData, f)
            elseif sortPreset == "LUMA" then
                local f = function(a, b)
                    return a.lum < b.lum
                end
                table.sort(palData, f)
            end

            local ascDesc = args.ascDesc
            if ascDesc == "DESCENDING" then
                reverse(palData)
            end

            local frame = 1

            local gw = 8
            local gh = 8
            local lut = Utilities.GLYPH_LUT
            local txtDispScl = 1
            local dw = txtDispScl * gw
            local dh = txtDispScl * gh

            local swatchSize = dh + 1
            local spriteMargin = 2
            local entryPadding = 2
            local colCount = 1

            -- Calculate column offets.
            local idxColOffset = dw * 4 + entryPadding
            local hexColOffset = dw * 8 + entryPadding
            local alphaColOffset = dw * 4 + entryPadding
            local rgbColOffset = dw * 12 + entryPadding
            local lumColOffset = dw * 4 + entryPadding
            local abColOffset = dw * 10 + entryPadding
            local chColOffset = dw * 8 + entryPadding
            -- chColOffset has not been tested to make
            -- sure it is right because there is nothing
            -- to the right of it.

            local txtHex = txtColor.rgbaPixel
            local shdHex = shdColor.rgbaPixel
            local hdrTxtHex = hdrTxtColor.rgbaPixel
            local hdrBkgHex = hdrBkgColor.rgbaPixel
            local bkgHex = bkgColor.rgbaPixel
            local row0Hex = row0Color.rgbaPixel
            local row1Hex = row1Color.rgbaPixel

            local palDataLen = #palData

            -- Calculate the height and width of each cel.
            local layerHeight = swatchSize + entryPadding * 2
            local layerWidth = swatchSize + entryPadding * 2
            if idxDisplay then layerWidth = layerWidth + idxColOffset end
            if hexDisplay then layerWidth = layerWidth + hexColOffset end
            if alphaDisplay then layerWidth = layerWidth + alphaColOffset end
            if rgbDisplay then layerWidth = layerWidth + rgbColOffset end
            if lumDisplay then layerWidth = layerWidth + lumColOffset end
            if labDisplay then layerWidth = layerWidth + abColOffset end
            if lchDisplay then layerWidth = layerWidth + chColOffset end
            layerWidth = layerWidth - dw
            layerWidth = math.max(layerWidth, swatchSize + entryPadding * 2)

            local hdrRepeatRate = args.hdrRepeatRate or defaults.hdrRepeatRate
            local hdrUseRepeat = true
            if hdrRepeatRate >= palDataLen or hdrRepeatRate < 3 then
                hdrUseRepeat = false
            end
            -- Account for header and title by adding 2 to palDataLen.
            local spriteHeight = layerHeight * (palDataLen + 2) + spriteMargin * 2
            if hdrUseRepeat then
                local extraHeaders = palDataLen // hdrRepeatRate
                if palDataLen % hdrRepeatRate == 0 then
                    extraHeaders = extraHeaders - 1
                end
                spriteHeight = spriteHeight + layerHeight * (extraHeaders)
            end

            local spriteWidth = colCount * layerWidth + spriteMargin * 2

            -- Adjust color space so that color conversions
            -- from sRGB to CIE LAB work properly.
            local sourceColorSpace = nil
            if palType == "ACTIVE" and app.activeSprite then
                sourceColorSpace = app.activeSprite.colorSpace
            else
                sourceColorSpace = ColorSpace { sRGB = true }
            end
            if sourceColorSpace == nil then
                sourceColorSpace = ColorSpace()
            end

            local manifestSprite = Sprite(spriteWidth, spriteHeight)
            local title = args.title or defaults.title
            manifestSprite.filename = title
            manifestSprite:setPalette(srcPal)
            manifestSprite:convertColorSpace(ColorSpace { sRGB = true })

            -- Create background.
            local bkgLayer = manifestSprite.layers[1]
            bkgLayer.name = "Background"
            local bkgImg = Image(spriteWidth, spriteHeight)
            for elm in bkgImg:pixels() do
                elm(bkgHex)
            end
            local bkgCel = manifestSprite:newCel(bkgLayer, frame)
            bkgCel.position = Point(0, 0)

            local xCenter = spriteWidth // 2
            local titleChars = strToCharArr(title:upper())
            local titleHalfLen = dw * #titleChars // 2
            drawCharsHorizShd(lut, bkgImg, titleChars,
                hdrTxtHex, shdHex,
                xCenter - titleHalfLen, entryPadding + 1,
                gw, gh, txtDispScl)

            bkgCel.image = bkgImg

            local row0Bkg = Image(layerWidth, layerHeight)
            for elm in row0Bkg:pixels() do
                elm(row0Hex)
            end

            local row1Bkg = Image(layerWidth, layerHeight)
            for elm in row1Bkg:pixels() do
                elm(row1Hex)
            end

            local hdrImg = Image(layerWidth, layerHeight)
            for elm in hdrImg:pixels() do
                elm(hdrBkgHex)
            end

            -- Create header image.
            local xCrtHdr = swatchSize + entryPadding

            if idxDisplay then
                local idxChars = strToCharArr("IDX")
                drawCharsHorizShd(lut, hdrImg, idxChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + idxColOffset
            end

            if hexDisplay then
                local hexChars = strToCharArr("    HEX")
                drawCharsHorizShd(lut, hdrImg, hexChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + hexColOffset
            end

            if alphaDisplay then
                local hexChars = strToCharArr("ALP")
                drawCharsHorizShd(lut, hdrImg, hexChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + alphaColOffset
            end

            if rgbDisplay then
                local rgbChars = strToCharArr("RED GRN BLU")
                drawCharsHorizShd(lut, hdrImg, rgbChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + rgbColOffset
            end

            if lumDisplay then
                local lumChars = strToCharArr("LUM")
                drawCharsHorizShd(lut, hdrImg, lumChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + lumColOffset

                if labDisplay then
                    local abChars = strToCharArr("   A    B")
                    drawCharsHorizShd(lut, hdrImg, abChars, hdrTxtHex, shdHex,
                        xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                    xCrtHdr = xCrtHdr + abColOffset
                end

                if lchDisplay then
                    local chChars = strToCharArr("CRM HUE")
                    drawCharsHorizShd(lut, hdrImg, chChars, hdrTxtHex, shdHex,
                        xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                    xCrtHdr = xCrtHdr + chColOffset
                end
            end

            -- Proceed in reverse order so layers read from the top down.
            local yCaret = spriteHeight - layerHeight - spriteMargin

            app.transaction(function()
                for i = palDataLen, 1, -1 do
                    if hdrUseRepeat and i ~= palDataLen and i % hdrRepeatRate == 0 then
                        -- This mechanism would need to be reconsidered
                        -- if you ever offered a multiple columns option.
                        local hdrRptLayer = manifestSprite:newLayer()
                        hdrRptLayer.name = "HEADER"
                        local hdrRptCel = manifestSprite:newCel(hdrRptLayer, frame)
                        hdrRptCel.position = Point(spriteMargin, yCaret)
                        hdrRptCel.image = hdrImg

                        yCaret = yCaret - layerHeight
                    end

                    local palEntry = palData[i]
                    local palIdx = palEntry.idx
                    local palHex = palEntry.hex
                    local palHexWeb = palEntry.hexWebStr

                    local rowLayer = manifestSprite:newLayer()
                    rowLayer.name = strfmt("%03d.%s",
                        palIdx,
                        string.sub(palHexWeb, 2))
                    rowLayer.data = strfmt("{\"idx\":%d,\"abgr\":%d}", palIdx, palHex)

                    local rowImg = nil
                    if i % 2 ~= 1 then
                        rowImg = row0Bkg:clone()
                    else
                        rowImg = row1Bkg:clone()
                    end

                    local rowCel = manifestSprite:newCel(rowLayer, frame)
                    rowCel.position = Point(spriteMargin, yCaret)

                    drawSwatch(rowImg, palHex,
                        entryPadding, entryPadding,
                        swatchSize, swatchSize)

                    local xCaret = swatchSize + entryPadding

                    if idxDisplay then
                        local idxStr = strfmt("%3d", palIdx)
                        local idxChars = strToCharArr(idxStr)
                        drawCharsHorizShd(lut, rowImg, idxChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + idxColOffset
                    end

                    if hexDisplay then
                        local hexChars = strToCharArr(palHexWeb)
                        drawCharsHorizShd(lut, rowImg, hexChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + hexColOffset
                    end

                    if alphaDisplay then
                        local alpha = palEntry.alpha
                        local alphaStr = strfmt("%3d", alpha)
                        local alphaChars = strToCharArr(alphaStr)
                        drawCharsHorizShd(lut, rowImg, alphaChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + alphaColOffset
                    end

                    if rgbDisplay then
                        local r = palEntry.red
                        local g = palEntry.green
                        local b = palEntry.blue
                        local rgbStr = strfmt("%3d %3d %3d", r, g, b)
                        local rgbChars = strToCharArr(rgbStr)
                        drawCharsHorizShd(lut, rowImg, rgbChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + rgbColOffset
                    end

                    if lumDisplay then
                        local lum = trunc(0.5 + palEntry.lum)
                        local lumStr = strfmt("%3d", lum)
                        local lumChars = strToCharArr(lumStr)
                        drawCharsHorizShd(lut, rowImg, lumChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + lumColOffset

                        if labDisplay then
                            local a = round(palEntry.a)
                            local b = round(palEntry.b)
                            local abStr = strfmt("%+04d %+04d", a, b)
                            local abChars = strToCharArr(abStr)
                            drawCharsHorizShd(lut, rowImg, abChars, txtHex, shdHex,
                                xCaret, entryPadding + 1, gw, gh, txtDispScl)
                            xCaret = xCaret + abColOffset
                        end

                        if lchDisplay then
                            local chroma = trunc(0.5 + palEntry.chroma)
                            local chStr = strfmt("%3d", chroma)

                            if chroma < 1 then
                                if grayHue == "ZERO" then
                                    -- This option was formerly called "RED", but
                                    -- in LCH, red is hue 40, not 0.
                                    chStr = chStr .. "   0"
                                elseif grayHue == "SHADING" then
                                    local hue = trunc(0.5 + palEntry.hue)
                                    chStr = chStr .. strfmt(" %3d", hue)
                                end
                            elseif chroma > 0 then
                                local hue = trunc(0.5 + palEntry.hue)
                                chStr = chStr .. strfmt(" %3d", hue)
                            end
                            local chChars = strToCharArr(chStr)
                            drawCharsHorizShd(lut, rowImg, chChars, txtHex, shdHex,
                                xCaret, entryPadding + 1, gw, gh, txtDispScl)
                            xCaret = xCaret + chColOffset
                        end
                    end

                    rowCel.image = rowImg
                    yCaret = yCaret - layerHeight
                end

                -- Draw header.
                local hdrLayer = manifestSprite:newLayer()
                hdrLayer.name = "HEADER"
                local hdrCel = manifestSprite:newCel(hdrLayer, frame)
                hdrCel.position = Point(spriteMargin, yCaret)
                hdrCel.image = hdrImg

            end)

            manifestSprite:assignColorSpace(sourceColorSpace)
            app.activeSprite = manifestSprite
            app.refresh()
         else
            app.alert("The source palette could not be found.")
         end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }