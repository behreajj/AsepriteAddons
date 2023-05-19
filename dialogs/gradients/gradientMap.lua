dofile("../../support/gradientutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ACTIVE",
    normalize = false,
    pullFocus = true
}

local dlg = Dialog { title = "Gradient Map" }

GradientUtilities.dialogWidgets(dlg, true)

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
        local site = app.site
        local activeSprite = site.sprite
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

        local srcLayer = site.layer
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

        -- Cache methods.
        local abs = math.abs
        local min = math.min
        local fromHex = Clr.fromHex
        local toHex = Clr.toHex
        local sRgbToLab = Clr.sRgbToSrLab2
        local quantize = Utilities.quantizeUnsigned
        local tilesToImage = AseUtilities.tilesToImage
        local strfmt = string.format
        local transact = app.transaction

        -- Unpack arguments.
        local args = dlg.data
        local stylePreset = args.stylePreset --[[@as string]]
        local target = args.target or defaults.target --[[@as string]]
        local useNormalize = args.useNormalize --[[@as boolean]]
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local easPreset = args.easPreset --[[@as string]]
        local huePreset = args.huePreset --[[@as string]]
        local aseColors = args.shades --[=[@as Color[]]=]
        local levels = args.quantize --[[@as integer]]
        local bayerIndex = args.bayerIndex --[[@as integer]]
        local ditherPath = args.ditherPath --[[@as string]]

        -- Find frames from target.
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local useMixed = stylePreset == "MIXED"
        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local dither = GradientUtilities.ditherFromPreset(
            stylePreset, bayerIndex, ditherPath)
        local cgmix = ClrGradient.eval

        -- Check for tile maps.
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.name = "Gradient.Map"
            if useMixed then
                trgLayer.name = trgLayer.name
                    .. "." .. clrSpacePreset
            end
            if useNormalize then
                trgLayer.name = trgLayer.name .. ".Contrast"
            end
        end)

        local lenFrames = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                ---@type table<integer, boolean>
                local srcHexDict = {}
                local srcItr = srcImg:pixels()
                for srcHex in srcItr do
                    srcHexDict[srcHex()] = true
                end

                ---@type table<integer, number>
                local lumDict = {}
                local minLum = 1.0
                local maxLum = 0.0
                for srcHex, _ in pairs(srcHexDict) do
                    if (srcHex & 0xff000000) ~= 0 then
                        local srgb = fromHex(srcHex)
                        local lab = sRgbToLab(srgb)
                        local lum = lab.l * 0.01
                        if lum < minLum then minLum = lum end
                        if lum > maxLum then maxLum = lum end
                        lumDict[srcHex] = lum
                    else
                        lumDict[srcHex] = 0.0
                    end
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

                local trgImg = srcImg:clone()
                local trgPixelItr = trgImg:pixels()

                if useMixed then
                    ---@type table<integer, integer>
                    local trgHexDict = {}
                    for srcHex, _ in pairs(srcHexDict) do
                        local fac = lumDict[srcHex]
                        fac = facAdjust(fac)
                        fac = quantize(fac, levels)
                        local trgClr = cgmix(
                            gradient, fac, mixFunc)

                        local trgHex = toHex(trgClr)
                        local minAlpha = min(
                            srcHex >> 0x18 & 0xff,
                            trgHex >> 0x18 & 0xff)
                        trgHexDict[srcHex] = (minAlpha << 0x18)
                            | (trgHex & 0x00ffffff)
                    end

                    for trgPixel in trgPixelItr do
                        trgPixel(trgHexDict[trgPixel()])
                    end
                else
                    for trgPixel in trgPixelItr do
                        local srcHex = trgPixel()
                        local fac = lumDict[srcHex]
                        fac = facAdjust(fac)
                        local trgClr = dither(
                            gradient, fac,
                            trgPixel.x, trgPixel.y)

                        local trgHex = toHex(trgClr)
                        local minAlpha = min(
                            srcHex >> 0x18 & 0xff,
                            trgHex >> 0x18 & 0xff)
                        trgPixel((minAlpha << 0x18)
                            | (trgHex & 0x00ffffff))
                    end
                end -- End mix type.

                transact(
                    strfmt("Gradient Map %d", srcFrame),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame, trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end -- End cel exists check.
        end     -- End frames loop.

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