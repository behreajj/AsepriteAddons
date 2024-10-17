dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    target = "ACTIVE",
    iterations = 1,
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
    pullFocus = true
}

local dlg <const> = Dialog { title = "Outline Gradient" }

local unfiltered <const> = GradientUtilities.dialogWidgets(dlg, false)

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
        local args <const> = dlg.data
        local alphaFade <const> = args.alphaFade --[[@as boolean]]

        dlg:modify {
            id = "reverseFade",
            visible = alphaFade
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
        -- TODO: Expose this option?
        local printElapsed <const> = false
        local startTime <const> = os.clock()

        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        local colorSpace <const> = activeSpec.colorSpace
        local alphaIndex <const> = activeSpec.transparentColor

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

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local alphaFade <const> = args.alphaFade --[[@as boolean]]
        local reverseFade <const> = args.reverseFade --[[@as boolean]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]
        local aseBkgColor <const> = args.bkgColor --[[@as Color]]
        local iterations <const> = args.iterations
            or defaults.iterations --[[@as integer]]

        -- Create matrices.
        -- Directions need to be flipped on x and y axes.

        ---@type boolean[]
        local activeMatrix <const> = {
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
        local dirMatrix <const> = {
            { 1, 1 }, { 0, 1 }, { -1, 1 },
            { 1, 0 }, { -1, 0 },
            { 1, -1 }, { 0, -1 }, { -1, -1 }
        }

        ---@type integer[][]
        local activeOffsets <const> = {}
        local activeCount = 0
        local m = 0
        while m < 8 do
            m = m + 1
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
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Used in naming transactions by frame.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Cache methods used in loop.
        local quantize <const> = Utilities.quantizeUnsigned
        local cgeval <const> = ClrGradient.eval
        local toHex <const> = Clr.toHex
        local blend <const> = Clr.blendInternal
        local clrNew <const> = Clr.new
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local transact <const> = app.transaction

        local bkgClr <const> = AseUtilities.aseColorToClr(aseBkgColor)
        local bkgHex <const> = toHex(bkgClr)

        -- Problem where an iteration is lost when a gradient
        -- evaluate returns the background color. This could
        -- still happen as a result of mix, but minimize the
        -- chances by filtering out background inputs.
        local gradient <const> = ClrGradient.opaque(unfiltered)

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

        -- Find frames from target.
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- For auto alpha fade.
        -- The clr needs to be blended with the background.
        local alphaEnd = 1.0
        local alphaStart = 1.0
        if iterations > 1 then
            alphaEnd = 1.0 / (iterations + 1.0)
            alphaStart = 1.0 - alphaEnd
        end

        if reverseFade then
            local swap <const> = alphaEnd
            alphaEnd = alphaStart
            alphaStart = swap
        end

        local itr2 <const> = iterations + iterations
        local alphaIndexVerif <const> = (colorMode ~= ColorMode.INDEXED
                or (alphaIndex >= 0 and alphaIndex < 256)) and
            alphaIndex or 0

        -- Convert iterations to a factor given to gradient.
        local toFac <const> = iterations > 1
            and 1.0 / (iterations - 1.0)
            or 1.0

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.name = "Gradient Outline " .. clrSpacePreset
        end)

        -- Calculate colors in an outer loop, to
        -- reduce penalty for high frame count.
        ---@type integer[]
        local hexesOutline <const> = {}
        local h = 0
        while h < iterations do
            local fac = h * toFac
            fac = quantize(fac, levels)
            h = h + 1

            local clr = cgeval(gradient, fac, mixFunc)
            if alphaFade then
                local a <const> = (1.0 - fac) * alphaStart
                    + fac * alphaEnd
                clr = clrNew(clr.r, clr.g, clr.b, a)
            end

            -- This needs to be blended whether or not alpha fade is on auto,
            -- because colors from shades may contain alpha as well.
            clr = blend(bkgClr, clr)
            local otlHex <const> = toHex(clr)
            hexesOutline[h] = otlHex
        end

        -- Wrapping this while loop in a transaction causes problems
        -- with undo history.
        local lenFrIdcs <const> = #frIdcs
        local g = 0
        while g < lenFrIdcs do
            g = g + 1
            local frIdx <const> = frIdcs[g]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcPos <const> = srcCel.position
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                local srcSpec <const> = srcImg.spec
                local srcByteStr <const> = srcImg.bytes
                local srcBpp <const> = srcImg.bytesPerPixel

                local wSrc <const> = srcSpec.width
                local hSrc <const> = srcSpec.height

                local unpackFmt <const> = "<I" .. srcBpp
                local wTrg <const> = wSrc + itr2
                local hTrg <const> = hSrc + itr2
                local areaTrg <const> = wTrg * hTrg

                ---@type integer[]
                local read = {}
                ---@type integer[]
                local write <const> = {}

                local i = 0
                while i < areaTrg do
                    local xSrc <const> = (i % wTrg) - iterations
                    local ySrc <const> = (i // wTrg) - iterations

                    local hex = alphaIndexVerif
                    if ySrc >= 0 and ySrc < hSrc
                        and xSrc >= 0 and xSrc < wSrc then
                        local jbpp <const> = (ySrc * wSrc + xSrc) * srcBpp
                        hex = strunpack(unpackFmt, strsub(srcByteStr,
                            1 + jbpp, srcBpp + jbpp))
                    end
                    i = i + 1
                    write[i] = hex
                end

                h = 0
                while h < iterations do
                    h = h + 1
                    local hexOut <const> = hexesOutline[h]

                    -- Copy write to read.
                    i = 0
                    while i < areaTrg do
                        i = i + 1
                        read[i] = write[i]
                    end

                    i = 0
                    while i < areaTrg do
                        local cRead <const> = read[1 + i]
                        -- TODO: Make this line and the neighbor line below
                        -- friendlier to any color mode?
                        if (cRead & 0xff000000) == 0x0
                            or cRead == bkgHex then
                            -- Loop through matrix, check neighbors against
                            -- background. There's no need to tally up
                            -- neighbor marks; just draw a pixel, then break
                            -- the loop.
                            local xRead <const> = i % wTrg
                            local yRead <const> = i // wTrg

                            local j = 0
                            local continue = true
                            while continue and j < activeCount do
                                j = j + 1
                                local offset <const> = activeOffsets[j]
                                local xNbr <const> = xRead + offset[1]
                                local yNbr <const> = yRead + offset[2]
                                if yNbr >= 0 and yNbr < hTrg
                                    and xNbr >= 0 and xNbr < wTrg then
                                    local cIdx <const> = yNbr * wTrg + xNbr
                                    local cNbr <const> = read[1 + cIdx]
                                    if (cNbr & 0xff000000) ~= 0x0
                                        and cNbr ~= bkgHex then
                                        write[1 + i] = hexOut
                                        continue = false
                                    end -- Neighbor not transparent check.
                                end     -- In bounds check.
                            end         -- Neighbors kernel.
                        end             -- Center transparent check.

                        i = i + 1
                    end -- End pixel loop.
                end     -- End Iterations loop.

                ---@type string[]
                local writeByteStrArr <const> = {}
                i = 0
                while i < areaTrg do
                    i = i + 1
                    writeByteStrArr[i] = strpack("<I4", write[i])
                end

                local trgSpec <const> = createSpec(wTrg, hTrg, colorMode,
                    colorSpace, alphaIndexVerif)
                local trgImg <const> = Image(trgSpec)
                trgImg.bytes = tconcat(writeByteStrArr)

                transact(
                    strfmt("Gradient Outline %d", frIdx + frameUiOffset),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, frIdx, trgImg,
                            Point(srcPos.x - iterations, srcPos.y - iterations))
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        app.layer = trgLayer
        app.refresh()

        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
            local txtArr <const> = {
                string.format("Start: %.2f", startTime),
                string.format("End: %.2f", endTime),
                string.format("Elapsed: %.6f", elapsed),
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

dlg:show {
    autoscrollbars = true,
    wait = false
}