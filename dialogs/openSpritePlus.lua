dofile("../support/aseutilities.lua")

local paletteTypes = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE",
    "PRESET" }

local defaults = {
    removeBkg = true,
    trimCels = true,
    palType = "EMBEDDED",
    uniquesOnly = true,
    prependMask = true,
    pullFocus = true
}

local dlg = Dialog { title = "Open Sprite +" }

dlg:file {
    id = "spriteFile",
    label = "File:",
    filetypes = {
        "ase",
        "aseprite",
        "gif",
        "jpg",
        "jpeg",
        "png",
        "webp" },
    open = true
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
    focus = defaults.pullFocus,
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

                hexesSrgb, hexesProfile = AseUtilities.asePaletteLoad(
                    palType, palFile, palPreset, 0, 256, true)
            else
                hexesProfile = AseUtilities.DEFAULT_PAL_ARR
                hexesSrgb = hexesProfile
            end

            local openSprite = nil
            local exists = app.fs.isFile(spriteFile)
            if exists then
                openSprite = Sprite { fromFile = spriteFile }
                if openSprite then
                    app.activeSprite = openSprite
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
                    -- index 6 should be the transparent color for both the
                    -- old and new palette, no matter how different the colors
                    -- in appearance. Better to reset to zero.
                    if openSprite.transparentColor ~= 0 then
                        app.alert(string.format(
                            "The sprite alpha mask was reset from %d to 0.",
                            openSprite.transparentColor))
                        openSprite.transparentColor = 0
                    end

                    if palType == "EMBEDDED" then
                        hexesProfile = AseUtilities.asePaletteToHexArr(
                            openSprite.palettes[1], 0, 256)
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
                                local srcImg = cel.image
                                if srcImg then
                                    local trgImg, x, y = trimImage(srcImg)
                                    local srcPos = cel.position
                                    cel.position = Point(srcPos.x + x, srcPos.y + y)
                                    cel.image = trgImg
                                end
                            end
                        end)
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