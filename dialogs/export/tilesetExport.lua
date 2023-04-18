dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local targetOptions = { "ACTIVE", "ALL" }

local defaults = {
    -- Atm, Aseprite tile and tile set objects
    -- don't include enough useful information
    -- to necessitate including them in JSON,
    -- esp. when they raise issues of how to
    -- format and organize.

    -- TODO: Test padding against Unity sprite sheet
    -- cutter tool. Consider adding margin, changing
    -- padding inbetween frames if needed.
    target = "ALL",
    padding = 0,
    scale = 1,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    saveJson = true,
    includeMaps = true,
    includeLocked = true,
    includeHidden = false,
    boundsFormat = "TOP_LEFT"
}

local sectionFormat = table.concat({
    "{\"id\":%s",
    "\"rect\":%s}",
}, ",")

local sheetFormat = table.concat({
    "{\"fileName\":\"%s\"",
    "\"size\":%s",
    "\"sizeGrid\":%s",
    "\"tiles\":[%s]}",
}, ",")

local mapFormat = table.concat({
    "{\"size\":%s",
    "\"indices\":[%s]",
    "\"frame\":%d",
    "\"layer\":%d}",
}, ",")

local function sectionToJson(section, boundsFormat)
    return string.format(sectionFormat,
        JsonUtilities.pointToJson(
            section.column, section.row),
        JsonUtilities.rectToJson(
            section.rect, boundsFormat))
end

local function mapToJson(map)
    return string.format(
        mapFormat,
        JsonUtilities.pointToJson(map.width, map.height),
        table.concat(map.indices, ","),
        map.frameNumber - 1,
        map.layer)
end

local function sheetToJson(sheet, boundsFormat)
    ---@type string[]
    local sectionsStrs = {}
    local sections = sheet.sections
    local lenSections = #sections
    local i = 0
    while i < lenSections do
        i = i + 1
        sectionsStrs[i] = sectionToJson(
            sections[i], boundsFormat)
    end

    return string.format(sheetFormat,
        sheet.fileName,
        JsonUtilities.pointToJson(
            sheet.width,
            sheet.height),
        JsonUtilities.pointToJson(
            sheet.columns,
            sheet.rows),
        table.concat(sectionsStrs, ","))
end

local dlg = Dialog { title = "Export Tilesets" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targetOptions,
    onchange = function()
        local args = dlg.data
        local saveJson = args.saveJson --[[@as boolean]]
        local includeMaps = args.includeMaps --[[@as boolean]]
        local allTarget = args.target == "ALL"
        dlg:modify { id = "includeLocked", visible = saveJson
            and includeMaps and allTarget }
        dlg:modify { id = "includeHidden", visible = saveJson
            and includeMaps and allTarget }
    end
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

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 10,
    value = defaults.scale
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
        local saveJson = args.saveJson --[[@as boolean]]
        local includeMaps = args.includeMaps --[[@as boolean]]
        local allTarget = args.target == "ALL"
        dlg:modify { id = "includeMaps", visible = saveJson }
        dlg:modify { id = "boundsFormat", visible = saveJson }
        dlg:modify { id = "userDataWarning", visible = saveJson }
        dlg:modify { id = "includeLocked", visible = saveJson
            and includeMaps and allTarget }
        dlg:modify { id = "includeHidden", visible = saveJson
            and includeMaps and allTarget }
    end
}

dlg:check {
    id = "includeMaps",
    label = "Include:",
    text = "&Tilemaps",
    selected = defaults.includeMaps,
    visible = defaults.saveJson,
    onclick = function()
        local args = dlg.data
        local enabled = args.includeMaps --[[@as boolean]]
        local allTarget = args.target == "ALL"
        dlg:modify { id = "includeLocked", visible = enabled
            and allTarget }
        dlg:modify { id = "includeHidden", visible = enabled
            and allTarget }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    text = "&Locked",
    selected = defaults.includeLocked,
    visible = defaults.saveJson
        and defaults.includeMaps
        and defaults.target == "ALL"
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    visible = defaults.saveJson
        and defaults.includeMaps
        and defaults.target == "ALL"
}

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

        -- Unpack arguments.
        local args = dlg.data
        local filename = args.filename --[[@as string]]
        local target = args.target
            or defaults.target --[[@as string]]
        local padding = args.padding
            or defaults.padding --[[@as integer]]
        local scale = args.scale
            or defaults.scale --[[@as integer]]
        local usePixelAspect = args.usePixelAspect --[[@as boolean]]
        local toPow2 = args.toPow2 --[[@as boolean]]
        local potUniform = args.potUniform --[[@as boolean]]
        local saveJson = args.saveJson --[[@as boolean]]
        local includeMaps = args.includeMaps --[[@as boolean]]
        local includeLocked = args.includeLocked --[[@as boolean]]
        local includeHidden = args.includeHidden --[[@as boolean]]
        local boundsFormat = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

        -- Unpack sprite spec.
        local spriteSpec = activeSprite.spec
        local spriteColorMode = spriteSpec.colorMode
        local spriteColorSpace = spriteSpec.colorSpace
        local spriteAlphaIndex = spriteSpec.transparentColor
        local spritePalettes = activeSprite.palettes

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

            if target == "ALL" and #spritePalettes > 1 then
                app.alert {
                    title = "Error",
                    text = {
                        "All tilesets not supported for indexed",
                        "sprites with multiple palettes."
                    }
                }
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

        -- Process scale.
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
        local pad2 = padding + padding
        local usePadding = padding > 0
        local nonUniformDim = not potUniform

        local sheetPalette = AseUtilities.getPalette(
            app.activeFrame, spritePalettes)

        local tileSets = {}
        if target == "ACTIVE" then
            local activeLayer = app.activeLayer
            if not activeLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
                }
                return
            end

            local isTilemap = activeLayer.isTilemap
            if not isTilemap then
                app.alert {
                    title = "Error",
                    text = "Active layer is not a tile map."
                }
                return
            end

            local tileSet = activeLayer.tileset
            tileSets[1] = tileSet
        else
            -- Default to all tilesets
            tileSets = activeSprite.tilesets
        end

        -- Cache methods used in loops.
        local resize = AseUtilities.resizeImageNearest
        local pad = AseUtilities.padImage
        local nextPow2 = Utilities.nextPowerOf2
        local ceil = math.ceil
        local max = math.max
        local sqrt = math.sqrt
        local strfmt = string.format
        local verifName = Utilities.validateFilename

        -- For JSON export.
        local sheetPackets = {}
        local lenTileSets = #tileSets
        local i = 0
        while i < lenTileSets do
            i = i + 1
            local tileSet = tileSets[i]
            local tileSetName = tileSet.name

            local tileGrid = tileSet.grid
            local tileDim = tileGrid.tileSize
            local wTileSrc = tileDim.width
            local hTileSrc = tileDim.height

            local tsNameVerif = tileSetName
            if tsNameVerif and #tsNameVerif > 1 then
                tsNameVerif = verifName(tileSetName)
            else
                tsNameVerif = strfmt("%03d", i - 1)
            end

            local wTileScale = wTileSrc * wScale
            local hTileScale = hTileSrc * hScale
            local wTileTrg = wTileScale + pad2
            local hTileTrg = hTileScale + pad2

            -- Same procedure as saving batched sheets in
            -- framesExport.
            local lenTileSet = #tileSet
            local columns = ceil(sqrt(lenTileSet))
            local rows = max(1, ceil(lenTileSet / columns))
            local wSheet = wTileTrg * columns
            local hSheet = hTileTrg * rows

            if toPow2 then
                if nonUniformDim then
                    wSheet = nextPow2(wSheet)
                    hSheet = nextPow2(hSheet)
                else
                    wSheet = nextPow2(max(wSheet, hSheet))
                    hSheet = wSheet
                end

                columns = max(1, wSheet // wTileTrg)
                rows = max(1, hSheet // hTileTrg)
            end

            -- Create composite image.
            local sheetSpec = ImageSpec {
                width = wSheet,
                height = hSheet,
                colorMode = spriteColorMode,
                transparentColor = spriteAlphaIndex
            }
            sheetSpec.colorSpace = spriteColorSpace
            local sheetImage = Image(sheetSpec)

            -- For JSON export.
            local sectionPackets = {}

            -- The first tile in a tile set is empty.
            -- Include this empty tile, and all others, to
            -- maintain indexing with tile maps.
            local k = 0
            while k < lenTileSet do
                local row = k // columns
                local column = k % columns

                local tile = tileSet:tile(k)
                k = k + 1

                -- Is the index different from j
                -- because of the tile set base index?
                local tileImage = tile.image --[[@as Image]]
                local tileScaled = tileImage
                if useResize then
                    tileScaled = resize(tileImage,
                        wTileScale, hTileScale)
                end
                local tilePadded = tileScaled
                if usePadding then
                    tilePadded = pad(tileScaled, padding)
                end

                local xTrg = column * wTileTrg
                local yTrg = row * hTileTrg
                sheetImage:drawImage(tilePadded, Point(xTrg, yTrg))

                local sectionPacket = {
                    column = column,
                    row = row,
                    rect = {
                        x = xTrg,
                        y = yTrg,
                        width = wTileTrg,
                        height = hTileTrg
                    }
                }
                sectionPackets[k] = sectionPacket
            end

            local fileNameShort = strfmt(
                "%s_%s",
                fileTitle, tsNameVerif)
            local fileNameLong = strfmt(
                "%s%s.%s",
                filePath, fileNameShort, fileExt)

            sheetImage:saveAs {
                filename = fileNameLong,
                palette = sheetPalette
            }

            local sheetPacket = {
                fileName = fileNameShort,
                width = wSheet,
                height = hSheet,
                columns = columns,
                rows = rows,
                sections = sectionPackets
            }
            sheetPackets[i] = sheetPacket
        end

        if saveJson then
            ---@type table[]
            local celPackets = {}
            -- Because frames is an inner array, use a dictionary
            -- to track unique frames that contain tile map cels.
            ---@type table<integer,table>
            local framePackets = {}
            ---@type table[]
            local layerPackets = {}
            ---@type table[]
            local mapPackets = {}

            if includeMaps then
                local pxTilei = app.pixelColor.tileI

                local frObjs = activeSprite.frames
                local tmFrames = Utilities.flatArr2(
                    AseUtilities.getFrames(activeSprite, target))

                local tmLayers = {}
                if target == "ACTIVE" then
                    -- This has already been validated to be
                    -- non-nil and a tile map at start of function.
                    tmLayers = { app.activeLayer }
                else
                    tmLayers = AseUtilities.getLayerHierarchy(
                        activeSprite,
                        includeLocked,
                        includeHidden,
                        true, false)
                end

                local lenTmFrames = #tmFrames
                local lenTmLayers = #tmLayers
                local j = 0
                while j < lenTmLayers do
                    j = j + 1
                    local tmLayer = tmLayers[j]
                    if tmLayer.isTilemap then
                        local tileSet = tmLayer.tileset
                        local tileGrid = tileSet.grid
                        local tileDim = tileGrid.tileSize
                        local wTile = tileDim.width
                        local hTile = tileDim.height
                        local lenTileSet = #tileSet

                        local layerId = tmLayer.id
                        ---@type userdata|Sprite|Layer
                        local parent = tmLayer.parent
                        local parentId = -1
                        if parent.__name ~= "doc::Sprite" then
                            parentId = parent.id
                        end

                        local layerPacket = {
                            blendMode = tmLayer.blendMode,
                            data = tmLayer.data,
                            id = layerId,
                            name = tmLayer.name,
                            opacity = tmLayer.opacity,
                            parent = parentId,
                            stackIndex = tmLayer.stackIndex
                        }
                        layerPackets[#layerPackets + 1] = layerPacket

                        local k = 0
                        while k < lenTmFrames do
                            k = k + 1
                            local tmFrame = tmFrames[k]
                            local framePacket = framePackets[tmFrame]
                            if not framePacket then
                                local frObj = frObjs[tmFrame]
                                framePacket = {
                                    frameNumber = tmFrame,
                                    duration = frObj.duration
                                }
                                framePackets[tmFrame] = framePacket
                            end

                            local tmCel = tmLayer:cel(tmFrame)
                            if tmCel then
                                local tmImage = tmCel.image
                                local tmPxItr = tmImage:pixels()

                                -- In the future, this would also need
                                -- a separate array of rotation flags.
                                ---@type integer[]
                                local tmIndicesArr = {}
                                for pixel in tmPxItr do
                                    local tlData = pixel()
                                    local tlIndex = pxTilei(tlData)
                                    if tlIndex >= lenTileSet then
                                        tlIndex = 0
                                    end
                                    tmIndicesArr[#tmIndicesArr + 1] = tlIndex
                                end

                                local wTileMap = tmImage.width
                                local hTileMap = tmImage.height
                                local mapPacket = {
                                    width = wTileMap,
                                    height = hTileMap,
                                    indices = tmIndicesArr,
                                    frameNumber = tmFrame,
                                    layer = layerId
                                }
                                mapPackets[#mapPackets + 1] = mapPacket

                                local tmCelPos = tmCel.position
                                local tmBounds = {
                                    x = tmCelPos.x,
                                    y = tmCelPos.y,
                                    width = wTileMap * wTile,
                                    height = hTileMap * hTile
                                }

                                local celPacket = {
                                    fileName = "",
                                    bounds = tmBounds,
                                    data = tmCel.data,
                                    frameNumber = tmFrame,
                                    layer = layerId,
                                    opacity = tmCel.opacity
                                }
                                celPackets[#celPackets + 1] = celPacket
                            end -- End cel exists check.
                        end     -- End frames loop.
                    end         -- End layer isTilemap check.
                end             -- End layers loop.
            end                 -- End include maps check.

            -- Cache Json methods.
            local celToJson = JsonUtilities.celToJson
            local frameToJson = JsonUtilities.frameToJson
            local layerToJson = JsonUtilities.layerToJson

            local h = 0
            ---@type string[]
            local tsStrs = {}
            local lenSheetPackets = #sheetPackets
            while h < lenSheetPackets do
                h = h + 1
                local sheet = sheetPackets[h]
                tsStrs[h] = sheetToJson(sheet, boundsFormat)
            end

            ---@type string[]
            local tmStrs = {}
            local lenMapPackets = #mapPackets
            local j = 0
            while j < lenMapPackets do
                j = j + 1
                local map = mapPackets[j]
                tmStrs[j] = mapToJson(map)
            end

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

            ---@type string[]
            local frameStrs = {}
            for _, frame in pairs(framePackets) do
                frameStrs[#frameStrs + 1] = frameToJson(frame)
            end

            local m = 0
            ---@type string[]
            local layerStrs = {}
            local lenLayerPackets = #layerPackets
            while m < lenLayerPackets do
                m = m + 1
                local layer = layerPackets[m]
                layerStrs[m] = layerToJson(layer)
            end

            local jsonFormat = table.concat({
                "{\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                "\"padding\":%d",
                "\"scale\":%d",
                "\"tileSets\":[%s]",
                "\"tileMaps\":[%s]",
                "\"cels\":[%s]",
                "\"frames\":[%s]",
                "\"layers\":[%s]",
                "\"sprite\":%s",
                "\"version\":%s}"
            }, ",")
            local jsonString = string.format(
                jsonFormat,
                filePath, fileExt,
                padding, scale,
                table.concat(tsStrs, ","),
                table.concat(tmStrs, ","),
                table.concat(celStrs, ","),
                table.concat(frameStrs, ","),
                table.concat(layerStrs, ","),
                JsonUtilities.spriteToJson(activeSprite),
                JsonUtilities.versionToJson())

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