dofile("../../support/aseutilities.lua")
dofile("../../support/quantizeutilities.lua")
dofile("../../support/octree.lua")

local ditherModes <const> = { "ONE_BIT", "PALETTE", "QUANTIZE" }
local areaTargets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local palTargets <const> = { "ACTIVE", "FILE" }
local greyMethods <const> = { "AVERAGE", "HSL", "HSV", "LUMINANCE" }

local defaults <const> = {
    -- Last commit for old version of dithering:
    -- 23e391771391d5ffaf3e7f2385389e4af7e84004
    ditherMode = "PALETTE",
    areaTarget = "ACTIVE",
    palTarget = "ACTIVE",
    threshold = 50,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    factor = 100,
    greyMethod = "LUMINANCE",
    printElapsed = false,
}

---Changes pixel array in place. Ignores alpha channel.
---@param pixels integer[] bytes of length w * h * bpp
---@param wSrc integer source image width
---@param hSrc integer source image height
---@param srcBpp integer source image bytes per pixel
---@param factor number dither factor
---@param closestFunc fun(r8Src: integer, g8Src: integer, b8Src: integer, a8Src: integer): integer, integer, integer, integer
local function fsDither(pixels, wSrc, hSrc, srcBpp, factor, closestFunc)
    local fs_1_16 <const> = 0.0625 * factor
    local fs_3_16 <const> = 0.1875 * factor
    local fs_5_16 <const> = 0.3125 * factor
    local fs_7_16 <const> = 0.4375 * factor

    local floor <const> = math.floor

    local areaImage <const> = wSrc * hSrc
    local i = 0
    while i < areaImage do
        local iSrcBpp <const> = i * srcBpp
        local x <const> = i % wSrc
        local y <const> = i // wSrc

        local r8Src <const> = pixels[1 + iSrcBpp]
        local g8Src <const> = pixels[2 + iSrcBpp]
        local b8Src <const> = pixels[3 + iSrcBpp]
        local a8Src <const> = pixels[4 + iSrcBpp]

        local r8Trg <const>,
        g8Trg <const>,
        b8Trg <const>,
        a8Trg <const> = closestFunc(r8Src, g8Src, b8Src, a8Src)

        pixels[1 + iSrcBpp] = r8Trg
        pixels[2 + iSrcBpp] = g8Trg
        pixels[3 + iSrcBpp] = b8Trg
        pixels[4 + iSrcBpp] = a8Trg

        -- Find difference between palette color and source color.
        local rErr <const> = r8Src - r8Trg
        local gErr <const> = g8Src - g8Trg
        local bErr <const> = b8Src - b8Trg
        local aErr <const> = a8Src - a8Trg

        local xp1InBounds <const> = x + 1 < wSrc
        local yp1InBounds <const> = y + 1 < hSrc

        local xBpp <const> = x * srcBpp

        -- Find right neighbor.
        if xp1InBounds then
            local idxNgbr0 <const> = y * wSrc * srcBpp + xBpp + srcBpp

            local rne0 = pixels[1 + idxNgbr0] + floor(rErr * fs_7_16)
            local gne0 = pixels[2 + idxNgbr0] + floor(gErr * fs_7_16)
            local bne0 = pixels[3 + idxNgbr0] + floor(bErr * fs_7_16)
            local ane0 = pixels[4 + idxNgbr0] + floor(aErr * fs_7_16)

            if rne0 < 0 then rne0 = 0 elseif rne0 > 255 then rne0 = 255 end
            if gne0 < 0 then gne0 = 0 elseif gne0 > 255 then gne0 = 255 end
            if bne0 < 0 then bne0 = 0 elseif bne0 > 255 then bne0 = 255 end
            if ane0 < 0 then ane0 = 0 elseif ane0 > 255 then ane0 = 255 end

            pixels[1 + idxNgbr0] = rne0
            pixels[2 + idxNgbr0] = gne0
            pixels[3 + idxNgbr0] = bne0
            pixels[4 + idxNgbr0] = ane0
        end

        if yp1InBounds then
            local yp1WSrcBpp <const> = (y + 1) * wSrc * srcBpp

            -- Find bottom left neighbor.
            if x > 0 then
                local idxNgbr1 <const> = yp1WSrcBpp + xBpp - srcBpp

                local rne1 = pixels[1 + idxNgbr1] + floor(rErr * fs_3_16)
                local gne1 = pixels[2 + idxNgbr1] + floor(gErr * fs_3_16)
                local bne1 = pixels[3 + idxNgbr1] + floor(bErr * fs_3_16)
                local ane1 = pixels[4 + idxNgbr1] + floor(aErr * fs_3_16)

                if rne1 < 0 then rne1 = 0 elseif rne1 > 255 then rne1 = 255 end
                if gne1 < 0 then gne1 = 0 elseif gne1 > 255 then gne1 = 255 end
                if bne1 < 0 then bne1 = 0 elseif bne1 > 255 then bne1 = 255 end
                if ane1 < 0 then ane1 = 0 elseif ane1 > 255 then ane1 = 255 end

                pixels[1 + idxNgbr1] = rne1
                pixels[2 + idxNgbr1] = gne1
                pixels[3 + idxNgbr1] = bne1
                pixels[4 + idxNgbr1] = ane1
            end

            -- Find the bottom neighbor.
            local idxNgbr2 <const> = yp1WSrcBpp + xBpp

            local rne2 = pixels[1 + idxNgbr2] + floor(rErr * fs_5_16)
            local gne2 = pixels[2 + idxNgbr2] + floor(gErr * fs_5_16)
            local bne2 = pixels[3 + idxNgbr2] + floor(bErr * fs_5_16)
            local ane2 = pixels[4 + idxNgbr2] + floor(aErr * fs_5_16)

            if rne2 < 0 then rne2 = 0 elseif rne2 > 255 then rne2 = 255 end
            if gne2 < 0 then gne2 = 0 elseif gne2 > 255 then gne2 = 255 end
            if bne2 < 0 then bne2 = 0 elseif bne2 > 255 then bne2 = 255 end
            if ane2 < 0 then ane2 = 0 elseif ane2 > 255 then ane2 = 255 end

            pixels[1 + idxNgbr2] = rne2
            pixels[2 + idxNgbr2] = gne2
            pixels[3 + idxNgbr2] = bne2
            pixels[4 + idxNgbr2] = ane2

            -- Find bottom right neighbor.
            if xp1InBounds then
                local idxNgbr3 <const> = yp1WSrcBpp + xBpp + srcBpp

                local rne3 = pixels[1 + idxNgbr3] + floor(rErr * fs_1_16)
                local gne3 = pixels[2 + idxNgbr3] + floor(gErr * fs_1_16)
                local bne3 = pixels[3 + idxNgbr3] + floor(bErr * fs_1_16)
                local ane3 = pixels[4 + idxNgbr3] + floor(aErr * fs_1_16)

                if rne3 < 0 then rne3 = 0 elseif rne3 > 255 then rne3 = 255 end
                if gne3 < 0 then gne3 = 0 elseif gne3 > 255 then gne3 = 255 end
                if bne3 < 0 then bne3 = 0 elseif bne3 > 255 then bne3 = 255 end
                if ane3 < 0 then ane3 = 0 elseif ane3 > 255 then ane3 = 255 end

                pixels[1 + idxNgbr3] = rne3
                pixels[2 + idxNgbr3] = gne3
                pixels[3 + idxNgbr3] = bne3
                pixels[4 + idxNgbr3] = ane3
            end -- End x + 1 in bounds.
        end     -- End y + 1 in bounds.

        i = i + 1
    end -- End pixel loop.
end

local dlg <const> = Dialog { title = "Dither" }

dlg:combobox {
    id = "areaTarget",
    label = "Target:",
    option = defaults.areaTarget,
    options = areaTargets
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

QuantizeUtilities.dialogWidgets(
    dlg, defaults.ditherMode == "QUANTIZE",
    true)

dlg:combobox {
    id = "palTarget",
    label = "Palette:",
    option = defaults.palTarget,
    options = palTargets,
    onchange = function()
        local args <const> = dlg.data
        local palTarget <const> = args.palTarget --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = palTarget == "FILE"
        }
    end,
    visible = defaults.ditherMode == "PALETTE"
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
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

dlg:slider {
    id = "factor",
    label = "Factor:",
    min = 0,
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

        local ditherMode <const> = args.ditherMode --[[@as string]]
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
        local getPixels <const> = AseUtilities.getPixels
        local setPixels <const> = AseUtilities.setPixels

        -- String that is assigned to new layer name to clarify operation.
        local dmStr = ""

        ---@param r8Src integer
        ---@param g8Src integer
        ---@param b8Src integer
        ---@param a8Src integer
        ---@return integer r8Trg
        ---@return integer g8Trg
        ---@return integer b8Trg
        ---@return integer a8Trg
        local closestFunc = function(r8Src, g8Src, b8Src, a8Src)
            return r8Src, g8Src, b8Src, a8Src
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
                if greyMethod(r8Src, g8Src, b8Src) >= threshold then
                    return dr8, dg8, db8, a8Src
                end
                return or8, og8, ob8, a8Src
            end

            dmStr = string.format("OneBit %s %03d", greyStr, thresh100)
        elseif ditherMode == "QUANTIZE" then
            -- These args come from QuantizeUtilities.
            local method <const> = args.method --[[@as string]]
            local rLevels = args.rLevels --[[@as integer]]
            local gLevels = args.gLevels --[[@as integer]]
            local bLevels = args.bLevels --[[@as integer]]
            local aLevels = args.aLevels --[[@as integer]]

            local rDelta = 0.0
            local gDelta = 0.0
            local bDelta = 0.0
            local aDelta = 0.0

            local quantize = Utilities.quantizeUnsignedInternal

            if method == "UNSIGNED" then
                quantize = Utilities.quantizeUnsignedInternal

                rDelta = 1.0 / (rLevels - 1.0)
                gDelta = 1.0 / (gLevels - 1.0)
                bDelta = 1.0 / (bLevels - 1.0)
                aDelta = 1.0 / (aLevels - 1.0)
            else
                quantize = Utilities.quantizeSignedInternal

                rLevels = rLevels - 1
                gLevels = gLevels - 1
                bLevels = bLevels - 1
                aLevels = aLevels - 1

                rDelta = 1.0 / rLevels
                gDelta = 1.0 / gLevels
                bDelta = 1.0 / bLevels
                aDelta = 1.0 / aLevels
            end

            local floor <const> = math.floor

            closestFunc = function(r8Src, g8Src, b8Src, a8Src)
                local rQtz <const> = quantize(r8Src / 255.0, rLevels, rDelta)
                local gQtz <const> = quantize(g8Src / 255.0, gLevels, gDelta)
                local bQtz <const> = quantize(b8Src / 255.0, bLevels, bDelta)
                local aQtz <const> = quantize(a8Src / 255.0, aLevels, aDelta)
                return floor(rQtz * 255.0 + 0.5),
                    floor(gQtz * 255.0 + 0.5),
                    floor(bQtz * 255.0 + 0.5),
                    floor(aQtz * 255.0 + 0.5)
            end

            dmStr = string.format(
                "Quantized R%02d G%02d B%02d A%02d",
                rLevels, gLevels, bLevels, aLevels)
        elseif ditherMode == "PALETTE" then
            local palTarget <const> = args.palTarget
                or defaults.palTarget --[[@as string]]
            local palFile <const> = args.palFile --[[@as string]]
            local octCapacity = args.octCapacity
                or defaults.octCapacityBits --[[@as integer]]

            local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
                palTarget, palFile, 0, 512, true)

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
            local fromHex <const> = Clr.fromHexAbgr32
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
                    local lab <const> = sRgbaToLab(fromHex(hexSrgb))
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
                    local point <const> = v3new(a, b, l)
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
            closestFunc = function(r8Src, g8Src, b8Src, a8Src)
                local srgb <const> = cnew(
                    r8Src / 255.0,
                    g8Src / 255.0,
                    b8Src / 255.0,
                    1.0)
                local lab <const> = sRgbaToLab(srgb)
                local query <const> = v3new(lab.a, lab.b, lab.l)
                local nearPoint <const>, _ <const> = octquery(
                    octree, query, queryRad, distFunc)

                local r8Trg, g8Trg, b8Trg = 0, 0, 0
                if nearPoint then
                    local nearHash <const> = v3hash(nearPoint)
                    local nearHex <const> = ptToHexDict[nearHash]
                    if nearHex ~= nil then
                        r8Trg = nearHex & 0xff
                        g8Trg = (nearHex >> 0x08) & 0xff
                        b8Trg = (nearHex >> 0x10) & 0xff
                    end
                end

                return r8Trg, g8Trg, b8Trg, a8Src
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
                    local trgPixels <const> = getPixels(srcImg)
                    fsDither(trgPixels, wSrc, hSrc, srcBpp, factor, closestFunc)
                    trgImg = Image(srcSpec)
                    setPixels(trgImg, trgPixels)
                    premadeTrgImgs[srcImgId] = trgImg
                end

                transact(strfmt("Dither %d", frIdx + frameUiOffset), function()
                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, srcCel.position)
                    trgCel.opacity = srcCel.opacity
                end)
            end -- End source cel exists.
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