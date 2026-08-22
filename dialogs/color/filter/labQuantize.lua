dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = { "LAB", "LCH" }

local defaults <const> = {
    target = "ACTIVE",
    mode = "LCH",

    lEnabled = true,
    cEnabled = true,
    hEnabled = true,
    aEnabled = true,
    bEnabled = true,

    lLevels = 16, -- unsigned
    cLevels = 16, -- unsigned
    hLevels = 16, -- signed
    aLevels = 16, -- signed
    bLevels = 16, -- signed

    lLevelsMin = 2,
    cLevelsMin = 2,
    hLevelsMin = 2,
    abLevelsMin = 2,

    lLevelsMax = 128,
    cLevelsMax = 128,
    hLevelsMax = 128,
    abLevelsMax = 128,

    printElapsed = false,
}

local dlg <const> = Dialog { title = "Quantize LAB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "mode",
    label = "Adjust:",
    focus = false,
    option = defaults.mode,
    options = modes,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data

        local mode <const> = args.mode --[[@as string]]
        local isLch <const> = mode == "LCH"
        local isLab <const> = mode == "LAB"

        dlg:modify { id = "cEnabled", visible = isLch }
        dlg:modify { id = "hEnabled", visible = isLch }
        dlg:modify { id = "aEnabled", visible = isLab }
        dlg:modify { id = "bEnabled", visible = isLab }

        dlg:modify { id = "lEnabled", selected = true }
        dlg:modify { id = "cEnabled", selected = isLch }
        dlg:modify { id = "hEnabled", selected = isLch }
        dlg:modify { id = "aEnabled", selected = isLab }
        dlg:modify { id = "bEnabled", selected = isLab }

        dlg:modify { id = "lLevels", visible = true }
        dlg:modify { id = "cLevels", visible = isLch }
        dlg:modify { id = "hLevels", visible = isLch }
        dlg:modify { id = "aLevels", visible = isLab }
        dlg:modify { id = "bLevels", visible = isLab }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "lEnabled",
    label = "Use:",
    text = "L",
    selected = defaults.lEnabled,
    focus = false,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local lEnabled <const> = args.lEnabled --[[@as boolean]]
        dlg:modify { id = "lLevels", visible = lEnabled }
    end
}

dlg:check {
    id = "cEnabled",
    text = "C",
    selected = defaults.cEnabled,
    focus = false,
    hexpand = false,
    visible = defaults.mode == "LCH",
    onclick = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local cEnabled <const> = args.cEnabled --[[@as boolean]]
        local isLch <const> = mode == "LCH"
        dlg:modify { id = "cLevels", visible = isLch and cEnabled }
    end
}

dlg:check {
    id = "hEnabled",
    text = "H",
    selected = defaults.hEnabled,
    focus = false,
    hexpand = false,
    visible = defaults.mode == "LCH",
    onclick = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local hEnabled <const> = args.hEnabled --[[@as boolean]]
        local isLch <const> = mode == "LCH"
        dlg:modify { id = "hLevels", visible = isLch and hEnabled }
    end
}

dlg:check {
    id = "aEnabled",
    text = "A",
    selected = defaults.aEnabled,
    focus = false,
    hexpand = false,
    visible = defaults.mode == "LAB",
    onclick = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local aEnabled <const> = args.aEnabled --[[@as boolean]]
        local isLab <const> = mode == "LAB"
        dlg:modify { id = "aLevels", visible = isLab and aEnabled }
    end
}

dlg:check {
    id = "bEnabled",
    text = "B",
    selected = defaults.bEnabled,
    focus = false,
    hexpand = false,
    visible = defaults.mode == "LAB",
    onclick = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local bEnabled <const> = args.bEnabled --[[@as boolean]]
        local isLab <const> = mode == "LAB"
        dlg:modify { id = "bLevels", visible = isLab and bEnabled }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lLevels",
    label = "L:",
    min = defaults.lLevelsMin,
    max = defaults.lLevelsMax,
    value = defaults.lLevels,
    focus = false,
    visible = defaults.lEnabled,
}

dlg:newrow { always = false }

dlg:slider {
    id = "cLevels",
    label = "C:",
    min = defaults.cLevelsMin,
    max = defaults.cLevelsMax,
    value = defaults.cLevels,
    focus = false,
    visible = defaults.mode == "LCH"
        and defaults.cEnabled,
}

dlg:newrow { always = false }

dlg:slider {
    id = "hLevels",
    label = "H:",
    min = defaults.hLevelsMin,
    max = defaults.hLevelsMax,
    value = defaults.hLevels,
    focus = false,
    visible = defaults.mode == "LCH"
        and defaults.hEnabled,
}

dlg:newrow { always = false }

dlg:slider {
    id = "aLevels",
    label = "A:",
    min = defaults.abLevelsMin,
    max = defaults.abLevelsMax,
    value = defaults.aLevels,
    focus = false,
    visible = defaults.mode == "LAB"
        and defaults.aEnabled,
}

dlg:newrow { always = false }

dlg:slider {
    id = "bLevels",
    label = "B:",
    min = defaults.abLevelsMin,
    max = defaults.abLevelsMax,
    value = defaults.bLevels,
    focus = false,
    visible = defaults.mode == "LAB"
        and defaults.bEnabled,
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]

        local lEnabled <const> = args.lEnabled --[[@as boolean]]
        local cEnabled <const> = args.cEnabled --[[@as boolean]]
        local hEnabled <const> = args.hEnabled --[[@as boolean]]
        local aEnabled <const> = args.aEnabled --[[@as boolean]]
        local bEnabled <const> = args.bEnabled --[[@as boolean]]

        local lLevels <const> = args.lLevels
            or defaults.lLevels --[[@as integer]]
        local cLevels <const> = args.cLevels
            or defaults.cLevels --[[@as integer]]
        local hLevels <const> = args.hLevels
            or defaults.hLevels --[[@as integer]]
        local aLevels <const> = args.aLevels
            or defaults.aLevels --[[@as integer]]
        local bLevels <const> = args.bLevels
            or defaults.bLevels --[[@as integer]]

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

        local useLchQuant <const> = mode == "LCH"
        if useLchQuant and (not lEnabled)
            and (not cEnabled)
            and (not hEnabled) then
            app.alert {
                title = "Error",
                text = "At least one color channel must be quantized."
            }
            return
        elseif (not lEnabled)
            and (not aEnabled)
            and (not bEnabled) then
            app.alert {
                title = "Error",
                text = "At least one color channel must be quantized."
            }
            return
        end

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        -- Cache methods used in loops.
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local transact <const> = app.transaction
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local labToLch <const> = Lab.toLch
        local lchToLab <const> = Lab.fromLch
        local labnew <const> = Lab.new
        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local quantizeSigned <const> = Utilities.quantizeSignedInternal
        local quantizeUnsigned <const> = Utilities.quantizeUnsignedInternal

        local lDelta <const> = lLevels ~= 1 and 1.0 / (lLevels - 1.0) or 0.0
        local cDelta <const> = cLevels ~= 1 and 1.0 / (cLevels - 1.0) or 0.0
        local hDelta <const> = hLevels ~= 0 and 1.0 / hLevels or 0.0
        local aDelta <const> = aLevels ~= 0 and 1.0 / aLevels or 0.0
        local bDelta <const> = bLevels ~= 0 and 1.0 / bLevels or 0.0

        ---@type table<integer, Lab>
        local abgr32ToLab <const> = {}

        local aMin = 2147483647
        local bMin = 2147483647
        local cMin = 2147483647

        local aMax = -2147483648
        local bMax = -2147483648
        local cMax = -2147483648

        local h = 0
        while h < lenFrIdcs do
            h = h + 1
            local frIdx <const> = frIdcs[h]
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
                local area <const> = wSrc * hSrc

                local i = 0
                while i < area do
                    local i4 <const> = i * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + i4, 4 + i4))
                    local srcLab = abgr32ToLab[srcAbgr32]
                    if not srcLab then
                        srcLab = sRgbToLab(fromHex(srcAbgr32))
                        abgr32ToLab[srcAbgr32] = srcLab
                    end

                    if srcLab.alpha > 0.0 then
                        local a <const> = srcLab.a
                        local b <const> = srcLab.b
                        local c <const> = sqrt(a * a + b * b)

                        if a < aMin then aMin = a end
                        if a > aMax then aMax = a end
                        if b < bMin then bMin = b end
                        if b > bMax then bMax = b end
                        if c < cMin then cMin = c end
                        if c > cMax then cMax = c end
                    end -- End non-zero source alpha.
                    i = i + 1
                end     -- End pixels loop.
            end         -- End source cel exists.
        end             -- End frames loop.

        local aRange <const> = aMax - aMin
        local aViable <const> = math.abs(aRange) > 0.0
        local aDenom <const> = aViable and 1.0 / aRange or 0.0
        -- print(strfmt("aMin: %.3f, aMax: %.3f, aRange: %.3f", aMin, aMax, aRange))

        local bRange <const> = bMax - bMin
        local bViable <const> = math.abs(bRange) > 0.0
        local bDenom <const> = bViable and 1.0 / bRange or 0.0
        -- print(strfmt("bMin: %.3f, bMax: %.3f, bRange: %.3f", bMin, bMax, bRange))

        local cRange <const> = cMax - cMin
        local cViable <const> = cRange > 0.0
        local cDenom <const> = cViable and 1.0 / cRange or 0.0

        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end

            local baseName <const> = strfmt("%s Quantized", srcLayerName)
            if mode == "LCH" then
                local name = baseName
                if lEnabled then name = name .. strfmt(" L%02d", lLevels) end
                if cEnabled then name = name .. strfmt(" C%02d", cLevels) end
                if hEnabled then name = name .. strfmt(" H%02d", hLevels) end
                trgLayer.name = name
            elseif mode == "LAB" then
                local name = baseName
                if lEnabled then name = name .. strfmt(" L%02d", lLevels) end
                if aEnabled then name = name .. strfmt(" A%02d", aLevels) end
                if bEnabled then name = name .. strfmt(" B%02d", bLevels) end
                trgLayer.name = name
            else
                trgLayer.name = baseName
            end

            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.blendMode = srcLayer.blendMode
                or BlendMode.NORMAL
        end)

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
                local area <const> = wSrc * hSrc

                ---@type string[]
                local trgByteArr <const> = {}
                local labZero <const> = labnew(0.0, 0.0, 0.0, 0.0)

                local j = 0
                while j < area do
                    local j4 <const> = j * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    local srcLab <const> = abgr32ToLab[srcAbgr32] or labZero
                    local trgAbgr32 = 0

                    if srcLab.alpha > 0.0 then
                        local lNorm <const> = srcLab.l * 0.01
                        local lq <const> = quantizeUnsigned(lNorm, lLevels, lDelta)

                        local trgLab = srcLab
                        if useLchQuant then
                            local srcLch <const> = labToLch(srcLab)
                            local cNorm <const> = cViable
                                and (srcLch.c - cMin) * cDenom
                                or 0.0
                            local hNorm <const> = srcLch.h

                            local cq <const> = quantizeUnsigned(cNorm, cLevels, cDelta)
                            local hq <const> = quantizeSigned(hNorm, hLevels, hDelta)

                            trgLab = lchToLab(
                                lEnabled and (lq * 100.0) or srcLch.l,
                                cEnabled and (cq * cRange + cMin) or srcLch.c,
                                hEnabled and hq or srcLch.h,
                                srcLch.a)
                        else
                            local aNorm <const> = aViable
                                and (srcLab.a - aMin) * aDenom
                                or 0.0
                            local bNorm <const> = bViable
                                and (srcLab.b - bMin) * bDenom
                                or 0.0

                            local aq <const> = quantizeSigned(aNorm, aLevels, aDelta)
                            local bq <const> = quantizeSigned(bNorm, bLevels, bDelta)

                            trgLab = labnew(
                                lEnabled and (lq * 100.0) or srcLab.l,
                                aEnabled and (aq * aRange + aMin) or srcLab.a,
                                bEnabled and (bq * bRange + bMin) or srcLab.b,
                                srcLab.alpha)
                        end -- End LCH vs. LAB mode.

                        trgAbgr32 = toHex(labTosRgb(trgLab))
                    end -- End non-zero source alpha.

                    j = j + 1
                    trgByteArr[j] = strpack("<I4", trgAbgr32)
                end -- End pixels loop.

                local trgImg <const> = Image(srcSpec)
                trgImg.bytes = tconcat(trgByteArr)

                transact(
                    strfmt("LAB Quantize %d", frIdx + frameUiOffset),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, frIdx, trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end -- End source cel exists.
        end     -- End frames loop.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        if printElapsed then
            AseUtilities.printElapsed(startTime)
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