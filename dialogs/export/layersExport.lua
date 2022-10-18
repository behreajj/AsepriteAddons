dofile("../../support/aseutilities.lua")

-- The range object is just not viable for this case,
-- because it can contain both a parent layer (a group)
-- and some or none of its children, leading to either
-- duplicates or an uncertain user intention.
local layerTargetOptions = { "ACTIVE", "ALL" }
local frameTargetOptions = { "ACTIVE", "ALL", "RANGE" }
local boundsOptions = { "CEL", "SPRITE" }
local originsOptions = { "CENTER", "CORNER" }

local defaults = {
    layerTarget = "ALL",
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "1,4,5-10",
    bounds = "CEL",
    padding = 2,
    padColor = Color(0, 0, 0, 0),
    scale = 1,
    prApply = false,
    flatGroups = false,
    saveJson = false,
    origin = "CORNER"
}

local function appendVisChildren(layer, array)
    if layer.isVisible then
        if layer.isGroup then
            local childLayers = layer.layers
            local lenChildLayers = #childLayers
            local i = 0
            while i < lenChildLayers do
                i = i + 1
                local childLayer = childLayers[i]
                appendVisChildren(childLayer, array)
            end
        else
            table.insert(array, layer)
        end
    end

    return array
end

local function bakeAlpha(hex, layerOpacity, celOpacity)
    local la = layerOpacity or 255
    local ca = celOpacity or 255
    local ha = (hex >> 0x18) & 0xff
    local hrgb = hex & 0x00ffffff
    local abake = (la * ca * ha) // 65025
    return (abake << 0x18) | hrgb
end

local function blendModeToStr(bm)
    -- The blend mode for group layers is nil.
    if bm then
        for k, v in pairs(BlendMode) do
            if bm == v then return k end
        end
    else
        return "NORMAL"
    end
end

local function getStackIndices(layer, sprite, arr)
    table.insert(arr, 1, layer.stackIndex)
    local sprName = "doc::Sprite"
    if sprite then sprName = sprite.__name end
    if layer.parent.__name == sprName then
        return arr
    else
        return getStackIndices(layer.parent, sprite, arr)
    end
end

local dlg = Dialog { title = "Export Layers" }

dlg:combobox {
    id = "layerTarget",
    label = "Layers:",
    option = defaults.layerTarget,
    options = layerTargetOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local state = dlg.data.frameTarget
        local isRange = state == "RANGE"
        dlg:modify { id = "rangeStr", visible = isRange }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Range:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.frameTarget == "RANGE",
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

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding,
    onchange = function()
        local args = dlg.data
        local pad = args.padding
        dlg:modify { id = "padColor", visible = pad > 0 }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "padColor",
    label = "Color:",
    color = defaults.padColor,
    visible = defaults.padding > 0
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
    id = "prApply",
    label = "Apply:",
    text = "Pixel Aspect",
    selected = defaults.prApply
}

dlg:newrow { always = false }

dlg:check {
    id = "flatGroups",
    label = "Flatten Groups:",
    selected = defaults.flatGroups,
    onclick = function()
        local args = dlg.data
        local useFlat = args.flatGroups
        dlg:modify { id = "useFlatWarning", visible = useFlat }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "bounds",
    label = "Bounds:",
    option = defaults.bounds,
    options = boundsOptions
}

dlg:newrow { always = false }

dlg:check {
    id = "saveJson",
    label = "Save JSON:",
    selected = defaults.saveJson,
    onclick = function()
        local args = dlg.data
        local enabled = args.saveJson
        dlg:modify { id = "origin", visible = enabled }
        dlg:modify { id = "userDataWarning", visible = enabled }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "origin",
    label = "Origin:",
    option = defaults.origin,
    options = originsOptions,
    visible = defaults.saveJson
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

dlg:label {
    id = "useFlatWarning",
    label = "Note:",
    text = "Blend modes not supported.",
    visible = defaults.flatGroups
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

        -- Early return for flatten groups and color mode.
        local specSprite = activeSprite.spec
        local colorMode = specSprite.colorMode
        local args = dlg.data
        local flatGroups = args.flatGroups
        if flatGroups and colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported for flatten groups."
            }
            return
        end

        -- Unpack sprite properties.
        local alphaIndex = specSprite.transparentColor
        local colorSpace = specSprite.colorSpace
        local spritePalettes = activeSprite.palettes
        local lenPalettes = #spritePalettes

        -- Version specific.
        local checkTilemaps = AseUtilities.tilesSupport()
        local missingUserData = "null"
        local spriteUserData = "\"data\":" .. missingUserData
        if checkTilemaps then
            local rawUserData = activeSprite.data
            if rawUserData and #rawUserData > 0 then
                spriteUserData = string.format(
                    "\"data\":%s", rawUserData)
            end
        end

        -- Unpack arguments.
        local layerTarget = args.layerTarget or defaults.layerTarget
        local frameTarget = args.frameTarget or defaults.frameTarget
        local rangeStr = args.rangeStr or defaults.rangeStr
        local bounds = args.bounds or defaults.bounds
        local padding = args.padding or defaults.padding
        local padColor = args.padColor or defaults.padColor
        local wScale = args.scale or defaults.scale
        local hScale = wScale
        local prApply = args.prApply
        local filename = args.filename

        local saveJson = args.saveJson
        local origin = args.origin or defaults.origin

        -- Cache methods used in loops.
        local floor = math.floor
        local strfmt = string.format
        local strgsub = string.gsub
        local concat = table.concat
        local insert = table.insert
        local blend = AseUtilities.blend
        local tilesToImage = AseUtilities.tilesToImage
        local trimAlpha = AseUtilities.trimImageAlpha

        -- .webp file extensions do not allow indexed
        -- color mode and Aseprite doesn't handle this
        -- limitation gracefully. RGB is required above
        -- anyway, so no need to worry.
        local fileExt = app.fs.fileExtension(filename)
        if fileExt == "json" then
            fileExt = app.preferences.export_file.image_default_extension
            filename = string.sub(filename, 1, -5) .. fileExt
        end

        local filePath = app.fs.filePath(filename)
        if filePath == nil or #filePath < 1 then
            app.alert { title = "Error", text = "Empty file path." }
            return
        end
        filePath = strgsub(filePath, "\\", "\\\\")

        local pathSep = app.fs.pathSeparator
        pathSep = strgsub(pathSep, "\\", "\\\\")

        local fileTitle = app.fs.fileTitle(filename)
        fileTitle = Utilities.validateFilename(fileTitle)

        filePath = filePath .. pathSep
        local filePrefix = filePath .. fileTitle

        -- Choose layers.
        local selectLayers = {}
        if layerTarget == "ACTIVE" then
            local activeLayer = app.activeLayer
            if activeLayer then
                if flatGroups then
                    -- Assume that user wants active layer even
                    -- if it is not visible.
                    selectLayers[1] = activeLayer
                else
                    appendVisChildren(activeLayer, selectLayers)
                end
            end
        else
            local activeLayers = activeSprite.layers
            local lenActiveLayers = #activeLayers
            if flatGroups then
                local i = 0
                while i < lenActiveLayers do i = i + 1
                    local activeLayer = activeLayers[i]
                    if activeLayer.isVisible then
                        insert(selectLayers, activeLayer)
                    end
                end
            else
                local i = 0
                while i < lenActiveLayers do i = i + 1
                    appendVisChildren(activeLayers[i], selectLayers)
                end
            end
        end

        -- Choose frames.
        local selectFrames = {}
        if frameTarget == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                selectFrames[1] = activeFrame
            end
        elseif frameTarget == "RANGE" then
            local allFrames = activeSprite.frames
            local lenAllFrames = #allFrames
            local idxRangeSet = Utilities.parseRangeStringUnique(
                rangeStr, lenAllFrames)
            local lenIdxRangeSet = #idxRangeSet

            if #rangeStr < 1 or lenIdxRangeSet < 1 then
                local rangeFrames = app.range.frames
                local rangeFramesLen = #rangeFrames
                for i = 1, rangeFramesLen, 1 do
                    selectFrames[i] = rangeFrames[i]
                end
            else
                for i = 1, lenIdxRangeSet, 1 do
                    selectFrames[i] = allFrames[idxRangeSet[i]]
                end
            end
        else
            local allFrames = activeSprite.frames
            for i = 1, #allFrames, 1 do
                selectFrames[i] = allFrames[i]
            end
        end

        if prApply then
            local pxRatio = activeSprite.pixelRatio
            local pxw = math.max(1, math.abs(pxRatio.width))
            local pxh = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end

        local selectLayerLen = #selectLayers
        local selectFrameLen = #selectFrames

        local useCenter = origin == "CENTER"
        local useResize = wScale ~= 1 or hScale ~= 1
        local useSpriteBounds = bounds == "SPRITE"
        local usePadding = padding > 0
        local usePadColor = padColor.alpha > 0

        -- Determine how to pad the image in hexadecimal
        -- based on sprite color mode.
        local pad2 = padding + padding
        local padOffset = Point(padding, padding)
        local padHex = AseUtilities.aseColorToHex(padColor, colorMode)

        local jsonEntries = {}
        local h = 0
        while h < selectLayerLen do h = h + 1
            local layer = selectLayers[h]
            local layerBlendMode = layer.blendMode
            local layerData = layer.data
            local layerName = layer.name
            local layerOpacity = layer.opacity

            -- Group layer possibility.
            local layerIsGroup = layer.isGroup
            local flatAndGroup = flatGroups and layerIsGroup
            local childLayers = nil
            local childLayersCount = 0
            if flatAndGroup then
                childLayers = {}
                appendVisChildren(layer, childLayers)
                childLayersCount = #childLayers
            end

            -- Tile map possibility.
            local layerIsTilemap = false
            local tileSet = nil
            if checkTilemaps then
                layerIsTilemap = layer.isTilemap
                if layerIsTilemap then
                    tileSet = layer.tileset
                end
            end

            -- A layer's stack index is local to its parent,
            -- not global to the entire sprite, so there needs
            -- to be a way to represent the hierarchy.
            local layerStackIndices = {}
            getStackIndices(layer, activeSprite, layerStackIndices)

            local jsonLayer = {
                layerBlendMode = layerBlendMode,
                layerData = layerData,
                layerName = layerName,
                layerOpacity = layerOpacity,
                layerStackIndices = layerStackIndices,
                jsonFrames = {}
            }

            local i = 0
            while i < selectFrameLen do i = i + 1
                local frame = selectFrames[i]
                local frameIndex = frame.frameNumber
                local palIndex = frameIndex
                if palIndex > lenPalettes then palIndex = 1 end
                local activePalette = spritePalettes[palIndex]

                local xTrg = 0
                local yTrg = 0
                local imgTrg = nil

                local celData = nil
                local celOpacity = 255
                local fileNameShort = strfmt(
                    "%s%03d_%03d",
                    fileTitle, h - 1, i - 1)

                if flatAndGroup then

                    local xMin = 2147483647
                    local yMin = 2147483647
                    local xMax = -2147483648
                    local yMax = -2147483648
                    local childPackets = {}

                    local j = 0
                    while j < childLayersCount do j = j + 1
                        local childLayer = childLayers[j]

                        local childLayerIsTilemap = false
                        local childTileSet = nil
                        if checkTilemaps then
                            childLayerIsTilemap = childLayer.isTilemap
                            if childLayerIsTilemap then
                                childTileSet = childLayer.tileset
                            end
                        end

                        local childCel = childLayer:cel(frame)
                        if childCel then
                            local celBounds = childCel.bounds
                            local tlx = celBounds.x
                            local tly = celBounds.y
                            local brx = tlx + celBounds.width
                            local bry = tly + celBounds.height

                            if tlx < xMin then xMin = tlx end
                            if tly < yMin then yMin = tly end
                            if brx > xMax then xMax = brx end
                            if bry > yMax then yMax = bry end

                            local imgChild = nil
                            if childLayerIsTilemap then
                                imgChild = tilesToImage(
                                    childCel.image,
                                    childTileSet,
                                    colorMode)
                            else
                                imgChild = childCel.image
                            end

                            -- Layer opacity does not need validation here
                            -- because the layer is known to already contain
                            -- a cel and therefore to not be a group.
                            local childPacket = {
                                alphaCel = childCel.opacity,
                                alphaLayer = childLayer.opacity,
                                image = imgChild,
                                xCel = tlx,
                                yCel = tly
                            }
                            insert(childPackets, childPacket)
                        end
                    end

                    if xMax > xMin and yMax > yMin then
                        -- Create composite image. Has to be RGB
                        -- due to alpha blending.
                        local specComp = ImageSpec {
                            width = xMax - xMin,
                            height = yMax - yMin,
                            colorMode = ColorMode.RGB,
                            transparentColor = alphaIndex
                        }
                        specComp.colorSpace = colorSpace
                        local imgComp = Image(specComp)

                        local lenPackets = #childPackets
                        local k = 0
                        while k < lenPackets do k = k + 1
                            local packet = childPackets[k]
                            local alphaCel = packet.alphaCel
                            local alphaLayer = packet.alphaLayer
                            local xDiff = packet.xCel - xMin
                            local yDiff = packet.yCel - yMin
                            local pxItr = packet.image:pixels()

                            for elm in pxItr do
                                local x = elm.x + xDiff
                                local y = elm.y + yDiff

                                -- Assumes hexDest is in RGB color mode.
                                local hexOrigin = imgComp:getPixel(x, y)
                                local hexDest = elm()
                                local bakedDest = bakeAlpha(
                                    hexDest, alphaLayer, alphaCel)
                                local blended = blend(hexOrigin, bakedDest)
                                imgComp:drawPixel(x, y, blended)
                            end
                        end

                        xTrg = xMin
                        yTrg = yMin
                        imgTrg = imgComp
                    end

                else

                    local cel = layer:cel(frame)
                    if cel then
                        celData = cel.data
                        celOpacity = cel.opacity
                        local celPos = cel.position
                        xTrg = celPos.x
                        yTrg = celPos.y
                        if layerIsTilemap then
                            imgTrg = tilesToImage(
                                cel.image, tileSet, colorMode)
                        else
                            imgTrg = cel.image
                        end
                    end

                end

                if imgTrg then
                    if useSpriteBounds then
                        local imgSprite = Image(specSprite)
                        imgSprite:drawImage(imgTrg, Point(xTrg, yTrg))

                        xTrg = 0
                        yTrg = 0
                        imgTrg = imgSprite
                    else
                        local imgTrim, xTrim, yTrim = trimAlpha(
                            imgTrg, 0, alphaIndex)

                        xTrg = xTrg + xTrim
                        yTrg = yTrg + yTrim
                        imgTrg = imgTrim
                    end

                    if useResize then
                        imgTrg = AseUtilities.resizeImageNearest(imgTrg,
                            imgTrg.width * wScale,
                            imgTrg.height * hScale)
                    end

                    if usePadding then
                        local specPad = ImageSpec {
                            colorMode = colorMode,
                            width = imgTrg.width + pad2,
                            height = imgTrg.height + pad2,
                            transparentColor = alphaIndex
                        }
                        specPad.colorSpace = colorSpace
                        local imgPad = Image(specPad)
                        if usePadColor then
                            imgPad:clear(padHex)
                        end
                        imgPad:drawImage(imgTrg, padOffset)
                        imgTrg = imgPad
                    end

                    if useCenter then
                        xTrg = xTrg + (imgTrg.width - pad2) // 2
                        yTrg = yTrg + (imgTrg.height - pad2) // 2
                    else
                        xTrg = xTrg - padding
                        yTrg = yTrg - padding
                    end

                    local fileNameLong = strfmt(
                        "%s%03d_%03d.%s",
                        filePrefix, h - 1, i - 1, fileExt)
                    imgTrg:saveAs {
                        filename = fileNameLong,
                        palette = activePalette
                    }

                    local jsonFrame = {
                        celData = celData,
                        celOpacity = celOpacity,
                        fileName = fileNameShort,
                        frameDuration = frame.duration,
                        frameNumber = frameIndex,
                        height = imgTrg.height,
                        width = imgTrg.width,
                        xOrigin = xTrg,
                        yOrigin = yTrg
                    }
                    insert(jsonLayer.jsonFrames, jsonFrame)
                end
            end

            if #jsonLayer.jsonFrames > 0 then
                insert(jsonEntries, jsonLayer)
            end
        end

        if saveJson then

            local versionStrFmt = concat({
                "{\"version\":{\"major\":%d",
                "\"minor\":%d",
                "\"patch\":%d",
                "\"prerelease\":\"%s\"",
                "\"prNo\":%d}",
            }, ",")

            local version = app.version
            local versionStr = strfmt(
                versionStrFmt,
                version.major, version.minor, version.patch,
                version.prereleaseLabel, version.prereleaseNumber)

            local jsonStrFmt = concat({
                versionStr,
                "\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                spriteUserData,
                "\"padding\":%d",
                "\"scale\":{\"x\":%d,\"y\":%d}",
                "\"layers\":[%s]}"
            }, ",")

            local layerStrFmt = concat({
                "{\"blendMode\":\"%s\"",
                "\"data\":%s",
                "\"name\":\"%s\"",
                "\"opacity\":%d",
                "\"stackIndices\":[%s]",
                "\"frames\":[%s]}"
            }, ",")

            local celStrFmt = concat({
                "{\"data\":%s",
                "\"fileName\":\"%s\"",
                "\"opacity\":%d",
                "\"position\":{\"x\":%d,\"y\":%d}",
                "\"size\":{\"x\":%d,\"y\":%d}}"
            }, ",")

            local frameStrFmt = concat({
                "{\"duration\":%d",
                "\"number\":%d",
                strfmt("\"cel\":%s}", celStrFmt)
            }, ",")

            local lenJsonEntries = #jsonEntries
            local layerStrArr = {}
            local i = 0
            while i < lenJsonEntries do i = i + 1
                local jsonLayer = jsonEntries[i]
                local jsonFrames = jsonLayer.jsonFrames
                local lenJsonFrames = #jsonFrames
                local celStrArr = {}
                local j = 0
                while j < lenJsonFrames do j = j + 1
                    local jsonFrame = jsonFrames[j]

                    -- Some data needs validation / transformation.
                    local frameDuration = floor(jsonFrame.frameDuration * 1000)
                    local frameNumber = jsonFrame.frameNumber - 1
                    local celData = jsonFrame.celData
                    if celData == nil or #celData < 1 then
                        celData = missingUserData
                    end

                    celStrArr[j] = strfmt(
                        frameStrFmt, frameDuration,
                        frameNumber, celData,
                        jsonFrame.fileName, jsonFrame.celOpacity,
                        jsonFrame.xOrigin, jsonFrame.yOrigin,
                        jsonFrame.width, jsonFrame.height)
                end

                -- Layer information.
                local layerBlendMode = blendModeToStr(jsonLayer.layerBlendMode)
                local layerData = jsonLayer.layerData
                if layerData == nil or #layerData < 1 then
                    layerData = missingUserData
                end

                local layerName = "Layer"
                if jsonLayer.layerName
                    and #jsonLayer.layerName > 0 then
                    layerName = jsonLayer.layerName
                end

                local layerOpacity = 0xff
                if jsonLayer.layerOpacity then
                    layerOpacity = jsonLayer.layerOpacity
                end

                -- Use JSON indexing conventions, start at zero.
                local layerStackIndices = jsonLayer.layerStackIndices
                local stackIdcsLen = #layerStackIndices
                local m = 0
                while m < stackIdcsLen do m = m + 1
                    layerStackIndices[m] = layerStackIndices[m] - 1
                end
                local stackIdcsStr = concat(layerStackIndices, ",")

                layerStrArr[i] = strfmt(
                    layerStrFmt, layerBlendMode,
                    layerData, layerName,
                    layerOpacity, stackIdcsStr,
                    concat(celStrArr, ","))
            end

            local jsonString = strfmt(
                jsonStrFmt,
                filePath, fileExt,
                padding, wScale, hScale,
                concat(layerStrArr, ","))

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

        app.refresh()
        app.alert { title = "Success", text = "File exported." }
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