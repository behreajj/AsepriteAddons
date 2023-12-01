dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local targetOptions <const> = { "ACTIVE", "ALL" }
local dataOptions <const> = { "JSON", "TILED", "NONE" }
local tiledImgExts <const> = {
    "bmp",
    "jpeg",
    "jpg",
    "png"
}

local defaults <const> = {
    -- TODO: Specify layer's tileset name in JSON export?
    target = "ALL",
    border = 0,
    padding = 0,
    scale = 1,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    metaData = "TILED",
    includeMaps = true,
    includeLocked = true,
    includeHidden = false,
    boundsFormat = "TOP_LEFT",
    tmxVersion = "1.10",
    tmxTiledVersion = "1.10.2",
    tmxOrientation = "orthogonal",
    tmxRenderOrder = "right-down",
    tsxRender = "grid",
    tsxFill = "preserve-aspect-fit"
}

local jsonSectionFormat <const> = table.concat({
    "{\"id\":%s",
    "\"rect\":%s}",
}, ",")

local jsonTileSetFormat <const> = table.concat({
    "{\"fileName\":\"%s\"",
    "\"baseIndex\":%d",
    "\"size\":%s",
    "\"sizeGrid\":%s",
    "\"tiles\":[%s]}",
}, ",")

local jsonTileMapFormat <const> = table.concat({
    "{\"size\":%s",
    "\"indices\":[%s]",
    "\"flags\":[%s]",
    "\"frame\":%d",
    "\"layer\":%d}",
}, ",")

local tmxMapFormat <const> = table.concat({
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
    "<map ",
    "version=\"%s\" ",
    "tiledversion=\"%s\" ",
    "orientation=\"%s\" ",
    "renderorder=\"%s\" ",
    "width=\"%d\" ",
    "height=\"%d\" ",
    "tilewidth=\"%d\" ",
    "tileheight=\"%d\" ",
    "infinite=\"0\">\n",
    "%s\n", -- tsx use ref array
    "%s\n", -- layer array
    "</map>"
}, "")

local tmxLayerFormat <const> = table.concat({
    "<layer ",
    "id=\"%d\" ",
    "name=\"%s\" ",
    "width=\"%d\" ",
    "height=\"%d\" ",
    "offsetx=\"%d\" ",
    "offsety=\"%d\" ",
    "visible=\"%d\" ",
    "locked=\"%d\" ",
    "opacity=\"%.6f\">\n",
    "<data encoding=\"csv\">\n%s\n</data>\n",
    "</layer>"
}, "")

local tilsetRefFormat <const> = table.concat({
    "<tileset ",
    "firstgid=\"%d\" ",
    "source=\"%s\"/>"
}, "")

local tsxFormat <const> = table.concat({
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
    "<tileset ",
    "version=\"%s\" ",
    "tiledversion=\"%s\" ",
    "name=\"%s\" ",
    "tilewidth=\"%d\" ",
    "tileheight=\"%d\" ",
    "spacing=\"%d\" ",
    "margin=\"%d\" ",
    "tilecount=\"%d\" ",
    "columns=\"%d\" ",
    "tilerendersize=\"%s\" ",
    "fillmode=\"%s\">\n",
    " <transformations ",
    "hflip=\"%d\" ",
    "vflip=\"%d\" ",
    "rotate=\"%d\" ",
    "preferuntransformed=\"%d\"/>\n",
    " <image ",
    "source=\"%s\" ",
    "%s", -- transparency string
    "width=\"%d\" ",
    "height=\"%d\"/>\n",
    "</tileset>"
})

---@param section table
---@param boundsFormat string
---@return string
local function sectionToJson(section, boundsFormat)
    return string.format(jsonSectionFormat,
        JsonUtilities.pointToJson(
            section.column, section.row),
        JsonUtilities.rectToJson(
            section.rect, boundsFormat))
end

---@param map table
---@return string
local function mapToJson(map)
    return string.format(
        jsonTileMapFormat,
        JsonUtilities.pointToJson(map.width, map.height),
        table.concat(map.indices, ","),
        table.concat(map.flags, ","),
        map.frameNumber - 1,
        map.layer)
end

---@param ts table
---@param boundsFormat string
---@return string
local function tileSetToJson(ts, boundsFormat)
    ---@type string[]
    local sectionsStrs <const> = {}
    local sections <const> = ts.sections
    local lenSections <const> = #sections
    local i = 0
    while i < lenSections do
        i = i + 1
        sectionsStrs[i] = sectionToJson(
            sections[i], boundsFormat)
    end

    return string.format(jsonTileSetFormat,
        ts.fileName,
        ts.baseIndex,
        JsonUtilities.pointToJson(
            ts.width,
            ts.height),
        JsonUtilities.pointToJson(
            ts.columns,
            ts.rows),
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
        local metaData <const> = args.metaData --[[@as string]]
        local usemd <const> = metaData ~= "NONE"
        local includeMaps <const> = args.includeMaps --[[@as boolean]]
        local allTarget <const> = args.target == "ALL"
        dlg:modify { id = "includeLocked", visible = usemd
            and includeMaps and allTarget }
        dlg:modify { id = "includeHidden", visible = usemd
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
    filetypes = tiledImgExts,
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:combobox {
    id = "metaData",
    label = "Data:",
    option = defaults.metaData,
    options = dataOptions,
    onchange = function()
        local args <const> = dlg.data
        local metaData <const> = args.metaData --[[@as string]]
        local usemd <const> = metaData ~= "NONE"
        local useJson <const> = metaData == "JSON"
        local includeMaps <const> = args.includeMaps --[[@as boolean]]
        local allTarget <const> = args.target == "ALL"
        dlg:modify { id = "includeMaps", visible = usemd }
        dlg:modify { id = "boundsFormat", visible = useJson }
        dlg:modify { id = "userDataWarning", visible = useJson }
        dlg:modify { id = "includeLocked", visible = usemd
            and includeMaps and allTarget }
        dlg:modify { id = "includeHidden", visible = usemd
            and includeMaps and allTarget }
    end
}

dlg:check {
    id = "includeMaps",
    label = "Include:",
    text = "&Tilemaps",
    selected = defaults.includeMaps,
    visible = defaults.metaData ~= "NONE",
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
    visible = defaults.metaData ~= "NONE"
        and defaults.includeMaps
        and defaults.target == "ALL"
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    visible = defaults.metaData ~= "NONE"
        and defaults.includeMaps
        and defaults.target == "ALL"
}

dlg:combobox {
    id = "boundsFormat",
    label = "Format:",
    option = defaults.boundsFormat,
    options = JsonUtilities.RECT_OPTIONS,
    visible = defaults.metaData == "JSON"
}

dlg:newrow { always = false }

dlg:label {
    id = "userDataWarning",
    label = "Note:",
    text = "User data not escaped.",
    visible = defaults.metaData == "JSON"
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
        local metaData <const> = args.metaData
            or defaults.metaData --[[@as string]]
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
        local fileExtLc = string.lower(fileExt)
        if fileExtLc == "json"
            or fileExtLc == "tmx"
            or fileExtLc == "tsx" then
            -- Now that this exporter works with Tiled, it has to use a
            -- narrower band of supported extensions.
            -- fileExt = app.preferences.export_file.image_default_extension
            fileExt = "png"
            fileExtLc = string.lower(fileExt)
            filename = string.sub(filename, 1, -(#fileExtLc) - 1) .. fileExt
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
            site.frame, spritePalettes)

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

        -- For meta data export.
        ---@type table[]
        local sheetPackets <const> = {}
        local lenTileSets <const> = #tileSets
        local i = 0
        while i < lenTileSets do
            i = i + 1
            local tileSet <const> = tileSets[i]
            local lenTileSet <const> = #tileSet
            local tileSetName <const> = tileSet.name
            local baseIndex <const> = tileSet.baseIndex

            local tileGrid <const> = tileSet.grid
            local tileDim <const> = tileGrid.tileSize
            local wTileSrc <const> = tileDim.width
            local hTileSrc <const> = tileDim.height

            local tsNameVerif = tileSetName
            if tsNameVerif and #tsNameVerif > 0 then
                tsNameVerif = verifName(tileSetName)
            else
                tsNameVerif = strfmt("TileSet %d", i - 1)
            end

            local wTileTrg <const> = wTileSrc * wScale
            local hTileTrg <const> = hTileSrc * hScale

            -- Same procedure as saving batched sheets in framesExport.
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
                wSheet, hSheet, spriteColorMode, spriteColorSpace,
                spriteAlphaIndex)
            local sheetImage <const> = Image(sheetSpec)

            -- For Meta data (JSON, TMX) export.
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

            -- Tile width and height are not used by JSON, but would be useful
            -- for Tiled (TMX, TSX) export.
            local sheetPacket <const> = {
                fileName = fileNameShort,
                baseIndex = baseIndex,
                width = wSheet,
                height = hSheet,
                columns = columns,
                rows = rows,
                sections = sectionPackets,
                lenTileSet = lenTileSet,
                wTile = wTileTrg,
                hTile = hTileTrg,
            }
            sheetPackets[i] = sheetPacket
        end

        if metaData ~= "NONE" then
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
                local pxTilef <const> = app.pixelColor.tileF

                local frObjs <const> = activeSprite.frames
                local tmFrames <const> = Utilities.flatArr2(
                    AseUtilities.getFrames(activeSprite, target))
                local lenTmFrames <const> = #tmFrames
                if lenTmFrames <= 0 then
                    app.alert {
                        title = "Error",
                        text = "No frames were selected."
                    }
                    return
                end

                ---@type Layer[]
                local tmLayers = {}
                if target == "ACTIVE" then
                    -- This has already been validated to be
                    -- non-nil and a tile map at start of function.
                    tmLayers = { site.layer --[[@as Layer]] }
                else
                    tmLayers = AseUtilities.getLayerHierarchy(
                        activeSprite,
                        includeLocked,
                        includeHidden,
                        true, false)
                end
                local lenTmLayers <const> = #tmLayers
                if lenTmLayers <= 0 then
                    app.alert {
                        title = "Error",
                        text = "No layers were selected."
                    }
                    return
                end

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

                        local tileSetName <const> = tileSet.name
                        local tsNameVerif = tileSetName
                        if tsNameVerif and #tsNameVerif > 0 then
                            tsNameVerif = verifName(tileSetName)
                        else
                            tsNameVerif = strfmt("TileSet %d", i - 1)
                        end
                        local fileNameShort <const> = strfmt(
                            "%s_%s",
                            fileTitle, tsNameVerif)

                        local layerPacket <const> = {
                            blendMode = tmLayer.blendMode,
                            data = tmLayer.data,
                            id = layerId,
                            isLocked = not tmLayer.isEditable,
                            isVisible = tmLayer.isVisible,
                            name = tmLayer.name,
                            opacity = tmLayer.opacity,
                            parent = parentId,
                            stackIndex = tmLayer.stackIndex,
                            tileSetName = fileNameShort,
                            lenTileSet = #tileSet
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

                                ---@type integer[]
                                local tmIndicesArr <const> = {}
                                ---@type integer[]
                                local tmFlagsArr <const> = {}

                                for pixel in tmPxItr do
                                    local tlData <const> = pixel()
                                    local tlIndex = pxTilei(tlData)
                                    local tlFlag = pxTilef(tlData)
                                    if tlIndex >= lenTileSet then
                                        tlIndex = 0
                                        tlFlag = 0
                                    end
                                    tmIndicesArr[#tmIndicesArr + 1] = tlIndex
                                    tmFlagsArr[#tmFlagsArr + 1] = tlFlag
                                end

                                local wTileMap <const> = tmImage.width
                                local hTileMap <const> = tmImage.height
                                local mapPacket <const> = {
                                    width = wTileMap,
                                    height = hTileMap,
                                    indices = tmIndicesArr,
                                    flags = tmFlagsArr,
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

                                local celPacket <const> = {
                                    fileName = "",
                                    bounds = tmBounds,
                                    data = tmCel.data,
                                    frameNumber = tmFrame,
                                    layer = layerId,
                                    opacity = tmCel.opacity,
                                    zIndex = tmCel.zIndex
                                }
                                celPackets[#celPackets + 1] = celPacket
                            end -- End cel exists check.
                        end     -- End frames loop.
                    end         -- End layer isTilemap check.
                end             -- End layers loop.
            end                 -- End include maps check.

            if metaData == "TILED" then
                local alphaStr = ""
                if spriteColorMode == ColorMode.INDEXED then
                    local trColor <const> = sheetPalette:getColor(spriteAlphaIndex)
                    if trColor.alpha == 255 then
                        local rTr <const> = trColor.red
                        local gTr <const> = trColor.green
                        local bTr <const> = trColor.blue

                        alphaStr = string.format("trans=\"%06x\" ",
                            rTr << 0x10 | gTr << 0x08 | bTr)
                    end
                end

                local tconcat <const> = table.concat
                local tmxVersion <const> = defaults.tmxVersion
                local tmxTiledVersion <const> = defaults.tmxTiledVersion
                local tsxRender <const> = defaults.tsxRender
                local tsxFill <const> = defaults.tsxFill
                local lenSheetPackets <const> = #sheetPackets

                local h = 0
                while h < lenSheetPackets do
                    h = h + 1

                    local sheetPacket <const> = sheetPackets[h]
                    local fileName <const> = sheetPacket.fileName

                    local wTile <const> = sheetPacket.wTile
                    local hTile <const> = sheetPacket.hTile
                    local width <const> = sheetPacket.width
                    local height <const> = sheetPacket.height
                    local lenTileSet <const> = sheetPacket.lenTileSet
                    local columns <const> = sheetPacket.columns

                    -- Currently the allowed flips and rotations doesn't seem
                    -- accessible from Lua API, so default to 1, 1, 1, 0.
                    local tsxStr <const> = strfmt(
                        tsxFormat,
                        tmxVersion, tmxTiledVersion,
                        fileName,
                        wTile, hTile,
                        padding, margin,
                        lenTileSet, columns,
                        tsxRender, tsxFill,
                        1, 1, 1, 0,
                        strfmt("%s.%s", fileName, fileExt),
                        alphaStr,
                        width, height)

                    local tsxFilePath <const> = strfmt("%s%s.tsx", filePath, fileName)
                    local tsxFile <const>, _ <const> = io.open(tsxFilePath, "w")
                    if tsxFile then
                        tsxFile:write(tsxStr)
                        tsxFile:close()
                    end
                end

                if includeMaps then
                    local tmxOrientation <const> = defaults.tmxOrientation
                    local tmxRenderOrder <const> = defaults.tmxRenderOrder

                    -- Use these for map tile width and height.
                    local spriteGrid <const> = activeSprite.gridBounds
                    local wSprGrid <const> = math.max(1, math.abs(
                        spriteGrid.width))
                    local hSprGrid <const> = math.max(1, math.abs(
                        spriteGrid.height))

                    local wSprInTiles <const> = math.max(1, math.ceil(
                        spriteSpec.width / wSprGrid))
                    local hSprInTiles <const> = math.max(1, math.ceil(
                        spriteSpec.height / hSprGrid))

                    local lenLayerPackets <const> = #layerPackets
                    local lenCelPackets <const> = #celPackets
                    local lenMapPackets <const> = #mapPackets

                    for _, frame in pairs(framePackets) do
                        local frIdx <const> = frame.frameNumber

                        -- Use layer ID as a key to access packet.
                        ---@type table<integer, table>
                        local filteredMapPackets <const> = {}
                        local k = 0
                        while k < lenMapPackets do
                            k = k + 1
                            local mapPacket <const> = mapPackets[k]
                            if mapPacket.frameNumber == frIdx then
                                filteredMapPackets[mapPacket.layer] = mapPacket
                            end
                        end

                        -- Use layer ID as a key to access packet.
                        ---@type table<integer, table>
                        local filteredCelPackets <const> = {}
                        local j = 0
                        while j < lenCelPackets do
                            j = j + 1
                            local celPacket <const> = celPackets[j]
                            if celPacket.frameNumber == frIdx then
                                filteredCelPackets[celPacket.layer] = celPacket
                            end
                        end

                        local firstgid = 1
                        ---@type table<string, integer>
                        local usedTileSets <const> = {}
                        ---@type string[]
                        local tmxLayerStrs <const> = {}
                        local m = 0
                        while m < lenLayerPackets do
                            m = m + 1
                            local layerPacket <const> = layerPackets[m]
                            local layerId <const> = layerPacket.id
                            local isLocked <const> = layerPacket.isLocked and 1 or 0
                            local isVisible <const> = layerPacket.isVisible and 1 or 0
                            local layerOpacity <const> = layerPacket.opacity / 255.0
                            local layerName <const> = layerPacket.name
                            local tileSetName <const> = layerPacket.tileSetName

                            local idxOffset = 0
                            if usedTileSets[tileSetName] then
                                idxOffset = usedTileSets[tileSetName]
                            else
                                idxOffset = firstgid
                                usedTileSets[tileSetName] = firstgid
                                local lenTileSet <const> = layerPacket.lenTileSet
                                firstgid = firstgid + lenTileSet
                            end

                            ---@type string[]
                            local csvData = {}
                            local wMap = 0
                            local hMap = 0
                            local mapPacket <const> = filteredMapPackets[layerId]
                            if mapPacket then
                                wMap = mapPacket.width
                                hMap = mapPacket.height

                                local indices <const> = mapPacket.indices
                                local flags <const> = mapPacket.flags

                                local y = 0
                                while y < hMap do
                                    ---@type integer[]
                                    local colArr = {}
                                    local x = 0
                                    while x < wMap do
                                        local flat <const> = 1 + y * wMap + x
                                        local index <const> = indices[flat]
                                        local flag <const> = flags[flat]
                                        local comp = 0
                                        if index ~= 0 then
                                            comp = flag | (idxOffset + index)
                                        end
                                        x = x + 1
                                        colArr[x] = comp
                                    end

                                    y = y + 1
                                    csvData[y] = tconcat(colArr, ",")
                                end
                            end

                            local celOpacity = 1.0
                            local xOffset = 0
                            local yOffset = 0
                            local celPacket <const> = filteredCelPackets[layerId]
                            if celPacket then
                                celOpacity = celPacket.opacity / 255.0
                                local boundsPacket <const> = celPacket.bounds
                                xOffset = boundsPacket.x
                                yOffset = boundsPacket.y
                            end

                            local compOpacity <const> = layerOpacity * celOpacity
                            local tmxLayerStr <const> = strfmt(
                                tmxLayerFormat,
                                m, layerName,
                                wMap, hMap,
                                xOffset, yOffset,
                                isVisible, isLocked,
                                compOpacity,
                                tconcat(csvData, ",\n"))
                            tmxLayerStrs[m] = tmxLayerStr
                        end

                        ---@type string[]
                        local tsxRefStrs <const> = {}
                        for tsName, tsGid in pairs(usedTileSets) do
                            tsxRefStrs[#tsxRefStrs + 1] = strfmt(
                                tilsetRefFormat,
                                tsGid,
                                strfmt("%s.tsx", tsName))
                        end

                        local tmxString <const> = strfmt(
                            tmxMapFormat,
                            tmxVersion, tmxTiledVersion,
                            tmxOrientation, tmxRenderOrder,
                            wSprInTiles,
                            hSprInTiles,
                            wSprGrid,
                            hSprGrid,
                            tconcat(tsxRefStrs, "\n"),
                            tconcat(tmxLayerStrs, "\n")
                        )

                        local tmxFilepath = filePrefix
                        if #fileTitle < 1 then
                            tmxFilepath = filePath .. pathSep .. "manifest"
                        end
                        tmxFilepath = strfmt("%s_%03d.tmx", tmxFilepath, frIdx - 1)

                        local tmxFile <const>, _ <const> = io.open(tmxFilepath, "w")
                        if tmxFile then
                            tmxFile:write(tmxString)
                            tmxFile:close()
                        end
                    end -- End frame dict loop.
                end     -- End include maps check.
            elseif metaData == "JSON" then
                -- Cache Json methods.
                local celToJson <const> = JsonUtilities.celToJson
                local frameToJson <const> = JsonUtilities.frameToJson
                local layerToJson <const> = JsonUtilities.layerToJson

                ---@type string[]
                local tsStrs <const> = {}
                local lenSheetPackets <const> = #sheetPackets
                local h = 0
                while h < lenSheetPackets do
                    h = h + 1
                    tsStrs[h] = tileSetToJson(sheetPackets[h], boundsFormat)
                end

                ---@type string[]
                local tmStrs <const> = {}
                local lenMapPackets <const> = #mapPackets
                local j = 0
                while j < lenMapPackets do
                    j = j + 1
                    tmStrs[j] = mapToJson(mapPackets[j])
                end

                ---@type string[]
                local celStrs <const> = {}
                local lenCelPackets <const> = #celPackets
                local k = 0
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

                ---@type string[]
                local layerStrs <const> = {}
                local lenLayerPackets <const> = #layerPackets
                local m = 0
                while m < lenLayerPackets do
                    m = m + 1
                    layerStrs[m] = layerToJson(layerPackets[m])
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

                local jsonFile <const>, jsonErr <const> = io.open(jsonFilepath, "w")
                if jsonFile then
                    jsonFile:write(jsonString)
                    jsonFile:close()
                end

                if jsonErr then
                    app.alert { title = "Error", text = jsonErr }
                    return
                end
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