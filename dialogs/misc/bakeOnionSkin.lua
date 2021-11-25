dofile("../../support/aseutilities.lua")

local directOps = { "BACKWARD", "BOTH", "FORWARD" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    iterations = 3,
    maxIterations = 32,
    directions = "BACKWARD",
    minAlpha = 64,
    maxAlpha = 128,
    useTint = true,
    foreTint = Color(0, 0, 255, 128),
    backTint = Color(255, 0, 0, 128),
    -- foreTint = Color(185, 146, 57, 128),
    -- backTint = Color(47, 0, 128, 128),
    pullFocus = false
}

local dlg = Dialog { title = "Bake Onion Skin" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "iterations",
    label = "Iterations:",
    min = 1,
    max = defaults.maxIterations,
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
    options = directOps,
    onchange = function()
        local args = dlg.data
        local md = args.directions
        local useTint = args.useTint
        if md == "FORWARD" then
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = false }
        elseif md == "BACKWARD" then
            dlg:modify { id = "foreTint", visible = false }
            dlg:modify { id = "backTint", visible = useTint }
        else
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = useTint }
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useTint",
    label = "Tint:",
    selected = defaults.useTint,
    onclick = function()
        local args = dlg.data
        local md = args.directions
        local useTint = args.useTint
        if md == "FORWARD" then
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = false }
        elseif md == "BACKWARD" then
            dlg:modify { id = "foreTint", visible = false }
            dlg:modify { id = "backTint", visible = useTint }
        else
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = useTint }
        end
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "backTint",
    label = "Back:",
    color = defaults.backTint,
    visible = defaults.useTint
        and (defaults.directions == "BACKWARD"
            or defaults.direcions == "BOTH")
}

dlg:newrow { always = false }

dlg:color {
    id = "foreTint",
    label = "Fore:",
    color = defaults.foreTint,
    visible = defaults.useTint
        and (defaults.directions == "FORWARD"
        or defaults.direcions == "BOTH")
}

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

        -- Unpack properties from sprite.
        local maxFrameCount = #activeSprite.frames
        local colorMode = activeSprite.colorMode

        if colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert("There is no active layer.")
            return
        end

        if srcLayer.isGroup then
            app.alert("Group layers are not supported.")
            return
        end

        if srcLayer.isBackground then
            app.alert("Background layer cannot be the source.")
            return
        end

        -- Cache global functions used in for loops.
        local abs = math.abs
        local max = math.max
        local min = math.min
        local trunc = math.tointeger

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target
        local iterations = args.iterations or defaults.iterations
        local directions = args.directions or defaults.directions
        local minAlpha = args.minAlpha or defaults.minAlpha
        local maxAlpha = args.maxAlpha or defaults.maxAlpha
        local useTint = args.useTint
        local backTint = args.backTint or defaults.backTint
        local foreTint = args.foreTint or defaults.foreTint

        -- Unpack colors.
        local backHex = backTint.rgbaPixel
        local foreHex = foreTint.rgbaPixel

        -- Find directions.
        local useBoth = directions == "BOTH"
        local useFore = directions == "FORWARD"
        local useBack = directions == "BACKWARD"
        local lookForward = useBoth or useFore
        local lookBackward = useBoth or useBack

        -- Fill frames.
        local frames = {}
        if target == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                frames[1] = activeFrame
            end
        elseif target == "RANGE" then
            local appRange = app.range
            local rangeFrames = appRange.frames
            local rangeFramesLen = #rangeFrames
            for i = 1, rangeFramesLen, 1 do
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        local trgLayer = activeSprite:newLayer()
        trgLayer.name = srcLayer.name .. ".Onion"
        trgLayer.opacity = srcLayer.opacity

        local framesLen = #frames
        app.transaction(function()
            for i = 1, framesLen, 1 do
                local srcFrame = frames[i]
                local srcFrameIdx = srcFrame.frameNumber

                local startFrameIdx = srcFrameIdx
                local endFrameIdx = srcFrameIdx

                if lookBackward then
                    startFrameIdx = srcFrameIdx - iterations
                    startFrameIdx = max(1, startFrameIdx)
                end

                if lookForward then
                    endFrameIdx = srcFrameIdx + iterations
                    endFrameIdx = min(maxFrameCount, endFrameIdx)
                end

                local sampleCount = abs(1 + endFrameIdx - startFrameIdx)

                -- For the image to be as efficient (i.e., small) as
                -- it can, find the top left and bottom right viable
                -- corners occupied by sample images.
                local xMin = 2147483647
                local yMin = 2147483647
                local xMax = -2147483648
                local yMax = -2147483648

                local packets = {}
                local packetIdx = 1
                for j = 1, sampleCount, 1 do
                    local frameIdx = startFrameIdx + (j - 1)
                    -- TODO: Support looping?
                    if frameIdx >= 1 and frameIdx <= maxFrameCount then
                        local currCel = srcLayer:cel(frameIdx)
                        if currCel then
                            local currImg = currCel.image
                            local currPos = currCel.position
                            local xTopLeft = currPos.x
                            local yTopLeft = currPos.y

                            -- Bottom right corner is cel's position
                            -- plus image dimensions.
                            local imgWidth = currImg.width
                            local imgHeight = currImg.height
                            local xBottomRight = xTopLeft + imgWidth
                            local yBottomRight = yTopLeft + imgHeight

                            -- Update minima and maxima.
                            if xTopLeft < xMin then xMin = xTopLeft end
                            if yTopLeft < yMin then yMin = yTopLeft end
                            if xBottomRight > xMax then xMax = xBottomRight end
                            if yBottomRight > yMax then yMax = yBottomRight end

                            -- Store pixels from the image.
                            local pixels = {}
                            local pixelIdx = 1
                            local pixelItr = currImg:pixels()
                            for elm in pixelItr do
                                local hex = elm()
                                local alphaOnly = hex & 0xff000000
                                if alphaOnly ~= 0x0 then
                                    pixels[pixelIdx] = hex
                                else
                                    pixels[pixelIdx] = 0x0
                                end
                                pixelIdx = pixelIdx + 1
                            end

                            -- Group all data into a packet.
                            packets[packetIdx] = {
                                frameIdx = frameIdx,
                                tlx = xTopLeft,
                                tly = yTopLeft,
                                width = imgWidth,
                                height = imgHeight,
                                pixels = pixels
                            }
                            packetIdx = packetIdx + 1
                        else
                            packetIdx = packetIdx + 1
                        end
                    end
                end

                if xMax ~= xMin and yMax ~= yMin then
                    -- Find maximum containing axis aligned bounding
                    -- box. Find minimum for top-left corner of cels.
                    local trgImgWidth = abs(xMax - xMin)
                    local trgImgHeight = abs(yMax - yMin)
                    local trgPos = Point(xMin, yMin)
                    local trgImg = Image(trgImgWidth, trgImgHeight)

                    -- Set function for both vs. forward or backward.
                    local lerpFunc = nil
                    if useBoth then
                        lerpFunc = function(a, b, c, d)
                            if sampleCount > 2 then
                                local t = (abs(c - d) - 1.0) / (0.5 * sampleCount - 1.0)
                                t = min(max(t, 0.0), 1.0)
                                return (1.0 - t) * b + t * a
                            elseif sampleCount > 1 then
                                return (a + b) * 0.5
                            else
                                return a
                            end
                        end
                    else
                        lerpFunc = function(a, b, c, d)
                            if sampleCount > 2 then
                                local t = (abs(c - d) - 1.0) / (sampleCount - 2.0)
                                return (1.0 - t) * b + t * a
                            elseif sampleCount > 1 then
                                return (a + b) * 0.5
                            else
                                return a
                            end
                        end
                    end

                    for j = 1, sampleCount, 1 do
                        local packet = packets[j]
                        if packet then
                            local frameIdxShd = packet.frameIdx
                            local relFrameIdx = srcFrameIdx - frameIdxShd

                            local fadeAlpha = maxAlpha
                            if relFrameIdx ~= 0 then
                                fadeAlpha = lerpFunc(
                                    minAlpha, maxAlpha,
                                    frameIdxShd, srcFrameIdx)
                                fadeAlpha = trunc(0.5 + fadeAlpha)
                            end

                            local tint = 0x0
                            if relFrameIdx > 0 then
                                tint = backHex
                            elseif relFrameIdx < 0 then
                                tint = foreHex
                            end

                            local shadowPixels = packet.pixels
                            local shadowWidth = packet.width
                            local xOffset = packet.tlx - xMin
                            local yOffset = packet.tly - yMin

                            local shadowPixelLen = #shadowPixels
                            for k = 0, shadowPixelLen - 1, 1 do
                                local shadowHex = shadowPixels[1 + k]
                                local shadowAlpha = shadowHex >> 0x18 & 0xff
                                if shadowAlpha > 0 then
                                    local x = (k % shadowWidth) + xOffset
                                    local y = (k // shadowWidth) + yOffset
                                    local orig = trgImg:getPixel(x, y)
                                    local dest = shadowHex
                                    if useTint then
                                        dest = AseUtilities.blend(shadowHex, tint)
                                    end
                                    local compAlpha = min(shadowAlpha, fadeAlpha)
                                    dest = (dest & 0x00ffffff) | (compAlpha << 0x18)

                                    trgImg:drawPixel(x, y,
                                        AseUtilities.blend(orig, dest))
                                end
                            end
                        end
                    end

                    activeSprite:newCel(trgLayer, srcFrame, trgImg, trgPos)
                end
            end
        end)

        -- Ensure that onion skin appears below source layer.
        app.transaction(function()
            local srcParent = srcLayer.parent
            trgLayer.parent = srcParent
            local oldSrcIdx = srcLayer.stackIndex
            trgLayer.stackIndex = oldSrcIdx

            local layers = srcParent.layers
            for i = oldSrcIdx + 1, #layers, 1 do
                layers[i].stackIndex = i
            end
            app.activeLayer = srcLayer
        end)
        app.refresh()
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