dofile("../../support/aseutilities.lua")

local dataOptions <const> = { "NONE", "TILED" }
local targetOptions <const> = { "ACTIVE", "ALL" }
local tiledImgExts <const> = {
    "bmp",
    "jpeg",
    "jpg",
    "png"
}
local tsxRenders <const> = { "GRID", "TILE" }
local tsxFills <const> = { "PRESERVE-ASPECT-FIT", "STRETCH" }
local tsxAligns <const> = {
    "BOTTOM",
    "BOTTOMLEFT",
    "BOTTOMRIGHT",
    "CENTER",
    "LEFT",
    "RIGHT",
    "TOP",
    "TOPLEFT",
    "TOPRIGHT",
    "UNSPECIFIED"
}

local defaults <const> = {
    target = "ALL",
    border = 0,
    padding = 0,
    scale = 1,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    metaData = "TILED",
    includeMaps = true,
    boundsFormat = "TOP_LEFT",
    tmxVersion = "1.10",
    tmxTiledVersion = "1.10.2",
    tmxOrientation = "orthogonal",
    tmxRenderOrder = "right-down",
    tsxAlign = "TOPLEFT",
    tsxRender = "TILE",
    tsxFill = "PRESERVE-ASPECT-FIT"
}

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
    "opacity=\"%.2f\">\n",
    "<data encoding=\"csv\">\n%s\n</data>\n",
    "</layer>"
}, "")

local tilsetRefFormat <const> = table.concat({
    "<tileset ",
    "firstgid=\"%d\" ",
    "source=\"%s.tsx\"/>"
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
    "objectalignment=\"%s\" ",
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

local dlg <const> = Dialog { title = "Export Tilesets" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targetOptions
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
        local useTsx <const> = metaData == "TILED"

        dlg:modify { id = "includeMaps", visible = usemd }
        dlg:modify { id = "tsxAlign", visible = useTsx }
        dlg:modify { id = "tsxRender", visible = useTsx }
        dlg:modify { id = "tsxFill", visible = useTsx }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "includeMaps",
    label = "Include:",
    text = "&Tilemaps",
    selected = defaults.includeMaps,
    visible = defaults.metaData ~= "NONE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tsxAlign",
    label = "Align:",
    option = defaults.tsxAlign,
    options = tsxAligns,
    visible = defaults.metaData == "TILED"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tsxRender",
    label = "Render:",
    option = defaults.tsxRender,
    options = tsxRenders,
    visible = defaults.metaData == "TILED"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tsxFill",
    label = "Fill:",
    option = defaults.tsxFill,
    options = tsxFills,
    visible = defaults.metaData == "TILED"
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

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local spriteColorMode <const> = spriteSpec.colorMode
        local spriteColorSpace <const> = spriteSpec.colorSpace
        local spriteAlphaIndex <const> = spriteSpec.transparentColor
        local spritePalettes <const> = activeSprite.palettes

        -- Validate file name.
        local fileExt = app.fs.fileExtension(filename)
        local fileExtLc = string.lower(fileExt)
        if fileExtLc == "tmx"
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

        local lenTileSets <const> = #tileSets
        if lenTileSets <= 0 then
            app.alert {
                title = "Error",
                text = "No tile sets were found."
            }
            return
        end

        -- For generating a Tileset id.
        math.randomseed(os.time())
        local minint64 <const> = 0x1000000000000000
        local maxint64 <const> = 0x7fffffffffffffff

        -- Cache methods used in loops.
        local ceil <const> = math.ceil
        local max <const> = math.max
        local rng <const> = math.random
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local tconcat <const> = table.concat
        local nextPow2 <const> = Utilities.nextPowerOf2
        local verifName <const> = Utilities.validateFilename
        local createSpec <const> = AseUtilities.createSpec
        local resize <const> = AseUtilities.resizeImageNearest

        -- If you wanted to include an option to target the layers in a range,
        -- then you'd have to perform this on all tilesets in the sprite, not
        -- just the tilesets chosen by the user.
        app.transaction("Set Tileset IDs", function()
            local h = 0
            while h < lenTileSets do
                h = h + 1
                local tileSet <const> = tileSets[h]
                local tileId = 0
                local tileSetProps <const> = tileSet.properties
                if tileSetProps["id"] then
                    tileId = tileSetProps["id"] --[[@as integer]]
                else
                    tileId = rng(minint64, maxint64)
                    tileSet.properties["id"] = tileId
                end
            end
        end)

        -- For meta data export.
        ---@type table<integer, table>
        local sheetPackets <const> = {}

        local i = 0
        while i < lenTileSets do
            i = i + 1
            local tileSet <const> = tileSets[i]
            local lenTileSet <const> = #tileSet
            local tileSetName <const> = tileSet.name
            local tileSetBaseIndex <const> = tileSet.baseIndex
            local tileId <const> = tileSet.properties["id"]

            local tileGrid <const> = tileSet.grid
            local tileDim <const> = tileGrid.tileSize
            local wTileSrc <const> = tileDim.width
            local hTileSrc <const> = tileDim.height

            local tsNameVerif = tileSetName
            if tsNameVerif and #tsNameVerif > 0 then
                tsNameVerif = verifName(tileSetName)
            else
                tsNameVerif = strfmt("tileset_%03d", i - 1)
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
                id = tileId,
                fileName = fileNameShort,
                baseIndex = tileSetBaseIndex,
                columns = columns,
                height = hSheet,
                hTile = hTileTrg,
                rows = rows,
                lenTileSet = lenTileSet,
                width = wSheet,
                wTile = wTileTrg
            }
            sheetPackets[tileId] = sheetPacket
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
                        true, true, true, true)
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
                        local lenTileSet <const> = #tileSet
                        local tileSetId <const> = tileSet.properties["id"]

                        local tileGrid <const> = tileSet.grid
                        local tileDim <const> = tileGrid.tileSize
                        local wTile <const> = tileDim.width
                        local hTile <const> = tileDim.height

                        local layerId <const> = tmLayer.id
                        local parent <const> = tmLayer.parent
                        local parentId = -1
                        if parent.__name ~= "doc::Sprite" then
                            parentId = parent.id
                        end

                        local layerPacket <const> = {
                            blendMode = tmLayer.blendMode or BlendMode.NORMAL,
                            data = tmLayer.data,
                            id = layerId,
                            isLocked = not tmLayer.isEditable,
                            isVisible = tmLayer.isVisible,
                            name = tmLayer.name,
                            opacity = tmLayer.opacity or 255,
                            parent = parentId,
                            stackIndex = tmLayer.stackIndex,
                            tileset = tileSetId
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
                                -- TODO: Can the image ID be given to map
                                -- and cel packets so that they are easier to
                                -- find in a collection later on?
                                local tmImage <const> = tmCel.image
                                local tmPxItr <const> = tmImage:pixels()

                                ---@type integer[]
                                local tmIndicesArr <const> = {}
                                ---@type integer[]
                                local tmFlagsArr <const> = {}

                                for pixel in tmPxItr do
                                    local tlData <const> = pixel() --[[@as integer]]
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
                                    flags = tmFlagsArr,
                                    frameNumber = tmFrame,
                                    height = hTileMap,
                                    indices = tmIndicesArr,
                                    layer = layerId,
                                    width = wTileMap,
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
                                    bounds = tmBounds,
                                    data = tmCel.data,
                                    fileName = "",
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
                    local aTr <const> = trColor.alpha
                    if aTr > 0 then
                        local rTr <const> = trColor.red
                        local gTr <const> = trColor.green
                        local bTr <const> = trColor.blue

                        -- TMX format is AARRGGBB.
                        alphaStr = string.format("trans=\"%08x\" ",
                            aTr << 0x18 | rTr << 0x10 | gTr << 0x08 | bTr)
                    end
                end

                local tmxVersion <const> = defaults.tmxVersion
                local tmxTiledVersion <const> = defaults.tmxTiledVersion
                local tsxAlign <const> = string.lower(args.tsxAlign
                    or defaults.tsxAlign --[[@as string]])
                local tsxRender <const> = string.lower(args.tsxRender
                    or defaults.tsxRender --[[@as string]])
                local tsxFill <const> = string.lower(args.tsxFill
                    or defaults.tsxFill --[[@as string]])

                for _, sheet in pairs(sheetPackets) do
                    local columns <const> = sheet.columns
                    local fileName <const> = sheet.fileName
                    local height <const> = sheet.height
                    local hTile <const> = sheet.hTile
                    local lenTileSet <const> = sheet.lenTileSet
                    local width <const> = sheet.width
                    local wTile <const> = sheet.wTile

                    -- Currently the allowed flips and rotations doesn't seem
                    -- accessible from Lua API, so default to 1, 1, 1, 0.
                    local tsxStr <const> = strfmt(
                        tsxFormat,
                        tmxVersion, tmxTiledVersion, fileName,
                        wTile, hTile, padding, margin, lenTileSet, columns,
                        tsxAlign, tsxRender, tsxFill,
                        1, 1, 1, 0,
                        strfmt("%s.%s", fileName, fileExt),
                        alphaStr, width, height)

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

                    local spriteGrid <const> = activeSprite.gridBounds
                    local wSprGrid <const> = math.max(1, math.abs(
                        wScale * spriteGrid.width))
                    local hSprGrid <const> = math.max(1, math.abs(
                        hScale * spriteGrid.height))

                    local wSprInTiles <const> = math.max(1, math.ceil(
                        (wScale * spriteSpec.width) / wSprGrid))
                    local hSprInTiles <const> = math.max(1, math.ceil(
                        (hScale * spriteSpec.height) / hSprGrid))

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
                        ---@type table<integer, integer>
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
                            local tileSetId <const> = layerPacket.tileset

                            local idxOffset = 0
                            if usedTileSets[tileSetId] then
                                idxOffset = usedTileSets[tileSetId]
                            else
                                idxOffset = firstgid
                                usedTileSets[tileSetId] = firstgid
                                local lenTileSet <const> = sheetPackets[tileSetId].lenTileSet
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
                                    local yw <const> = y * wMap
                                    ---@type integer[]
                                    local colArr = {}
                                    local x = 0
                                    while x < wMap do
                                        local flat <const> = 1 + yw + x
                                        local index <const> = indices[flat]
                                        local comp = 0
                                        if index ~= 0 then
                                            local flag <const> = flags[flat]
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
                        for tsId, tsGid in pairs(usedTileSets) do
                            local sheet <const> = sheetPackets[tsId]
                            tsxRefStrs[#tsxRefStrs + 1] = strfmt(
                                tilsetRefFormat,
                                tsGid,
                                sheet.fileName)
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
            end         -- End Tiled format check.
        end             -- End write meta data check.

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