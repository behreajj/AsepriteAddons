dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")
dofile("../../support/clr.lua")


local modes = { "ONE_BIT", "PALETTE", "QUANTIZE" }

local defaults = {
    ditherMode = "PALETTE",
    levels = 16,
    aColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    bColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    threshold = 21, -- 50 needs gamma adjustment.
    palType = "ACTIVE",
    octCapacity = 16,
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

            local rn0 = neighbor0 & 0xff
            local gn0 = neighbor0 >> 0x08 & 0xff
            local bn0 = neighbor0 >> 0x10 & 0xff

            local rne0 = rn0 + trunc(rErr * fs_7_16)
            local gne0 = gn0 + trunc(gErr * fs_7_16)
            local bne0 = bn0 + trunc(bErr * fs_7_16)

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

                local rn3 = neighbor3 & 0xff
                local gn3 = neighbor3 >> 0x08 & 0xff
                local bn3 = neighbor3 >> 0x10 & 0xff

                local rne3 = rn3 + trunc(rErr * fs_1_16)
                local gne3 = gn3 + trunc(gErr * fs_1_16)
                local bne3 = bn3 + trunc(bErr * fs_1_16)

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

            local rn2 = neighbor2 & 0xff
            local gn2 = neighbor2 >> 0x08 & 0xff
            local bn2 = neighbor2 >> 0x10 & 0xff

            local rne2 = rn2 + trunc(rErr * fs_5_16)
            local gne2 = gn2 + trunc(gErr * fs_5_16)
            local bne2 = bn2 + trunc(bErr * fs_5_16)

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

                local rn1 = neighbor1 & 0xff
                local gn1 = neighbor1 >> 0x08 & 0xff
                local bn1 = neighbor1 >> 0x10 & 0xff

                local rne1 = rn1 + trunc(rErr * fs_3_16)
                local gne1 = gn1 + trunc(gErr * fs_3_16)
                local bne1 = bn1 + trunc(bErr * fs_3_16)

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
    id = "octCapacity",
    label = "Cell Capacity:",
    min = 3,
    max = 32,
    value = defaults.octCapacity,
    visible = defaults.ditherMode == "PALETTE"
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
        if printElapsed then
            startTime = os.time()
        end

        local sprite = app.activeSprite
        if sprite then

            local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                args.palType, args.palFile, args.palPreset)

            local srcCel = app.activeCel
            if srcCel then
                local srcImg = srcCel.image
                if srcImg ~= nil then

                    local oldColorMode = sprite.colorMode
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

                        dmStr = string.format("OneBit.%03d", threshold100)

                        -- Mask out alpha so that source alpha
                        -- can be composited in.
                        local aHex = 0x00ffffff & aColorAse.rgbaPixel
                        local bHex = 0x00ffffff & bColorAse.rgbaPixel

                        closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                            local srgb = Clr.new(
                                rSrc * 0.00392156862745098,
                                gSrc * 0.00392156862745098,
                                bSrc * 0.00392156862745098,
                                1.0)
                            local alpha = aSrc << 0x18
                            local lum = Clr.lumsRgb(srgb)
                            if lum >= threshold then
                                return alpha | bHex
                            end
                            return alpha | aHex
                        end

                    elseif ditherMode == "QUANTIZE" then

                        local levels = args.levels or defaults.levels
                        dmStr = string.format("Quantize.%03d", levels)

                        closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                            local srgb = Clr.new(
                                rSrc * 0.00392156862745098,
                                gSrc * 0.00392156862745098,
                                bSrc * 0.00392156862745098,
                                1.0)
                            local alpha = aSrc << 0x18
                            return alpha | Clr.toHex(Clr.quantize(srgb, levels))
                        end

                    else
                        dmStr = "Palette"

                        local octCapacity = args.octCapacity or defaults.octCapacity
                        local bounds = Bounds3.cieLab()
                        local octree = Octree.new(bounds, octCapacity, 0)

                        -- Find minimum and maximum channel values.
                        local lMin = 0.0
                        local aMin = 0.0
                        local bMin = 0.0

                        local lMax = 0.0
                        local aMax = 0.0
                        local bMax = 0.0

                        local viableCount = 0

                        -- Unpack source palette to a dictionary and an octree.
                        -- Ignore transparent colors in palette.
                        local palHexesLen = #hexesSrgb
                        local ptToHexDict = {}
                        for i = 1, palHexesLen, 1 do
                            local hexSrgb = hexesSrgb[i]
                            if hexSrgb & 0xff000000 ~= 0 then
                                local clr = Clr.fromHex(hexSrgb)
                                local lab = Clr.sRgbaToLab(clr)
                                local point = Vec3.new(lab.a, lab.b, lab.l)

                                if lab.l < lMin then lMin = lab.l end
                                if lab.a < aMin then aMin = lab.a end
                                if lab.b < bMin then bMin = lab.b end

                                if lab.l > lMax then lMax = lab.l end
                                if lab.a > aMax then aMax = lab.a end
                                if lab.b > bMax then bMax = lab.b end

                                local hexProfile = hexesProfile[i]
                                ptToHexDict[Vec3.hashCode(point)] = hexProfile
                                Octree.insert(octree, point)
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

                        -- Add a fudge factor to ensure an outlier color
                        -- won't be clipped off at limit.
                        local queryRad = 50.0 + math.sqrt(
                            lDiff * lDiff + aDiff * aDiff + bDiff * bDiff)
                        local resultLimit = viableCount

                        closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                            local srgb = Clr.new(
                                rSrc * 0.00392156862745098,
                                gSrc * 0.00392156862745098,
                                bSrc * 0.00392156862745098,
                                1.0)
                            local lab = Clr.sRgbaToLab(srgb)
                            local query = Vec3.new(lab.a, lab.b, lab.l)

                            local nearestPts = {}
                            Octree.querySphericalInternal(
                                octree,
                                query, queryRad,
                                nearestPts, resultLimit)

                            local trgHex = 0x0
                            if #nearestPts > 0 then
                                local nearestHash = Vec3.hashCode(nearestPts[1].point)
                                local nearestHex = ptToHexDict[nearestHash]
                                if nearestHex then
                                    local alpha = aSrc << 0x18
                                    trgHex = alpha | nearestHex & 0x00ffffff
                                end
                            end

                            return trgHex
                        end

                    end

                    -- Cache pixels from iterator to an array.
                    local srcPxItr = srcImg:pixels()
                    local pxArray = {}
                    local pxIdx = 1
                    for elm in srcPxItr do
                        local hex = elm()
                        pxArray[pxIdx] = hex
                        pxIdx = pxIdx + 1
                    end

                    -- Get arguments to pass to dithering method.
                    local srcWidth = srcImg.width
                    local srcHeight = srcImg.height
                    local factor100 = args.factor or defaults.factor
                    local factor = factor100 * 0.01
                    fsDither(pxArray, srcWidth, srcHeight, factor, closestFunc)

                    local trgImg = Image(srcWidth, srcHeight)
                    local trgPxItr = trgImg:pixels()
                    local m = 1
                    for elm in trgPxItr do
                        elm(pxArray[m])
                        m = m + 1
                    end

                    -- Either copy to new layer or reassign image.
                    local copyToLayer = args.copyToLayer
                    if copyToLayer then
                        app.transaction(function()
                            local srcLayer = srcCel.layer
                            local trgLayer = sprite:newLayer()
                            trgLayer.name = string.format(
                                "%s.Dither.%s.%03d",
                                srcLayer.name, dmStr, factor100)
                            trgLayer.opacity = srcLayer.opacity
                            local frame = app.activeFrame or sprite.frames[1]
                            local trgCel = sprite:newCel(
                                trgLayer, frame,
                                trgImg, srcCel.position)
                            trgCel.opacity = srcCel.opacity
                        end)
                    else
                        srcCel.image = trgImg
                    end

                    AseUtilities.changePixelFormat(oldColorMode)

                    if printElapsed then
                        endTime = os.time()
                        elapsed = os.difftime(endTime, startTime)
                        local msg = string.format(
                            "Start: %d\nEnd: %d\nElapsed: %d",
                            startTime, endTime, elapsed)
                        print(msg)
                    end

                    app.refresh()
                else
                    app.alert("The cel has no image.")
                end
            else
                app.alert("There is no active cel.")
            end
        else
            app.alert("There is no active sprite.")
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