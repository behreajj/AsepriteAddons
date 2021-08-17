dofile("../../support/mat4.lua")
dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local defaults = {
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    queryRad = 22,
    octCapacity = 16,
    projection = "ORTHO",
    axx = 0.0,
    axy = 0.0,
    axz = 1.0,
    minSwatchSize = 3,
    maxSwatchSize = 10,
    swatchAlpha = 85,
    bkgColor = Color(0xff202020),
    frames = 16,
    duration = 100.0,
    pullFocus = false
}

local dlg = Dialog { title = "Palette Nearest" }

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
    id = "palStart",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.palStart
}

dlg:newrow { always = false }

dlg:slider {
    id = "palCount",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.palCount
}

dlg:newrow { always = false }

dlg:slider {
    id = "queryRad",
    label = "Query Radius:",
    min = 10,
    max = 100,
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
        else
            if app.activeSprite then
                srcPal = app.activeSprite.palettes[1]
            end
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

            local sprite = Sprite(512, 512)
            sprite:setPalette(srcPal)
            sprite:convertColorSpace(ColorSpace { sRGB = true })

            -- Unpack args.
            local palStart = args.palStart or defaults.palStart
            local palCount = args.palCount or defaults.palCount
            local queryRad = args.queryRad or defaults.queryRad
            local bkgColor = args.bkgClr or defaults.bkgColor
            local duration = args.duration or defaults.duration
            local axx = args.axx or defaults.axx
            local axy = args.axy or defaults.axy
            local axz = args.axz or defaults.axz

            -- Cache global functions used in for loops.
            local cos = math.cos
            local sin = math.sin
            local trunc = math.tointeger
            local strfmt = string.format
            local rgbToLab = Clr.sRgbaToLab
            local screen = Utilities.toScreen
            local drawCirc = AseUtilities.drawCircleFill
            local aseToClr = AseUtilities.aseColorToClr
            local rotax = Vec3.rotateInternal
            local v3scl = Vec3.scale
            local v3sub = Vec3.sub
            local v3hsh = Vec3.hashCode
            local search = Octree.querySphericalInternal

            -- Create background image once, then clone.
            local width = sprite.width
            local height = sprite.height
            local bkgImg = Image(width, height)
            local bkgHex = bkgColor.rgbaPixel
            for elm in bkgImg:pixels() do
                elm(bkgHex)
            end

            -- Add requested number of frames.
            local oldFrameLen = #sprite.frames
            local reqFrames = args.frames
            local needed = math.max(0, reqFrames - oldFrameLen)
            duration = duration * 0.001

            app.transaction(function()
                for _ = 1, needed, 1 do
                    local frame = sprite:newEmptyFrame()
                    frame.duration = duration
                end
            end)

            -- Create background layer across frames.
            local bkgLayer = sprite.layers[#sprite.layers]
            bkgLayer.name = "Bkg"
            app.transaction(function()
                for j = 1, reqFrames, 1 do
                    sprite:newCel(bkgLayer, sprite.frames[j], bkgImg)
                end
            end)

            -- Validate range of palette to sample.
            palStart = math.min(#srcPal - 1, palStart)
            palCount = math.min(palCount, #srcPal - palStart, 256)

            -- Find lab minimums and maximums.
            local lMin = 999999
            local aMin = 999999
            local bMin = 999999

            local lMax = -999999
            local aMax = -999999
            local bMax = -999999

            -- Create points.
            local srcPts = {}
            local hexes = {}
            local ptHexDict = {}
            local layers = {}
            app.transaction(function()

                -- Create layers in reverse order.
                for i = 0, palCount - 1, 1 do
                    layers[palCount - i] = sprite:newLayer()
                end

                for i = 0, palCount - 1, 1 do
                    local ase = srcPal:getColor(palStart + i)
                    local hex = ase.rgbaPixel
                    local clr = aseToClr(ase)
                    local lab = rgbToLab(clr)
                    local srcPt = Vec3.new(lab.a, lab.b, lab.l)
                    srcPts[1 + i] = srcPt
                    hexes[1 + i] = hex
                    ptHexDict[v3hsh(srcPt)] = hex

                    local b255 = hex >> 0x10 & 0xff
                    local g255 = hex >> 0x08 & 0xff
                    local r255 = hex & 0xff

                    layers[1 + i].name = strfmt("%03d.%06X", i,
                        r255 << 0x10 | g255 << 0x08 | b255)

                    if lab.l < lMin then lMin = lab.l end
                    if lab.a < aMin then aMin = lab.a end
                    if lab.b < bMin then bMin = lab.b end

                    if lab.l > lMax then lMax = lab.l end
                    if lab.a > aMax then aMax = lab.a end
                    if lab.b > bMax then bMax = lab.b end
                end
            end)

            -- Find original scale.
            local lDiff = lMax - lMin
            local aDiff = aMax - aMin
            local bDiff = bMax - bMin

            -- Normalize source point.
            local pivot = Vec3.new(
                0.5 * (aMin + aMax),
                0.5 * (bMin + bMax),
                0.5 * (lMin + lMax))
            local inv = 1.0 / math.max(aDiff, bDiff, lDiff)

            -- Create Octree.
            local octCapacity = args.octCapacity
            local bounds = Bounds3.cieLab()
            local octree = Octree.new(bounds, octCapacity, 0)
            Octree.insertAll(octree, srcPts)
            -- print(octree)

            local results = {}
            local resultLimit = 256
            for i = 1, palCount, 1 do
                local srcPt = srcPts[i]
                local found = {}
                search(octree, srcPt, queryRad, found, resultLimit)

                local nearHexes = {}
                local nearPts = {}
                for m = 1, #found, 1 do
                    local nearPt = found[m].point
                    nearHexes[m] = ptHexDict[v3hsh(nearPt)]
                    nearPts[m] = v3scl(v3sub(nearPt, pivot), inv)
                end

                results[i] = {
                    layer = layers[i],
                    hex = hexes[i],
                    nearHexes = nearHexes,
                    source = v3scl(v3sub(srcPt, pivot), inv),
                    nearPts = nearPts
                }
            end

            -- Create geometry rotation axis.
            local axis = Vec3.new(axx, axy, axz)
            if Vec3.any(axis) then
                axis = Vec3.normalize(axis)
            else
                axis = Vec3.forward()
            end

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
            local uniformScale = 0.825 * math.min(width, height)
            local model = Mat4.fromScale(uniformScale)
            local camera = Mat4.cameraIsometric(
                1.0, -1.0, 1.0, "RIGHT")
            local modelview = model * camera

            local toTheta = 6.283185307179586 / reqFrames
            local minSwatchSize = args.minSwatchSize
            local maxSwatchSize = args.maxSwatchSize
            local swatchDiff = maxSwatchSize - minSwatchSize

            local pts2d = {}
            local zMin = 999999
            local zMax = -999999

            local len2 = reqFrames * palCount - 1
            for k = 0, len2, 1 do
                local i = k // reqFrames -- layer
                local j = k % reqFrames -- frame

                local theta = j * toTheta
                local cosa = cos(theta)
                local sina = sin(theta)

                local result = results[1 + i]
                local source = result.source
                local nearPts = result.nearPts

                local rotated = rotax(source, cosa, sina, axis)
                local pt2d = screen(
                    modelview, projection, rotated,
                    width, height)

                if pt2d.z < zMin then zMin = pt2d.z end
                if pt2d.z > zMax then zMax = pt2d.z end

                local near2ds = {}
                for m = 1, #nearPts, 1 do
                    local nearPt = nearPts[m]
                    local rotNear = rotax(nearPt, cosa, sina, axis)
                    local near2d = screen(
                        modelview, projection, rotNear,
                        width, height)
                    near2ds[m] = near2d
                end

                pts2d[1 + k] = {
                    layer = result.layer,
                    frame = sprite.frames[1 + j],
                    hex = result.hex,
                    nearHexes = result.nearHexes,
                    source = pt2d,
                    near = near2ds
                }
            end

            local zDiff = zMin - zMax
            local zDenom = 1.0
            if zDiff ~= 0.0 then zDenom = 1.0 / zDiff end

            app.transaction(function()
                for k = 0, len2, 1 do
                    local packet = pts2d[1 + k]

                    local layer = packet.layer
                    local frame = packet.frame
                    local pt2d = packet.source
                    local hex = packet.hex
                    local near2ds = packet.near
                    local nearHexes = packet.nearHexes

                    local scl = minSwatchSize + swatchDiff
                        * ((pt2d.z - zMax) * zDenom)

                    local cel = sprite:newCel(layer, frame)
                    local img = Image(width, height)

                    for m = 1, #near2ds, 1 do
                        local near2d = near2ds[m]
                        local nearHex = nearHexes[m]
                        local nearScl = minSwatchSize + swatchDiff
                            * ((near2d.z - zMax) * zDenom)
                        drawCirc(
                            img,
                            trunc(0.5 + near2d.x),
                            trunc(0.5 + near2d.y),
                            trunc(0.5 + nearScl),
                            nearHex)
                    end

                    drawCirc(
                        img,
                        trunc(0.5 + pt2d.x),
                        trunc(0.5 + pt2d.y),
                        trunc(0.5 + scl),
                        hex)

                    cel.image = img
                end
            end)

            sprite:assignColorSpace(sourceColorSpace)
            app.activeSprite = sprite
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