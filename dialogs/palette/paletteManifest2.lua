dofile("../../support/aseutilities.lua")

local palTypes = { "ACTIVE", "FILE", "PRESET" }
local palFormats = { "aseprite", "gpl", "png", "pal" }
local sortPresets = { "ALPHA", "CHROMA", "HUE", "INDEX", "LUMA" }
local sortOrders = { "ASCENDING", "DESCENDING" }

local defaults = {
    title = "Manifest",
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    uniquesOnly = true,
    sortPreset = "INDEX",
    ascDesc = "ASCENDING",


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

        if palType == "FILE" then
            local fp =  args.palFile
            if fp and #fp > 0 then
                -- Palettes loaded from a file _could_ support an
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
            local activeSprite = app.activeSprite
            if activeSprite then
                local palActive = activeSprite.palettes[1]
                if palActive then
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        palActive, startIndex, count)

                    local activeProfile = activeSprite.colorSpace
                    if activeProfile then
                        -- This is a very cheap hack to test for equality,
                        -- but not sure what else can be done here...
                        local apName = activeProfile.name
                        local apNameLc = apName:lower()
                        if apNameLc ~= "srgb" and apNameLc ~= "none" then
                            activeSprite:convertColorSpace(ColorSpace { sRGB = true })
                            hexesSrgb = AseUtilities.asePaletteToHexArr(
                                palActive, startIndex, count)
                            activeSprite:convertColorSpace(activeProfile)
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
                    if not hexDict[hex] then
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

            local sortPreset = args.sortPreset or defaults.sortPreset
            if sortPreset == "ALPHA" then
                local f = function(a, b)
                    return a.alphaSrgb255 < b.alphaSrgb255
                end
                table.sort(palData, f)
            elseif sortPreset == "CHROMA" then
                local f = function(a, b)
                    return a.c < b.c
                end
                table.sort(palData, f)
            elseif sortPreset == "HUE" then
                local f = function(a, b)
                    if a.c < 1 and b.c < 1 then
                        return a.l < b.l
                    elseif a.c < 1 then
                        return true
                    elseif b.c < 1 then
                        return false
                    end

                    local diff = b.h - a.h
                    if math.abs(diff) < 1 then
                        return a.l < b.l
                    end

                    return a.h < b.h
                end
                table.sort(palData, f)
            elseif sortPreset == "LUMA" then
                local f = function(a, b)
                    return a.l < b.l
                end
                table.sort(palData, f)
            end

            local ascDesc = args.ascDesc or defaults.ascDesc
            if ascDesc == "DESCENDING" then
                reverse(palData)
            end

            -- Pal data will not necessarily equal srcHex data
            -- in length.
            local palDataLen = #palData
            local mnsftPalLen = palDataLen
            local palStartIdx = 0
            local prependAlpha = palData[1].hexProfile ~= 0x00000000
            if prependAlpha then
                -- print("alpha must be prepended")
                mnsftPalLen = mnsftPalLen + 1
                palStartIdx = palStartIdx + 1
            end
            local mnfstPalette = Palette(mnsftPalLen)
            for i = 1, palDataLen, 1 do
                local palHex = palData[i].hexProfile
                local aseColor = Color(palHex)
                mnfstPalette:setColor(palStartIdx + i - 1, aseColor)
            end
            if prependAlpha then
                mnfstPalette:setColor(0, Color(0, 0, 0, 0))
            end

            print(AseUtilities.asePaletteToString(mnfstPalette))

            local frameIndex = 1
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