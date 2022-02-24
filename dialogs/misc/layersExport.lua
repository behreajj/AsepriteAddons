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
    frameStart = 1,
    frameCount = 8,
    maxFrameCount = 32,
    bounds = "CEL",
    padding = 2,
    padColor = Color(0, 0, 0, 0),
    scale = 1,
    flatGroups = false,
    saveJson = false,
    origin = "CORNER",
    pullFocus = false
}

local function appendVisChildren(layer, array)
    if layer.isVisible then
        if layer.isGroup then
            local childLayers = layer.layers
            if childLayers then
                local childLayerCount = #childLayers
                if childLayerCount > 0 then
                    for i = 1, childLayerCount, 1 do
                        local childLayer = childLayers[i]
                        if childLayer then
                            appendVisChildren(childLayer, array)
                        end
                    end
                end
            end
        elseif (not layer.isReference) then
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
    if bm == BlendMode.NORMAL then
        return "NORMAL"
    elseif bm == BlendMode.MULTIPLY then
        return "MULTIPLY"
    elseif bm == BlendMode.SCREEN then
        return "SCREEN"
    elseif bm == BlendMode.OVERLAY then
        return "OVERLAY"
    elseif bm == BlendMode.DARKEN then
        return "DARKEN"
    elseif bm == BlendMode.LIGHTEN then
        return "LIGHTEN"
    elseif bm == BlendMode.COLOR_DODGE then
        return "COLOR_DODGE"
    elseif bm == BlendMode.COLOR_BURN then
        return "COLOR_BURN"
    elseif bm == BlendMode.HARD_LIGHT then
        return "HARD_LIGHT"
    elseif bm == BlendMode.SOFT_LIGHT then
        return "SOFT_LIGHT"
    elseif bm == BlendMode.DIFFERENCE then
        return "DIFFERENCE"
    elseif bm == BlendMode.EXCLUSION then
        return "EXCLUSION"
    elseif bm == BlendMode.HSL_HUE then
        return "HSL_HUE"
    elseif bm == BlendMode.HSL_SATURATION then
        return "HSL_SATURATION"
    elseif bm == BlendMode.HSL_COLOR then
        return "HSL_COLOR"
    elseif bm == BlendMode.HSL_LUMINOSITY then
        return "HSL_LUMINOSITY"
    elseif bm == BlendMode.ADDITION then
        return "ADDITION"
    elseif bm == BlendMode.SUBTRACT then
        return "SUBTRACT"
    elseif bm == BlendMode.DIVIDE then
        return "DIVIDE"
    else
        return "NORMAL"
    end
end

local function fillPad(img, padding, padHex)
    local padWidth = img.width
    local padHeight = img.height
    local trgWidth = padWidth - padding * 2
    local trgHeight = padHeight - padding * 2

    -- Top edge.
    for x = 0, trgWidth + padding - 1, 1 do
        for y = 0, padding - 1, 1 do
            img:drawPixel(x, y, padHex)
        end
    end

    -- Right edge.
    for y = 0, trgHeight + padding - 1, 1 do
        for x = trgWidth + padding, padWidth - 1, 1 do
            img:drawPixel(x, y, padHex)
        end
    end

    -- Bottom edge.
    for x = padding, padWidth - 1, 1 do
        for y = trgHeight + padding, padHeight - 1, 1 do
            img:drawPixel(x, y, padHex)
        end
    end

    -- Left edge.
    for y = padding, padHeight - 1, 1 do
        for x = 0, padding - 1, 1 do
            img:drawPixel(x, y, padHex)
        end
    end

    return img
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
        dlg:modify { id = "frameStart", visible = isRange }
        dlg:modify { id = "frameCount", visible = isRange }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "frameStart",
    label = "Start:",
    min = 1,
    max = 256,
    value = defaults.frameStart,
    visible = defaults.frameTarget == "RANGE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "frameCount",
    label = "Count:",
    min = 1,
    max = defaults.maxFrameCount,
    value = defaults.frameCount,
    visible = defaults.frameTarget == "RANGE"
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
    save = true
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
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then

            -- Unpack sprite properties.
            local oldMode = activeSprite.colorMode
            local alphaIndex = activeSprite.transparentColor
            local activePalette = activeSprite.palettes[1]
            local widthSprite = activeSprite.width
            local heightSprite = activeSprite.height

            -- Unpack arguments.
            local args = dlg.data
            local layerTarget = args.layerTarget or defaults.layerTarget
            local frameTarget = args.frameTarget or defaults.frameTarget
            local frameStart = args.frameStart or defaults.frameStart
            local frameCount = args.frameCount or defaults.frameCount
            local bounds = args.bounds or defaults.bounds
            local padding = args.padding or defaults.padding
            local padColor = args.padColor or defaults.padColor
            local scale = args.scale or defaults.scale
            local filename = args.filename
            local flatGroups = args.flatGroups
            local saveJson = args.saveJson
            local origin = args.origin or defaults.origin

            -- Cache methods used in loops.
            local min = math.min
            local trunc = math.tointeger
            local strfmt = string.format
            local strgsub = string.gsub
            local concat = table.concat
            local insert = table.insert
            local blend = AseUtilities.blend
            local trimAlpha = AseUtilities.trimImageAlpha

            -- Clean file path strings.
            local filePath = app.fs.filePath(filename)
            filePath = strgsub(filePath, "\\", "\\\\")
            local pathSep = app.fs.pathSeparator
            pathSep = strgsub(pathSep, "\\", "\\\\")
            local fileTitle = app.fs.fileTitle(filename)
            local fileExt = app.fs.fileExtension(filename)
            fileTitle = strgsub(fileTitle, "%s+", "")
            filePath = filePath .. pathSep
            local filePrefix = filePath .. fileTitle

            -- Choose layers.
            local selectLayers = {}
            if layerTarget == "ACTIVE" then
                local activeLayer = app.activeLayer
                if activeLayer then
                    if flatGroups then
                        selectLayers[1] = activeLayer
                    else
                        appendVisChildren(activeLayer, selectLayers)
                    end
                end
            else
                local activeLayers = activeSprite.layers
                if flatGroups then
                    for i = 1, #activeLayers, 1 do
                        selectLayers[i] = activeLayers[i]
                    end
                else
                    for i = 1, #activeLayers, 1 do
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
                local availFrames = #allFrames
                local frameStartVal = min(frameStart, availFrames)
                local frameCountVal = min(frameCount, 1 + availFrames - frameStartVal)
                for i = 1, frameCountVal, 1 do
                    selectFrames[i] = allFrames[frameStartVal + i - 1]
                end
            else
                local activeFrames = activeSprite.frames
                for i = 1, #activeFrames, 1 do
                    selectFrames[i] = activeFrames[i]
                end
            end

            local selectLayerLen = #selectLayers
            local selectFrameLen = #selectFrames

            local useCenter = origin == "CENTER"
            local useResize = scale ~= 1
            local useSpriteBounds = bounds == "SPRITE"
            local usePadding = padding > 0
            local usePadColor = padColor.alpha > 0

            local pad2 = padding + padding
            local padOffset = Point(padding, padding)

            local padHex = 0
            if oldMode == ColorMode.INDEXED then
                -- In older API versions, Color.index
                -- returns a float, not an integer.
                padHex = math.tointeger(padColor.index)
            elseif oldMode == ColorMode.GRAY then
                padHex = padColor.grayPixel
            else
                padHex = padColor.rgbaPixel
            end

            local jsonEntries = {}
            for i = 1, selectLayerLen, 1 do
                local layer = selectLayers[i]
                local layerBlendMode = layer.blendMode
                local layerData = layer.data
                local layerName = layer.name
                local layerOpacity = layer.opacity
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

                if flatGroups and layer.isGroup then
                    local childLayers = {}
                    appendVisChildren(layer, childLayers)
                    local childLayersCount = #childLayers

                    for j = 1, selectFrameLen, 1 do
                        local frame = selectFrames[j]

                        local xMin = 2147483647
                        local yMin = 2147483647
                        local xMax = -2147483648
                        local yMax = -2147483648
                        local childCels = {}

                        for k = 1, childLayersCount, 1 do
                            local childLayer = childLayers[k]
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

                                insert(childCels, childCel)
                            end
                        end

                        if xMax > xMin and yMax > yMin then
                            local compWidth = xMax - xMin
                            local compHeight = yMax - yMin
                            local imgComp = Image(compWidth, compHeight)

                            local celCount = #childCels
                            for k = 1, celCount, 1 do
                                local cel = childCels[k]

                                local celAlpha = cel.opacity
                                local layerAlpha = 255
                                if cel.layer.opacity then
                                    layerAlpha = cel.layer.opacity
                                end

                                local celPos = cel.position
                                local xDiff = celPos.x - xMin
                                local yDiff = celPos.y - yMin

                                local celImage = cel.image
                                local pxItr = celImage:pixels()
                                for elm in pxItr do
                                    local x = elm.x + xDiff
                                    local y = elm.y + yDiff

                                    local hexOrigin = imgComp:getPixel(x, y)
                                    local hexDest = elm()
                                    local bakedDest = bakeAlpha(hexDest, layerAlpha, celAlpha)
                                    local blended = blend(hexOrigin, bakedDest)
                                    imgComp:drawPixel(x, y, blended)
                                end
                            end

                            local xTrg = xMin
                            local yTrg = yMin
                            local imgTrg = imgComp

                            if useSpriteBounds then
                                imgTrg = Image(widthSprite, heightSprite, oldMode)
                                imgTrg:drawImage(imgComp, Point(xMin, yMin))
                                xTrg = 0
                                yTrg = 0
                            end

                            if useResize then
                                imgTrg:resize(
                                    imgTrg.width * scale,
                                    imgTrg.height * scale)
                            end

                            if usePadding then
                                local wTrg = imgTrg.width
                                local hTrg = imgTrg.height
                                local wPad = wTrg + pad2
                                local hPad = hTrg + pad2
                                local padded = Image(wPad, hPad, oldMode)
                                padded:drawImage(imgTrg, padOffset)
                                if usePadColor then
                                    fillPad(padded, padding, padHex)
                                end
                                imgTrg = padded
                            end

                            local fileNameLong = strfmt(
                                "%s%03d_%03d.%s",
                                filePrefix, i - 1, j - 1, fileExt)
                            imgTrg:saveAs {
                                filename = fileNameLong,
                                palette = activePalette }

                            local fileNameShort = strfmt(
                                "%s%03d_%03d",
                                fileTitle, i - 1, j - 1)

                            xTrg = xTrg * scale
                            yTrg = yTrg * scale
                            if useCenter then
                                xTrg = xTrg + imgTrg.width // 2
                                yTrg = yTrg + imgTrg.height // 2
                            else
                                xTrg = xTrg - padding
                                yTrg = yTrg - padding
                            end

                            local jsonFrame = {
                                celData = nil,
                                celOpacity = 255,
                                fileName = fileNameShort,
                                frameDuration = frame.duration,
                                frameNumber = frame.frameNumber,
                                height = imgTrg.height,
                                width = imgTrg.width,
                                xOrigin = xTrg,
                                yOrigin = yTrg
                            }
                            insert(jsonLayer.jsonFrames, jsonFrame)
                        end
                    end
                elseif layer.isReference then
                    -- Pass.
                else
                    for j = 1, selectFrameLen, 1 do
                        local frame = selectFrames[j]
                        local cel = layer:cel(frame)
                        if cel then
                            local celPos = cel.position
                            local xSrc = celPos.x
                            local ySrc = celPos.y
                            local imgSrc = cel.image

                            local xTrg = 0
                            local yTrg = 0
                            local imgTrg = nil

                            if useSpriteBounds then
                                imgTrg = Image(widthSprite, heightSprite, oldMode)
                                imgTrg:drawImage(imgSrc, celPos)
                            else
                                local xTrim = 0
                                local yTrim = 0
                                imgTrg, xTrim, yTrim = trimAlpha(
                                    imgSrc, 0, alphaIndex)
                                xTrg = xSrc + xTrim
                                yTrg = ySrc + yTrim
                            end

                            if useResize then
                                imgTrg:resize(
                                    imgTrg.width * scale,
                                    imgTrg.height * scale)
                            end

                            if usePadding then
                                local wTrg = imgTrg.width
                                local hTrg = imgTrg.height
                                local wPad = wTrg + pad2
                                local hPad = hTrg + pad2
                                local padded = Image(wPad, hPad, oldMode)
                                padded:drawImage(imgTrg, padOffset)
                                if usePadColor then
                                    fillPad(padded, padding, padHex)
                                end
                                imgTrg = padded
                            end

                            local fileNameLong = strfmt(
                                "%s%03d_%03d.%s",
                                filePrefix, i - 1, j - 1, fileExt)
                            imgTrg:saveAs {
                                filename = fileNameLong,
                                palette = activePalette }

                            local fileNameShort = strfmt(
                                "%s%03d_%03d",
                                fileTitle, i - 1, j - 1)

                            xTrg = xTrg * scale
                            yTrg = yTrg * scale
                            if useCenter then
                                xTrg = xTrg + imgTrg.width // 2
                                yTrg = yTrg + imgTrg.height // 2
                            else
                                xTrg = xTrg - padding
                                yTrg = yTrg - padding
                            end

                            local jsonFrame = {
                                celData = cel.data,
                                celOpacity = cel.opacity,
                                fileName = fileNameShort,
                                frameDuration = frame.duration,
                                frameNumber = frame.frameNumber,
                                height = imgTrg.height,
                                width = imgTrg.width,
                                xOrigin = xTrg,
                                yOrigin = yTrg
                            }
                            insert(jsonLayer.jsonFrames, jsonFrame)
                        end
                    end
                end

                if #jsonLayer.jsonFrames > 0 then
                    insert(jsonEntries, jsonLayer)
                end
            end

            if saveJson then
                local missingUserData = "null"

                local jsonStrFmt = concat({
                    "{\"fileDir\":\"%s\"",
                    "\"fileExt\":\"%s\"",
                    "\"padding\":%d",
                    "\"scale\":%d",
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
                    "\"size\":{\"x\":%d,\"y\":%d}}",
                }, ",")

                local frameStrFmt = concat({
                    "{\"duration\":%d",
                    "\"number\":%d",
                    strfmt("\"cel\":%s}", celStrFmt)
                }, ",")

                local lenJsonEntries = #jsonEntries
                local layerStrArr = {}
                for i = 1, lenJsonEntries, 1 do
                    local jsonLayer = jsonEntries[i]
                    local jsonFrames = jsonLayer.jsonFrames
                    local lenJsonFrames = #jsonFrames
                    local celStrArr = {}
                    for j = 1, lenJsonFrames do
                        local jsonFrame = jsonFrames[j]

                        -- Frame information.
                        local frameDuration = trunc(jsonFrame.frameDuration * 1000)
                        local frameNumber = jsonFrame.frameNumber - 1

                        -- Cel Information.
                        local celData = jsonFrame.celData
                        if celData == nil or #celData < 1 then
                            celData = missingUserData
                        -- elseif type(celData == "string") then
                            -- Causes a problem for user data containing quote marks.
                            -- celData = strfmt("\"%s\"", celData)
                        end
                        local celOpacity = jsonFrame.celOpacity

                        -- Image, file information.
                        local fileName = jsonFrame.fileName
                        local width = jsonFrame.width
                        local height = jsonFrame.height
                        local xOrigin = jsonFrame.xOrigin
                        local yOrigin = jsonFrame.yOrigin

                        local celStr = strfmt(
                            frameStrFmt,
                            frameDuration,
                            frameNumber,
                            celData,
                            fileName,
                            celOpacity,
                            xOrigin, yOrigin,
                            width, height)
                        celStrArr[j] =  celStr
                    end

                    -- Layer information.
                    local layerBlendMode = blendModeToStr(jsonLayer.layerBlendMode)
                    local layerData = jsonLayer.layerData
                    if layerData == nil or #layerData < 1 then
                        layerData = missingUserData
                    -- elseif type(layerData == "string") then
                        -- Causes a problem for user data containing quote marks.
                        -- layerData = strfmt("\"%s\"", layerData)
                    end
                    local layerName = jsonLayer.layerName
                    local layerOpacity = 0xff
                    if jsonLayer.layerOpacity then
                        layerOpacity = jsonLayer.layerOpacity
                    end

                    -- Use JSON indexing conventions, start at zero.
                    local layerStackIndices = jsonLayer.layerStackIndices
                    local stackIdcsLen = #layerStackIndices
                    for j = 1, stackIdcsLen, 1 do
                        layerStackIndices[j] = layerStackIndices[j] - 1
                    end
                    local stackIdcsStr = concat(layerStackIndices, ",")

                    local layerStr = strfmt(
                        layerStrFmt, -- 1
                        layerBlendMode, -- 2
                        layerData, -- 3
                        layerName, -- 4
                        layerOpacity, -- 5
                        stackIdcsStr,
                        concat(celStrArr, ","))
                    layerStrArr[i] = layerStr
                end

                local jsonString = strfmt(
                    jsonStrFmt,
                    filePath,
                    fileExt,
                    padding,
                    scale,
                    concat(layerStrArr, ","))

                local jsonFilepath = filePrefix
                if #fileTitle < 1 then
                    jsonFilepath = filePath .. pathSep .. "manifest"
                end
                jsonFilepath = jsonFilepath .. ".json"
                local file = io.open(jsonFilepath, "w")
                file:write(jsonString)
                file:close()
            end

            app.refresh()
            -- dlg:close()
        else
            app.alert("There is no active sprite.")
        end
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