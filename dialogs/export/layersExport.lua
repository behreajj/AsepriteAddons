dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local frameTargetOptions = { "ACTIVE", "ALL", "MANUAL", "RANGE" }
local layerTargetOptions = { "ACTIVE", "ALL", "RANGE" }
local cropTypes = { "CROPPED", "SPRITE" }

local defaults = {
    layerTarget = "ALL",
    includeLocked = true,
    includeHidden = false,
    includeTiles = false,
    includeBkg = true,
    bakeOpacity = true,
    flatGroups = true,
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6-9,13",
    cropType = "CROPPED",
    padding = 0,
    scale = 1,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    saveJson = false,
    boundsFormat = "TOP_LEFT"
}

local dlg = Dialog { title = "Export Layers" }

dlg:combobox {
    id = "layerTarget",
    label = "Layers:",
    option = defaults.layerTarget,
    options = layerTargetOptions,
    onchange = function()
        local args = dlg.data
        local state = args.layerTarget
        local isNotRange = state ~= "RANGE"
        dlg:modify { id = "flatGroups", visible = isNotRange }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden
}

dlg:newrow { always = false }

dlg:check {
    id = "includeTiles",
    text = "&Tiles",
    selected = defaults.includeTiles
}

dlg:check {
    id = "includeBkg",
    text = "&Background",
    selected = defaults.includeBkg
}

dlg:newrow { always = false }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args = dlg.data
        local state = args.frameTarget
        local isManual = state == "MANUAL"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Entry:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.frameTarget == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "cropType",
    label = "Trim:",
    option = defaults.cropType,
    options = cropTypes
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 10,
    value = defaults.scale
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding
}

dlg:newrow { always = false }

dlg:check {
    id = "bakeOpacity",
    label = "Bake:",
    text = "Op&acity",
    selected = defaults.bakeOpacity,
    visible = true
}

dlg:check {
    id = "flatGroups",
    label = "Flatten:",
    text = "&Groups",
    selected = defaults.flatGroups,
    visible = defaults.layerTarget ~= "RANGE"
}

dlg:newrow { always = false }

dlg:check {
    id = "usePixelAspect",
    label = "Apply:",
    text = "Pi&xel Aspect",
    selected = defaults.usePixelAspect,
    visible = true
}

dlg:newrow { always = false }

dlg:check {
    id = "toPow2",
    label = "Nearest:",
    text = "&Power of 2",
    selected = defaults.toPow2,
    visible = true,
    onclick = function()
        local args = dlg.data
        local state = args.toPow2
        dlg:modify { id = "potUniform", visible = state }
    end
}

dlg:check {
    id = "potUniform",
    text = "&Uniform",
    selected = defaults.potUniform,
    visible = defaults.toPow2
}

dlg:newrow { always = false }

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS,
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:check {
    id = "saveJson",
    label = "Save:",
    text = "&JSON",
    selected = defaults.saveJson,
    onclick = function()
        local args = dlg.data
        local enabled = args.saveJson
        dlg:modify { id = "boundsFormat", visible = enabled }
        dlg:modify { id = "userDataWarning", visible = enabled }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "boundsFormat",
    label = "Format:",
    option = defaults.boundsFormat,
    options = JsonUtilities.RECT_OPTIONS,
    visible = defaults.saveJson
}

dlg:newrow { always = false }

dlg:label {
    id = "userDataWarning",
    label = "Note:",
    text = "User data not escaped.",
    visible = defaults.saveJson
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack sprite spec.
        local spriteSpec = activeSprite.spec
        local spriteColorMode = spriteSpec.colorMode
        local spriteColorSpace = spriteSpec.colorSpace
        local spriteAlphaIndex = spriteSpec.transparentColor
        local spritePalettes = activeSprite.palettes
        local spriteWidth = spriteSpec.width
        local spriteHeight = spriteSpec.height

        -- Unpack arguments.
        local args = dlg.data
        local filename = args.filename --[[@as string]]
        local layerTarget = args.layerTarget
            or defaults.layerTarget --[[@as string]]
        local includeLocked = args.includeLocked --[[@as boolean]]
        local includeHidden = args.includeHidden --[[@as boolean]]
        local includeTiles = args.includeTiles --[[@as boolean]]
        local includeBkg = args.includeBkg --[[@as boolean]]
        local bakeOpacity = args.bakeOpacity --[[@as boolean]]
        local flatGroups = args.flatGroups --[[@as boolean]]
        local frameTarget = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local cropType = args.cropType
            or defaults.cropType --[[@as string]]
        local scale = args.scale or defaults.scale --[[@as integer]]
        local padding = args.padding
            or defaults.padding --[[@as integer]]
        local usePixelAspect = args.usePixelAspect --[[@as boolean]]
        local toPow2 = args.toPow2 --[[@as boolean]]
        local potUniform = args.potUniform --[[@as boolean]]
        local saveJson = args.saveJson --[[@as boolean]]
        local boundsFormat = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

        -- Validate file name.
        local fileExt = app.fs.fileExtension(filename)
        if string.lower(fileExt) == "json" then
            fileExt = app.preferences.export_file.image_default_extension
            filename = string.sub(filename, 1, -5) .. fileExt
        end

        local filePath = app.fs.filePath(filename)
        if filePath == nil or #filePath < 1 then
            app.alert { title = "Error", text = "Empty file path." }
            return
        end
        filePath = string.gsub(filePath, "\\", "\\\\")

        -- .webp file extensions do not allow indexed
        -- color mode and Aseprite doesn't handle this
        -- limitation gracefully.
        if spriteColorMode == ColorMode.INDEXED then
            if string.lower(fileExt) == "webp" then
                app.alert {
                    title = "Error",
                    text = "Indexed color not supported for webp."
                }
                return
            end
        elseif spriteColorMode == ColorMode.GRAY then
            if string.lower(fileExt) == "bmp" then
                app.alert {
                    title = "Error",
                    text = "Grayscale not supported for bmp."
                }
                return
            end
        end

        local pathSep = app.fs.pathSeparator
        pathSep = string.gsub(pathSep, "\\", "\\\\")

        local fileTitle = app.fs.fileTitle(filename)
        if #fileTitle < 1 then
            fileTitle = app.fs.fileTitle(activeSprite.filename)
        end
        fileTitle = Utilities.validateFilename(fileTitle)

        filePath = filePath .. pathSep
        local filePrefix = filePath .. fileTitle

        -- Process scale
        local wScale = scale
        local hScale = scale
        if usePixelAspect then
            local pxRatio = activeSprite.pixelRatio
            local pxw = math.max(1, math.abs(pxRatio.width))
            local pxh = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end
        local useResize = wScale ~= 1 or hScale ~= 1

        -- Process commonly used equivalences.
        local cropToSprite = cropType == "SPRITE"
        local normalBlendMode = BlendMode.NORMAL
        local zeroPoint = Point(0, 0)
        local nonUniformDim = not potUniform
        local usePadding = padding > 0

        -- Cache methods used in loops.
        local floor = math.floor
        local strfmt = string.format
        local appendLeaves = AseUtilities.appendLeaves
        local getPalette = AseUtilities.getPalette
        local expandPow2 = AseUtilities.expandImageToPow2
        local nameVerify = Utilities.validateFilename
        local padImage = AseUtilities.padImage
        local resize = AseUtilities.resizeImageNearest
        local trimAlpha = AseUtilities.trimImageAlpha

        local chosenFrames = Utilities.flatArr2(
            AseUtilities.getFrames(
                activeSprite, frameTarget,
                true, rangeStr))
        local lenChosenFrames = #chosenFrames
        local spriteFrameObjs = activeSprite.frames

        ---@type Layer[]
        local topLayers = {}
        if layerTarget == "ALL" then
            -- print("ALL layers chosen")
            topLayers = activeSprite.layers
        elseif layerTarget == "RANGE" then
            -- print("RANGE layers chosen")
            local tlHidden = not app.preferences.general.visible_timeline
            if tlHidden then
                app.command.Timeline { open = true }
            end

            local appRange = app.range
            if appRange.sprite == activeSprite then
                local rangeLayers = appRange.layers
                local lenRangeLayers = #rangeLayers
                local i = 0
                while i < lenRangeLayers do
                    i = i + 1
                    local rangeLayer = rangeLayers[i]
                    if not rangeLayer.isGroup then
                        topLayers[#topLayers + 1] = rangeLayer
                    end
                end
            end

            if tlHidden then
                app.command.Timeline { close = true }
            end
        else
            -- print("ACTIVE layers chosen")
            local activeLayer = app.activeLayer
            if activeLayer then
                topLayers = { activeLayer }
            end
        end
        local lenTopLayers = #topLayers

        -- Because the layers loop is the inner loop below,
        -- avoid processing this information for each frame.
        local g = 0
        local lenChosenLayers = 0
        ---@type Layer[]
        local chosenLayers = {}
        ---@type string[]
        local verifLayerNames = {}
        while g < lenTopLayers do
            g = g + 1
            local topLayer = topLayers[g]
            if topLayer.isGroup then
                if flatGroups then
                    lenChosenLayers = lenChosenLayers + 1
                    chosenLayers[lenChosenLayers] = topLayer
                    verifLayerNames[lenChosenLayers] = nameVerify(topLayer.name)
                else
                    local leaves = appendLeaves(
                        topLayer, {},
                        includeLocked, includeHidden,
                        includeTiles, includeBkg)
                    local lenLeaves = #leaves

                    local h = 0
                    while h < lenLeaves do
                        h = h + 1
                        local leaf = leaves[h]
                        -- print(string.format("leaf:%s", leaf.name))
                        lenChosenLayers = lenChosenLayers + 1
                        chosenLayers[lenChosenLayers] = leaf
                        verifLayerNames[lenChosenLayers] = nameVerify(leaf.name)
                    end
                end
            elseif (not topLayer.isReference)
                and (includeLocked or topLayer.isEditable)
                and (includeHidden or topLayer.isVisible)
                and (includeTiles or (not topLayer.isTilemap))
                and (includeBkg or (not topLayer.isBackground)) then
                lenChosenLayers = lenChosenLayers + 1
                chosenLayers[lenChosenLayers] = topLayer
                verifLayerNames[lenChosenLayers] = nameVerify(topLayer.name)
            end
        end

        local i = 0
        ---@type table<integer, table>
        local layerPackets = {}
        ---@type table[]
        local framePackets = {}
        ---@type table[]
        local celPackets = {}
        while i < lenChosenFrames do
            i = i + 1
            local frIdx = chosenFrames[i]

            -- For JSON writing:
            local frObj = spriteFrameObjs[frIdx]
            local framePacket = {
                frameNumber = frIdx,
                duration = frObj.duration
            }
            framePackets[i] = framePacket

            -- For saving the image in Indexed color mode.
            local activePalette = getPalette(frIdx, spritePalettes)

            local j = 0
            while j < lenChosenLayers do
                j = j + 1
                local chosenLayer = chosenLayers[j]

                -- Reset on inner loop to avoid repeating images.
                local image = nil
                local bounds = nil

                -- For JSON packets.
                local celData = nil
                local celOpacity = 255
                local layerOpacity = 255
                local layerBlendMode = normalBlendMode

                if chosenLayer.isGroup then
                    -- print("Layer is a group")
                    image, bounds = AseUtilities.flattenGroup(
                        chosenLayer, frIdx,
                        spriteColorMode,
                        spriteColorSpace,
                        spriteAlphaIndex,
                        includeLocked,
                        includeHidden,
                        includeTiles,
                        includeBkg)
                else
                    layerOpacity = chosenLayer.opacity
                    layerBlendMode = chosenLayer.blendMode

                    local cel = chosenLayer:cel(frIdx)
                    if cel then
                        -- print("Cel was found.")
                        celData = cel.data
                        celOpacity = cel.opacity

                        image = cel.image
                        if chosenLayer.isTilemap then
                            local tileSet = chosenLayer.tileset
                            image = AseUtilities.tilesToImage(
                                image, tileSet, spriteColorMode)
                        end

                        if bakeOpacity then
                            -- print("Baking opacity.")
                            local celOpac01 = celOpacity * 0.003921568627451
                            local layerOpac01 = layerOpacity * 0.003921568627451
                            local compOpac01 = celOpac01 * layerOpac01
                            local compOpacity = floor(compOpac01 * 255.0 + 0.5)

                            local bakedImage = Image(image.spec)
                            bakedImage:drawImage(
                                image, zeroPoint,
                                compOpacity, normalBlendMode)

                            image = bakedImage

                            -- After finished baking, then reset
                            layerOpacity = 255
                            celOpacity = 255
                        end

                        -- Calculate manually. Don't use cel bounds.
                        local celPos = cel.position
                        bounds = Rectangle(
                            celPos.x, celPos.y,
                            image.width, image.height)
                    end
                end

                if image and bounds then
                    if cropToSprite then
                        local imgSprite = Image(spriteSpec)
                        imgSprite:drawImage(image, Point(bounds.x, bounds.y))

                        image = imgSprite
                        bounds.x = 0
                        bounds.y = 0
                        bounds.width = spriteWidth
                        bounds.height = spriteHeight
                    else
                        local imgTrim, xTrim, yTrim = trimAlpha(
                            image, 0, spriteAlphaIndex, 8, 8)

                        image = imgTrim
                        bounds.x = bounds.x + xTrim
                        bounds.y = bounds.y + yTrim
                        bounds.width = imgTrim.width
                        bounds.height = imgTrim.height
                    end

                    -- There's no point in continuing further
                    -- if the image is empty.
                    if not image:isEmpty() then
                        -- print("Image is not clear")
                        if useResize then
                            local imgResized = resize(image,
                                image.width * wScale,
                                image.height * hScale)
                            image = imgResized
                        end

                        if usePadding then
                            local imgPadded = padImage(image, padding)
                            image = imgPadded
                        end

                        if toPow2 then
                            local imgPow2 = expandPow2(
                                image,
                                spriteColorMode,
                                spriteAlphaIndex,
                                spriteColorSpace,
                                nonUniformDim)

                            -- Bounds are not updated here because
                            -- user may want to extract image from pot.
                            image = imgPow2
                        end

                        local layerName = verifLayerNames[j]
                        local fileNameShort = strfmt(
                            "%s_%s_%03d",
                            fileTitle, layerName, frIdx - 1)
                        local fileNameLong = strfmt(
                            "%s%s.%s",
                            filePath, fileNameShort, fileExt)

                        -- print(string.format("fileNameLong: %s", fileNameLong))

                        image:saveAs {
                            filename = fileNameLong,
                            palette = activePalette
                        }

                        if saveJson then
                            local layerId = chosenLayer.id
                            if not layerPackets[layerId] then
                                ---@type userdata|Sprite|Layer
                                local parent = chosenLayer.parent
                                local parentId = -1
                                if parent.__name ~= "doc::Sprite" then
                                    parentId = parent.id
                                end

                                local layerPacket = {
                                    blendMode = layerBlendMode,
                                    data = chosenLayer.data,
                                    id = layerId,
                                    name = layerName,
                                    opacity = layerOpacity,
                                    parent = parentId,
                                    stackIndex = chosenLayer.stackIndex,
                                }
                                layerPackets[layerId] = layerPacket
                            end

                            local celPacket = {
                                fileName = fileNameShort,
                                bounds = bounds,
                                data = celData,
                                frameNumber = frIdx,
                                layer = layerId,
                                opacity = celOpacity
                            }
                            celPackets[#celPackets + 1] = celPacket
                        end -- End of saveJson check
                    end     -- End of image empty check.
                end         -- End of image/bounds nil check.
            end             -- End loop through chosen layers.
        end                 -- End loop through chosen frames.

        if saveJson then
            -- Cache Json methods.
            local celToJson = JsonUtilities.celToJson
            local frameToJson = JsonUtilities.frameToJson
            local layerToJson = JsonUtilities.layerToJson

            local k = 0
            ---@type string[]
            local celStrs = {}
            local lenCelPackets = #celPackets
            while k < lenCelPackets do
                k = k + 1
                local cel = celPackets[k]
                celStrs[k] = celToJson(
                    cel, cel.fileName, boundsFormat)
            end

            local m = 0
            ---@type string[]
            local frameStrs = {}
            while m < lenChosenFrames do
                m = m + 1
                frameStrs[m] = frameToJson(framePackets[m])
            end

            ---@type string[]
            local layerStrs = {}
            for _, layer in pairs(layerPackets) do
                layerStrs[#layerStrs + 1] = layerToJson(layer)
            end

            local jsonFormat = table.concat({
                "{\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                "\"padding\":%d",
                "\"scale\":%d",
                "\"cels\":[%s]",
                "\"frames\":[%s]",
                "\"layers\":[%s]",
                "\"sprite\":%s",
                "\"version\":%s}",
            }, ",")
            local jsonString = string.format(
                jsonFormat,
                filePath, fileExt,
                padding, scale,
                table.concat(celStrs, ","),
                table.concat(frameStrs, ","),
                table.concat(layerStrs, ","),
                JsonUtilities.spriteToJson(activeSprite),
                JsonUtilities.versionToJson()
            )

            local jsonFilepath = filePrefix
            if #fileTitle < 1 then
                jsonFilepath = filePath .. pathSep .. "manifest"
            end
            jsonFilepath = jsonFilepath .. ".json"

            local file, err = io.open(jsonFilepath, "w")
            if file then
                file:write(jsonString)
                file:close()
            end

            if err then
                app.refresh()
                app.alert { title = "Error", text = err }
                return
            end
        end

        app.alert {
            title = "Success",
            text = "File(s) exported."
        }
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