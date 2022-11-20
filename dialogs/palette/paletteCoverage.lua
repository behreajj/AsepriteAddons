dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local geometries = {
    "CUBE",
    "SPHERE"
}

local defaults = {
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,

    queryRad = 175,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,

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
    swatchAlpha = 217,
    bkgColor = Color { r = 32, g = 32, b = 32 },
    frames = 16,
    fps = 24,
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
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
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
    label = "Capacity (2^n):",
    min = defaults.minCapacityBits,
    max = defaults.maxCapacityBits,
    value = defaults.octCapacityBits
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
        dlg:modify { id = "lats", visible = isSphere }
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

dlg:newrow { always = false }

dlg:slider {
    id = "lats",
    label = "Latitudes:",
    min = 3,
    max = 48,
    value = defaults.lats,
    visible = defaults.geometry == "SPHERE"
}

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
    min = 0,
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
    text = string.format("%.3f", defaults.axx),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "axy",
    text = string.format("%.3f", defaults.axy),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "axz",
    text = string.format("%.3f", defaults.axz),
    decimals = AseUtilities.DISPLAY_DECIMAL
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
    max = 255,
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

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- Get palette.
        local startIndex = defaults.startIndex
        local count = defaults.count
        local palType = args.palType or defaults.palType --[[@as string]]
        local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, args.palFile, args.palPreset,
            startIndex, count)

        -- Create cover profile.
        -- This should be done BEFORE the coverage sprite is
        -- created, while the reference sprite is active.
        local cvrClrPrf = nil
        if palType == "ACTIVE" and app.activeSprite then
            cvrClrPrf = app.activeSprite.colorSpace
            if cvrClrPrf == nil then
                cvrClrPrf = ColorSpace()
            end
        else
            cvrClrPrf = ColorSpace { sRGB = true }
        end

        -- Sift for unique, non-mask colors.
        -- The dictionary must be checked to see if it contains
        -- an entry, otherwise the resulting array will have gaps
        -- and its length method will return a boundary with nil.
        local hexDictSrgb = {}
        local hexDictProfile = {}
        local lenHexesProfile = #hexesProfile
        local idxDict = 0
        local g = 0
        while g < lenHexesProfile do
            g = g + 1
            local hexProfile = hexesProfile[g]
            if (hexProfile & 0xff000000) ~= 0x0 then
                local hexProfOpaque = 0xff000000 | hexProfile
                if not hexDictProfile[hexProfOpaque] then
                    idxDict = idxDict + 1
                    hexDictProfile[hexProfOpaque] = idxDict

                    local hexSrgb = hexesSrgb[g]
                    local hexSrgbOpaque = 0xff000000 | hexSrgb
                    hexDictSrgb[hexSrgbOpaque] = idxDict
                end
            end
        end

        -- Convert dictionaries to lists.
        local uniqueHexesSrgb = {}
        for k, v in pairs(hexDictSrgb) do
            uniqueHexesSrgb[v] = k
        end

        local uniqueHexesProfile = {}
        for k, v in pairs(hexDictProfile) do
            uniqueHexesProfile[v] = k
        end

        -- Cache global functions used in for loops.
        local cos = math.cos
        local sin = math.sin
        local floor = math.floor
        local sRgbToSrLab2 = Clr.sRgbToSrLab2
        local fromHex = Clr.fromHex
        local rotax = Vec3.rotateInternal
        local v3hsh = Vec3.hashCode
        local octins = Octree.insert
        local search = Octree.queryInternal
        local distSq = Vec3.distSq
        local screen = Utilities.toScreen
        local drawCirc = AseUtilities.drawCircleFill
        local tablesort = table.sort

        -- Create Octree.
        local octCapacity = args.octCapacity
            or defaults.octCapacityBits
        octCapacity = 2 ^ octCapacity
        local bounds = Bounds3.lab()
        local octree = Octree.new(bounds, octCapacity, 1)

        -- Unpack unique colors to data.
        local uniqueHexesSrgbLen = #uniqueHexesSrgb
        local ptHexDict = {}
        local i = 0
        while i < uniqueHexesSrgbLen do
            i = i + 1
            local hexSrgb = uniqueHexesSrgb[i]
            local srgb = fromHex(hexSrgb)
            local lab = sRgbToSrLab2(srgb)
            local point = Vec3.new(lab.a, lab.b, lab.l)
            ptHexDict[v3hsh(point)] = uniqueHexesProfile[i]
            octins(octree, point)
        end

        Octree.cull(octree)

        -- Create geometry.
        local gridPts = nil
        local gridClrs = nil

        local swatchAlpha = args.swatchAlpha or defaults.swatchAlpha
        local swatchAlpha01 = swatchAlpha / 255.0
        local geometry = args.geometry or defaults.geometry
        if geometry == "SPHERE" then
            local lons = args.lons or defaults.lons --[[@as integer]]
            local lats = args.lats or (lons // 2) --[[@as integer]]
            local layersSphere = args.layersSphere
                or defaults.layersSphere --[[@as integer]]
            local minSat = args.minSat or defaults.minSat
            local maxSat = args.maxSat or defaults.maxSat

            minSat = minSat * 0.01
            maxSat = maxSat * 0.01

            gridPts = Vec3.gridSpherical(
                lons, lats, layersSphere,
                minSat * 0.5, maxSat * 0.5)
            gridClrs = Clr.gridHsl(
                lons, lats, layersSphere,
                minSat, maxSat,
                swatchAlpha01)
        else
            local cols = args.cols or defaults.cols --[[@as integer]]
            local rows = args.rows or defaults.rows --[[@as integer]]
            local layersCube = args.layersCube
                or defaults.layersCube --[[@as integer]]

            local lbx = args.lbx or defaults.lbx --[[@as number]]
            local lby = args.lby or defaults.lby --[[@as number]]
            local lbz = args.lbz or defaults.lbz --[[@as number]]

            local ubx = args.ubx or defaults.ubx --[[@as number]]
            local uby = args.uby or defaults.uby --[[@as number]]
            local ubz = args.ubz or defaults.ubz --[[@as number]]

            gridPts = Vec3.gridCartesian(
                cols, rows, layersCube,
                Vec3.new(lbx, lby, lbz),
                Vec3.new(ubx, uby, ubz))

            gridClrs = Clr.gridsRgb(
                cols, rows, layersCube,
                swatchAlpha01)
        end

        -- Create replacement colors.
        local queryRad = args.queryRad or defaults.queryRad
        local rsq = queryRad * queryRad
        local replaceClrs = {}
        local gridLen = #gridPts
        local swatchAlphaMask = swatchAlpha << 0x18
        local j = 0
        while j < gridLen do
            j = j + 1
            local srcClr = gridClrs[j]
            local srcLab = sRgbToSrLab2(srcClr)
            local srcLabPt = Vec3.new(
                srcLab.a, srcLab.b, srcLab.l)

            local nearPoint, _ = search(octree, srcLabPt, rsq, distSq)
            if nearPoint then
                local ptHash = v3hsh(nearPoint)
                replaceClrs[j] = swatchAlphaMask
                    | (ptHexDict[ptHash] & 0x00ffffff)
            else
                replaceClrs[j] = 0x0
            end
        end

        -- Create geometry rotation axis.
        local axx = args.axx or defaults.axx --[[@as number]]
        local axy = args.axy or defaults.axy --[[@as number]]
        local axz = args.axz or defaults.axz --[[@as number]]
        local axis = Vec3.new(axx, axy, axz)
        if Vec3.any(axis) then
            axis = Vec3.normalize(axis)
        else
            axis = Vec3.forward()
        end

        local coverSprite = Sprite(512, 512)
        coverSprite.filename = "Coverage"

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
            local fov = 0.86602540378444
            local aspect = width / height
            projection = Mat4.perspective(
                fov, aspect, 0.001, 1000.0)
        else
            projection = Mat4.orthographic(
                -halfWidth, halfWidth,
                -halfHeight, halfHeight,
                0.001, 1000.0)
        end

        -- Create camera and modelview matrices.
        local camera = Mat4.cameraIsometric(
            1.0, -1.0, 1.0, "RIGHT")
        local su = 0.7071 * math.min(width, height)
        local model = Mat4.fromScale(su, su, su)
        local modelview = Mat4.mul(model, camera)

        local hToTheta = 6.2831853071796 / reqFrames
        local minSwatchSize = args.minSwatchSize
        local maxSwatchSize = args.maxSwatchSize
        local swatchDiff = maxSwatchSize - minSwatchSize

        local pts2d = {}
        local zMin = 2147483647
        local zMax = -2147483648
        local comparator = function(a, b)
            return b.point.z < a.point.z
        end

        local h = 0
        while h < reqFrames do
            local theta = h * hToTheta
            local cosa = cos(theta)
            local sina = sin(theta)
            local frame2d = {}
            local k = 0
            while k < gridLen do
                k = k + 1
                local vec = gridPts[k]
                local vr = rotax(vec, cosa, sina, axis)
                local scrpt = screen(
                    modelview, projection, vr,
                    width, height)

                if scrpt.z < zMin then zMin = scrpt.z end
                if scrpt.z > zMax then zMax = scrpt.z end

                frame2d[k] = {
                    point = scrpt,
                    color = replaceClrs[k] }
            end
            -- Depth sorting.
            tablesort(frame2d, comparator)
            h = h + 1
            pts2d[h] = frame2d
        end

        -- Create layer.
        local layer = coverSprite.layers[#coverSprite.layers]
        layer.name = string.format(
            "Palette.Coverage.%s.%s",
            geometry, projPreset)

        local zDiff = zMin - zMax
        local zDenom = 1.0
        if zDiff ~= 0.0 then zDenom = 1.0 / zDiff end

        -- Create background image once, then clone.
        local bkgImg = Image(width, height)
        local bkgHex = args.bkgColor.rgbaPixel
        for elm in bkgImg:pixels() do elm(bkgHex) end

        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)
        app.transaction(function()
            local m = 0
            while m < reqFrames do
                m = m + 1
                local frame = coverSprite.frames[m]
                frame.duration = duration
                local img = bkgImg:clone()
                local frame2d = pts2d[m]

                local n = 0
                while n < gridLen do
                    n = n + 1
                    local packet = frame2d[n]
                    local screenPoint = packet.point

                    -- Remap z to swatch size based on min and max.
                    local scl = minSwatchSize + swatchDiff
                        * ((screenPoint.z - zMax) * zDenom)

                    drawCirc(
                        img,
                        floor(0.5 + screenPoint.x),
                        floor(0.5 + screenPoint.y),
                        floor(0.5 + scl),
                        packet.color)
                end

                coverSprite:newCel(layer, frame, img)
            end
        end)

        app.activeSprite = coverSprite
        app.activeFrame = coverSprite.frames[1]

        -- Create and set the coverage palette.
        -- Wait to do this until the end, so we have greater
        -- assurance that the coverSprite is app.active.
        AseUtilities.setPalette(
            uniqueHexesProfile, coverSprite, 1)
        app.refresh()
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
