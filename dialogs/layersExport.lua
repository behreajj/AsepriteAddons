dofile("../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local frames = { "CEL", "SPRITE" }
local origins = { "CENTER", "CORNER" }

local defaults = {
    target = "ALL",
    frame = "CEL",
    padding = 2,
    saveJson = false,
    origin = "CORNER",
    pullFocus = false
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

            -- Unpack arguments.
            local args = dlg.data
            local target = args.target or defaults.target
            local frame = args.frame or defaults.frame
            local padding = args.padding or defaults.padding
            local filename = args.filename
            local saveJson = args.saveJson
            local origin = args.origin or defaults.origin

            -- Cache methods used in loops.
            local trunc = math.tointeger
            local strfmt = string.format
            local strgsub = string.gsub
            local isVisible = AseUtilities.layerIsVisible
            local trimAlpha = AseUtilities.trimImageAlpha

            local filePath = app.fs.filePath(filename)
            filePath = strgsub(filePath, "\\", "\\\\")

            local fileTitle = app.fs.fileTitle(filename)
            local fileExt = app.fs.fileExtension(filename)
            fileTitle = strgsub(fileTitle, "%s+", "")
            local pathSep = app.fs.pathSeparator
            pathSep = strgsub(pathSep, "\\", "\\\\")
            local filePrefix = filePath
                .. pathSep
                .. fileTitle

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
            local widthSprite = activeSprite.width
            local heightSprite = activeSprite.height
            local pad2 = padding + padding
            local wPaddedSprite = widthSprite + pad2
            local hPaddedSprite = heightSprite + pad2
            local padOffset = Point(padding, padding)

            local celsLen = #cels
            local jsonEntries = {}
            local j = 1
            for i = 1, celsLen, 1 do
                local cel = cels[i]
                local layer = cel.layer
                local layerOpacity = layer.opacity
                local isVis = isVisible(layer, activeSprite)
                if isVis and (not layer.isReference)
                    and layerOpacity > 0 then

                    local srcImage = cel.image
                    local trgImage = nil
                    local xOrigin = 0
                    local yOrigin = 0
                    if useSpriteFrame then
                        local celPos = cel.position
                        trgImage = Image(wPaddedSprite, hPaddedSprite)
                        trgImage:drawImage(srcImage, padOffset + celPos)
                    else
                        trgImage, xOrigin, yOrigin = trimAlpha(srcImage, padding)
                        local celPos = cel.position
                        xOrigin = xOrigin + celPos.x
                        yOrigin = yOrigin + celPos.y
                    end

                    -- TODO: Test this aspect of the script.
                    -- Maybe place layer and cel opacity in meta data instead
                    -- of baking.
                    local celOpacity = cel.opacity
                    if celOpacity < 0xff or layerOpacity < 0xff then
                        local celLyrAlpha = (celOpacity * layerOpacity) // 0xff
                        local pxlItr = trgImage:pixels()
                        for elm in pxlItr do
                            local srcHex = elm()
                            local srcAlpha = srcHex >> 0x18 & 0xff
                            local cmpAlpha = (celLyrAlpha * srcAlpha) // 0xff
                            if cmpAlpha > 0 then
                                elm((cmpAlpha << 0x18) | (srcHex & 0x00ffffff))
                            else
                                elm(0x0)
                            end
                        end
                    end

                    local layerName = layer.name
                    layerName = strgsub(layerName, "%s+", "")
                    local frameNumber = cel.frameNumber
                    local fileName = strfmt(
                        "%s%s_%03d.%s",
                        filePrefix, layerName, frameNumber, fileExt)
                    trgImage:saveAs(fileName)

                    jsonEntries[j] = {
                        fileName = fileName,
                        cel = cel,
                        layer = layer,
                        xOrigin = xOrigin,
                        yOrigin = yOrigin,
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
                        table.insert(entriesByLayer[stackIndex], entry)
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
                        local celData = cel.data
                        if celData == nil or #celData < 1 then
                            celData = "\"\""
                        end

                        if useCenter then
                            xOrigin = xOrigin + width // 2
                            yOrigin = yOrigin + height // 2
                        end

                        celStrArr[i] = strfmt(
                            "{\"filePath\":\"%s\",\"frameNumber\":%d,\"duration\":%d,\"position\":{\"x\":%d,\"y\":%d},\"dimension\":{\"x\":%d,\"y\":%d},\"data\":%s}",
                            fileName, frameNumber, duration, xOrigin, yOrigin, width, height, celData)
                    end

                    -- Unpack layer.
                    local layer = celsArr[1].layer
                    local layerName = layer.name
                    local layerData = layer.data
                    if layerData == nil or #layerData < 1 then
                        layerData = "\"\""
                    end

                    local layerPrefix = strfmt(
                        "{\"name\":\"%s\",\"stackIndex\":%d,\"data\":%s,\"frames\":[",
                        layerName, stackIndex, layerData)
                    local layerStr = layerPrefix .. table.concat(celStrArr, ",") .. "]}"
                    table.insert(lyrStrArr, layerStr)
                end
                local jsonString = "{\"layers\":[" .. table.concat(lyrStrArr, ",") .. "]}"

                local jsonFilepath = filePrefix
                if #fileTitle < 1 then
                    jsonFilepath = filePath .. pathSep .. "manifest"
                end
                jsonFilepath = jsonFilepath .. ".json"
                local file = io.open(jsonFilepath, "w")
                file:write(jsonString)
                file:close()
            end

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            AseUtilities.changePixelFormat(oldMode)
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