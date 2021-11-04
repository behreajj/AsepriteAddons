dofile("../support/aseutilities.lua")

local frames = { "CEL", "SPRITE" }
local origins = { "CENTER", "CORNER" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ALL",
    frame = "CEL",
    padding = 2,
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
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "frame",
    label = "Frame:",
    option = defaults.frame,
    options = frames
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

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = {
        "ase",
        "aseprite",
        "gif",
        "jpg",
        "jpeg",
        "png",
        "webp" },
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
    options = origins,
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
            -- Image padding is impacted by scaling. To correct this,
            -- you'd have to  make a separate image padding method in
            -- AseUtililties. Then trim, then scale, then pad.
            -- Doesn't seem worth it, though, as there's an argument
            -- that for a pixel perfect image, scaled pad is desirable.

            -- Unpack sprite properties.
            local oldMode = activeSprite.colorMode
            local alphaIndex = activeSprite.transparentColor
            local activePalette = activeSprite.palettes[1]
            local widthSprite = activeSprite.width
            local heightSprite = activeSprite.height

            -- Unpack arguments.
            local args = dlg.data
            local target = args.target or defaults.target
            local frame = args.frame or defaults.frame
            local padding = args.padding or defaults.padding
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

            local useSpriteFrame = frame == "SPRITE"
            local useCenter = origin == "CENTER"
            local useResize = scale ~= 1
            local pad2 = padding + padding
            local wPaddedSprite = widthSprite + pad2
            local hPaddedSprite = heightSprite + pad2
            local padOffset = Point(padding, padding)

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

                -- For whatever reason, the Lua hierarchical
                -- function causes problems.
                local isVis = layer.isVisible
                if isVis and (not layer.isReference) then
                    local srcImage = cel.image
                    local trgImage = nil
                    local xOrigin = 0
                    local yOrigin = 0
                    if useSpriteFrame then
                        local celPos = cel.position
                        trgImage = Image(wPaddedSprite, hPaddedSprite, oldMode)
                        trgImage:drawImage(srcImage, padOffset + celPos)
                    else
                        trgImage, xOrigin, yOrigin = trimAlpha(srcImage, padding, alphaIndex)
                        local celPos = cel.position
                        xOrigin = xOrigin + celPos.x
                        yOrigin = yOrigin + celPos.y
                    end

                    local stackIndex = layer.stackIndex
                    local frameNumber = cel.frameNumber

                    local fileNameShort = strfmt(
                        "%s%03d_%03d",
                        fileTitle, stackIndex, frameNumber)
                    local fileNameLong = strfmt(
                        "%s%03d_%03d.%s",
                        filePrefix, stackIndex, frameNumber, fileExt)

                    if useResize then
                        trgImage:resize(
                            trgImage.width * scale,
                            trgImage.height * scale)
                    end

                    trgImage:saveAs {
                        filename = fileNameLong,
                        palette = activePalette
                    }

                    jsonEntries[j] = {
                        fileName = fileNameShort,
                        cel = cel,
                        layer = layer,
                        xOrigin = xOrigin * scale,
                        yOrigin = yOrigin * scale,
                        width = trgImage.width,
                        height = trgImage.height
                    }
                    j = j + 1
                end
            end

            if saveJson then
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
                        local cel = entry.cel
                        local fileName = entry.fileName
                        local xOrigin = entry.xOrigin
                        local yOrigin = entry.yOrigin
                        local width = entry.width
                        local height = entry.height

                        -- Unpack cel.
                        local frameNumber = cel.frameNumber
                        local duration = trunc(cel.frame.duration * 1000)
                        local celOpacity = cel.opacity
                        local celData = cel.data
                        if celData == nil or #celData < 1 then
                            celData = missingUserData
                        end

                        if useCenter then
                            xOrigin = xOrigin + width // 2
                            yOrigin = yOrigin + height // 2
                        end

                        celStrArr[i] = strfmt(
                            frameFormat,
                            frameNumber, fileName, duration,
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
                local jsonString = string.format(
                    "{\"fileDir\":\"%s\",\"fileExt\":\"%s\",\"layers\":[",
                    filePath, fileExt)
                    .. concat(lyrStrArr, ",")
                    .. "]}"

                local jsonFilepath = filePrefix
                if #fileTitle < 1 then
                    jsonFilepath = filePath .. pathSep .. "manifest"
                end
                jsonFilepath = jsonFilepath .. ".json"
                local file = io.open(jsonFilepath, "w")
                file:write(jsonString)
                file:close()
            end

            -- AseUtilities.changePixelFormat(oldMode)
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