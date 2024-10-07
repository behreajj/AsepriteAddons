dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }

local defaults <const> = {
    -- TODO: Add an elapsed time check box.
    target = "ACTIVE",
    normalize = false,
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Gradient Map" }

local gradient <const> = GradientUtilities.dialogWidgets(dlg, true)

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

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
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

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local useNormalize <const> = args.useNormalize --[[@as boolean]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrIdcs <const> = #frIdcs

        -- If isSelect is true, then a new layer will be created.
        local srcLayer = site.layer --[[@as Layer]]

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
        else
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
        end

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Cache global methods to local.
        local abs <const> = math.abs
        local min <const> = math.min
        local fromHex <const> = Clr.fromHexAbgr32
        local toHex <const> = Clr.toHex
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local quantize <const> = Utilities.quantizeUnsigned
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        local useMixed <const> = stylePreset == "MIXED"
        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local dither <const> = GradientUtilities.ditherFromPreset(
            stylePreset, bayerIndex, ditherPath)
        local cgmix <const> = ClrGradient.eval

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.name = "Gradient Map"
            if useMixed then
                trgLayer.name = trgLayer.name
                    .. " " .. clrSpacePreset
            end
            if useNormalize then
                trgLayer.name = trgLayer.name .. " Contrast"
            end
        end)

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local srcFrame <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcPos <const> = srcCel.position
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                ---@type table<integer, boolean>
                local srcHexDict <const> = {}
                local srcPxItr <const> = srcImg:pixels()
                for srcPixel in srcPxItr do
                    srcHexDict[srcPixel()] = true
                end

                ---@type table<integer, number>
                local lumDict <const> = {}
                local minLum = 1.0
                local maxLum = 0.0
                for srcHex, _ in pairs(srcHexDict) do
                    if (srcHex & 0xff000000) ~= 0 then
                        local srgb <const> = fromHex(srcHex)
                        local lab <const> = sRgbToLab(srgb)
                        local lum <const> = lab.l * 0.01
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
                local rangeLum <const> = abs(maxLum - minLum)
                if useNormalize and rangeLum > 0.07 then
                    local invRangeLum <const> = 1.0 / rangeLum
                    for hex, lum in pairs(lumDict) do
                        if (hex & 0xff000000) ~= 0 then
                            lumDict[hex] = (lum - minLum) * invRangeLum
                        else
                            lumDict[hex] = 0.0
                        end
                    end
                end

                local trgImg <const> = srcImg:clone()
                local trgPxItr <const> = trgImg:pixels()

                if useMixed then
                    ---@type table<integer, integer>
                    local trgHexDict <const> = {}
                    for srcHex, _ in pairs(srcHexDict) do
                        local fac = lumDict[srcHex]
                        fac = quantize(fac, levels)
                        local trgClr <const> = cgmix(
                            gradient, fac, mixFunc)

                        local trgHex <const> = toHex(trgClr)
                        local minAlpha <const> = min(
                            srcHex >> 0x18 & 0xff,
                            trgHex >> 0x18 & 0xff)
                        trgHexDict[srcHex] = (minAlpha << 0x18)
                            | (trgHex & 0x00ffffff)
                    end

                    for trgPixel in trgPxItr do
                        trgPixel(trgHexDict[trgPixel()])
                    end
                else
                    -- Cel position needs to be added to the dither,
                    -- otherwise there's flickering in animations as
                    -- the same image is translated across frames.
                    local xSrcPos <const> = srcPos.x
                    local ySrcPos <const> = srcPos.y
                    for trgPixel in trgPxItr do
                        local srcHex <const> = trgPixel()
                        local fac = lumDict[srcHex]
                        local trgClr <const> = dither(
                            gradient, fac,
                            xSrcPos + trgPixel.x,
                            ySrcPos + trgPixel.y)

                        local trgHex <const> = toHex(trgClr)
                        local minAlpha <const> = min(
                            srcHex >> 0x18 & 0xff,
                            trgHex >> 0x18 & 0xff)
                        trgPixel((minAlpha << 0x18)
                            | (trgHex & 0x00ffffff))
                    end
                end -- End mix type.

                transact(strfmt("Gradient Map %d", srcFrame),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, srcFrame, trgImg, srcPos)
                        trgCel.opacity = srcCel.opacity
                    end)
            end -- End cel exists check.
        end     -- End frames loop.

        if isSelect then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.layer = trgLayer
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