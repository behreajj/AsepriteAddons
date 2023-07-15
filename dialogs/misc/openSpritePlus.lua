dofile("../../support/aseutilities.lua")

local paletteTypes = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE"
}

---@param filePath string
---@return Sprite
local function loadSprite(filePath)
    -- GPL and PAL file formats cannot be loaded as sprites.
    local fileExt = app.fs.fileExtension(filePath)
    local sprite = nil
    if string.lower(fileExt) == "gpl"
        or string.lower(fileExt) == "pal" then
        local spriteHexes, _ = AseUtilities.asePaletteLoad(
            "FILE", filePath, 0, 256, true)
        local lenColors = #spriteHexes
        local rtLen = math.max(16,
            math.ceil(math.sqrt(math.max(1, lenColors))))
        sprite = Sprite(rtLen, rtLen)
        AseUtilities.setPalette(spriteHexes, sprite, 1)

        local layer = sprite.layers[1]
        local cel = layer.cels[1]
        local image = cel.image
        local pxItr = image:pixels()

        local index = 0
        for pixel in pxItr do
            if index <= lenColors then
                index = index + 1
                pixel(spriteHexes[index])
            end
        end
    else
        sprite = Sprite { fromFile = filePath }
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
        local state = dlg.data.palType
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
        local args = dlg.data
        local spriteFile = args.spriteFile --[[@as string]]

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
        local oldOpSeqPref = app.preferences.open_file.open_sequence
        app.preferences.open_file.open_sequence = 2

        -- Palettes need to be retrieved before a new sprite
        -- is created in case it auto-sets the app.activeSprite
        -- to the new sprite. Unfortunately, that means this
        -- is wasted effort if the palette type is "EMBEDDED"
        -- or there is no new sprite.
        local palType = args.palType or defaults.palType --[[@as string]]
        local hexesSrgb = {}
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile = args.palFile --[[@as string]]
            hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 256, true)
        else
            -- As of circa apiVersion 24, version v1.3-rc4.
            local defaultPalette = app.defaultPalette
            if defaultPalette then
                hexesProfile = AseUtilities.asePaletteToHexArr(
                    defaultPalette, 0, #defaultPalette)
            else
                local hexesDefault = AseUtilities.DEFAULT_PAL_ARR
                local lenHexesDef = #hexesDefault
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

        local openSprite = loadSprite(spriteFile)
        if not openSprite then
            app.alert {
                title = "Error",
                text = "Sprite could not be found."
            }
            return
        end

        app.activeSprite = openSprite
        local oldColorMode = openSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local removeBkg = args.removeBkg
        if removeBkg then
            local bkgLayer = openSprite.backgroundLayer
            if bkgLayer then
                app.transaction("Layer From Bkg", function()
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

        local uniquesOnly = args.uniquesOnly --[[@as boolean]]
        if uniquesOnly then
            local uniques, _ = Utilities.uniqueColors(
                hexesProfile, true)
            hexesProfile = uniques
        end

        local prependMask = args.prependMask --[[@as boolean]]
        if prependMask then
            Utilities.prependMask(hexesProfile)
        end

        local lenPalettes = #openSprite.palettes
        local setPalette = AseUtilities.setPalette
        local i = 0
        while i < lenPalettes do
            i = i + 1
            setPalette(hexesProfile, openSprite, i)
        end

        local trimCels = args.trimCels
        if trimCels then
            local cels = AseUtilities.filterCels(
                openSprite, nil, nil, "ALL",
                true, true, false, false)
            app.transaction("Trim Cels", function()
                local j = 0
                local lenCels = #cels
                local trimImage = AseUtilities.trimImageAlpha
                while j < lenCels do
                    j = j + 1
                    local cel = cels[j]
                    local trgImg, x, y = trimImage(cel.image, 0, 0)
                    local srcPos = cel.position
                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                    cel.image = trgImg
                end
            end)
        end

        app.preferences.open_file.open_sequence = oldOpSeqPref
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