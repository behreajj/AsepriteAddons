dofile("../../support/aseutilities.lua")

local paletteTypes <const> = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE"
}

local defaults <const> = {
    -- TODO: Option to open sequences from directory?

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

---@param filePath string
---@return Sprite|nil
local function loadSprite(filePath)
    -- GPL and PAL file formats cannot be loaded as sprites.
    local fileExt <const> = app.fs.fileExtension(filePath)
    local fileExtLower <const> = string.lower(fileExt)
    local sprite = nil
    if fileExtLower == "gpl" or fileExtLower == "pal" then
        local spriteHexes <const>, _ <const> = AseUtilities.asePaletteLoad(
            "FILE", filePath, 0, 512, true)
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
            if index < lenColors then
                index = index + 1
                pixel(spriteHexes[index])
            end
        end

        app.transaction("Set Image", function()
            sprite.cels[1].image = image
        end)
    else
        sprite = Sprite { fromFile = filePath }
        if fileExtLower ~= "ase" and fileExtLower ~= "aseprite" then
            local appPrefs <const> = app.preferences
            appPrefs.selection.pivot_position = 4

            local docPrefs <const> = appPrefs.document(sprite)
            local onionSkinPrefs <const> = docPrefs.onionskin
            onionSkinPrefs.loop_tag = false

            -- Default overlay_size is 5.
            local thumbPrefs <const> = docPrefs.thumbnails
            thumbPrefs.enabled = true
            thumbPrefs.zoom = 1
            thumbPrefs.overlay_enabled = true
        end
    end

    return sprite
end

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
    label = "Convert:",
    text = "&Bkg",
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
        -- it sets the app.sprite to the new sprite. Unfortunately, that
        -- means this is wasted effort if the palette type is "EMBEDDED" or
        -- there is no new sprite.
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local hexesSrgb = {}
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile <const> = args.palFile --[[@as string]]
            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 512, true)
        else
            -- As of circa apiVersion 24, version v1.3-rc4.
            -- local defaultPalette = app.defaultPalette
            -- if defaultPalette then
            -- hexesProfile = AseUtilities.asePaletteToHexArr(
            -- defaultPalette, 0, #defaultPalette)
            -- else
            local hexesDefault <const> = AseUtilities.DEFAULT_PAL_ARR
            local lenHexesDef <const> = #hexesDefault
            local i = 0
            while i < lenHexesDef do
                i = i + 1
                hexesProfile[i] = hexesDefault[i]
            end
            -- end

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

        app.sprite = openSprite

        local oldColorMode <const> = openSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Due to indexed color mode backgrounds potentiallly containing
        -- transparent colors, or having an opaque color set as the sprite
        -- transparent color, there's no great solution as to whether this
        -- should go before or after RGB conversion.
        local removeBkg <const> = args.removeBkg --[[@as boolean]]
        if removeBkg then
            -- Do this automatically for pngs, gifs, jpgs, jpegs, etc.
            -- but not ase or aseprite file extensions?
            app.transaction("Background to Layer", function()
                AseUtilities.bkgToLayer(openSprite, true)
            end)
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
                openSprite, nil, {}, "ALL",
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
        app.layer = openSprite.layers[#openSprite.layers]
        app.tool = "hand"
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

dlg:show {
    autoscrollbars = true,
    wait = false
}