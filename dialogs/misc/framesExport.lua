dofile("../../support/aseutilities.lua")

local function flattenFrameToImage(sprite, frameIdx, alphaIdx)
    local flat = Image(sprite.spec)
    flat:drawSprite(sprite, sprite.frames[frameIdx or 1])
    return AseUtilities.trimImageAlpha(flat, 0, alphaIdx)
end

local function indexToPacket(sprite, index, amsk, wMax, hMax)
    local trimmed, xDelta, yDelta = flattenFrameToImage(
        sprite, index, amsk)
    local wLocal = trimmed.width
    local hLocal = trimmed.height

    local packet = {
        frameIndex = index,
        image = trimmed,
        xDelta = xDelta,
        yDelta = yDelta }

    local wMaxNew = wMax
    local hMaxNew = hMax
    if wLocal > wMax then wMaxNew = wLocal end
    if hLocal > hMax then hMaxNew = hLocal end

    return packet,
        wMaxNew,
        hMaxNew
end

local function allIndicesToPackets(
    sprite,
    padding, wScale, hScale)

    local wMax = -2147483648
    local hMax = -2147483648
    local packets = {}
    local lenFrameObjs = #sprite.frames
    local alphaIndex = sprite.transparentColor
    for i = 1, lenFrameObjs, 1 do
        packets[i], wMax, hMax = indexToPacket(
            sprite, i, alphaIndex,
            wMax, hMax)
    end

    local pad2 = padding + padding
    wMax = wScale * wMax + pad2
    hMax = hScale * hMax + pad2

    return packets, wMax, hMax
end

local function idcsArr1ToPacket(
        sprite, idcsArr,
        wMaxPrev, hMaxPrev,
        padding, wScale, hScale)

    local lenIdcsSet = #idcsArr
    local wMaxNext = wMaxPrev
    local hMaxNext = hMaxPrev
    local packets = {}
    local alphaIndex = sprite.transparentColor
    for k = 1, lenIdcsSet, 1 do
        local frameIndex = idcsArr[k]
        packets[k], wMaxNext, hMaxNext = indexToPacket(
            sprite, frameIndex, alphaIndex,
            wMaxNext, hMaxNext)
    end

    local pad2 = padding + padding
    wMaxNext = wScale * wMaxNext + pad2
    hMaxNext = hScale * hMaxNext + pad2

    return packets, wMaxNext, hMaxNext
end

local function idcsArr2ToPackets(
    sprite, idcsBatches,
    padding, wScale, hScale)
    local lenIdcsBatches = #idcsBatches
    local packetsBatched = {}
    for k = 1, lenIdcsBatches, 1 do
        local idcsBatch = idcsBatches[k]
        local wMaxBatch = -2147483648
        local hMaxBatch = -2147483648
        local packetBatch = {}
        packetBatch, wMaxBatch, hMaxBatch = idcsArr1ToPacket(
            sprite, idcsBatch, wMaxBatch, hMaxBatch,
            padding, wScale, hScale)

        packetsBatched[k] = {
            wMax = wMaxBatch,
            hMax = hMaxBatch,
            batch = packetBatch }
    end
    return packetsBatched
end

local function scaleAndPadPacketImages(
    packets,
    useResize, wScale, hScale,
    usePadding, padding, usePadColor, padHex,
    colorMode, colorSpace, alphaIndex)

    local pad2 = padding + padding
    local padOffset = Point(padding, padding)
    local lenPackets = #packets
    for k = 1, lenPackets, 1 do
        local packet = packets[k]
        local image = packet.image

        if useResize then
            image:resize(
                image.width * wScale,
                image.height * hScale)
        end

        if usePadding then
            local padSpec = ImageSpec {
                colorMode = colorMode,
                width = image.width + pad2,
                height = image.height + pad2,
                transparentColor = alphaIndex }
            padSpec.colorSpace = colorSpace
            local padded = Image(padSpec)
            if usePadColor then
                padded:clear(padHex)
            end
            padded:drawImage(image, padOffset)
            image = padded
        end

        packets[k].image = image
    end
end

local function saveSheet(
    filename,
    packets, wMax, hMax, spec, compPalette,
    useBorder, border, useBorderColor, borderColor)

    if wMax < 1 or hMax < 1 or #filename < 1 then
        return
    end

    -- Composite sheet from all images.
    local lenPackets = #packets
    local columns = math.ceil(math.sqrt(lenPackets))
    local rows = math.max(1, math.ceil(lenPackets / columns))

    -- Center the image in the cell.
    local xCellCenter = wMax // 2
    local yCellCenter = hMax // 2

    local compSpec = ImageSpec {
        width = wMax * columns,
        height = hMax * rows,
        colorMode = spec.colorMode,
        transparentColor = spec.transparentColor }
    compSpec.colorSpace = spec.colorSpace
    local comp = Image(compSpec)
    for k = 1, lenPackets, 1 do
        local packet = packets[k]
        local image = packet.image

        local i = (k - 1) // columns
        local j = (k - 1) % columns
        local x = j * wMax
        local y = i * hMax

        local wh = image.width // 2
        local hh = image.height // 2
        comp:drawImage(image, Point(
            x + xCellCenter - wh,
            y + yCellCenter - hh))
    end

    -- Handle border.
    local border2 = border + border
    local borderOffset = Point(border, border)
    local borderHex = AseUtilities.aseColorToHex(
        borderColor, spec.colorMode)

    if useBorder then
        local borderSpec = ImageSpec {
            width = comp.width + border2,
            height = comp.height + border2,
            colorMode = spec.colorMode,
            transparentColor = spec.transparentColor }
        borderSpec.colorSpace = spec.colorSpace
        local bordered = Image(borderSpec)
        if useBorderColor then
            bordered:clear(borderHex)
        end
        bordered:drawImage(comp, borderOffset)
        comp = bordered
    end

    comp:saveAs {
        filename = filename,
        palette = compPalette }
end

local frameTargetOptions = { "ALL", "RANGE", "TAGS" }

local defaults = {
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "1,4,5-10",
    padding = 2,
    padColor = Color(0, 0, 0, 0),
    scale = 1,
    prApply = false,
    useSheet = false,
    batchSheets = false,
    border = 2,
    borderColor = Color(0, 0, 0, 0),
    -- saveJson = false,
    pullFocus = false
}

local dlg = Dialog { title = "Export Frames" }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local state = dlg.data.frameTarget
        local isRange = state == "RANGE"
        local isTags = state == "TAGS"
        local args = dlg.data
        local useSheet = args.useSheet

        dlg:modify { id = "rangeStr", visible = isRange }
        dlg:modify { id = "strExample", visible = false }

        dlg:modify {
            id = "batchSheets",
            visible = useSheet and (isRange or isTags) }
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
    id = "useSheet",
    label = "Sheet:",
    selected = defaults.useSheet,
    onclick = function()
        local args = dlg.data
        local useSheet = args.useSheet
        local border = args.border
        local state = args.frameTarget
        local isRange = state == "RANGE"
        local isTags = state == "TAGS"
        dlg:modify {
            id = "batchSheets",
            visible = useSheet and (isRange or isTags) }
        dlg:modify { id = "border", visible = useSheet }
        dlg:modify {
            id = "borderColor",
            visible = useSheet and border > 0 }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "batchSheets",
    label = "Batch:",
    selected = defaults.batchSheets,
    visible = defaults.useSheet
}

dlg:newrow { always = false }

dlg:slider {
    id = "border",
    label = "Border:",
    min = 0,
    max = 32,
    value = defaults.border,
    visible = defaults.useSheet
        and defaults.border > 0,
    onchange = function()
        local args = dlg.data
        local border = args.border
        dlg:modify {
            id = "borderColor",
            visible = border > 0 }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "borderColor",
    label = "Color:",
    color = defaults.borderColor,
    visible = defaults.useSheet
        and defaults.border > 0
}

-- dlg:newrow { always = false }

-- dlg:check {
--     id = "saveJson",
--     label = "Save JSON:",
--     selected = defaults.saveJson,
--     onclick = function()
--         local args = dlg.data
--         local enabled = args.saveJson
--         dlg:modify { id = "userDataWarning", visible = enabled }
--     end
-- }

dlg:newrow { always = false }

dlg:file {
    id = "filename",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS,
    save = true
}

-- dlg:newrow { always = false }

-- dlg:label {
--     id = "userDataWarning",
--     label = "Note:",
--     text = "User data not escaped.",
--     visible = defaults.saveJson
-- }

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local spec = activeSprite.spec
        local colorSpace = spec.colorSpace
        local colorMode = spec.colorMode

        local args = dlg.data
        local useSheet = args.useSheet

        if useSheet and colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported for sprite sheets.")
            return
        end

        local tags = activeSprite.tags
        local frameTarget = args.frameTarget or defaults.frameTarget

        local targetIsAll = frameTarget == "ALL"
        local targetIsRange = frameTarget == "RANGE"
        local targetIsTags = frameTarget == "TAGS"
        local batchSheets = useSheet
            and args.batchSheets
            and (targetIsRange or targetIsTags)

        local lenTags = #tags
        if lenTags < 1 and targetIsTags then
            targetIsAll = true
            targetIsTags = false
        end

        local filename = args.filename
        local fileExt = app.fs.fileExtension(filename)

        local filePath = app.fs.filePath(filename)
        filePath = string.gsub(filePath, "\\", "\\\\")

        local pathSep = app.fs.pathSeparator
        pathSep = string.gsub(pathSep, "\\", "\\\\")

        local fileTitle = app.fs.fileTitle(filename)
        fileTitle = Utilities.validateFilename(fileTitle)

        filePath = filePath .. pathSep
        local filePrefix = filePath .. fileTitle

        local wMaxUnbatch = -2147483648
        local hMaxUnbatch = -2147483648
        local alphaIndex = spec.transparentColor

        -- Determine how to pad the image in hexadecimal
        -- based on sprite color mode.
        local padding = args.padding or defaults.padding
        local padColor = args.padColor or defaults.padColor
        local usePadding = padding > 0
        local usePadColor = padColor.alpha > 0
        local padHex = AseUtilities.aseColorToHex(padColor, colorMode)

        -- Modify images according to scale and pixel aspect.
        local wScale = args.scale or defaults.scale
        local hScale = wScale
        local prApply = args.prApply

        if prApply then
            local pxRatio = activeSprite.pixelRatio
            local pxw = math.max(1, math.abs(pxRatio.width))
            local pxh = math.max(1, math.abs(pxRatio.height))
            wScale = wScale * pxw
            hScale = hScale * pxh
        end
        local useResize = wScale ~= 1 or hScale ~= 1

        local spriteFrameObjs = activeSprite.frames
        local lenFrameObjs = #spriteFrameObjs

        local packetsUnbatched = {}
        local packetsBatched = {}

        if targetIsAll then

            packetsUnbatched, wMaxUnbatch, hMaxUnbatch = allIndicesToPackets(
                activeSprite, padding, wScale, hScale)

        elseif targetIsRange then

            -- Check range string first.
            local rangeStr = args.rangeStr or defaults.rangeStr
            local nonEmptyStr = #rangeStr > 0
            if nonEmptyStr then
                if batchSheets then
                    local idcsBatches = Utilities.parseRangeStringOverlap(
                        rangeStr, lenFrameObjs)
                    packetsBatched = idcsArr2ToPackets(
                        activeSprite, idcsBatches,
                        padding, wScale, hScale)
                else
                    local idcsSet = Utilities.parseRangeStringUnique(
                        rangeStr, lenFrameObjs)
                    packetsUnbatched, wMaxUnbatch, hMaxUnbatch = idcsArr1ToPacket(
                        activeSprite, idcsSet,
                        wMaxUnbatch, hMaxUnbatch,
                        padding, wScale, hScale)
                end
            end

            -- Next, check app.range object.
            if (#packetsUnbatched < 1)
                and (#packetsBatched < 1) then

                local idcsSet = AseUtilities.parseRange(app.range)
                packetsUnbatched, wMaxUnbatch, hMaxUnbatch = idcsArr1ToPacket(
                    activeSprite, idcsSet,
                    wMaxUnbatch, hMaxUnbatch,
                    padding, wScale, hScale)

                if batchSheets then
                    packetsBatched[1] = {
                        wMax = wMaxUnbatch,
                        hMax = hMaxUnbatch,
                        batch = packetsUnbatched
                    }
                end
            end

            -- Last resort, use all frames.
            if (#packetsUnbatched < 1)
                and (#packetsBatched < 1) then

                packetsUnbatched, wMaxUnbatch, hMaxUnbatch = allIndicesToPackets(
                    activeSprite, padding, wScale, hScale)

                if batchSheets then
                    packetsBatched[1] = {
                        wMax = wMaxUnbatch,
                        hMax = hMaxUnbatch,
                        batch = packetsUnbatched
                    }
                end
            end

        elseif targetIsTags then

            -- Back up strategies aren't needed here, since
            -- number of tags has already been checked.
            if batchSheets then
                local idcsBatches = AseUtilities.parseTagsOverlap(tags)
                packetsBatched = idcsArr2ToPackets(
                    activeSprite, idcsBatches,
                    padding, wScale, hScale)
            else
                local idcsSet = Utilities.parseTagsUnique(tags)
                packetsUnbatched, wMaxUnbatch, hMaxUnbatch = idcsArr1ToPacket(
                    activeSprite, idcsSet,
                    wMaxUnbatch, hMaxUnbatch,
                    padding, wScale, hScale)
            end

        end

        if batchSheets then
            for i = 1, #packetsBatched, 1 do
                scaleAndPadPacketImages(
                    packetsBatched[i].batch,
                    useResize, wScale, hScale,
                    usePadding, padding, usePadColor, padHex,
                    colorMode, colorSpace, alphaIndex)
            end
        else
            scaleAndPadPacketImages(
                packetsUnbatched,
                useResize, wScale, hScale,
                usePadding, padding, usePadColor, padHex,
                colorMode, colorSpace, alphaIndex)
        end

        local spritePalettes = activeSprite.palettes
        local lenPalettes = #spritePalettes

        if useSheet then
            local border = args.border or defaults.border
            local borderColor = args.borderColor or defaults.borderColor
            local useBorder = border > 0
            local useBorderColor = borderColor.alpha > 0

            -- Create a palette from all sprite palettes.
            local compHexArr = AseUtilities.asePalettesToHexArr(
                spritePalettes)
            Utilities.prependMask(compHexArr)
            local lenCompHexArr = #compHexArr
            local compPalette = Palette(lenCompHexArr)
            for i = 1, lenCompHexArr, 1 do
                compPalette:setColor(
                    i - 1, AseUtilities.hexToAseColor(
                        compHexArr[i]))
            end

            if batchSheets then
                for i = 1, #packetsBatched, 1 do
                    local packet = packetsBatched[i]
                    local batchFilename = string.format(
                        "%s%03d.%s",
                        filePrefix, i - 1, fileExt)
                    saveSheet(
                        batchFilename,
                        packet.batch, packet.wMax, packet.hMax,
                        spec, compPalette,
                        useBorder, border, useBorderColor, borderColor)
                end
            else
                saveSheet(
                    filename,
                    packetsUnbatched, wMaxUnbatch, hMaxUnbatch,
                    spec, compPalette,
                    useBorder, border, useBorderColor, borderColor)
            end
        else
            for k = 1, #packetsUnbatched, 1 do
                local packet = packetsUnbatched[k]
                local frameIndex = packet.frameIndex
                local image = packet.image

                local palIndex = frameIndex
                if palIndex > lenPalettes then palIndex = 1 end
                local activePalette = spritePalettes[palIndex]

                local fileNameLong = string.format(
                    "%s%03d.%s",
                    filePrefix, k - 1, fileExt)
                image:saveAs {
                    filename = fileNameLong,
                    palette = activePalette }
            end
        end

        local saveJson = args.saveJson
        if saveJson then
            -- TODO: Implement.
            -- Whether or not you select your frames by tags should have
            -- no bearing on whether or not they're included in the JSON file.
        end

        dlg:close()
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