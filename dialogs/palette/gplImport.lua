dofile("../../support/aseutilities.lua")

local setBoxSize = 13
local setBoxSep = true
if app.preferences then
    local colorBarPrefs <const> = app.preferences.color_bar
    if colorBarPrefs then
        local boxSizeCand <const> = colorBarPrefs.box_size --[[@as integer]]
        if boxSizeCand and boxSizeCand > 0 then
            setBoxSize = boxSizeCand
        end

        local sepCand <const> = colorBarPrefs.entries_separator --[[@as boolean]]
        if sepCand ~= nil then
            setBoxSep = sepCand
        end
    end
end

local paletteModes <const> = { "APPEND", "REPLACE" }

local defaults <const> = {
    uniquesOnly = false,
    keepIndices = false,
    prependMask = true,
    useNew = false,
    paletteIndex = 1,
    paletteMode = "REPLACE"
}

local dlg <const> = Dialog { title = "GPL PAL Import" }

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "gpl", "pal" },
    open = true,
    focus = true
}

dlg:newrow { always = false }

dlg:check {
    id = "useNew",
    label = "New Sprite:",
    selected = defaults.useNew,
    onclick = function()
        local args <const> = dlg.data
        local useNew <const> = args.useNew --[[@as boolean]]
        dlg:modify { id = "keepIndices", visible = not useNew }
        dlg:modify { id = "paletteIndex", visible = not useNew }
        dlg:modify { id = "paletteMode", visible = not useNew }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask
}

dlg:newrow { always = false }

dlg:check {
    id = "keepIndices",
    label = "Indices:",
    text = "&Keep",
    selected = defaults.keepIndices,
    visible = not defaults.useNew
}

dlg:newrow { always = false }

dlg:combobox {
    id = "paletteMode",
    label = "Mode:",
    option = defaults.paletteMode,
    options = paletteModes,
    visible = not defaults.useNew
}

dlg:newrow { always = false }

dlg:slider {
    id = "paletteIndex",
    label = "Palette:",
    min = 1,
    max = 96,
    value = defaults.paletteIndex,
    visible = not defaults.useNew
}

dlg:separator { id = "uiSep", text = "Display" }

dlg:slider {
    id = "swatchSize",
    label = "Swatch:",
    min = 4,
    max = 32,
    value = setBoxSize,
    onchange = function()
        local args <const> = dlg.data
        local size <const> = args.swatchSize --[[@as integer]]
        app.command.SetPaletteEntrySize { size = size }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useSeparator",
    label = "Display:",
    text = "Separator",
    selected = setBoxSep,
    onclick = function()
        local args <const> = dlg.data
        local useSep <const> = args.useSeparator --[[@as boolean]]
        local appPrefs <const> = app.preferences
        if appPrefs then
            local colorBarPrefs <const> = appPrefs.color_bar
            if colorBarPrefs then
                colorBarPrefs.entries_separator = useSep
            end
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local filepath <const> = args.filepath --[[@as string]]

        if (not filepath)
            or (#filepath < 1)
            or (not app.fs.isFile(filepath)) then
            app.alert {
                title = "Error",
                text = "Invalid file path."
            }
            return
        end

        local fileExtLc <const> = string.lower(
            app.fs.fileExtension(filepath))
        local extIsPal <const> = fileExtLc == "pal"
        local extIsGpl <const> = fileExtLc == "gpl"
        if (not extIsGpl) and (not extIsPal) then
            app.alert {
                title = "Error",
                text = "File format must be gpl or pal."
            }
            return
        end

        AseUtilities.preserveForeBack()

        ---@type integer[]
        local colors = {}
        local lenColors = 0
        local columns = 0

        local palIdx <const> = args.paletteIndex
            or defaults.paletteIndex --[[@as integer]]
        local paletteMode <const> = args.paletteMode
            or defaults.paletteMode --[[@as string]]
        local activeSprite = app.site.sprite
        if paletteMode == "APPEND" then
            if activeSprite then
                local rgbColorMode <const> = ColorMode.RGB
                local aseToHex <const> = AseUtilities.aseColorToHex
                local palette <const> = AseUtilities.getPalette(
                    palIdx, activeSprite.palettes)
                local lenPalette = #palette
                local i = 0
                while i < lenPalette do
                    local aseColor <const> = palette:getColor(i)
                    lenColors = lenColors + 1
                    colors[lenColors] = aseToHex(aseColor, rgbColorMode)
                    i = i + 1
                end
            end
        end

        -- Cache functions to local when used in loop.
        local strbyte <const> = string.byte
        local strgmatch <const> = string.gmatch
        local strlower <const> = string.lower
        local strsub <const> = string.sub
        local strmatch <const> = string.match
        local strpack <const> = string.pack
        local strunpack <const> = string.unpack

        local isValidRiff = false
        if extIsPal then
            local binFile <const>, binErr <const> = io.open(filepath, "rb")
            if binErr ~= nil then
                app.alert { title = "Error", text = binErr }
                return
            end
            if binFile == nil then return end

            local fileData <const> = binFile:read("a")
            binFile:close()

            local lenFileData <const> = #fileData
            -- print(string.format("lenFileData: %d", lenFileData))

            local magicWordRiff <const> = strunpack("<I4",
                strsub(fileData, 1, 4))
            local magicCheckRiff <const> = strunpack("<I4", "RIFF")
            isValidRiff = magicWordRiff == magicCheckRiff
            -- print(string.format(
            --     "magicWordRiff: %d, magicCheckRiff: %d %s",
            --     magicWordRiff, magicCheckRiff,
            --     magicWordRiff == magicCheckRiff and "MATCH" or "MISMATCH"))

            local i = 4
            local magicWordPal = 0
            local magicCheckPal <const> = strunpack("<I4", "PAL ")
            if isValidRiff then
                while i < lenFileData and magicWordPal ~= magicCheckPal do
                    magicWordPal = strunpack("<I4",
                        strsub(fileData, 1 + i, 4 + i))
                    i = i + 1
                end
            end
            isValidRiff = isValidRiff and magicWordPal == magicCheckPal
            -- print(string.format(
            --     "i: %d, magicWordPal: %d, magicCheckPal: %d %s",
            --     i, magicWordPal, magicCheckPal,
            --     magicWordPal == magicCheckPal and "MATCH" or "MISMATCH"))

            local magicWordData = 0
            local magicCheckData <const> = strunpack("<I4", "data")
            if isValidRiff then
                while i < lenFileData and magicWordData ~= magicCheckData do
                    magicWordData = strunpack("<I4",
                        strsub(fileData, 1 + i, 4 + i))
                    i = i + 1
                end
            end
            isValidRiff = isValidRiff and magicWordData == magicCheckData
            -- print(string.format(
            --     "i: %d, magicWordData: %d, magicCheckData: %d %s",
            --     i, magicWordData, magicCheckData,
            --     magicWordData == magicCheckData and "MATCH" or "MISMATCH"))

            -- print(isValidRiff and "Valid" or "Not valid")
            if isValidRiff then
                -- local lenDataChunk <const> = strunpack("<I4",
                -- strsub(fileData, 4 + i, 7 + i))
                -- local palVersion <const> = strunpack("<I2",
                -- strsub(fileData, 8 + i, 9 + i))
                local numColors <const> = strunpack("<I2",
                    strsub(fileData, 10 + i, 11 + i))
                -- print(string.format(
                --     "lenDataChunk: %d, palVersion: %d, numColors: %d",
                --     lenDataChunk, palVersion, numColors))

                local j = 0
                while j < numColors do
                    local j4 <const> = i + j * 4
                    local r <const>, g <const>, b <const> = strbyte(
                        fileData, 12 + j4, 14 + j4)
                    local hex <const> = 0xff000000 | b << 0x10 | g << 0x08 | r
                    lenColors = lenColors + 1
                    colors[lenColors] = hex
                    j = j + 1
                end
            end
        end

        if not isValidRiff then
            local asciiFile <const>, asciiErr <const> = io.open(filepath, "r")
            if asciiErr ~= nil then
                app.alert { title = "Error", text = asciiErr }
                return
            end
            if asciiFile == nil then return end

            -- Implicitly tries to support JASC-PAL.
            local gplHeaderFound = 0
            local palHeaderFound = 0
            local palMagicFound = 0
            local nameFound = 0
            local jascPalClrCountFound = 0
            local aseAlphaFound = 0
            ---@type string[]
            local comments <const> = {}

            local lineCount = 1
            local linesItr <const> = asciiFile:lines()

            for line in linesItr do
                local lc <const> = strlower(line)

                if lc == "gimp palette" then
                    gplHeaderFound = lineCount
                elseif lc == "jasc-pal" then
                    palHeaderFound = lineCount
                elseif palHeaderFound == (lineCount - 1)
                    and lc == "0100" then
                    palMagicFound = lineCount
                elseif strsub(lc, 1, 4) == "name" then
                    nameFound = lineCount
                elseif strsub(lc, 1, 7) == "columns" then
                    local colStr <const> = strmatch(lc, ":(.*)")
                    local colDraft <const> = tonumber(colStr, 10)
                    if colDraft then
                        columns = colDraft
                    end
                elseif lc == "channels: rgba" then
                    aseAlphaFound = lineCount
                elseif strsub(lc, 1, 1) == '#' then
                    comments[#comments + 1] = strsub(line, 1)
                elseif #lc > 0 then
                    if palHeaderFound > 0
                        and palMagicFound > 0
                        and jascPalClrCountFound < 1 then
                        jascPalClrCountFound = lineCount
                    else
                        local a = 255
                        local b = 0
                        local g = 0
                        local r = 0

                        ---@type string[]
                        local tokens <const> = {}
                        local lenTokens = 0
                        for token in strgmatch(line, "%S+") do
                            lenTokens = lenTokens + 1
                            tokens[lenTokens] = token
                        end

                        if lenTokens > 2 then
                            if (aseAlphaFound > 0 or palHeaderFound > 0)
                                and lenTokens > 3 then
                                local aPrs <const> = tonumber(tokens[4], 10)
                                if aPrs then a = aPrs end
                            end

                            if a > 0 then
                                local bPrs <const> = tonumber(tokens[3], 10)
                                local gPrs <const> = tonumber(tokens[2], 10)
                                local rPrs <const> = tonumber(tokens[1], 10)

                                if bPrs then b = bPrs end
                                if gPrs then g = gPrs end
                                if rPrs then r = rPrs end
                            end
                        end

                        -- Saturation arithmetic instead of modular.
                        if a < 0 then a = 0 elseif a > 255 then a = 255 end
                        if b < 0 then b = 0 elseif b > 255 then b = 255 end
                        if g < 0 then g = 0 elseif g > 255 then g = 255 end
                        if r < 0 then r = 0 elseif r > 255 then r = 255 end

                        local hex <const> = a << 0x18 | b << 0x10 | g << 0x08 | r
                        lenColors = lenColors + 1
                        colors[lenColors] = hex
                    end
                end
                lineCount = lineCount + 1
            end
            asciiFile:close()
        end

        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        if uniquesOnly then
            local uniques <const>, _ <const> = Utilities.uniqueColors(
                colors, true)
            colors = uniques
        end

        local prependMask <const> = args.prependMask --[[@as boolean]]
        if prependMask then
            Utilities.prependMask(colors)
        end

        -- If no sprite exists, then create a new
        -- sprite and place palette swatches in it.
        local useNew <const> = args.useNew --[[@as boolean]]
        local keepIndices <const> = args.keepIndices --[[@as boolean]]
        local keepIdcsVerif <const> = keepIndices
            and not (useNew or (not activeSprite))
        local profileFlag = false
        if useNew or (not activeSprite) then
            -- Try to base sprite width on columns in GPL file. If not,
            -- find square root of colors length.
            local wSprite = columns
            if columns < 1 then
                wSprite = math.max(8,
                    math.ceil(math.sqrt(math.max(
                        1, #colors))))
            end
            local hSprite <const> = math.max(1,
                math.ceil(#colors / wSprite))

            ---@type string[]
            local byteArr <const> = {}
            local areaSprite <const> = wSprite * hSprite
            local i = 0
            while i < areaSprite do
                i = i + 1
                byteArr[i] = strpack("<I4", colors[i] or 0)
            end

            local spec <const> = AseUtilities.createSpec(wSprite, hSprite)
            local image <const> = Image(spec)
            image.bytes = table.concat(byteArr)

            activeSprite = AseUtilities.createSprite(spec, "Palette")
            local layer <const> = activeSprite.layers[1]
            local cel <const> = layer.cels[1]
            cel.image = image
            app.tool = "hand"
            app.command.FitScreen()
        else
            local profile <const> = activeSprite.colorSpace
            profileFlag = profile ~= ColorSpace { sRGB = true }
                and profile ~= ColorSpace()
        end

        -- No point in preserving old transparent color index if sprite is in
        -- indexed color mode. The new palette may be shorter than the old, or
        -- have clear black at different index.
        local oldMode <const> = activeSprite.colorMode

        if keepIdcsVerif then
            AseUtilities.setPalette(colors, activeSprite, palIdx, true)
        else
            AseUtilities.changePixelFormat(ColorMode.RGB)
            AseUtilities.setPalette(colors, activeSprite, palIdx)
            AseUtilities.changePixelFormat(oldMode)
        end
        app.refresh()

        if profileFlag then
            app.alert {
                title = "Warning",
                text = {
                    "Palette may not appear as intended.",
                    "Sprite uses a custom color profile."
                }
            }
        end
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