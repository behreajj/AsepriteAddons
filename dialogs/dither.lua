dofile("../support/aseutilities.lua")
dofile("../support/octree.lua")
dofile("../support/clr.lua")

local defaults = {
    palType = "ACTIVE",
    queryRad = 175,
    octCapacity = 16,
    factor = 100,
    pullFocus = false
}

local dlg = Dialog { title = "Floyd-Steinberg Dither" }

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
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:slider {
    id = "queryRad",
    label = "Query Radius:",
    min = 25,
    max = 250,
    value = defaults.queryRad
}

dlg:newrow { always = false }

dlg:slider {
    id = "octCapacity",
    label = "Cell Capacity:",
    min = 3,
    max = 32,
    value = defaults.octCapacity
}

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "factor",
--     label = "Factor:",
--     min = 0,
--     max = 100,
--     value = defaults.factor
-- }

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then

            local srcPal = nil
            local palType = args.palType
            if palType == "FILE" then
                local fp =  args.palFile
                if fp and #fp > 0 then
                    srcPal = Palette { fromFile = fp }
                end
            elseif palType == "PRESET" then
                local pr = args.palPreset
                if pr and #pr > 0 then
                    srcPal = Palette { fromResource = pr }
                end
            else
                srcPal = sprite.palettes[1]
            end

            if srcPal then
                local srcCel = app.activeCel
                if srcCel then
                    local srcImg = srcCel.image
                    if srcImg ~= nil then

                        -- TODO: Option presets for quantize, octree, one-bit.

                        local resultLimit = 256
                        local octCapacity = args.octCapacity or defaults.octCapacity
                        local queryRad = args.queryRad and defaults.queryRad
                        local factor100 = args.factor or defaults.factor
                        local factor = factor100 * 0.01

                        -- Cache global methods to local.
                        local trunc = math.tointeger

                        -- Floyd-Steinberg coefficients.
                        local one_255 = 1.0 / 255.0
                        local fs_1_16 = 0.0625 * factor
                        local fs_3_16 = 0.1875 * factor
                        local fs_5_16 = 0.3125 * factor
                        local fs_7_16 = 0.4375 * factor

                        local oldMode = sprite.colorMode
                        app.command.ChangePixelFormat { format = "rgb" }

                        local srcPalLen = #srcPal
                        local ptToHexDict = {}

                        -- Cache bounds as a separate variable in case you want
                        -- to switch color representation later.
                        local bounds = Bounds3.cieLab()
                        local octree = Octree.new(bounds, octCapacity, 0)

                        -- Unpack source palette to a dictionary and an octree.
                        for i = 1, srcPalLen, 1 do
                            local aseColor = srcPal:getColor(i - 1)
                            local clr = AseUtilities.aseColorToClr(aseColor)
                            local lab = Clr.sRgbaToLab(clr)
                            local point = Vec3.new(lab.a, lab.b, lab.l)
                            ptToHexDict[Vec3.hashCode(point)] = aseColor.rgbaPixel
                            Octree.insert(octree, point)
                        end

                        -- Cache pixels from iterator to an array.
                        local srcPxItr = srcImg:pixels()
                        local px = {}
                        local i = 1
                        for elm in srcPxItr do
                            px[i] = elm()
                            i = i + 1
                        end

                        local srcWidth = srcImg.width
                        local srcHeight = srcImg.height
                        local pxLen = #px

                        for k = 1, pxLen, 1 do
                            local srcHex = px[k]
                            local rSrc = srcHex & 0xff
                            local gSrc = srcHex >> 0x08 & 0xff
                            local bSrc = srcHex >> 0x10 & 0xff

                            local srgb = Clr.new(
                                rSrc * one_255,
                                gSrc * one_255,
                                bSrc * one_255, 1.0)
                            local lab = Clr.sRgbaToLab(srgb)
                            local query = Vec3.new(lab.a, lab.b, lab.l)

                            local trgHex = 0
                            local rTrg = 0
                            local gTrg = 0
                            local bTrg = 0

                            local nearestPts = {}
                            Octree.querySphericalInternal(octree, query, queryRad, nearestPts, resultLimit)
                            if #nearestPts > 0 then
                                local nearestHash = Vec3.hashCode(nearestPts[1].point)
                                local nearestHex = ptToHexDict[nearestHash]
                                if nearestHex then
                                    rTrg = nearestHex & 0xff
                                    gTrg = nearestHex >> 0x08 & 0xff
                                    bTrg = nearestHex >> 0x10 & 0xff
                                    trgHex = srcHex & 0xff000000
                                       | nearestHex & 0x00ffffff
                                end
                            end

                            px[k] = trgHex

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
                                local neighbor0 = px[k0]

                                local rn0 = neighbor0 & 0xff
                                local gn0 = neighbor0 >> 0x08 & 0xff
                                local bn0 = neighbor0 >> 0x10 & 0xff

                                local rne0 = rn0 + trunc(rErr * fs_7_16)
                                local gne0 = gn0 + trunc(gErr * fs_7_16)
                                local bne0 = bn0 + trunc(bErr * fs_7_16)

                                if rne0 < 0 then rne0 = 0 elseif rne0 > 255 then rne0 = 255 end
                                if gne0 < 0 then gne0 = 0 elseif gne0 > 255 then gne0 = 255 end
                                if bne0 < 0 then bne0 = 0 elseif bne0 > 255 then bne0 = 255 end

                                px[k0] = neighbor0 & 0xff000000
                                    | bne0 << 0x10
                                    | gne0 << 0x08
                                    | rne0

                                -- Find bottom-right neighbor.
                                if yp1InBounds then
                                    local k3 = 1 + xp1 + yp1w
                                    local neighbor3 = px[k3]

                                    local rn3 = neighbor3 & 0xff
                                    local gn3 = neighbor3 >> 0x08 & 0xff
                                    local bn3 = neighbor3 >> 0x10 & 0xff

                                    local rne3 = rn3 + trunc(rErr * fs_1_16)
                                    local gne3 = gn3 + trunc(gErr * fs_1_16)
                                    local bne3 = bn3 + trunc(bErr * fs_1_16)

                                    if rne3 < 0 then rne3 = 0 elseif rne3 > 255 then rne3 = 255 end
                                    if gne3 < 0 then gne3 = 0 elseif gne3 > 255 then gne3 = 255 end
                                    if bne3 < 0 then bne3 = 0 elseif bne3 > 255 then bne3 = 255 end

                                    px[k3] = neighbor3 & 0xff000000
                                        | bne3 << 0x10
                                        | gne3 << 0x08
                                        | rne3
                                end
                            end

                            -- Find bottom neighbor.
                            if yp1InBounds then
                                local k2 = 1 + x + yp1w
                                local neighbor2 = px[k2]

                                local rn2 = neighbor2 & 0xff
                                local gn2 = neighbor2 >> 0x08 & 0xff
                                local bn2 = neighbor2 >> 0x10 & 0xff

                                local rne2 = rn2 + trunc(rErr * fs_5_16)
                                local gne2 = gn2 + trunc(gErr * fs_5_16)
                                local bne2 = bn2 + trunc(bErr * fs_5_16)

                                if rne2 < 0 then rne2 = 0 elseif rne2 > 255 then rne2 = 255 end
                                if gne2 < 0 then gne2 = 0 elseif gne2 > 255 then gne2 = 255 end
                                if bne2 < 0 then bne2 = 0 elseif bne2 > 255 then bne2 = 255 end

                                px[k2] = neighbor2 & 0xff000000
                                    | bne2 << 0x10
                                    | gne2 << 0x08
                                    | rne2

                                -- Find left neighbor.
                                if x > 0 then
                                    local k1 = x + yp1w
                                    local neighbor1 = px[k1]

                                    local rn1 = neighbor1 & 0xff
                                    local gn1 = neighbor1 >> 0x08 & 0xff
                                    local bn1 = neighbor1 >> 0x10 & 0xff

                                    local rne1 = rn1 + trunc(rErr * fs_3_16)
                                    local gne1 = gn1 + trunc(gErr * fs_3_16)
                                    local bne1 = bn1 + trunc(bErr * fs_3_16)

                                    if rne1 < 0 then rne1 = 0 elseif rne1 > 255 then rne1 = 255 end
                                    if gne1 < 0 then gne1 = 0 elseif gne1 > 255 then gne1 = 255 end
                                    if bne1 < 0 then bne1 = 0 elseif bne1 > 255 then bne1 = 255 end

                                    px[k1] = neighbor1 & 0xff000000
                                        | bne1 << 0x10
                                        | gne1 << 0x08
                                        | rne1
                                end
                            end
                        end

                        local trgImg = Image(srcWidth, srcHeight)
                        local trgPxItr = trgImg:pixels()
                        local m = 1
                        for elm in trgPxItr do
                            elm(px[m])
                            m = m + 1
                        end

                        -- Either copy to new layer or reassign image.
                        -- local copyToLayer = args.copyToLayer
                        local copyToLayer = true
                        if copyToLayer then
                            local trgLayer = sprite:newLayer()
                            trgLayer.name = srcCel.layer.name
                                .. string.format(".Dithered.%03d", factor100)
                            local frame = app.activeFrame or 1
                            local trgCel = sprite:newCel(trgLayer, frame)
                            trgCel.image = trgImg
                            trgCel.position = srcCel.position
                        else
                            srcCel.image = trgImg
                        end

                        if oldMode == ColorMode.INDEXED then
                            app.command.ChangePixelFormat { format = "indexed" }
                        elseif oldMode == ColorMode.GRAY then
                            app.command.ChangePixelFormat { format = "gray" }
                        end

                        app.refresh()
                    else
                        app.alert("The cel has no image.")
                    end
                else
                    app.alert("There is no active cel.")
                end
            else
                app.alert("The source palette could not be found.")
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