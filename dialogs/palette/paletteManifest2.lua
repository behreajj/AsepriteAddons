dofile("../../support/aseutilities.lua")

-- TODO: Combobox to choose between SRGB and Profile RGB?
local palTypes = { "ACTIVE", "FILE", "PRESET" }
local palFormats = { "aseprite", "gpl", "png", "pal" }
local sortPresets = { "ALPHA", "CHROMA", "HUE", "INDEX", "LUMA" }
local sortOrders = { "ASCENDING", "DESCENDING" }
local grayHues = { "OMIT", "SHADING", "ZERO" }

local defaults = {
    title = "Manifest",
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    uniquesOnly = true,
    sortPreset = "INDEX",
    ascDesc = "ASCENDING",
    idxDisplay = true,
    hexDisplay = true,
    alphaDisplay = false,
    rgbDisplay = false,
    labDisplay = false,
    lchDisplay = true,
    grayHue = "OMIT",
    txtColor = Color(255, 245, 215, 255),
    shdColor = Color(0, 0, 0, 235),
    bkgColor =  Color(16, 16, 16, 255),
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
    max = 256,
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

        local palType = args.palType or defaults.palType
        local startIndex = args.startIndex or defaults.startIndex
        local count = args.count or defaults.count

        local hexesSrgb = nil
        local hexesProfile = nil

        -- TODO: Global conversion to sRGB which is not reverted until
        -- source sprite is no longer active sprite?

        -- TODO: A way to indicate which palette color is indexed as
        -- the transparency/alpha mask? If no active sprite was available
        -- then would default to zero.

        -- Force a refresh, this is an extra precaution in case
        -- a Sprite has been opened with an embedded profile, then
        -- closed, or in case a Sprite has been set to a
        -- different color mode, then closed.
        app.refresh()

        -- Determine how important it is to specify the transparency mask.
        local useMaskIndex = false
        local srcMaskIdx = 0
        if palType == "ACTIVE" then
            local idxActSpr = app.activeSprite
            if idxActSpr then
                -- There's no point in checking: if the original image
                -- is in indexed color mode, then the script wouldn't work
                -- without forcing a color mode conversion...
                -- local idxActSprClrMd = idxActSpr.colorMode
                -- if idxActSprClrMd == ColorMode.INDEXED then
                useMaskIndex = true
                srcMaskIdx = idxActSpr.transparentColor
                -- print(string.format(
                --     "Mask Index (unvalidated): %d",
                --     srcMaskIdx))
                -- end
            end
        end

        -- TODO: This should be its own function in AseUtilities.
        if palType == "FILE" then
            local fp =  args.palFile
            if fp and #fp > 0 then
                -- Palettes loaded from a file COULD support an
                -- embedded color profile hypothetically, but do not.
                -- You could check the extension, and if it is a
                -- .png, .aseprite, etc. then load as a sprite, get
                -- the profile, dispose of the sprite.
                local palFile = Palette { fromFile = fp }
                if palFile then
                    hexesSrgb = AseUtilities.asePaletteToHexArr(
                        palFile, startIndex, count)
                    hexesProfile = hexesSrgb
                end
            end
        elseif palType == "PRESET" then
            local pr = args.palPreset
            if pr and #pr > 0 then
                local palPreset = Palette { fromResource = pr }
                if palPreset then
                    hexesSrgb = AseUtilities.asePaletteToHexArr(
                        palPreset, startIndex, count)
                    hexesProfile = hexesSrgb
                end
            end
        elseif palType == "ACTIVE" then
            local palActSpr = app.activeSprite
            if palActSpr then
                local palActive = palActSpr.palettes[1]
                if palActive then
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palActive, startIndex, count)

                    local activeProfile = palActSpr.colorSpace
                    if activeProfile then
                        -- This is a very cheap hack to test for equality,
                        -- but not sure what else can be done here...
                        local apName = activeProfile.name
                        local apNameLc = apName:lower()
                        if apNameLc ~= "srgb" and apNameLc ~= "none" then
                            palActSpr:convertColorSpace(
                                ColorSpace { sRGB = true })
                            hexesSrgb = AseUtilities.asePaletteToHexArr(
                                palActive, startIndex, count)
                            palActSpr:convertColorSpace(activeProfile)
                        else
                            hexesSrgb = hexesProfile
                        end
                    else
                        hexesSrgb = hexesProfile
                    end
                end
            end
        end

        if hexesSrgb then
            local trunc = math.tointeger
            local sRgbToLab = Clr.sRgbaToLab
            local labToLch = Clr.labToLch

            -- Do not take the length of hexesSrgb
            -- after this point, as it will potentially
            -- contain nils and premature boundaries.
            local hexesSrgbLen = #hexesSrgb

            -- Stage 1 validate hex integer mask.
            if srcMaskIdx < 0 then srcMaskIdx = 0 end
            if srcMaskIdx > hexesSrgbLen - 1 then srcMaskIdx = 0 end
            -- print(string.format(
            --     "Mask Index (1 validation): %d",
            --     srcMaskIdx))

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
                    if (not hexDict[hex]) or (i == srcMaskIdx) then
                        hexDict[hex] = i
                    end
                end

                hexesSrgb = {}
                for k, v in pairs(hexDict) do
                    hexesSrgb[v] = k
                end
            end

            local palData = {}
            for i = 1, hexesSrgbLen, 1 do
                local hexSrgb = hexesSrgb[i]
                if hexSrgb then
                    local palIdx = startIndex + i - 1
                    local isMaskIdx = palIdx == srcMaskIdx

                    local alphaSrgb255 = hexSrgb >> 0x18 & 0xff
                    local blueSrgb255 = hexSrgb >> 0x10 & 0xff
                    local greenSrgb255 = hexSrgb >> 0x08 & 0xff
                    local redSrgb255 = hexSrgb & 0xff

                    local webSrgbStr = string.format("#%06X",
                        (redSrgb255 << 0x10)
                        | (greenSrgb255 << 0x08)
                        | blueSrgb255)

                    -- print(palIdx)
                    -- print(webSrgbStr)

                    -- if isMaskIdx then
                    --     print(palIdx)
                    --     print(webSrgbStr)
                    -- end

                    local blueProfile255 = blueSrgb255
                    local greenProfile255 = greenSrgb255
                    local redProfile255 = redSrgb255
                    local webProfileStr = webSrgbStr

                    local hexProfile = hexesProfile[i]
                    if hexSrgb ~= hexProfile then
                        blueProfile255 = hexProfile >> 0x10 & 0xff
                        greenProfile255 = hexProfile >> 0x08 & 0xff
                        redProfile255 = hexProfile & 0xff

                        webProfileStr = string.format("#%06X",
                            (redProfile255 << 0x10)
                            | (greenProfile255 << 0x08)
                            | blueProfile255)
                        -- print(webProfileStr)
                    end

                    local clr = Clr.new(
                        redSrgb255 * 0.00392156862745098,
                        greenSrgb255 * 0.00392156862745098,
                        blueSrgb255 * 0.00392156862745098,
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

                        l = trunc(0.5 + lab.l),
                        a = round(lab.a),
                        b = round(lab.b),
                        c = trunc(0.5 + lch.c),
                        h = trunc(0.5 + lch.h * 360.0)
                    }

                    table.insert(palData, palEntry)
                end
            end

            -- Treat any transparent color as grayscale.
            local sortPreset = args.sortPreset or defaults.sortPreset
            if sortPreset == "ALPHA" then
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
                reverse(palData)
            end

            -- Pal data length will not equal srcHex length.
            local palDataLen = #palData
            local spriteHeight = 256 -- TODO: Placeholder
            local spriteWidth = 256 -- TODO: Placeholder

            -- Create a manifest palette.
            -- If the original does not have an alpha mask, then
            -- one must be prepended.
            local mnfstPalLen = palDataLen
            local palStartIdx = 0
            local prependAlpha = palData[1].hexProfile ~= 0x00000000
            if prependAlpha then
                mnfstPalLen = mnfstPalLen + 1
                palStartIdx = palStartIdx + 1
            end
            local mnfstPal = Palette(mnfstPalLen)
            for i = 1, palDataLen, 1 do
                local palHex = palData[i].hexProfile
                local aseColor = Color(palHex)
                mnfstPal:setColor(palStartIdx + i - 1, aseColor)
            end

            if prependAlpha then
                mnfstPal:setColor(0, Color(0, 0, 0, 0))
            end

            -- print(AseUtilities.asePaletteToString(mnfstPal))

            -- Set manifest profile.
            local mnfstClrPrf = nil
            if palType == "ACTIVE" and app.activeSprite then
                mnfstClrPrf = app.activeSprite.colorSpace
                if mnfstClrPrf == nil then
                    mnfstClrPrf = ColorSpace()
                end
            else
                mnfstClrPrf = ColorSpace { sRGB = true }
            end

            -- Declare constants.
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
            local entryHeight = swatchSize + entryPadding * 2
            local entryWidth = swatchSize + entryPadding * 2
            if idxDisplay then entryWidth = entryWidth + idxColOffset end
            if hexDisplay then entryWidth = entryWidth + hexColOffset end
            if alphaDisplay then entryWidth = entryWidth + alphaColOffset end
            if rgbDisplay then entryWidth = entryWidth + rgbColOffset end
            if lumDisplay then entryWidth = entryWidth + lumColOffset end
            if labDisplay then entryWidth = entryWidth + abColOffset end
            if lchDisplay then entryWidth = entryWidth + chColOffset end
            entryWidth = entryWidth - dw
            entryWidth = math.max(entryWidth, 256)

            -- TODO: Order:
            -- Create background image
            -- Create color profile footer image
            -- Create header image
            -- Create row images
            -- Create palette
            -- Find color profile
            -- Create sprite
            -- Assign color profile

            -- Create background image.
            -- TODO: Update sprite width and sprite height.
            local bkgColor = args.bkgColor or defaults.bkgColor
            local bkgHex = bkgColor.rgbaPixel
            local bkgImg = Image(spriteWidth, spriteHeight)
            for elm in bkgImg:pixels() do elm(bkgHex) end

            -- Unpack text and text shadow colors.
            local txtColor = args.txtColor or defaults.txtColor
            local shdColor = args.shdColor or defaults.shdColor
            local txtHex = txtColor.rgbaPixel
            local shdHex = shdColor.rgbaPixel

            -- Create footer to display profile name.
            local footImg = Image(entryWidth, entryHeight)
            local footText = string.upper(string.sub(mnfstClrPrf.name, 1, 12))
            footText = "PROFILE: " .. footText
            local footChars = strToCharArr(footText)
            drawCharsHorizShd(
                lut, footImg, footChars,
                txtHex, shdHex,
                entryPadding,
                entryPadding,
                gw, gh, txtDispScl)

            local manifestSprite = Sprite(spriteWidth, spriteHeight)

            local mnfstTitle = args.title or defaults.title
            mnfstTitle = string.upper(string.sub(mnfstTitle, 1, 12))
            manifestSprite.filename = mnfstTitle
            manifestSprite:setPalette(mnfstPal)

            local frameIndex = 1

            -- Create background layer and cel.
            local bkgLayer = manifestSprite.layers[1]
            bkgLayer.name = "Bkg"
            bkgLayer.color = bkgColor
            local bkgCel = manifestSprite:newCel(
                bkgLayer, frameIndex, bkgImg)

            local footLayer = manifestSprite:newLayer()
            footLayer.name = "Profile"
            local footCel = manifestSprite:newCel(
                footLayer, frameIndex, footImg,
                Point(spriteMargin, spriteHeight - spriteMargin - entryHeight))

            -- TODO: In revision, title should be on a separate layer.

            -- Assign Color Space as late as possible.
            manifestSprite:assignColorSpace(mnfstClrPrf)
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