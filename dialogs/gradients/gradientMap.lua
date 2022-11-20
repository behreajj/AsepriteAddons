dofile("../../support/gradientutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    normalize = false,
    pullFocus = true
}

local dlg = Dialog { title = "Gradient Map" }

GradientUtilities.dialogWidgets(dlg)

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:check {
    id = "useNormalize",
    label = "Normalize:",
    text = "Stretch Contrast",
    selected = defaults.normalize
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

        -- Tile map layers may be present in 1.3 beta.
        local layerIsTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        -- QUERY: Necessary to switch to SR LAB 2?
        -- Cache methods and tables.
        local stlLut = Utilities.STL_LUT
        local lRgbToXyz = Clr.lRgbToCieXyzInternal
        local xyzToLab = Clr.cieXyzToLab
        local abs = math.abs
        local min = math.min
        local quantize = Utilities.quantizeUnsigned
        local tohex = Clr.toHex
        local cgeval = ClrGradient.eval
        local tilesToImage = AseUtilities.tilesToImage

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local useNormalize = args.useNormalize
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local levels = args.quantize  --[[@as integer]]
        local aseColors = args.shades --[[@as Color[] ]]

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        -- Find frames from target.
        local frames = AseUtilities.getFrames(activeSprite, target)

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer = activeSprite:newLayer()
        trgLayer.parent = srcLayer.parent
        trgLayer.opacity = srcLayer.opacity
        trgLayer.name = "Gradient.Map." .. clrSpacePreset
        if useNormalize then
            trgLayer.name = trgLayer.name .. ".Contrast"
        end

        app.transaction(function()
            local framesLen = #frames
            local i = 0
            while i < framesLen do i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if layerIsTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, colorMode)
                    end

                    -- Cache source colors.
                    local srcClrDict = {}
                    local srcItr = srcImg:pixels()
                    for srcClr in srcItr do
                        srcClrDict[srcClr()] = true
                    end

                    local srcAlphaDict = {}
                    local lumDict = {}
                    local minLum = 1.0
                    local maxLum = 0.0

                    -- Cache luminosities and source alphas in dictionaries.
                    for hex, _ in pairs(srcClrDict) do
                        local sai = hex >> 0x18 & 0xff
                        local lum = 0.0
                        if sai > 0 then
                            local sbi = hex >> 0x10 & 0xff
                            local sgi = hex >> 0x08 & 0xff
                            local sri = hex & 0xff

                            if sbi == sgi and sbi == sri then
                                lum = sbi * 0.003921568627451
                            else
                                -- Convert to linear via look up table.
                                local lbi = stlLut[1 + sbi]
                                local lgi = stlLut[1 + sgi]
                                local lri = stlLut[1 + sri]

                                local xyz = lRgbToXyz(
                                    lri * 0.003921568627451,
                                    lgi * 0.003921568627451,
                                    lbi * 0.003921568627451,
                                    1.0)
                                local lab = xyzToLab(xyz.x, xyz.y, xyz.z, 1.0)

                                lum = lab.l * 0.01
                            end

                            if lum < minLum then minLum = lum end
                            if lum > maxLum then maxLum = lum end
                        end

                        lumDict[hex] = lum
                        srcAlphaDict[hex] = sai
                    end

                    -- Normalize range if requested.
                    -- A color disc with uniform perceptual luminance
                    -- generated by Okhsl has a range of about 0.069.
                    local rangeLum = abs(maxLum - minLum)
                    if useNormalize and rangeLum > 0.07 then
                        local invRangeLum = 1.0 / rangeLum
                        for hex, lum in pairs(lumDict) do
                            if (hex & 0xff000000) ~= 0 then
                                lumDict[hex] = (lum - minLum) * invRangeLum
                            else
                                lumDict[hex] = 0.0
                            end
                        end
                    end

                    local trgClrDict = {}
                    for hex, _ in pairs(srcClrDict) do
                        local fac = lumDict[hex]
                        fac = facAdjust(fac)
                        fac = quantize(fac, levels)
                        local clrGray = cgeval(gradient, fac, mixFunc)
                        local hexGray = tohex(clrGray)

                        local aSrc = srcAlphaDict[hex]
                        local aTrg = (hexGray >> 0x18 & 0xff)

                        trgClrDict[hex] = min(aSrc, aTrg) << 0x18
                            | (0x00ffffff & hexGray)
                    end

                    -- Create cel.
                    local trgCel = activeSprite:newCel(trgLayer, srcCel.frame)
                    trgCel.position = srcCel.position
                    trgCel.image = srcImg:clone()
                    trgCel.opacity = srcCel.opacity

                    -- Assign color from gradient function.
                    local trgImg = trgCel.image
                    local trgItr = trgImg:pixels()
                    for trgClr in trgItr do
                        trgClr(trgClrDict[trgClr()])
                    end

                end
            end
        end)

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