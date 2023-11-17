dofile("../../support/aseutilities.lua")

local directOps <const> = { "BACKWARD", "BOTH", "FORWARD" }
local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    -- Also known as ghost trail or Echo in After Effects.
    -- This could be refactored with new drawImage, but
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

local dlg <const> = Dialog { title = "Bake Onion Skin" }

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
        local args <const> = dlg.data
        local md <const> = args.directions --[[@as string]]
        local useTint <const> = args.useTint --[[@as boolean]]
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
        local args <const> = dlg.data
        local md <const> = args.directions --[[@as string]]
        local useTint <const> = args.useTint --[[@as boolean]]
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local maxFrameCount <const> = #activeSprite.frames
        if maxFrameCount < 2 then
            app.alert {
                title = "Error",
                text = "The sprite contains only one frame."
            }
            return
        end

        local colorMode <const> = activeSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer <const> = site.layer
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
        local colorSpace <const> = activeSprite.colorSpace
        local alphaIndex <const> = activeSprite.transparentColor

        -- Cache global functions used in for loops.
        local abs <const> = math.abs
        local max <const> = math.max
        local min <const> = math.min
        local floor <const> = math.floor
        local blend <const> = AseUtilities.blendRgba
        local createSpec <const> = AseUtilities.createSpec
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local iterations <const> = args.iterations
            or defaults.iterations --[[@as integer]]
        local directions <const> = args.directions
            or defaults.directions --[[@as string]]
        local minAlpha <const> = args.minAlpha
            or defaults.minAlpha --[[@as integer]]
        local maxAlpha <const> = args.maxAlpha
            or defaults.maxAlpha --[[@as integer]]
        local useTint <const> = args.useTint --[[@as boolean]]
        local backTint <const> = args.backTint --[[@as Color]]
        local foreTint <const> = args.foreTint --[[@as Color]]

        -- Find directions.
        local useBoth <const> = directions == "BOTH"
        local useFore <const> = directions == "FORWARD"
        local useBack <const> = directions == "BACKWARD"
        local lookForward <const> = useBoth or useFore
        local lookBackward <const> = useBoth or useBack

        -- Unpack colors.
        -- Neutral hex is when onion skin lands
        -- on current frame. When "BOTH" directions
        -- are used, mix between back and fore.
        local backHex <const> = AseUtilities.aseColorToHex(backTint, ColorMode.RGB)
        local foreHex <const> = AseUtilities.aseColorToHex(foreTint, ColorMode.RGB)
        local neutHex = 0x00808080
        if useBoth then
            neutHex = Clr.toHex(Clr.mixSrLab2(
                Clr.fromHex(backHex),
                Clr.fromHex(foreHex), 0.5))
        end

        -- Fill frames.
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Do not copy source layer blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = srcLayer.name .. ".Onion"
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.stackIndex = srcLayer.stackIndex
        end)

        -- Set function for both vs. forward or backward.
        local lerpFunc = nil
        if useBoth then
            lerpFunc = function(aMin, aMax, i, d, s)
                if s > 2 then
                    local t <const> = (abs(i - d) - 1.0) / (0.5 * s - 1.0)
                    if t <= 0.0 then return aMax end
                    if t >= 1.0 then return aMin end
                    return (1.0 - t) * aMax + t * aMin
                elseif s > 1 then
                    return (aMin + aMax) * 0.5
                else
                    return aMin
                end
            end
        else
            lerpFunc = function(aMin, aMax, i, d, s)
                if s > 2 then
                    local t <const> = (abs(i - d) - 1.0) / (s - 2.0)
                    return (1.0 - t) * aMax + t * aMin
                elseif s > 1 then
                    return (aMin + aMax) * 0.5
                else
                    return aMin
                end
            end
        end

        local lenFrames <const> = #frames
        local rgbColorMode <const> = ColorMode.RGB
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]

            local startFrameIdx = srcFrame
            if lookBackward then
                startFrameIdx = max(1, srcFrame - iterations)
            end

            local endFrameIdx = srcFrame
            if lookForward then
                endFrameIdx = min(maxFrameCount, srcFrame + iterations)
            end

            local sampleCount <const> = abs(1 + endFrameIdx - startFrameIdx)

            -- For the image to be as efficient (i.e., small) as
            -- it can, find the top left and bottom right viable
            -- corners occupied by sample images.
            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            ---@type table[]
            local packets <const> = {}
            local packetIdx = 0
            local j = 0
            while j < sampleCount do
                local frameIdx <const> = startFrameIdx + j
                j = j + 1
                if frameIdx >= 1 and frameIdx <= maxFrameCount then
                    local currCel <const> = srcLayer:cel(frameIdx)
                    if currCel then
                        local currImg <const> = currCel.image
                        local currPos <const> = currCel.position
                        local xTopLeft <const> = currPos.x
                        local yTopLeft <const> = currPos.y

                        -- Bottom right corner is cel's position
                        -- plus image dimensions.
                        local imgWidth <const> = currImg.width
                        local imgHeight <const> = currImg.height
                        local xBottomRight <const> = xTopLeft + imgWidth
                        local yBottomRight <const> = yTopLeft + imgHeight

                        -- Update minima and maxima.
                        if xTopLeft < xMin then xMin = xTopLeft end
                        if yTopLeft < yMin then yMin = yTopLeft end
                        if xBottomRight > xMax then xMax = xBottomRight end
                        if yBottomRight > yMax then yMax = yBottomRight end

                        -- Store pixels from the image.
                        ---@type integer[]
                        local pixels <const> = {}
                        local pixelIdx = 0
                        local pxItr <const> = currImg:pixels()
                        for pixel in pxItr do
                            pixelIdx = pixelIdx + 1
                            local hex <const> = pixel()
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

            -- This was initially xMax ~= xMin and yMax ~= yMin, but then there
            -- was a problem where a range containing empty cels in the initial
            -- slots would freeze the program.
            if packetIdx > 0 and xMax > xMin and yMax > yMin then
                -- Find containing axis aligned bounding box.
                -- Find minimum for top-left corner of cels.
                local trgPos <const> = Point(xMin, yMin)
                local trgSpec = createSpec(
                    xMax - xMin, yMax - yMin,
                    rgbColorMode, colorSpace, alphaIndex)
                local trgImg <const> = Image(trgSpec)

                local h = 0
                while h < sampleCount do
                    h = h + 1
                    local packet <const> = packets[h]
                    if packet then
                        local frameIdxShd <const> = packet.frameIdx
                        local relFrameIdx <const> = srcFrame - frameIdxShd

                        local fadeAlpha = maxAlpha
                        if relFrameIdx ~= 0 then
                            fadeAlpha = lerpFunc(
                                minAlpha, maxAlpha,
                                frameIdxShd, srcFrame, sampleCount)
                            fadeAlpha = floor(0.5 + fadeAlpha)
                        end

                        local tint = neutHex
                        if relFrameIdx > 0 then
                            tint = backHex
                        elseif relFrameIdx < 0 then
                            tint = foreHex
                        end

                        local shadowPixels <const> = packet.pixels
                        local shadowWidth <const> = packet.width
                        local xOffset <const> = packet.tlx - xMin
                        local yOffset <const> = packet.tly - yMin

                        local lenShadowPixels <const> = #shadowPixels - 1
                        local k = -1
                        while k < lenShadowPixels do
                            k = k + 1
                            local shadowHex <const> = shadowPixels[1 + k]
                            local shadowAlpha <const> = shadowHex >> 0x18 & 0xff
                            if shadowAlpha > 0 then
                                local x <const> = (k % shadowWidth) + xOffset
                                local y <const> = (k // shadowWidth) + yOffset

                                local dest = shadowHex
                                if useTint then
                                    dest = blend(shadowHex, tint)
                                end
                                local compAlpha <const> = min(shadowAlpha, fadeAlpha)
                                dest = (compAlpha << 0x18) | (dest & 0x00ffffff)

                                local orig <const> = trgImg:getPixel(x, y)
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

        app.layer = srcLayer
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

dlg:show {
    autoscrollbars = true,
    wait = false
}