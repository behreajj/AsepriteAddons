dofile("../../support/aseutilities.lua")

local paletteTypes = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE",
    "PRESET" }

local function loadSprite(spriteFile)
    -- GPL and PAL file formats cannot be loaded as sprites.
    local fileExt = app.fs.fileExtension(spriteFile)
    local sprite = nil
    if fileExt == "gpl" or fileExt == "pal" then
        local spriteHexes, _ = AseUtilities.asePaletteLoad(
            "FILE", spriteFile, "", 0, 256, true)
        local colorsLen = #spriteHexes
        local rtLen = math.max(16,
            math.ceil(math.sqrt(math.max(1, colorsLen))))
        sprite = Sprite(rtLen, rtLen)
        AseUtilities.setPalette(spriteHexes, sprite, 1)

        local layer = sprite.layers[1]
        local cel = layer.cels[1]
        local image = cel.image
        local pxItr = image:pixels()

        local index = 0
        for elm in pxItr do
            if index <= colorsLen then
                index = index + 1
                elm(spriteHexes[index])
            end
        end
    else
        sprite = Sprite { fromFile = spriteFile }
    end

    return sprite
end

local defaults = {
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

local dlg = Dialog { title = "Open Sprite +" }

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
    label = "Transfer Bkg:",
    selected = defaults.removeBkg
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Edges",
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
        local state = dlg.data.palType
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "palPreset", visible = state == "PRESET" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "gpl", "pal" },
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

dlg:entry {
    id = "palPreset",
    focus = false,
    visible = defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
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
        local args = dlg.data
        local spriteFile = args.spriteFile
        if (not spriteFile)
            or (#spriteFile < 1)
            or (not app.fs.isFile(spriteFile)) then
            app.alert {
                title = "Error",
                text = "Invalid file path." }
            return
        end

        -- Do not ask to open animation sequences.
        -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L125
        local oldOpSeqPref = app.preferences.open_file.open_sequence
        app.preferences.open_file.open_sequence = 2

        -- Palettes need to be retrieved before a new sprite
        -- is created in case it auto-sets the app.activeSprite
        -- to the new sprite. Unfortunately, that means this
        -- is wasted effort if the palette type is "EMBEDDED"
        -- or there is no new sprite.
        local palType = args.palType or defaults.palType
        local hexesSrgb = {}
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile = args.palFile
            local palPreset = args.palPreset

            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, palPreset, 0, 256, true)
        else
            hexesProfile = AseUtilities.DEFAULT_PAL_ARR
            hexesSrgb = hexesProfile
        end

        -- Shift indexed fore- and back colors to RGB.
        AseUtilities.preserveForeBack()

        local openSprite = loadSprite(spriteFile)
        if not openSprite then
            app.alert {
                title = "Error",
                text = "Sprite could not be found." }
            return
        end

        -- Tile map layers should not be trimmed, so check
        -- if Aseprite is newer than 1.3.
        local version = app.version
        local checkForTilemaps = (version.major >= 1)
            and (version.minor >= 3)

        app.activeSprite = openSprite
        local oldColorMode = openSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local removeBkg = args.removeBkg
        if removeBkg then
            local bkgLayer = openSprite.backgroundLayer
            if bkgLayer then
                app.transaction(function()
                    app.activeLayer = bkgLayer
                    app.command.LayerFromBackground()
                    bkgLayer.name = "Bkg"
                end)
            end
        end

        -- Adjustable transparent color causes problems
        -- with multiple palettes.
        if openSprite.transparentColor ~= 0 then
            local oldAlphaMask = openSprite.transparentColor
            openSprite.transparentColor = 0
            app.alert {
                title = "Warning",
                text = string.format(
                    "The sprite alpha mask was reset from %d to 0.",
                    oldAlphaMask) }
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

        local uniquesOnly = args.uniquesOnly
        if uniquesOnly then
            local uniques, _ = Utilities.uniqueColors(
                hexesProfile, true)
            hexesProfile = uniques
        end

        local prependMask = args.prependMask
        if prependMask then
            Utilities.prependMask(hexesProfile)
        end

        local lenPalettes = #openSprite.palettes
        local setPalette = AseUtilities.setPalette
        local i = 0
        while i < lenPalettes do i = i + 1
            setPalette(hexesProfile, openSprite, i)
        end

        local trimCels = args.trimCels
        if trimCels then
            -- Problem with refactoring this to its own function
            -- is that it would need to check for pixel color mode
            -- and to create its own transaction.
            local cels = openSprite.cels
            local celsLen = #cels
            local trimImage = AseUtilities.trimImageAlpha
            app.transaction(function()
                local j = 0
                while j < celsLen do j = j + 1
                    local cel = cels[j]

                    local layer = cel.layer
                    local layerIsTilemap = false
                    if checkForTilemaps then
                        layerIsTilemap = layer.isTilemap
                    end

                    if layerIsTilemap then
                        -- Tile map layers should only belong to
                        -- .aseprite files, and hence not need this.
                    else
                        local trgImg, x, y = trimImage(cel.image, 0, 0)
                        local srcPos = cel.position
                        cel.position = Point(srcPos.x + x, srcPos.y + y)
                        cel.image = trgImg
                    end
                end
            end)
        end

        app.preferences.open_file.open_sequence = oldOpSeqPref
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
