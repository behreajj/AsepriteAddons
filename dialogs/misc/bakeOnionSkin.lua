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
    foreTint = Color { r = 0, g = 0, b = 255, a = 128 },
    backTint = Color { r = 255, g = 0, b = 0, a = 128 } ,
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
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack properties from sprite.
        local maxFrameCount = #activeSprite.frames
        local colorMode = activeSprite.colorMode

        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        if srcLayer.isBackground then
            app.alert {
                title = "Error",
                text = "Background layer cannot be the source."
            }
            return
        end

        -- Get sprite properties.
        local colorSpace = activeSprite.colorSpace
        local alphaIdx = activeSprite.transparentColor

        -- Cache global functions used in for loops.
        local abs = math.abs
        local max = math.max
        local min = math.min
        local floor = math.floor

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target --[[@as string]]
        local iterations = args.iterations or defaults.iterations
        local directions = args.directions or defaults.directions
        local minAlpha = args.minAlpha or defaults.minAlpha
        local maxAlpha = args.maxAlpha or defaults.maxAlpha
        local useTint = args.useTint
        local backTint = args.backTint or defaults.backTint
        local foreTint = args.foreTint or defaults.foreTint

        -- Find directions.
        local useBoth = directions == "BOTH"
        local useFore = directions == "FORWARD"
        local useBack = directions == "BACKWARD"
        local lookForward = useBoth or useFore
        local lookBackward = useBoth or useBack

        -- Unpack colors.
        -- Neutral hex is when onion skin lands
        -- on current frame. When "BOTH" directions
        -- are used, mix between back and fore.
        local backHex = backTint.rgbaPixel
        local foreHex = foreTint.rgbaPixel
        local neutHex = 0x00808080
        if useBoth then
            neutHex = Clr.toHex(Clr.mixSrLab2(
                Clr.fromHex(backHex),
                Clr.fromHex(foreHex), 0.5))
        end

        -- Fill frames.
        local frames = AseUtilities.getFrames(activeSprite, target)

        -- Do not copy source layer blend mode.
        -- Target layer parent is set later,
        -- to ensure that onion is beneath source.
        local trgLayer = activeSprite:newLayer()
        trgLayer.name = srcLayer.name .. ".Onion"
        trgLayer.opacity = srcLayer.opacity

        local framesLen = #frames
        app.transaction(function()
            local i = 0
            while i < framesLen do i = i + 1
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
                local packetIdx = 0
                local j = 0
                while j < sampleCount do
                    local frameIdx = startFrameIdx + j
                    j = j + 1
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
                            local pixelIdx = 0
                            local pixelItr = currImg:pixels()
                            for elm in pixelItr do
                                pixelIdx = pixelIdx + 1
                                local hex = elm()
                                if (hex & 0xff000000) ~= 0x0 then
                                    pixels[pixelIdx] = hex
                                else
                                    pixels[pixelIdx] = 0x0
                                end
                            end

                            -- Group all data into a packet.
                            packetIdx = packetIdx + 1
                            packets[packetIdx] = {
                                frameIdx = frameIdx,
                                tlx = xTopLeft,
                                tly = yTopLeft,
                                width = imgWidth,
                                height = imgHeight,
                                pixels = pixels
                            }
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

                    local trgSpec = ImageSpec {
                        width = trgImgWidth,
                        height = trgImgHeight,
                        colorMode = ColorMode.RGB,
                        transparentColor = alphaIdx
                    }
                    trgSpec.colorSpace = colorSpace
                    local trgImg = Image(trgSpec)

                    -- Set function for both vs. forward or backward.
                    local lerpFunc = nil
                    if useBoth then
                        lerpFunc = function(a, b, c, d)
                            if sampleCount > 2 then
                                local t = (abs(c - d) - 1.0) / (0.5 * sampleCount - 1.0)
                                if t <= 0.0 then return b end
                                if t >= 1.0 then return a end
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

                    local h = 0
                    while h < sampleCount do h = h + 1
                        local packet = packets[h]
                        if packet then
                            local frameIdxShd = packet.frameIdx
                            local relFrameIdx = srcFrameIdx - frameIdxShd

                            local fadeAlpha = maxAlpha
                            if relFrameIdx ~= 0 then
                                fadeAlpha = lerpFunc(
                                    minAlpha, maxAlpha,
                                    frameIdxShd, srcFrameIdx)
                                fadeAlpha = floor(0.5 + fadeAlpha)
                            end

                            local tint = neutHex
                            if relFrameIdx > 0 then
                                tint = backHex
                            elseif relFrameIdx < 0 then
                                tint = foreHex
                            end

                            local shadowPixels = packet.pixels
                            local shadowWidth = packet.width
                            local xOffset = packet.tlx - xMin
                            local yOffset = packet.tly - yMin

                            local shadowPixelLen = #shadowPixels - 1
                            local k = -1
                            while k < shadowPixelLen do k = k + 1
                                local shadowHex = shadowPixels[1 + k]
                                local shadowAlpha = shadowHex >> 0x18 & 0xff
                                if shadowAlpha > 0 then
                                    local x = (k % shadowWidth) + xOffset
                                    local y = (k // shadowWidth) + yOffset

                                    local dest = shadowHex
                                    if useTint then
                                        dest = AseUtilities.blendHexes(shadowHex, tint)
                                    end
                                    local compAlpha = min(shadowAlpha, fadeAlpha)
                                    dest = (compAlpha << 0x18) | (dest & 0x00ffffff)

                                    local orig = trgImg:getPixel(x, y)
                                    trgImg:drawPixel(x, y,
                                        AseUtilities.blendHexes(orig, dest))
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
            local lenLayers = #layers
            local i = oldSrcIdx
            while i < lenLayers do i = i + 1
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
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }