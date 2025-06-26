dofile("../../../support/gradientutilities.lua")
dofile("../../../support/quantizeutilities.lua")
dofile("../../../support/octree.lua")

local ditherModes <const> = { "ONE_BIT", "PALETTE", "QUANTIZE" }
local areaTargets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local palTargets <const> = { "ACTIVE", "FILE", "PRESET" }
local greyMethods <const> = { "AVERAGE", "HSL", "HSV", "LUMINANCE" }

local defaults <const> = {
    -- Animated x, y offset for ordered dither:
    -- d4fe9fee58d8e3d4edd17cea96c30ad41422eafc
    -- Last commit for old version:
    -- 23e391771391d5ffaf3e7f2385389e4af7e84004
    ditherMode = "PALETTE",
    ditherPattern = "FLOYD_STEINBERG",
    alphaMode = "THRESHOLD",
    areaTarget = "ACTIVE",
    palTarget = "ACTIVE",
    palResource = "",
    threshold = 50,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    factor = 100,
    greyMethod = "LUMINANCE",
    bayerIndex = 2,
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Dither " }

dlg:combobox {
    id = "areaTarget",
    label = "Target:",
    option = defaults.areaTarget,
    options = areaTargets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "alphaMode",
    label = "Alpha:",
    option = defaults.alphaMode,
    options = QuantizeUtilities.ALPHA_MODES,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ditherPattern",
    label = "Pattern:",
    option = defaults.ditherPattern,
    options = QuantizeUtilities.DITHER_PATTERNS,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local ditherPattern <const> = args.ditherPattern
        local isCustom <const> = ditherPattern == "DITHER_CUSTOM"
        dlg:modify { id = "ditherPath", visible = isCustom }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "ditherPath",
    label = "File:",
    filetypes = AseUtilities.FILE_FORMATS_OPEN,
    basepath = app.fs.userDocsPath,
    focus = false,
    visible = defaults.ditherPattern == "DITHER_CUSTOM"
}

dlg:newrow { always = false }

dlg:slider {
    id = "factor",
    label = "Factor:",
    min = 0,
    max = 100,
    value = defaults.factor
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ditherMode",
    label = "Mode:",
    option = defaults.ditherMode,
    options = ditherModes,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local ditherMode <const> = args.ditherMode --[[@as string]]
        local palTarget <const> = args.palTarget --[[@as string]]

        local isQnt <const> = ditherMode == "QUANTIZE"
        local isOne <const> = ditherMode == "ONE_BIT"
        local isPal <const> = ditherMode == "PALETTE"

        local md <const> = args.levelsInput --[[@as string]]
        local isu <const> = md == "UNIFORM"
        local isnu <const> = md == "NON_UNIFORM"

        local unit <const> = args.unitsInput --[[@as string]]
        local isbit <const> = unit == "BITS"
        local isint <const> = unit == "INTEGERS"

        dlg:modify { id = "method", visible = isQnt }
        dlg:modify { id = "levelsInput", visible = isQnt }
        dlg:modify { id = "unitsInput", visible = isQnt }

        dlg:modify { id = "rBits", visible = isQnt and isnu and isbit }
        dlg:modify { id = "gBits", visible = isQnt and isnu and isbit }
        dlg:modify { id = "bBits", visible = isQnt and isnu and isbit }
        dlg:modify { id = "aBits", visible = isQnt and isnu and isbit }
        dlg:modify {
            id = "bitsUni",
            visible = isQnt and isu and isbit
        }

        dlg:modify { id = "rLevels", visible = isQnt and isnu and isint }
        dlg:modify { id = "gLevels", visible = isQnt and isnu and isint }
        dlg:modify { id = "bLevels", visible = isQnt and isnu and isint }
        dlg:modify { id = "aLevels", visible = isQnt and isnu and isint }
        dlg:modify {
            id = "levelsUni",
            visible = isQnt and isu and isint
        }

        dlg:modify { id = "oColor", visible = isOne }
        dlg:modify { id = "dColor", visible = isOne }
        dlg:modify { id = "greyMethod", visible = isOne }
        dlg:modify { id = "threshold", visible = isOne }

        dlg:modify { id = "palTarget", visible = isPal }
        dlg:modify {
            id = "palResource",
            visible = isPal and palTarget == "PRESET"
        }
        dlg:modify {
            id = "palFile",
            visible = isPal and palTarget == "FILE"
        }
        dlg:modify { id = "octCapacity", visible = isPal }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "oColor",
    label = "Colors:",
    color = app.preferences.color_bar.fg_color,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:color {
    id = "dColor",
    color = app.preferences.color_bar.bg_color,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "greyMethod",
    label = "Evaluate:",
    option = defaults.greyMethod,
    options = greyMethods,
    visible = defaults.ditherMode == "ONE_BIT",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:slider {
    id = "threshold",
    label = "Threshold:",
    min = 1,
    max = 99,
    value = defaults.threshold,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:newrow { always = false }

QuantizeUtilities.dialogWidgets(dlg,
    defaults.ditherMode == "QUANTIZE", false)

dlg:combobox {
    id = "palTarget",
    label = "Palette:",
    option = defaults.palTarget,
    options = palTargets,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local palTarget <const> = args.palTarget --[[@as string]]
        dlg:modify {
            id = "palResource",
            visible = palTarget == "PRESET"
        }
        dlg:modify {
            id = "palFile",
            visible = palTarget == "FILE"
        }
    end,
    visible = defaults.ditherMode == "PALETTE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palResource",
    text = defaults.palResource,
    visible = defaults.ditherMode == "PALETTE"
        and defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    basepath = app.fs.joinPath(app.fs.userConfigPath, "palettes"),
    visible = defaults.ditherMode == "PALETTE"
        and defaults.palTarget == "FILE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "octCapacity",
    label = "Capacity (2^n):",
    min = defaults.minCapacityBits,
    max = defaults.maxCapacityBits,
    value = defaults.octCapacityBits
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

        local cmRgb <const> = ColorMode.RGB
        local cmIsRgb <const> = colorMode == cmRgb
        if not cmIsRgb then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local args <const> = dlg.data
        local areaTarget <const> = args.areaTarget
            or defaults.areaTarget --[[@as string]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = areaTarget == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or areaTarget))
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

        local alphaMode <const> = args.alphaMode
            or defaults.alphaMode --[[@as string]]
        local ditherMode <const> = args.ditherMode
            or defaults.ditherMode --[[@as string]]
        local ditherPattern <const> = args.ditherPattern
            or defaults.ditherPattern --[[@as string]]
        local factor100 <const> = args.factor
            or defaults.factor --[[@as integer]]

        local factor <const> = factor100 * 0.01

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap and srcLayer.tileset then
            tileSet = srcLayer.tileset
        end

        -- Used in naming transactions by frame.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Cache global methods to local.
        local strfmt <const> = string.format
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local transact <const> = app.transaction
        local getBytes <const> = AseUtilities.getBytes
        local setBytes <const> = AseUtilities.setBytes

        local alphaFunc <const> = QuantizeUtilities.alphaFuncFromPreset(
            alphaMode)
        local dither <const> = QuantizeUtilities.ditherFuncFromPreset(
            ditherPattern)

        local bayerIndex <const> = defaults.bayerIndex
        local ditherPath <const> = args.ditherPath --[[@as string]]

        local matrix <const>,
        cols <const>,
        rows <const> = GradientUtilities.ditherMatrixFromPreset(
            ditherPattern, bayerIndex, ditherPath)

        -- String that is assigned to new layer name to clarify operation.
        local dmStr = ""

        -- Unlike color quantize, dither cannot set zero alpha pixels to clear
        -- black because it relies on comparison with neighbors. Excess clear
        -- black distorts accuracy of color comparison.
        ---@param r8Src integer
        ---@param g8Src integer
        ---@param b8Src integer
        ---@param a8Src integer
        ---@return integer r8Trg
        ---@return integer g8Trg
        ---@return integer b8Trg
        ---@return integer a8Trg
        local closestFunc = function(r8Src, g8Src, b8Src, a8Src)
            return r8Src, g8Src, b8Src, alphaFunc(a8Src)
        end

        if ditherMode == "ONE_BIT" then
            local oColorAse <const> = args.oColor --[[@as Color]]
            local dColorAse <const> = args.dColor --[[@as Color]]
            local thresh100 <const> = args.threshold
                or defaults.threshold --[[@as integer]]
            local greyPreset <const> = args.greyMethod
                or defaults.greyMethod --[[@as string]]

            local or8 = oColorAse.red
            local og8 = oColorAse.green
            local ob8 = oColorAse.blue

            local dr8 = dColorAse.red
            local dg8 = dColorAse.green
            local db8 = dColorAse.blue

            if math.abs(or8 - dr8) <= 4
                and math.abs(og8 - dg8) <= 4
                and math.abs(ob8 - db8) <= 4 then
                app.alert {
                    title = "Error",
                    text = "Contrast too low between colors."
                }
                return
            end

            local greyMethod = function(r8Src, g8Src, b8Src) return 0.5 end
            local greyStr = ""
            if greyPreset == "AVERAGE" then
                -- In HSI, I = (r + g + b) / 3, S = 1 - min(r, g, b) / I.
                -- 3 * 255 = 765
                greyMethod = function(r8Src, g8Src, b8Src)
                    return (r8Src + g8Src + b8Src) / 765.0
                end
                greyStr = "Average"
            elseif greyPreset == "HSL" then
                -- 2 * 255 = 510
                greyMethod = function(r8Src, g8Src, b8Src)
                    return (math.max(r8Src, g8Src, b8Src)
                        + math.min(r8Src, g8Src, b8Src)) / 510.0
                end
                greyStr = "HSL"
            elseif greyPreset == "HSV" then
                greyMethod = function(r8Src, g8Src, b8Src)
                    return math.max(r8Src, g8Src, b8Src) / 255.0
                end
                greyStr = "HSV"
            else
                greyMethod = function(r8Src, g8Src, b8Src)
                    return (r8Src * 0.30 + g8Src * 0.59 + b8Src * 0.11) / 255.0
                end
                greyStr = "Luminance"
            end

            if greyMethod(or8, og8, ob8) > greyMethod(dr8, dg8, db8) then
                or8, og8, ob8, dr8, dg8, db8 = dr8, dg8, db8, or8, og8, ob8
            end

            -- print(string.format(
            --     "or8: %d, og8: %d, ob8: %d",
            --     or8, og8, ob8))
            -- print(string.format(
            --     "dr8: %d, dg8: %d, db8: %d",
            --     dr8, dg8, db8))

            local threshold <const> = thresh100 * 0.01
            closestFunc = function(r8Src, g8Src, b8Src, a8Src)
                local a8Trg <const> = alphaFunc(a8Src)
                if greyMethod(r8Src, g8Src, b8Src) >= threshold then
                    return dr8, dg8, db8, a8Trg
                end
                return or8, og8, ob8, a8Trg
            end

            dmStr = string.format("OneBit %s %03d", greyStr, thresh100)
        elseif ditherMode == "QUANTIZE" then
            -- These args come from QuantizeUtilities.
            local method <const> = args.method --[[@as string]]
            local rLevels = args.rLevels --[[@as integer]]
            local gLevels = args.gLevels --[[@as integer]]
            local bLevels = args.bLevels --[[@as integer]]

            local rDelta = 0.0
            local gDelta = 0.0
            local bDelta = 0.0

            local quantize = Utilities.quantizeUnsignedInternal

            if method == "UNSIGNED" then
                quantize = Utilities.quantizeUnsignedInternal

                rDelta = 1.0 / (rLevels - 1.0)
                gDelta = 1.0 / (gLevels - 1.0)
                bDelta = 1.0 / (bLevels - 1.0)
            else
                quantize = Utilities.quantizeSignedInternal

                rLevels = rLevels - 1
                gLevels = gLevels - 1
                bLevels = bLevels - 1

                rDelta = 1.0 / rLevels
                gDelta = 1.0 / gLevels
                bDelta = 1.0 / bLevels
            end

            local floor <const> = math.floor

            closestFunc = function(r8Src, g8Src, b8Src, a8Src)
                local a8Trg <const> = alphaFunc(a8Src)

                local rQtz <const> = quantize(r8Src / 255.0, rLevels, rDelta)
                local gQtz <const> = quantize(g8Src / 255.0, gLevels, gDelta)
                local bQtz <const> = quantize(b8Src / 255.0, bLevels, bDelta)

                return floor(rQtz * 255.0 + 0.5),
                    floor(gQtz * 255.0 + 0.5),
                    floor(bQtz * 255.0 + 0.5),
                    a8Trg
            end

            dmStr = string.format(
                "Quantized R%02d G%02d B%02d",
                rLevels, gLevels, bLevels)
        elseif ditherMode == "PALETTE" then
            local palTarget <const> = args.palTarget
                or defaults.palTarget --[[@as string]]
            local palFile <const> = args.palFile --[[@as string]]
            local palResource <const> = args.palResource
                or defaults.palResource --[[@as string]]
            local octCapacity = args.octCapacity
                or defaults.octCapacityBits --[[@as integer]]

            local hexesProfile <const>,
            hexesSrgb <const> = AseUtilities.asePaletteLoad(
                palTarget, palFile, palResource, 0, 512, true)

            octCapacity = 1 << octCapacity
            local octree <const> = Octree.new(
                BoundsLab.srLab2(), octCapacity, 1)

            -- Find minimum and maximum channel values.
            local lMin = 2147483647
            local aMin = 2147483647
            local bMin = 2147483647

            local lMax = -2147483648
            local aMax = -2147483648
            local bMax = -2147483648

            -- Cache methods to local.
            local distFunc <const> = Lab.distCylindrical
            local labHash <const> = Lab.toHexWrap64
            local fromHex <const> = Rgb.fromHexAbgr32
            local rgbnew <const> = Rgb.new
            local octins <const> = Octree.insert
            local octquery <const> = Octree.queryInternal
            local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal

            -- Unpack source palette to a dictionary and an octree.
            -- Ignore transparent colors in palette.
            local lenPalHexes <const> = #hexesSrgb
            ---@type table<integer, integer>
            local ptToHexDict <const> = {}
            local viableCount = 0
            local idxPalHex = 0
            while idxPalHex < lenPalHexes do
                idxPalHex = idxPalHex + 1
                local hexSrgb <const> = hexesSrgb[idxPalHex]
                if (hexSrgb & 0xff000000) ~= 0x0 then
                    local lab <const> = sRgbToLab(fromHex(hexSrgb))
                    local l <const> = lab.l
                    local a <const> = lab.a
                    local b <const> = lab.b

                    if l < lMin then lMin = l end
                    if a < aMin then aMin = a end
                    if b < bMin then bMin = b end

                    if l > lMax then lMax = l end
                    if a > aMax then aMax = a end
                    if b > bMax then bMax = b end

                    local hexProfile <const> = hexesProfile[idxPalHex]
                    ptToHexDict[labHash(lab)] = hexProfile
                    octins(octree, lab)
                    viableCount = viableCount + 1
                end
            end

            if viableCount < 3 then
                app.alert {
                    title = "Warning",
                    text = {
                        "The palette contains fewer than 3 viable colors.",
                        "For better results, use either one bit mode or",
                        "a bigger palette."
                    }
                }
                return
            end

            -- Find largest needed query radius and result limit.
            local lDiff <const> = lMax - lMin
            local aDiff <const> = aMax - aMin
            local bDiff <const> = bMax - bMin

            -- Square-root for this regularly seems too
            -- small, leading to transparent patches.
            local queryRad <const> = lDiff * lDiff
                + aDiff * aDiff
                + bDiff * bDiff

            Octree.cull(octree)
            closestFunc = function(r8Src, g8Src, b8Src, a8Src)
                local a8Trg <const> = alphaFunc(a8Src)
                local srgb <const> = rgbnew(
                    r8Src / 255.0,
                    g8Src / 255.0,
                    b8Src / 255.0,
                    1.0)
                local lab <const> = sRgbToLab(srgb)
                local nearPoint <const>, _ <const> = octquery(
                    octree, lab, queryRad, distFunc)

                local r8Trg, g8Trg, b8Trg = 0, 0, 0
                if nearPoint then
                    local nearHash <const> = labHash(nearPoint)
                    local nearHex <const> = ptToHexDict[nearHash]
                    if nearHex ~= nil then
                        r8Trg = nearHex & 0xff
                        g8Trg = (nearHex >> 0x08) & 0xff
                        b8Trg = (nearHex >> 0x10) & 0xff
                    end
                end

                return r8Trg, g8Trg, b8Trg, a8Trg
            end

            dmStr = "Palette"
        end

        -- Create a new layer, srcLayer should not be a group,
        -- and thus have an opacity and blend mode.
        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s Dither %s %03d",
                srcLayerName, dmStr, factor100)
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.blendMode = srcLayer.blendMode
                or BlendMode.NORMAL
        end)

        -- Account for linked cels which may have the same image.
        ---@type table<integer, Image>
        local premadeTrgImgs <const> = {}

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
                    and tilesToImage(origImg, tileSet, cmRgb)
                    or origImg
                local trgImg = premadeTrgImgs[srcImgId]

                if not trgImg then
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local srcBpp <const> = srcImg.bytesPerPixel
                    local trgPixels <const> = getBytes(srcImg)
                    dither(trgPixels, wSrc, hSrc, srcBpp,
                        matrix, cols, rows, srcPos.x, srcPos.y,
                        factor, closestFunc)
                    trgImg = Image(srcSpec)
                    setBytes(trgImg, trgPixels)
                    premadeTrgImgs[srcImgId] = trgImg
                end -- Target image not found.

                transact(strfmt("Dither %d", frIdx + frameUiOffset), function()
                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, srcPos)
                    trgCel.opacity = srcCel.opacity
                end)
            end -- End source cel exists.
        end     -- End frames loop.

        if removeSrcLayer then
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