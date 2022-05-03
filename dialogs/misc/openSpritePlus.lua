dofile("../../support/aseutilities.lua")

local paletteTypes = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE",
    "PRESET" }

local function loadSprite(spriteFile)
    -- TODO: Move to AseUtilities?

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
        sprite:setPalette(
            AseUtilities.hexArrToAsePalette(spriteHexes))

        local layer = sprite.layers[1]
        local cel = layer.cels[1]
        local image = cel.image
        local pxItr = image:pixels()

        local index = 1
        for elm in pxItr do
            if index <= colorsLen then
                elm(spriteHexes[index])
                index = index + 1
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
        if spriteFile and #spriteFile > 0 then
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

            -- Aseprite will automatically trigger opening an image
            -- sequence if possible, so no point in creating a custom.
            local openSprite = nil
            local exists = app.fs.isFile(spriteFile)
            if exists then
                AseUtilities.preserveForeBack()
                openSprite = loadSprite(spriteFile)

                if openSprite then

                    -- Tile map layers should not be trimmed, so check
                    -- if Aseprite is newer than 1.3.
                    local version = app.version
                    local checkForTilemaps = false
                    if version.major >= 1 and version.minor >= 3 then
                        checkForTilemaps = true
                    end

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

                    -- Aseprite's built-in nearest color in palette method
                    -- isn't trustworthy. Even if it were, there's no way
                    -- of telling the user's intent. It could be that
                    -- index n should be the transparent color for both the
                    -- old and new palette, no matter how different the colors
                    -- in appearance. Better to reset to zero.
                    if openSprite.transparentColor ~= 0 then
                        app.alert(string.format(
                            "The sprite alpha mask was reset from %d to 0.",
                            openSprite.transparentColor))
                        openSprite.transparentColor = 0
                    end

                    if palType == "EMBEDDED" then
                        -- Recent changes to color conversion require this?
                        if oldColorMode == ColorMode.GRAY then
                            hexesProfile = AseUtilities.grayHexes(
                                AseUtilities.GRAY_COUNT)
                        else
                            hexesProfile = AseUtilities.asePaletteToHexArr(
                                openSprite.palettes[1], 0, 256)
                        end
                    end

                    local uniquesOnly = args.uniquesOnly
                    if uniquesOnly then
                        local uniques, dict = Utilities.uniqueColors(
                            hexesProfile, true)
                        hexesProfile = uniques
                    end

                    local prependMask = args.prependMask
                    if prependMask then
                        Utilities.prependMask(hexesProfile)
                    end
                    local newPal = AseUtilities.hexArrToAsePalette(hexesProfile)
                    openSprite:setPalette(newPal)

                    local trimCels = args.trimCels
                    if trimCels then
                        -- Problem with refactoring this to its own function
                        -- is that it would need to check for pixel color mode
                        -- and to create its own transaction.
                        local cels = openSprite.cels
                        local celsLen = #cels
                        local trimImage = AseUtilities.trimImageAlpha

                        app.transaction(function ()
                            for i = 1, celsLen, 1 do
                                local cel = cels[i]

                                local layer = cel.layer
                                local layerIsTilemap = false
                                if checkForTilemaps then
                                    layerIsTilemap = layer.isTilemap
                                end

                                if layerIsTilemap then
                                    -- Tile map layers should only belong to
                                    -- .aseprite files, and hence not need this.
                                else
                                    local srcImg = cel.image
                                    local trgImg, x, y = trimImage(srcImg, 0, 0)
                                    local srcPos = cel.position
                                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                                    cel.image = trgImg
                                end
                            end
                        end)
                    end

                    local xGrid = args.xGrid or defaults.xGrid
                    local yGrid = args.yGrid or defaults.yGrid
                    local wGrid = args.wGrid or defaults.wGrid
                    local hGrid = args.hGrid or defaults.hGrid
                    if wGrid > 1 and hGrid > 1 then
                        openSprite.gridBounds = Rectangle(
                            xGrid, yGrid, wGrid, hGrid)
                    end

                    app.refresh()
                else
                    app.alert("Sprite could not be found.")
                end
            else
                app.alert("File does not exist at path.")
            end
        else
            app.alert("Invalid file path.")
        end

        dlg:close()
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