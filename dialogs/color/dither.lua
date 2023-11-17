dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local ditherModes <const> = { "ONE_BIT", "PALETTE", "QUANTIZE" }
local greyMethods <const> = { "AVERAGE", "HSL", "HSV", "LUMINANCE" }
local palTypes <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
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

---@param pxArray integer[]
---@param srcWidth integer
---@param srcHeight integer
---@param factor number
---@param closestFunc fun(rSrc: integer, gSrc: integer, bSrc: integer, aSrc: integer): integer
local function fsDither(pxArray, srcWidth, srcHeight, factor, closestFunc)
    local pxLen <const> = #pxArray
    local floor <const> = math.floor

    local fs_1_16 <const> = 0.0625 * factor
    local fs_3_16 <const> = 0.1875 * factor
    local fs_5_16 <const> = 0.3125 * factor
    local fs_7_16 <const> = 0.4375 * factor

    local k = 0
    while k < pxLen do
        -- Calculate conversions from 1D to 2D indices.
        local x <const> = k % srcWidth
        local y <const> = k // srcWidth
        local yp1 <const> = y + 1
        local xp1 <const> = x + 1
        local xp1InBounds <const> = xp1 < srcWidth
        local yp1InBounds <const> = yp1 < srcHeight
        local yp1w <const> = yp1 * srcWidth

        k = k + 1
        local srcHex <const> = pxArray[k]
        local rSrc <const> = srcHex & 0xff
        local gSrc <const> = srcHex >> 0x08 & 0xff
        local bSrc <const> = srcHex >> 0x10 & 0xff
        local aSrc <const> = srcHex >> 0x18 & 0xff

        local trgHex <const> = closestFunc(rSrc, gSrc, bSrc, aSrc)
        local rTrg <const> = trgHex & 0xff
        local gTrg <const> = trgHex >> 0x08 & 0xff
        local bTrg <const> = trgHex >> 0x10 & 0xff
        pxArray[k] = trgHex

        -- Find difference between palette color and source color.
        local rErr <const> = rSrc - rTrg
        local gErr <const> = gSrc - gTrg
        local bErr <const> = bSrc - bTrg

        -- Find right neighbor.
        if xp1InBounds then
            local k0 <const> = 1 + xp1 + y * srcWidth
            local neighbor0 <const> = pxArray[k0]

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
                local k3 <const> = 1 + xp1 + yp1w
                local neighbor3 <const> = pxArray[k3]

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
            local k2 <const> = 1 + x + yp1w
            local neighbor2 <const> = pxArray[k2]

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
                local k1 <const> = x + yp1w
                local neighbor1 <const> = pxArray[k1]

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

local dlg <const> = Dialog { title = "Dither" }

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
        local args <const> = dlg.data
        local ditherMode <const> = args.ditherMode --[[@as string]]
        local palType <const> = args.palType --[[@as string]]

        local isQnt <const> = ditherMode == "QUANTIZE"
        local isOne <const> = ditherMode == "ONE_BIT"
        local isPal <const> = ditherMode == "PALETTE"

        dlg:modify { id = "levels", visible = isQnt }

        dlg:modify { id = "aColor", visible = isOne }
        dlg:modify { id = "bColor", visible = isOne }
        dlg:modify { id = "greyMethod", visible = isOne }
        dlg:modify { id = "threshold", visible = isOne }

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
        local args <const> = dlg.data
        local palType <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = palType == "FILE"
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
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.clock()
        end

        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
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

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        local oldMode <const> = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local ditherMode <const> = args.ditherMode
            or defaults.ditherMode --[[@as string]]
        local factor100 <const> = args.factor
            or defaults.factor --[[@as integer]]

        local factor <const> = factor100 * 0.01
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Choose function based on dither mode.
        local closestFunc = nil
        local dmStr = ""
        if ditherMode == "ONE_BIT" then
            local aColorAse <const> = args.aColor --[[@as Color]]
            local bColorAse <const> = args.bColor --[[@as Color]]
            local thresh100 <const> = args.threshold
                or defaults.threshold --[[@as integer]]
            local greyPreset <const> = args.greyMethod
                or defaults.greyMethod --[[@as string]]

            -- Mask out alpha, source alpha will be used.
            local aHex = 0x00ffffff & AseUtilities.aseColorToHex(
                aColorAse, ColorMode.RGB)
            local bHex = 0x00ffffff & AseUtilities.aseColorToHex(
                bColorAse, ColorMode.RGB)

            local greyMethod = function(rSrc, gSrc, bSrc) return 0.5 end
            local greyStr = ""
            if greyPreset == "AVERAGE" then
                -- In HSI, I = (r + g + b) / 3, S = 1 - min(r, g, b) / I.
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
                local stlLut <const> = Utilities.STL_LUT
                local ltsLut <const> = Utilities.LTS_LUT
                greyMethod = function(rSrc, gSrc, bSrc)
                    local rLin <const> = stlLut[1 + rSrc]
                    local gLin <const> = stlLut[1 + gSrc]
                    local bLin <const> = stlLut[1 + bSrc]
                    local lum <const> = math.floor(
                        rLin * 0.21264934272065
                        + gLin * 0.7151691357059
                        + bLin * 0.072181521573443)
                    return ltsLut[1 + lum] * 0.003921568627451
                end
                greyStr = "Luminance"
            end

            -- Swap colors so that origin (a) is the darker color.
            if greyMethod(aColorAse.red, aColorAse.green, aColorAse.blue) >
                greyMethod(bColorAse.red, bColorAse.green, bColorAse.blue) then
                aHex, bHex = bHex, aHex
            end

            local threshold <const> = thresh100 * 0.01
            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local fac <const> = greyMethod(rSrc, gSrc, bSrc)
                local alpha <const> = aSrc << 0x18
                if fac >= threshold then
                    return alpha | bHex
                end
                return alpha | aHex
            end

            dmStr = string.format("OneBit.%s.%03d", greyStr, thresh100)
        elseif ditherMode == "QUANTIZE" then
            local levels <const> = args.levels
                or defaults.levels --[[@as integer]]
            local delta <const> = 1.0 / (levels - 1.0)
            local quantize <const> = Utilities.quantizeUnsignedInternal
            local floor <const> = math.floor

            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local aQtz <const> = quantize(aSrc / 255.0, levels, delta)
                local bQtz <const> = quantize(bSrc / 255.0, levels, delta)
                local gQtz <const> = quantize(gSrc / 255.0, levels, delta)
                local rQtz <const> = quantize(rSrc / 255.0, levels, delta)

                local a255 <const> = floor(aQtz * 255.0 + 0.5)
                local b255 <const> = floor(bQtz * 255.0 + 0.5)
                local g255 <const> = floor(gQtz * 255.0 + 0.5)
                local r255 <const> = floor(rQtz * 255.0 + 0.5)

                return a255 << 0x18 | b255 << 0x10 | g255 << 0x08 |  r255
            end

            dmStr = string.format("Quantize.%02d", levels)
        else
            local palType <const> = args.palType
                or defaults.palType --[[@as string]]
            local palFile <const> = args.palFile --[[@as string]]
            local octCapacity = args.octCapacity
                or defaults.octCapacityBits --[[@as integer]]

            local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
                palType, palFile, 0, 256, true)

            octCapacity = 1 << octCapacity
            local bounds <const> = Bounds3.lab()
            local octree <const> = Octree.new(bounds, octCapacity, 1)

            -- Find minimum and maximum channel values.
            local lMin = 2147483647
            local aMin = 2147483647
            local bMin = 2147483647

            local lMax = -2147483648
            local aMax = -2147483648
            local bMax = -2147483648

            -- Cache methods to local.
            local sqrt <const> = math.sqrt
            local abs <const> = math.abs
            local cnew <const> = Clr.new
            local fromHex <const> = Clr.fromHex
            local sRgbaToLab <const> = Clr.sRgbToSrLab2
            local octins <const> = Octree.insert
            local octquery <const> = Octree.queryInternal
            local v3new <const> = Vec3.new
            local v3hash <const> = Vec3.hashCode

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
                    local clr <const> = fromHex(hexSrgb)
                    local lab <const> = sRgbaToLab(clr)
                    local l <const> = lab.l
                    local a <const> = lab.a
                    local b <const> = lab.b
                    local point <const> = v3new(a, b, l)

                    if l < lMin then lMin = l end
                    if a < aMin then aMin = a end
                    if b < bMin then bMin = b end

                    if l > lMax then lMax = l end
                    if a > aMax then aMax = a end
                    if b > bMax then bMax = b end

                    local hexProfile <const> = hexesProfile[idxPalHex]
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
            local lDiff <const> = lMax - lMin
            local aDiff <const> = aMax - aMin
            local bDiff <const> = bMax - bMin

            -- Square-root for this regularly seems too
            -- small, leading to transparent patches.
            local queryRad <const> = lDiff * lDiff
                + aDiff * aDiff
                + bDiff * bDiff

            local distFunc = function(a, b)
                local da <const> = b.x - a.x
                local db <const> = b.y - a.y
                return sqrt(da * da + db * db) + abs(b.z - a.z)
            end

            Octree.cull(octree)
            closestFunc = function(rSrc, gSrc, bSrc, aSrc)
                local srgb <const> = cnew(
                    rSrc * 0.003921568627451,
                    gSrc * 0.003921568627451,
                    bSrc * 0.003921568627451,
                    1.0)
                local lab <const> = sRgbaToLab(srgb)
                local query <const> = v3new(lab.a, lab.b, lab.l)
                local nearPoint <const>, _ <const> = octquery(
                    octree, query, queryRad, distFunc)

                local trgHex = 0x0
                if nearPoint then
                    local nearHash <const> = v3hash(nearPoint)
                    local nearHex <const> = ptToHexDict[nearHash]
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
        local tilesToImage <const> = AseUtilities.tilesToImage
        local transact <const> = app.transaction
        local strfmt <const> = string.format

        local lenFrames <const> = #frames
        local i = 0
        local rgbColorMode <const> = ColorMode.RGB
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                local srcSpec <const> = srcImg.spec
                local srcWidth <const> = srcSpec.width
                local srcHeight <const> = srcSpec.height

                local srcPxItr <const> = srcImg:pixels()
                ---@type integer[]
                local arrSrcPixels <const> = {}
                local idxRdPixels = 0
                for pixel in srcPxItr do
                    idxRdPixels = idxRdPixels + 1
                    arrSrcPixels[idxRdPixels] = pixel()
                end

                fsDither(arrSrcPixels, srcWidth, srcHeight, factor, closestFunc)

                local trgImg <const> = Image(srcSpec)
                local trgPxItr <const> = trgImg:pixels()
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

dlg:show {
    autoscrollbars = true,
    wait = false
}