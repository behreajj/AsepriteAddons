dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }

local defaults <const> = {
    target = "ACTIVE",
    normalize = false,
    pullFocus = true
}

local dlg <const> = Dialog { title = "Gradient Map" }

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

        -- Cache methods.
        local abs <const> = math.abs
        local min <const> = math.min
        local fromHex <const> = Clr.fromHex
        local toHex <const> = Clr.toHex
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local quantize <const> = Utilities.quantizeUnsigned
        local tilesToImage <const> = AseUtilities.tilesToImage
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        -- Unpack arguments.
        local args <const> = dlg.data
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local target <const> = args.target or defaults.target --[[@as string]]
        local useNormalize <const> = args.useNormalize --[[@as boolean]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local easPreset <const> = args.easPreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local aseColors <const> = args.shades --[=[@as Color[]]=]
        local levels <const> = args.quantize --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]

        -- Find frames from target.
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local useMixed <const> = stylePreset == "MIXED"
        local gradient <const> = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust <const> = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local dither <const> = GradientUtilities.ditherFromPreset(
            stylePreset, bayerIndex, ditherPath)
        local cgmix <const> = ClrGradient.eval

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
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

        local lenFrames <const> = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
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
                        fac = facAdjust(fac)
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
                        fac = facAdjust(fac)
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

                transact(
                    strfmt("Gradient Map %d", srcFrame),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, srcFrame, trgImg, srcPos)
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

dlg:show {
    autoscrollbars = true,
    wait = false
}