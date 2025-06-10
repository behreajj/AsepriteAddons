dofile("../../../support/aseutilities.lua")

--[[Standardization is not the same as normalization.
For standardization, a range's average must be found,
then its standard deviation must be found:
sqrt ( sum( ( arr[i] - mean ) ^ 2 / len ) )
Then each element must be recalculated:
elm[i]' = (elm[i] - mean) / std .
]]

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = {
    "L_NORMALIZE",
    "LC_CONTRAST",
    "LS_CONTRAST",
}

local defaults <const> = {
    target = "ACTIVE",
    mode = "LS_CONTRAST",
    lNormalize = 0,
    lContrast = 0,
    cContrast = 0,
    sContrast = 0,
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Contrast" }

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "mode",
    label = "Mode:",
    focus = false,
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local useLNorm <const> = mode == "L_NORMALIZE"
        local useLcCtr <const> = mode == "LC_CONTRAST"
        local useLsCtr <const> = mode == "LS_CONTRAST"
        dlg:modify { id = "lNormalize", visible = useLNorm }
        dlg:modify { id = "lContrast", visible = useLcCtr or useLsCtr }
        dlg:modify { id = "cContrast", visible = useLcCtr }
        dlg:modify { id = "sContrast", visible = useLsCtr }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lNormalize",
    label = "Lightness:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.lNormalize,
    visible = defaults.mode == "L_NORMALIZE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "lContrast",
    label = "Lightness:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.lContrast,
    visible = defaults.mode == "LC_CONTRAST"
        or defaults.mode == "LS_CONTRAST"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cContrast",
    label = "Chroma:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.cContrast,
    visible = defaults.mode == "LC_CONTRAST"
}

dlg:newrow { always = false }

dlg:slider {
    id = "sContrast",
    label = "Saturation:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.sContrast,
    visible = defaults.mode == "LS_CONTRAST"
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
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
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]
        local lNormalizei <const> = args.lNormalize
            or defaults.lNormalize --[[@as integer]]
        local lContrasti <const> = args.lContrast
            or defaults.lContrast --[[@as integer]]
        local cContrasti <const> = args.cContrast
            or defaults.cContrast --[[@as integer]]
        local sContrasti <const> = args.sContrast
            or defaults.sContrast --[[@as integer]]

        local useLNorm <const> = mode == "L_NORMALIZE"
        local useLcCtr <const> = mode == "LC_CONTRAST"
        local useLsCtr <const> = mode == "LS_CONTRAST"

        if useLNorm
            and lNormalizei == 0 then
            return
        end

        if useLcCtr
            and lContrasti == 0
            and cContrasti == 0 then
            return
        end

        if useLsCtr
            and lContrasti == 0
            and sContrasti == 0 then
            return
        end

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrIdcs <const> = #frIdcs

        local srcLayer = site.layer --[[@as Layer]]
        local removeSrcLayer = false

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
            removeSrcLayer = true
        else
            if not srcLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
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

            if srcLayer.isGroup then
                app.transaction("Flatten Group", function()
                    srcLayer = AseUtilities.flattenGroup(
                        activeSprite, srcLayer, frIdcs)
                    removeSrcLayer = true
                end)
            end
        end

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage

        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local labTosRgba <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local labnew <const> = Lab.new

        local abs <const> = math.abs
        local sqrt <const> = math.sqrt

        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack

        local tconcat <const> = table.concat

        local lMin = 2147483647
        -- local cMin = 2147483647
        -- local sMin = 2147483647

        local lMax = -2147483648
        -- local cMax = -2147483648
        -- local sMax = -2147483648

        local lSum = 0.0
        local cSum = 0.0
        local sSum = 0.0
        local tally = 0

        ---@type table<integer, Lab>
        local abgr32ToLab <const> = {}
        local labZero <const> = {
            l = 0.0,
            a = 0.0,
            b = 0.0,
            alpha = 0.0
        }
        abgr32ToLab[0] = labZero

        ---@type Image[]
        local srcImgs <const> = {}
        ---@type integer[]
        local srcFrames <const> = {}
        ---@type Point[]
        local srcPoses <const> = {}
        ---@type integer[]
        local srcOpacities <const> = {}
        local lenSources = 0

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcImg = srcCel.image
                if isTileMap then
                    srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                end

                local srcBytes <const> = srcImg.bytes
                local srcSpec <const> = srcImg.spec
                local wSrc <const> = srcSpec.width
                local hSrc <const> = srcSpec.height
                local areaSrc <const> = wSrc * hSrc

                local j = 0
                while j < areaSrc do
                    local j4 <const> = j * 4
                    local abgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    if not abgr32ToLab[abgr32] then
                        abgr32ToLab[abgr32] = labZero
                        local t8 <const> = (abgr32 >> 0x18) & 0xff
                        if t8 > 0 then
                            local srgbSrc <const> = fromHex(abgr32)
                            local labSrc <const> = sRgbToLab(srgbSrc)
                            abgr32ToLab[abgr32] = labSrc

                            local l <const> = labSrc.l
                            if l < lMin then lMin = l end
                            if l > lMax then lMax = l end
                            lSum = lSum + l

                            local a <const> = labSrc.a
                            local b <const> = labSrc.b
                            local cSq <const> = a * a + b * b
                            local c <const> = sqrt(cSq)
                            -- if c < cMin then cMin = c end
                            -- if c > cMax then cMax = c end
                            cSum = cSum + c

                            local mcpl <const> = sqrt(cSq + l * l)
                            local s <const> = mcpl ~= 0.0
                                and c / mcpl
                                or 0.0
                            -- if s < sMin then sMin = s end
                            -- if s > sMax then sMax = s end
                            sSum = sSum + s

                            tally = tally + 1
                        end -- Not transparent.
                    end     -- Not in dictionary.

                    j = j + 1
                end -- End pixels loop.

                lenSources = lenSources + 1
                srcImgs[lenSources] = srcImg
                srcFrames[lenSources] = frIdx
                srcPoses[lenSources] = srcCel.position
                srcOpacities[lenSources] = srcCel.opacity
            end -- End cel exists.
        end     -- End frames loop.

        -- For normalizing lightness.
        local lGtZero <const> = lNormalizei > 0
        local lLtZero <const> = lNormalizei < 0
        local tNorm <const> = abs(lNormalizei * 0.01)
        local uNorm <const> = 1.0 - tNorm

        -- Only applicable for the positive factor.
        local lRange <const> = abs(lMax - lMin)
        local tlDenom <const> = lRange ~= 0.0
            and tNorm * 100.0 / lRange
            or tNorm
        local tlOff <const> = lRange ~= 0.0
            and lMin * tlDenom
            or 0.0

        -- Only applicable for negative factor.
        local lMean <const> = tally ~= 0.0 and lSum / tally or 0.0
        local tlMean <const> = tNorm * lMean

        -- For adjusting contrast.
        local lAdjVerif <const> = 1.0 + lContrasti * 0.01
        local cAdjVerif <const> = 1.0 + cContrasti * 0.01
        local sAdjVerif <const> = 1.0 + sContrasti * 0.01

        local lPivot <const> = 50.0
        local cPivot <const> = tally ~= 0.0 and cSum / tally or 0.0
        local sPivot <const> = tally ~= 0.0 and sSum / tally or 0.0
        -- Only relevant if you want to use the range as a pivot,
        -- not the arithmetic mean.
        -- local cRange <const> = abs(cMax - cMin)
        -- local sRange <const> = abs(sMax - sMin)

        -- Create target layer.
        app.transaction("Contrast Layer", function()
            local trgLayer <const> = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end

            if useLNorm then
                trgLayer.name = string.format(
                    "%s Normalize %d",
                    srcLayerName, lNormalizei)
            elseif useLcCtr then
                trgLayer.name = string.format(
                    "%s Contrast L %d C %d",
                    srcLayerName, lContrasti, cContrasti)
            elseif useLsCtr then
                trgLayer.name = string.format(
                    "%s Contrast L %d S %d",
                    srcLayerName, lContrasti, sContrasti)
            else
                trgLayer.name = string.format(
                    "%s Contrast", srcLayerName)
            end

            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            -- Do not copy blend mode, it only confuses things.

            ---@type table<integer, integer>
            local srcToTrg <const> = {}

            local k = 0
            while k < lenSources do
                k = k + 1

                local srcFrame <const> = srcFrames[k]
                local srcImg <const> = srcImgs[k]
                local srcPos <const> = srcPoses[k]
                local srcOpacity <const> = srcOpacities[k]

                local srcBytes <const> = srcImg.bytes
                local srcSpec <const> = srcImg.spec
                local wSrc <const> = srcSpec.width
                local hSrc <const> = srcSpec.height
                local area <const> = wSrc * hSrc

                ---@type string[]
                local trgByteArr <const> = {}

                local j = 0
                while j < area do
                    local j4 <const> = j * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    local trgAbgr32 = 0

                    if srcToTrg[srcAbgr32] then
                        trgAbgr32 = srcToTrg[srcAbgr32]
                    else
                        local srcLab <const> = abgr32ToLab[srcAbgr32]
                        local lSrc <const> = srcLab.l
                        local aSrc <const> = srcLab.a
                        local bSrc <const> = srcLab.b
                        local tSrc <const> = srcLab.alpha

                        local lTrg, aTrg, bTrg, tTrg = lSrc, aSrc, bSrc, tSrc

                        if useLNorm then
                            if lGtZero then
                                lTrg = uNorm * lSrc + tlDenom * lSrc - tlOff
                            elseif lLtZero then
                                lTrg = uNorm * lSrc + tlMean
                            end
                        elseif useLcCtr then
                            lTrg = (lSrc - lPivot) * lAdjVerif + lPivot

                            local csqSrc <const> = aSrc * aSrc + bSrc * bSrc
                            -- if csqSrc >= 0.1 then
                            local cSrc <const> = sqrt(csqSrc)
                            local cTrg <const> = (cSrc - cPivot) * cAdjVerif + cPivot

                            local aby <const> = cSrc ~= 0.0 and cTrg / cSrc or 0.0
                            aTrg = aSrc * aby
                            bTrg = bSrc * aby
                            -- end
                        elseif useLsCtr then
                            lTrg = (lSrc - lPivot) * lAdjVerif + lPivot

                            local csqSrc <const> = aSrc * aSrc + bSrc * bSrc
                            -- if csqSrc >= 0.1 then
                            local cSrc <const> = sqrt(csqSrc)
                            local mcplSrc <const> = sqrt(csqSrc + lSrc * lSrc)
                            local mcplAdj <const> = sqrt(csqSrc + lTrg * lTrg)
                            local sSrc <const> = mcplSrc ~= 0.0 and cSrc / mcplSrc or 0.0

                            local sTrg <const> = (sSrc - sPivot) * sAdjVerif + sPivot
                            local cTrg <const> = sTrg * mcplAdj

                            local aby <const> = cSrc ~= 0.0 and cTrg / cSrc or 0.0
                            aTrg = aSrc * aby
                            bTrg = bSrc * aby
                            -- end
                        end

                        local labTrg <const> = labnew(lTrg, aTrg, bTrg, tTrg)
                        trgAbgr32 = toHex(labTosRgba(labTrg))
                        srcToTrg[srcAbgr32] = trgAbgr32
                    end

                    j = j + 1
                    trgByteArr[j] = strpack("<I4", trgAbgr32)
                end -- End pixels loop.

                local trgImg <const> = Image(srcSpec)
                trgImg.bytes = tconcat(trgByteArr)

                local trgCel <const> = activeSprite:newCel(
                    trgLayer, srcFrame, trgImg, srcPos)
                trgCel.opacity = srcOpacity
            end -- End cels loop.

            app.layer = trgLayer
        end) --End transaction.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed)
                }
            }
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