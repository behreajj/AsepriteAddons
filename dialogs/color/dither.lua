dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local ditherModes = { "ONE_BIT", "PALETTE", "QUANTIZE" }
local greyMethods = { "AVERAGE", "HSL", "HSV", "LUMINANCE" }
local palTypes = { "ACTIVE", "FILE" }

local defaults = {
    target = "ACTIVE",
    ditherMode = "PALETTE",
    levels = 16,
    greyMethod = "LUMINANCE",
    threshold = 50,
    pullFocus = false,
    palType = "ACTIVE",
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    factor = 100,
    printElapsed = false,
}

local function fsDither(pxArray, srcWidth, srcHeight, factor, closestFunc)
    local pxLen = #pxArray
    local floor = math.floor

    local fs_1_16 = 0.0625 * factor
    local fs_3_16 = 0.1875 * factor
    local fs_5_16 = 0.3125 * factor
    local fs_7_16 = 0.4375 * factor

    local k = 0
    while k < pxLen do
        -- Calculate conversions from 1D to 2D indices.
        local x = k % srcWidth
        local y = k // srcWidth
        local yp1 = y + 1
        local xp1 = x + 1
        local xp1InBounds = xp1 < srcWidth
        local yp1InBounds = yp1 < srcHeight
        local yp1w = yp1 * srcWidth

        k = k + 1
        local srcHex = pxArray[k]
        local rSrc = srcHex & 0xff
        local gSrc = srcHex >> 0x08 & 0xff
        local bSrc = srcHex >> 0x10 & 0xff
        local aSrc = srcHex >> 0x18 & 0xff

        local trgHex = closestFunc(rSrc, gSrc, bSrc, aSrc)
        local rTrg = trgHex & 0xff
        local gTrg = trgHex >> 0x08 & 0xff
        local bTrg = trgHex >> 0x10 & 0xff
        pxArray[k] = trgHex

        -- Find difference between palette color and source color.
        local rErr = rSrc - rTrg
        local gErr = gSrc - gTrg
        local bErr = bSrc - bTrg

        -- Find right neighbor.
        if xp1InBounds then
            local k0 = 1 + xp1 + y * srcWidth
            local neighbor0 = pxArray[k0]

            local rne0 = (neighbor0 & 0xff) + floor(rErr * fs_7_16)
            local gne0 = (neighbor0 >> 0x08 & 0xff) + floor(gErr * fs_7_16)
            local bne0 = (neighbor0 >> 0x10 & 0xff) + floor(bErr * fs_7_16)

            if rne0 < 0 then rne0 = 0 elseif rne0 > 255 then rne0 = 255 end
            if gne0 < 0 then gne0 = 0 elseif gne0 > 255 then gne0 = 255 end
            if bne0 < 0 then bne0 = 0 elseif bne0 > 255 then bne0 = 255 end

            pxArray[k0] = neighbor0 & 0xff000000
                | bne0 << 0x10
                | gne0 << 0x08
                | rne0

            -- Find bottom-right neighbor.
            if yp1InBounds then
                local k3 = 1 + xp1 + yp1w
                local neighbor3 = pxArray[k3]

                local rne3 = (neighbor3 & 0xff) + floor(rErr * fs_1_16)
                local gne3 = (neighbor3 >> 0x08 & 0xff) + floor(gErr * fs_1_16)
                local bne3 = (neighbor3 >> 0x10 & 0xff) + floor(bErr * fs_1_16)

                if rne3 < 0 then rne3 = 0 elseif rne3 > 255 then rne3 = 255 end
                if gne3 < 0 then gne3 = 0 elseif gne3 > 255 then gne3 = 255 end
                if bne3 < 0 then bne3 = 0 elseif bne3 > 255 then bne3 = 255 end

                pxArray[k3] = neighbor3 & 0xff000000
                    | bne3 << 0x10
                    | gne3 << 0x08
                    | rne3
            end
        end

        -- Find bottom neighbor.
        if yp1InBounds then
            local k2 = 1 + x + yp1w
            local neighbor2 = pxArray[k2]

            local rne2 = (neighbor2 & 0xff) + floor(rErr * fs_5_16)
            local gne2 = (neighbor2 >> 0x08 & 0xff) + floor(gErr * fs_5_16)
            local bne2 = (neighbor2 >> 0x10 & 0xff) + floor(bErr * fs_5_16)

            if rne2 < 0 then rne2 = 0 elseif rne2 > 255 then rne2 = 255 end
            if gne2 < 0 then gne2 = 0 elseif gne2 > 255 then gne2 = 255 end
            if bne2 < 0 then bne2 = 0 elseif bne2 > 255 then bne2 = 255 end

            pxArray[k2] = neighbor2 & 0xff000000
                | bne2 << 0x10
                | gne2 << 0x08
                | rne2

            -- Find left neighbor.
            if x > 0 then
                local k1 = x + yp1w
                local neighbor1 = pxArray[k1]

                local rne1 = (neighbor1 & 0xff) + floor(rErr * fs_3_16)
                local gne1 = (neighbor1 >> 0x08 & 0xff) + floor(gErr * fs_3_16)
                local bne1 = (neighbor1 >> 0x10 & 0xff) + floor(bErr * fs_3_16)

                if rne1 < 0 then rne1 = 0 elseif rne1 > 255 then rne1 = 255 end
                if gne1 < 0 then gne1 = 0 elseif gne1 > 255 then gne1 = 255 end
                if bne1 < 0 then bne1 = 0 elseif bne1 > 255 then bne1 = 255 end

                pxArray[k1] = neighbor1 & 0xff000000
                    | bne1 << 0x10
                    | gne1 << 0x08
                    | rne1
            end
        end
    end
end

local dlg = Dialog { title = "Dither" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "ditherMode",
    label = "Mode:",
    option = defaults.ditherMode,
    options = ditherModes,
    onchange = function()
        local args = dlg.data
        local isQnt = args.ditherMode == "QUANTIZE"
        local isOne = args.ditherMode == "ONE_BIT"
        local isPal = args.ditherMode == "PALETTE"

        dlg:modify { id = "levels", visible = isQnt }

        dlg:modify { id = "aColor", visible = isOne }
        dlg:modify { id = "bColor", visible = isOne }
        dlg:modify { id = "greyMethod", visible = isOne }
        dlg:modify { id = "threshold", visible = isOne }

        local palType = dlg.data.palType
        dlg:modify { id = "palType", visible = isPal }
        dlg:modify {
            id = "palFile",
            visible = isPal and palType == "FILE"
        }
        dlg:modify { id = "octCapacity", visible = isPal }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = app.preferences.color_bar.fg_color,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:color {
    id = "bColor",
    color = app.preferences.color_bar.bg_color,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "greyMethod",
    label = "Evaluate:",
    option = defaults.greyMethod,
    options = greyMethods,
    visible = defaults.ditherMode == "ONE_BIT"
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

dlg:slider {
    id = "levels",
    label = "Levels:",
    min = 2,
    max = 96,
    value = defaults.levels,
    visible = defaults.ditherMode == "QUANTIZE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    onchange = function()
        local state = dlg.data.palType
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end,
    visible = defaults.ditherMode == "PALETTE"
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.ditherMode == "PALETTE"
        and defaults.palType == "FILE"
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

dlg:slider {
    id = "factor",
    label = "Factor:",
    min = 1,
    max = 100,
    value = defaults.factor
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
    focus = defaults.pullFocus,
    onclick = function()
        -- Begin timing the function elapsed.
        local args = dlg.data
        local printElapsed = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.clock()
        end

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

        -- Check for tile maps.
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        local oldMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local target = args.target or defaults.target --[[@as string]]
        local ditherMode = args.ditherMode
            or defaults.ditherMode --[[@as string]]
        local factor100 = args.factor or defaults.factor --[[@as integer]]

        local factor = factor100 * 0.01
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Choose function based on dither mode.
        local closestFunc = nil
        local dmStr = ""
        if ditherMode == "ONE_BIT" then
            local aColorAse = args.aColor --[[@as Color]]
            local bColorAse = args.bColor --[[@as Color]]
            local thresh100 = args.threshold
                or defaults.threshold --[[@as integer]]
            local greyPreset = args.greyMethod
                or defaults.greyMethod --[[@as string]]

            -- Mask out alpha, source alpha will be used.
            local aHex = 0x00ffffff & AseUtilities.aseColorToHex(
                aColorAse, ColorMode.RGB)
            local bHex = 0x00ffffff & AseUtilities.aseColorToHex(
                bColorAse, ColorMode.RGB)
            local threshold = thresh100 * 0.01

            -- Swap colors so that origin (a) is always the
            -- darker color.
            local aLum = Clr.lumsRgb(Clr.fromHex(aHex))
            local bLum = Clr.lumsRgb(Clr.fromHex(bHex))
            if aLum > bLum then aLum, bLum = bLum, aLum end

            local greyMethod = nil
            local greyStr = ""
            if greyPreset == "AVERAGE" then
                -- 3 * 255 = 765
                greyMethod = function(rSrc, gSrc, bSrc)
                    return (rSrc + gSrc + bSrc) * 0.0013071895424837
                end
                greyStr = "Average"
            elseif greyPreset == "HSL" then
                -- 2 * 255 = 510
                greyMethod = function(rSrc, gSrc, bSrc)
                    return (math.max(rSrc, gSrc, bSrc)
                        + math.min(rSrc, gSrc, bSrc)) * 0.0019607843137255
                end
                greyStr = "HSL"
            elseif greyPreset == "HSV" then
                greyMethod = function(rSrc, gSrc, bSrc)
                    return math.max(rSrc, gSrc, bSrc) * 0.003921568627451
                end
                greyStr = "HSV"
            else
                -- TODO: Phase out use of look up tables?
                local stlLut = Utilities.STL_LUT
                local ltsLut = Utilities.LTS_LUT
                greyMethod = function(rSrc, gSrc, bSrc)
                    local rLin = stlLut[1 + rSrc]
                    local gLin = stlLut[1 + gSrc]
                    local bLin = stlLut[1 + bSrc]
                    local lum = math.floor(
                        rLin * 0.21264934272065
                        + gLin * 0.7151691357059
                        + bLin * 0.072181521573443)
                    return ltsLut[1 + lum] * 0.003921568627451
                end
                greyStr = "Luminance"
            end

            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local fac = greyMethod(rSrc, gSrc, bSrc)
                local alpha = aSrc << 0x18
                if fac >= threshold then
                    return alpha | bHex
                end
                return alpha | aHex
            end

            dmStr = string.format("OneBit.%s.%03d", greyStr, thresh100)
        elseif ditherMode == "QUANTIZE" then
            local levels = args.levels
                or defaults.levels --[[@as integer]]

            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local srgb = Clr.new(
                    rSrc * 0.003921568627451,
                    gSrc * 0.003921568627451,
                    bSrc * 0.003921568627451,
                    1.0)
                local trgHex = Clr.toHex(Clr.quantize(srgb, levels))
                return (aSrc << 0x18) | (0x00ffffff & trgHex)
            end

            dmStr = string.format("Quantize.%03d", levels)
        else
            local palType = args.palType or defaults.palType --[[@as string]]
            local palFile = args.palFile --[[@as string]]
            local octCapacity = args.octCapacity
                or defaults.octCapacityBits --[[@as integer]]

            local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 256, true)

            octCapacity = 1 << octCapacity
            local bounds = Bounds3.lab()
            local octree = Octree.new(bounds, octCapacity, 1)

            -- Find minimum and maximum channel values.
            local lMin = 2147483647
            local aMin = 2147483647
            local bMin = 2147483647

            local lMax = -2147483648
            local aMax = -2147483648
            local bMax = -2147483648

            -- Cache methods to local.
            local fromHex = Clr.fromHex
            local sRgbaToLab = Clr.sRgbToSrLab2
            local v3new = Vec3.new
            local v3hash = Vec3.hashCode
            local octins = Octree.insert

            -- Unpack source palette to a dictionary and an octree.
            -- Ignore transparent colors in palette.
            local lenPalHexes = #hexesSrgb
            ---@type table<integer, integer>
            local ptToHexDict = {}
            local viableCount = 0
            local idxPalHex = 0
            while idxPalHex < lenPalHexes do
                idxPalHex = idxPalHex + 1
                local hexSrgb = hexesSrgb[idxPalHex]
                if (hexSrgb & 0xff000000) ~= 0x0 then
                    local clr = fromHex(hexSrgb)
                    local lab = sRgbaToLab(clr)
                    local l = lab.l
                    local a = lab.a
                    local b = lab.b
                    local point = v3new(a, b, l)

                    if l < lMin then lMin = l end
                    if a < aMin then aMin = a end
                    if b < bMin then bMin = b end

                    if l > lMax then lMax = l end
                    if a > aMax then aMax = a end
                    if b > bMax then bMax = b end

                    local hexProfile = hexesProfile[idxPalHex]
                    ptToHexDict[v3hash(point)] = hexProfile
                    octins(octree, point)
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
            local lDiff = lMax - lMin
            local aDiff = aMax - aMin
            local bDiff = bMax - bMin

            -- Square-root for this regularly seems too
            -- small, leading to transparent patches.
            local queryRad = lDiff * lDiff
                + aDiff * aDiff
                + bDiff * bDiff

            local distFunc = function(a, b)
                local da = b.x - a.x
                local db = b.y - a.y
                return math.sqrt(da * da + db * db)
                    + math.abs(b.z - a.z)
            end

            Octree.cull(octree)
            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local srgb = Clr.new(
                    rSrc * 0.003921568627451,
                    gSrc * 0.003921568627451,
                    bSrc * 0.003921568627451,
                    1.0)
                local lab = Clr.sRgbToSrLab2(srgb)
                local query = Vec3.new(lab.a, lab.b, lab.l)
                local nearPoint, _ = Octree.queryInternal(
                    octree, query, queryRad, distFunc)

                local trgHex = 0x0
                if nearPoint then
                    local nearHash = Vec3.hashCode(nearPoint)
                    local nearHex = ptToHexDict[nearHash]
                    if nearHex ~= nil then
                        trgHex = (aSrc << 0x18)
                            | (nearHex & 0x00ffffff)
                    end
                end

                return trgHex
            end

            dmStr = "Palette"
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s.Dither.%s.%03d",
                srcLayerName, dmStr, factor100)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        -- Cache global methods.
        local tilesToImage = AseUtilities.tilesToImage
        local transact = app.transaction
        local strfmt = string.format

        local lenFrames = #frames
        local i = 0
        local rgbColorMode = ColorMode.RGB
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                local srcSpec = srcImg.spec
                local srcWidth = srcSpec.width
                local srcHeight = srcSpec.height

                local srcPxItr = srcImg:pixels()
                ---@type integer[]
                local arrSrcPixels = {}
                local idxRdPixels = 0
                for pixel in srcPxItr do
                    idxRdPixels = idxRdPixels + 1
                    arrSrcPixels[idxRdPixels] = pixel()
                end

                fsDither(arrSrcPixels, srcWidth, srcHeight, factor, closestFunc)

                local trgImg = Image(srcSpec)
                local trgPxItr = trgImg:pixels()
                local idxWtPixels = 0
                for pixel in trgPxItr do
                    idxWtPixels = idxWtPixels + 1
                    pixel(arrSrcPixels[idxWtPixels])
                end

                transact(
                    strfmt("Dither %d", srcFrame),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        AseUtilities.changePixelFormat(oldMode)
        app.refresh()

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
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

dlg:show { wait = false }