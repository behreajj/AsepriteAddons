dofile("../../support/aseutilities.lua")
dofile("../../support/clr.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
-- local grayHues = { "OMIT", "SHADING", "ZERO" }
local modes = { "LAB", "LCH" }

local defaults = {
    target = "RANGE",
    mode = "LCH",
    -- grayHue = "OMIT",
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
    copyToLayer = true,
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

dlg:newrow { always = false }

dlg:combobox {
    id = "mode",
    label = "Adjust:",
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args = dlg.data
        local isLch = args.mode == "LCH"
        local isLab = args.mode == "LAB"
        -- dlg:modify { id = "grayHue", visible = isLch }
        dlg:modify { id = "cAdj", visible = isLch }
        dlg:modify { id = "hAdj", visible = isLch }
        dlg:modify { id = "aAdj", visible = isLab }
        dlg:modify { id = "bAdj", visible = isLab }
    end
}

-- dlg:newrow { always = false }

-- dlg:combobox {
--     id = "grayHue",
--     label = "Grays:",
--     option = defaults.grayHue,
--     options = grayHues,
--     visible = defaults.mode == "LCH"
-- }

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

dlg:newrow { always = false }

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

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
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

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        -- Check version, if 1.3 then check tile map.
        local version = app.version
        local isTilemap = false
        local tileSet = nil
        if version.major >= 1 and version.minor >= 3 then
            isTilemap = srcLayer.isTilemap
            if isTilemap then
                tileSet = srcLayer.tileset
            end
        end

        -- Cache methods used in loops.
        local abs = math.abs
        local tilesToImage = AseUtilities.tilesToImage
        local fromHex = Clr.fromHex
        local sRgbaToLab = Clr.sRgbaToLab
        local labTosRgba = Clr.labTosRgba
        local toHex = Clr.toHex
        local labToLch = Clr.labToLch
        local lchToLab = Clr.lchToLab

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local mode = args.mode or defaults.mode
        -- local grayHue = args.grayHue or defaults.grayHue
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
        local copyToLayer = args.copyToLayer or isTilemap

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

        local normFac = normalize * 0.01
        local normGtZero = normFac > 0.0
        local normLtZero = normFac < 0.0
        local absNormFac = math.abs(normFac)
        local complNormFac = 1.0 - absNormFac
        local contrastFac = 1.0 + contrast * 0.01
        local alpha01 = alphaAdj * 0.003921568627451
        local hue01 = hAdj * 0.0027777777777778
        local aSign = 1.0
        local bSign = 1.0
        if aInvert then aSign = -1.0 end
        if bInvert then bSign = -1.0 end

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
            local h = 0
            while h < rangeFramesLen do h = h + 1
                frames[h] = rangeFrames[h]
            end
        else
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            local h = 0
            while h < activeFramesLen do h = h + 1
                frames[h] = activeFrames[h]
            end
        end

        -- Create a new layer if necessary.
        local trgLayer = nil
        if copyToLayer then
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s.Adjusted",
                srcLayerName)
            if srcLayer.opacity then
                trgLayer.opacity = srcLayer.opacity
            end
            if srcLayer.blendMode then
                trgLayer.blendMode = srcLayer.blendMode
            end
        end

        local oldMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local framesLen = #frames
        app.transaction(function()
            local i = 0
            while i < framesLen do i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if isTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                    end

                    -- Find unique colors in image.
                    local srcpxitr = srcImg:pixels()
                    local srcDict = {}
                    for elm in srcpxitr do
                        local hex = elm()
                        if (hex & 0xff000000) ~= 0 then
                            srcDict[hex] = true
                        end
                    end

                    -- Convert unique colors to CIE LAB.
                    local labDict = {}
                    local minLum = 100.0
                    local maxLum = 0.0
                    local sumLum = 0.0
                    local countLum = 0
                    for key, _ in pairs(srcDict) do
                        local srgb = fromHex(key)
                        local lab = sRgbaToLab(srgb)
                        labDict[key] = lab

                        local lum = lab.l
                        if lum < minLum then minLum = lum end
                        if lum > maxLum then maxLum = lum end
                        sumLum = sumLum + lum
                        countLum = countLum + 1
                    end

                    if useNormalize then
                        local rangeLum = abs(maxLum - minLum)
                        if rangeLum > 0.07 then
                            local avgLum = 50.0
                            if countLum > 0 then avgLum = sumLum / countLum end
                            local tDenom = absNormFac * (100.0 / rangeLum)
                            local lumMintDenom = minLum * tDenom
                            local normDict = {}
                            for key, value in pairs(labDict) do
                                local lOld = value.l
                                local lNew = lOld
                                if normGtZero then
                                    lNew = complNormFac * lOld
                                        + tDenom * lOld - lumMintDenom
                                elseif normLtZero then
                                    lNew = complNormFac * lOld
                                        + absNormFac * avgLum
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
                            labAdjDict[key] = {
                                l = value.l + lAdj,
                                a = value.a + aAdj,
                                b = value.b + bAdj,
                                alpha = value.alpha + alpha01
                            }
                        end
                        labDict = labAdjDict
                    end

                    if useLchAdj then
                        local lchAdjDict = {}
                        for key, value in pairs(labDict) do
                            local lch = labToLch(
                                value.l,
                                value.a,
                                value.b,
                                value.alpha)
                            lchAdjDict[key] = lchToLab(
                                lch.l + lAdj,
                                lch.c + cAdj,
                                lch.h + hue01,
                                lch.a + alpha01)
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

                    -- Convert CIE LAB to sRGBA hexadecimal.
                    local trgDict = {}
                    for key, value in pairs(labDict) do
                        trgDict[key] = toHex(labTosRgba(
                            value.l, value.a, value.b,
                            value.alpha))
                    end

                    -- Create image.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        local hex = elm()
                        if (hex & 0xff000000) ~= 0 then
                            elm(trgDict[hex])
                        elseif alphaInvert then
                            elm(0xff000000 | hex)
                        else
                            elm(0x0)
                        end
                    end

                    if copyToLayer then
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    else
                        srcCel.image = trgImg
                    end
                end
            end
        end)

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