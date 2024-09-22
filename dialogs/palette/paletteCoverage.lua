dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local palTypes <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    palType = "ACTIVE",
    startIndex = 0,
    count = 256,
    queryRad = 175,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    projection = "ORTHO",
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
    bkgColor = 0xff101010,
    frames = 16,
    fps = 24,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Palette Coverage" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = defaults.palType == "FILE"
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

dlg:slider {
    id = "cols",
    label = "Resolution:",
    min = 3,
    max = 32,
    value = defaults.cols
}

dlg:slider {
    id = "rows",
    min = 3,
    max = 32,
    value = defaults.rows
}

dlg:slider {
    id = "layersCube",
    min = 3,
    max = 32,
    value = defaults.layersCube
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
    color = AseUtilities.hexToAseColor(defaults.bkgColor)
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
        local args <const> = dlg.data

        -- Get palette.
        local startIndex <const> = defaults.startIndex
        local count <const> = defaults.count
        local palType <const> = args.palType or defaults.palType --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palType, palFile, startIndex, count)

        -- Create profile.
        -- This should be done BEFORE the sprite is
        -- created, while the reference sprite is active.
        local cvrClrPrf = nil
        if palType == "ACTIVE" and app.site.sprite then
            cvrClrPrf = app.site.sprite.colorSpace
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
        ---@type table<integer, integer>
        local hexDictSrgb <const> = {}
        ---@type table<integer, integer>
        local hexDictProfile <const> = {}
        local lenHexesProfile <const> = #hexesProfile
        local idxDict = 0
        local g = 0
        while g < lenHexesProfile do
            g = g + 1
            local hexProfile <const> = hexesProfile[g]
            if (hexProfile & 0xff000000) ~= 0x0 then
                local hexProfOpaque <const> = 0xff000000 | hexProfile
                if not hexDictProfile[hexProfOpaque] then
                    idxDict = idxDict + 1
                    hexDictProfile[hexProfOpaque] = idxDict

                    local hexSrgb <const> = hexesSrgb[g]
                    local hexSrgbOpaque <const> = 0xff000000 | hexSrgb
                    hexDictSrgb[hexSrgbOpaque] = idxDict
                end
            end
        end

        -- Convert dictionaries to lists.
        ---@type integer[]
        local uniqueHexesSrgb <const> = {}
        for k, v in pairs(hexDictSrgb) do
            uniqueHexesSrgb[v] = k
        end

        ---@type integer[]
        local uniqueHexesProfile <const> = {}
        for k, v in pairs(hexDictProfile) do
            uniqueHexesProfile[v] = k
        end

        -- Cache global functions used in for loops.
        local cos <const> = math.cos
        local sin <const> = math.sin
        local floor <const> = math.floor
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local fromHex <const> = Clr.fromHexAbgr32
        local rotax <const> = Vec3.rotateInternal
        local v3hash <const> = Vec3.hashCode
        local v3new <const> = Vec3.new
        local octins <const> = Octree.insert
        local search <const> = Octree.queryInternal
        local distFunc <const> = function(a, b)
            local da <const> = b.x - a.x
            local db <const> = b.y - a.y
            return math.sqrt(da * da + db * db)
                + math.abs(b.z - a.z)
        end
        local screen <const> = Utilities.toScreen
        local drawCirc <const> = AseUtilities.drawCircleFill
        local getPixels <const> = AseUtilities.getPixels
        local setPixels <const> = AseUtilities.setPixels
        local tablesort <const> = table.sort

        -- Create Octree.
        local octCapacity = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        octCapacity = 1 << octCapacity
        local bounds <const> = Bounds3.lab()
        local octree <const> = Octree.new(bounds, octCapacity, 1)

        -- Unpack unique colors to data.
        local uniqueHexesSrgbLen <const> = #uniqueHexesSrgb
        ---@type table<integer, integer>
        local ptHexDict <const> = {}
        local i = 0
        while i < uniqueHexesSrgbLen do
            i = i + 1
            local hexSrgb <const> = uniqueHexesSrgb[i]
            local srgb <const> = fromHex(hexSrgb)
            local lab <const> = sRgbToLab(srgb)
            local point <const> = Vec3.new(lab.a, lab.b, lab.l)
            ptHexDict[v3hash(point)] = uniqueHexesProfile[i]
            octins(octree, point)
        end

        Octree.cull(octree)

        local swatchAlpha <const> = args.swatchAlpha
            or defaults.swatchAlpha --[[@as integer]]
        local swatchAlpha01 <const> = swatchAlpha / 255.0
        local cols <const> = args.cols or defaults.cols --[[@as integer]]
        local rows <const> = args.rows or defaults.rows --[[@as integer]]
        local layersCube <const> = args.layersCube
            or defaults.layersCube --[[@as integer]]

        local lbx <const> = args.lbx or defaults.lbx --[[@as number]]
        local lby <const> = args.lby or defaults.lby --[[@as number]]
        local lbz <const> = args.lbz or defaults.lbz --[[@as number]]

        local ubx <const> = args.ubx or defaults.ubx --[[@as number]]
        local uby <const> = args.uby or defaults.uby --[[@as number]]
        local ubz <const> = args.ubz or defaults.ubz --[[@as number]]

        -- Create geometry.
        local gridPts <const> = Vec3.gridCartesian(
            cols, rows, layersCube,
            Vec3.new(lbx, lby, lbz),
            Vec3.new(ubx, uby, ubz))

        local gridClrs <const> = Clr.gridsRgb(
            cols, rows, layersCube,
            swatchAlpha01)

        -- Create replacement colors.
        local queryRad <const> = args.queryRad
            or defaults.queryRad --[[@as number]]

        ---@type integer[]
        local replaceRgbs <const> = {}
        local gridLen <const> = #gridPts
        local j = 0
        while j < gridLen do
            local j4 <const> = j * 4
            j = j + 1
            local srcClr <const> = gridClrs[j]
            local srcLab <const> = sRgbToLab(srcClr)
            local srcLabPt <const> = v3new(
                srcLab.a, srcLab.b, srcLab.l)

            local nearPoint <const>, _ <const> = search(octree, srcLabPt, queryRad, distFunc)
            if nearPoint then
                local ptHash <const> = v3hash(nearPoint)
                local abgr32 <const> = ptHexDict[ptHash]
                replaceRgbs[1 + j4] = abgr32 & 0xff
                replaceRgbs[2 + j4] = (abgr32 >> 0x08) & 0xff
                replaceRgbs[3 + j4] = (abgr32 >> 0x10) & 0xff
                replaceRgbs[4 + j4] = swatchAlpha
            else
                replaceRgbs[1 + j4] = 0
                replaceRgbs[2 + j4] = 0
                replaceRgbs[3 + j4] = 0
                replaceRgbs[4 + j4] = 0
            end
        end

        -- Create geometry rotation axis.
        local axx <const> = args.axx or defaults.axx --[[@as number]]
        local axy <const> = args.axy or defaults.axy --[[@as number]]
        local axz <const> = args.axz or defaults.axz --[[@as number]]
        local axis = Vec3.new(axx, axy, axz)
        if Vec3.any(axis) then
            axis = Vec3.normalize(axis)
        else
            axis = Vec3.forward()
        end

        -- TODO: Check if you can reuse sprite spec
        local coverSprite <const> = AseUtilities.createSprite(
            AseUtilities.createSpec(512, 512),
            "Palette Coverage")

        -- Add requested number of frames.
        local oldFrameLen <const> = #coverSprite.frames
        local reqFrames <const> = args.frames
        local needed <const> = math.max(0, reqFrames - oldFrameLen)
        app.transaction("New Frames", function()
            for _ = 1, needed, 1 do
                coverSprite:newEmptyFrame()
            end
        end)

        local width <const> = coverSprite.width
        local height <const> = coverSprite.height
        local halfWidth <const> = width * 0.5
        local halfHeight <const> = height * 0.5

        -- Create projection matrix.
        local projection = nil
        local projPreset <const> = args.projection
        if projPreset == "PERSPECTIVE" then
            local fov <const> = 0.86602540378444
            local aspect <const> = width / height
            projection = Mat4.perspective(
                fov, aspect, 0.001, 1000.0)
        else
            projection = Mat4.orthographic(
                -halfWidth, halfWidth,
                -halfHeight, halfHeight,
                0.001, 1000.0)
        end

        -- Create camera and modelview matrices.
        local camera <const> = Mat4.cameraIsometric(
            1.0, -1.0, 1.0, "RIGHT")
        local su <const> = 0.7071 * math.min(width, height)
        local model <const> = Mat4.fromScale(su, su, su)
        local modelview <const> = Mat4.mul(model, camera)

        local hToTheta <const> = 6.2831853071796 / reqFrames
        local minSwatchSize <const> = args.minSwatchSize --[[@as integer]]
        local maxSwatchSize <const> = args.maxSwatchSize --[[@as integer]]
        local swatchDiff <const> = maxSwatchSize - minSwatchSize

        ---@type { point: Vec3, r: integer, g: integer, b: integer, a: integer}[][]
        local pts2d <const> = {}
        local zMin = 2147483647
        local zMax = -2147483648
        local comparator <const> = function(a, b)
            return b.point.z < a.point.z
        end

        local h = 0
        while h < reqFrames do
            local theta <const> = h * hToTheta
            local cosa <const> = cos(theta)
            local sina <const> = sin(theta)
            ---@type { point: Vec3, r: integer, g: integer, b: integer, a: integer}[]
            local frame2d <const> = {}
            local k = 0
            while k < gridLen do
                local k4 <const> = k * 4
                k = k + 1
                local vec <const> = gridPts[k]
                local vr <const> = rotax(vec, cosa, sina, axis)
                local scrpt <const> = screen(
                    modelview, projection, vr,
                    width, height)

                if scrpt.z < zMin then zMin = scrpt.z end
                if scrpt.z > zMax then zMax = scrpt.z end

                frame2d[k] = {
                    point = scrpt,
                    r = replaceRgbs[1 + k4],
                    g = replaceRgbs[2 + k4],
                    b = replaceRgbs[3 + k4],
                    a = replaceRgbs[4 + k4]
                }
            end
            -- Depth sorting.
            tablesort(frame2d, comparator)
            h = h + 1
            pts2d[h] = frame2d
        end

        -- Create layer.
        local layer <const> = coverSprite.layers[#coverSprite.layers]
        layer.name = string.format("Palette Coverage %s", projPreset)

        local zDiff = zMin - zMax
        local zDenom = 1.0
        if zDiff ~= 0.0 then zDenom = 1.0 / zDiff end

        -- Create background image once, then clone.
        local bkgImg <const> = Image(width, height)
        local bkgColor <const> = args.bkgColor --[[@as Color]]
        local bkgHex <const> = AseUtilities.aseColorToHex(bkgColor, ColorMode.RGB)
        bkgImg:clear(bkgHex)
        local bkgPixels <const> = getPixels(bkgImg)
        local lenBkgPixels <const> = #bkgPixels

        local fps <const> = args.fps or defaults.fps --[[@as integer]]
        local duration <const> = 1.0 / math.max(1, fps)
        app.transaction("Palette Coverage", function()
            local m = 0
            while m < reqFrames do
                m = m + 1
                local frame2d <const> = pts2d[m]
                local frame <const> = coverSprite.frames[m]
                frame.duration = duration

                ---@type integer[]
                local imgPixels <const> = {}
                local o = 0
                while o < lenBkgPixels do
                    o = o + 1
                    imgPixels[o] = bkgPixels[o]
                end

                local n = 0
                while n < gridLen do
                    n = n + 1
                    local packet <const> = frame2d[n]
                    local screenPoint <const> = packet.point

                    -- Remap z to swatch size based on min and max.
                    local scl <const> = minSwatchSize + swatchDiff
                        * ((screenPoint.z - zMax) * zDenom)

                    drawCirc(
                        imgPixels, width,
                        floor(0.5 + screenPoint.x),
                        floor(0.5 + screenPoint.y),
                        floor(0.5 + scl),
                        packet.r, packet.g, packet.b, packet.a)
                end

                local img <const> = Image(width, height)
                setPixels(img, imgPixels)
                coverSprite:newCel(layer, frame, img)
            end
        end)

        app.sprite = coverSprite
        app.frame = coverSprite.frames[1]

        -- Create and set the coverage palette.
        -- Wait to do this until the end, so we have greater
        -- assurance that the coverSprite is active.
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

dlg:show {
    autoscrollbars = true,
    wait = false
}