dofile("../../support/aseutilities.lua")

local maskCriteria <const> = {
    "LIGHTNESS",
    "CHROMA",
    "HUE",
    "ALPHA",
    "SELECTION"
}

local sortCriteria <const> = {
    "INTEGER",
    "LIGHTNESS",
    "CHROMA",
    "HUE",
    "RED",
    "GREEN",
    "BLUE",
    "ALPHA"
}

local directions <const> = {
    "HORIZONTAL",
    "VERTICAL"
}

local defaults <const> = {
    frameCount = 8,
    fps = 24,
    maskCriterion = "LIGHTNESS",
    lbThresh = 25,
    ubThresh = 75,
    xRandom = 33,
    yRandom = 33,
    sortCriterion = "LIGHTNESS",
    direction = "VERTICAL"
}

local dlg <const> = Dialog { title = "Pixel Sort" }

dlg:slider {
    id = "frameCount",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frameCount
}

dlg:newrow { always = false }

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps
}

dlg:newrow { always = false }

dlg:combobox {
    id = "maskCriterion",
    label = "Mask:",
    option = defaults.maskCriterion,
    options = maskCriteria,
    onchange = function()
        local args <const> = dlg.data
        local maskCriterion <const> = args.maskCriterion --[[@as string]]
        local isNotSel <const> = maskCriterion ~= "SELECTION"
        dlg:modify { id = "lbThresh", visible = isNotSel }
        dlg:modify { id = "ubThresh", visible = isNotSel }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lbThresh",
    label = "Treshold:",
    min = 0,
    max = 100,
    value = defaults.lbThresh,
    visible = defaults.maskCriterion ~= "SELECTION"
}

dlg:slider {
    id = "ubThresh",
    min = 0,
    max = 100,
    value = defaults.ubThresh,
    visible = defaults.maskCriterion ~= "SELECTION"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "sortCriterion",
    label = "Sort:",
    option = defaults.sortCriterion,
    options = sortCriteria
}

dlg:newrow { always = false }

dlg:slider {
    id = "xRandom",
    label = "Variance:",
    min = 0,
    max = 100,
    value = defaults.xRandom
}

dlg:slider {
    id = "yRandom",
    min = 0,
    max = 100,
    value = defaults.yRandom
}

dlg:newrow { always = false }

dlg:combobox {
    id = "direction",
    label = "Direction:",
    option = defaults.direction,
    options = directions
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local site <const> = app.site
        local srcSprite <const> = site.sprite
        if not srcSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcSpriteSpec <const> = srcSprite.spec
        local srcColorMode <const> = srcSpriteSpec.colorMode

        if srcColorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcFrame <const> = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        -- Cache palette, preserve fore and background.
        AseUtilities.preserveForeBack()
        local hexArr <const> = AseUtilities.asePalettesToHexArr(
            srcSprite.palettes)

        -- Unpack arguments.
        local args <const> = dlg.data
        local frameCount <const> = args.frameCount
            or defaults.frameCount --[[@as integer]]
        local fps <const> = args.fps
            or defaults.fps --[[@as integer]]
        local maskCriterion <const> = args.maskCriterion
            or defaults.maskCriterion --[[@as string]]
        local lbThresh100 = args.lbThresh
            or defaults.lbThresh --[[@as integer]]
        local ubThresh100 = args.ubThresh
            or defaults.ubThresh --[[@as integer]]
        local sortCriterion <const> = args.sortCriterion
            or defaults.sortCriterion --[[@as string]]
        local xRandom100 <const> = args.xRandom
            or defaults.xRandom --[[@as integer]]
        local yRandom100 <const> = args.yRandom
            or defaults.yRandom --[[@as integer]]
        local direction <const> = args.direction
            or defaults.direction --[[@as string]]

        --Cache methods used in loops.
        local fromHex <const> = Clr.fromHex
        local sRgbToLch <const> = Clr.sRgbToSrLch
        local rng <const> = math.random
        local floor <const> = math.floor
        local tSort <const> = table.sort
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        -- Blit sprite to image, then trim image.
        local srcImg = Image(srcSpriteSpec)
        srcImg:drawSprite(srcSprite, srcFrame)
        local tlx = 0
        local tly = 0
        srcImg, tlx, tly = AseUtilities.trimImageAlpha(
            srcImg, 0, srcSpriteSpec.transparentColor, 8, 8)
        local srcPos <const> = Point(tlx, tly)
        local srcImgSpec <const> = srcImg.spec
        local wSrc <const> = srcImgSpec.width
        local hSrc <const> = srcImgSpec.height
        local srcItr <const> = srcImg:pixels()

        local lenSrcPxArr = 0
        ---@type integer[]
        local srcPxArr <const> = {}
        ---@type table<integer, boolean>
        local masked <const> = {}
        ---@type table<integer, table>
        local lchDict <const> = {}

        local colOrigAbs <const> = 0
        local colDestAbs <const> = wSrc - 1
        local rowOrigAbs <const> = 0
        local rowDestAbs <const> = hSrc - 1

        if maskCriterion == "SELECTION" then
            local sel <const>, _ <const> = AseUtilities.getSelection(srcSprite)
            for pixel in srcItr do
                lenSrcPxArr = lenSrcPxArr + 1
                local hex <const> = pixel()
                local mask <const> = sel:contains(
                    tlx + pixel.x,
                    tly + pixel.y)
                if not lchDict[hex] then
                    local srgb <const> = fromHex(hex)
                    local lch <const> = sRgbToLch(srgb)
                    lchDict[hex] = lch
                end
                masked[hex] = mask
                srcPxArr[lenSrcPxArr] = hex
            end

            -- This doesn't produce decent results, as pixels
            -- are confined to selection bounds, not the
            -- selection itself. Would have to make sure
            -- these are clamped to [0, image size - 1].
            -- local selBounds = sel.bounds
            -- colOrigAbs = selBounds.x - tlx
            -- colDestAbs = colOrigAbs + selBounds.width - 1
            -- rowOrigAbs = selBounds.y - tly
            -- rowDestAbs = rowOrigAbs + selBounds.height - 1
        else
            -- Validate threshold.
            if lbThresh100 == ubThresh100 then
                app.alert {
                    title = "Error",
                    text = "Threshold bounds are equal."
                }
                return
            end

            if lbThresh100 > ubThresh100 then
                lbThresh100, ubThresh100 = ubThresh100, lbThresh100
            end

            -- Default to masking by lightness.
            local lbThresh = lbThresh100 --[[@as number]]
            local ubThresh = ubThresh100 --[[@as number]]
            local maskFunc = function(lch, lb, ub)
                return lch.l >= lb and lch.l <= ub
            end

            if maskCriterion == "CHROMA" then
                local ratio <const> = Clr.SR_LCH_MAX_CHROMA / 100.0
                lbThresh = lbThresh100 * ratio
                ubThresh = ubThresh100 * ratio
                maskFunc = function(lch, lb, ub)
                    return lch.c >= lb and lch.c <= ub
                end
            elseif maskCriterion == "HUE" then
                lbThresh = lbThresh100 * 0.01
                ubThresh = ubThresh100 * 0.01
                maskFunc = function(lch, lb, ub)
                    if lch.c < 0.5 then return false end
                    return lch.h >= lb and lch.h <= ub
                end
            elseif maskCriterion == "ALPHA" then
                lbThresh = lbThresh100 * 0.01
                ubThresh = ubThresh100 * 0.01
                maskFunc = function(lch, lb, ub)
                    return lch.a >= lb and lch.a <= ub
                end
            end

            for pixel in srcItr do
                lenSrcPxArr = lenSrcPxArr + 1
                local hex <const> = pixel()
                local mask = false
                if masked[hex] ~= nil then
                    mask = masked[hex]
                else
                    local srgb <const> = fromHex(hex)
                    local lch <const> = sRgbToLch(srgb)
                    mask = maskFunc(lch, lbThresh, ubThresh)
                    lchDict[hex] = lch
                end
                masked[hex] = mask
                srcPxArr[lenSrcPxArr] = hex
            end
        end

        -- Default to sorting by integer.
        local sorter = nil
        if sortCriterion == "LIGHTNESS" then
            sorter = function(o, d)
                local left <const> = lchDict[o]
                local right <const> = lchDict[d]
                return left.l < right.l
            end
        elseif sortCriterion == "CHROMA" then
            sorter = function(o, d)
                local left <const> = lchDict[o]
                local right <const> = lchDict[d]
                return left.c < right.c
            end
        elseif sortCriterion == "HUE" then
            sorter = function(o, d)
                local left <const> = lchDict[o]
                local right <const> = lchDict[d]
                if left.c < 0.5 or right.c < 0.5 then
                    return left.l < right.l
                end
                return left.h < right.h
            end
        elseif sortCriterion == "RED" then
            sorter = function(o, d)
                return (o & 0xff) < (d & 0xff)
            end
        elseif sortCriterion == "GREEN" then
            sorter = function(o, d)
                return (o >> 0x08 & 0xff)
                    < (d >> 0x08 & 0xff)
            end
        elseif sortCriterion == "BLUE" then
            sorter = function(o, d)
                return (o >> 0x10 & 0xff)
                    < (d >> 0x10 & 0xff)
            end
        elseif sortCriterion == "ALPHA" then
            sorter = function(o, d)
                local left <const> = lchDict[o]
                local right <const> = lchDict[d]
                if left.a == right.a then
                    return left.l < right.l
                end
                return left.a < right.a
            end
        end

        local frToFac = 1.0
        if frameCount > 1 then
            frToFac = 1.0 / (frameCount - 1.0)
        end

        local dirIsVertical <const> = direction == "VERTICAL"
        ---@type integer[]
        local yRndOffsets <const> = {}
        ---@type integer[]
        local xRndOffsets <const> = {}
        ---@type integer[]
        local fRndOffsets <const> = {}

        local yOffMax = 0
        local yOffMin = 0
        if yRandom100 > 0 then
            local yRnd01 <const> = yRandom100 * 0.005
            local yRndScale <const> = 1 + rowDestAbs - rowOrigAbs
            yOffMax = math.floor(0.5 + yRndScale * yRnd01)
            yOffMin = -yOffMax
        end

        local xOffMax = 0
        local xOffMin = 0
        if xRandom100 > 0 then
            local xRnd01 <const> = xRandom100 * 0.005
            local xRndScale <const> = 1 + colDestAbs - colOrigAbs
            xOffMax = math.floor(0.5 + xRndScale * xRnd01)
            xOffMin = -xOffMax
        end

        local xSearchRange <const> = 1 + colDestAbs - colOrigAbs
        local ySearchRange <const> = 1 + rowDestAbs - rowOrigAbs

        if dirIsVertical then
            local h = 0
            while h < xSearchRange do
                h = h + 1
                yRndOffsets[h] = rng(yOffMin, yOffMax)
            end

            h = 0
            while h < frameCount do
                h = h + 1
                fRndOffsets[h] = rng(xOffMin, xOffMax)
            end
        else
            local i = 0
            while i < ySearchRange do
                i = i + 1
                xRndOffsets[i] = rng(xOffMin, xOffMax)
            end

            i = 0
            while i < frameCount do
                i = i + 1
                fRndOffsets[i] = rng(yOffMin, yOffMax)
            end
        end

        ---@type Image[]
        local frameImages <const> = {}
        if dirIsVertical then
            local colOrig <const> = colOrigAbs
            local colDest <const> = colDestAbs

            local rowOrigFirst <const> = rowOrigAbs
            local rowDestFirst = rowOrigAbs
            if frameCount < 2 then
                rowDestFirst = rowDestAbs
            end
            local rowOrigLast <const> = rowOrigAbs
            local rowDestLast <const> = rowDestAbs

            local frIdx = 0
            while frIdx < frameCount do
                -- Copy source array to a frame array.
                ---@type integer[]
                local frPxArr <const> = {}
                local k = 0
                while k < lenSrcPxArr do
                    k = k + 1
                    frPxArr[k] = srcPxArr[k]
                end

                -- Convert frame index to the number of rows to sort.
                local t <const> = frIdx * frToFac
                local u <const> = 1.0 - t

                local rowOrig <const> = floor(0.5 + u * rowOrigFirst
                    + t * rowOrigLast)
                local rowDest <const> = floor(0.5 + u * rowDestFirst
                    + t * rowDestLast)

                -- Offset the x column.
                frIdx = frIdx + 1
                local xRndOffset <const> = fRndOffsets[frIdx]

                local rndIdx = 0
                local x = colOrig - 1
                while x < colDest do
                    x = x + 1
                    local xOff <const> = (xRndOffset + x) % wSrc

                    rndIdx = rndIdx + 1
                    local yRndOffset <const> = yRndOffsets[rndIdx]

                    local lenFound = 0
                    ---@type integer[]
                    local indices <const> = {}
                    ---@type integer[]
                    local sorted <const> = {}

                    local y = rowDest + 1
                    while y > rowOrig do
                        y = y - 1
                        local yOff <const> = (yRndOffset + y) % hSrc
                        local index <const> = 1 + xOff + yOff * wSrc
                        local hex <const> = frPxArr[index]
                        if masked[hex] then
                            lenFound = lenFound + 1
                            indices[lenFound] = index
                            sorted[lenFound] = hex
                        end
                    end -- End of inner loop (y, rows).

                    tSort(sorted, sorter)
                    local j = 0
                    while j < lenFound do
                        j = j + 1
                        frPxArr[indices[j]] = sorted[j]
                    end
                end -- End of outer loop (x, cols).

                local frameImage <const> = Image(srcImgSpec)
                local frameItr <const> = frameImage:pixels()
                local j = 0
                for pixel in frameItr do
                    j = j + 1
                    pixel(frPxArr[j])
                end

                frameImages[frIdx] = frameImage
            end -- End of frame loop.
        else
            -- Default is to search the whole image.
            local rowOrig <const> = rowOrigAbs
            local rowDest <const> = rowDestAbs

            local colOrigFirst <const> = colOrigAbs
            local colDestFirst = colOrigAbs
            if frameCount < 2 then
                colDestFirst = colDestAbs
            end
            local colOrigLast <const> = colOrigAbs
            local colDestLast <const> = colDestAbs

            local frIdx = 0
            while frIdx < frameCount do
                -- Copy source array to a frame array.
                ---@type integer[]
                local frPxArr <const> = {}
                local k = 0
                while k < lenSrcPxArr do
                    k = k + 1
                    frPxArr[k] = srcPxArr[k]
                end

                -- Convert frame index to the number of columns to sort.
                local t <const> = frIdx * frToFac
                local u <const> = 1.0 - t
                local colOrig <const> = floor(0.5 + u * colOrigFirst
                    + t * colOrigLast)
                local colDest <const> = floor(0.5 + u * colDestFirst
                    + t * colDestLast)

                -- Offset the yRow.
                frIdx = frIdx + 1
                local yRndOffset <const> = fRndOffsets[frIdx]

                local rndIdx = 0
                local y = rowDest + 1
                while y > rowOrig do
                    y = y - 1
                    local yOff <const> = (yRndOffset + y) % hSrc
                    rndIdx = rndIdx + 1
                    local xRndOffset <const> = xRndOffsets[rndIdx]

                    -- For horizontal only, y * w can be cached.
                    local yw <const> = yOff * wSrc

                    local lenFound = 0
                    ---@type integer[]
                    local indices <const> = {}
                    ---@type integer[]
                    local sorted <const> = {}

                    local x = colOrig - 1
                    while x < colDest do
                        x = x + 1
                        local xOff <const> = (xRndOffset + x) % wSrc
                        local index <const> = 1 + xOff + yw
                        local hex <const> = frPxArr[index]
                        if masked[hex] then
                            lenFound = lenFound + 1
                            indices[lenFound] = index
                            sorted[lenFound] = hex
                        end
                    end -- End of inner loop (x, cols).

                    tSort(sorted, sorter)
                    local j = 0
                    while j < lenFound do
                        j = j + 1
                        frPxArr[indices[j]] = sorted[j]
                    end
                end -- End of outer loop (y, rows).

                local frameImage <const> = Image(srcImgSpec)
                local frameItr <const> = frameImage:pixels()
                local j = 0
                for pixel in frameItr do
                    j = j + 1
                    pixel(frPxArr[j])
                end
                frameImages[frIdx] = frameImage
            end -- End of frame loop.
        end

        local trgSprite <const> = AseUtilities.createSprite(
            srcSpriteSpec, "Pixel Sort")
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        -- Create frames
        app.transaction("New Frames", function()
            local duration = 1.0
            if fps > 1 then duration = 1.0 / fps end
            trgSprite.frames[1].duration = duration

            local i = 1
            while i < frameCount do
                i = i + 1
                local frameObj <const> = trgSprite:newEmptyFrame()
                frameObj.duration = duration
            end
        end)

        local trgLayer <const> = trgSprite.layers[1]
        trgLayer.name = string.format(
            "%s.%s",
            maskCriterion, sortCriterion)

        local j = 0
        local trgFrames <const> = trgSprite.frames
        while j < frameCount do
            j = j + 1
            local trgFrame <const> = trgFrames[j]
            local frameImage <const> = frameImages[j]

            transact(strfmt(
                    "Pixel Sort %d", trgFrame.frameNumber),
                function()
                    trgSprite:newCel(
                        trgLayer, trgFrame,
                        frameImage, srcPos)
                end)
        end

        app.command.FitScreen()
        app.refresh()
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