dofile("../../support/mat4.lua")
dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local geometries = {
    "CUBE",
    "SPHERE"
}

local defaults = {
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,

    queryRad = 175,
    octCapacity = 16,

    projection = "ORTHO",
    geometry = "CUBE",

    cols = 8,
    rows = 8,
    layersCube = 8,
    lbx = -0.35355338,
    lby = -0.35355338,
    lbz = -0.35355338,
    ubx = 0.35355338,
    uby = 0.35355338,
    ubz = 0.35355338,

    lons = 24,
    lats = 12,
    layersSphere = 3,
    minSat = 33,
    maxSat = 100,

    axx = 0.0,
    axy = 0.0,
    axz = 1.0,
    minSwatchSize = 2,
    maxSwatchSize = 10,
    swatchAlpha = 85,
    bkgColor = Color(0xff202020),
    frames = 16,
    duration = 100.0,
    pullFocus = false
}

local dlg = Dialog { title = "Palette Coverage" }

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
    filetypes = { "aseprite", "gpl", "pal" },
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

dlg:combobox {
    id = "projection",
    label = "Projection:",
    option = defaults.projection,
    options = AseUtilities.PROJECTIONS
}

dlg:newrow { always = false }

dlg:combobox {
    id = "geometry",
    label = "Geometry:",
    option = defaults.geometry,
    options = geometries,
    onchange = function()
        local md = dlg.data.geometry
        local isCube = md == "CUBE"
        local isSphere = md == "SPHERE"

        dlg:modify { id = "cols", visible = isCube }
        dlg:modify { id = "rows", visible = isCube }
        dlg:modify { id = "layersCube", visible = isCube }

        dlg:modify { id = "lons", visible = isSphere }
        -- dlg:modify { id = "lats", visible = isSphere }
        dlg:modify { id = "layersSphere", visible = isSphere }
        dlg:modify { id = "minSat", visible = isSphere }
        dlg:modify { id = "maxSat", visible = isSphere }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lons",
    label = "Longitudes:",
    min = 3,
    max = 96,
    value = defaults.lons,
    visible = defaults.geometry == "SPHERE"
}

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "lats",
--     label = "Latitudes:",
--     min = 3,
--     max = 48,
--     value = defaults.lats,
--     visible = defaults.geometry == "SPHERE"
-- }

dlg:newrow { always = false }

dlg:slider {
    id = "layersSphere",
    label = "Layers:",
    min = 1,
    max = 12,
    value = defaults.layersSphere,
    visible = defaults.geometry == "SPHERE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "minSat",
    label = "Saturation:",
    min = 1,
    max = 50,
    value = defaults.minSat,
    visible = defaults.geometry == "SPHERE"
}

dlg:slider {
    id = "maxSat",
    min = 51,
    max = 100,
    value = defaults.maxSat,
    visible = defaults.geometry == "SPHERE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cols",
    label = "Resolution:",
    min = 3,
    max = 32,
    value = defaults.cols,
    visible = defaults.geometry == "CUBE"
}

dlg:slider {
    id = "rows",
    min = 3,
    max = 32,
    value = defaults.rows,
    visible = defaults.geometry == "CUBE"
}

dlg:slider {
    id = "layersCube",
    min = 3,
    max = 32,
    value = defaults.layersCube,
    visible = defaults.geometry == "CUBE"
}

dlg:newrow { always = false }

dlg:number {
    id = "axx",
    label = "Rot Axis:",
    text = string.format("%.5f", defaults.axx),
    decimals = 5
}

dlg:number {
    id = "axy",
    text = string.format("%.5f", defaults.axy),
    decimals = 5
}

dlg:number {
    id = "axz",
    text = string.format("%.5f", defaults.axz),
    decimals = 5
}

dlg:newrow { always = false }

dlg:slider {
    id = "minSwatchSize",
    label = "Swatch:",
    min = 1,
    max = 60,
    value = defaults.minSwatchSize
}

dlg:slider {
    id = "maxSwatchSize",
    min = 4,
    max = 64,
    value = defaults.maxSwatchSize
}

dlg:newrow { always = false }

dlg:slider {
    id = "swatchAlpha",
    label = "Alpha:",
    min = 1,
    max = 100,
    value = defaults.swatchAlpha
}

dlg:newrow { always = false }

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = defaults.bkgColor
}

dlg:newrow { always = false }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frames
}

dlg:newrow { always = false }

dlg:number {
    id = "duration",
    label = "Duration:",
    text = string.format("%.1f", defaults.duration),
    decimals = 1
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- Search for appropriate source palette.
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
        elseif palType == "ACTIVE" and app.activeSprite then
            local activeProfile = app.activeSprite.colorSpace
            app.activeSprite:convertColorSpace(ColorSpace{ sRGB = true })
            srcPal = app.activeSprite.palettes[1]
            app.activeSprite:convertColorSpace(activeProfile)
        end

        if srcPal then

            -- Adjust color space so that color conversions
            -- from sRGB to CIE LAB work properly.
            local sourceColorSpace = nil
            if palType == "ACTIVE" and app.activeSprite then
                sourceColorSpace = app.activeSprite.colorSpace
            else
                sourceColorSpace = ColorSpace { sRGB = true }
            end
            if sourceColorSpace == nil then
                sourceColorSpace = ColorSpace()
            end

            local coverSprite = Sprite(512, 512)
            coverSprite:setPalette(srcPal)
            coverSprite:convertColorSpace(ColorSpace { sRGB = true })

            -- Validate range of palette to sample.
            local palStart = defaults.palStart
            local palCount = defaults.palCount
            palStart = math.min(#srcPal - 1, palStart)
            palCount = math.min(palCount, #srcPal - palStart, 256)

            -- Find palette's unique values only.
            -- Alpha is masked out of hexadecimal values.
            local hexDict = {}
            for i = 0, palCount - 1, 1 do
                local idx = palStart + i
                local aseColor = srcPal:getColor(idx)
                local hex = 0xff000000 | aseColor.rgbaPixel
                hexDict[hex] = idx
            end

            local hexes = {}
            local incr = 1
            for key, _ in pairs(hexDict) do
                hexes[incr] = key
                incr = incr + 1
            end

            -- Sort.
            table.sort(hexes,
                function(a, b)
                    return hexDict[a] < hexDict[b]
                end)

            -- Cache global functions used in for loops.
            local cos = math.cos
            local sin = math.sin
            local trunc = math.tointeger
            local linearToXyz = Clr.lRgbaToXyzInternal
            local xyzToLab = Clr.xyzToLab
            local rgbaToLab = Clr.sRgbaToLab
            local labToRgba = Clr.labTosRgba
            local toHex = Clr.toHex
            local fromHex = Clr.fromHex
            local stdToLin = Clr.sRgbaTolRgbaInternal
            local rotax = Vec3.rotateInternal
            local screen = Utilities.toScreen
            local drawCirc = AseUtilities.drawCircleFill

            -- Unpack unique entries to data.
            local points = {}
            for i = 1, #hexes, 1 do
                local hex = hexes[i]

                -- The LUT shortcut is not used because here
                -- accuracy is preferred over speed. Ideally,
                -- the color picker should be able to match
                -- to the palette without being put into
                -- Best Fit Index mode.

                local srgb = fromHex(hex)
                local lrgb = stdToLin(srgb)
                local xyz = linearToXyz(lrgb.r, lrgb.g, lrgb.b, 1.0)
                local lab = xyzToLab(xyz.x, xyz.y, xyz.z, 1.0)

                local point = Vec3.new(lab.a, lab.b, lab.l)
                points[i] = point
            end

            -- Create Octree.
            local octCapacity = args.octCapacity
            local bounds = Bounds3.cieLab()
            local octree = Octree.new(bounds, octCapacity, 0)
            Octree.insertAll(octree, points)

            -- Create geometry.
            local gridPts = nil
            local gridClrs = nil

            local swatchAlpha = args.swatchAlpha or defaults.swatchAlpha
            swatchAlpha = swatchAlpha * 0.01
            local geometry = args.geometry
            if geometry == "SPHERE" then

                local lons = args.lons or defaults.lons
                local lats = args.lats or (lons // 2)
                local layersSphere = args.layersSphere
                local minSat = args.minSat * 0.01
                local maxSat = args.maxSat * 0.01

                gridPts = Vec3.gridSpherical(
                    lons, lats, layersSphere,
                    minSat * 0.5, maxSat * 0.5, false)
                gridClrs = Clr.gridHsl(
                    lons, lats, layersSphere,
                    minSat, maxSat,
                    swatchAlpha)
            else
                local cols = args.cols
                local rows = args.rows
                local layersCube = args.layersCube

                local lbx = args.lbx or defaults.lbx
                local lby = args.lby or defaults.lby
                local lbz = args.lbz or defaults.lbz

                local ubx = args.ubx or defaults.ubx
                local uby = args.uby or defaults.uby
                local ubz = args.ubz or defaults.ubz

                gridPts = Vec3.gridCartesian(
                    cols, rows, layersCube,
                    Vec3.new(lbx, lby, lbz),
                    Vec3.new(ubx, uby, ubz))

                gridClrs = Clr.gridsRgb(
                    cols, rows, layersCube,
                    swatchAlpha)
            end

            -- Create replacement colors.
            local queryRad = args.queryRad or defaults.queryRad
            local replaceClrs = {}
            local gridLen = #gridPts
            for i = 1, gridLen, 1 do
                local srcClr = gridClrs[i]
                local srcLab = rgbaToLab(srcClr)
                local srcLabPt = Vec3.new(
                    srcLab.a, srcLab.b, srcLab.l)

                local results = {}
                Octree.querySphericalInternal(
                    octree, srcLabPt, queryRad, results, 256)
                if #results > 1 then
                    local nearestPt = results[1].point

                    -- TODO: Use ptToHexDict instead?
                    local nearestClr = labToRgba(
                        nearestPt.z,
                        nearestPt.x,
                        nearestPt.y,
                        swatchAlpha)
                    replaceClrs[i] = toHex(nearestClr)
                else
                    replaceClrs[i] = 0x00000000
                end
            end

            -- Create geometry rotation axis.
            local axx = args.axx or defaults.axx
            local axy = args.axy or defaults.axy
            local axz = args.axz or defaults.axz
            local axis = Vec3.new(axx, axy, axz)
            if Vec3.any(axis) then
                axis = Vec3.normalize(axis)
            else
                axis = Vec3.forward()
            end

            -- Add requested number of frames.
            local oldFrameLen = #coverSprite.frames
            local reqFrames = args.frames
            local needed = math.max(0, reqFrames - oldFrameLen)
            app.transaction(function()
                for _ = 1, needed, 1 do
                    coverSprite:newEmptyFrame()
                end
            end)

            local width = coverSprite.width
            local height = coverSprite.height
            local halfWidth = width * 0.5
            local halfHeight = height * 0.5

            -- Create projection matrix.
            local projection = nil
            local projPreset = args.projection
            if projPreset == "PERSPECTIVE" then
                local fov = 0.8660254037844386
                local aspect = width / height
                projection = Mat4.perspective(
                    fov, aspect)
            else
                projection = Mat4.orthographic(
                    -halfWidth, halfWidth,
                    -halfHeight, halfHeight,
                    0.001, 1000.0)
            end

            -- Create camera and modelview matrices.
            local camera = Mat4.cameraIsometric(
                1.0, -1.0, 1.0, "RIGHT")
            local model = Mat4.fromScale(
                0.7071 * math.min(width, height))
            local modelview = model * camera

            local hToTheta = 6.283185307179586 / reqFrames
            local minSwatchSize = args.minSwatchSize
            local maxSwatchSize = args.maxSwatchSize
            local swatchDiff = maxSwatchSize - minSwatchSize

            local pts2d = {}
            local zMin = 999999
            local zMax = -999999
            for h = 1, reqFrames, 1 do
                local frame2d = {}
                local theta = (h - 1) * hToTheta
                local cosa = cos(theta)
                local sina = sin(theta)
                for i = 1, gridLen, 1 do
                    local vec = gridPts[i]

                    -- TODO: Would this rotation be better if you
                    -- used a quaternion instead?
                    local vr = rotax(vec, cosa, sina, axis)
                    local scrpt = screen(
                        modelview, projection, vr,
                        width, height)

                    -- TODO: Introduce frustum near plane
                    -- culling so that a cross-section of
                    -- the cube or sphere can be seen.
                    -- Alternatively, quantize to a sector then
                    -- assign to separate layers?
                    if scrpt.z < zMin then zMin = scrpt.z end
                    if scrpt.z > zMax then zMax = scrpt.z end

                    frame2d[i] = {
                        point = scrpt,
                        color = replaceClrs[i] }
                end

                -- Depth sorting.
                table.sort(frame2d,
                    function(a, b)
                        return b.point.z < a.point.z
                    end)
                pts2d[h] = frame2d
            end

            -- Create layer.
            local layer = coverSprite.layers[#coverSprite.layers]
            layer.name = "Palette.Coverage."
                .. geometry .. "."
                .. projPreset

            local zDiff = zMin - zMax
            local zDenom = 1.0
            if zDiff ~= 0.0 then zDenom = 1.0 / zDiff end

            -- Create background image once, then clone.
            local bkgImg = Image(width, height)
            local bkgHex = args.bkgColor.rgbaPixel
            for elm in bkgImg:pixels() do
                elm(bkgHex)
            end

            local duration = args.duration or defaults.duration
            duration = duration * 0.001
            app.transaction(function()
                for h = 1, reqFrames, 1 do
                    local frame = coverSprite.frames[h]
                    frame.duration = duration
                    local cel = coverSprite:newCel(layer, frame)
                    local img = bkgImg:clone()
                    local frame2d = pts2d[h]

                    for i = 1, gridLen, 1 do

                        local packet = frame2d[i]
                        local scrpt = packet.point

                        -- Remap z to swatch size based on min and max.
                        local scl = minSwatchSize + swatchDiff
                            * ((scrpt.z - zMax) * zDenom)

                        drawCirc(
                            img,
                            trunc(0.5 + scrpt.x),
                            trunc(0.5 + scrpt.y),
                            trunc(0.5 + scl),
                            packet.color)
                    end

                    cel.image = img
                end
            end)

            coverSprite:assignColorSpace(sourceColorSpace)
            app.activeSprite = coverSprite
            app.refresh()
        else
            app.alert("The source palette could not be found.")
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