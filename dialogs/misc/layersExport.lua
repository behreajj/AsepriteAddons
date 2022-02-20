dofile("../../support/aseutilities.lua")

local boundsOptions = { "CEL", "SPRITE" }
local originOptions = { "CENTER", "CORNER" }
local targetOptions = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ALL",
    bounds = "CEL",
    padding = 2,
    padColor = Color(0, 0, 0, 0),
    scale = 1,
    saveJson = false,
    origin = "CORNER",
    pullFocus = false,
    -- missingUserData = "\"\""
    missingUserData = "null"
}

local dlg = Dialog { title = "Export Layers" }

dlg:combobox {
    id = "target",
    label = "Layers:",
    option = defaults.target,
    options = targetOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "bounds",
    label = "Bounds:",
    option = defaults.bounds,
    options = boundsOptions
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

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS,
    save = true
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
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "origin",
    label = "Origin:",
    option = defaults.origin,
    options = originOptions,
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
            local target = args.target or defaults.target
            local bounds = args.bounds or defaults.bounds
            local padding = args.padding or defaults.padding
            local padColor = args.padColor or defaults.padColor
            local scale = args.scale or defaults.scale
            local filename = args.filename
            local saveJson = args.saveJson
            local origin = args.origin or defaults.origin
            local missingUserData = defaults.missingUserData

            -- Cache methods used in loops.
            local trunc = math.tointeger
            local strfmt = string.format
            local strgsub = string.gsub
            local concat = table.concat
            local insert = table.insert
            local isVisibleHierarchy = AseUtilities.isVisibleHierarchy
            local trimAlpha = AseUtilities.trimImageAlpha

            -- app.command.ChangePixelFormat { format = "rgb" }

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

            -- Determine cels by target preset.
            -- TODO: Create a flatten group layers method
            -- then refactor this to use layers instead of cels.
            local cels = {}
            if target == "ACTIVE" then
                local activeCel = app.activeCel
                if activeCel then
                    cels[1] = activeCel
                end
            elseif target == "RANGE" then
                cels = app.range.cels
            else
                cels = activeSprite.cels
            end

            local useSpriteBounds = bounds == "SPRITE"
            local useCenter = origin == "CENTER"
            local useResize = scale ~= 1
            local addPadding = padding > 0
            local usePadColor = padColor.alpha > 0
            local pad2 = padding + padding
            local padOffset = Point(padding, padding)

            local padHex = 0
            if oldMode == ColorMode.INDEXED then
                -- Color.index returns a float, not an integer.
                padHex = math.tointeger(padColor.index)
            elseif oldMode == ColorMode.GRAY then
                padHex = padColor.grayPixel
            else
                padHex = padColor.rgbaPixel
            end

            local layerFormat = concat({
                "{\"stackIndex\":%d,",
                "\"name\":\"%s\",",
                "\"opacity\":%d,",
                "\"data\":%s,",
                "\"frames\":["
            })
            local frameFormat = concat({
                "{\"frameNumber\":%d,",
                "\"fileName\":\"%s\",",
                "\"duration\":%d,",
                "\"position\":{\"x\":%d,\"y\":%d},",
                "\"dimension\":{\"x\":%d,\"y\":%d},",
                "\"opacity\":%d,",
                "\"data\":%s}"
            })

            local celsLen = #cels
            local jsonEntries = {}
            local j = 1
            for i = 1, celsLen, 1 do
                local cel = cels[i]
                local layer = cel.layer

                -- TODO: Option to bake cel and layer alpha?
                local isVis = isVisibleHierarchy(layer, activeSprite)
                local isRef = layer.isReference
                if isVis and (not isRef) then
                    local srcImage = cel.image
                    local isEmpty = srcImage:isEmpty()
                    if not isEmpty then
                        local trgImage = nil
                        local xOrigin = 0
                        local yOrigin = 0
                        if useSpriteBounds then
                            local celPos = cel.position
                            trgImage = Image(widthSprite, heightSprite, oldMode)
                            trgImage:drawImage(srcImage, celPos)
                        else
                            trgImage, xOrigin, yOrigin = trimAlpha(
                                srcImage, 0, alphaIndex)
                            local celPos = cel.position
                            xOrigin = xOrigin + celPos.x
                            yOrigin = yOrigin + celPos.y
                        end

                        -- These file names cannot use stack index as a naming
                        -- convention, because stack indices are relative to
                        -- a parent, not absolute to the sprite.
                        local frameNumber = cel.frameNumber
                        local fileNameShort = strfmt(
                            "%s%03d_%03d",
                            fileTitle, i, frameNumber)
                        local fileNameLong = strfmt(
                            "%s%03d_%03d.%s",
                            filePrefix, i, frameNumber, fileExt)

                        if useResize then
                            trgImage:resize(
                                trgImage.width * scale,
                                trgImage.height * scale)
                        end

                        if addPadding then
                            local trgWidth = trgImage.width
                            local trgHeight = trgImage.height
                            local padWidth = trgWidth + pad2
                            local padHeight = trgHeight + pad2

                            local padded = Image(padWidth, padHeight, oldMode)
                            padded:drawImage(trgImage, padOffset)

                            if usePadColor then
                                -- Top edge.
                                for x = 0, trgWidth + padding - 1, 1 do
                                    for y = 0, padding - 1, 1 do
                                        padded:drawPixel(x, y, padHex)
                                    end
                                end

                                -- Right edge.
                                for y = 0, trgHeight + padding - 1, 1 do
                                    for x = trgWidth + padding, padWidth - 1, 1 do
                                        padded:drawPixel(x, y, padHex)
                                    end
                                end

                                -- Bottom edge.
                                for x = padding, padWidth - 1, 1 do
                                    for y = trgHeight + padding, padHeight - 1, 1 do
                                        padded:drawPixel(x, y, padHex)
                                    end
                                end

                                -- Left edge.
                                for y = padding, padHeight - 1, 1 do
                                    for x = 0, padding - 1, 1 do
                                        padded:drawPixel(x, y, padHex)
                                    end
                                end
                            end
                            trgImage = padded
                        end

                        trgImage:saveAs {
                            filename = fileNameLong,
                            palette = activePalette
                        }

                        jsonEntries[j] = {
                            celData = cel.data,
                            celOpacity = cel.opacity,
                            fileName = fileNameShort,
                            layer = layer,
                            frameDuration = trunc(cel.frame.duration * 1000),
                            frameNumber = cel.frameNumber,
                            xOrigin = xOrigin,
                            yOrigin = yOrigin,
                            width = trgImage.width,
                            height = trgImage.height
                        }
                        j = j + 1
                    end
                end
            end

            if saveJson then

                -- Regroup each entry by layer.
                local entriesByLayer = {}
                local jsonDataLen = #jsonEntries
                for i = 1, jsonDataLen, 1 do
                    local entry = jsonEntries[i]
                    local layer = entry.layer
                    local stackIndex = layer.stackIndex
                    if entriesByLayer[stackIndex] then
                        insert(entriesByLayer[stackIndex], entry)
                    else
                        entriesByLayer[stackIndex] = { entry }
                    end
                end

                local lyrStrArr = {}
                for stackIndex, celsArr in pairs(entriesByLayer) do
                    local celStrArr = {}
                    local celsArrLen = #celsArr
                    for i = 1, celsArrLen, 1 do
                        local entry = celsArr[i]

                        -- Unpack entry.
                        local fileName = entry.fileName
                        local xOrigin = entry.xOrigin
                        local yOrigin = entry.yOrigin
                        local width = entry.width
                        local height = entry.height

                        -- Cel Properties.
                        local celData = entry.celData
                        local celOpacity = entry.celOpacity
                        local frameNumber = entry.frameNumber
                        local frameDuration = entry.frameDuration

                        if celData == nil or #celData < 1 then
                            celData = missingUserData
                        end

                        xOrigin = xOrigin * scale
                        yOrigin = yOrigin * scale

                        if useCenter then
                            xOrigin = xOrigin + width // 2
                            yOrigin = yOrigin + height // 2
                        else
                            xOrigin = xOrigin - padding
                            yOrigin = yOrigin - padding
                        end

                        celStrArr[i] = strfmt(
                            frameFormat,
                            frameNumber, fileName, frameDuration,
                            xOrigin, yOrigin,
                            width, height,
                            celOpacity, celData)
                    end

                    -- Unpack layer.
                    local layer = celsArr[1].layer
                    local layerName = layer.name
                    local layerOpacity = layer.opacity
                    local layerData = layer.data
                    if layerData == nil or #layerData < 1 then
                        layerData = missingUserData
                    end

                    local layerPrefix = strfmt(
                        layerFormat,
                        stackIndex, layerName,
                        layerOpacity, layerData)
                    local layerStr = layerPrefix
                        .. concat(celStrArr, ",")
                        .. "]}"
                    insert(lyrStrArr, layerStr)
                end
                local jsonString = strfmt(
                    "{\"fileDir\":\"%s\",\"fileExt\":\"%s\",\"layers\":[",
                    filePath, fileExt)
                    .. concat(lyrStrArr, ",")
                    .. strfmt(
                        "],\"padding\":%d,\"scale\":%d}",
                        padding, scale)

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
            dlg:close()
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