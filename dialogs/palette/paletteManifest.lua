dofile("../../support/aseutilities.lua")

local palTypes = { "ACTIVE", "FILE", "PRESET" }
local palFormats = { "aseprite", "gpl", "png", "pal", "webp" }
local sortPresets = {
    "A", "ALPHA", "B",
    "CHROMA", "HUE",
    "INDEX", "LUMA"
}
local sortOrders = { "ASCENDING", "DESCENDING" }
local numBases = { "PROFILE", "SRGB" }

local defaults = {
    maxCount = 512,
    count = 512,
    title = "Manifest",
    palType = "ACTIVE",
    startIndex = 0,
    uniquesOnly = true,
    sortPreset = "INDEX",
    ascDesc = "ASCENDING",
    idxDisplay = true,
    hexDisplay = true,
    alphaDisplay = false,
    rgbDisplay = false,
    labDisplay = false,
    lchDisplay = true,
    numBasis = "PROFILE",
    grayHue = "OMIT",
    hdrRepeatRate = 16,
    txtColor = 0xffd7f5ff,
    shdColor = 0xeb000000,
    hdrTxtColor = 0xff79b7d7,
    hdrBkgColor = 0xeb282828,
    rowColor0 = 0xeb181818,
    rowColor1 = 0xeb202020,
    bkgColor = 0xeb101010,
    pullFocus = false
}

local function drawCharsHorizShd(
    lut, image, chars, fillHex, shadHex,
    x, y, gw, gh, scale)

    AseUtilities.drawString(
        lut, image, chars, shadHex,
        x, y + 1, gw, gh, scale)
    AseUtilities.drawString(
        lut, image, chars, fillHex,
        x, y, gw, gh, scale)
end

local function drawSwatch(image, hex, x, y, w, h)
    local lenn1 = (w * h) - 1
    local i = -1
    while i < lenn1 do i = i + 1
        image:drawPixel(
            x + (i % w),
            y + (i // w),
            hex)
    end
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
    options = palTypes,
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
    filetypes = palFormats,
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
    max = defaults.maxCount,
    value = defaults.count
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Filter:",
    text = "Uniques Only",
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sortPreset",
    label = "Sort:",
    option = defaults.sortPreset,
    options = sortPresets
}

dlg:combobox {
    id = "ascDesc",
    option = defaults.ascDesc,
    options = sortOrders
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
    selected = defaults.hexDisplay,
    onclick = function()
        dlg:modify {
            id = "numBasis",
            visible = dlg.data.hexDisplay
                or dlg.data.rgbDisplay
        }
    end
}

dlg:check {
    id = "alphaDisplay",
    text = "Alpha",
    selected = defaults.alphaDisplay
}

dlg:newrow { always = false }

dlg:check {
    id = "rgbDisplay",
    text = "RGB",
    selected = defaults.rgbDisplay,
    onclick = function()
        dlg:modify {
            id = "numBasis",
            visible = dlg.data.hexDisplay
                or dlg.data.rgbDisplay
        }
    end
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
        -- dlg:modify {
        --     id = "grayHue",
        --     visible = dlg.data.lchDisplay
        -- }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "numBasis",
    label = "Basis:",
    option = defaults.numBasis,
    options = numBases,
    visible = defaults.hexDisplay
        or defaults.rgbDisplay
}

dlg:newrow { always = false }

dlg:color {
    id = "txtColor",
    label = "Text:",
    color = AseUtilities.hexToAseColor(defaults.txtColor)
}

-- dlg:newrow { always = false }

dlg:color {
    id = "shdColor",
    -- label = "Shadow:",
    color = AseUtilities.hexToAseColor(defaults.shdColor)
}

dlg:newrow { always = false }

dlg:color {
    id = "hdrTxtColor",
    -- label = "Header Text:",
    label = "Header:",
    color = AseUtilities.hexToAseColor(defaults.hdrTxtColor)
}

-- dlg:newrow { always = false }

dlg:color {
    id = "hdrBkgColor",
    -- label = "Header Bkg:",
    color = AseUtilities.hexToAseColor(defaults.hdrBkgColor)
}

dlg:newrow { always = false }

dlg:slider {
    id = "hdrRepeatRate",
    -- label = "Repeat:",
    min = 0,
    max = 128,
    value = defaults.hdrRepeatRate
}

dlg:newrow { always = false }

dlg:color {
    id = "rowColor0",
    label = "Row:",
    color = AseUtilities.hexToAseColor(defaults.rowColor0)
}

dlg:color {
    id = "rowColor1",
    color = AseUtilities.hexToAseColor(defaults.rowColor1)
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = AseUtilities.hexToAseColor(defaults.bkgColor)
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Force a refresh, this is an extra precaution in case
        -- a Sprite has been opened with an embedded profile, then
        -- closed, or in case a Sprite has been set to a
        -- different color mode, then closed.
        app.refresh()

        local args = dlg.data

        -- Determine how important it is to specify the transparency mask.
        local useMaskIdx = false
        local srcMaskIdx = 0
        local palType = args.palType or defaults.palType
        if palType == "ACTIVE" then
            local idxActSpr = app.activeSprite
            if idxActSpr then
                local idxActSprClrMd = idxActSpr.colorMode
                useMaskIdx = idxActSprClrMd == ColorMode.INDEXED
                srcMaskIdx = idxActSpr.transparentColor
            end
        end

        local startIndex = args.startIndex or defaults.startIndex
        local palCount = args.count or defaults.count
        local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, args.palFile, args.palPreset,
            startIndex, palCount, false)

        -- Set manifest profile.
        -- This should be done BEFORE the manifest sprite is
        -- created, while the reference sprite is active.
        local mnfstClrPrf = nil
        if palType == "ACTIVE" and app.activeSprite then
            mnfstClrPrf = app.activeSprite.colorSpace
            if mnfstClrPrf == nil then
                mnfstClrPrf = ColorSpace()
            end
        else
            mnfstClrPrf = ColorSpace { sRGB = true }
        end

        -- Cache global functions to locals.
        local round = Utilities.round
        local strfmt = string.format
        local sRgbToLab = Clr.sRgbToCieLab
        local labToLch = Clr.cieLabToCieLch
        local strToChars = Utilities.stringToCharTable

        -- Do not take the length of hexesSrgb
        -- after this point, as it will potentially
        -- contain nils and premature boundaries.
        local hexesSrgbLen = #hexesSrgb

        -- Stage 1 validate hex integer mask.
        if srcMaskIdx < 0 then srcMaskIdx = 0 end
        if srcMaskIdx > hexesSrgbLen - 1 then srcMaskIdx = 0 end

        -- The goal here should be to give you
        -- diagnostic info, so if two colors are
        -- alpha zero, but otherwise different, that
        -- difference should be retained. That's why
        -- there are no alpha filters.
        local uniquesOnly = args.uniquesOnly
        if uniquesOnly then
            local hexDict = {}
            for i = 1, hexesSrgbLen, 1 do
                local hex = hexesSrgb[i]

                -- Mask color should be included even if it is
                -- already present in palette at another index.
                if (not hexDict[hex]) or ((i - 1) == srcMaskIdx) then
                    hexDict[hex] = i
                end
            end

            hexesSrgb = {}
            for k, v in pairs(hexDict) do
                hexesSrgb[v] = k
            end
        end

        -- Package together different representations
        -- of color into one object, so that all can
        -- remain affiliated when the data are sorted.
        local palData = {}
        local entryIdx = 1
        for i = 1, hexesSrgbLen, 1 do
            local hexSrgb = hexesSrgb[i]
            if hexSrgb then
                local palIdx = startIndex + i - 1
                local isMaskIdx = palIdx == srcMaskIdx

                local alphaSrgb255 = hexSrgb >> 0x18 & 0xff
                local blueSrgb255 = hexSrgb >> 0x10 & 0xff
                local greenSrgb255 = hexSrgb >> 0x08 & 0xff
                local redSrgb255 = hexSrgb & 0xff

                local webSrgbStr = strfmt("#%06X",
                    (redSrgb255 << 0x10)
                    | (greenSrgb255 << 0x08)
                    | blueSrgb255)

                local blueProfile255 = blueSrgb255
                local greenProfile255 = greenSrgb255
                local redProfile255 = redSrgb255
                local webProfileStr = webSrgbStr

                local hexProfile = hexesProfile[i]
                if hexSrgb ~= hexProfile then
                    blueProfile255 = hexProfile >> 0x10 & 0xff
                    greenProfile255 = hexProfile >> 0x08 & 0xff
                    redProfile255 = hexProfile & 0xff

                    webProfileStr = strfmt("#%06X",
                        (redProfile255 << 0x10)
                        | (greenProfile255 << 0x08)
                        | blueProfile255)
                    -- print(webProfileStr)
                end

                local clr = Clr.new(
                    redSrgb255 * 0.003921568627451,
                    greenSrgb255 * 0.003921568627451,
                    blueSrgb255 * 0.003921568627451,
                    1.0)
                local lab = sRgbToLab(clr)
                local lch = labToLch(
                    lab.l, lab.a, lab.b, 1.0)

                -- Convert values to integers to make them
                -- easier to sort and to make sorting conform
                -- to visual presentation.
                local palEntry = {
                    palIdx = palIdx,
                    isMaskIdx = isMaskIdx,

                    hexSrgb = hexSrgb,
                    webSrgbStr = webSrgbStr,

                    alphaSrgb255 = alphaSrgb255,
                    blueSrgb255 = blueSrgb255,
                    greenSrgb255 = greenSrgb255,
                    redSrgb255 = redSrgb255,

                    hexProfile = hexProfile,
                    webProfileStr = webProfileStr,

                    blueProfile255 = blueProfile255,
                    greenProfile255 = greenProfile255,
                    redProfile255 = redProfile255,

                    l = round(lab.l),
                    a = round(lab.a),
                    b = round(lab.b),
                    c = round(lch.c),
                    h = round(lch.h * 360.0)
                }

                palData[entryIdx] = palEntry
                entryIdx = entryIdx + 1
            end
        end

        -- Treat any transparent color as grayscale.
        local sortPreset = args.sortPreset or defaults.sortPreset
        if sortPreset == "A" then
            local f = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.a < b.a
            end
            table.sort(palData, f)
        elseif sortPreset == "B" then
            local f = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.b < b.b
            end
            table.sort(palData, f)
        elseif sortPreset == "ALPHA" then
            local f = function(a, b)
                if a.alphaSrgb255 == b.alphaSrgb255 then
                    return a.l < b.l
                end
                return a.alphaSrgb255 < b.alphaSrgb255
            end
            table.sort(palData, f)
        elseif sortPreset == "CHROMA" then
            local f = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.c < b.c
            end
            table.sort(palData, f)
        elseif sortPreset == "HUE" then
            local f = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end

                -- Hue is invalid for desaturated colors.
                if a.c < 1 and b.c < 1 then
                    return a.l < b.l
                elseif a.c < 1 then
                    return true
                elseif b.c < 1 then
                    return false
                end

                -- Technically don't need to do fuzzy equals
                -- here, as hue has been refactored to be an int.
                local diff = b.h - a.h
                if math.abs(diff) < 1 then
                    return a.l < b.l
                end

                return a.h < b.h
            end
            table.sort(palData, f)
        elseif sortPreset == "LUMA" then
            local f = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.l < b.l
            end
            table.sort(palData, f)
        end

        local ascDesc = args.ascDesc or defaults.ascDesc
        if ascDesc == "DESCENDING" then
            Utilities.reverseTable(palData)
        end

        -- Pal data length will not equal srcHex length.
        local palDataLen = #palData
        local spriteHeight = 768
        local spriteWidth = 512

        -- Declare constants.
        local gw = 8
        local gh = 8
        local lut = Utilities.GLYPH_LUT
        local txtDispScl = 1
        local dw = txtDispScl * gw
        local dh = txtDispScl * gh

        local swchSize = dh + 1
        local swchOffs = 3
        local swchSizeTotal = swchSize + swchOffs
        local spriteMargin = 2
        local entryPadding = 2
        local colCount = 1

        -- Get user prefs for what to display.
        local idxDisplay = args.idxDisplay
        local hexDisplay = args.hexDisplay
        local alphaDisplay = args.alphaDisplay
        local rgbDisplay = args.rgbDisplay
        local labDisplay = args.labDisplay
        local lchDisplay = args.lchDisplay
        local lumDisplay = lchDisplay or labDisplay

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

        -- Find width and height of each entry.
        local entryHeight = swchSizeTotal + entryPadding * 2
        local entryWidth = swchSizeTotal + entryPadding * 2
        if idxDisplay then entryWidth = entryWidth + idxColOffset end
        if hexDisplay then entryWidth = entryWidth + hexColOffset end
        if alphaDisplay then entryWidth = entryWidth + alphaColOffset end
        if rgbDisplay then entryWidth = entryWidth + rgbColOffset end
        if lumDisplay then entryWidth = entryWidth + lumColOffset end
        if labDisplay then entryWidth = entryWidth + abColOffset end
        if lchDisplay then entryWidth = entryWidth + chColOffset end
        entryWidth = entryWidth - dw
        entryWidth = math.max(entryWidth, 128)

        -- Validate how often to repeat the header.
        local hdrRepeatRate = args.hdrRepeatRate or defaults.hdrRepeatRate
        local hdrUseRepeat = true
        if hdrRepeatRate >= (palDataLen - 1) or hdrRepeatRate < 4 then
            hdrUseRepeat = false
        end

        -- Unpack text and text shadow colors.
        local txtColor = args.txtColor
        local shdColor = args.shdColor
        local hdrTxtColor = args.hdrTxtColor
        local hdrBkgColor = args.hdrBkgColor
        local row0Color = args.rowColor0
        local row1Color = args.rowColor1
        local bkgColor = args.bkgColor

        -- Convert to hexadecimal.
        local txtHex = txtColor.rgbaPixel
        local shdHex = shdColor.rgbaPixel
        local hdrTxtHex = hdrTxtColor.rgbaPixel
        local hdrBkgHex = hdrBkgColor.rgbaPixel
        local row0Hex = row0Color.rgbaPixel
        local row1Hex = row1Color.rgbaPixel
        local bkgHex = bkgColor.rgbaPixel

        -- Recalaculate sprite width and height.
        spriteWidth = colCount * entryWidth + spriteMargin * 2
        spriteHeight = entryHeight * (palDataLen + 3)
            + spriteMargin * 2

        -- Add extra height to image for repeated headers.
        if hdrUseRepeat then
            local extraHeaders = palDataLen // hdrRepeatRate

            -- If the palette data length is even and it is cleanly
            -- divisible by the repeat rate, subtract one.
            -- If the palette data length is odd and either it or one
            -- less is cleanly divisible by the repeat rate, subtract one.
            if (palDataLen % 2 == 0 and palDataLen % hdrRepeatRate == 0)
                or (palDataLen % 2 == 1
                    and ((palDataLen - 1) % hdrRepeatRate == 0
                        or palDataLen % hdrRepeatRate == 0))
            then
                -- print(string.format("%d %% %d = %d",
                -- palDataLen, hdrRepeatRate, palDataLen % hdrRepeatRate))
                extraHeaders = extraHeaders - 1
            end
            spriteHeight = spriteHeight + entryHeight * extraHeaders
        end

        -- Create background image.

        local bkgImg = Image(spriteWidth, spriteHeight, ColorMode.RGB)
        bkgImg:clear(bkgHex)

        -- Create footer to display profile name.
        local footImg = Image(entryWidth, entryHeight, ColorMode.RGB)
        local footText = "NONE"
        if mnfstClrPrf then
            if mnfstClrPrf.name and #mnfstClrPrf.name > 0 then
                footText = string.upper(string.sub(mnfstClrPrf.name, 1, 14))
            end
        end
        footText = "PROFILE: " .. footText
        local footChars = strToChars(footText)
        drawCharsHorizShd(
            lut, footImg, footChars,
            hdrTxtHex, shdHex,
            entryPadding,
            entryPadding,
            gw, gh, txtDispScl)

        -- Create title image.
        local mnfstTitle = args.title or defaults.title
        if #mnfstTitle < 1 then mnfstTitle = defaults.title end
        local mnfstTitleDisp = string.sub(mnfstTitle, 1, 14)
        mnfstTitleDisp = string.upper(mnfstTitleDisp)
        local titleImg = Image(entryWidth, entryHeight, ColorMode.RGB)
        local titleChars = strToChars(mnfstTitleDisp)
        local titleHalfLen = dw * #titleChars // 2
        drawCharsHorizShd(
            lut, titleImg, titleChars,
            hdrTxtHex, shdHex,
            spriteWidth // 2 - titleHalfLen, entryPadding,
            gw, gh, txtDispScl)

        -- Create templates for alternating rows.
        local row0Tmpl = Image(entryWidth, entryHeight, ColorMode.RGB)
        row0Tmpl:clear(row0Hex)

        local row1Tmpl = Image(entryWidth, entryHeight, ColorMode.RGB)
        row1Tmpl:clear(row1Hex)

        -- Create header image.
        local hdrImg = Image(entryWidth, entryHeight, ColorMode.RGB)
        hdrImg:clear(hdrBkgHex)

        local xCrtHdr = swchSizeTotal + entryPadding

        if idxDisplay then
            local idxChars = strToChars("IDX")
            drawCharsHorizShd(lut, hdrImg, idxChars, hdrTxtHex, shdHex,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + idxColOffset
        end

        if hexDisplay then
            local hexChars = strToChars("    HEX")
            drawCharsHorizShd(lut, hdrImg, hexChars, hdrTxtHex, shdHex,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + hexColOffset
        end

        if alphaDisplay then
            local hexChars = strToChars("ALP")
            drawCharsHorizShd(lut, hdrImg, hexChars, hdrTxtHex, shdHex,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + alphaColOffset
        end

        if rgbDisplay then
            local rgbChars = strToChars("RED GRN BLU")
            drawCharsHorizShd(lut, hdrImg, rgbChars, hdrTxtHex, shdHex,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + rgbColOffset
        end

        if lumDisplay then
            local lumChars = strToChars("LUM")
            drawCharsHorizShd(lut, hdrImg, lumChars, hdrTxtHex, shdHex,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + lumColOffset

            if labDisplay then
                local abChars = strToChars("   A    B")
                drawCharsHorizShd(lut, hdrImg, abChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + abColOffset
            end

            if lchDisplay then
                local chChars = strToChars("CRM HUE")
                drawCharsHorizShd(lut, hdrImg, chChars, hdrTxtHex, shdHex,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + chColOffset
            end
        end

        -- Create sprite.
        local manifestSprite = Sprite(spriteWidth, spriteHeight, ColorMode.RGB)
        manifestSprite.filename = mnfstTitle

        -- This is not necessary. It is retained in case this
        -- script ever needs to use multiple frames.
        local frameObj = manifestSprite.frames[1]

        -- Create background layer and cel.
        local bkgLayer = manifestSprite.layers[1]
        bkgLayer.name = "Bkg"
        manifestSprite:newCel(
            bkgLayer, frameObj, bkgImg)

        -- Create foot layer.
        local yCaret = spriteHeight - spriteMargin - entryHeight
        local footLayer = manifestSprite:newLayer()
        footLayer.name = "Profile"
        manifestSprite:newCel(
            footLayer, frameObj, footImg,
            Point(
                spriteMargin,
                spriteHeight - spriteMargin - entryHeight))
        yCaret = yCaret - entryHeight

        -- Proceed in reverse order, from bottom to top, so
        -- layers in stack read from top to bottom.
        local numBasis = args.numBasis or defaults.numBasis
        local nbIsSrgb = numBasis == "SRGB"

        local grayHue = args.grayHue or defaults.grayHue
        local grIsZero = grayHue == "ZERO"
        local grIsShad = grayHue == "SHADING"

        local swatchMask = 0x0
        local noAlpha = true
        if noAlpha then swatchMask = 0xff000000 end

        app.transaction(function()
            for i = palDataLen, 1, -1 do
                local palEntry = palData[i]
                local palIdx = palEntry.palIdx
                local hexSrgb = palEntry.hexSrgb
                local hexProfile = palEntry.hexProfile

                local hexWeb = nil
                local hexCel = nil
                if nbIsSrgb then
                    hexWeb = palEntry.webSrgbStr
                    hexCel = hexSrgb
                else
                    hexWeb = palEntry.webProfileStr
                    hexCel = hexProfile
                end

                local rowImg = nil
                if i % 2 ~= 1 then
                    rowImg = row0Tmpl:clone()
                else
                    rowImg = row1Tmpl:clone()
                end

                local rowLayer = manifestSprite:newLayer()
                rowLayer.name = strfmt("%03d.%s",
                    palIdx, string.sub(hexWeb, 2))

                if hexSrgb ~= hexProfile then
                    local back = swatchMask | hexSrgb
                    local fore = swatchMask | hexProfile

                    drawSwatch(rowImg, back,
                        entryPadding + swchOffs, entryPadding + swchOffs,
                        swchSize, swchSize)

                    drawSwatch(rowImg, fore,
                        entryPadding, entryPadding,
                        swchSize, swchSize)
                else
                    drawSwatch(rowImg, swatchMask | hexProfile,
                        entryPadding, entryPadding,
                        swchSizeTotal, swchSizeTotal)
                end

                if useMaskIdx and palEntry.isMaskIdx then
                    rowLayer.name = rowLayer.name .. " (MASK)"
                    local pipColor = 0xffffffff
                    local halfSz = swchSize // 2
                    if palEntry.l > 50 then
                        pipColor = 0xff000000
                    end
                    drawSwatch(rowImg, pipColor,
                        entryPadding, entryPadding,
                        halfSz, halfSz)
                end

                local xCaret = swchSizeTotal + entryPadding

                if idxDisplay then
                    local idxStr = strfmt("%3d", palIdx)
                    local idxChars = strToChars(idxStr)
                    drawCharsHorizShd(lut, rowImg, idxChars, txtHex, shdHex,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + idxColOffset
                end

                if hexDisplay then
                    local hexChars = strToChars(hexWeb)
                    drawCharsHorizShd(lut, rowImg, hexChars, txtHex, shdHex,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + hexColOffset
                end

                if alphaDisplay then
                    local alpha = palEntry.alphaSrgb255
                    local alphaStr = strfmt("%3d", alpha)
                    local alphaChars = strToChars(alphaStr)
                    drawCharsHorizShd(lut, rowImg, alphaChars, txtHex, shdHex,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + alphaColOffset
                end

                if rgbDisplay then
                    local r = 0
                    local g = 0
                    local b = 0
                    if nbIsSrgb then
                        r = palEntry.redSrgb255
                        g = palEntry.greenSrgb255
                        b = palEntry.blueSrgb255
                    else
                        r = palEntry.redProfile255
                        g = palEntry.greenProfile255
                        b = palEntry.blueProfile255
                    end

                    local rgbStr = strfmt("%3d %3d %3d", r, g, b)
                    local rgbChars = strToChars(rgbStr)
                    drawCharsHorizShd(lut, rowImg, rgbChars, txtHex, shdHex,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + rgbColOffset
                end

                if lumDisplay then
                    local lum = palEntry.l
                    local lumStr = strfmt("%3d", lum)
                    local lumChars = strToChars(lumStr)
                    drawCharsHorizShd(lut, rowImg, lumChars, txtHex, shdHex,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + lumColOffset

                    if labDisplay then
                        local a = palEntry.a
                        local b = palEntry.b

                        local abStr = ""
                        if a == 0 then abStr = " 000"
                        else abStr = strfmt("%+04d", a) end
                        if b == 0 then abStr = abStr .. "  000"
                        else abStr = abStr .. strfmt(" %+04d", b) end

                        local abChars = strToChars(abStr)
                        drawCharsHorizShd(lut, rowImg, abChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + abColOffset
                    end

                    if lchDisplay then
                        local chroma = palEntry.c
                        local chStr = strfmt("%3d", chroma)
                        if chroma < 1 then
                            if grIsZero then
                                chStr = chStr .. "   0"
                            elseif grIsShad then
                                chStr = chStr .. strfmt(" %3d", palEntry.h)
                            end
                        elseif chroma > 0 then
                            chStr = chStr .. strfmt(" %3d", palEntry.h)
                        end

                        local chChars = strToChars(chStr)
                        drawCharsHorizShd(lut, rowImg, chChars, txtHex, shdHex,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + chColOffset
                    end

                end

                local rowCel = manifestSprite:newCel(
                    rowLayer, frameObj, rowImg,
                    Point(spriteMargin, yCaret))
                rowCel.color = Color(hexCel)
                yCaret = yCaret - entryHeight

                -- Always place at least one header at the top.
                -- Otherwise check to see if user wanted repeating headers.
                -- Never place a header at the bottom.
                if i == 1 or (hdrUseRepeat
                    and i < palDataLen
                    and (i - 1) % hdrRepeatRate == 0) then
                    local hdrRptLayer = manifestSprite:newLayer()
                    hdrRptLayer.name = "Header"
                    manifestSprite:newCel(
                        hdrRptLayer, frameObj, hdrImg,
                        Point(spriteMargin, yCaret))
                    yCaret = yCaret - entryHeight
                end
            end
        end)

        -- Create title layer.
        local titleLayer = manifestSprite:newLayer()
        titleLayer.name = "Title"
        manifestSprite:newCel(
            titleLayer, frameObj, titleImg,
            Point(spriteMargin, spriteMargin))

        app.activeSprite = manifestSprite

        -- Create and set the manifest palette.
        -- Wait to do this until the end, so we have greater
        -- assurance that the manifestSprite is app.active.
        AseUtilities.setPalette(hexesProfile,
            manifestSprite, 1)
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }