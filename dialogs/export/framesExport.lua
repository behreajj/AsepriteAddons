dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local frameTargetOptions = { "ACTIVE", "ALL", "MANUAL", "RANGE", "TAGS" }
local cropTypes = { "CROPPED", "SPRITE" }

local defaults = {
    -- Option to put batches (sprite sheet off)
    -- into subfolders? If this is not implemented,
    -- then the batches option should only be available
    -- if useSheet is true.
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "4,6-9,13",
    cropType = "CROPPED",
    border = 0,
    padding = 0,
    scale = 1,
    useBatches = false,
    useSheet = false,
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    saveJson = false,
    boundsFormat = "TOP_LEFT"
}

local sheetFormat = table.concat({
    "{\"fileName\":\"%s\"",
    "\"size\":%s",
    "\"sizeCell\":%s",
    "\"sizeGrid\":%s",
    "\"sections\":[%s]}"
}, ",")

local function sectionToJson(section, boundsFormat)
    return string.format(
        "{\"id\":%s, \"rect\":%s}",
        JsonUtilities.pointToJson(
            section.column, section.row),
        JsonUtilities.rectToJson(
            section.rect, boundsFormat))
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

    return string.format(
        sheetFormat,
        sheet.fileName,
        JsonUtilities.pointToJson(
            sheet.width,
            sheet.height),
        JsonUtilities.pointToJson(
            sheet.wCell,
            sheet.hCell),
        JsonUtilities.pointToJson(
            sheet.columns,
            sheet.rows),
        table.concat(sectionsStrs, ","))
end

---Makes a batch file name from a packets array by
---finding the first and last frame index in the range.
---@param fileTitle string file title
---@param packets1 table[] packets 1D array
---@return string
local function makeBatchFileName(fileTitle, packets1)
    local first = packets1[1].frame
    local last = packets1[#packets1].frame
    local frIdx0 = first.frameNumber
    local frIdxLen = last.frameNumber
    return string.format(
        "%s_%03d_%03d",
        fileTitle, frIdx0 - 1, frIdxLen - 1)
end

---Saves a sheet according to a one dimensional packet.
---Returns a table with image positions on a sheet.
---@param filename string file name
---@param packets1 table[] packets 1D array
---@param wMax integer maximum image width
---@param hMax integer maximum image height
---@param spriteSpec ImageSpec sprite spec
---@param compPalette Palette palette for all images
---@param margin integer margin amount
---@param padding integer padding amount
---@param usePow2 boolean promote to nearest pot
---@param nonUniformDim boolean non uniform npot
---@return table
local function saveSheet(
    filename, packets1,
    wMax, hMax,
    spriteSpec, compPalette,
    margin, padding,
    usePow2, nonUniformDim)
    local lenPackets1 = #packets1
    local columns = math.max(1,
        math.ceil(math.sqrt(lenPackets1)))
    local rows = math.max(1,
        math.ceil(lenPackets1 / columns))
    local margin2 = margin + margin
    local wSheet = margin2 + wMax * columns
        + padding * (columns - 1)
    local hSheet = margin2 + hMax * rows
        + padding * (rows - 1)

    if usePow2 then
        if nonUniformDim then
            wSheet = Utilities.nextPowerOf2(wSheet)
            hSheet = Utilities.nextPowerOf2(hSheet)
        else
            wSheet = Utilities.nextPowerOf2(
                math.max(wSheet, hSheet))
            hSheet = wSheet
        end

        -- This needs to account for large
        -- margins and padding.
        -- columns = math.max(1, wSheet // wMax)
        -- rows = math.max(1, hSheet // hMax)
    end

    -- Unpack source spec.
    local colorMode = spriteSpec.colorMode
    local alphaIndex = spriteSpec.transparentColor
    local colorSpace = spriteSpec.colorSpace

    -- Create composite image.
    local sheetSpec = ImageSpec {
        width = wSheet,
        height = hSheet,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    sheetSpec.colorSpace = colorSpace
    local compImg = Image(sheetSpec)

    -- For centering the image.
    local xCellCenter = wMax // 2
    local yCellCenter = hMax // 2

    ---@type table[]
    local sectionPackets = {}

    local k = 0
    while k < lenPackets1 do
        local row = k // columns
        local column = k % columns
        local x = margin + column * wMax
        local y = margin + row * hMax

        x = x + column * padding
        y = y + row * padding

        k = k + 1
        local packet = packets1[k]
        local image = packet.cel.image
        local wImage = image.width
        local hImage = image.height

        local wHalf = wImage // 2
        local hHalf = hImage // 2
        x = x + xCellCenter - wHalf
        y = y + yCellCenter - hHalf

        compImg:drawImage(image, Point(x, y))

        sectionPackets[k] = {
            row = row,
            column = column,
            rect = {
                x = x,
                y = y,
                width = wImage,
                height = hImage
            }
        }
    end

    compImg:saveAs {
        filename = filename,
        palette = compPalette
    }

    return {
        fileName = "",
        sections = sectionPackets,
        width = wSheet,
        height = hSheet,
        wCell = wMax,
        hCell = hMax,
        columns = columns,
        rows = rows
    }
end

---Generates a packet of data for each frame index.
---@param frIdx integer frame index
---@param activeSprite Sprite active sprite
---@param spriteFrameObjs Frame[] sprite frames
---@param spriteSpec ImageSpec sprite spec
---@param wScale integer width scalar
---@param hScale integer height scalar
---@param useCrop boolean use crop
---@param useResize boolean use resize
---@return table
local function genPacket(
    frIdx,
    activeSprite, spriteFrameObjs,
    spriteSpec, wScale, hScale,
    useCrop, useResize)
    local flat = Image(spriteSpec)
    flat:drawSprite(activeSprite, frIdx)

    -- These should reflect the unscaled, unpadded
    -- cel image in the original sprite, so no alterations
    -- should be made to them after cropping.
    local xtl = 0
    local ytl = 0
    local wImage = spriteSpec.width
    local hImage = spriteSpec.height
    local alphaIndex = spriteSpec.transparentColor
    if useCrop then
        local trimmed, xd, yd = AseUtilities.trimImageAlpha(
            flat, 0, alphaIndex, 8, 8)

        flat = trimmed
        xtl = xtl + xd
        ytl = ytl + yd
        wImage = flat.width
        hImage = flat.height
    end

    -- Do not omit empty images as in layer exports.
    -- If user wants an empty image, give it to them.

    if useResize then
        local wr = flat.width * wScale
        local hr = flat.height * hScale
        local resized = AseUtilities.resizeImageNearest(
            flat, wr, hr)

        flat = resized
    end

    local frObj = spriteFrameObjs[frIdx]
    local framePacket = {
        duration = frObj.duration,
        frameNumber = frIdx
    }

    local boundsPacket = {
        x = xtl,
        y = ytl,
        width = wImage,
        height = hImage
    }

    local celPacket = {
        bounds = boundsPacket,
        data = nil,
        fileName = "",
        frameNumber = frIdx,
        image = flat,
        layer = -1,
        opacity = 255
    }

    return {
        cel = celPacket,
        frame = framePacket
    }
end

local dlg = Dialog { title = "Export Frames" }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args = dlg.data
        local state = args.frameTarget
        local isManual = state == "MANUAL"
        local isTags = state == "TAGS"
        local useSheet = args.useSheet
        local validBatching = useSheet and (isTags or isManual)
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "useBatches", visible = validBatching }
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
    options = cropTypes,
    visible = true
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 32,
    value = defaults.border,
    visible = defaults.useSheet
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
    id = "useSheet",
    label = "Use:",
    text = "&Sheet",
    selected = defaults.useSheet,
    visible = true,
    onclick = function()
        local args = dlg.data
        local frameTarget = args.frameTarget
        local isManual = frameTarget == "MANUAL"
        local isTags = frameTarget == "TAGS"
        local useSheet = args.useSheet
        local state = useSheet
            and (isTags or isManual)
        dlg:modify { id = "useBatches", visible = state }
        dlg:modify { id = "border", visible = useSheet }
    end
}

dlg:check {
    id = "useBatches",
    -- label = "Use:",
    text = "&Batch",
    selected = defaults.useBatches,
    visible = defaults.useSheet
        and (defaults.frameTarget == "TAGS"
        or defaults.frameTarget == "MANUAL")
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
        local enabled = args.saveJson
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack sprite spec.
        local spriteSpec = activeSprite.spec
        local spriteColorMode = spriteSpec.colorMode
        local spriteColorSpace = spriteSpec.colorSpace
        local spriteAlphaIndex = spriteSpec.transparentColor
        local spritePalettes = activeSprite.palettes

        -- Unpack arguments.
        local args = dlg.data
        local filename = args.filename --[[@as string]]
        local frameTarget = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local cropType = args.cropType
            or defaults.cropType --[[@as string]]
        local margin = args.border
            or defaults.border --[[@as integer]]
        local padding = args.padding
            or defaults.padding --[[@as integer]]
        local scale = args.scale
            or defaults.scale --[[@as integer]]
        local useSheet = args.useSheet --[[@as boolean]]
        local useBatches = args.useBatches --[[@as boolean]]
        local usePixelAspect = args.usePixelAspect --[[@as boolean]]
        local usePow2 = args.toPow2 --[[@as boolean]]
        local potUniform = args.potUniform --[[@as boolean]]
        local saveJson = args.saveJson --[[@as boolean]]
        local boundsFormat = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

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

            if useSheet and #spritePalettes > 1 then
                app.alert {
                    title = "Error",
                    text = {
                        "Sheets are not supported for indexed",
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

        -- Process other variables.
        local useCrop = cropType == "CROPPED"
        local nonUniformDim = not potUniform
        useBatches = useBatches
            and useSheet
            and (frameTarget == "TAGS"
            or frameTarget == "MANUAL")
        local usePadding = padding > 0
        if not useSheet then margin = 0 end

        -- Cache methods used in loops.
        local strfmt = string.format

        -- Get frames.
        local tags = activeSprite.tags
        local frIdcs2 = AseUtilities.getFrames(
            activeSprite, frameTarget,
            useBatches, rangeStr, tags)
        local spriteFrameObjs = activeSprite.frames

        -- Track the global and local maximum dimensions.
        local wMaxGlobal = -2147483648
        local hMaxGlobal = -2147483648
        ---@type integer[]
        local wMaxesLocal = {}
        ---@type integer[]
        local hMaxesLocal = {}

        ---@type table<integer, table>
        ---The key is the frame index.
        ---The value is a flattened image.
        local packetsUnique = {}
        ---@type table[][]
        local packets2 = {}
        local lenOuter = #frIdcs2
        local i = 0
        while i < lenOuter do
            i = i + 1
            local frIdcs1 = frIdcs2[i]
            local lenInner = #frIdcs1
            local packets1 = {}
            local wMaxLocal = -2147483648
            local hMaxLocal = -2147483648

            local j = 0
            while j < lenInner do
                j = j + 1
                local frIdx = frIdcs1[j]
                local packet = packetsUnique[frIdx]
                if not packet then
                    packet = genPacket(
                        frIdx, activeSprite,
                        spriteFrameObjs, spriteSpec,
                        wScale, hScale,
                        useCrop, useResize)
                    packetsUnique[frIdx] = packet
                end
                packets1[j] = packet

                -- Update the maximum width and height.
                local celBounds = packet.cel.bounds
                local w = celBounds.width
                local h = celBounds.height
                if w > wMaxLocal then wMaxLocal = w end
                if h > hMaxLocal then hMaxLocal = h end
            end

            if wMaxLocal > wMaxGlobal then
                wMaxGlobal = wMaxLocal
            end
            if hMaxLocal > hMaxGlobal then
                hMaxGlobal = hMaxLocal
            end

            packets2[i] = packets1
            wMaxesLocal[i] = wMaxLocal
            hMaxesLocal[i] = hMaxLocal
        end

        -- If tags are not used in the export, then dummy
        -- data needs to be generated for them.
        ---@type string[]
        local tagFileNames = {}
        local lenTags = #tags
        local exportByTags = useBatches
            and frameTarget == "TAGS"
        if exportByTags then
            local validate = Utilities.validateFilename
            local m = 0
            while m < lenTags do
                m = m + 1
                local tag = tags[m]
                local fileNameShort = strfmt(
                    "%s_%s",
                    fileTitle,
                    validate(tag.name))
                tagFileNames[m] = fileNameShort
            end
        else
            local m = 0
            while m < lenTags do
                m = m + 1
                tagFileNames[m] = ""
            end
        end

        -- If a sprite did have a palette per frame,
        -- a comprehensive palette would have to be made,
        -- then each indexed image's indices would need
        -- to be offset, e.g. for an image on frame 2,
        -- the length of the palette from frame 1
        -- would need to be added.
        local sheetPalette = AseUtilities.getPalette(
            1, spritePalettes)
        local sheetPackets = {}
        if useBatches then
            if useSheet then
                local j = 0
                while j < lenOuter do
                    j = j + 1

                    local packets1 = packets2[j]

                    local batchFileShort = tagFileNames[j]
                    if (not batchFileShort)
                        or #batchFileShort < 1 then
                        batchFileShort = makeBatchFileName(fileTitle, packets1)
                    end
                    local batchFileLong = strfmt(
                        "%s%s.%s",
                        filePath, batchFileShort, fileExt)
                    -- print(batchFileLong)

                    local wMaxLocal = wMaxesLocal[j]
                    local hMaxLocal = hMaxesLocal[j]
                    local wCell = wMaxLocal * wScale
                    local hCell = hMaxLocal * hScale
                    local sheetPacket = saveSheet(
                        batchFileLong, packets1,
                        wCell, hCell,
                        spriteSpec, sheetPalette,
                        margin, padding,
                        usePow2, nonUniformDim)
                    sheetPacket.fileName = batchFileShort
                    sheetPackets[j] = sheetPacket
                end
            else
                -- This is not a viable option for now, unless batched
                -- individual images in subfolders were implemented.
            end
        else
            local expandPot = AseUtilities.expandImageToPow2
            local padImage = AseUtilities.padImage

            ---@type table[]
            local packets1 = packets2[1]
            local lenInner = #packets1
            if useSheet then
                local wCell = wMaxGlobal * wScale
                local hCell = hMaxGlobal * hScale
                local sheetPacket = saveSheet(
                    filename, packets1,
                    wCell, hCell,
                    spriteSpec, sheetPalette,
                    margin, padding,
                    usePow2, nonUniformDim)
                sheetPacket.fileName = fileTitle
                sheetPackets[1] = sheetPacket
            else
                local k = 0
                while k < lenInner do
                    k = k + 1

                    if usePadding then
                        local imgPadded = padImage(
                            packets1[k].cel.image, padding)
                        packets1[k].cel.image = imgPadded
                    end

                    if usePow2 then
                        local imgPow2 = expandPot(
                            packets1[k].cel.image,
                            spriteColorMode,
                            spriteAlphaIndex,
                            spriteColorSpace,
                            nonUniformDim)

                        -- Bounds are not updated here because
                        -- user may want to extract image from pot.
                        packets1[k].cel.image = imgPow2
                    end

                    local packet = packets1[k]
                    local cel = packet.cel
                    local frame = packet.frame

                    local frIdx = frame.frameNumber
                    local activePalette = AseUtilities.getPalette(
                        frIdx, spritePalettes)

                    local fileNameShort = strfmt(
                        "%s_%03d",
                        fileTitle, frIdx - 1)
                    local fileNameLong = strfmt(
                        "%s%s.%s",
                        filePath, fileNameShort, fileExt)

                    local image = cel.image
                    image:saveAs {
                        filename = fileNameLong,
                        palette = activePalette
                    }

                    -- This needs to be re-set because of
                    -- the saveJson option.
                    packets1[k].cel.fileName = fileNameShort
                end
            end
        end

        if saveJson then
            -- Cache Json methods.
            local celToJson = JsonUtilities.celToJson
            local frameToJson = JsonUtilities.frameToJson
            local tagToJson = JsonUtilities.tagToJson

            local lenFrameStrs = 0
            ---@type string[]
            local celStrs = {}
            ---@type string[]
            local frameStrs = {}
            for _, packet in pairs(packetsUnique) do
                local cel = packet.cel
                local frame = packet.frame
                lenFrameStrs = lenFrameStrs + 1
                celStrs[lenFrameStrs] = celToJson(
                    cel, cel.fileName, boundsFormat)
                frameStrs[lenFrameStrs] = frameToJson(frame)
            end

            local k = 0
            ---@type string[]
            local tagStrs = {}
            while k < lenTags do
                k = k + 1
                local tag = tags[k]
                local fileName = tagFileNames[k]
                tagStrs[k] = tagToJson(tag, fileName)
            end

            ---@type string[]
            local sheetStrArr = {}
            if useSheet then
                local lenSheetPackets = #sheetPackets
                local j = 0
                while j < lenSheetPackets do
                    j = j + 1
                    sheetStrArr[j] = sheetToJson(
                        sheetPackets[j], boundsFormat)
                end
            end

            -- Layers array included for the sake of uniformity.
            local jsonFormat = table.concat({
                "{\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                "\"border\":%d",
                "\"padding\":%d",
                "\"scale\":%d",
                "\"sheets\":[%s]",
                "\"cels\":[%s]",
                "\"frames\":[%s]",
                "\"layers\":[]",
                "\"sprite\":%s",
                "\"tags\":[%s]",
                "\"version\":%s}"
            }, ",")
            local jsonString = string.format(
                jsonFormat,
                filePath, fileExt,
                margin, padding, scale,
                table.concat(sheetStrArr, ","),
                table.concat(celStrs, ","),
                table.concat(frameStrs, ","),
                JsonUtilities.spriteToJson(activeSprite),
                table.concat(tagStrs, ","),
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