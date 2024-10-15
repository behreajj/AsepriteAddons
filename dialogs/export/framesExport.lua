dofile("../../support/aseutilities.lua")
dofile("../../support/jsonutilities.lua")

local frameTargetOptions <const> = {
    "ACTIVE",
    "ALL",
    "MANUAL",
    "RANGE",
    "TAG",
    "TAGS"
}
local cropTypes <const> = { "CROPPED", "SPRITE" }
local sheetTypes <const> = { "HORIZONTAL", "SQUARE", "VERTICAL" }

local defaults <const> = {
    -- Calculate total duration of selected frames and place in JSON?
    -- The reason why not is that if an animation is split to tags, then
    -- the start time is reset for every tag, not accumulated... And this
    -- information can be calculated by the importer from given data.
    -- https://community.aseprite.org/t/tag-total-time-in-json-export-meta-data/

    -- Option to put batches (sprite sheet off) into subfolders? If this is not
    -- implemented, then the batches option should only be available if
    -- useSheet is true.
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "4,6:9,13",
    cropType = "CROPPED",
    border = 0,
    padding = 0,
    scale = 1,
    useSheet = false,
    useBatches = false,
    sheetOrient = "SQUARE",
    usePixelAspect = true,
    toPow2 = false,
    potUniform = false,
    saveJson = false,
    boundsFormat = "TOP_LEFT"
}

local sheetFormat <const> = table.concat({
    "{\"fileName\":\"%s\"",
    "\"size\":%s",
    "\"sizeCell\":%s",
    "\"sizeGrid\":%s",
    "\"sections\":[%s]}"
}, ",")

---@param section table
---@param boundsFormat string
---@return string
local function sectionToJson(section, boundsFormat)
    return string.format(
        "{\"id\":%s, \"rect\":%s}",
        JsonUtilities.pointToJson(section.column, section.row),
        JsonUtilities.rectToJson(section.rect, boundsFormat))
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
        sectionsStrs[i] = sectionToJson(sections[i], boundsFormat)
    end

    return string.format(
        sheetFormat,
        sheet.fileName,
        JsonUtilities.pointToJson(sheet.width, sheet.height),
        JsonUtilities.pointToJson(sheet.wCell, sheet.hCell),
        JsonUtilities.pointToJson(sheet.columns, sheet.rows),
        table.concat(sectionsStrs, ","))
end

---Makes a batch file name from a packets array by
---finding the first and last frame index in the range.
---@param fileTitle string file title
---@param packets1 table[] packets 1D array
---@return string
local function makeBatchFileName(fileTitle, packets1)
    local first <const> = packets1[1].frame
    local last <const> = packets1[#packets1].frame
    local frIdx0 <const> = first.frameNumber
    local frIdxLen <const> = last.frameNumber
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
---@param sheetOrient "HORIZONTAL"|"VERTICAL"|"SQUARE" sheet orientation
---@return table
local function saveSheet(
    filename, packets1,
    wMax, hMax,
    spriteSpec, compPalette,
    margin, padding,
    usePow2, nonUniformDim, sheetOrient)
    local lenPackets1 <const> = #packets1
    local margin2 <const> = margin + margin

    local cols = 1
    local rows = 1
    local isHoriz <const> = sheetOrient == "HORIZONTAL"
    local isVert <const> = sheetOrient == "VERTICAL"
    if isHoriz then
        cols = lenPackets1
    elseif isVert then
        rows = lenPackets1
    else
        cols = math.max(1, math.ceil(math.sqrt(lenPackets1)))
        rows = math.max(1, math.ceil(lenPackets1 / cols))
    end

    local wSheet = margin2 + wMax * cols + padding * (cols - 1)
    local hSheet = margin2 + hMax * rows + padding * (rows - 1)

    if usePow2 then
        -- Horizontal and vertical sheets have performance issues when uniform
        -- power of 2 is used, e.g., 16384x16384 pixels.
        if nonUniformDim or isHoriz or isVert then
            wSheet = Utilities.nextPowerOf2(wSheet)
            hSheet = Utilities.nextPowerOf2(hSheet)
        else
            wSheet = Utilities.nextPowerOf2(math.max(wSheet, hSheet))
            hSheet = wSheet
        end

        -- There's one less padding per denominator,
        -- so experiment adding one padding to numerator.
        if not (isVert or isHoriz) then
            cols = math.max(1,
                (wSheet + padding - margin2)
                // (wMax + padding))
            rows = math.max(1,
                (hSheet + padding - margin2)
                // (hMax + padding))
        end
    end

    -- Create composite image.
    local sheetSpec <const> = AseUtilities.createSpec(
        wSheet, hSheet, spriteSpec.colorMode,
        spriteSpec.colorSpace, spriteSpec.transparentColor)
    local compImg <const> = Image(sheetSpec)
    local blendModeSrc <const> = BlendMode.SRC

    -- For centering the image.
    local xCellCenter <const> = wMax // 2
    local yCellCenter <const> = hMax // 2

    ---@type table[]
    local sectionPackets <const> = {}

    local k = 0
    while k < lenPackets1 do
        local row <const> = k // cols
        local column <const> = k % cols
        local x = margin + column * wMax
        local y = margin + row * hMax

        x = x + column * padding
        y = y + row * padding

        k = k + 1
        local packet <const> = packets1[k]
        local image <const> = packet.cel.image
        local wImage <const> = image.width
        local hImage <const> = image.height

        local wHalf <const> = wImage // 2
        local hHalf <const> = hImage // 2
        x = x + xCellCenter - wHalf
        y = y + yCellCenter - hHalf

        compImg:drawImage(image, Point(x, y), 255, blendModeSrc)

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
        columns = cols,
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

    -- These should reflect the unscaled, unpadded cel image in the original
    -- sprite, so no alterations should be made to them after cropping.
    local xtl = 0
    local ytl = 0
    local wImage = spriteSpec.width
    local hImage = spriteSpec.height
    local alphaIndex <const> = spriteSpec.transparentColor
    if useCrop then
        local tr <const>, xd <const>, yd <const> = AseUtilities.trimImageAlpha(
            flat, 0, alphaIndex, 8, 8)

        flat = tr
        xtl = xtl + xd
        ytl = ytl + yd
        wImage = flat.width
        hImage = flat.height
    end

    -- Do not omit empty images as in layer exports.
    -- If user wants an empty image, give it to them.

    if useResize then
        local resized <const> = AseUtilities.upscaleImageForExport(
            flat, wScale, hScale)
        flat = resized
    end

    local frObj <const> = spriteFrameObjs[frIdx]
    local framePacket <const> = {
        duration = frObj.duration,
        frameNumber = frIdx
    }

    local boundsPacket <const> = {
        x = xtl,
        y = ytl,
        width = wImage,
        height = hImage
    }

    local celPacket <const> = {
        bounds = boundsPacket,
        data = nil,
        fileName = "",
        frameNumber = frIdx,
        image = flat,
        layer = -1,
        opacity = 255,
        zIndex = 0,
        properties = {}
    }

    return {
        cel = celPacket,
        frame = framePacket
    }
end

local dlg <const> = Dialog { title = "Export Frames" }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.frameTarget --[[@as string]]
        local useSheet <const> = args.useSheet --[[@as boolean]]

        local isManual <const> = state == "MANUAL"
        local isRange <const> = state == "RANGE"
        local isTags <const> = state == "TAGS"
        local validBatching <const> = useSheet
            and (isTags or isRange or isManual)

        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
        dlg:modify { id = "sheetOrient", visible = useSheet }
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
    value = defaults.border,
    visible = defaults.useSheet
}

dlg:newrow { always = false }

dlg:check {
    id = "useSheet",
    label = "Use:",
    text = "&Sheet",
    selected = defaults.useSheet,
    visible = true,
    onclick = function()
        local args <const> = dlg.data
        local frameTarget <const> = args.frameTarget --[[@as string]]
        local useSheet <const> = args.useSheet --[[@as boolean]]
        local toPow2 <const> = args.toPow2 --[[@as boolean]]
        local sheetOrient <const> = args.sheetOrient --[[@as string]]
        local noUniform <const> = useSheet
            and (sheetOrient == "VERTICAL"
                or sheetOrient == "HORIZONTAL")

        local isManual <const> = frameTarget == "MANUAL"
        local isRange <const> = frameTarget == "RANGE"
        local isTags <const> = frameTarget == "TAGS"
        local state <const> = useSheet
            and (isTags or isRange or isManual)

        dlg:modify { id = "useBatches", visible = state }
        dlg:modify { id = "border", visible = useSheet }
        dlg:modify { id = "sheetOrient", visible = useSheet }
        dlg:modify { id = "potUniform", visible = toPow2 and (not noUniform) }
    end
}

dlg:check {
    id = "useBatches",
    text = "&Batch",
    selected = defaults.useBatches,
    visible = defaults.useSheet
        and (defaults.frameTarget == "TAGS"
            or defaults.frameTarget == "RANGE"
            or defaults.frameTarget == "MANUAL")
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sheetOrient",
    label = "Orient:",
    option = defaults.sheetOrient,
    options = sheetTypes,
    visible = defaults.useSheet,
    onchange = function()
        local args <const> = dlg.data
        local toPow2 <const> = args.toPow2 --[[@as boolean]]
        local useSheet <const> = args.useSheet --[[@as boolean]]
        local sheetOrient <const> = args.sheetOrient --[[@as string]]
        local noUniform <const> = useSheet
            and (sheetOrient == "VERTICAL"
                or sheetOrient == "HORIZONTAL")
        dlg:modify { id = "potUniform", visible = toPow2 and (not noUniform) }
    end
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
        local toPow2 <const> = args.toPow2 --[[@as boolean]]
        local useSheet <const> = args.useSheet --[[@as boolean]]
        local sheetOrient <const> = args.sheetOrient --[[@as string]]
        local noUniform <const> = useSheet
            and (sheetOrient == "VERTICAL"
                or sheetOrient == "HORIZONTAL")
        dlg:modify { id = "potUniform", visible = toPow2 and (not noUniform) }
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
    filetypes = AseUtilities.FILE_FORMATS_SAVE,
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
        local enabled <const> = args.saveJson --[[@as boolean]]
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
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack sprite.
        local spriteSpec <const> = activeSprite.spec
        local spriteColorMode <const> = spriteSpec.colorMode
        local spritePalettes <const> = activeSprite.palettes

        -- Unpack arguments.
        local args <const> = dlg.data
        local filename = args.filename --[[@as string]]
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]
        local cropType <const> = args.cropType
            or defaults.cropType --[[@as string]]
        local margin = args.border
            or defaults.border --[[@as integer]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local useSheet <const> = args.useSheet --[[@as boolean]]
        local useBatches = args.useBatches --[[@as boolean]]
        local sheetOrient = args.sheetOrient
            or defaults.sheetOrient --[[@as string]]
        local usePixelAspect <const> = args.usePixelAspect --[[@as boolean]]
        local usePow2 <const> = args.toPow2 --[[@as boolean]]
        local potUniform <const> = args.potUniform --[[@as boolean]]
        local saveJson <const> = args.saveJson --[[@as boolean]]
        local boundsFormat <const> = args.boundsFormat
            or defaults.boundsFormat --[[@as string]]

        -- Validate file name.
        local fileExt = app.fs.fileExtension(filename)
        if string.lower(fileExt) == "json" then
            fileExt = app.preferences.export_file.image_default_extension --[[@as string]]
            filename = string.sub(filename, 1, -5) .. fileExt
        end

        local filePath = app.fs.filePath(filename)
        if filePath == nil or #filePath < 1 then
            app.alert { title = "Error", text = "Empty file path." }
            return
        end
        filePath = string.gsub(filePath, "\\", "\\\\")

        -- .qoi and .webp file extensions do not allow indexed color mode and
        --  Aseprite doesn't handle this limitation gracefully.
        --
        -- .tga files are not properly imported into Blender. GIMP converts
        -- them from indexed to RGB on import and export doesn't support
        -- translucency. Unity does not import with transparency. See
        -- https://github.com/aseprite/aseprite/issues/3982
        if spriteColorMode == ColorMode.INDEXED then
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "webp"
                or lcFileExt == "jpg"
                or lcFileExt == "jpeg"
                or lcFileExt == "qoi"
                or lcFileExt == "tga" then
                app.alert {
                    title = "Error",
                    text = {
                        "Indexed color not supported for",
                        "jpeg, jpg, qoi, tga or webp."
                    }
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
            local lcFileExt <const> = string.lower(fileExt)
            if lcFileExt == "bmp"
                or lcFileExt == "qoi"
                or lcFileExt == "webp" then
                app.alert {
                    title = "Error",
                    text = "Grayscale not supported for bmp, qoi or webp."
                }
                return
            end
        end

        -- TODO: Replace these usages with app.fs.joinPath
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

        -- Process other variables.
        local useCrop <const> = cropType == "CROPPED"
        local nonUniformDim <const> = not potUniform
        useBatches = useBatches
            and useSheet
            and (frameTarget == "TAGS"
                or frameTarget == "RANGE"
                or frameTarget == "MANUAL")
        local usePadding <const> = padding > 0
        if not useSheet then margin = 0 end

        -- Cache methods used in loops.
        local strfmt <const> = string.format

        -- Get frames.
        local tags <const> = activeSprite.tags
        local frIdcs2 <const> = AseUtilities.getFrames(
            activeSprite, frameTarget,
            useBatches, rangeStr, tags)
        local lenOuter <const> = #frIdcs2
        if lenOuter <= 0 then
            app.alert {
                title = "Error",
                text = "No frames were selected."
            }
            return
        end

        local spriteFrameObjs <const> = activeSprite.frames

        -- Track the global and local maximum dimensions.
        local wMaxGlobal = -2147483648
        local hMaxGlobal = -2147483648
        ---@type integer[]
        local wMaxesLocal <const> = {}
        ---@type integer[]
        local hMaxesLocal <const> = {}

        ---@type table<integer, table>
        local packetsUnique <const> = {}
        ---@type table[][]
        local packets2 <const> = {}
        local i = 0
        while i < lenOuter do
            i = i + 1
            local frIdcs1 <const> = frIdcs2[i]
            local lenInner <const> = #frIdcs1
            ---@type table[]
            local packets1 <const> = {}
            local wMaxLocal = -2147483648
            local hMaxLocal = -2147483648

            local j = 0
            while j < lenInner do
                j = j + 1
                local frIdx <const> = frIdcs1[j]
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
                local celBounds <const> = packet.cel.bounds
                local w <const> = celBounds.width
                local h <const> = celBounds.height
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
        local tagFileNames <const> = {}
        local lenTags <const> = #tags
        local exportByTags <const> = useBatches
            and frameTarget == "TAGS"
        if exportByTags then
            local validate <const> = Utilities.validateFilename
            local m = 0
            while m < lenTags do
                m = m + 1
                local tag <const> = tags[m]
                local fileNameShort <const> = strfmt(
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

        -- If a sprite did have a palette per frame, a comprehensive palette
        -- would have to be made, then each indexed image's indices would need
        -- to be offset, e.g. for an image on frame 2, the length of the
        -- palette from frame 1 would need to be added.
        local sheetPalette <const> = AseUtilities.getPalette(
            1, spritePalettes)
        ---@type table[]
        local sheetPackets <const> = {}
        if useBatches then
            if useSheet then
                local j = 0
                while j < lenOuter do
                    j = j + 1

                    local packets1 <const> = packets2[j]

                    local batchFileShort = tagFileNames[j]
                    if (not batchFileShort)
                        or #batchFileShort < 1 then
                        batchFileShort = makeBatchFileName(fileTitle, packets1)
                    end
                    local batchFileLong <const> = strfmt(
                        "%s%s.%s",
                        filePath, batchFileShort, fileExt)
                    -- print(batchFileLong)

                    local wMaxLocal <const> = wMaxesLocal[j]
                    local hMaxLocal <const> = hMaxesLocal[j]
                    local wCell <const> = wMaxLocal * wScale
                    local hCell <const> = hMaxLocal * hScale
                    local sheetPacket <const> = saveSheet(
                        batchFileLong, packets1,
                        wCell, hCell,
                        spriteSpec, sheetPalette,
                        margin, padding,
                        usePow2, nonUniformDim,
                        sheetOrient)
                    sheetPacket.fileName = batchFileShort
                    sheetPackets[j] = sheetPacket
                end -- End save sheet loop.
            else
                -- This is not a viable option for now, unless batched
                -- individual images in subfolders were implemented.
            end -- End use batches check.
        else
            local expandPot <const> = AseUtilities.expandImageToPow2
            local padImage <const> = AseUtilities.padImage

            ---@type table[]
            local packets1 <const> = packets2[1]
            local lenInner <const> = #packets1
            if useSheet then
                local wCell <const> = wMaxGlobal * wScale
                local hCell <const> = hMaxGlobal * hScale
                local sheetPacket <const> = saveSheet(
                    filename, packets1,
                    wCell, hCell,
                    spriteSpec, sheetPalette,
                    margin, padding,
                    usePow2, nonUniformDim,
                    sheetOrient)
                sheetPacket.fileName = fileTitle
                sheetPackets[1] = sheetPacket
            else
                local k = 0
                while k < lenInner do
                    k = k + 1

                    if usePadding then
                        local imgPadded <const> = padImage(
                            packets1[k].cel.image, padding)
                        packets1[k].cel.image = imgPadded
                    end

                    if usePow2 then
                        local imgPow2 <const> = expandPot(
                            packets1[k].cel.image, nonUniformDim)

                        -- Bounds are not updated here because
                        -- user may want to extract image from pot.
                        packets1[k].cel.image = imgPow2
                    end

                    local packet <const> = packets1[k]
                    local cel <const> = packet.cel
                    local frame <const> = packet.frame

                    local frIdx <const> = frame.frameNumber
                    local activePalette <const> = AseUtilities.getPalette(
                        frIdx, spritePalettes)

                    local fileNameShort <const> = strfmt(
                        "%s_%03d",
                        fileTitle, frIdx - 1)
                    local fileNameLong <const> = strfmt(
                        "%s%s.%s",
                        filePath, fileNameShort, fileExt)

                    local image <const> = cel.image
                    image:saveAs {
                        filename = fileNameLong,
                        palette = activePalette
                    }

                    -- This needs to be re-set because of the saveJson option.
                    packets1[k].cel.fileName = fileNameShort
                end -- End save image loop.
            end     -- End use sheet check.
        end         -- End use batches check.

        if saveJson then
            -- Cache Json methods.
            local celToJson <const> = JsonUtilities.celToJson
            local frameToJson <const> = JsonUtilities.frameToJson
            local tagToJson <const> = JsonUtilities.tagToJson

            ---@type table[]
            local pckUnqArr <const> = {}
            local lenPckUnqArr = 0
            for _, packet in pairs(packetsUnique) do
                lenPckUnqArr = lenPckUnqArr + 1
                pckUnqArr[lenPckUnqArr] = packet
            end
            table.sort(pckUnqArr, function(a, b)
                return a.frame.frameNumber < b.frame.frameNumber
            end)

            ---@type string[]
            local celStrs <const> = {}
            ---@type string[]
            local frameStrs <const> = {}
            local m = 0
            while m < lenPckUnqArr do
                m = m + 1
                local packet <const> = pckUnqArr[m]
                local cel <const> = packet.cel
                local frame <const> = packet.frame
                celStrs[m] = celToJson(
                    cel, cel.fileName, boundsFormat)
                frameStrs[m] = frameToJson(frame)
            end

            local k = 0
            ---@type string[]
            local tagStrs <const> = {}
            while k < lenTags do
                k = k + 1
                local tag <const> = tags[k]
                local fileName <const> = tagFileNames[k]
                tagStrs[k] = tagToJson(tag, fileName)
            end

            ---@type string[]
            local sheetStrArr <const> = {}
            if useSheet then
                local lenSheetPackets <const> = #sheetPackets
                local j = 0
                while j < lenSheetPackets do
                    j = j + 1
                    sheetStrArr[j] = sheetToJson(
                        sheetPackets[j], boundsFormat)
                end
            end

            -- Layers array included for the sake of uniformity.
            local jsonFormat <const> = table.concat({
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
            local jsonString <const> = string.format(
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

            local file <const>, err <const> = io.open(jsonFilepath, "w")
            if file then
                file:write(jsonString)
                file:close()
            end

            if err then
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

dlg:show {
    autoscrollbars = true,
    wait = false
}