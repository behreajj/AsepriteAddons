dofile("../support/aseutilities.lua")
dofile("../support/octree.lua")
dofile("../support/clr.lua")

local defaults = {
    palType = "ACTIVE",
    queryRad = 100,
    octCapacity = 16,
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

                        local queryRad = args.queryRad or defaults.queryRad

                        -- Cache global functions to local.
                        local max = math.max
                        local min = math.min
                        local aseToClr = AseUtilities.aseColorToClr
                        local fromHex = Clr.fromHex
                        local rgbaToLab = Clr.rgbaToLab
                        local v3new = Vec3.new
                        local v3hash = Vec3.hashCode

                        local oldMode = sprite.colorMode
                        app.command.ChangePixelFormat { format = "rgb" }

                        -- Find lab minimums and maximums.
                        local lMin = 999999
                        local aMin = 999999
                        local bMin = 999999

                        local lMax = -999999
                        local aMax = -999999
                        local bMax = -999999

                        local srcPalLen = #srcPal
                        local ptToHexDict = {}
                        local points = {}
                        for i = 0, srcPalLen - 1, 1 do
                            local aseColor = srcPal:getColor(i)
                            local hex = aseColor.rgbaPixel
                            local clr = aseToClr(aseColor)
                            local lab = rgbaToLab(clr)
                            local vec = v3new(lab.a, lab.b, lab.l)
                            local vecHash = v3hash(vec)
                            ptToHexDict[vecHash] = hex
                            points[1 + i] = vec

                            if lab.l < lMin then lMin = lab.l end
                            if lab.a < aMin then aMin = lab.a end
                            if lab.b < bMin then bMin = lab.b end

                            if lab.l > lMax then lMax = lab.l end
                            if lab.a > aMax then aMax = lab.a end
                            if lab.b > bMax then bMax = lab.b end
                        end

                        -- Create Octree.
                        local octCapacity = args.octCapacity
                        local bounds = Bounds3.newByRef(
                            Vec3.new(
                                aMin - 0.00001,
                                bMin - 0.00001,
                                lMin - 0.00001),
                            Vec3.new(
                                aMax + 0.00001,
                                bMax + 0.00001,
                                lMax + 0.00001))
                        local octree = Octree.new(bounds, octCapacity, 0)
                        Octree.insertAll(octree, points)
                        -- print(octree)

                        -- https://github.com/aseprite/aseprite/blob/a5c36d0b0f3663d36a8105497458e86a41da310e/src/render/error_diffusion.cpp

                        -- Floyd Steinberg coefficients.
                        -- TODO: Multiply these by an input factor in [0, 1]?
                        local fs_1_16 = 0.0625
                        local fs_3_16 = 0.1875
                        local fs_5_16 = 0.3125
                        local fs_7_16 = 0.4375

                        local srcPxItr = srcImg:pixels()
                        local trgPixels = {}
                        local i = 1
                        for elm in srcPxItr do
                            local hex = elm()
                            trgPixels[i] = hex
                            i = i + 1
                        end

                        local srcPxlsLen = #trgPixels - 1
                        local srcWidth = srcImg.width
                        local srcHeight = srcImg.height
                        for k = 0, srcPxlsLen, 1 do
                            local y = k // srcWidth
                            local x = k % srcWidth

                            local srcHex = trgPixels[1 + k]
                            local ak = srcHex >> 0x18 & 0xff
                            local bk = srcHex >> 0x10 & 0xff
                            local gk = srcHex >> 0x08 & 0xff
                            local rk = srcHex & 0xff

                            local bn = 0
                            local gn = 0
                            local rn = 0

                            local bErr = 0
                            local gErr = 0
                            local rErr = 0

                            local srcClr = fromHex(srcHex)
                            local srcLab = rgbaToLab(srcClr)
                            local srcPt = v3new(srcLab.a, srcLab.b, srcLab.l)

                            local nearestPts = Octree.querySpherical(octree, srcPt, queryRad)
                            if #nearestPts > 0 then
                                local nearestPt = nearestPts[1]
                                local nearestHex = ptToHexDict[v3hash(nearestPt)]

                                bn = nearestHex >> 0x10 & 0xff
                                gn = nearestHex >> 0x08 & 0xff
                                rn = nearestHex & 0xff

                                trgPixels[1 + k] = ak << 0x18
                                    | bn << 0x10
                                    | gn << 0x08
                                    | rn

                                bErr = bk - bn
                                gErr = gk - gn
                                rErr = rk - rn
                            end

                            -- Neighboring indices. index = x + y * width
                            local xn1 = max(x - 1, 0)
                            local xp1 = min(x + 1, srcWidth - 1)
                            local yp1 = min(y + 1, srcHeight - 1)

                            local k0 = xp1 + y * srcWidth
                            local neighbor0 = trgPixels[1 + k0]

                            local an0 = neighbor0 >> 0x18 & 0xff
                            local bn0 = neighbor0 >> 0x10 & 0xff
                            local gn0 = neighbor0 >> 0x08 & 0xff
                            local rn0 = neighbor0 & 0xff

                            local bne0 = max(0, min(255, bn0 + bErr * fs_7_16))
                            local gne0 = max(0, min(255, gn0 + gErr * fs_7_16))
                            local rne0 = max(0, min(255, rn0 + rErr * fs_7_16))

                            trgPixels[1 + k0] = an0 << 0x18
                                | bne0 << 0x10
                                | gne0 << 0x08
                                | rne0

                            local k1 = xn1 + yp1 * srcWidth
                            local neighbor1 = trgPixels[1 + k1]

                            local an1 = neighbor1 >> 0x18 & 0xff
                            local bn1 = neighbor1 >> 0x10 & 0xff
                            local gn1 = neighbor1 >> 0x08 & 0xff
                            local rn1 = neighbor1 & 0xff

                            local bne1 = max(0, min(255, bn1 + bErr * fs_3_16))
                            local gne1 = max(0, min(255, gn1 + gErr * fs_3_16))
                            local rne1 = max(0, min(255, rn1 + rErr * fs_3_16))

                            trgPixels[1 + k1] = an1 << 0x18
                                | bne1 << 0x10
                                | gne1 << 0x08
                                | rne1

                            local k2 = x + yp1 * srcWidth
                            local neighbor2 = trgPixels[1 + k2]

                            local an2 = neighbor2 >> 0x18 & 0xff
                            local bn2 = neighbor2 >> 0x10 & 0xff
                            local gn2 = neighbor2 >> 0x08 & 0xff
                            local rn2 = neighbor2 & 0xff

                            local bne2 = max(0, min(255, bn2 + bErr * fs_5_16))
                            local gne2 = max(0, min(255, gn2 + gErr * fs_5_16))
                            local rne2 = max(0, min(255, rn2 + rErr * fs_5_16))

                            trgPixels[1 + k2] = an2 << 0x18
                                | bne2 << 0x10
                                | gne2 << 0x08
                                | rne2

                            local k3 = xp1 + yp1 * srcWidth
                            local neighbor3 = trgPixels[1 + k3]

                            local an3 = neighbor3 >> 0x18 & 0xff
                            local bn3 = neighbor3 >> 0x10 & 0xff
                            local gn3 = neighbor3 >> 0x08 & 0xff
                            local rn3 = neighbor3 & 0xff

                            local bne3 = max(0, min(255, bn3 + bErr * fs_1_16))
                            local gne3 = max(0, min(255, gn3 + gErr * fs_1_16))
                            local rne3 = max(0, min(255, rn3 + rErr * fs_1_16))

                            trgPixels[1 + k2] = an3 << 0x18
                                | bne3 << 0x10
                                | gne3 << 0x08
                                | rne3
                        end

                        local trgImg = Image(srcWidth, srcHeight)
                        local m = 1
                        for elm in trgImg:pixels() do
                            elm(trgPixels[m])
                            m = m + 1
                        end

                        -- Either copy to new layer or reassign image.
                        -- local copyToLayer = args.copyToLayer
                        local copyToLayer = true
                        if copyToLayer then
                            local trgLayer = sprite:newLayer()
                            trgLayer.name = srcCel.layer.name .. ".Dithered"
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