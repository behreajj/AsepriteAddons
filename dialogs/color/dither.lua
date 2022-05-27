dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")

local modes = { "ONE_BIT", "PALETTE", "QUANTIZE" }
local greyMethods = { "AVERAGE", "HSL", "HSV", "LUMINANCE" }

local defaults = {
    ditherMode = "PALETTE",
    levels = 16,
    aColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    bColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    greyMethod = "LUMINANCE",
    threshold = 50,
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    factor = 100,
    copyToLayer = true,
    printElapsed = false,
    pullFocus = false
}

local function fsDither(pxArray, srcWidth, srcHeight, factor, closestFunc)
    local pxLen = #pxArray
    local trunc = math.tointeger

    local fs_1_16 = 0.0625 * factor
    local fs_3_16 = 0.1875 * factor
    local fs_5_16 = 0.3125 * factor
    local fs_7_16 = 0.4375 * factor

    for k = 1, pxLen, 1 do
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

        -- Calculate conversions from 1D to 2D indices.
        local x = (k - 1) % srcWidth
        local y = (k - 1) // srcWidth
        local yp1 = y + 1
        local xp1 = x + 1
        local xp1InBounds = xp1 < srcWidth
        local yp1InBounds = yp1 < srcHeight
        local yp1w = yp1 * srcWidth

        -- Find right neighbor.
        if xp1InBounds then
            local k0 = 1 + xp1 + y * srcWidth
            local neighbor0 = pxArray[k0]

            local rne0 = (neighbor0 & 0xff) + trunc(rErr * fs_7_16)
            local gne0 = (neighbor0 >> 0x08 & 0xff) + trunc(gErr * fs_7_16)
            local bne0 = (neighbor0 >> 0x10 & 0xff) + trunc(bErr * fs_7_16)

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

                local rne3 = (neighbor3 & 0xff) + trunc(rErr * fs_1_16)
                local gne3 = (neighbor3 >> 0x08 & 0xff) + trunc(gErr * fs_1_16)
                local bne3 = (neighbor3 >> 0x10 & 0xff) + trunc(bErr * fs_1_16)

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

            local rne2 = (neighbor2 & 0xff) + trunc(rErr * fs_5_16)
            local gne2 = (neighbor2 >> 0x08 & 0xff) + trunc(gErr * fs_5_16)
            local bne2 = (neighbor2 >> 0x10 & 0xff) + trunc(bErr * fs_5_16)

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

                local rne1 = (neighbor1 & 0xff) + trunc(rErr * fs_3_16)
                local gne1 = (neighbor1 >> 0x08 & 0xff) + trunc(gErr * fs_3_16)
                local bne1 = (neighbor1 >> 0x10 & 0xff) + trunc(bErr * fs_3_16)

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

local dlg = Dialog { title = "Floyd-Steinberg Dither" }

dlg:combobox {
    id = "ditherMode",
    label = "Mode:",
    option = defaults.ditherMode,
    options = modes,
    onchange = function()
        local args = dlg.data
        local isQuant = args.ditherMode == "QUANTIZE"
        local isOne = args.ditherMode == "ONE_BIT"
        local isPalette = args.ditherMode == "PALETTE"

        dlg:modify { id = "levels", visible = isQuant }

        dlg:modify { id = "aColor", visible = isOne }
        dlg:modify { id = "bColor", visible = isOne }
        dlg:modify { id = "greyMethod", visible = isOne }
        dlg:modify { id = "threshold", visible = isOne }

        local palType = dlg.data.palType
        dlg:modify { id = "palType", visible = isPalette }
        dlg:modify {
            id = "palFile",
            visible = isPalette and palType == "FILE" }
        dlg:modify {
            id = "palPreset",
            visible = isPalette and palType == "PRESET" }
        dlg:modify { id = "octCapacity", visible = isPalette }
        dlg:modify { id = "octCapacity", visible = isPalette }
        dlg:modify { id = "startIndex", visible = isPalette }
        dlg:modify { id = "count", visible = isPalette }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor,
    visible = defaults.ditherMode == "ONE_BIT"
}

dlg:color {
    id = "bColor",
    color = defaults.bColor,
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
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType

        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
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

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.ditherMode == "PALETTE"
        and defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = defaults.ditherMode == "PALETTE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.count,
    visible = defaults.ditherMode == "PALETTE"
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
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print Diagnostic:",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local printElapsed = args.printElapsed
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.time() end

        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local srcCel = app.activeCel
        if not srcCel then
            app.alert("There is no active cel.")
            return
        end

        local startIndex = args.startIndex or defaults.startIndex
        local palCount = args.count or defaults.count
        local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            args.palType, args.palFile, args.palPreset,
            startIndex, palCount, true)

        local alphaIndex = activeSprite.transparentColor
        local colorSpace = activeSprite.colorSpace
        local oldColorMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        -- Choose function based on dither mode.
        local closestFunc = nil
        local ditherMode = args.ditherMode or defaults.ditherMode
        local dmStr = ""
        if ditherMode == "ONE_BIT" then

            local aColorAse = args.aColor or defaults.aColor
            local bColorAse = args.bColor or defaults.bColor
            local threshold100 = args.threshold or defaults.threshold
            local threshold = threshold100 * 0.01

            -- Mask out alpha so that source alpha
            -- can be composited in.
            local aHex = 0x00ffffff & aColorAse.rgbaPixel
            local bHex = 0x00ffffff & bColorAse.rgbaPixel

            -- Swap colors so that origin (a) is always the
            -- darker color.
            local aLum = Clr.lumsRgb(Clr.fromHex(aHex))
            local bLum = Clr.lumsRgb(Clr.fromHex(bHex))
            if aLum > bLum then
                local temp = aHex
                aHex = bHex
                bHex = temp
            end

            local greyPreset = args.greyMethod or defaults.greyMethod
            local greyMethod = nil
            local greyStr = ""
            if greyPreset == "AVERAGE" then
                -- 3 * 255 = 765
                greyStr = "Average"
                greyMethod = function(rSrc, gSrc, bSrc)
                    return (rSrc + gSrc + bSrc) * 0.0013071895424837
                end
            elseif greyPreset == "HSL" then
                -- 2 * 255 = 510
                greyStr = "HSL"
                greyMethod = function(rSrc, gSrc, bSrc)
                    return (math.max(rSrc, gSrc, bSrc)
                        + math.min(rSrc, gSrc, bSrc)) * 0.0019607843137255
                end
            elseif greyPreset == "HSV" then
                greyStr = "HSV"
                greyMethod = function(rSrc, gSrc, bSrc)
                    return math.max(rSrc, gSrc, bSrc) * 0.003921568627451
                end
            else
                greyStr = "Luminance"

                local stlLut = Utilities.STL_LUT
                local ltsLut = Utilities.LTS_LUT

                greyMethod = function(rSrc, gSrc, bSrc)
                    local rLin = stlLut[1 + rSrc]
                    local gLin = stlLut[1 + gSrc]
                    local bLin = stlLut[1 + bSrc]
                    local lum = math.tointeger(
                        rLin * 0.21264934272065
                        + gLin * 0.7151691357059
                        + bLin * 0.072181521573443)
                    return ltsLut[1 + lum] * 0.003921568627451
                end
            end

            dmStr = string.format("OneBit.%s.%03d", greyStr, threshold100)

            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local fac = greyMethod(rSrc, gSrc, bSrc)
                local alpha = aSrc << 0x18
                if fac >= threshold then
                    return alpha | bHex
                end
                return alpha | aHex
            end

        elseif ditherMode == "QUANTIZE" then

            local levels = args.levels or defaults.levels
            dmStr = string.format("Quantize.%03d", levels)

            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local srgb = Clr.new(
                    rSrc * 0.003921568627451,
                    gSrc * 0.003921568627451,
                    bSrc * 0.003921568627451,
                    1.0)
                local trgHex = Clr.toHex(Clr.quantize(srgb, levels))
                return (aSrc << 0x18) | (0x00ffffff & trgHex)
            end

        else
            dmStr = "Palette"

            local octCapacity = args.octCapacity
                or defaults.octCapacityBits
            octCapacity = 2 ^ octCapacity
            local bounds = Bounds3.cieLab()
            local octree = Octree.new(bounds, octCapacity, 1)

            -- Find minimum and maximum channel values.
            local lMin = 2147483647
            local aMin = 2147483647
            local bMin = 2147483647

            local lMax = -2147483648
            local aMax = -2147483648
            local bMax = -2147483648

            local viableCount = 0

            -- Cache methods to local.
            local fromHex = Clr.fromHex
            local sRgbaToLab = Clr.sRgbaToLab
            local v3new = Vec3.new
            local v3hash = Vec3.hashCode
            local octins = Octree.insert

            -- Unpack source palette to a dictionary and an octree.
            -- Ignore transparent colors in palette.
            local lenPalHexes = #hexesSrgb
            local ptToHexDict = {}
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

            -- for k,v in pairs(ptToHexDict) do
            --     print(string.format("%d %08X", k, v))
            -- end

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

            Octree.cull(octree)
            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local srgb = Clr.new(
                    rSrc * 0.003921568627451,
                    gSrc * 0.003921568627451,
                    bSrc * 0.003921568627451,
                    1.0)
                local lab = Clr.sRgbaToLab(srgb)
                local query = Vec3.new(lab.a, lab.b, lab.l)
                local nearPoint, _ = Octree.queryInternal(
                    octree, query, queryRad)

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

        end

        -- Cache pixels from iterator to an array.
        local srcImg = srcCel.image
        local srcPxItr = srcImg:pixels()
        local arrSrcPixels = {}
        local idxRdPixels = 0
        for elm in srcPxItr do
            idxRdPixels = idxRdPixels + 1
            arrSrcPixels[idxRdPixels] = elm()
        end

        -- Get arguments to pass to dithering method.
        local srcWidth = srcImg.width
        local srcHeight = srcImg.height
        local factor100 = args.factor or defaults.factor
        local factor = factor100 * 0.01
        fsDither(arrSrcPixels, srcWidth, srcHeight, factor, closestFunc)

        local trgSpec = ImageSpec {
            width = srcWidth,
            height = srcHeight,
            colorMode = ColorMode.RGB,
            transparentColor = alphaIndex
        }
        trgSpec.colorSpace = colorSpace
        local trgImg = Image(trgSpec)
        local trgPxItr = trgImg:pixels()
        local idxWtPixels = 0
        for elm in trgPxItr do
            idxWtPixels = idxWtPixels + 1
            elm(arrSrcPixels[idxWtPixels])
        end

        -- Either copy to new layer or reassign image.
        local copyToLayer = args.copyToLayer
        if copyToLayer then
            app.transaction(function()
                local srcLayer = srcCel.layer

                -- Copy layer.
                local trgLayer = activeSprite:newLayer()
                local srcLayerName = "Layer"
                if #srcLayer.name > 0 then
                    srcLayerName = srcLayer.name
                end
                trgLayer.name = string.format(
                    "%s.Dither.%s.%03d",
                    srcLayerName, dmStr, factor100)
                if srcLayer.opacity then
                    trgLayer.opacity = srcLayer.opacity
                end
                -- Do not copy blend mode.

                -- Copy cel.
                local frame = app.activeFrame or activeSprite.frames[1]
                local trgCel = activeSprite:newCel(
                    trgLayer, frame,
                    trgImg, srcCel.position)
                trgCel.opacity = srcCel.opacity
            end)
        else
            srcCel.image = trgImg
        end

        AseUtilities.changePixelFormat(oldColorMode)
        app.refresh()

        if printElapsed then
            endTime = os.time()
            elapsed = os.difftime(endTime, startTime)
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %d", startTime),
                    string.format("End: %d", endTime),
                    string.format("Elapsed: %d", elapsed)
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
