dofile("../../support/aseutilities.lua")

local frameTargetOptions = { "ALL", "RANGE", "TAGS" }

local defaults = {
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "1,4,5-10",
    padding = 2,
    padColor = Color { r = 0, g = 0, b = 0, a = 0 },
    scale = 1,
    prApply = false,
    usePot = false,
    useSheet = false,
    batchSheets = false,
    border = 2,
    borderColor = Color { r = 0, g = 0, b = 0, a = 0 },
    saveJson = false
}

local function flattenFrameToImage(sprite, frIdx, alphaIdx)
    local flat = Image(sprite.spec)
    local frameObj = sprite.frames[frIdx or 1]
    local duration = frameObj.duration
    flat:drawSprite(sprite, frameObj)
    local trimmed, xd, yd = AseUtilities.trimImageAlpha(
        flat, 0, alphaIdx)
    return trimmed, xd, yd, duration
end

local function indexToPacket(
    sprite, frIdx, alphaIdx, wMax, hMax,
    padding, wScale, hScale)
    local trimmed, xd, yd, duration = flattenFrameToImage(
        sprite, frIdx, alphaIdx)

    local packet = {
        number = frIdx,
        duration = duration,
        image = trimmed,
        x = xd * wScale - padding,
        y = yd * hScale - padding
    }

    local wMaxNew = wMax
    local hMaxNew = hMax
    local wLocal = trimmed.width
    local hLocal = trimmed.height
    if wLocal > wMax then wMaxNew = wLocal end
    if hLocal > hMax then hMaxNew = hLocal end

    return packet, wMaxNew, hMaxNew
end

local function allIndicesToPackets(
    sprite, padding, wScale, hScale)

    local wMax = -2147483648
    local hMax = -2147483648
    local packets = {}
    local lenFrameObjs = #sprite.frames
    local alphaIndex = sprite.transparentColor
    local h = 0
    while h < lenFrameObjs do h = h + 1
        packets[h], wMax, hMax = indexToPacket(
            sprite, h, alphaIndex,
            wMax, hMax, padding, wScale, hScale)
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
    local i = 0
    while i < lenIdcsSet do i = i + 1
        local frameIndex = idcsArr[i]
        packets[i], wMaxNext, hMaxNext = indexToPacket(
            sprite, frameIndex, alphaIndex,
            wMaxNext, hMaxNext,
            padding, wScale, hScale)
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

    local j = 0
    while j < lenIdcsBatches do j = j + 1
        local idcsBatch = idcsBatches[j]
        local wMaxBatch = -2147483648
        local hMaxBatch = -2147483648
        local packetBatch = {}
        packetBatch, wMaxBatch, hMaxBatch = idcsArr1ToPacket(
            sprite, idcsBatch, wMaxBatch, hMaxBatch,
            padding, wScale, hScale)
        packetsBatched[j] = {
            wMax = wMaxBatch,
            hMax = hMaxBatch,
            batch = packetBatch
        }
    end
    return packetsBatched
end

local function scaleAndPadPacketImages(
    packets,
    useResize, wScale, hScale,
    usePadding, padding, usePadColor, padHex,
    colorMode, colorSpace, alphaIndex)

    local resize = AseUtilities.resizeImageNearest
    local pad2 = padding + padding
    local padOffset = Point(padding, padding)
    local lenPackets = #packets
    local k = 0
    while k < lenPackets do k = k + 1
        local packet = packets[k]
        local image = packet.image

        if useResize then
            image = resize(image,
                image.width * wScale,
                image.height * hScale)
        end

        if usePadding then
            local padSpec = ImageSpec {
                colorMode = colorMode,
                width = image.width + pad2,
                height = image.height + pad2,
                transparentColor = alphaIndex
            }
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
    filename, packets, wMax, hMax,
    spec, compPalette, useBrdr, border,
    useBrdrClr, brdrClr, padding, usePot)

    if (wMax < 1) or (hMax < 1) or (#filename < 1) then
        return false
    end

    local lenPackets = #packets
    local columns = math.ceil(math.sqrt(lenPackets))
    local rows = math.max(1, math.ceil(lenPackets / columns))
    local wComp = wMax * columns
    local hComp = hMax * rows

    -- Unpack source spec.
    local colorMode = spec.colorMode
    local alphaMask = spec.transparentColor
    local colorSpace = spec.colorSpace

    -- Create composite image.
    local compSpec = ImageSpec {
        width = wComp,
        height = hComp,
        colorMode = colorMode,
        transparentColor = alphaMask
    }
    compSpec.colorSpace = colorSpace
    local compImg = Image(compSpec)

    -- For centering the image.
    local xCellCenter = wMax // 2
    -- local yCellCenter = hMax // 2

    local k = 0
    while k < lenPackets do
        local x = (k % columns) * wMax
        local y = (k // columns) * hMax

        k = k + 1
        local packet = packets[k]
        local image = packet.image

        local wh = image.width // 2
        -- local hh = image.height // 2
        x = x + xCellCenter - wh
        -- y = y + yCellCenter - hh
        y = y + hMax - image.height

        compImg:drawImage(image, Point(x, y))
        packets[k].xSheet = x + border + padding
        packets[k].ySheet = y + border + padding
    end

    -- This might seem less efficient, but clearing
    -- to a border color before images are drawn leads
    -- to the border acting more as a background.
    if useBrdr then
        local border2 = border + border
        local borderOffset = Point(border, border)
        local borderHex = AseUtilities.aseColorToHex(
            brdrClr, spec.colorMode)
        local borderSpec = ImageSpec {
            width = wComp + border2,
            height = hComp + border2,
            colorMode = colorMode,
            transparentColor = alphaMask
        }
        borderSpec.colorSpace = colorSpace
        local bordered = Image(borderSpec)
        if useBrdrClr then
            bordered:clear(borderHex)
        end
        bordered:drawImage(compImg, borderOffset)
        compImg = bordered
    end

    -- Again, not efficient, but better to do this
    -- than to mess around with how border interacts
    -- with power of two.
    if usePot then
        compImg = AseUtilities.expandImageToPow2(
            compImg, colorMode, alphaMask,
            colorSpace, false)
    end

    compImg:saveAs {
        filename = filename,
        palette = compPalette
    }
    return true
end

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
            visible = useSheet and (isRange or isTags)
        }
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
    id = "usePot",
    label = "Power of 2:",
    selected = defaults.usePot
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
            visible = useSheet and (isRange or isTags)
        }
        dlg:modify { id = "border", visible = useSheet }
        dlg:modify {
            id = "borderColor",
            visible = useSheet and border > 0
        }
    end
}

dlg:check {
    id = "batchSheets",
    text = "Batch",
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
            visible = border > 0
        }
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

dlg:newrow { always = false }

dlg:check {
    id = "saveJson",
    label = "Save JSON:",
    selected = defaults.saveJson,
    onclick = function()
        local args = dlg.data
        local enabled = args.saveJson
        dlg:modify { id = "userDataWarning", visible = enabled }
    end
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
    id = "userDataWarning",
    label = "Note:",
    text = "User data not escaped.",
    visible = defaults.saveJson
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local spec = activeSprite.spec
        local colorSpace = spec.colorSpace
        local colorMode = spec.colorMode
        local alphaMask = spec.transparentColor

        local args = dlg.data
        local useSheet = args.useSheet
        local usePot = args.usePot

        if useSheet and colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported for sprite sheets."
            }
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

        local filename = args.filename --[[@as string]]
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
        local padColor = args.padColor or defaults.padColor --[[@as Color]]
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
            local rangeStr = args.rangeStr or defaults.rangeStr --[[@as string]]
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
                local idcsSet = AseUtilities.parseTagsUnique(tags)
                packetsUnbatched, wMaxUnbatch, hMaxUnbatch = idcsArr1ToPacket(
                    activeSprite, idcsSet,
                    wMaxUnbatch, hMaxUnbatch,
                    padding, wScale, hScale)
            end

        end

        if batchSheets then
            local lenPacketsBatched = #packetsBatched
            local i = 0
            while i < lenPacketsBatched do i = i + 1
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
        local border = 0

        if useSheet then
            border = args.border or defaults.border --[[@as integer]]
            local brdrClr = args.borderColor or defaults.borderColor
            local useBorder = border > 0
            local useBrdrClr = brdrClr.alpha > 0

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
                        useBorder, border,
                        useBrdrClr, brdrClr,
                        padding, usePot)
                    packetsBatched[i].filename = string.format(
                        "%s%03d", fileTitle, i - 1)
                end
            else
                saveSheet(
                    filename,
                    packetsUnbatched, wMaxUnbatch, hMaxUnbatch,
                    spec, compPalette,
                    useBorder, border,
                    useBrdrClr, brdrClr,
                    padding, usePot)
            end
        else
            for k = 1, #packetsUnbatched, 1 do
                local fileNameLong = string.format(
                    "%s%03d.%s",
                    filePrefix, k - 1, fileExt)
                packetsUnbatched[k].filename = string.format(
                    "%s%03d", fileTitle, k - 1)

                local packet = packetsUnbatched[k]
                local frameIndex = packet.number
                local image = packet.image

                -- AseUtilities.getPalette not used here because
                -- the frame object is not available.
                local palIndex = frameIndex
                if palIndex > lenPalettes then palIndex = 1 end
                local activePalette = spritePalettes[palIndex]

                if usePot then
                    image = AseUtilities.expandImageToPow2(
                        image, colorMode, alphaMask,
                        colorSpace, false)
                end

                image:saveAs {
                    filename = fileNameLong,
                    palette = activePalette
                }
            end
        end

        local saveJson = args.saveJson
        if saveJson then

            -- 1.3 beta has userData for sprites and tags.
            local missingUserData = "null"
            local spriteUserData = "\"data\":" .. missingUserData
            local version = app.version
            local is1_3 = (version.major >= 1)
                and (version.minor >= 3)
            if is1_3 then
                local rawUserData = activeSprite.data --[[@as string]]
                if rawUserData and #rawUserData > 0 then
                    spriteUserData = string.format(
                        "\"data\":%s", rawUserData)
                end
            end

            local packetsStr = ""
            local packetsFmt = ""
            local packetStrFmt = ""
            local batchFmt = ""
            local frameIndvFmt = ""
            if useSheet then
                if batchSheets then
                    packetsFmt = string.format(
                        "\"border\":%d,\"sheets\":",
                        border) .. "[%s]"
                else
                    packetsFmt = string.format(table.concat({
                        "\"fileName\":\"%s\"",
                        "\"border\":%d",
                        "\"cellSize\":{\"x\":%d,\"y\":%d}",
                        "\"sheet\":"
                    }, ','),
                        fileTitle, border,
                        wMaxUnbatch, hMaxUnbatch) .. "[%s]"
                end

                batchFmt = table.concat({
                    "{\"fileName\":\"%s\"",
                    "\"cellSize\":{\"x\":%d,\"y\":%d}",
                    "\"frames\":[%s]}"
                }, ',')

                frameIndvFmt = table.concat({
                    "{\"duration\":%d",
                    "\"number\":%d",
                    "\"posOrig\":{\"x\":%d,\"y\":%d}",
                    "\"posSheet\":{\"x\":%d,\"y\":%d}",
                    "\"size\":{\"x\":%d,\"y\":%d}}"
                }, ',')
            else
                packetsFmt = "\"frames\":[%s]"

                packetStrFmt = table.concat({
                    "{\"fileName\":\"%s\"",
                    "\"duration\":%d",
                    "\"number\":%d",
                    "\"position\":{\"x\":%d,\"y\":%d}",
                    "\"size\":{\"x\":%d,\"y\":%d}}"
                }, ',')
            end

            local versionStrFmt = table.concat({
                "{\"version\":{\"major\":%d",
                "\"minor\":%d",
                "\"patch\":%d",
                "\"prerelease\":\"%s\"",
                "\"prNo\":%d}",
            }, ",")
            local versionStr = string.format(
                versionStrFmt,
                version.major, version.minor, version.patch,
                version.prereleaseLabel, version.prereleaseNumber)

            local jsonStrFmt = table.concat({
                versionStr,
                "\"fileDir\":\"%s\"",
                "\"fileExt\":\"%s\"",
                spriteUserData,
                "\"padding\":%d",
                "\"scale\":{\"x\":%d,\"y\":%d}",
                packetsFmt,
                "\"tags\":[%s]}"
            }, ',')

            local tagStrFmt = table.concat({
                "{\"name\":\"%s\"",
                "\"aniDir\":\"%s\"",
                "\"data\":%s",
                "\"fromFrame\":%d",
                "\"toFrame\":%d",
                "\"repeats\":%d}"
            }, ',')

            local tagsStr = ""
            if lenTags > 0 then
                local tagStrArr = {}
                local i = 0
                while i < lenTags do
                    i = i + 1
                    local tag = tags[i]

                    local aniDir = tag.aniDir
                    local aniDirStr = "FORWARD"
                    if aniDir == AniDir.REVERSE then
                        aniDirStr = "REVERSE"
                    elseif aniDir == AniDir.PING_PONG then
                        aniDirStr = "PING_PONG"
                    elseif aniDir == 3 then
                        aniDirStr = "PING_PONG_REVERSE"
                    end

                    local repeats = 0
                    local tagUserData = missingUserData
                    if is1_3 then
                        -- TODO: This causes problems for 1.3beta21.
                        -- repeats = tag.repeats
                        local rawUserData = tag.data --[[@as string]]
                        if rawUserData and #rawUserData > 0 then
                            tagUserData = rawUserData
                        end
                    end

                    local tagStr = string.format(
                        tagStrFmt, tag.name, aniDirStr,
                        tagUserData,
                        tag.fromFrame.frameNumber - 1,
                        tag.toFrame.frameNumber - 1,
                        repeats)
                    tagStrArr[i] = tagStr
                end
                tagsStr = table.concat(tagStrArr, ',')
            end

            if useSheet then
                local packetStrArr = {}

                if batchSheets then
                    local lenPacketsBatched = #packetsBatched
                    local i = 0
                    while i < lenPacketsBatched do
                        i = i + 1
                        local packet1 = packetsBatched[i]
                        local batch = packet1.batch
                        local lenBatch = #batch

                        local innerStrArr = {}
                        local j = 0
                        while j < lenBatch do
                            j = j + 1
                            local packet2 = batch[j]
                            local image = packet2.image
                            local innerStr = string.format(
                                frameIndvFmt,
                                math.floor(packet2.duration * 1000),
                                packet2.number - 1,
                                packet2.x, packet2.y,
                                packet2.xSheet, packet2.ySheet,
                                image.width, image.height)
                            innerStrArr[j] = innerStr
                        end
                        local innerStr = table.concat(innerStrArr, ",")

                        local packetStr = string.format(
                            batchFmt,
                            packet1.filename,
                            packet1.wMax, packet1.hMax,
                            innerStr)
                        packetStrArr[i] = packetStr
                    end
                    packetsStr = table.concat(packetStrArr, ',')
                else
                    -- TODO: Image size includes padding in its size and in
                    -- its posSheet, e.g. 256x256 becomes 260x260.

                    local lenPacketsUnbatched = #packetsUnbatched
                    local i = 0
                    while i < lenPacketsUnbatched do i = i + 1
                        local packet = packetsUnbatched[i]
                        local image = packet.image
                        local packetStr = string.format(
                            frameIndvFmt,
                            math.floor(packet.duration * 1000),
                            packet.number - 1,
                            packet.x, packet.y,
                            packet.xSheet, packet.ySheet,
                            image.width, image.height)
                        packetStrArr[i] = packetStr
                    end

                    packetsStr = table.concat(packetStrArr, ',')
                end

            else

                local packetStrArr = {}
                local lenPacketsUnbatched = #packetsUnbatched
                local k = 0
                while k < lenPacketsUnbatched do k = k + 1
                    local packet = packetsUnbatched[k]
                    local image = packet.image
                    local packetStr = string.format(
                        packetStrFmt,
                        packet.filename,
                        math.floor(packet.duration * 1000),
                        packet.number - 1,
                        packet.x, packet.y,
                        image.width, image.height)
                    packetStrArr[k] = packetStr
                end
                packetsStr = table.concat(packetStrArr, ',')

            end

            local jsonString = string.format(
                jsonStrFmt,
                filePath, fileExt,
                padding, wScale, hScale,
                packetsStr, tagsStr)

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