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

local function findNear(x, y, w, srcPixels, oct, radius, ptToHexDict, trgPixels)
    local index = 1 + x + y * w
    local srcHex = srcPixels[index]

    local bSrc = srcHex >> 0x10 & 0xff
    local gSrc = srcHex >> 0x08 & 0xff
    local rSrc = srcHex & 0xff

    local bErr = 0
    local gErr = 0
    local rErr = 0

    local trgHex = 0

    -- local clr = Clr.fromHex(srcHex)
    local clr = Clr.new(
        rSrc * 0.00392156862745098,
        gSrc * 0.00392156862745098,
        bSrc * 0.00392156862745098,
        1.0)
    local lab = Clr.sRgbaToLab(clr)
    local pt = Vec3.new(lab.a, lab.b, lab.l)

    -- TODO: Consider using query internal.
    -- New array would have to be created.
    local nearestPts = Octree.querySpherical(oct, pt, radius)

    if #nearestPts > 0 then
        local nearestPt = nearestPts[1]
        local nearestHex = ptToHexDict[Vec3.hashCode(nearestPt)]
        if nearestHex then
            local bTrg = nearestHex >> 0x10 & 0xff
            local gTrg = nearestHex >> 0x08 & 0xff
            local rTrg = nearestHex & 0xff

            bErr = bSrc - bTrg
            gErr = gSrc - gTrg
            rErr = rSrc - rTrg

            local aSrc = srcHex >> 0x18 & 0xff
            trgHex = aSrc << 0x18
                | bTrg << 0x10
                | gTrg << 0x08
                | rTrg
            trgPixels[index] = trgHex
        else
            trgPixels[index] = trgHex
        end
    else
        trgPixels[index] = trgHex
    end

    return rErr, gErr, bErr
end

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

dlg:slider {
    id = "factor",
    label = "Factor:",
    min = 0,
    max = 100,
    value = defaults.factor
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
                        local rgbaToLab = Clr.sRgbaToLab
                        local v3new = Vec3.new
                        local v3hash = Vec3.hashCode

                        local oldMode = sprite.colorMode
                        app.command.ChangePixelFormat { format = "rgb" }

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
                        end

                        -- Create Octree.
                        local octCapacity = args.octCapacity
                        local bounds = Bounds3.newByRef(
                            Vec3.new(-110.0, -110.0, -1.0),
                            Vec3.new(110.0, 110.0, 101.0))
                        local octree = Octree.new(bounds, octCapacity, 0)
                        Octree.insertAll(octree, points)
                        -- print(octree)

                        -- Floyd Steinberg coefficients.
                        local factor = args.factor or defaults.factor
                        factor = factor * 0.01
                        local fs_1_16 = 0.0625 * factor
                        local fs_3_16 = 0.1875 * factor
                        local fs_5_16 = 0.3125 * factor
                        local fs_7_16 = 0.4375 * factor

                        local srcPxItr = srcImg:pixels()
                        local trgPixels = {}
                        local i = 1
                        for elm in srcPxItr do
                            trgPixels[i] = elm()
                            i = i + 1
                        end

                        local srcWidth = srcImg.width
                        local srcHeight = srcImg.height

                        -- for x = 0, srcWidth - 1, 1 do
                        --     findNear(x, 0, srcWidth, trgPixels, octree, queryRad, ptToHexDict, trgPixels)
                        --     findNear(x, srcHeight - 1, srcWidth, trgPixels, octree, queryRad, ptToHexDict, trgPixels)
                        -- end

                        -- for y = 1, srcHeight - 2, 1 do
                        --     findNear(0, y, srcWidth, trgPixels, octree, queryRad, ptToHexDict, trgPixels)
                        --     findNear(srcWidth - 1, y, srcWidth, trgPixels, octree, queryRad, ptToHexDict, trgPixels)
                        -- end

                        for y = 0, srcHeight - 1, 1 do
                            local yp1 = y + 1

                            local yw = y * srcWidth
                            local yp1w = yp1 * srcWidth

                            for x = 0, srcWidth - 1, 1 do
                                local rErr = 0
                                local gErr = 0
                                local bErr = 0

                                rErr, gErr, bErr = findNear(
                                    x, y, srcWidth,
                                    trgPixels, octree, queryRad,
                                    ptToHexDict, trgPixels)

                                local xn1 = x - 1
                                local xp1 = x + 1

                                if xp1 < srcWidth then
                                    local k0 = 1 + xp1 + yw
                                    local neighbor0 = trgPixels[k0]

                                    local an0 = neighbor0 >> 0x18 & 0xff
                                    local bn0 = neighbor0 >> 0x10 & 0xff
                                    local gn0 = neighbor0 >> 0x08 & 0xff
                                    local rn0 = neighbor0 & 0xff

                                    local bne0 = max(0, min(255, bn0 + bErr * fs_7_16))
                                    local gne0 = max(0, min(255, gn0 + gErr * fs_7_16))
                                    local rne0 = max(0, min(255, rn0 + rErr * fs_7_16))

                                    trgPixels[k0] = an0 << 0x18
                                        | bne0 << 0x10
                                        | gne0 << 0x08
                                        | rne0
                                end

                                if xn1 > -1 and yp1 < srcHeight then
                                    local k1 = 1 + xn1 + yp1w
                                    local neighbor1 = trgPixels[k1]

                                    local an1 = neighbor1 >> 0x18 & 0xff
                                    local bn1 = neighbor1 >> 0x10 & 0xff
                                    local gn1 = neighbor1 >> 0x08 & 0xff
                                    local rn1 = neighbor1 & 0xff

                                    local bne1 = max(0, min(255, bn1 + bErr * fs_3_16))
                                    local gne1 = max(0, min(255, gn1 + gErr * fs_3_16))
                                    local rne1 = max(0, min(255, rn1 + rErr * fs_3_16))

                                    trgPixels[k1] = an1 << 0x18
                                        | bne1 << 0x10
                                        | gne1 << 0x08
                                        | rne1
                                end

                                if yp1 < srcHeight then
                                    local k2 = 1 + x + yp1w
                                    local neighbor2 = trgPixels[k2]

                                    local an2 = neighbor2 >> 0x18 & 0xff
                                    local bn2 = neighbor2 >> 0x10 & 0xff
                                    local gn2 = neighbor2 >> 0x08 & 0xff
                                    local rn2 = neighbor2 & 0xff

                                    local bne2 = max(0, min(255, bn2 + bErr * fs_5_16))
                                    local gne2 = max(0, min(255, gn2 + gErr * fs_5_16))
                                    local rne2 = max(0, min(255, rn2 + rErr * fs_5_16))

                                    trgPixels[k2] = an2 << 0x18
                                        | bne2 << 0x10
                                        | gne2 << 0x08
                                        | rne2
                                end

                                if xp1 < srcWidth and yp1 < srcHeight then
                                    local k3 = 1 + xp1 + yp1w
                                    local neighbor3 = trgPixels[k3]

                                    local an3 = neighbor3 >> 0x18 & 0xff
                                    local bn3 = neighbor3 >> 0x10 & 0xff
                                    local gn3 = neighbor3 >> 0x08 & 0xff
                                    local rn3 = neighbor3 & 0xff

                                    local bne3 = max(0, min(255, bn3 + bErr * fs_1_16))
                                    local gne3 = max(0, min(255, gn3 + gErr * fs_1_16))
                                    local rne3 = max(0, min(255, rn3 + rErr * fs_1_16))

                                    trgPixels[k3] = an3 << 0x18
                                        | bne3 << 0x10
                                        | gne3 << 0x08
                                        | rne3
                                end
                            end
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