dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local targetOptions <const> = { "ACTIVE", "ALL" }

local defaults <const> = {
    -- Atm, Aseprite tile and tile set objects
    -- don't include enough useful information
    -- to necessitate including them in JSON,
    -- esp. when they raise issues of how to
    -- format and organize.
    target = "ALL",
    border = 0,
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

local sectionFormat <const> = table.concat({
    "{\"id\":%s",
    "\"rect\":%s}",
}, ",")

local sheetFormat <const> = table.concat({
    "{\"fileName\":\"%s\"",
    "\"size\":%s",
    "\"sizeGrid\":%s",
    "\"tiles\":[%s]}",
}, ",")

local mapFormat <const> = table.concat({
    "{\"size\":%s",
    "\"indices\":[%s]",
    "\"frame\":%d",
    "\"layer\":%d}",
}, ",")

---@param section table
---@param boundsFormat string
---@return string
local function sectionToJson(section, boundsFormat)
    return string.format(sectionFormat,
        JsonUtilities.pointToJson(
            section.column, section.row),
        JsonUtilities.rectToJson(
            section.rect, boundsFormat))
end

---@param map table
---@return string
local function mapToJson(map)
    return string.format(
        mapFormat,
        JsonUtilities.pointToJson(map.width, map.height),
        table.concat(map.indices, ","),
        map.frameNumber - 1,
        map.layer)
end

---@param sheet table
---@param boundsFormat string
---@return string
local function sheetToJson(sheet, boundsFormat)
    ---@type string[]
    local sectionsStrs <const> = {}
    local sections <const> = sheet.sections
    local lenSections <const> = #sections
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

local dlg <const> = Dialog { title = "Export Tilesets" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targetOptions,
    onchange = function()
        local args <const> = dlg.data
        local saveJson <const> = args.saveJson --[[@as boolean]]
        local includeMaps <const> = args.includeMaps --[[@as boolean]]
        local allTarget <const> = args.target == "ALL"
        dlg:modify { id = "includeLocked", visible = saveJson
            and includeMaps and allTarget }
        dlg:modify { id = "includeHidden", visible = saveJson
            and includeMaps and allTarget }
    end
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

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 32,
    value = defaults.border
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
        local args <const> = dlg.data
        local saveJson <const> = args.saveJson --[[@as boolean]]
        local includeMaps <const> = args.includeMaps --[[@as boolean]]
        local allTarget <const> = args.target == "ALL"
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
        local args <const> = dlg.data
        local enabled <const> = args.includeMaps --[[@as boolean]]
        local allTarget <const> = args.target == "ALL"
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local filename = args.filename --[[@as string]]
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local margin <const> = args.border
            or defaults.border --[[@as integer]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]
        local usePow2 <const> = args.toPow2 --[[@as boolean]]
        local potUniform <const> = args.potUniform --[[@as boolean]]
        local saveJson <const> = args.saveJson --[[@as boolean]]
        local includeMaps <const> = args.includeMaps --[[@as boolean]]
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local boundsFormat <const> = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local spriteColorMode <const> = spriteSpec.colorMode
        local spriteColorSpace <const> = spriteSpec.colorSpace
        local spriteAlphaIndex <const> = spriteSpec.transparentColor
        local spritePalettes <const> = activeSprite.palettes

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

        -- For explanatory comment, see framesExport.lua .
        if spriteColorMode == ColorMode.INDEXED then
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "webp"
                or lcFileExt == "jpg"
                or lcFileExt == "jpeg"
                or lcFileExt == "tga" then
                app.alert {
                    title = "Error",
                    text = "Indexed color not supported for jpeg, jpg, tga or webp."
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
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "bmp" then
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
        local filePrefix <const> = filePath .. fileTitle

        -- Process scale.
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
        local margin2 <const> = margin + margin
        local nonUniformDim <const> = not potUniform

        local sheetPalette <const> = AseUtilities.getPalette(
            app.activeFrame, spritePalettes)

        ---@type Tileset[]
        local tileSets = {}
        if target == "ACTIVE" then
            local activeLayer <const> = site.layer
            if not activeLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
                }
                return
            end

            local isTilemap <const> = activeLayer.isTilemap
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
        local ceil <const> = math.ceil
        local max <const> = math.max
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local nextPow2 <const> = Utilities.nextPowerOf2
        local verifName <const> = Utilities.validateFilename
        local createSpec <const> = AseUtilities.createSpec
        local resize <const> = AseUtilities.resizeImageNearest

        -- For JSON export.
        ---@type table[]
        local sheetPackets <const> = {}
        local lenTileSets <const> = #tileSets
        local i = 0
        while i < lenTileSets do
            i = i + 1
            local tileSet <const> = tileSets[i]
            local tileSetName <const> = tileSet.name

            local tileGrid <const> = tileSet.grid
            local tileDim <const> = tileGrid.tileSize
            local wTileSrc <const> = tileDim.width
            local hTileSrc <const> = tileDim.height

            local tsNameVerif = tileSetName
            if tsNameVerif and #tsNameVerif > 1 then
                tsNameVerif = verifName(tileSetName)
            else
                tsNameVerif = strfmt("%03d", i - 1)
            end

            local wTileTrg <const> = wTileSrc * wScale
            local hTileTrg <const> = hTileSrc * hScale

            -- Same procedure as saving batched sheets in
            -- framesExport.
            local lenTileSet <const> = #tileSet
            local columns = max(1, ceil(sqrt(lenTileSet)))
            local rows = max(1, ceil(lenTileSet / columns))
            local wSheet = margin2 + wTileTrg * columns
                + padding * (columns - 1)
            local hSheet = margin2 + hTileTrg * rows
                + padding * (rows - 1)

            if usePow2 then
                if nonUniformDim then
                    wSheet = nextPow2(wSheet)
                    hSheet = nextPow2(hSheet)
                else
                    wSheet = nextPow2(max(wSheet, hSheet))
                    hSheet = wSheet
                end

                -- There's one less padding per denominator,
                -- so experiment adding one padding to numerator.
                columns = math.max(1,
                    (wSheet + padding - margin2)
                    // (wTileTrg + padding))
                rows = math.max(1,
                    (hSheet + padding - margin2)
                    // (hTileTrg + padding))
            end

            -- Create composite image.
            local sheetSpec <const> = createSpec(
                wSheet,hSheet, spriteColorMode, spriteColorSpace,
                spriteAlphaIndex)
            local sheetImage <const> = Image(sheetSpec)

            -- For JSON export.
            ---@type table[]
            local sectionPackets <const> = {}

            -- The first tile in a tile set is empty.
            -- Include this empty tile, and all others, to
            -- maintain indexing with tile maps.
            local k = 0
            while k < lenTileSet do
                local row <const> = k // columns
                local column <const> = k % columns
                local tile <const> = tileSet:tile(k)

                -- Is the index different from j
                -- because of the tile set base index?
                local tileImage <const> = tile.image --[[@as Image]]
                local tileScaled = tileImage
                if useResize then
                    tileScaled = resize(tileImage,
                        wTileTrg, hTileTrg)
                end

                local xOff <const> = margin + column * padding
                local yOff <const> = margin + row * padding
                local xTrg <const> = xOff + column * wTileTrg
                local yTrg <const> = yOff + row * hTileTrg
                sheetImage:drawImage(tileScaled, Point(xTrg, yTrg))

                k = k + 1
                sectionPackets[k] = {
                    column = column,
                    row = row,
                    rect = {
                        x = xTrg,
                        y = yTrg,
                        width = wTileTrg,
                        height = hTileTrg
                    }
                }
            end

            local fileNameShort <const> = strfmt(
                "%s_%s",
                fileTitle, tsNameVerif)
            local fileNameLong <const> = strfmt(
                "%s%s.%s",
                filePath, fileNameShort, fileExt)

            sheetImage:saveAs {
                filename = fileNameLong,
                palette = sheetPalette
            }

            local sheetPacket <const> = {
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
            local celPackets <const> = {}
            -- Because frames is an inner array, use a dictionary
            -- to track unique frames that contain tile map cels.
            ---@type table<integer,table>
            local framePackets <const> = {}
            ---@type table[]
            local layerPackets <const> = {}
            ---@type table[]
            local mapPackets <const> = {}

            if includeMaps then
                local pxTilei <const> = app.pixelColor.tileI
                local useZIndex <const> = app.apiVersion >= 23

                local frObjs <const> = activeSprite.frames
                local tmFrames <const> = Utilities.flatArr2(
                    AseUtilities.getFrames(activeSprite, target))

                ---@type Layer[]
                local tmLayers = {}
                if target == "ACTIVE" then
                    -- This has already been validated to be
                    -- non-nil and a tile map at start of function.
                    tmLayers = { app.activeLayer --[[@as Layer]] }
                else
                    tmLayers = AseUtilities.getLayerHierarchy(
                        activeSprite,
                        includeLocked,
                        includeHidden,
                        true, false)
                end

                local lenTmFrames <const> = #tmFrames
                local lenTmLayers <const> = #tmLayers
                local j = 0
                while j < lenTmLayers do
                    j = j + 1
                    local tmLayer <const> = tmLayers[j]
                    if tmLayer.isTilemap then
                        local tileSet <const> = tmLayer.tileset --[[@as Tileset]]
                        local tileGrid <const> = tileSet.grid
                        local tileDim <const> = tileGrid.tileSize
                        local wTile <const> = tileDim.width
                        local hTile <const> = tileDim.height
                        local lenTileSet <const> = #tileSet

                        local layerId <const> = tmLayer.id
                        local parent <const> = tmLayer.parent
                        local parentId = -1
                        if parent.__name ~= "doc::Sprite" then
                            parentId = parent.id
                        end

                        local layerPacket <const> = {
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
                            local tmFrame <const> = tmFrames[k]
                            local framePacket = framePackets[tmFrame]
                            if not framePacket then
                                local frObj <const> = frObjs[tmFrame]
                                framePacket = {
                                    frameNumber = tmFrame,
                                    duration = frObj.duration
                                }
                                framePackets[tmFrame] = framePacket
                            end

                            local tmCel <const> = tmLayer:cel(tmFrame)
                            if tmCel then
                                local tmImage <const> = tmCel.image
                                local tmPxItr <const> = tmImage:pixels()

                                -- TODO: In the future, this would also need
                                -- a separate array of rotation flags.
                                ---@type integer[]
                                local tmIndicesArr <const> = {}
                                for pixel in tmPxItr do
                                    local tlData <const> = pixel()
                                    local tlIndex = pxTilei(tlData)
                                    if tlIndex >= lenTileSet then
                                        tlIndex = 0
                                    end
                                    tmIndicesArr[#tmIndicesArr + 1] = tlIndex
                                end

                                local wTileMap <const> = tmImage.width
                                local hTileMap <const> = tmImage.height
                                local mapPacket <const> = {
                                    width = wTileMap,
                                    height = hTileMap,
                                    indices = tmIndicesArr,
                                    frameNumber = tmFrame,
                                    layer = layerId
                                }
                                mapPackets[#mapPackets + 1] = mapPacket

                                local tmCelPos <const> = tmCel.position
                                local tmBounds <const> = {
                                    x = tmCelPos.x,
                                    y = tmCelPos.y,
                                    width = wTileMap * wTile,
                                    height = hTileMap * hTile
                                }

                                local zIndex = 0
                                if useZIndex then zIndex = tmCel.zIndex end

                                local celPacket <const> = {
                                    fileName = "",
                                    bounds = tmBounds,
                                    data = tmCel.data,
                                    frameNumber = tmFrame,
                                    layer = layerId,
                                    opacity = tmCel.opacity,
                                    zIndex = zIndex
                                }
                                celPackets[#celPackets + 1] = celPacket
                            end -- End cel exists check.
                        end     -- End frames loop.
                    end         -- End layer isTilemap check.
                end             -- End layers loop.
            end                 -- End include maps check.

            -- Cache Json methods.
            local celToJson <const> = JsonUtilities.celToJson
            local frameToJson <const> = JsonUtilities.frameToJson
            local layerToJson <const> = JsonUtilities.layerToJson

            local h = 0
            ---@type string[]
            local tsStrs <const> = {}
            local lenSheetPackets <const> = #sheetPackets
            while h < lenSheetPackets do
                h = h + 1
                local sheet <const> = sheetPackets[h]
                tsStrs[h] = sheetToJson(sheet, boundsFormat)
            end

            ---@type string[]
            local tmStrs <const> = {}
            local lenMapPackets <const> = #mapPackets
            local j = 0
            while j < lenMapPackets do
                j = j + 1
                local map <const> = mapPackets[j]
                tmStrs[j] = mapToJson(map)
            end

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

            ---@type string[]
            local frameStrs <const> = {}
            for _, frame in pairs(framePackets) do
                frameStrs[#frameStrs + 1] = frameToJson(frame)
            end

            local m = 0
            ---@type string[]
            local layerStrs <const> = {}
            local lenLayerPackets <const> = #layerPackets
            while m < lenLayerPackets do
                m = m + 1
                local layer <const> = layerPackets[m]
                layerStrs[m] = layerToJson(layer)
            end

            local jsonFormat <const> = table.concat({
                "{\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                "\"border\":%d",
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
            local jsonString <const> = string.format(
                jsonFormat,
                filePath, fileExt,
                margin, padding, scale,
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

            local file <const>, err <const> = io.open(jsonFilepath, "w")
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