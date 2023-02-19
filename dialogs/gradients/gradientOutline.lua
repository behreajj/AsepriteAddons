dofile("../../support/gradientutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ACTIVE",
    iterations = 16,
    alphaFade = false,
    reverseFade = false,
    m00 = false,
    m01 = true,
    m02 = false,
    m10 = true,
    m12 = true,
    m20 = false,
    m21 = true,
    m22 = false,
    pullFocus = false
}

local dlg = Dialog { title = "Outline Gradient" }

GradientUtilities.dialogWidgets(dlg)

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "iterations",
    label = "Repeat:",
    min = 1,
    max = 64,
    value = defaults.iterations
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = Color { r = 0, g = 0, b = 0, a = 0 }
}

dlg:newrow { always = false }

dlg:check {
    id = "alphaFade",
    label = "Alpha:",
    text = "Auto Fade",
    selected = defaults.alphaFade,
    onclick = function()
        local args = dlg.data
        dlg:modify {
            id = "reverseFade",
            visible = args.alphaFade
        }
        dlg:modify {
            id = "reverseFade",
            selected = defaults.reverseFade
        }
    end
}

dlg:check {
    id = "reverseFade",
    text = "Reverse",
    selected = defaults.reverseFade,
    visible = defaults.alphaFade
}

dlg:newrow { always = false }

dlg:button {
    id = "square",
    label = "Matrix:",
    text = "S&QUARE",
    focus = false,
    onclick = function()
        dlg:modify { id = "m00", selected = true }
        dlg:modify { id = "m01", selected = true }
        dlg:modify { id = "m02", selected = true }
        dlg:modify { id = "m10", selected = true }
        dlg:modify { id = "m12", selected = true }
        dlg:modify { id = "m20", selected = true }
        dlg:modify { id = "m21", selected = true }
        dlg:modify { id = "m22", selected = true }
    end
}

dlg:button {
    id = "circle",
    text = "&DIAMOND",
    focus = false,
    onclick = function()
        dlg:modify { id = "m00", selected = false }
        dlg:modify { id = "m01", selected = true }
        dlg:modify { id = "m02", selected = false }
        dlg:modify { id = "m10", selected = true }
        dlg:modify { id = "m12", selected = true }
        dlg:modify { id = "m20", selected = false }
        dlg:modify { id = "m21", selected = true }
        dlg:modify { id = "m22", selected = false }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "m00",
    selected = defaults.m00
}

dlg:check {
    id = "m01",
    selected = defaults.m01
}

dlg:check {
    id = "m02",
    selected = defaults.m02
}

dlg:newrow { always = false }

dlg:check {
    id = "m10",
    selected = defaults.m10
}

dlg:check {
    id = "m11",
    enabled = false,
    selected = false
}

dlg:check {
    id = "m12",
    selected = defaults.m12
}

dlg:newrow { always = false }

dlg:check {
    id = "m20",
    selected = defaults.m20
}

dlg:check {
    id = "m21",
    selected = defaults.m21
}

dlg:check {
    id = "m22",
    selected = defaults.m22
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local printElapsed = false
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.time() end

        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
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

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local alphaFade = args.alphaFade --[[@as boolean]]
        local reverseFade = args.reverseFade --[[@as boolean]]
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local aseColors = args.shades --[[@as Color[] ]]
        local levels = args.quantize --[[@as integer]]
        local aseBkgColor = args.bkgColor --[[@as Color]]
        local iterations = args.iterations
            or defaults.iterations --[[@as integer]]

        -- Create matrices.
        -- Directions need to be flipped on x and y axes.

        ---@type boolean[]
        local activeMatrix = {
            args.m00 --[[@as boolean]],
            args.m01 --[[@as boolean]],
            args.m02 --[[@as boolean]],
            args.m10 --[[@as boolean]],
            args.m12 --[[@as boolean]],
            args.m20 --[[@as boolean]],
            args.m21 --[[@as boolean]],
            args.m22 --[[@as boolean]]
        }

        ---@type integer[][]
        local dirMatrix = {
            { 1, 1 }, { 0, 1 }, { -1, 1 },
            { 1, 0 }, { -1, 0 },
            { 1, -1 }, { 0, -1 }, { -1, -1 }
        }

        ---@type integer[][]
        local activeOffsets = {}
        local activeCount = 0
        local m = 0
        while m < 8 do m = m + 1
            if activeMatrix[m] then
                activeCount = activeCount + 1
                activeOffsets[activeCount] = dirMatrix[m]
            end
        end

        if activeCount < 1 then
            app.alert {
                title = "Error",
                text = "Neighbor matrix is empty."
            }
            return
        end

        -- Check for tile maps.
        local layerIsTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        -- Cache methods.
        local quantize = Utilities.quantizeUnsigned
        local cgeval = ClrGradient.eval
        local toHex = Clr.toHex
        local blend = Clr.blendInternal
        local clrNew = Clr.new
        local tilesToImage = AseUtilities.tilesToImage

        local bkgClr = AseUtilities.aseColorToClr(aseBkgColor)
        local bkgHex = toHex(bkgClr)

        -- Problem where an iteration is lost when a gradient
        -- evaluate returns the background color. This could
        -- still happen as a result of mix, but minimize the
        -- chances by filtering out background inputs.
        local filtered = {}
        local lenAseColors = #aseColors
        local k = 0
        while k < lenAseColors do k = k + 1
            local aseColor = aseColors[k]
            if aseColor.alpha > 0
                and aseColor.rgbaPixel ~= bkgHex then
                filtered[#filtered + 1] = aseColor
            end
        end

        local gradient = GradientUtilities.aseColorsToClrGradient(filtered)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        -- Find frames from target.
        local frames = AseUtilities.getFrames(activeSprite, target)

        -- For auto alpha fade.
        -- The clr needs to be blended with the background.
        local alphaEnd = 1.0
        local alphaStart = 1.0
        if iterations > 1 then
            alphaEnd = 1.0 / (iterations + 1.0)
            alphaStart = 1.0 - alphaEnd
        end

        if reverseFade then
            local swap = alphaEnd
            alphaEnd = alphaStart
            alphaStart = swap
        end

        local itr2 = iterations + iterations
        local itrPoint = Point(iterations, iterations)

        -- Convert iterations to a factor given to gradient.
        local toFac = 1.0
        if iterations > 1 then
            toFac = 1.0 / (iterations - 1.0)
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLyr = activeSprite:newLayer()
        trgLyr.parent = srcLayer.parent
        trgLyr.opacity = srcLayer.opacity
        trgLyr.name = "Gradient.Outline." .. clrSpacePreset

        -- Calculate colors in an outer loop, to
        -- reduce penalty for high frame count.
        local hexesOutline = {}
        local h = 0
        while h < iterations do
            local fac = h * toFac
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            h = h + 1

            local clr = cgeval(gradient, fac, mixFunc)
            if alphaFade then
                local a = (1.0 - fac) * alphaStart
                    + fac * alphaEnd
                clr = clrNew(clr.r, clr.g, clr.b, a)
            end

            -- This needs to be blended whether or not
            -- alpha fade is on auto, because colors
            -- from shades may contain alpha as well.
            clr = blend(bkgClr, clr)
            local otlHex = toHex(clr)
            hexesOutline[h] = otlHex
        end

        -- Wrapping this while loop in a transaction
        -- causes problems with undo history.
        local lenFrames = #frames
        local g = 0
        while g < lenFrames do g = g + 1
            local srcFrame = frames[g]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if layerIsTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                local specSrc = srcImg.spec
                local wTrg = specSrc.width + itr2
                local hTrg = specSrc.height + itr2
                local specTrg = {
                    width = wTrg,
                    height = hTrg,
                    colorMode = specSrc.colorMode,
                    transparentColor = specSrc.transparentColor
                }
                specTrg.colorSpace = specSrc.colorSpace
                local trgImg = Image(specTrg)
                trgImg:drawImage(srcImg, itrPoint)

                h = 0
                while h < iterations do h = h + 1
                    -- Read image must be separate from target.
                    local hexOut = hexesOutline[h]
                    local readImg = trgImg:clone()
                    local readPxItr = readImg:pixels()
                    for pixel in readPxItr do
                        local cRead = pixel()
                        if (cRead & 0xff000000) == 0x0
                            or cRead == bkgHex then
                            -- Loop through matrix, check neighbors
                            -- against background. There's no need to
                            -- tally up neighbor marks; just draw a
                            -- pixel, then break the loop.
                            local xRead = pixel.x
                            local yRead = pixel.y

                            local j = 0
                            local continue = true
                            while continue and j < activeCount do
                                j = j + 1
                                local offset = activeOffsets[j]
                                local yNbr = yRead + offset[2]
                                if yNbr >= 0 and yNbr < hTrg then
                                    local xNbr = xRead + offset[1]
                                    if xNbr >= 0 and xNbr < wTrg then
                                        local cNbr = readImg:getPixel(xNbr, yNbr)
                                        if (cNbr & 0xff000000) ~= 0x0
                                            and cNbr ~= bkgHex then
                                            trgImg:drawPixel(xRead, yRead, hexOut)
                                            continue = false
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                app.transaction(function()
                    local trgCel = activeSprite:newCel(
                        trgLyr, srcFrame, trgImg,
                        srcCel.position - itrPoint)
                    trgCel.opacity = srcCel.opacity
                end)
            end
        end

        app.refresh()

        if printElapsed then
            endTime = os.time()
            elapsed = os.difftime(endTime, startTime)
            local txtArr = {
                string.format("Start: %d", startTime),
                string.format("End: %d", endTime),
                string.format("Elapsed: %d", elapsed),
            }
            app.alert { title = "Diagnostic", text = txtArr }
        end
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