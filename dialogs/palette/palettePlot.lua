dofile("../../support/mat4.lua")
dofile("../../support/aseutilities.lua")
dofile("../../support/curve3.lua")

local projections = {
    "ORTHO",
    "PERSPECTIVE"
}

local defaults = {
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    palSkip = 0,
    closeLoop = false,
    tension = 0,
    resolution = 48,
    projection = "ORTHO",
    axx = 0.0,
    axy = 0.0,
    axz = 1.0,
    minSwatchSize = 2,
    maxSwatchSize = 8,
    bkgColor = Color(0xff202020),
    frames = 16,
    -- duration = 100.0,
    pullFocus = false
}

local dlg = Dialog { title = "Plot Palette" }

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
    id = "palSkip",
    label = "Skip:",
    min = 0,
    max = 16,
    value = defaults.palSkip
}

dlg:newrow { always = false }

dlg:check {
    id = "closedLoop",
    label = "Closed Loop:",
    selected = defaults.closedLoop
}

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "tension",
--     label = "Tension:",
--     min = -30,
--     max = 30,
--     value = defaults.tension
-- }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 0,
    max = 128,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:combobox {
    id = "projection",
    label = "Projection:",
    option = defaults.projection,
    options = projections
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

-- dlg:number {
--     id = "duration",
--     label = "Duration:",
--     text = string.format("%.0f", defaults.duration),
--     decimals = 0
-- }

-- dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- TODO: Make palette analysis tools create a new sprite instead,
        -- so that sprite width and height are more reliable.
        local sprite = app.activeSprite
        if sprite then

            local oldMode = sprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

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
                srcPal = sprite.palettes[1]
            end

            if srcPal then
                -- Validate range of palette to sample.
                local palStart = args.palStart or defaults.palStart
                local palCount = args.palCount or defaults.palCount
                local palSkip = args.palSkip or defaults.palSkip

                palSkip = 1 + palSkip
                palStart = math.min(#srcPal - 1, palStart)
                palCount = math.min(palCount, #srcPal - palStart, 256)

                -- Create points.
                local srcPts = {}
                for i = 0, palCount - 1, palSkip do
                    local ase = srcPal:getColor(palStart + i)
                    local clr = AseUtilities.aseColorToClr(ase)
                    local lab = Clr.rgbaToLab(clr)
                    local srcPt = Vec3.new(lab.a, lab.b, lab.l)
                    table.insert(srcPts, srcPt)
                end

                local closedLoop = args.closedLoop or defaults.closeLoop
                local resolution = args.resolution or defaults.resolution
                local tension = args.tension or defaults.tension
                tension = tension * 0.1

                -- local curve = Curve3.fromCatmull(closedLoop, srcPts, tension)
                local curve = Curve3.fromPoints(closedLoop, srcPts)

                local ptsSampled = {}
                local clrsSampled = {}

                local iToStep = 1.0
                if closedLoop then
                    iToStep = 1.0 / resolution
                else
                    iToStep = 1.0 / (resolution - 1)
                end

                local swatchAlpha = 1.0
                for i = 0, resolution, 1 do
                    local step = i * iToStep
                    local point = Curve3.eval(curve, step)

                    local j = i + 1
                    ptsSampled[j] = point

                    local clr = Clr.labToRgba(
                        point.z, point.x, point.y, swatchAlpha)

                    local hex = Clr.toHex(clr)
                    clrsSampled[j] = hex
                end

                local width = sprite.width
                local height = sprite.height
                local halfWidth = width * 0.5
                local halfHeight = height * 0.5

                local projection = nil
                local projPreset = args.projection or defaults.projection
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
                local uniformScale = 1.25 * math.min(width, height)
                local model = Mat4.fromScale(uniformScale)
                local camera = Mat4.cameraIsometric(
                    1.0, -1.0, 1.25, "RIGHT")
                local modelview = model * camera

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
                local oldFrameLen = #sprite.frames
                local reqFrames = args.frames
                local needed = math.max(0, reqFrames - oldFrameLen)
                for h = 1, needed, 1 do
                    sprite:newEmptyFrame()
                end

                local hToTheta = 6.283185307179586 / reqFrames
                local minSwatchSize = args.minSwatchSize
                local maxSwatchSize = args.maxSwatchSize
                local swatchDiff = maxSwatchSize - minSwatchSize

                local pts2d = {}
                local zMin = 999999.0
                local zMax = -999999.0

                local aMin = -110.0
                local aMax = 110.0
                local bMin = -110.0
                local bMax = 110.0
                local lMin = 0.0
                local lMax = 100.0

                -- Find original scale.
                local lDiff = lMax - lMin
                local aDiff = aMax - aMin
                local bDiff = bMax - bMin

                local pivot = Vec3.new(
                    0.5 * (aMin + aMax),
                    0.5 * (bMin + bMax), 0.0)
                local inv = 1.0 / math.max(aDiff, bDiff, lDiff)
                for h = 1, reqFrames, 1 do
                    local frame2d = {}
                    local theta = (h - 1) * hToTheta
                    local cosa = math.cos(theta)
                    local sina = math.sin(theta)
                    for i = 1, resolution, 1 do
                        local vec = ptsSampled[i]

                        vec = Vec3.sub(vec, pivot)
                        vec = Vec3.scale(vec, inv)

                        local vr = Vec3.rotateInternal(
                            vec, cosa, sina, axis)
                        local scrpt = Utilities.toScreen(
                            modelview, projection, vr,
                            width, height)

                        if scrpt.z < zMin then zMin = scrpt.z end
                        if scrpt.z > zMax then zMax = scrpt.z end

                        frame2d[i] = {
                            point = scrpt,
                            color = clrsSampled[i] }
                    end

                    -- Depth sorting.
                    table.sort(frame2d,
                        function(a, b)
                            return b.point.z < a.point.z
                        end)
                    pts2d[h] = frame2d
                end

                -- Create layer.
                local layer = sprite:newLayer()
                layer.name = "Palette.Plot"

                local zDiff = zMin - zMax
                local zDenom = 1.0
                if zDiff ~= 0.0 then zDenom = 1.0 / zDiff end

                local trunc = math.tointeger
                local drawCirc = AseUtilities.drawCircleFill

                -- Create background image once, then clone.
                local bkgImg = Image(width, height)
                local bkgHex = args.bkgColor.rgbaPixel
                for elm in bkgImg:pixels() do
                    elm(bkgHex)
                end

                -- local duration = args.duration or defaults.duration
                -- duration = trunc(0.5 + duration * 0.001)
                for h = 1, reqFrames, 1 do
                    local frame = sprite.frames[h]
                    -- frame.duration = duration

                    local cel = sprite:newCel(layer, frame)
                    local img = bkgImg:clone()
                    local frame2d = pts2d[h]

                    for i = 1, resolution, 1 do

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

            else
                app.alert("The source palette could not be found.")
            end

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()

        else
            app.alert("There is no active sprite.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }