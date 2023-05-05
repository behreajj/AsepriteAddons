dofile("../../support/aseutilities.lua")

local filterTypes = { "BOX_BLUR", "KUWAHARA" }
local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
    filterType = "KUWAHARA",
    target = "ACTIVE",
    delSrc = "NONE",
    kernelStep = 1,
    useTiled = false,
    pullFocus = false
}

local dlg = Dialog { title = "Filter" }

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
    id = "usedTiled",
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
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

        local srcLayer = app.activeLayer --[[@as Layer]]
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
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target
            or defaults.target --[[@as string]]
        local delSrcStr = args.delSrc
            or defaults.delSrc --[[@as string]]
        local filterType = args.filterType
            or defaults.filterType --[[@as string]]
        local krnStep = args.kernelStep
            or defaults.kernelStep --[[@as integer]]
        local useTiled = args.useTiled --[[@as boolean]]

        -- Cache global methods.
        local fromHex = Clr.fromHex
        local labToRgb = Clr.srLab2TosRgb
        local rgbToLab = Clr.sRgbToSrLab2Internal
        local sqrt = math.sqrt
        local tilesToImage = AseUtilities.tilesToImage
        local toHex = Clr.toHex
        local strfmt = string.format
        local transact = app.transaction

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrames = #frames

        local useBoxBlur = filterType == "BOX_BLUR"
        local rgbColorMode = ColorMode.RGB

        -- Calculate the size of the window/kernel.
        local wKrn = 1 + krnStep * 2
        local krnLen = wKrn * wKrn
        local bbToAverage = 1.0 / krnLen

        -- Create SRLAB2 dictionary outside of while loop
        -- to minimize re-calculation of SR LAB2 colors for
        -- similar images across multiple frames.
        ---@type table<integer, table>
        local labDict = {}
        labDict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

        -- Specific to Kuwahara.
        local wKrnHalf = wKrn // 2
        local quadSize = math.ceil(wKrn * 0.5)
        local wQuadn1 = quadSize - 1
        local quadLen = quadSize * quadSize
        local kToAverage = 1.0 / quadLen
        local quadrants = { {}, {}, {}, {} }
        local averages = {
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
                "%s.%s.%d",
                srcLayerName, filterType, wKrn)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                ---@type integer[]
                local pxArr = {}
                local lenPxArr = 0
                local srcPixels = srcImg:pixels()
                for srcPixel in srcPixels do
                    local hex = srcPixel()
                    lenPxArr = lenPxArr + 1
                    pxArr[lenPxArr] = hex
                    if not labDict[hex] then
                        labDict[hex] = rgbToLab(fromHex(hex))
                    end
                end

                local srcSpec = srcImg.spec
                local wImg = srcSpec.width
                local hImg = srcSpec.height

                local trgImg = Image(srcSpec)
                local trgPixels = trgImg:pixels()

                if useBoxBlur then
                    for trgPixel in trgPixels do
                        -- When the kernel is out of bounds, sample
                        -- the central color, but do not tally alpha.
                        local xSrc = trgPixel.x
                        local ySrc = trgPixel.y
                        local iSrc = xSrc + ySrc * wImg

                        local labSrc = labDict[pxArr[1 + iSrc]]
                        local labClear = {
                            l = labSrc.l,
                            a = labSrc.a,
                            b = labSrc.b,
                            alpha = 0.0
                        }

                        -- Subtract step to center the kernel
                        -- in the inner for loop.
                        local xtl = xSrc - krnStep
                        local ytl = ySrc - krnStep

                        local lSum = 0.0
                        local aSum = 0.0
                        local bSum = 0.0
                        local tSum = 0.0

                        local j = 0
                        while j < krnLen do
                            local xSample = xtl + (j % wKrn)
                            local ySample = ytl + (j // wKrn)

                            local labSample = labClear
                            if ySample >= 0 and ySample < hImg
                                and xSample >= 0 and xSample < wImg then
                                local iSample = xSample + ySample * wImg
                                labSample = labDict[pxArr[1 + iSample]]
                            elseif useTiled then
                                local iSample = (xSample % wImg)
                                    + (ySample % hImg) * wImg
                                labSample = labDict[pxArr[1 + iSample]]
                            end

                            lSum = lSum + labSample.l
                            aSum = aSum + labSample.a
                            bSum = bSum + labSample.b
                            tSum = tSum + labSample.alpha

                            j = j + 1
                        end

                        local srgb = labToRgb(
                            lSum * bbToAverage,
                            aSum * bbToAverage,
                            bSum * bbToAverage,
                            tSum * bbToAverage)
                        trgPixel(toHex(srgb))
                    end
                else
                    for trgPixel in trgPixels do
                        local xSrc = trgPixel.x
                        local ySrc = trgPixel.y
                        local iSrc = xSrc + ySrc * wImg

                        local labSrc = labDict[pxArr[1 + iSrc]]
                        local labClear = {
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

                        local xtlWindow = xSrc - wKrnHalf
                        local ytlWindow = ySrc - wKrnHalf

                        local j = 0
                        while j < 4 do
                            local xGrid = j % 2
                            local yGrid = j // 2
                            local xtlQuad = xtlWindow + xGrid * wQuadn1
                            local ytlQuad = ytlWindow + yGrid * wQuadn1

                            j = j + 1
                            local quadrant = quadrants[j]

                            local lSum = 0.0
                            local aSum = 0.0
                            local bSum = 0.0
                            local tSum = 0.0

                            local k = 0
                            while k < quadLen do
                                local xQuad = k % quadSize
                                local yQuad = k // quadSize
                                local xSample = xtlQuad + xQuad
                                local ySample = ytlQuad + yQuad

                                local labSample = labClear
                                if ySample >= 0 and ySample < hImg
                                    and xSample >= 0 and xSample < wImg then
                                    local iSample = xSample + ySample * wImg
                                    labSample = labDict[pxArr[1 + iSample]]
                                elseif useTiled then
                                    local iSample = (xSample % wImg)
                                        + (ySample % hImg) * wImg
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
                            local labAverage = averages[j]
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
                                local labSample = quadrant[k]

                                local lDiff = labSample.l - labAverage.l
                                local aDiff = labSample.a - labAverage.a
                                local bDiff = labSample.b - labAverage.b
                                local tDiff = labSample.alpha - labAverage.alpha

                                lDevSqSum = lDevSqSum + lDiff * lDiff
                                aDevSqSum = aDevSqSum + aDiff * aDiff
                                bDevSqSum = bDevSqSum + bDiff * bDiff
                                tDevSqSum = tDevSqSum + tDiff * tDiff
                            end

                            local lStd = sqrt(lDevSqSum * kToAverage)
                            local aStd = sqrt(aDevSqSum * kToAverage)
                            local bStd = sqrt(bDevSqSum * kToAverage)
                            local tStd = sqrt(tDevSqSum * kToAverage)

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
                        local clrTrg = labToRgb(
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
                        local trgCel = activeSprite:newCel(
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
                        local frame = frames[idxDel]
                        local cel = srcLayer:cel(frame)
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

dlg:show { wait = false }