dofile("../../support/gradientutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    iterations = 16,
    alphaFade = false,
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
    color = Color(0, 0, 0, 0)
}

dlg:newrow { always = false }

dlg:check {
    id = "alphaFade",
    label = "Alpha:",
    text = "Auto Fade",
    selected = defaults.alphaFade
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
                text = "There is no active sprite." }
            return
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported." }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer." }
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local alphaFade = args.alphaFade
        local clrSpacePreset = args.clrSpacePreset
        local aseColors = args.shades
        local levels = args.quantize
        local aseBkgColor = args.bkgColor
        local iterations = args.iterations or defaults.iterations

        -- Create matrices.
        -- Directions need to be flipped on x and y axes.
        local activeMatrix = {
            args.m00, args.m01, args.m02,
            args.m10, args.m12,
            args.m20, args.m21, args.m22 }
        local dirMatrix = {
            { 1, 1 }, { 0, 1 }, { -1, 1 },
            { 1, 0 }, { -1, 0 },
            { 1, -1 }, { 0, -1 }, { -1, -1 } }

        local activeOffsets = {}
        -- local diagStrs = {}
        for i = 1, #activeMatrix, 1 do
            if activeMatrix[i] then
                table.insert(activeOffsets, dirMatrix[i])
                -- table.insert(diagStrs,
                --     string.format("(%d, %d)",
                --         dirMatrix[i][1], dirMatrix[i][2]))
            end
        end
        -- print(table.concat(diagStrs, ", "))
        local activeCount = #activeOffsets

        if activeCount < 1 then
            app.alert {
                title = "Error",
                text = "Neighbor matrix is empty." }
            return
        end

        -- Tile map layers may be present in 1.3 beta.
        local layerIsTilemap = false
        local tileSet = nil
        local version = app.version
        if version.major >= 1 and version.minor >= 3 then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        -- Find frames from target.
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
            local i = 0
            while i < rangeFramesLen do i = i + 1
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            local i = 0
            while i < activeFramesLen do i = i + 1
                frames[i] = activeFrames[i]
            end
        end

        -- Cache methods.
        local quantize = Utilities.quantizeUnsigned
        local cgeval = ClrGradient.eval
        local toHex = Clr.toHex
        local blend = Clr.blendInternal
        local clrNew = Clr.new
        local tilesToImage = AseUtilities.tilesToImage

        -- For auto alpha fade.
        -- The clr needs to be blended with the background.
        local alphaEnd = 0.0
        if iterations > 1 then
            alphaEnd = 1.0 / (iterations - 1.0)
        end
        local alphaStart = 1.0 - alphaEnd
        local bkgClr = AseUtilities.aseColorToClr(aseBkgColor)
        local bkgHex = toHex(bkgClr)
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
        if srcLayer.opacity then
            trgLyr.opacity = srcLayer.opacity
        end
        trgLyr.name = "Gradient.Outline." .. clrSpacePreset

        -- Calculate colors in an outer loop, so
        -- high frame count pentalty is reduced.
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
        local framesLen = #frames
        local g = 0
        while g < framesLen do g = g + 1
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
                trgImg:clear(bkgHex)
                trgImg:drawImage(srcImg, itrPoint)

                h = 0
                while h < iterations do h = h + 1
                    -- Read image must be separate from target.
                    local hexOutline = hexesOutline[h]
                    local readImg = trgImg:clone()
                    local readPxItr = readImg:pixels()
                    for elm in readPxItr do
                        local cRead = elm()
                        if cRead == bkgHex then
                            -- Loop through matrix, check neighbors
                            -- against background. There's no need to
                            -- tally up neighbor marks; just draw a
                            -- pixel, then break the loop.
                            local j = 0
                            local continue = true
                            while j < activeCount and continue do
                                j = j + 1
                                local offset = activeOffsets[j]
                                local yRead = elm.y
                                local yNbr = yRead + offset[2]
                                if yNbr >= 0 and yNbr < hTrg then
                                    local xRead = elm.x
                                    local xNbr = xRead + offset[1]
                                    if xNbr >= 0 and xNbr < wTrg then
                                        local cNbr = readImg:getPixel(xNbr, yNbr)
                                        if cNbr ~= bkgHex then
                                            trgImg:drawPixel(xRead, yRead, hexOutline)
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
