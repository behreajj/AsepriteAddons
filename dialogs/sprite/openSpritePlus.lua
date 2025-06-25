dofile("../../support/aseutilities.lua")

local paletteTypes <const> = {
    "ACTIVE",
    "DEFAULT",
    "EMBEDDED",
    "FILE"
}

local defaults <const> = {
    asSeq = false,
    fps = 12,
    removeBkg = true,
    trimCels = true,
    fixZeroAlpha = false,
    palType = "EMBEDDED",
    uniquesOnly = true,
    prependMask = true,
    xGrid = 0,
    yGrid = 0,
    wGrid = 32,
    hGrid = 32
}

---@param filePath string
---@param showLayerEdges? boolean
---@return Sprite|nil
local function loadSprite(filePath, showLayerEdges)
    -- Palette file formats cannot be loaded as sprites.
    local fileExt <const> = app.fs.fileExtension(filePath)
    local lcFileExt <const> = string.lower(fileExt)
    local sprite = nil
    if lcFileExt == "gpl"
        or lcFileExt == "pal"
        or lcFileExt == "act"
        or lcFileExt == "col"
        or lcFileExt == "hex" then
        local spriteHexes <const>, _ <const> = AseUtilities.asePaletteLoad(
            "FILE", filePath, "", 0, 512, true)
        local lenColors <const> = #spriteHexes
        local rtLen <const> = math.max(16,
            math.ceil(math.sqrt(math.max(1, lenColors))))

        local spec <const> = AseUtilities.createSpec(rtLen, rtLen)
        sprite = AseUtilities.createSprite(spec, app.fs.fileName(filePath))
        AseUtilities.setPalette(spriteHexes, sprite, 1)

        local image <const> = Image(spec)
        ---@type string[]
        local byteArr <const> = {}
        local strpack <const> = string.pack
        local areaImage <const> = rtLen * rtLen
        local packZero <const> = strpack("<I4", 0)
        local i = 0
        while i < areaImage do
            i = i + 1
            local trgHex = packZero
            if i <= lenColors then
                trgHex = strpack("<I4", spriteHexes[i])
            end
            byteArr[i] = trgHex
        end
        image.bytes = table.concat(byteArr)

        app.transaction("Set Image", function()
            sprite.cels[1].image = image
        end)
    else
        sprite = Sprite { fromFile = filePath }
        if sprite ~= nil then
            local appPrefs <const> = app.preferences
            if appPrefs then
                local docPrefs <const> = appPrefs.document(sprite)
                if docPrefs then
                    if lcFileExt ~= "ase" and lcFileExt ~= "aseprite" then
                        local onionSkinPrefs <const> = docPrefs.onionskin
                        if onionSkinPrefs then
                            onionSkinPrefs.loop_tag = false
                        end -- Onion skin preferences exists.

                        local thumbPrefs <const> = docPrefs.thumbnails
                        if thumbPrefs then
                            thumbPrefs.enabled = true
                            thumbPrefs.zoom = 1
                            thumbPrefs.overlay_enabled = true
                        end -- Thumb preferences exists.

                        if showLayerEdges then
                            local showPrefs <const> = docPrefs.show
                            if showPrefs then
                                showPrefs.layer_edges = true
                            end -- Show preferences exists.
                        end     -- Show layer edges.
                    end         -- Not an aseprite file.

                    -- This doesn't seem to effect Image:saveAs or new files.
                    -- If it did, you'd have to generalize the method.
                    local exportPrefs <const> = docPrefs.save_copy
                    if exportPrefs then
                        exportPrefs.for_twitter = false
                    end -- Export prefs exists.
                end     -- Doc preferences exists.
            end         -- App preferences exists.
        end             -- Sprite exists.
    end                 -- File ext match block.

    return sprite
end

local dlg <const> = Dialog { title = "Open Sprite +" }

dlg:file {
    id = "spriteFile",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS_OPEN,
    basepath = app.fs.userDocsPath,
    focus = true,
    visible = defaults.asSeq == false
}

dlg:newrow { always = false }

dlg:file {
    id = "fromFile",
    label = "From:",
    filetypes = AseUtilities.FILE_FORMATS_OPEN,
    basepath = app.fs.userDocsPath,
    title = "Open Sequence",
    focus = false,
    visible = defaults.asSeq == true
}

dlg:newrow { always = false }

dlg:file {
    id = "toFile",
    label = "To:",
    filetypes = AseUtilities.FILE_FORMATS_OPEN,

    basepath = app.fs.userDocsPath,
    title = "Open Sequence",
    focus = false,
    visible = defaults.asSeq == true
}

dlg:newrow { always = false }

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps,
    visible = defaults.asSeq == true
}

dlg:newrow { always = false }

dlg:check {
    id = "asSeq",
    label = "Folder:",
    text = "Se&quence",
    selected = defaults.asSeq,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.asSeq --[[@as boolean]]
        dlg:modify { id = "fromFile", visible = state }
        dlg:modify { id = "toFile", visible = state }
        dlg:modify { id = "fps", visible = state }
        dlg:modify { id = "spriteFile", visible = not state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "removeBkg",
    label = "Fix:",
    text = "&Bkg",
    selected = defaults.removeBkg,
    visible = true,
    hexpand = false,
}

dlg:check {
    id = "trimCels",
    text = "&Trim",
    selected = defaults.trimCels,
    visible = true,
    hexpand = false,
}

dlg:check {
    id = "fixZeroAlpha",
    text = "&Alpha",
    selected = defaults.fixZeroAlpha,
    visible = true,
    hexpand = false,
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
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,

    basepath = app.fs.joinPath(app.fs.userConfigPath, "palettes"),
    visible = defaults.palType == "FILE",
    focus = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Filter:",
    text = "Uniques",
    focus = false,
    selected = defaults.uniquesOnly,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Mask:",
    text = "Prepend",
    selected = defaults.prependMask,
    hexpand = false,
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
        local asSeq <const> = args.asSeq --[[@as boolean]]

        if (not spriteFile) or (#spriteFile < 1) then
            app.alert {
                title = "Error",
                text = "Invalid file path."
            }
            return
        end

        if (not asSeq) and (not app.fs.isFile(spriteFile)) then
            app.alert {
                title = "Error",
                text = "Path is not a file."
            }
            return
        end

        -- Do not allow slices UI interface to be active.
        -- Since this will be set to hand later on anyway, simplify.
        app.tool = "hand"

        -- Change fore and background colors to RGB mode.
        AseUtilities.preserveForeBack()

        -- Do not ask to open animation sequences.
        -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L125
        -- Do not automatically handle any color profiles.
        -- https://github.com/aseprite/aseprite/blob/main/data/pref.xml#L107
        local oldOpSeqPref = 0  -- Ask
        local oldAskProfile = 4 -- Ask
        local oldAskMissing = 4 -- Ask
        local oldQuantAlg = 0   -- Default
        local autoFit = false
        local showLayerEdges = false

        local appPrefs <const> = app.preferences
        if appPrefs then
            local openFilePrefs <const> = appPrefs.open_file
            if openFilePrefs then
                oldOpSeqPref = openFilePrefs.open_sequence or 0 --[[@as integer]]
                openFilePrefs.open_sequence = 2 -- No
            end

            local cmPrefs <const> = appPrefs.color
            if cmPrefs then
                oldAskProfile = cmPrefs.files_with_profile or 4 --[[@as integer]]
                oldAskMissing = cmPrefs.missing_profile or 4 --[[@as integer]]

                cmPrefs.files_with_profile = 1 -- Embedded
                cmPrefs.missing_profile = 0    -- Disable
            end

            local quantPrefs <const> = appPrefs.quantization
            if quantPrefs then
                oldQuantAlg = quantPrefs.rgbmap_algorithm or 0 --[[@as integer]]
                quantPrefs.rgbmap_algorithm = 1 -- RGB5A3
            end

            local editorPrefs <const> = appPrefs.editor
            if editorPrefs then
                autoFit = editorPrefs.auto_fit
            end

            local prevSprite <const> = app.sprite
            if prevSprite then
                local docPrefs <const> = appPrefs.document(prevSprite)
                if docPrefs then
                    local showPrefs <const> = docPrefs.show
                    if showPrefs then
                        showLayerEdges = showPrefs.layer_edges or false
                    end -- Show preferences exists.
                end     -- Doc preferences exists.
            end         -- Sprite exists.
        end             -- App preferences exists.

        -- Palettes need to be retrieved before a new sprite is created in case
        -- it sets the app.sprite to the new sprite. Unfortunately, that
        -- means this is wasted effort if the palette type is "EMBEDDED" or
        -- there is no new sprite.
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local hexesProfile = {}

        if palType ~= "DEFAULT" then
            local palFile <const> = args.palFile --[[@as string]]
            hexesProfile, _ = AseUtilities.asePaletteLoad(
                palType, palFile, "", 0, 512, true)
        else
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
        end

        local openSprite = nil
        if asSeq then
            local fileSys <const> = app.fs
            local tconcat <const> = table.concat
            local strbyte <const> = string.byte
            local strchar <const> = string.char

            -- See https://steamcommunity.com/app/431730/discussions/2/501693855099265776/
            local frFile <const> = args.fromFile --[[@as string]]
            local toFile <const> = args.toFile --[[@as string]]

            local frFolder <const> = fileSys.filePath(frFile)
            local toFolder <const> = fileSys.filePath(toFile)
            if frFolder ~= toFolder then
                app.alert {
                    title = "Error",
                    text = "File paths aren't from the same folder."
                }
                return
            end

            local relFilePaths <const> = fileSys.listFiles(frFolder)
            local lenRelFilePaths <const> = #relFilePaths
            local supportedExts <const> = AseUtilities.FILE_FORMATS_OPEN
            local lenSupportedExts <const> = #supportedExts

            local frIdx = 1
            local toIdx = lenRelFilePaths
            local found = 0
            local h = 0
            while h < lenRelFilePaths and found < 2 do
                h = h + 1
                local relFilePath <const> = relFilePaths[h]
                local absFilePath <const> = fileSys.joinPath(frFolder, relFilePath)
                if absFilePath == frFile then
                    frIdx = h
                    found = found + 1
                end
                if absFilePath == toFile then
                    toIdx = h
                    found = found + 1
                end
            end

            ---@type Image[]
            local images <const> = {}
            local lenImages = 0
            local wMax = -2147483648
            local hMax = -2147483648

            local frIdxVrf = math.min(frIdx, toIdx)
            local toIdxVrf = math.max(frIdx, toIdx)

            local i = frIdxVrf - 1
            while i < toIdxVrf do
                i = i + 1
                local relFilePath <const> = relFilePaths[i]
                local fileExt <const> = fileSys.fileExtension(relFilePath)

                local isSupported = false
                local j = 0
                while (not isSupported) and j < lenSupportedExts do
                    j = j + 1
                    if fileExt == supportedExts[j] then
                        isSupported = true
                    end -- End check if ext is supported.
                end     -- End supported extensions loop.

                if isSupported then
                    local absFilePath <const> = fileSys.joinPath(
                        frFolder, relFilePath)
                    local srcImg <const> = Image { fromFile = absFilePath }
                    if srcImg then
                        local srcImgSpec <const> = srcImg.spec
                        local wSrcImg <const> = srcImgSpec.width
                        local hSrcImg <const> = srcImgSpec.height
                        local cmSrcImg <const> = srcImgSpec.colorMode

                        if wSrcImg > wMax then wMax = wSrcImg end
                        if hSrcImg > hMax then hMax = hSrcImg end

                        local trgImg = srcImg
                        if cmSrcImg ~= ColorMode.RGB then
                            ---@type string[]
                            local trgByteArr <const> = {}
                            local srcBytes <const> = srcImg.bytes
                            local areaSrcImg <const> = wSrcImg * hSrcImg

                            if cmSrcImg == ColorMode.GRAY then
                                local k = 0
                                while k < areaSrcImg do
                                    local k2 <const> = k + k
                                    local v8, t8 <const> = strbyte(
                                        srcBytes, 1 + k2, 2 + k2)
                                    if t8 <= 0 then v8 = 0 end
                                    local v8Char <const> = strchar(v8)
                                    local k4 <const> = k * 4
                                    trgByteArr[1 + k4] = v8Char
                                    trgByteArr[2 + k4] = v8Char
                                    trgByteArr[3 + k4] = v8Char
                                    trgByteArr[4 + k4] = strchar(t8)
                                    k = k + 1
                                end -- End pixels loop.
                            elseif cmSrcImg == ColorMode.INDEXED then
                                local palette <const> = Palette { fromFile = absFilePath }
                                if palette then
                                    local lenPalette <const> = #palette
                                    local alphaIndex <const> = srcImgSpec.transparentColor
                                    local keepBkg <const> = (alphaIndex >= 0 and
                                            alphaIndex < lenPalette)
                                        and palette:getColor(alphaIndex).alpha >= 255
                                        or false

                                    local k = 0
                                    while k < areaSrcImg do
                                        local i8 <const> = strbyte(srcBytes, 1 + k)

                                        local r8, g8, b8, t8 = 0, 0, 0, 0
                                        if (keepBkg or i8 ~= alphaIndex)
                                            and i8 >= 0
                                            and i8 < lenPalette then
                                            local ase <const> = palette:getColor(i8)
                                            t8 = ase.alpha
                                            if t8 > 0 then
                                                r8 = ase.red
                                                g8 = ase.green
                                                b8 = ase.blue
                                            end
                                        end

                                        local k4 <const> = k * 4
                                        trgByteArr[1 + k4] = strchar(r8)
                                        trgByteArr[2 + k4] = strchar(g8)
                                        trgByteArr[3 + k4] = strchar(b8)
                                        trgByteArr[4 + k4] = strchar(t8)

                                        k = k + 1
                                    end -- End pixels loop.
                                end     -- End palette exists.
                            end         -- End color mode block.

                            trgImg = Image(ImageSpec {
                                width = wSrcImg,
                                height = hSrcImg,
                                colorMode = ColorMode.RGB
                            })
                            trgImg.bytes = tconcat(trgByteArr)
                        end -- End image is not RGB.

                        lenImages = lenImages + 1
                        images[lenImages] = trgImg
                    end -- End image exists.
                end     -- End extension is supported.
            end         -- End relative paths loop.

            if lenImages > 0
                and wMax > 0
                and hMax > 0 then
                openSprite = AseUtilities.createSprite(
                    AseUtilities.createSpec(wMax, hMax),
                    "Sequence", showLayerEdges)

                if frIdx > toIdx then
                    Utilities.reverseTable(images)
                end

                app.transaction("Open Sequence", function()
                    -- While you could open the primary file as a palette,
                    -- grayscale images make that a poor option.
                    AseUtilities.setPalette(
                        AseUtilities.DEFAULT_PAL_ARR, openSprite)

                    -- Set the frame duration.
                    local fps <const> = args.fps
                        or defaults.fps --[[@as integer]]
                    local duration <const> = 1.0 / math.max(1, fps)
                    openSprite.frames[1].duration = duration
                    local j = 1
                    while j < lenImages do
                        j = j + 1
                        local frObj <const> = openSprite:newEmptyFrame(j)
                        frObj.duration = duration
                    end

                    local firstLayer <const> = openSprite.layers[1]
                    local k = 0
                    while k < lenImages do
                        k = k + 1
                        local image <const> = images[k]
                        local x <const> = (wMax - image.width) // 2
                        -- For baseline alignment:
                        -- local y <const> = hMax - image.height
                        local y <const> = (hMax - image.height) // 2
                        openSprite:newCel(firstLayer, k, image, Point(x, y))
                    end -- End frame, cel creation loop.
                end)    -- End transaction.
            end         -- End valid images exist.
        else
            openSprite = loadSprite(spriteFile, showLayerEdges)
        end -- End as sequence check.

        if not openSprite then
            app.alert {
                title = "Error",
                text = "Sprite could not be found."
            }
            return
        end
        app.sprite = openSprite

        local oldColorMode <const> = openSprite.colorMode
        AseUtilities.changePixelFormat(ColorMode.RGB)

        -- Due to indexed color mode backgrounds potentially containing
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
        local fixZeroAlpha <const> = args.fixZeroAlpha --[[@as boolean]]
        local acquireCels <const> = trimCels or fixZeroAlpha

        if acquireCels then
            local cels <const> = AseUtilities.filterCels(
                openSprite, nil, {}, "ALL",
                true, true, false, false)
            local lenCels <const> = #cels

            if trimCels then
                local trimImage <const> = AseUtilities.trimImageAlpha
                app.transaction("Trim Cels", function()
                    local j = 0
                    while j < lenCels do
                        j = j + 1
                        local cel <const> = cels[j]
                        local trgImg <const>, x <const>, y <const> = trimImage(
                            cel.image, 0, 0)
                        local srcPos <const> = cel.position
                        cel.position = Point(srcPos.x + x, srcPos.y + y)
                        cel.image = trgImg
                    end -- End cels loop.
                end)    -- End transaction.
            end         -- End trim cels.

            if fixZeroAlpha then
                local correctZero <const> = AseUtilities.correctZeroAlpha
                app.transaction("Correct Alpha", function()
                    local j = 0
                    while j < lenCels do
                        j = j + 1
                        local cel <const> = cels[j]
                        cel.image = correctZero(cel.image)
                    end -- End cels loop.
                end)    -- End transaction.
            end         -- End check alpha.
        end             -- End acquire cels.

        -- Restore old preferences.
        if appPrefs then
            local openFilePrefs <const> = appPrefs.open_file
            if openFilePrefs then
                openFilePrefs.open_sequence = oldOpSeqPref
            end

            local cmPrefs <const> = appPrefs.color
            if cmPrefs then
                cmPrefs.files_with_profile = oldAskProfile
                cmPrefs.missing_profile = oldAskMissing
            end

            local quantPrefs <const> = appPrefs.quantization
            if quantPrefs then
                quantPrefs.rgbmap_algorithm = oldQuantAlg
            end
        end

        app.frame = openSprite.frames[1]
        app.layer = openSprite.layers[#openSprite.layers]
        app.refresh()

        if autoFit then
            app.command.FitScreen()
        else
            app.command.Zoom {
                action = "set",
                focus = "center",
                percentage = 100.0
            }
            app.command.ScrollCenter()
        end

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