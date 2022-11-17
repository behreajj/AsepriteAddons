dofile("../../support/aseutilities.lua")

local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }

local defaults = {
    size = 512,
    sectors = 0,
    rings = 0,
    xFlip = false,
    yFlip = false,
    zFlip = false,
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    correctPalette = true,
    strokeSize = 6,
    fillSize = 5,
    minSize = 64,
    maxSize = 2048,
    maxSectors = 32,
    maxRings = 16
}

local normalsPal = {
    0x00000000, 0xffff8080,
    0xff8080ff, 0xff80dada, 0xff80ff80, 0xff80da25,
    0xff808000, 0xff802525, 0xff800080, 0xff8025da,
    0xffb080f5, 0xffb0d3d3, 0xffb0f580, 0xffb0d32c,
    0xffb0800a, 0xffb02c2c, 0xffb00a80, 0xffb02cd3,
    0xffda80da, 0xffdabfbf, 0xffdada80, 0xffdabf40,
    0xffda8025, 0xffda4040, 0xffda2580, 0xffda40bf,
    0xfff580b0, 0xfff5a2a2, 0xfff5b080, 0xfff5a25d,
    0xfff5804f, 0xfff55d5d, 0xfff54f80, 0xfff55da2
}

local dlg = Dialog { title = "Normal Wheel" }

dlg:slider {
    id = "size",
    label = "Size:",
    min = defaults.minSize,
    max = defaults.maxSize,
    value = defaults.size,
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 0,
    max = defaults.maxSectors,
    value = defaults.sectors
}

dlg:newrow { always = false }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 0,
    max = defaults.maxRings,
    value = defaults.rings
}

dlg:newrow { always = false }

dlg:check {
    id = "xFlip",
    label = "Flip:",
    text = "X",
    selected = defaults.xFlip
}

dlg:check {
    id = "yFlip",
    text = "Y",
    selected = defaults.yFlip
}

dlg:check {
    id = "zFlip",
    text = "Z",
    selected = defaults.zFlip
}

dlg:newrow { always = false }

dlg:check {
    id = "plotPalette",
    label = "Plot:",
    text = "Palette",
    selected = defaults.plotPalette,
    onclick = function()
        local args = dlg.data
        local usePlot = args.plotPalette
        local palType = args.palType

        dlg:modify { id = "correctPalette", visible = usePlot and palType ~= "DEFAULT" }
        dlg:modify { id = "palType", visible = usePlot }
        dlg:modify { id = "palFile", visible = usePlot and palType == "FILE" }
        dlg:modify { id = "palPreset", visible = usePlot and palType == "PRESET" }
        -- dlg:modify { id = "palStart", visible = usePlot }
        -- dlg:modify { id = "palCount", visible = usePlot }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "correctPalette",
    label = "Normalize:",
    selected = defaults.correctPalette,
    visible = defaults.plotPalette,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = paletteTypes,
    visible = defaults.plotPalette,
    onchange = function()
        local state = dlg.data.palType
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "palPreset", visible = state == "PRESET" }
        dlg:modify { id = "correctPalette", visible = state ~= "DEFAULT" }

    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = defaults.plotPalette
        and defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = defaults.plotPalette
        and defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:slider {
    id = "palStart",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.palStart,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "palCount",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.palCount,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Cache methods.
        local cos = math.cos
        local sin = math.sin
        local sqrt = math.sqrt
        local atan2 = math.atan
        local acos = math.acos
        local floor = math.floor

        -- Cache math constants.
        local pi = math.pi
        local tau = pi + pi
        local halfPi = pi * 0.5

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size
        local sectors = args.sectors or defaults.sectors
        local rings = args.rings or defaults.rings
        local plotPalette = args.plotPalette
        local correctPalette = args.correctPalette
        local xFlip = args.xFlip
        local yFlip = args.yFlip
        local zFlip = args.zFlip

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        if plotPalette then
            local palType = args.palType or defaults.palType
            if palType ~= "DEFAULT" then
                local palFile = args.palFile
                local palPreset = args.palPreset
                local palStart = args.palStart or defaults.palStart
                local palCount = args.palCount or defaults.palCount

                hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                    palType, palFile, palPreset, palStart, palCount, true)
            else
                -- Different from other color wheels.
                hexesProfile = normalsPal
                hexesSrgb = hexesProfile
                correctPalette = false
            end
        end

        -- Create sprite.
        local sprite = Sprite(size, size)
        sprite.filename = "Normal Map Color Wheel"
        sprite:assignColorSpace(ColorSpace())
        local wheelCel = sprite.cels[1]

        -- For flipping the wheel orientation.
        local hexDefault = 0xffff8080
        local zFlipNum = 1
        local yFlipNum = 1
        local xFlipNum = 1

        if zFlip then
            zFlipNum = -1
            hexDefault = 0xff008080
        end
        if yFlip then yFlipNum = -1 end
        if xFlip then xFlipNum = -1 end

        -- Discrete sectors (azimuths).
        -- To quantize, values need to be in [0.0, 1.0].
        -- That's why alpha divides by tau and beta
        -- multiplies by tau after the floor.
        local azimAlpha = sectors / tau
        local azimBeta = 0.0
        local quantAzims = sectors > 0
        if quantAzims then
            azimBeta = tau / sectors
        end

        -- Discrete rings (inclinations).
        local inclAlpha = rings / halfPi
        local inclBeta = 0.0
        local quantIncls = rings > 0
        if quantIncls then
            inclBeta = halfPi / rings
        end

        -- Create image, prepare for loop.
        local quantUse = quantAzims or quantIncls
        local szInv = 1.0 / (size - 1.0)

        local imgSpec = ImageSpec { width = size, height = size }
        imgSpec.colorSpace = ColorSpace()
        local wheelImg = Image(imgSpec)

        local pxItr = wheelImg:pixels()
        for elm in pxItr do

            -- Find rise and run.
            local yNrm = elm.y * szInv
            local ySgn = yFlipNum * (1.0 - (yNrm + yNrm))
            local xNrm = elm.x * szInv
            local xSgn = xFlipNum * (xNrm + xNrm - 1.0)

            -- Find square magnitude.
            -- Magnitude is correlated with inclination.
            -- Epsilon = 2 * ((1 / 255) ^ 2) = 0.000031
            local magSq = xSgn * xSgn + ySgn * ySgn
            if magSq > 0.000031 and magSq <= 1.0 then
                local zSgn = zFlipNum * sqrt(1.0 - magSq)

                local xn = xSgn
                local yn = ySgn
                local zn = zSgn

                -- Discrete swatches are more expensive because
                -- atan2, acos, cos and sin are used.
                if quantUse then
                    local azim = atan2(ySgn, xSgn)
                    local incl = halfPi - acos(zSgn)

                    if quantAzims then
                        azim = floor(0.5 + azim * azimAlpha) * azimBeta
                    end

                    if quantIncls then
                        incl = floor(0.5 + incl * inclAlpha) * inclBeta
                    end

                    local cosIncl = cos(incl)
                    xn = cosIncl * cos(azim)
                    yn = cosIncl * sin(azim)
                    zn = sin(incl)
                end

                elm(0xff000000
                    | (floor(zn * 127.5 + 128.0) << 0x10)
                    | (floor(yn * 127.5 + 128.0) << 0x08)
                    | floor(xn * 127.5 + 128.0))
            else
                elm(hexDefault)
            end
        end

        wheelCel.image = wheelImg
        sprite.layers[1].name = "Wheel"

        if plotPalette then
            -- Unpack arguments.
            local strokeSize = args.strokeSize or defaults.strokeSize
            local fillSize = args.fillSize or defaults.fillSize

            local hexesPlot = hexesSrgb
            if correctPalette then
                hexesPlot = {}
                local lenHexesSrgb = #hexesSrgb
                local h = 0
                local k = 0
                while h < lenHexesSrgb do h = h + 1
                    local hexSrgb = hexesSrgb[h]
                    if (hexSrgb & 0xff000000) ~= 0 then
                        local b = (hexSrgb >> 0x10) & 0xff
                        local g = (hexSrgb >> 0x08) & 0xff
                        local r = hexSrgb & 0xff

                        local x = (r + r - 255) * 0.003921568627451
                        local y = (g + g - 255) * 0.003921568627451
                        local z = (b + b - 255) * 0.003921568627451

                        local hexPlot = 0xff808080
                        local sqMag = x * x + y * y + z * z
                        if sqMag > 0.000047 then
                            local invMag = 127.5 / sqrt(sqMag)
                            hexPlot = 0xff000000
                                | (floor(z * invMag + 128.0) << 0x10)
                                | (floor(y * invMag + 128.0) << 0x08)
                                | floor(x * invMag + 128.0)
                        end

                        k = k + 1
                        hexesPlot[k] = hexPlot
                    end
                end
            end

            -- Find min and max.
            local xs = {}
            local ys = {}
            local lenHexesPlot = #hexesPlot

            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            local center = size // 2
            local xFlipScale = xFlipNum * 0.003921568627451
            local yFlipScale = yFlipNum * 0.003921568627451
            local zFlipScale = zFlipNum * 0.003921568627451

            local i = 0
            while i < lenHexesPlot do i = i + 1
                local hexPlot = hexesPlot[i]
                local xi = center
                local yi = center

                local r255 = hexPlot & 0xff
                local g255 = (hexPlot >> 0x08) & 0xff

                local x = (r255 + r255 - 255) * xFlipScale
                local y = (255 - (g255 + g255)) * yFlipScale

                local sqMag2d = x * x + y * y
                if sqMag2d > 0.000031 then
                    local invMag2d = 1.0 / sqrt(sqMag2d)
                    local xn2d = x * invMag2d
                    local yn2d = y * invMag2d
                    local xu = 0.5
                    local yu = 0.5
                    if sqMag2d > 1.0 then
                        -- Would it be more accurate to normalize
                        -- the color again by 3d mag? This approach
                        -- is better suited to a color picker.
                        xu = xn2d * 0.5 + 0.5
                        yu = yn2d * 0.5 + 0.5
                    elseif sqMag2d == 1.0 then
                        xu = xn2d * 0.5 + 0.5
                        yu = yn2d * 0.5 + 0.5
                    else
                        local b255 = (hexPlot >> 0x10) & 0xff
                        local z = (b255 + b255 - 255) * zFlipScale
                        local zn3d = z / sqrt(sqMag2d + z * z)

                        -- cos(asin(z)) == sqrt(1 - z * z)
                        local dist = sqrt(1.0 - zn3d * zn3d)
                        local xn3d = xn2d * dist
                        local yn3d = yn2d * dist

                        xu = xn3d * 0.5 + 0.5
                        yu = yn3d * 0.5 + 0.5
                    end

                    xi = floor(0.5 + xu * size)
                    yi = floor(0.5 + yu * size)
                end

                if xi < xMin then xMin = xi end
                if xi > xMax then xMax = xi end
                if yi < yMin then yMin = yi end
                if yi > yMax then yMax = yi end

                xs[i] = xi
                ys[i] = yi
            end

            if xMax > xMin and yMax > yMin then
                local drawCircleFill = AseUtilities.drawCircleFill
                local stroke2 = strokeSize + strokeSize
                local xOff = 1 + xMin - strokeSize
                local yOff = 1 + yMin - strokeSize

                local plotSpec = ImageSpec {
                    width = (xMax - xMin) + stroke2 - 1,
                    height = (yMax - yMin) + stroke2 - 1,
                }
                local plotImage = Image(plotSpec)
                local plotPos = Point(xOff, yOff)

                local j = 0
                while j < lenHexesPlot do j = j + 1
                    local hexPlot = hexesPlot[j]
                    if (hexPlot & 0xff000000) ~= 0 then
                        local xi = xs[j] - xOff
                        local yi = ys[j] - yOff
                        drawCircleFill(plotImage, xi, yi, strokeSize,
                            0xffffffff)
                        drawCircleFill(plotImage, xi, yi, fillSize,
                            0xff000000 | hexPlot)
                    end
                end

                local plotPalLayer = sprite:newLayer()
                plotPalLayer.name = "Palette"
                sprite:newCel(
                    plotPalLayer, sprite.frames[1],
                    plotImage, plotPos)

                -- This needs to be done at the very end because
                -- prependMask modifies hexesProfile.
                Utilities.prependMask(hexesPlot)
                AseUtilities.setPalette(hexesPlot, sprite, 1)
            end
        else
            AseUtilities.setPalette(normalsPal, sprite, 1)
        end

        app.activeLayer = sprite.layers[1]
        app.command.FitScreen()
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