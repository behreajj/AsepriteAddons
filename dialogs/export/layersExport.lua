dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local frameTargetOptions <const> = { "ACTIVE", "ALL", "MANUAL", "RANGE" }
local layerTargetOptions <const> = { "ACTIVE", "ALL", "RANGE" }
local cropTypes <const> = { "CROPPED", "SPRITE" }

local defaults <const> = {
    -- If there's a malformed palette in indexed color mode, then background
    -- layers will save with transparency where there shouldn't be.

    -- "TAG" and "TAGS" frame targets are not supported because they would
    -- require extra data to be written to the json data.
    layerTarget = "ALL",
    includeLocked = true,
    includeHidden = false,
    includeTiles = false,
    includeBkg = true,
    bakeOpacity = true,
    flatGroups = true,
    frameTarget = "ACTIVE",
    rangeStr = "",
    strExample = "4,6:9,13",
    cropType = "CROPPED",
    padding = 0,
    scale = 1,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    saveJson = false,
    boundsFormat = "TOP_LEFT"
}

local dlg <const> = Dialog { title = "Export Layers" }

dlg:combobox {
    id = "layerTarget",
    label = "Layers:",
    option = defaults.layerTarget,
    options = layerTargetOptions,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.layerTarget --[[@as string]]
        local isNotRange <const> = state ~= "RANGE"
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
        local args <const> = dlg.data
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"
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
        local args <const> = dlg.data
        local state <const> = args.toPow2 --[[@as boolean]]
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
    filetypes = AseUtilities.FILE_FORMATS_SAVE,
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
        local args <const> = dlg.data
        local enabled <const> = args.saveJson --[[@as boolean]]
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local spriteColorMode <const> = spriteSpec.colorMode
        local spriteColorSpace <const> = spriteSpec.colorSpace
        local spriteAlphaIndex <const> = spriteSpec.transparentColor
        local spritePalettes <const> = activeSprite.palettes
        local spriteWidth <const> = spriteSpec.width
        local spriteHeight <const> = spriteSpec.height

        -- Unpack arguments.
        local args <const> = dlg.data
        local filename = args.filename --[[@as string]]
        local layerTarget = args.layerTarget
            or defaults.layerTarget --[[@as string]]
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local includeTiles <const> = args.includeTiles --[[@as boolean]]
        local includeBkg <const> = args.includeBkg --[[@as boolean]]
        local bakeOpacity <const> = args.bakeOpacity --[[@as boolean]]
        local flatGroups <const> = args.flatGroups --[[@as boolean]]
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local cropType <const> = args.cropType
            or defaults.cropType --[[@as string]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]
        local toPow2 <const> = args.toPow2 --[[@as boolean]]
        local potUniform <const> = args.potUniform --[[@as boolean]]
        local saveJson <const> = args.saveJson --[[@as boolean]]
        local boundsFormat <const> = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

        -- Validate file name.
        local fileExt = app.fs.fileExtension(filename)
        if string.lower(fileExt) == "json" then
            fileExt = app.preferences.export_file.image_default_extension --[[@as string]]
            filename = string.sub(filename, 1, -5) .. fileExt
        end

        local filePath = app.fs.filePath(filename)
        if filePath == nil or #filePath < 1 then
            app.alert { title = "Error", text = "Empty file path." }
            return
        end
        filePath = string.gsub(filePath, "\\", "\\\\")

        -- For explanatory comment, see framesExport.lua .
        if spriteColorMode == ColorMode.INDEXED then
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "webp"
                or lcFileExt == "jpg"
                or lcFileExt == "jpeg"
                or lcFileExt == "qoi"
                or lcFileExt == "tga" then
                app.alert {
                    title = "Error",
                    text = {
                        "Indexed color not supported for",
                        "jpeg, jpg, qoi, tga or webp."
                    }
                }
                return
            end
        elseif spriteColorMode == ColorMode.GRAY then
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "bmp"
                or lcFileExt == "qoi"
                or lcFileExt == "webp" then
                app.alert {
                    title = "Error",
                    text = "Grayscale not supported for bmp, qoi or webp."
                }
                return
            end
        end

        -- TODO: Replace these usages with app.fs.joinPath
        local pathSep = app.fs.pathSeparator
        pathSep = string.gsub(pathSep, "\\", "\\\\")

        local fileTitle = app.fs.fileTitle(filename)
        if #fileTitle < 1 then
            fileTitle = app.fs.fileTitle(activeSprite.filename)
        end
        fileTitle = Utilities.validateFilename(fileTitle)

        filePath = filePath .. pathSep
        local filePrefix <const> = filePath .. fileTitle

        -- Process scale
        local wScale = scale
        local hScale = scale
        if usePixelAspect then
            local pxRatio <const> = activeSprite.pixelRatio
            local pxw <const> = math.max(1, math.abs(pxRatio.width))
            local pxh <const> = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end
        local useResize <const> = wScale ~= 1 or hScale ~= 1

        -- Process commonly used equivalences.
        local cropToSprite <const> = cropType == "SPRITE"
        local blendModeNormal <const> = BlendMode.NORMAL
        local blendModeSrc <const> = BlendMode.SRC
        local zeroPoint <const> = Point(0, 0)
        local nonUniformDim <const> = not potUniform
        local usePadding <const> = padding > 0

        -- Cache methods used in loops.
        local floor <const> = math.floor
        local strfmt <const> = string.format
        local appendLeaves <const> = AseUtilities.appendLeaves
        local getPalette <const> = AseUtilities.getPalette
        local expandPow2 <const> = AseUtilities.expandImageToPow2
        local nameVerify <const> = Utilities.validateFilename
        local padImage <const> = AseUtilities.padImage
        local upscale <const> = AseUtilities.upscaleImageForExport
        local trimAlpha <const> = AseUtilities.trimImageAlpha

        local chosenFrames <const> = Utilities.flatArr2(AseUtilities.getFrames(
            activeSprite, frameTarget, true, rangeStr))
        local lenChosenFrames <const> = #chosenFrames
        if lenChosenFrames <= 0 then
            app.alert {
                title = "Error",
                text = "No frames were selected."
            }
            return
        end

        local spriteFrameObjs <const> = activeSprite.frames

        ---@type Layer[]
        local topLayers = {}
        if layerTarget == "ALL" then
            -- print("ALL layers chosen")
            topLayers = activeSprite.layers
        elseif layerTarget == "RANGE" then
            -- print("RANGE layers chosen")
            local tlHidden <const> = not app.preferences.general.visible_timeline
            if tlHidden then
                app.command.Timeline { open = true }
            end

            local range <const> = app.range
            if range.sprite == activeSprite then
                -- If range is RangeType.FRAMES, then the layers table will be
                -- empty, but maybe that is appropriate for export, unlike with
                -- toggling visibility, etc.
                local rangeLayers <const> = range.layers
                local lenRangeLayers <const> = #rangeLayers
                local lenTopLayers = 0
                local i = 0
                while i < lenRangeLayers do
                    i = i + 1
                    local rangeLayer <const> = rangeLayers[i]
                    if not rangeLayer.isGroup then
                        lenTopLayers = lenTopLayers + 1
                        topLayers[lenTopLayers] = rangeLayer
                    end
                end

                -- Layers in a range can be out of order.
                table.sort(topLayers, function(a, b)
                    if a.stackIndex == b.stackIndex then
                        return a.name < b.name
                    end
                    return a.stackIndex < b.stackIndex
                end)
            end

            if tlHidden then
                app.command.Timeline { close = true }
            end
        else
            -- print("ACTIVE layers chosen")
            local activeLayer <const> = site.layer
            if activeLayer then
                topLayers = { activeLayer }
            end
        end
        local lenTopLayers <const> = #topLayers

        -- Because the layers loop is the inner loop below,
        -- avoid processing this information for each frame.
        local g = 0
        local lenChosenLayers = 0
        ---@type Layer[]
        local chosenLayers <const> = {}
        ---@type string[]
        local verifLayerNames <const> = {}
        while g < lenTopLayers do
            g = g + 1
            local topLayer <const> = topLayers[g]
            if topLayer.isGroup then
                if flatGroups then
                    lenChosenLayers = lenChosenLayers + 1
                    chosenLayers[lenChosenLayers] = topLayer
                    verifLayerNames[lenChosenLayers] = nameVerify(topLayer.name)
                else
                    local leaves <const> = appendLeaves(
                        topLayer, {},
                        includeLocked, includeHidden,
                        includeTiles, includeBkg)
                    local lenLeaves <const> = #leaves

                    local h = 0
                    while h < lenLeaves do
                        h = h + 1
                        local leaf <const> = leaves[h]
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

        if lenChosenLayers <= 0 then
            app.alert {
                title = "Error",
                text = "No layers were selected."
            }
            return
        end

        local i = 0
        ---@type table<integer, table>
        local layerPackets <const> = {}
        ---@type table[]
        local framePackets <const> = {}
        ---@type table[]
        local celPackets <const> = {}
        while i < lenChosenFrames do
            i = i + 1
            local frIdx <const> = chosenFrames[i]

            -- For JSON writing:
            local frObj <const> = spriteFrameObjs[frIdx]
            local framePacket <const> = {
                frameNumber = frIdx,
                duration = frObj.duration
            }
            framePackets[i] = framePacket

            -- For saving the image in Indexed color mode.
            local activePalette <const> = getPalette(frIdx, spritePalettes)

            local j = 0
            while j < lenChosenLayers do
                j = j + 1
                local chosenLayer <const> = chosenLayers[j]

                -- Reset on inner loop to avoid repeating images.
                local image = nil
                local bounds = nil

                -- For JSON packets.
                ---@type table<string, any>
                local celProps = {}
                local celData = nil
                local celOpacity = 255
                local zIndex = 0
                local layerOpacity = 255
                local layerBlendMode = blendModeNormal

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

                    local cel <const> = chosenLayer:cel(frIdx)
                    if cel then
                        -- print("Cel was found.")
                        celData = cel.data
                        celOpacity = cel.opacity
                        celProps = cel.properties

                        -- Beware that this property is not shared between
                        -- linked cels.
                        zIndex = cel.zIndex

                        image = cel.image
                        if chosenLayer.isTilemap then
                            local tileSet <const> = chosenLayer.tileset
                            image = AseUtilities.tileMapToImage(
                                image, tileSet, spriteColorMode)
                        end

                        if bakeOpacity then
                            -- print("Baking opacity.")
                            local celOpac01 <const> = celOpacity / 255.0
                            local layerOpac01 <const> = layerOpacity / 255.0
                            local compOpac01 <const> = celOpac01 * layerOpac01
                            local compOpacity <const> = floor(compOpac01 * 255.0 + 0.5)

                            local bakedImage <const> = Image(image.spec)
                            bakedImage:drawImage(
                                image, zeroPoint,
                                compOpacity, blendModeSrc)

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
                        local imgSprite <const> = Image(spriteSpec)
                        imgSprite:drawImage(image,
                            Point(bounds.x, bounds.y),
                            255, blendModeSrc)

                        image = imgSprite
                        bounds.x = 0
                        bounds.y = 0
                        bounds.width = spriteWidth
                        bounds.height = spriteHeight
                    else
                        local imgTrim <const>, xTrim <const>, yTrim <const> = trimAlpha(
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
                            local imgResized <const> = upscale(image,
                                wScale, hScale)
                            image = imgResized
                        end

                        if usePadding then
                            local imgPadded <const> = padImage(image, padding)
                            image = imgPadded
                        end

                        if toPow2 then
                            local imgPow2 <const> = expandPow2(image,
                                nonUniformDim)

                            -- Bounds are not updated here because
                            -- user may want to extract image from pot.
                            image = imgPow2
                        end

                        local layerName <const> = verifLayerNames[j]
                        local fileNameShort <const> = strfmt(
                            "%s_%s_%03d",
                            fileTitle, layerName, frIdx - 1)
                        local fileNameLong <const> = strfmt(
                            "%s%s.%s",
                            filePath, fileNameShort, fileExt)

                        -- print(string.format("fileNameLong: %s", fileNameLong))

                        image:saveAs {
                            filename = fileNameLong,
                            palette = activePalette
                        }

                        if saveJson then
                            local layerId <const> = chosenLayer.id
                            if not layerPackets[layerId] then
                                local parent <const> = chosenLayer.parent
                                local parentId = -1
                                ---@diagnostic disable-next-line: undefined-field
                                if parent.__name ~= "doc::Sprite" then
                                    parentId = parent.id
                                end

                                local layerPacket <const> = {
                                    blendMode = layerBlendMode,
                                    data = chosenLayer.data,
                                    id = layerId,
                                    name = layerName,
                                    opacity = layerOpacity,
                                    parent = parentId,
                                    stackIndex = chosenLayer.stackIndex,
                                    properties = chosenLayer.properties
                                }
                                layerPackets[layerId] = layerPacket
                            end

                            local celPacket <const> = {
                                fileName = fileNameShort,
                                bounds = bounds,
                                data = celData,
                                frameNumber = frIdx,
                                layer = layerId,
                                opacity = celOpacity,
                                zIndex = zIndex,
                                properties = celProps
                            }
                            celPackets[#celPackets + 1] = celPacket
                        end -- End of saveJson check
                    end     -- End of image empty check.
                end         -- End of image/bounds nil check.
            end             -- End loop through chosen layers.
        end                 -- End loop through chosen frames.

        if saveJson then
            -- Cache Json methods.
            local celToJson <const> = JsonUtilities.celToJson
            local frameToJson <const> = JsonUtilities.frameToJson
            local layerToJson <const> = JsonUtilities.layerToJson

            local k = 0
            ---@type string[]
            local celStrs <const> = {}
            local lenCelPackets <const> = #celPackets
            while k < lenCelPackets do
                k = k + 1
                local cel <const> = celPackets[k]
                celStrs[k] = celToJson(
                    cel, cel.fileName, boundsFormat)
            end

            local m = 0
            ---@type string[]
            local frameStrs <const> = {}
            while m < lenChosenFrames do
                m = m + 1
                frameStrs[m] = frameToJson(framePackets[m])
            end

            ---@type string[]
            local layerStrs <const> = {}
            for _, layer in pairs(layerPackets) do
                layerStrs[#layerStrs + 1] = layerToJson(layer)
            end

            local jsonFormat <const> = table.concat({
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
            local jsonString <const> = string.format(
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

            local file <const>, err <const> = io.open(jsonFilepath, "w")
            if file then
                file:write(jsonString)
                file:close()
            end

            if err then
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

dlg:show {
    autoscrollbars = true,
    wait = false
}