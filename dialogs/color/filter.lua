dofile("../../support/aseutilities.lua")

local filterTypes <const> = { "BOX_BLUR", "KUWAHARA" }
local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    filterType = "KUWAHARA",
    target = "ACTIVE",
    delSrc = "NONE",
    kernelStep = 1,
    useTiled = false,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Filter" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "filterType",
    label = "Type:",
    option = defaults.filterType,
    options = filterTypes
}

dlg:newrow { always = false }

dlg:slider {
    id = "kernelStep",
    label = "Step:",
    min = 1,
    max = 8,
    value = defaults.kernelStep
}

dlg:newrow { always = false }

dlg:check {
    id = "useTiled",
    label = "Tiled:",
    selected = defaults.useTiled
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
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

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local delSrcStr <const> = args.delSrc
            or defaults.delSrc --[[@as string]]
        local filterType <const> = args.filterType
            or defaults.filterType --[[@as string]]
        local krnStep <const> = args.kernelStep
            or defaults.kernelStep --[[@as integer]]
        local useTiled <const> = args.useTiled --[[@as boolean]]

        -- Cache global methods.
        local fromHex <const> = Clr.fromHex
        local labToRgb <const> = Clr.srLab2TosRgb
        local rgbToLab <const> = Clr.sRgbToSrLab2Internal
        local sqrt <const> = math.sqrt
        local tilesToImage <const> = AseUtilities.tilesToImage
        local toHex <const> = Clr.toHex
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrames <const> = #frames

        local useBoxBlur <const> = filterType == "BOX_BLUR"
        local rgbColorMode <const> = ColorMode.RGB

        -- Calculate the size of the window/kernel.
        local wKrn <const> = 1 + krnStep * 2
        local krnLen <const> = wKrn * wKrn
        local bbToAverage <const> = 1.0 / krnLen

        -- Create SRLAB2 dictionary outside of while loop
        -- to minimize re-calculation of SR LAB2 colors for
        -- similar images across multiple frames.
        ---@type table<integer, {l: number, a: number, b: number, alpha: number}>
        local labDict <const> = {}
        labDict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

        -- Specific to Kuwahara.
        local wKrnHalf <const> = wKrn // 2
        local quadSize <const> = math.ceil(wKrn * 0.5)
        local wQuadn1 <const> = quadSize - 1
        local quadLen <const> = quadSize * quadSize
        local kToAverage <const> = 1.0 / quadLen
        ---@type {l: number, a: number, b: number, alpha: number}[][]
        local quadrants <const> = { {}, {}, {}, {} }
        ---@type {l: number, a: number, b: number, alpha: number}[]
        local averages <const> = {
            { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 },
            { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 },
            { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 },
            { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
        }

        -- Create a new layer, srcLayer should not be a group,
        -- and thus have an opacity and blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s %s %d",
                srcLayerName, filterType, wKrn)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                ---@type integer[]
                local pxArr <const> = {}
                local lenPxArr = 0
                local srcPixels <const> = srcImg:pixels()
                for srcPixel in srcPixels do
                    local hex <const> = srcPixel()
                    lenPxArr = lenPxArr + 1
                    pxArr[lenPxArr] = hex
                    if not labDict[hex] then
                        labDict[hex] = rgbToLab(fromHex(hex))
                    end
                end

                local srcSpec <const> = srcImg.spec
                local wImg <const> = srcSpec.width
                local hImg <const> = srcSpec.height

                local trgImg <const> = Image(srcSpec)
                local trgPixels <const> = trgImg:pixels()

                if useBoxBlur then
                    for trgPixel in trgPixels do
                        -- When the kernel is out of bounds, sample
                        -- the central color, but do not tally alpha.
                        local xSrc <const> = trgPixel.x
                        local ySrc <const> = trgPixel.y
                        local iSrc <const> = xSrc + ySrc * wImg

                        local labSrc <const> = labDict[pxArr[1 + iSrc]]
                        local labClear <const> = {
                            l = labSrc.l,
                            a = labSrc.a,
                            b = labSrc.b,
                            alpha = 0.0
                        }

                        -- Subtract step to center the kernel
                        -- in the inner for loop.
                        local xtl <const> = xSrc - krnStep
                        local ytl <const> = ySrc - krnStep

                        local lSum = 0.0
                        local aSum = 0.0
                        local bSum = 0.0
                        local tSum = 0.0

                        local j = 0
                        while j < krnLen do
                            local xSample <const> = xtl + (j % wKrn)
                            local ySample <const> = ytl + (j // wKrn)

                            local labSample = labClear
                            if useTiled then
                                local iSample <const> = (xSample % wImg)
                                    + (ySample % hImg) * wImg
                                labSample = labDict[pxArr[1 + iSample]]
                            elseif ySample >= 0 and ySample < hImg
                                and xSample >= 0 and xSample < wImg then
                                local iSample <const> = xSample + ySample * wImg
                                labSample = labDict[pxArr[1 + iSample]]
                            end

                            lSum = lSum + labSample.l
                            aSum = aSum + labSample.a
                            bSum = bSum + labSample.b
                            tSum = tSum + labSample.alpha

                            j = j + 1
                        end

                        local srgb <const> = labToRgb(
                            lSum * bbToAverage,
                            aSum * bbToAverage,
                            bSum * bbToAverage,
                            tSum * bbToAverage)
                        trgPixel(toHex(srgb))
                    end
                else
                    -- Kuwahara filter.
                    for trgPixel in trgPixels do
                        local xSrc <const> = trgPixel.x
                        local ySrc <const> = trgPixel.y
                        local iSrc <const> = xSrc + ySrc * wImg

                        local labSrc <const> = labDict[pxArr[1 + iSrc]]
                        local labClear <const> = {
                            l = labSrc.l,
                            a = labSrc.a,
                            b = labSrc.b,
                            alpha = 0.0
                        }

                        local lMinStdIdx = 2147483647
                        local aMinStdIdx = 2147483647
                        local bMinStdIdx = 2147483647
                        local tMinStdIdx = 2147483647

                        local lMinStd = 2147483647
                        local aMinStd = 2147483647
                        local bMinStd = 2147483647
                        local tMinStd = 2147483647

                        local xtlWindow <const> = xSrc - wKrnHalf
                        local ytlWindow <const> = ySrc - wKrnHalf

                        local j = 0
                        while j < 4 do
                            local xGrid <const> = j % 2
                            local yGrid <const> = j // 2
                            local xtlQuad <const> = xtlWindow + xGrid * wQuadn1
                            local ytlQuad <const> = ytlWindow + yGrid * wQuadn1

                            j = j + 1
                            local quadrant <const> = quadrants[j]

                            local lSum = 0.0
                            local aSum = 0.0
                            local bSum = 0.0
                            local tSum = 0.0

                            local k = 0
                            while k < quadLen do
                                local xQuad <const> = k % quadSize
                                local yQuad <const> = k // quadSize
                                local xSample <const> = xtlQuad + xQuad
                                local ySample <const> = ytlQuad + yQuad

                                local labSample = labClear
                                if useTiled then
                                    local iSample <const> = (xSample % wImg)
                                        + (ySample % hImg) * wImg
                                    labSample = labDict[pxArr[1 + iSample]]
                                elseif ySample >= 0 and ySample < hImg
                                    and xSample >= 0 and xSample < wImg then
                                    local iSample <const> = xSample + ySample * wImg
                                    labSample = labDict[pxArr[1 + iSample]]
                                end

                                k = k + 1
                                quadrant[k] = labSample

                                lSum = lSum + labSample.l
                                aSum = aSum + labSample.a
                                bSum = bSum + labSample.b
                                tSum = tSum + labSample.alpha
                            end

                            -- Convert the sum to the arithmetic mean (average)
                            -- by dividing the sum by the number of elements.
                            local labAverage <const> = averages[j]
                            labAverage.l = lSum * kToAverage
                            labAverage.a = aSum * kToAverage
                            labAverage.b = bSum * kToAverage
                            labAverage.alpha = tSum * kToAverage

                            -- Find the standard deviation for the quadrant.
                            -- For each quadrant, subtract the arithmetic mean
                            -- from the sample. Square the difference. Sum the
                            -- squared differences. Divide the sums by the
                            -- the number of elements, then take the square root.
                            local lDevSqSum = 0.0
                            local aDevSqSum = 0.0
                            local bDevSqSum = 0.0
                            local tDevSqSum = 0.0

                            k = 0
                            while k < quadLen do
                                k = k + 1
                                local labSample <const> = quadrant[k]

                                local lDiff <const> = labSample.l - labAverage.l
                                local aDiff <const> = labSample.a - labAverage.a
                                local bDiff <const> = labSample.b - labAverage.b
                                local tDiff <const> = labSample.alpha - labAverage.alpha

                                lDevSqSum = lDevSqSum + lDiff * lDiff
                                aDevSqSum = aDevSqSum + aDiff * aDiff
                                bDevSqSum = bDevSqSum + bDiff * bDiff
                                tDevSqSum = tDevSqSum + tDiff * tDiff
                            end

                            local lStd <const> = sqrt(lDevSqSum * kToAverage)
                            local aStd <const> = sqrt(aDevSqSum * kToAverage)
                            local bStd <const> = sqrt(bDevSqSum * kToAverage)
                            local tStd <const> = sqrt(tDevSqSum * kToAverage)

                            if lStd < lMinStd then
                                lMinStd = lStd
                                lMinStdIdx = j
                            end

                            if aStd < aMinStd then
                                aMinStd = aStd
                                aMinStdIdx = j
                            end

                            if bStd < bMinStd then
                                bMinStd = bStd
                                bMinStdIdx = j
                            end

                            if tStd < tMinStd then
                                tMinStd = tStd
                                tMinStdIdx = j
                            end
                        end

                        -- In each color channel, find the index of the quadrant
                        -- with the minimum standard deviation. Take the average
                        -- from that quadrant.
                        local clrTrg <const> = labToRgb(
                            averages[lMinStdIdx].l,
                            averages[aMinStdIdx].a,
                            averages[bMinStdIdx].b,
                            averages[tMinStdIdx].alpha)
                        trgPixel(toHex(clrTrg))
                    end
                end

                transact(
                    strfmt("Filter %d", srcFrame),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        if delSrcStr == "HIDE" then
            srcLayer.isVisible = false
        elseif (not srcLayer.isBackground) then
            if delSrcStr == "DELETE_LAYER" then
                activeSprite:deleteLayer(srcLayer)
            elseif delSrcStr == "DELETE_CELS" then
                app.transaction("Delete Cels", function()
                    local idxDel = lenFrames + 1
                    while idxDel > 1 do
                        idxDel = idxDel - 1
                        local frame <const> = frames[idxDel]
                        local cel <const> = srcLayer:cel(frame)
                        if cel then activeSprite:deleteCel(cel) end
                    end
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

dlg:show {
    autoscrollbars = true,
    wait = false
}