dofile("../../support/aseutilities.lua")

local paletteTypes <const> = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE"
}

---@param filePath string
---@return Sprite|nil
local function loadNetPbm(filePath)
    -- This would need to know in advance that file is binary so as to read
    -- "rb" instead of "r".
    local file <const>, err <const> = io.open(filePath, "r")
    if file then
        -- Cache functions to local when used in loop.
        local floor <const> = math.floor
        local strgmatch <const> = string.gmatch
        local strlower <const> = string.lower
        local strsub <const> = string.sub

        local channelMaxFound = 0
        local whFound = 0
        ---@type string[]
        local comments <const> = {}

        ---@type number[]
        local data = {}
        local channels3 = false
        local invert = false
        local includesChnlSz = false
        local channelMax = 255.0
        local fromChnlSz = 255.0
        local w = 1
        local h = 1

        local lineCount = 0
        local linesItr <const> = file:lines()

        for line in linesItr do
            lineCount = lineCount + 1
            local lenLine <const> = #line
            if lenLine > 0 then
                local lc <const> = strlower(line)
                if strsub(line, 1, 1) == '#' then
                    comments[#comments + 1] = strsub(line, 1)
                elseif lc == "p1" then
                    invert = true
                elseif lc == "p2" then
                    includesChnlSz = true
                elseif lc == "p3" then
                    includesChnlSz = true
                    channels3 = true
                elseif whFound <= 0 then
                    whFound = lineCount

                    ---@type string[]
                    local whTokens <const> = {}
                    local lenWhTokens = 0
                    for token in strgmatch(line, "%S+") do
                        lenWhTokens = lenWhTokens + 1
                        whTokens[lenWhTokens] = token
                    end

                    if lenWhTokens > 0 then
                        local wPrs <const> = tonumber(whTokens[1], 10)
                        if wPrs then w = floor(wPrs) end
                    end

                    if lenWhTokens > 1 then
                        local hPrs <const> = tonumber(whTokens[2], 10)
                        if hPrs then h = floor(hPrs) end
                    end
                elseif includesChnlSz and channelMaxFound <= 0 then
                    channelMaxFound = lineCount
                    local channelMaxPrs <const> = tonumber(lc, 10)
                    if channelMaxPrs then
                        channelMax = floor(channelMaxPrs)
                        if channelMax ~= 0.0 then
                            fromChnlSz = 255.0 / channelMax
                        end
                    end
                else
                    -- Parse line as image data.
                    for token in strgmatch(line, "%S+") do
                        local numPrs <const> = tonumber(token, 10)
                        local num = 0
                        if numPrs then num = numPrs end
                        data[#data + 1] = num
                    end
                end
            end
        end
        file:close()

        local spec <const> = AseUtilities.createSpec(w, h, ColorMode.RGB)
        local sprite <const> = AseUtilities.createSprite(spec,
            app.fs.fileName(filePath))
        local image <const> = Image(spec)

        if channels3 then
            local i = 0
            local pxItr = image:pixels()
            for pixel in pxItr do
                local k <const> = i * 3
                local r <const> = floor(data[1 + k] * fromChnlSz + 0.5)
                local g <const> = floor(data[2 + k] * fromChnlSz + 0.5)
                local b <const> = floor(data[3 + k] * fromChnlSz + 0.5)
                local hex <const> = 0xff000000 | b << 0x10 | g << 0x08 | r
                pixel(hex)
                i = i + 1
            end
        else
            local i = 0
            local pxItr = image:pixels()
            for pixel in pxItr do
                i = i + 1
                local v = floor(data[i] * fromChnlSz + 0.5)
                if invert then v = 255 ~ v end
                local hex <const> = 0xff000000 | v << 0x10 | v << 0x08 | v
                pixel(hex)
            end
        end

        app.transaction("Set Image", function()
            sprite.cels[1].image = image
        end)

        app.command.ColorQuantization { ui = false, maxColors = 255 }

        return sprite
    else
        if err ~= nil then
            app.alert { title = "Error", text = err }
        end
        return nil
    end
end

---@param filePath string
---@return Sprite|nil
local function loadSprite(filePath)
    -- GPL and PAL file formats cannot be loaded as sprites.
    local fileExt <const> = app.fs.fileExtension(filePath)
    local fileExtLower <const> = string.lower(fileExt)
    local sprite = nil
    if fileExtLower == "gpl" or fileExtLower == "pal" then
        local spriteHexes <const>, _ <const> = AseUtilities.asePaletteLoad(
            "FILE", filePath, 0, 256, true)
        local lenColors <const> = #spriteHexes
        local rtLen <const> = math.max(16,
            math.ceil(math.sqrt(math.max(1, lenColors))))

        local spec <const> = AseUtilities.createSpec(rtLen, rtLen)
        sprite = AseUtilities.createSprite(spec, app.fs.fileName(filePath))
        AseUtilities.setPalette(spriteHexes, sprite, 1)

        local image <const> = Image(spec)
        local pxItr <const> = image:pixels()
        local index = 0
        for pixel in pxItr do
            if index <= lenColors then
                index = index + 1
                pixel(spriteHexes[index])
            end
        end

        app.transaction("Set Image", function()
            sprite.cels[1].image = image
        end)
    elseif fileExtLower == "ppm"
        or fileExtLower == "pgm"
        or fileExtLower == "pbm" then
        sprite = loadNetPbm(filePath)
    else
        sprite = Sprite { fromFile = filePath }
        if fileExtLower ~= "ase" and fileExtLower ~= "aseprite" then
            local docPrefs <const> = app.preferences.document(sprite)
            local onionSkinPrefs <const> = docPrefs.onionskin
            onionSkinPrefs.loop_tag = false
        end
    end

    return sprite
end

local defaults <const> = {
    removeBkg = true,
    trimCels = true,
    palType = "EMBEDDED",
    uniquesOnly = true,
    prependMask = true,
    xGrid = 0,
    yGrid = 0,
    wGrid = 32,
    hGrid = 32
}

local dlg <const> = Dialog { title = "Open Sprite +" }

dlg:file {
    id = "spriteFile",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS,
    open = true,
    focus = true
}

dlg:newrow { always = false }

dlg:check {
    id = "removeBkg",
    label = "Convert Bkg:",
    selected = defaults.removeBkg
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
}

dlg:separator {
    id = "palSeparate",
    visible = defaults.colorMode ~= "GRAY"
}

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = paletteTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    focus = false,
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask
}

dlg:separator { id = "noteSeparate" }

dlg:label {
    id = "clrMdWarn",
    label = "Note:",
    text = "Sprites open in RGB mode."
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local spriteFile <const> = args.spriteFile --[[@as string]]

        if (not spriteFile)
            or (#spriteFile < 1)
            or (not app.fs.isFile(spriteFile)) then
            app.alert {
                title = "Error",
                text = "Invalid file path."
            }
            return
        end

        -- Do not ask to open animation sequences.
        -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L125
        local openFilePrefs <const> = app.preferences.open_file
        local oldOpSeqPref <const> = openFilePrefs.open_sequence --[[@as integer]]
        openFilePrefs.open_sequence = 2

        -- Palettes need to be retrieved before a new sprite is created in case
        -- it sets the app.activeSprite to the new sprite. Unfortunately, that
        -- means this is wasted effort if the palette type is "EMBEDDED" or
        -- there is no new sprite.
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local hexesSrgb = {}
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile <const> = args.palFile --[[@as string]]
            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 256, true)
        else
            -- As of circa apiVersion 24, version v1.3-rc4.
            local defaultPalette = app.defaultPalette
            if defaultPalette then
                hexesProfile = AseUtilities.asePaletteToHexArr(
                    defaultPalette, 0, #defaultPalette)
            else
                local hexesDefault <const> = AseUtilities.DEFAULT_PAL_ARR
                local lenHexesDef <const> = #hexesDefault
                local i = 0
                while i < lenHexesDef do
                    i = i + 1
                    hexesProfile[i] = hexesDefault[i]
                end
            end

            hexesSrgb = hexesProfile
        end

        -- Shift indexed fore- and back colors to RGB.
        AseUtilities.preserveForeBack()

        local openSprite <const> = loadSprite(spriteFile)
        if not openSprite then
            app.alert {
                title = "Error",
                text = "Sprite could not be found."
            }
            return
        end

        app.activeSprite = openSprite
        local oldColorMode <const> = openSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local removeBkg <const> = args.removeBkg --[[@as boolean]]
        if removeBkg then
            local bkgLayer <const> = openSprite.backgroundLayer
            if bkgLayer then
                app.transaction("Layer From Bkg", function()
                    app.activeLayer = bkgLayer
                    app.command.LayerFromBackground()
                    bkgLayer.name = "Bkg"
                end)
            end
        end

        -- Adjustable transparent color causes problems with multiple palettes.
        if openSprite.transparentColor ~= 0 then
            local oldAlphaMask <const> = openSprite.transparentColor
            openSprite.transparentColor = 0
            app.alert {
                title = "Warning",
                text = string.format(
                    "The sprite alpha mask was reset from %d to 0.",
                    oldAlphaMask)
            }
        end

        if palType == "EMBEDDED" then
            -- Recent changes to color conversion require this?
            if oldColorMode == ColorMode.GRAY then
                hexesProfile = AseUtilities.grayHexes(
                    AseUtilities.GRAY_COUNT)
            else
                hexesProfile = AseUtilities.asePalettesToHexArr(
                    openSprite.palettes)
            end
        end

        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        if uniquesOnly then
            local uniques <const>, _ <const> = Utilities.uniqueColors(
                hexesProfile, true)
            hexesProfile = uniques
        end

        local prependMask <const> = args.prependMask --[[@as boolean]]
        if prependMask then
            Utilities.prependMask(hexesProfile)
        end

        local lenPalettes <const> = #openSprite.palettes
        local setPalette <const> = AseUtilities.setPalette
        local i = 0
        while i < lenPalettes do
            i = i + 1
            setPalette(hexesProfile, openSprite, i)
        end

        local trimCels <const> = args.trimCels --[[@as boolean]]
        if trimCels then
            local cels <const> = AseUtilities.filterCels(
                openSprite, nil, nil, "ALL",
                true, true, false, false)
            app.transaction("Trim Cels", function()
                local j = 0
                local lenCels <const> = #cels
                local trimImage <const> = AseUtilities.trimImageAlpha
                while j < lenCels do
                    j = j + 1
                    local cel <const> = cels[j]
                    local trgImg <const>, x <const>, y <const> = trimImage(cel.image, 0, 0)
                    local srcPos <const> = cel.position
                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                    cel.image = trgImg
                end
            end)
        end

        openFilePrefs.open_sequence = oldOpSeqPref
        app.activeTool = "hand"
        app.command.FitScreen()
        app.refresh()
        dlg:close()
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