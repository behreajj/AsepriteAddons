dofile("../../support/aseutilities.lua")

local maskCriteria = {
    "LIGHTNESS",
    "CHROMA",
    "HUE",
    "ALPHA",
    "SELECTION"
}

local sortCriteria = {
    "INTEGER",
    "LIGHTNESS",
    "CHROMA",
    "HUE",
    "RED",
    "GREEN",
    "BLUE",
    "ALPHA"
}

local directions = {
    "HORIZONTAL",
    "VERTICAL"
}

-- local function wrap(v, lb, ub)
--     local r = ub - lb
--     if r ~= 0.0 then
--         return v - r * ((v - lb) // r)
--     end
--     return v
-- end

local defaults = {
    -- TODO: Support animations as source, like wave.
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

local dlg = Dialog { title = "Pixel Sort" }

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
        local args = dlg.data
        local isNotSel = args.maskCriterion ~= "SELECTION"
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
        local srcSprite = app.activeSprite
        if not srcSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcSpriteSpec = srcSprite.spec
        local srcColorMode = srcSpriteSpec.colorMode

        if srcColorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcFrame = app.activeFrame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        -- Cache palette, preserve fore and background.
        AseUtilities.preserveForeBack()
        local hexArr = AseUtilities.asePalettesToHexArr(
            srcSprite.palettes)

        -- Unpack arguments.
        local args = dlg.data
        local frameCount = args.frameCount
            or defaults.frameCount --[[@as integer]]
        local fps = args.fps
            or defaults.fps --[[@as integer]]
        local maskCriterion = args.maskCriterion
            or defaults.maskCriterion --[[@as string]]
        local lbThresh100 = args.lbThresh
            or defaults.lbThresh --[[@as integer]]
        local ubThresh100 = args.ubThresh
            or defaults.ubThresh --[[@as integer]]
        local sortCriterion = args.sortCriterion
            or defaults.sortCriterion --[[@as string]]
        local xRandom100 = args.xRandom
            or defaults.xRandom --[[@as integer]]
        local yRandom100 = args.yRandom
            or defaults.yRandom --[[@as integer]]
        local direction = args.direction
            or defaults.direction --[[@as string]]

        --Cache methods used in loops.
        local fromHex = Clr.fromHex
        local sRgbToLch = Clr.sRgbToSrLch
        local rng = math.random
        local floor = math.floor
        local tSort = table.sort

        -- Blit sprite to image, then trim image.
        local srcImg = Image(srcSpriteSpec)
        srcImg:drawSprite(srcSprite, srcFrame)
        local tlx = 0
        local tly = 0
        srcImg, tlx, tly = AseUtilities.trimImageAlpha(
            srcImg, 0, srcSpriteSpec.transparentColor, 8, 8)
        local srcPos = Point(tlx, tly)
        local srcImgSpec = srcImg.spec
        local wSrc = srcImgSpec.width
        local hSrc = srcImgSpec.height
        local srcItr = srcImg:pixels()

        local lenSrcPxArr = 0
        ---@type integer[]
        local srcPxArr = {}
        ---@type table<integer, boolean>
        local masked = {}
        ---@type table<integer, table>
        local lchDict = {}

        local colOrigAbs = 0
        local colDestAbs = wSrc - 1
        local rowOrigAbs = 0
        local rowDestAbs = hSrc - 1

        if maskCriterion == "SELECTION" then
            local sel = AseUtilities.getSelection(srcSprite)
            for pixel in srcItr do
                lenSrcPxArr = lenSrcPxArr + 1
                local hex = pixel()
                local mask = sel:contains(
                    tlx + pixel.x,
                    tly + pixel.y)
                if not lchDict[hex] then
                    local srgb = fromHex(hex)
                    local lch = sRgbToLch(srgb)
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
            end

            if lbThresh100 > ubThresh100 then
                lbThresh100, ubThresh100 = ubThresh100, lbThresh100
            end

            -- Default to masking by lightness.
            local lbThresh = lbThresh100
            local ubThresh = ubThresh100
            local maskFunc = function(lch, lb, ub)
                return lch.l >= lb and lch.l <= ub
            end

            if maskCriterion == "CHROMA" then
                local ratio = 135.0 / 100.0
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
                local hex = pixel()
                local mask = false
                if masked[hex] ~= nil then
                    mask = masked[hex]
                else
                    local srgb = fromHex(hex)
                    local lch = sRgbToLch(srgb)
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
                local left = lchDict[o]
                local right = lchDict[d]
                return left.l < right.l
            end
        elseif sortCriterion == "CHROMA" then
            sorter = function(o, d)
                local left = lchDict[o]
                local right = lchDict[d]
                return left.c < right.c
            end
        elseif sortCriterion == "HUE" then
            sorter = function(o, d)
                local left = lchDict[o]
                local right = lchDict[d]
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
                local left = lchDict[o]
                local right = lchDict[d]
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

        local dirIsVertical = direction == "VERTICAL"
        local yRndOffsets = {}
        local xRndOffsets = {}
        local fRndOffsets = {}

        local yOffMax = 0
        local yOffMin = 0
        if yRandom100 > 0 then
            local yRnd01 = yRandom100 * 0.005
            local yRndScale = 1 + rowDestAbs - rowOrigAbs
            yOffMax = math.floor(0.5 + yRndScale * yRnd01)
            yOffMin = -yOffMax
        end

        local xOffMax = 0
        local xOffMin = 0
        if xRandom100 > 0 then
            local xRnd01 = xRandom100 * 0.005
            local xRndScale = 1 + colDestAbs - colOrigAbs
            xOffMax = math.floor(0.5 + xRndScale * xRnd01)
            xOffMin = -xOffMax
        end

        local xSearchRange = 1 + colDestAbs - colOrigAbs
        local ySearchRange = 1 + rowDestAbs - rowOrigAbs

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

        local frameImages = {}
        if dirIsVertical then
            local colOrig = colOrigAbs
            local colDest = colDestAbs

            local rowOrigFirst = rowOrigAbs
            local rowDestFirst = rowOrigAbs
            if frameCount < 2 then
                rowDestFirst = rowDestAbs
            end
            local rowOrigLast = rowOrigAbs
            local rowDestLast = rowDestAbs

            local frIdx = 0
            while frIdx < frameCount do
                -- Copy source array to a frame array.
                local frPxArr = {}
                local k = 0
                while k < lenSrcPxArr do
                    k = k + 1
                    frPxArr[k] = srcPxArr[k]
                end

                -- Convert frame index to the number of rows
                -- to sort.
                local t = frIdx * frToFac
                local u = 1.0 - t

                local rowOrig = floor(0.5 + u * rowOrigFirst
                    + t * rowOrigLast)
                local rowDest = floor(0.5 + u * rowDestFirst
                    + t * rowDestLast)

                -- Offset the x column.
                frIdx = frIdx + 1
                local xRndOffset = fRndOffsets[frIdx]

                local rndIdx = 0
                local x = colOrig - 1
                while x < colDest do
                    x = x + 1
                    local xOff = (xRndOffset + x) % wSrc
                    -- local xOff = wrap(xRndOffset + x, colOrig, colDest + 1)

                    rndIdx = rndIdx + 1
                    local yRndOffset = yRndOffsets[rndIdx]

                    local lenFound = 0
                    local indices = {}
                    local sorted = {}

                    local y = rowDest + 1
                    while y > rowOrig do
                        y = y - 1
                        local yOff = (yRndOffset + y) % hSrc
                        -- local yOff = wrap(yRndOffset + y, rowOrig, rowDest + 1)
                        local index = 1 + xOff + yOff * wSrc
                        local hex = frPxArr[index]
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

                local frameImage = Image(srcImgSpec)
                local frameItr = frameImage:pixels()
                local j = 0
                for pixel in frameItr do
                    j = j + 1
                    pixel(frPxArr[j])
                end

                frameImages[frIdx] = frameImage
            end -- End of frame loop.
        else
            -- Default is to search the whole image.
            local rowOrig = rowOrigAbs
            local rowDest = rowDestAbs

            local colOrigFirst = colOrigAbs
            local colDestFirst = colOrigAbs
            if frameCount < 2 then
                colDestFirst = colDestAbs
            end
            local colOrigLast = colOrigAbs
            local colDestLast = colDestAbs

            local frIdx = 0
            while frIdx < frameCount do
                -- Copy source array to a frame array.
                local frPxArr = {}
                local k = 0
                while k < lenSrcPxArr do
                    k = k + 1
                    frPxArr[k] = srcPxArr[k]
                end

                -- Convert frame index to the number of columns
                -- to sort.
                local t = frIdx * frToFac
                local u = 1.0 - t
                local colOrig = floor(0.5 + u * colOrigFirst
                    + t * colOrigLast)
                local colDest = floor(0.5 + u * colDestFirst
                    + t * colDestLast)

                -- Offset the yRow.
                frIdx = frIdx + 1
                local yRndOffset = fRndOffsets[frIdx]

                local rndIdx = 0
                local y = rowDest + 1
                while y > rowOrig do
                    y = y - 1
                    local yOff = (yRndOffset + y) % hSrc
                    -- local yOff = wrap(yRndOffset + y, rowOrig, rowDest + 1)
                    rndIdx = rndIdx + 1
                    local xRndOffset = xRndOffsets[rndIdx]

                    -- For horizontal only, y * w can be cached.
                    local yw = yOff * wSrc

                    local lenFound = 0
                    local indices = {}
                    local sorted = {}

                    local x = colOrig - 1
                    while x < colDest do
                        x = x + 1
                        local xOff = (xRndOffset + x) % wSrc
                        -- local xOff = wrap(xRndOffset + x, colOrig, colDest + 1)
                        local index = 1 + xOff + yw
                        local hex = frPxArr[index]
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

                local frameImage = Image(srcImgSpec)
                local frameItr = frameImage:pixels()
                local j = 0
                for pixel in frameItr do
                    j = j + 1
                    pixel(frPxArr[j])
                end
                frameImages[frIdx] = frameImage
            end -- End of frame loop.
        end

        local trgSprite = Sprite(srcSpriteSpec)
        trgSprite.filename = "Pixel Sort"
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        -- Create frames
        app.transaction("New Frames", function()
            local duration = 1.0
            if fps > 1 then duration = 1.0 / fps end
            trgSprite.frames[1].duration = duration

            local i = 1
            while i < frameCount do
                i = i + 1
                local frameObj = trgSprite:newEmptyFrame()
                frameObj.duration = duration
            end
        end)

        -- Create cels.
        local trgLayer = trgSprite.layers[1]
        trgLayer.name = string.format(
            "Pixel Sort.%s.%s",
            maskCriterion, sortCriterion)

        local j = 0
        local trgFrames = trgSprite.frames
        while j < frameCount do
            j = j + 1
            local trgFrame = trgFrames[j]
            local frameImage = frameImages[j]

            app.transaction(string.format(
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