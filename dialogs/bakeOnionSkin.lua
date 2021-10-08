dofile("../support/aseutilities.lua")

local directOps = { "BACKWARD", "BOTH", "FORWARD" }

local defaults = {
    iterations = 6,
    directions = "BACKWARD",
    minAlpha = 24,
    maxAlpha = 96
}

local dlg = Dialog { title = "Bake Onion Skin" }

dlg:slider {
    id = "iterations",
    label = "Iterations:",
    min = 1,
    max = 96,
    value = defaults.iterations
}

dlg:newrow { always = false }

dlg:slider {
    id = "minAlpha",
    label = "Min Alpha:",
    min = 0,
    max = 255,
    value = defaults.minAlpha
}

dlg:newrow { always = false }

dlg:slider {
    id = "maxAlpha",
    label = "Max Alpha:",
    min = 0,
    max = 255,
    value = defaults.maxAlpha
}

dlg:newrow { always = false }

dlg:combobox {
    id = "directions",
    label = "Direction:",
    option = defaults.direcions,
    options = directOps
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local srcSprite = app.activeSprite
        if srcSprite then
            if srcSprite.colorMode == ColorMode.RGB then
                local srcCel = app.activeCel
                if srcCel then
                    -- Unpack arguments.
                    local args = dlg.data
                    local iterations = args.iterations or defaults.iterations
                    local directions = args.directions or defaults.directions
                    local minAlpha = args.minAlpha or defaults.minAlpha
                    local maxAlpha = args.maxAlpha or defaults.maxAlpha

                    -- Find directions.
                    local useBoth = directions == "BOTH"
                    local useFore = directions == "FORWARD"
                    local useBack = directions == "BACKWARD"
                    local lookForward = useBoth or useFore
                    local lookBackward = useBoth or useBack

                    local srcLayer = srcCel.layer -- row
                    local srcFrame = srcCel.frame -- column
                    local srcFrameIndex = srcFrame.frameNumber
                    local frameCount = #srcSprite.frames
                    -- print(string.format("srcFrameIndex: %d", srcFrameIndex))

                    local startFrameIndex = srcFrameIndex
                    local endFrameIndex = srcFrameIndex

                    if lookBackward then
                        startFrameIndex = srcFrameIndex - iterations
                        startFrameIndex = math.max(1, startFrameIndex)
                    end
                    -- print(string.format("startFrameIndex: %d", startFrameIndex))

                    if lookForward then
                        endFrameIndex = srcFrameIndex + iterations
                        endFrameIndex = math.min(frameCount, endFrameIndex)
                    end
                    -- print(string.format("endFrameIndex: %d", endFrameIndex))

                    local sampleCount = math.abs(1 + endFrameIndex - startFrameIndex)
                    -- print(string.format("sampleCount: %d", sampleCount))

                    -- For the image to be as efficient (i.e., small) as
                    -- it can, find the top left and bottom right viable
                    -- corners occupied by sample images.
                    local xMin = 99999
                    local yMin = 99999
                    local xMax = -99999
                    local yMax = -99999

                    local packets = {}
                    local frameIndices = {}

                    for i = 1, sampleCount, 1 do
                        local frameIndex = startFrameIndex + (i - 1)
                        frameIndex = math.min(math.max(frameIndex, 1), frameCount)
                        frameIndices[i] = frameIndex
                        -- print(string.format("frameIndex: %d", frameIndex))

                        local currCel = srcLayer:cel(frameIndex)
                        if currCel then
                            local currImg = currCel.image
                            if currImg then
                                local imgWidth = currImg.width
                                local imgHeight = currImg.height

                                local currPos = currCel.position
                                local xTopLeft = currPos.x
                                local yTopLeft = currPos.y
                                local xBottomRight = xTopLeft + imgWidth
                                local yBottomRight = yTopLeft + imgHeight

                                if xTopLeft < xMin then xMin = xTopLeft end
                                if yTopLeft < yMin then yMin = yTopLeft end
                                if xBottomRight > xMax then xMax = xBottomRight end
                                if yBottomRight > yMax then yMax = yBottomRight end

                                local pixels = {}
                                local pixelIdx = 1
                                local pixelItr = currImg:pixels()
                                for elm in pixelItr do
                                    local hex = elm()
                                    local alphaOnly = hex & 0xff000000
                                    if alphaOnly ~= 0 then
                                        pixels[pixelIdx] = hex
                                    else
                                        pixels[pixelIdx] = 0x0
                                    end
                                    pixelIdx = pixelIdx + 1
                                end

                                packets[i] = {
                                    tlx = xTopLeft,
                                    tly = yTopLeft,
                                    width = imgWidth,
                                    pixels = pixels }
                            else
                                packets[i] = nil
                            end
                        else
                            packets[i] = nil
                        end
                    end

                    if xMax ~= xMin and yMax ~= yMin then
                        -- Find maximum containing axis aligned bounding
                        -- box. Find minimum for top-left corner of cels.
                        local trgImgWidth = math.abs(xMax - xMin)
                        local trgImgHeight = math.abs(yMax - yMin)
                        local trgPos = Point(xMin, yMin)
                        -- print(string.format("celPos: (%d, %d)", xMin, yMin))
                        -- print(string.format("imgDim: (%d, %d)", trgImgWidth, trgImgHeight))

                        -- Set function for both vs. forward or backward.
                        local lerpFunc = nil
                        if useBoth then
                            lerpFunc = function(a, b, c, d)
                                local t = (math.abs(c - d) - 1.0) / (0.5 * sampleCount - 1.0)
                                t = math.min(math.max(t, 0.0), 1.0)
                                -- print(string.format("fac: %.6f", t))
                                return (1.0 - t) * b + t * a
                            end
                        else
                            lerpFunc = function(a, b, c, d)
                                local t = (math.abs(c - d) - 1.0) / (sampleCount - 2.0)
                                return (1.0 - t) * b + t * a
                            end
                        end

                        -- Create target images.
                        local trgImgs = {}
                        for i = 1, sampleCount, 1 do
                            local baseIndex = frameIndices[i]
                            local trgImg = Image(trgImgWidth, trgImgHeight)

                            local startIndex = 1
                            local endIndex = sampleCount
                            local step = 1
                            if useBack then
                                startIndex = 1
                                endIndex = i
                                step = 1
                            elseif useFore then
                                startIndex = sampleCount
                                endIndex = i
                                step = -1
                            end

                            for j = startIndex, endIndex, step do
                                -- Only draw shadows not base.
                                local shadowIndex = frameIndices[j]
                                local shadowPacket = packets[j]
                                if shadowPacket then
                                    local fadeAlpha = 255
                                    if shadowIndex ~= baseIndex then
                                        fadeAlpha = lerpFunc(minAlpha, maxAlpha, shadowIndex, baseIndex)
                                        fadeAlpha = math.tointeger(0.5 + fadeAlpha)

                                        local shadowPixels = shadowPacket.pixels
                                        local shadowWidth = shadowPacket.width
                                        local xShadow = shadowPacket.tlx
                                        local yShadow = shadowPacket.tly

                                        local shadowPixelLen = #shadowPixels
                                        for k = 0, shadowPixelLen - 1, 1 do

                                            -- x pixel in source image is k % baseWidth .
                                            -- y pixel in source image is k // baseWidth .
                                            -- Then add original cel position.
                                            -- Then subtract new cel position.
                                            local x = (k % shadowWidth) + (xShadow - xMin)
                                            local y = (k // shadowWidth) + (yShadow - yMin)

                                            -- Alpha is the minimum of the original and the fade.
                                            local shadowHex = shadowPixels[1 + k]
                                            local shadowAlpha = shadowHex >> 0x18 & 0xff
                                            local compAlpha = math.min(shadowAlpha, fadeAlpha)

                                            local orig = trgImg:getPixel(x, y)
                                            local dest = shadowHex & 0x00ffffff
                                                            | compAlpha << 0x18
                                            trgImg:drawPixel(x, y,
                                                AseUtilities.blend(orig, dest))
                                        end
                                    end
                                end
                            end

                            -- Always draw the current animation frame last,
                            -- so that it is on top.
                            local basePacket = packets[i]
                            if basePacket then
                                local basePixels = basePacket.pixels
                                local baseWidth = basePacket.width
                                local xBase = basePacket.tlx
                                local yBase = basePacket.tly

                                local basePixelLen = #basePixels
                                for k = 0, basePixelLen - 1, 1 do
                                    local x = (k % baseWidth) + (xBase - xMin)
                                    local y = (k // baseWidth) + (yBase - yMin)
                                    trgImg:drawPixel(x, y,
                                        AseUtilities.blend(
                                            trgImg:getPixel(x, y),
                                            basePixels[1 + k]))
                                end
                            end

                            trgImgs[i] = trgImg
                        end

                        -- Create target layer.
                        local trgLayer = srcSprite:newLayer()
                        trgLayer.name = srcLayer.name .. ".OnionSkin"

                        -- Create target cels in a transaction.
                        app.transaction(function()
                            for i = 1, sampleCount, 1 do
                                local frameIndex = frameIndices[i]
                                local frameObject = srcSprite.frames[frameIndex]
                                local trgImg = trgImgs[i]
                                srcSprite:newCel(
                                    trgLayer, frameObject, trgImg, trgPos)
                            end
                        end)

                        app.refresh()
                    else
                        app.alert("No pixel data found.")
                    end
                else
                    app.alert("There is no active cel.")
                end
            else
                app.alert("Only RGB color mode is supported.")
            end
        else
            app.alert("There is no active sprite.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }