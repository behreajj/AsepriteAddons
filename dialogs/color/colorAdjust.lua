dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes = { "LAB", "LCH" }

local defaults = {
    target = "ACTIVE",
    mode = "LCH",
    lAdj = 0,
    cAdj = 0,
    hAdj = 0,
    aAdj = 0,
    bAdj = 0,
    alphaAdj = 0,
    contrast = 0,
    normalize = 0,
    lInvert = false,
    aInvert = false,
    bInvert = false,
    alphaInvert = false,
    pullFocus = false
}

local dlg = Dialog { title = "Adjust Color" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "normalize",
    label = "Normalize:",
    min = -100,
    max = 100,
    value = defaults.normalize
}

dlg:newrow { always = false }

dlg:slider {
    id = "contrast",
    label = "Contrast:",
    min = -100,
    max = 100,
    value = defaults.contrast
}

dlg:separator { id = "adjustSep" }

dlg:combobox {
    id = "mode",
    label = "Adjust:",
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args = dlg.data
        local isLch = args.mode == "LCH"
        local isLab = args.mode == "LAB"
        dlg:modify { id = "cAdj", visible = isLch }
        dlg:modify { id = "hAdj", visible = isLch }
        dlg:modify { id = "aAdj", visible = isLab }
        dlg:modify { id = "bAdj", visible = isLab }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lAdj",
    label = "Lightness:",
    min = -100,
    max = 100,
    value = defaults.lAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "cAdj",
    label = "Chroma:",
    min = -135,
    max = 135,
    value = defaults.cAdj,
    visible = defaults.mode == "LCH"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hAdj",
    label = "Hue:",
    min = -180,
    max = 180,
    value = defaults.hAdj,
    visible = defaults.mode == "LCH"
}

dlg:newrow { always = false }

dlg:slider {
    id = "aAdj",
    label = "Green-Red:",
    min = -220,
    max = 220,
    value = defaults.aAdj,
    visible = defaults.mode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "bAdj",
    label = "Blue-Yellow:",
    min = -220,
    max = 220,
    value = defaults.bAdj,
    visible = defaults.mode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "alphaAdj",
    label = "Alpha:",
    min = -255,
    max = 255,
    value = defaults.aAdj
}

dlg:separator { id = "invertSep" }

dlg:check {
    id = "lInvert",
    label = "Invert:",
    text = "L",
    selected = defaults.lInvert
}

dlg:check {
    id = "aInvert",
    text = "A",
    selected = defaults.aInvert
}

dlg:check {
    id = "bInvert",
    text = "B",
    selected = defaults.bInvert
}

dlg:newrow { always = false }

dlg:check {
    id = "alphaInvert",
    text = "Alpha",
    selected = defaults.alphaInvert
}

dlg:newrow { always = false }

dlg:button {
    id = "adjustButton",
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

        -- Unpack arguments.
        -- Get the range as soon as possible, before any changes
        -- cause it to be removed or updated.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local isSelect = target == "SELECTION"
        local frames = AseUtilities.getFrames(activeSprite, target)
        local lenFrames = #frames

        local srcLayer = app.activeLayer
        if not isSelect then
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
        end

        local oldMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }
        local activeSpec = activeSprite.spec

        if isSelect then
            local sel = AseUtilities.getSelection(activeSprite)
            local selBounds = sel.bounds
            local xSel = selBounds.x
            local ySel = selBounds.y

            local alphaIndex = activeSpec.transparentColor
            local selSpec = ImageSpec {
                width = math.max(1, selBounds.width),
                height = math.max(1, selBounds.height),
                colorMode = ColorMode.RGB,
                transparentColor = alphaIndex
            }
            selSpec.colorSpace = activeSpec.colorSpace

            -- Blit flatened sprite to image.
            local selFrame = app.activeFrame
                or activeSprite.frames[1]
            local selImage = Image(selSpec)
            selImage:drawSprite(
                activeSprite, selFrame, Point(-xSel, -ySel))

            -- Set pixels not in selection to alpha.
            local pxItr = selImage:pixels()
            for pixel in pxItr do
                local x = pixel.x + xSel
                local y = pixel.y + ySel
                if not sel:contains(x, y) then
                    pixel(alphaIndex)
                end
            end

            -- Create new layer and cel.
            srcLayer = activeSprite:newLayer()
            srcLayer.name = "Selection"
            activeSprite:newCel(
                srcLayer, selFrame,
                selImage, Point(xSel, ySel))
        end

        -- Check for tile map support.
        local isTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            isTilemap = srcLayer.isTilemap
            if isTilemap then
                tileSet = srcLayer.tileset
            end
        end

        local mode = args.mode or defaults.mode
        local lAdj = args.lAdj or defaults.lAdj
        local cAdj = args.cAdj or defaults.cAdj
        local hAdj = args.hAdj or defaults.hAdj
        local aAdj = args.aAdj or defaults.aAdj
        local bAdj = args.bAdj or defaults.bAdj
        local alphaAdj = args.alphaAdj or defaults.alphaAdj
        local contrast = args.contrast or defaults.contrast
        local normalize = args.normalize or defaults.normalize
        local lInvert = args.lInvert
        local aInvert = args.aInvert
        local bInvert = args.bInvert
        local alphaInvert = args.alphaInvert

        local useNormalize = normalize ~= 0
        local useContrast = contrast ~= 0
        local useLabInvert = bInvert or aInvert or lInvert
        local lAdjNonZero = lAdj ~= 0
        local alphaAdjNonZero = alphaAdj ~= 0
        local useLabAdj = mode == "LAB"
            and (lAdjNonZero
                or aAdj ~= 0
                or bAdj ~= 0
                or alphaAdjNonZero)
        local useLchAdj = mode == "LCH"
            and (lAdjNonZero
                or cAdj ~= 0
                or hAdj ~= 0
                or alphaAdjNonZero)

        -- Alpha invert is grouped with LAB invert, so
        -- the expectation is that it occurs after
        -- adjustment. Logically, though, alpha invert
        -- comes before.
        local alAdj01 = alphaAdj * 0.003921568627451
        if alphaInvert then alAdj01 = -alAdj01 end
        local normFac = normalize * 0.01
        local normGtZero = normFac > 0.0
        local normLtZero = normFac < 0.0
        local absNormFac = math.abs(normFac)
        local complNormFac = 1.0 - absNormFac
        local contrastFac = 1.0 + contrast * 0.01
        local hue01 = hAdj * 0.0027777777777778
        local aSign = 1.0
        local bSign = 1.0
        if aInvert then aSign = -1.0 end
        if bInvert then bSign = -1.0 end

        local trgLayer = activeSprite:newLayer()
        local srcLayerName = "Layer"
        if #srcLayer.name > 0 then
            srcLayerName = srcLayer.name
        end
        trgLayer.name = string.format(
            "%s.Adjusted", srcLayerName)
        trgLayer.parent = srcLayer.parent
        trgLayer.opacity = srcLayer.opacity
        trgLayer.blendMode = srcLayer.blendMode

        -- Cache methods used in loops.
        local abs = math.abs
        local tilesToImage = AseUtilities.tilesToImage
        local fromHex = Clr.fromHex
        local toHex = Clr.toHex

        local sRgbaToLab = Clr.sRgbToSrLab2
        local labTosRgba = Clr.srLab2TosRgb
        local labToLch = Clr.srLab2ToSrLch
        local lchToLab = Clr.srLchToSrLab2

        app.transaction(function()
            local i = 0
            while i < lenFrames do i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if isTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                    end

                    -- Find unique colors in image.
                    -- A cel image may contain only opaque pixels, but
                    -- occupy a small part of the canvas. Ensure that
                    -- there is always a zero key for alpha invert.
                    local srcPxItr = srcImg:pixels()
                    local srcDict = {}
                    for pixel in srcPxItr do
                        local h = pixel()
                        if (h & 0xff000000) == 0 then h = 0x0 end
                        srcDict[h] = true
                    end
                    srcDict[0x0] = true

                    -- Convert unique colors to CIE LAB.
                    -- Normalization should ignore transparent pixels.
                    local labDict = {}
                    local minLum = 100.0
                    local maxLum = 0.0
                    local sumLum = 0.0
                    local countLum = 0
                    for key, _ in pairs(srcDict) do
                        local srgb = fromHex(key)
                        local lab = sRgbaToLab(srgb)
                        labDict[key] = lab

                        if key ~= 0 then
                            local lum = lab.l
                            if lum < minLum then minLum = lum end
                            if lum > maxLum then maxLum = lum end
                            sumLum = sumLum + lum
                            countLum = countLum + 1
                        end
                    end

                    if useNormalize then
                        local rangeLum = abs(maxLum - minLum)
                        if rangeLum > 0.07 then
                            -- When factor is less than zero, the average lum
                            -- can be multiplied by the factor prior to the loop.
                            local avgLum = 50.0
                            if countLum > 0 then avgLum = sumLum / countLum end
                            avgLum = absNormFac * avgLum

                            -- When factor is greater than zero.
                            local tDenom = absNormFac * (100.0 / rangeLum)
                            local lumMintDenom = minLum * tDenom

                            local normDict = {}
                            for key, value in pairs(labDict) do
                                local lOld = value.l
                                local lNew = lOld
                                if key ~= 0 then
                                    if normGtZero then
                                        lNew = complNormFac * lOld
                                            + tDenom * lOld - lumMintDenom
                                    elseif normLtZero then
                                        lNew = complNormFac * lOld + avgLum
                                    end
                                end

                                normDict[key] = {
                                    l = lNew,
                                    a = value.a,
                                    b = value.b,
                                    alpha = value.alpha
                                }
                            end
                            labDict = normDict
                        end
                    end

                    if alphaInvert then
                        local aInvDict = {}
                        for key, value in pairs(labDict) do
                            aInvDict[key] = {
                                l = value.l,
                                a = value.a,
                                b = value.b,
                                alpha = 1.0 - value.alpha
                            }
                        end
                        labDict = aInvDict
                    end

                    if useContrast then
                        local contrDict = {}
                        for key, value in pairs(labDict) do
                            contrDict[key] = {
                                l = (value.l - 50.0) * contrastFac + 50.0,
                                a = value.a,
                                b = value.b,
                                alpha = value.alpha
                            }
                        end
                        labDict = contrDict
                    end

                    if useLabAdj then
                        local labAdjDict = {}
                        for key, value in pairs(labDict) do
                            local al = value.alpha
                            if al > 0.0 then al = al + alAdj01 end
                            labAdjDict[key] = {
                                l = value.l + lAdj,
                                a = value.a + aAdj,
                                b = value.b + bAdj,
                                alpha = al
                            }
                        end
                        labDict = labAdjDict
                    elseif useLchAdj then
                        local lchAdjDict = {}
                        for key, value in pairs(labDict) do
                            local lch = labToLch(
                                value.l,
                                value.a,
                                value.b,
                                value.alpha)
                            local al = lch.a
                            if al > 0.0 then al = al + alAdj01 end
                            lchAdjDict[key] = lchToLab(
                                lch.l + lAdj,
                                lch.c + cAdj,
                                lch.h + hue01, al)
                        end
                        labDict = lchAdjDict
                    end

                    if useLabInvert then
                        local labInvDict = {}
                        for key, value in pairs(labDict) do
                            local lNew = value.l
                            if lInvert then lNew = 100.0 - lNew end
                            labInvDict[key] = {
                                l = lNew,
                                a = value.a * aSign,
                                b = value.b * bSign,
                                alpha = value.alpha
                            }
                        end
                        labDict = labInvDict
                    end

                    -- Convert CIE LAB to sRGBA hexadecimal.
                    local trgDict = {}
                    for key, value in pairs(labDict) do
                        trgDict[key] = toHex(labTosRgba(
                            value.l, value.a, value.b,
                            value.alpha))
                    end

                    local srcPos = srcCel.position
                    local trgPos = srcPos
                    local trgImg = nil
                    if alphaInvert then
                        trgImg = Image(activeSpec)
                        trgImg:drawImage(srcImg, srcPos)
                        trgPos = Point(0, 0)
                    else
                        trgImg = srcImg:clone()
                    end

                    local trgPxItr = trgImg:pixels()
                    for pixel in trgPxItr do
                        local h = pixel()
                        if (h & 0xff000000) == 0 then h = 0x0 end
                        pixel(trgDict[h])
                    end

                    local trgCel = activeSprite:newCel(
                        trgLayer, srcFrame,
                        trgImg, trgPos)
                    trgCel.opacity = srcCel.opacity
                end
            end
        end)

        if isSelect then
            activeSprite:deleteLayer(srcLayer)
        end

        AseUtilities.changePixelFormat(oldMode)
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