dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }

local defaults <const> = {
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
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        -- Cache global methods to local.
        local abs <const> = math.abs
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strunpack <const> = string.unpack
        local strsub <const> = string.sub
        local tconcat <const> = table.concat
        local fromHex <const> = Clr.fromHexAbgr32
        local toHex <const> = Clr.toHex
        local sRgbToLab <const> = Clr.sRgbToSrLab2Internal
        local quantize <const> = Utilities.quantizeUnsigned
        local tilesToImage <const> = AseUtilities.tileMapToImage
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

        -- Account for linked cels which may have the same image.
        ---@type table<integer, Image>
        local premadeTrgImgs <const> = {}

        -- Used in naming transactions by frame.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcPos <const> = srcCel.position

                local origImg <const> = srcCel.image
                local srcImgId <const> = origImg.id
                local srcImg <const> = isTileMap
                    and tilesToImage(origImg, tileSet, colorMode)
                    or origImg

                local trgImg = premadeTrgImgs[srcImgId]
                if not trgImg then
                    -- Get unique hexadecimal values from image.
                    -- There's no need to preserve order.
                    ---@type table<integer, integer[]>
                    local hexesUnique <const> = {}

                    ---@type table<integer, number>
                    local lumDict <const> = {}
                    local minLum = 1.0
                    local maxLum = 0.0

                    local srcBytes <const> = srcImg.bytes
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local lenSrc <const> = wSrc * hSrc

                    local j = 0
                    while j < lenSrc do
                        local j4 <const> = j * 4
                        local abgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local idcs <const> = hexesUnique[abgr32]
                        if idcs then
                            idcs[#idcs + 1] = j
                        else
                            hexesUnique[abgr32] = { j }

                            -- For each unique abgr32, find the
                            -- minimum and maximum lightness.
                            if (abgr32 & 0xff000000) ~= 0 then
                                local c <const> = fromHex(abgr32)
                                -- Cheaper method:
                                -- local lum <const> = 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
                                local lum <const> = sRgbToLab(c).l * 0.01
                                if lum < minLum then minLum = lum end
                                if lum > maxLum then maxLum = lum end
                                lumDict[abgr32] = lum
                            else
                                lumDict[abgr32] = 0.0
                            end
                        end
                        j = j + 1
                    end

                    -- Normalize range if requested.
                    -- A color disc with uniform perceptual luminance
                    -- generated by Okhsl has a range of about 0.069.
                    local rangeLum <const> = abs(maxLum - minLum)
                    if useNormalize and rangeLum > 0.07 then
                        local invRangeLum <const> = 1.0 / rangeLum
                        for abgr32, lum in pairs(lumDict) do
                            if (abgr32 & 0xff000000) ~= 0 then
                                lumDict[abgr32] = (lum - minLum) * invRangeLum
                            else
                                lumDict[abgr32] = 0.0
                            end
                        end
                    end

                    ---@type string[]
                    local trgBytesArr <const> = {}

                    if useMixed then
                        for srcAbgr32, idcs in pairs(hexesUnique) do
                            local fac <const> = quantize(lumDict[srcAbgr32], levels)
                            local trgClr <const> = cgmix(gradient, fac, mixFunc)
                            local trgAbgr32 <const> = toHex(trgClr)

                            local mulAlpha <const> = ((srcAbgr32 >> 0x18 & 0xff) *
                                (trgAbgr32 >> 0x18 & 0xff)) // 255
                            local compAbgr32 <const> = mulAlpha > 0
                                and ((mulAlpha << 0x18) | (trgAbgr32 & 0x00ffffff))
                                or 0

                            local trgPack <const> = strpack("<I4", compAbgr32)
                            local lenIdcs <const> = #idcs
                            local k = 0
                            while k < lenIdcs do
                                k = k + 1
                                trgBytesArr[1 + idcs[k]] = trgPack
                            end
                        end
                    else
                        -- Cel position needs to be added to the dither,
                        -- otherwise there's flickering in animations as
                        -- the same image is translated across frames.
                        local xSrcPos <const> = srcPos.x
                        local ySrcPos <const> = srcPos.y

                        for srcAbgr32, idcs in pairs(hexesUnique) do
                            local fac <const> = lumDict[srcAbgr32]
                            local lenIdcs <const> = #idcs
                            local k = 0
                            while k < lenIdcs do
                                k = k + 1
                                local idx <const> = idcs[k]
                                local trgClr <const> = dither(gradient, fac,
                                    xSrcPos + idx % wSrc,
                                    ySrcPos + idx // wSrc)
                                local trgAbgr32 <const> = toHex(trgClr)

                                local mulAlpha <const> = ((srcAbgr32 >> 0x18 & 0xff) *
                                    (trgAbgr32 >> 0x18 & 0xff)) // 255
                                local compAbgr32 <const> = mulAlpha > 0
                                    and ((mulAlpha << 0x18) | (trgAbgr32 & 0x00ffffff))
                                    or 0

                                local trgPack <const> = strpack("<I4", compAbgr32)
                                trgBytesArr[1 + idx] = trgPack
                            end
                        end
                    end

                    trgImg = Image(srcSpec)
                    trgImg.bytes = tconcat(trgBytesArr)
                    premadeTrgImgs[srcImgId] = trgImg
                end

                transact(strfmt("Gradient Map %d", frIdx + frameUiOffset),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, frIdx, trgImg, srcPos)
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