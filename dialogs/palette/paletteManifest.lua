dofile("../../support/textutilities.lua")

local palTypes <const> = { "ACTIVE", "FILE" }
local sortPresets <const> = {
    "A", "ALPHA", "B",
    "CHROMA", "HUE",
    "INDEX", "LUMA"
}
local sortOrders <const> = { "ASCENDING", "DESCENDING" }
local numBases <const> = { "PROFILE", "S_RGB" }

local defaults <const> = {
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
    labDisplay = true,
    lchDisplay = false,
    numBasis = "PROFILE",
    grayHue = "OMIT",
    hdrRepeatRate = 16,
    txtColor = 0xffd7f5ff,
    shdColor = 0xeb000000,
    hdrTxtColor = 0xff79b7d7,
    hdrBkgColor = 0xeb282828,
    rowColor0 = 0xeb181818,
    rowColor1 = 0xeb202020,
    bkgColor = 0xff101010
}

---@param lut table
---@param image Image
---@param chars string[]
---@param rFill integer
---@param gFill integer
---@param bFill integer
---@param aFill integer
---@param rShad integer
---@param gShad integer
---@param bShad integer
---@param aShad integer
---@param x integer
---@param y integer
---@param gw integer
---@param gh integer
---@param scale integer
local function drawCharsHorizShd(
    lut, image, chars,
    rFill, gFill, bFill, aFill,
    rShad, gShad, bShad, aShad,
    x, y, gw, gh, scale)
    local pixels <const> = AseUtilities.getPixels(image)
    local wImage <const> = image.width
    TextUtilities.drawString(
        lut, pixels, wImage, chars,
        rShad, gShad, bShad, aShad,
        x, y + 1, gw, gh, scale)
    TextUtilities.drawString(
        lut, pixels, wImage, chars,
        rFill, gFill, bFill, aFill,
        x, y, gw, gh, scale)
    AseUtilities.setPixels(image, pixels)
end

---@param image Image
---@param hex integer
---@param x integer
---@param y integer
---@param w integer
---@param h integer
local function drawSwatch(image, hex, x, y, w, h)
    local lenn1 <const> = (w * h) - 1
    local i = -1
    while i < lenn1 do
        i = i + 1
        image:drawPixel(
            x + (i % w),
            y + (i // w),
            hex)
    end
end

---@param aseColor Color
---@return Color
local function invertAseColor(aseColor)
    local srgb <const> = AseUtilities.aseColorToClr(aseColor)
    local lab <const> = Clr.sRgbToSrLab2(srgb)
    local inv <const> = Clr.srLab2TosRgb(100 - lab.l, -lab.a, -lab.b, lab.alpha)
    return AseUtilities.clrToAseColor(inv)
end

local dlg <const> = Dialog { title = "Palette Manifest" }

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
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = defaults.maxCount,
    value = defaults.count,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Filter:",
    text = "Uniques",
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
    text = "&Index",
    selected = defaults.idxDisplay
}

dlg:check {
    id = "hexDisplay",
    text = "He&x",
    selected = defaults.hexDisplay
}

dlg:check {
    id = "alphaDisplay",
    text = "Al&pha",
    selected = defaults.alphaDisplay
}

dlg:newrow { always = false }

dlg:check {
    id = "rgbDisplay",
    text = "&RGB",
    selected = defaults.rgbDisplay
}

dlg:check {
    id = "labDisplay",
    text = "&LAB",
    selected = defaults.labDisplay
}

dlg:check {
    id = "lchDisplay",
    text = "LC&H",
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
    options = numBases
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
    id = "invert",
    label = "Theme:",
    text = "&INVERT",
    onclick = function()
        local args <const> = dlg.data

        local txtColor <const> = args.txtColor --[[@as Color]]
        local shdColor <const> = args.shdColor --[[@as Color]]
        local hdrTxtColor <const> = args.hdrTxtColor --[[@as Color]]
        local hdrBkgColor <const> = args.hdrBkgColor --[[@as Color]]
        local rowColor0 <const> = args.rowColor0 --[[@as Color]]
        local rowColor1 <const> = args.rowColor1 --[[@as Color]]
        local bkgColor <const> = args.bkgColor --[[@as Color]]

        dlg:modify { id = "txtColor", color = invertAseColor(txtColor) }
        dlg:modify { id = "shdColor", color = invertAseColor(shdColor) }
        dlg:modify { id = "hdrTxtColor", color = invertAseColor(hdrTxtColor) }
        dlg:modify { id = "hdrBkgColor", color = invertAseColor(hdrBkgColor) }
        dlg:modify { id = "rowColor0", color = invertAseColor(rowColor0) }
        dlg:modify { id = "rowColor1", color = invertAseColor(rowColor1) }
        dlg:modify { id = "bkgColor", color = invertAseColor(bkgColor) }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        -- Force a refresh, this is an extra precaution in case
        -- a Sprite has been opened with an embedded profile, then
        -- closed, or in case a Sprite has been set to a
        -- different color mode, then closed.
        app.refresh()

        local args <const> = dlg.data

        -- Determine how important it is to specify the transparency mask.
        local useMaskIdx = false
        local srcMaskIdx = 0
        local palType = args.palType
            or defaults.palType --[[@as string]]
        if palType == "ACTIVE" then
            local idxActSpr <const> = app.site.sprite
            if idxActSpr then
                local idxActSprClrMd <const> = idxActSpr.colorMode
                useMaskIdx = idxActSprClrMd == ColorMode.INDEXED
                srcMaskIdx = idxActSpr.transparentColor
            end
        end

        local startIndex <const> = args.startIndex
            or defaults.startIndex --[[@as integer]]
        local palCount <const> = args.count
            or defaults.count --[[@as integer]]
        local palFile <const> = args.palFile --[[@as string]]
        local hexesProfile <const>, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, palFile, startIndex, palCount, false)

        -- Set manifest profile.
        -- This should be done BEFORE the manifest sprite is
        -- created, while the reference sprite is active.
        local cpSrgb <const> = ColorSpace { sRGB = true }

        local cpSource = cpSrgb
        if palType == "ACTIVE" and app.site.sprite then
            cpSource = app.site.sprite.colorSpace
            if cpSource == nil then
                cpSource = ColorSpace()
            end
        end

        -- Cache global functions to locals.
        local round <const> = Utilities.round
        local strfmt <const> = string.format
        local strsub <const> = string.sub
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local labToLch <const> = Clr.srLab2ToSrLch
        local strToChars <const> = Utilities.stringToCharArr
        local hexToAse <const> = AseUtilities.hexToAseColor

        -- Do not take the length of hexesSrgb
        -- after this point, as it will potentially
        -- contain nils and premature boundaries.
        local hexesSrgbLen <const> = #hexesSrgb

        -- Stage 1 validate hex integer mask.
        if srcMaskIdx < 0 then srcMaskIdx = 0 end
        if srcMaskIdx > hexesSrgbLen - 1 then srcMaskIdx = 0 end

        -- The goal here should be to give you
        -- diagnostic info, so if two colors are
        -- alpha zero, but otherwise different, that
        -- difference should be retained. That's why
        -- there are no alpha filters.
        local uniquesOnly <const> = args.uniquesOnly
        if uniquesOnly then
            ---@type table<integer, integer>
            local hexDict <const> = {}
            for i = 1, hexesSrgbLen, 1 do
                local hex <const> = hexesSrgb[i]

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
        ---@type table[]
        local palData <const> = {}
        local entryIdx = 1
        for i = 1, hexesSrgbLen, 1 do
            local hexSrgb <const> = hexesSrgb[i]
            if hexSrgb then
                local palIdx <const> = startIndex + i - 1
                local isMaskIdx <const> = palIdx == srcMaskIdx

                local alphaSrgb255 <const> = hexSrgb >> 0x18 & 0xff
                local blueSrgb255 <const> = hexSrgb >> 0x10 & 0xff
                local greenSrgb255 <const> = hexSrgb >> 0x08 & 0xff
                local redSrgb255 <const> = hexSrgb & 0xff

                local webSrgbStr <const> = strfmt("#%06X",
                    (redSrgb255 << 0x10)
                    | (greenSrgb255 << 0x08)
                    | blueSrgb255)

                local blueProfile255 = blueSrgb255
                local greenProfile255 = greenSrgb255
                local redProfile255 = redSrgb255
                local webProfileStr = webSrgbStr

                local hexProfile <const> = hexesProfile[i]
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

                local clr <const> = Clr.new(
                    redSrgb255 / 255.0,
                    greenSrgb255 / 255.0,
                    blueSrgb255 / 255.0,
                    1.0)
                local lab <const> = sRgbToLab(clr)
                local lch <const> = labToLch(
                    lab.l, lab.a, lab.b, 1.0)

                -- Convert values to integers to make them
                -- easier to sort and to make sorting conform
                -- to visual presentation.
                local palEntry <const> = {
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
        local sortPreset <const> = args.sortPreset
            or defaults.sortPreset --[[@as string]]
        if sortPreset == "A" then
            local f <const> = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.a < b.a
            end
            table.sort(palData, f)
        elseif sortPreset == "B" then
            local f <const> = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.b < b.b
            end
            table.sort(palData, f)
        elseif sortPreset == "ALPHA" then
            local f <const> = function(a, b)
                if a.alphaSrgb255 == b.alphaSrgb255 then
                    return a.l < b.l
                end
                return a.alphaSrgb255 < b.alphaSrgb255
            end
            table.sort(palData, f)
        elseif sortPreset == "CHROMA" then
            local f <const> = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                if a.c < 1 and b.c < 1 then return a.l < b.l end
                return a.c < b.c
            end
            table.sort(palData, f)
        elseif sortPreset == "HUE" then
            local f <const> = function(a, b)
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
            local f <const> = function(a, b)
                if a.alphaSrgb255 < 1 and b.alphaSrgb255 < 1 then
                    return a.l < b.l
                end
                if a.alphaSrgb255 < 1 then return true end
                if b.alphaSrgb255 < 1 then return false end
                return a.l < b.l
            end
            table.sort(palData, f)
        end

        local ascDesc <const> = args.ascDesc
            or defaults.ascDesc --[[@as string]]
        if ascDesc == "DESCENDING" then
            Utilities.reverseTable(palData)
        end

        -- Pal data length will not equal srcHex length.
        local lenPalData <const> = #palData
        local spriteHeight = 768
        local spriteWidth = 512

        -- Declare constants.
        local lut <const> = TextUtilities.GLYPH_LUT
        local gw <const> = TextUtilities.GLYPH_WIDTH
        local gh <const> = TextUtilities.GLYPH_HEIGHT
        local txtDispScl <const> = 1
        local dw <const> = txtDispScl * gw
        local dh <const> = txtDispScl * gh

        local swchSize <const> = dh + 1
        local swchOffs <const> = 3
        local swchSizeTotal <const> = swchSize + swchOffs
        local spriteMargin <const> = 2
        local entryPadding <const> = 2
        local colCount <const> = 1

        -- Get args for what to display.
        local idxDisplay <const> = args.idxDisplay --[[@as boolean]]
        local hexDisplay <const> = args.hexDisplay --[[@as boolean]]
        local alphaDisplay <const> = args.alphaDisplay --[[@as boolean]]
        local rgbDisplay <const> = args.rgbDisplay --[[@as boolean]]
        local labDisplay <const> = args.labDisplay --[[@as boolean]]
        local lchDisplay <const> = args.lchDisplay --[[@as boolean]]
        local lumDisplay <const> = lchDisplay or labDisplay

        -- Calculate column offets.
        local idxColOffset <const> = dw * 4 + entryPadding
        local hexColOffset <const> = dw * 8 + entryPadding
        local alphaColOffset <const> = dw * 4 + entryPadding
        local rgbColOffset <const> = dw * 12 + entryPadding
        local lumColOffset <const> = dw * 4 + entryPadding
        local abColOffset <const> = dw * 10 + entryPadding
        local chColOffset <const> = dw * 8 + entryPadding
        -- chColOffset has not been tested to make
        -- sure it is right because there is nothing
        -- to the right of it.

        -- Find width and height of each entry.
        local entryHeight <const> = swchSizeTotal + entryPadding * 2
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
        local hdrRepeatRate <const> = args.hdrRepeatRate or defaults.hdrRepeatRate
        local hdrUseRepeat = true
        if hdrRepeatRate >= (lenPalData - 1) or hdrRepeatRate < 4 then
            hdrUseRepeat = false
        end

        -- Unpack text and text shadow colors.
        local txtColor <const> = args.txtColor --[[@as Color]]
        local shdColor <const> = args.shdColor --[[@as Color]]
        local hdrTxtColor <const> = args.hdrTxtColor --[[@as Color]]
        local hdrBkgColor <const> = args.hdrBkgColor --[[@as Color]]
        local row0Color <const> = args.rowColor0 --[[@as Color]]
        local row1Color <const> = args.rowColor1 --[[@as Color]]
        local bkgColor <const> = args.bkgColor --[[@as Color]]

        -- Convert to hexadecimal.
        local hdrBkgHex <const> = AseUtilities.aseColorToHex(hdrBkgColor, ColorMode.RGB)
        local row0Hex <const> = AseUtilities.aseColorToHex(row0Color, ColorMode.RGB)
        local row1Hex <const> = AseUtilities.aseColorToHex(row1Color, ColorMode.RGB)
        local bkgHex <const> = AseUtilities.aseColorToHex(bkgColor, ColorMode.RGB)

        local rHdr <const> = hdrTxtColor.red
        local gHdr <const> = hdrTxtColor.green
        local bHdr <const> = hdrTxtColor.blue
        local aHdr <const> = hdrTxtColor.alpha

        local rTxt <const> = txtColor.red
        local gTxt <const> = txtColor.green
        local bTxt <const> = txtColor.blue
        local aTxt <const> = txtColor.alpha

        local rShd <const> = shdColor.red
        local gShd <const> = shdColor.green
        local bShd <const> = shdColor.blue
        local aShd <const> = shdColor.alpha

        -- Recalaculate sprite width and height.
        spriteWidth = colCount * entryWidth + spriteMargin * 2
        spriteHeight = entryHeight * (lenPalData + 3) + spriteMargin * 2

        -- Add extra height to image for repeated headers.
        if hdrUseRepeat then
            local extraHeaders = lenPalData // hdrRepeatRate

            -- If the palette data length is even and it is cleanly
            -- divisible by the repeat rate, subtract one.
            -- If the palette data length is odd and either it or one
            -- less is cleanly divisible by the repeat rate, subtract one.
            if (lenPalData % 2 == 0 and lenPalData % hdrRepeatRate == 0)
                or (lenPalData % 2 == 1
                    and ((lenPalData - 1) % hdrRepeatRate == 0
                        or lenPalData % hdrRepeatRate == 0))
            then
                -- print(string.format("%d %% %d = %d",
                -- palDataLen, hdrRepeatRate, palDataLen % hdrRepeatRate))
                extraHeaders = extraHeaders - 1
            end
            spriteHeight = spriteHeight + entryHeight * extraHeaders
        end

        -- Create background image.
        local numBasis <const> = args.numBasis
            or defaults.numBasis --[[@as string]]
        local nbIsSrgb <const> = numBasis == "S_RGB"
        local cpManifest <const> = nbIsSrgb and cpSrgb or cpSource
        local mnfstSpec <const> = AseUtilities.createSpec(
            spriteWidth, spriteHeight, ColorMode.RGB, cpManifest, 0)
        local bkgImg <const> = Image(mnfstSpec)
        bkgImg:clear(bkgHex)

        -- Create footer to display profile name.
        local entrySpec <const> = AseUtilities.createSpec(
            entryWidth, entryHeight, ColorMode.RGB, cpManifest, 0)
        local footImg <const> = Image(entrySpec)
        local footText = "NONE"
        if cpSource.name and #cpSource.name > 0 then
            footText = string.upper(string.sub(cpSource.name, 1, 14))
        end

        footText = "PROFILE: " .. footText
        local footChars <const> = strToChars(footText)
        drawCharsHorizShd(
            lut, footImg, footChars,
            rHdr, gHdr, bHdr, aHdr,
            rShd, gShd, bShd, aShd,
            entryPadding,
            entryPadding,
            gw, gh, txtDispScl)

        -- Create title image.
        local mnfstTitle = args.title or defaults.title --[[@as string]]
        if #mnfstTitle < 1 then mnfstTitle = defaults.title end
        local mnfstTitleDisp = string.sub(mnfstTitle, 1, 14)
        mnfstTitleDisp = string.upper(mnfstTitleDisp)
        local titleImg <const> = Image(entrySpec)
        local titleChars <const> = strToChars(mnfstTitleDisp)
        local titleHalfLen <const> = dw * #titleChars // 2
        drawCharsHorizShd(
            lut, titleImg, titleChars,
            rHdr, gHdr, bHdr, aHdr,
            rShd, gShd, bShd, aShd,
            spriteWidth // 2 - titleHalfLen, entryPadding,
            gw, gh, txtDispScl)

        -- Create templates for alternating rows.
        local row0Tmpl <const> = Image(entrySpec)
        row0Tmpl:clear(row0Hex)

        local row1Tmpl <const> = Image(entrySpec)
        row1Tmpl:clear(row1Hex)

        -- Create header image.
        local hdrImg <const> = Image(entrySpec)
        hdrImg:clear(hdrBkgHex)

        local xCrtHdr = swchSizeTotal + entryPadding

        if idxDisplay then
            local idxChars <const> = strToChars("IDX")
            drawCharsHorizShd(lut, hdrImg, idxChars,
                rHdr, gHdr, bHdr, aHdr,
                rShd, gShd, bShd, aShd,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + idxColOffset
        end

        if hexDisplay then
            local hexChars <const> = strToChars("    HEX")
            drawCharsHorizShd(lut, hdrImg, hexChars,
                rHdr, gHdr, bHdr, aHdr,
                rShd, gShd, bShd, aShd,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + hexColOffset
        end

        if alphaDisplay then
            local hexChars <const> = strToChars("ALP")
            drawCharsHorizShd(lut, hdrImg, hexChars,
                rHdr, gHdr, bHdr, aHdr,
                rShd, gShd, bShd, aShd,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + alphaColOffset
        end

        if rgbDisplay then
            local rgbChars <const> = strToChars("RED GRN BLU")
            drawCharsHorizShd(lut, hdrImg, rgbChars,
                rHdr, gHdr, bHdr, aHdr,
                rShd, gShd, bShd, aShd,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + rgbColOffset
        end

        if lumDisplay then
            local lumChars <const> = strToChars("LUM")
            drawCharsHorizShd(lut, hdrImg, lumChars,
                rHdr, gHdr, bHdr, aHdr,
                rShd, gShd, bShd, aShd,
                xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
            xCrtHdr = xCrtHdr + lumColOffset

            if labDisplay then
                local abChars <const> = strToChars("   A    B")
                drawCharsHorizShd(lut, hdrImg, abChars,
                    rHdr, gHdr, bHdr, aHdr,
                    rShd, gShd, bShd, aShd,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + abColOffset
            end

            if lchDisplay then
                local chChars <const> = strToChars("CRM HUE")
                drawCharsHorizShd(lut, hdrImg, chChars,
                    rHdr, gHdr, bHdr, aHdr,
                    rShd, gShd, bShd, aShd,
                    xCrtHdr, entryPadding + 1, gw, gh, txtDispScl)
                xCrtHdr = xCrtHdr + chColOffset
            end
        end

        -- Create sprite.
        local manifestSprite <const> = AseUtilities.createSprite(
            mnfstSpec, mnfstTitle)

        app.transaction("Set Grid", function()
            manifestSprite.gridBounds = Rectangle(
                spriteMargin, spriteMargin,
                entryWidth, entryHeight)
        end)

        -- This is not necessary. It is retained in case this
        -- script ever needs to use multiple frames.
        local frameObj <const> = manifestSprite.frames[1]

        -- Create background layer and cel.
        local bkgLayer <const> = manifestSprite.layers[1]
        bkgLayer.name = "Bkg"
        manifestSprite:newCel(
            bkgLayer, frameObj, bkgImg)

        -- Create foot layer.
        local yCaret = spriteHeight - spriteMargin - entryHeight
        local footLayer <const> = manifestSprite:newLayer()
        footLayer.name = "Profile"
        manifestSprite:newCel(
            footLayer, frameObj, footImg,
            Point(
                spriteMargin,
                spriteHeight - spriteMargin - entryHeight))
        yCaret = yCaret - entryHeight

        local grayHue <const> = args.grayHue
            or defaults.grayHue --[[@as string]]
        local grIsZero <const> = grayHue == "ZERO"
        local grIsShad <const> = grayHue == "SHADING"

        local swatchMask = 0x0
        local noAlpha <const> = true
        if noAlpha then swatchMask = 0xff000000 end

        app.transaction("Manifest", function()
            -- Proceed in reverse order, from bottom to top, so
            -- layers in stack read from top to bottom.
            local i = lenPalData + 1
            while i > 1 do
                i = i - 1
                local palEntry <const> = palData[i]
                local palIdx <const> = palEntry.palIdx
                local hexSrgb <const> = palEntry.hexSrgb
                local hexProfile <const> = palEntry.hexProfile

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

                local rowLayer <const> = manifestSprite:newLayer()
                rowLayer.name = strfmt("%03d %s",
                    palIdx, strsub(hexWeb, 2))

                if hexSrgb ~= hexProfile then
                    local back <const> = swatchMask
                        | (nbIsSrgb and hexProfile or hexSrgb)
                    local fore <const> = swatchMask
                        | (nbIsSrgb and hexSrgb or hexProfile)

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
                    local halfSz <const> = swchSize // 2
                    if palEntry.l > 50 then
                        pipColor = 0xff000000
                    end
                    drawSwatch(rowImg, pipColor,
                        entryPadding, entryPadding,
                        halfSz, halfSz)
                end

                local xCaret = swchSizeTotal + entryPadding

                if idxDisplay then
                    local idxStr <const> = strfmt("%3d", palIdx)
                    local idxChars <const> = strToChars(idxStr)
                    drawCharsHorizShd(lut, rowImg, idxChars,
                        rTxt, gTxt, bTxt, aTxt,
                        rShd, gShd, bShd, aShd,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + idxColOffset
                end

                if hexDisplay then
                    local hexChars <const> = strToChars(hexWeb)
                    drawCharsHorizShd(lut, rowImg, hexChars,
                        rTxt, gTxt, bTxt, aTxt,
                        rShd, gShd, bShd, aShd,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + hexColOffset
                end

                if alphaDisplay then
                    local alpha <const> = palEntry.alphaSrgb255
                    local alphaStr <const> = strfmt("%3d", alpha)
                    local alphaChars <const> = strToChars(alphaStr)
                    drawCharsHorizShd(lut, rowImg, alphaChars,
                        rTxt, gTxt, bTxt, aTxt,
                        rShd, gShd, bShd, aShd,
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

                    local rgbStr <const> = strfmt("%3d %3d %3d", r, g, b)
                    local rgbChars <const> = strToChars(rgbStr)
                    drawCharsHorizShd(lut, rowImg, rgbChars,
                        rTxt, gTxt, bTxt, aTxt,
                        rShd, gShd, bShd, aShd,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + rgbColOffset
                end

                if lumDisplay then
                    local lum <const> = palEntry.l
                    local lumStr <const> = strfmt("%3d", lum)
                    local lumChars <const> = strToChars(lumStr)
                    drawCharsHorizShd(lut, rowImg, lumChars,
                        rTxt, gTxt, bTxt, aTxt,
                        rShd, gShd, bShd, aShd,
                        xCaret, entryPadding + 1, gw, gh, txtDispScl)
                    xCaret = xCaret + lumColOffset

                    if labDisplay then
                        local a <const> = palEntry.a
                        local b <const> = palEntry.b

                        local abStr = ""
                        if a == 0 then
                            abStr = " 000"
                        else
                            abStr = strfmt("%+04d", a)
                        end
                        if b == 0 then
                            abStr = abStr .. "  000"
                        else
                            abStr = abStr .. strfmt(" %+04d", b)
                        end

                        local abChars <const> = strToChars(abStr)
                        drawCharsHorizShd(lut, rowImg, abChars,
                            rTxt, gTxt, bTxt, aTxt,
                            rShd, gShd, bShd, aShd,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + abColOffset
                    end

                    if lchDisplay then
                        local chroma <const> = palEntry.c
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

                        local chChars <const> = strToChars(chStr)
                        drawCharsHorizShd(lut, rowImg, chChars,
                            rTxt, gTxt, bTxt, aTxt,
                            rShd, gShd, bShd, aShd,
                            xCaret, entryPadding + 1, gw, gh, txtDispScl)
                        xCaret = xCaret + chColOffset
                    end
                end

                local rowCel <const> = manifestSprite:newCel(
                    rowLayer, frameObj, rowImg,
                    Point(spriteMargin, yCaret))
                rowCel.color = hexToAse(hexCel)
                yCaret = yCaret - entryHeight

                -- Always place at least one header at the top.
                -- Otherwise check to see if user wanted repeating headers.
                -- Never place a header at the bottom.
                if i == 1 or (hdrUseRepeat
                        and i < lenPalData
                        and (i - 1) % hdrRepeatRate == 0) then
                    local hdrRptLayer <const> = manifestSprite:newLayer()
                    hdrRptLayer.name = "Header"
                    manifestSprite:newCel(
                        hdrRptLayer, frameObj, hdrImg,
                        Point(spriteMargin, yCaret))
                    yCaret = yCaret - entryHeight
                end
            end
        end)

        -- Create title layer.
        local titleLayer <const> = manifestSprite:newLayer()
        titleLayer.name = "Title"
        manifestSprite:newCel(
            titleLayer, frameObj, titleImg,
            Point(spriteMargin, spriteMargin))

        app.sprite = manifestSprite

        -- Create and set the manifest palette.
        -- Wait to do this until the end, so we have greater
        -- assurance that the manifestSprite is active.
        if nbIsSrgb then
            AseUtilities.setPalette(hexesSrgb,
                manifestSprite, 1)
        else
            AseUtilities.setPalette(hexesProfile,
                manifestSprite, 1)
        end
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

dlg:show {
    autoscrollbars = true,
    wait = false
}