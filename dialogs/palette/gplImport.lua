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

local defaults <const> = {
    uniquesOnly = false,
    prependMask = true,
    useNew = false,
    paletteIndex = 1
}

local dlg <const> = Dialog { title = "GPL Import" }

dlg:file {
    id = "filepath",
    label = "Path:",
    filetypes = { "gpl", "pal" },
    open = true,
    focus = true
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
    id = "useNew",
    label = "New Sprite:",
    selected = defaults.useNew,
    onclick = function()
        local args <const> = dlg.data
        local useNew <const> = args.useNew --[[@as boolean]]
        dlg:modify { id = "paletteIndex", visible = not useNew }
    end
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

        local fileExt <const> = string.lower(
            app.fs.fileExtension(filepath))
        if fileExt ~= "gpl" and fileExt ~= "pal" then
            app.alert {
                title = "Error",
                text = "File format is not gpl."
            }
            return
        end

        ---@type integer[]
        local colors = {}
        local lenColors = 0
        local columns = 0

        local file <const>, err <const> = io.open(filepath, "r")
        if file ~= nil then
            AseUtilities.preserveForeBack()

            -- Cache functions to local when used in loop.
            local strlower <const> = string.lower
            local strsub <const> = string.sub
            local strgmatch <const> = string.gmatch
            local strmatch <const> = string.match

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
            local linesItr <const> = file:lines()

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
            file:close()

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
            local activeSprite = app.site.sprite
            local profileFlag = false
            if useNew or (not activeSprite) then
                -- Try to base sprite width on columns in GPL file. If not,
                -- find square root of colors length.
                local wSprite = columns
                if columns < 1 then
                    wSprite = math.max(8,
                        math.ceil(math.sqrt(math.max(
                            1, lenColors))))
                end
                local hSprite <const> = math.max(1,
                    math.ceil(lenColors / wSprite))

                local spec <const> = AseUtilities.createSpec(wSprite, hSprite)
                local image <const> = Image(spec)
                local pxItr <const> = image:pixels()
                local index = 0
                for pixel in pxItr do
                    if index <= lenColors then
                        index = index + 1
                        pixel(colors[index])
                    end
                end

                activeSprite = AseUtilities.createSprite(spec, "Palette")
                local layer <const> = activeSprite.layers[1]
                local cel <const> = layer.cels[1]
                cel.image = image
                app.tool = "hand"
            else
                local profile <const> = activeSprite.colorSpace
                profileFlag = profile ~= ColorSpace { sRGB = true }
                    and profile ~= ColorSpace()
            end

            local oldMode <const> = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }
            local palIdx <const> = args.paletteIndex
                or defaults.paletteIndex --[[@as integer]]
            AseUtilities.setPalette(colors, activeSprite, palIdx)
            AseUtilities.changePixelFormat(oldMode)
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

            local appPrefs <const> = app.preferences
            if appPrefs then
                local cmPrefs <const> = appPrefs.color
                if cmPrefs then
                    local useMgmt <const> = cmPrefs.manage
                    if useMgmt then
                        local working <const> = cmPrefs.working_rgb_space --[[@as string]]
                        local windowConst <const> = cmPrefs.window_profile

                        local windowStr = "sRGB"
                        if windowConst ~= 1 then
                            windowStr = cmPrefs.window_profile_name --[[@as string]]
                        end

                        if windowStr ~= "sRGB" or working ~= "sRGB" then
                            app.alert {
                                title = "Warning",
                                text = {
                                    "Palette may not appear as intended.",
                                    "Aseprite's working and window color profiles are not sRGB.",
                                    "See Edit > Preferences > Color ."
                                }
                            }
                        end
                    end
                end
            end
        end -- File is not nil.

        if err ~= nil then
            app.alert { title = "Error", text = err }
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