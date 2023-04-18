dofile("../../support/aseutilities.lua")

local directOps = { "BACKWARD", "BOTH", "FORWARD" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    -- Also known as ghost trail or Echo in After Effects.
    -- This could be refactored with new trgImg:drawImage, but
    -- it wouldn't offer much convenience, as layer blend modes
    -- use dest alpha, not source alpha (union, not intersect).
    target = "ACTIVE",
    iterations = 3,
    maxIterations = 32,
    directions = "BACKWARD",
    minAlpha = 64,
    maxAlpha = 128,
    useTint = true,
    foreTint = Color { r = 0, g = 0, b = 255, a = 128 },
    backTint = Color { r = 255, g = 0, b = 0, a = 128 },
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

        local maxFrameCount = #activeSprite.frames
        if maxFrameCount < 2 then
            app.alert {
                title = "Error",
                text = "The sprite contains only one frame."
            }
            return
        end

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

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
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
        local blend = AseUtilities.blendRgba
        local strfmt = string.format
        local transact = app.transaction

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local iterations = args.iterations or defaults.iterations --[[@as integer]]
        local directions = args.directions or defaults.directions --[[@as string]]
        local minAlpha = args.minAlpha or defaults.minAlpha --[[@as integer]]
        local maxAlpha = args.maxAlpha or defaults.maxAlpha --[[@as integer]]
        local useTint = args.useTint --[[@as boolean]]
        local backTint = args.backTint --[[@as Color]]
        local foreTint = args.foreTint --[[@as Color]]

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
        local backHex = AseUtilities.aseColorToHex(backTint, ColorMode.RGB)
        local foreHex = AseUtilities.aseColorToHex(foreTint, ColorMode.RGB)
        local neutHex = 0x00808080
        if useBoth then
            neutHex = Clr.toHex(Clr.mixSrLab2(
                Clr.fromHex(backHex),
                Clr.fromHex(foreHex), 0.5))
        end

        -- Fill frames.
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Do not copy source layer blend mode.
        -- Avoid setting stackIndex property as much as possible!
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = srcLayer.name .. ".Onion"
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
        end)

        local lenFrames = #frames
        local rgbColorMode = ColorMode.RGB --[[@as integer]]
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]

            local startFrameIdx = srcFrame
            local endFrameIdx = srcFrame

            if lookBackward then
                startFrameIdx = srcFrame - iterations
                startFrameIdx = max(1, startFrameIdx)
            end

            if lookForward then
                endFrameIdx = srcFrame + iterations
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
                        ---@type integer[]
                        local pixels = {}
                        local pixelIdx = 0
                        local pxItr = currImg:pixels()
                        for pixel in pxItr do
                            pixelIdx = pixelIdx + 1
                            local hex = pixel()
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
                    colorMode = rgbColorMode,
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
                while h < sampleCount do
                    h = h + 1
                    local packet = packets[h]
                    if packet then
                        local frameIdxShd = packet.frameIdx
                        local relFrameIdx = srcFrame - frameIdxShd

                        local fadeAlpha = maxAlpha
                        if relFrameIdx ~= 0 then
                            fadeAlpha = lerpFunc(
                                minAlpha, maxAlpha,
                                frameIdxShd, srcFrame)
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

                        local lenShadowPixels = #shadowPixels - 1
                        local k = -1
                        while k < lenShadowPixels do
                            k = k + 1
                            local shadowHex = shadowPixels[1 + k]
                            local shadowAlpha = shadowHex >> 0x18 & 0xff
                            if shadowAlpha > 0 then
                                local x = (k % shadowWidth) + xOffset
                                local y = (k // shadowWidth) + yOffset

                                local dest = shadowHex
                                if useTint then
                                    dest = blend(shadowHex, tint)
                                end
                                local compAlpha = min(shadowAlpha, fadeAlpha)
                                dest = (compAlpha << 0x18) | (dest & 0x00ffffff)

                                local orig = trgImg:getPixel(x, y)
                                trgImg:drawPixel(x, y, blend(orig, dest))
                            end
                        end
                    end
                end

                -- Important to break this into separate transactions
                -- in case there is a bug that is causing an Aseprite crash.
                transact(
                    strfmt("Bake Onion %d", srcFrame),
                    function()
                        activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, trgPos)
                    end)
            end
        end

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