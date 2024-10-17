dofile("../../support/aseutilities.lua")

local palTypes <const> = { "ACTIVE", "DEFAULT", "FILE" }

local defaults <const> = {
    size = 512,
    sectors = 0,
    rings = 0,
    uniformRings = false,
    xFlip = false,
    yFlip = false,
    zFlip = false,
    plotPalette = false,
    palType = "DEFAULT",
    correctPalette = true,
    strokeSize = 6,
    fillSize = 5,
    minSize = 64,
    maxSize = 2048,
    maxSectors = 32,
    maxRings = 16,
    pullFocus = true
}

local normalsPal <const> = {
    0x00000000, 0xffff8080,
    0xff8080ff, 0xff80dada, 0xff80ff80, 0xff80da25, -- 1
    0xff808000, 0xff802525, 0xff800080, 0xff8025da, -- 2
    0xffb080f5, 0xffb0d3d3, 0xffb0f580, 0xffb0d32c, -- 3
    0xffb0800a, 0xffb02c2c, 0xffb00a80, 0xffb02cd3, -- 4
    0xffda80da, 0xffdabfbf, 0xffdada80, 0xffdabf40, -- 5
    0xffda8025, 0xffda4040, 0xffda2580, 0xffda40bf, -- 6
    0xfff680af, 0xfff6a1a1, 0xfff6af80, 0xfff6a15e, -- 7
    0xfff68050, 0xfff65e5e, 0xfff65080, 0xfff65ea1  -- 8
}

local dlg <const> = Dialog { title = "Normal Wheel" }

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
    value = defaults.rings,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.rings > 0
        dlg:modify { id = "uniformRings", visible = state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "uniformRings",
    label = "Swatches:",
    text = "&Uniform",
    selected = defaults.uniformRings,
    visible = defaults.rings > 0
}

dlg:newrow { always = false }

dlg:check {
    id = "xFlip",
    label = "Flip:",
    text = "&X",
    selected = defaults.xFlip
}

dlg:check {
    id = "yFlip",
    text = "&Y",
    selected = defaults.yFlip
}

dlg:check {
    id = "zFlip",
    text = "&Z",
    selected = defaults.zFlip
}

dlg:newrow { always = false }

dlg:check {
    id = "plotPalette",
    label = "Plot:",
    text = "&Palette",
    selected = defaults.plotPalette,
    onclick = function()
        local args <const> = dlg.data
        local usePlot <const> = args.plotPalette --[[@as boolean]]
        local palType <const> = args.palType --[[@as string]]

        dlg:modify { id = "correctPalette", visible = usePlot
            and palType ~= "DEFAULT" }
        dlg:modify { id = "palType", visible = usePlot }
        dlg:modify { id = "palFile", visible = usePlot
            and palType == "FILE" }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "correctPalette",
    label = "Normalize:",
    selected = defaults.correctPalette,
    visible = defaults.plotPalette
        and defaults.palType ~= "DEFAULT",
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = defaults.palType,
    options = palTypes,
    visible = defaults.plotPalette,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "correctPalette", visible = state ~= "DEFAULT" }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    open = true,
    visible = defaults.plotPalette
        and defaults.palType == "FILE"
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Cache methods.
        local abs <const> = math.abs
        local atan2 <const> = math.atan
        local acos <const> = math.acos
        local ceil <const> = math.ceil
        local cos <const> = math.cos
        local floor <const> = math.floor
        local max <const> = math.max
        local sin <const> = math.sin
        local sqrt <const> = math.sqrt
        local strchar <const> = string.char

        -- Cache math constants.
        local pi <const> = math.pi
        local tau <const> = pi + pi
        local halfPi <const> = pi * 0.5

        -- Unpack arguments.
        local args <const> = dlg.data
        local size <const> = args.size or defaults.size --[[@as integer]]
        local sectors <const> = args.sectors or defaults.sectors --[[@as integer]]
        local rings <const> = args.rings or defaults.rings --[[@as integer]]
        local plotPalette <const> = args.plotPalette --[[@as boolean]]
        local correctPalette = args.correctPalette --[[@as boolean]]
        local uniformRings <const> = args.uniformRings --[[@as boolean]]
        local xFlip <const> = args.xFlip --[[@as boolean]]
        local yFlip <const> = args.yFlip --[[@as boolean]]
        local zFlip <const> = args.zFlip --[[@as boolean]]

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        if plotPalette then
            local palType <const> = args.palType or defaults.palType --[[@as string]]
            if palType ~= "DEFAULT" then
                local palFile <const> = args.palFile --[[@as string]]
                hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                    palType, palFile, 0, 512, true)
            else
                -- Different from other color wheels.
                hexesProfile = normalsPal
                hexesSrgb = hexesProfile
                correctPalette = false
            end
        end

        -- Create sprite.
        local spec = AseUtilities.createSpec(
            size, size, ColorMode.RGB, ColorSpace(), 0)
        local sprite = AseUtilities.createSprite(spec, "Normal Map Wheel")
        local wheelCel <const> = sprite.cels[1]

        -- For flipping the wheel orientation.
        local r8Default <const> = 0x80
        local g8Default <const> = 0x80
        local b8Default <const> = zFlip and 0x00 or 0xff
        local a8Default <const> = 0xff

        local xFlipNum <const> = xFlip and -1 or 1
        local yFlipNum <const> = yFlip and -1 or 1
        local zFlipNum <const> = zFlip and -1 or 1

        -- Discrete sectors (azimuths).
        -- To quantize, values need to be in [0.0, 1.0].
        -- That's why alpha divides by tau and beta
        -- multiplies by tau after the floor.
        local sectorsDivTau <const> = sectors / tau
        local tauDivSectors = 0.0
        local quantAzims <const> = sectors > 0
        if quantAzims then
            tauDivSectors = tau / sectors
        end

        -- Discrete rings (inclinations).
        local rings2DivPi <const> = rings / halfPi
        local piDivRings2 = 0.0
        local quantIncls <const> = rings > 0
        if quantIncls then
            piDivRings2 = halfPi / rings
        end

        -- Discrete rings (distance).
        local ringsp1 <const> = rings + 1.0
        local oneDivRings = 0.0
        if quantIncls then
            oneDivRings = 1.0 / rings
        end

        local quantUse <const> = quantAzims or quantIncls
        local szInv <const> = 1.0 / (size - 1.0)
        local szSq <const> = size * size
        ---@type string[]
        local byteStrArr <const> = {}

        local n = 0
        while n < szSq do
            -- Find rise and run as [0.0, 1.0], convert to
            -- [-1.0, 1.0] and flip as requested.
            local x <const> = n % size
            local x01 <const> = x * szInv
            local xSgn <const> = xFlipNum * (x01 + x01 - 1.0)

            local y <const> = n // size
            local y01 <const> = y * szInv
            local ySgn <const> = yFlipNum * (1.0 - (y01 + y01))

            -- Find square magnitude.
            -- Magnitude is correlated with inclination.
            -- Epsilon = 2 * ((1 / 255) ^ 2) = 0.000031
            local r8, g8, b8, a8 = r8Default, g8Default, b8Default, a8Default
            local sqMag2d <const> = xSgn * xSgn + ySgn * ySgn
            if sqMag2d > 0.000031 and sqMag2d <= 1.0 then
                local zSgn <const> = zFlipNum * sqrt(1.0 - sqMag2d)

                local xn = xSgn
                local yn = ySgn
                local zn = zSgn

                -- Discrete swatches are more expensive because
                -- atan2, acos, cos and sin are used.
                if quantUse then
                    local azimSmooth <const> = atan2(ySgn, xSgn)
                    local azim = azimSmooth
                    if quantAzims then
                        azim = floor(0.5 + azimSmooth * sectorsDivTau)
                            * tauDivSectors
                    end

                    local incl = halfPi
                    if quantIncls then
                        if uniformRings then
                            -- To make a polygon rather than a circle,
                            -- multiply by the difference between the
                            -- discrete and smooth angle supplied to cos.
                            local geom <const> = sqrt(sqMag2d)
                            -- geom = geom * cos(azim - azimSmooth)
                            local fac <const> = max(0.0, (ceil(geom * ringsp1) - 1.0)
                                * oneDivRings)
                            incl = zFlipNum * (halfPi - fac * halfPi)
                        else
                            incl = floor(0.5 + (halfPi - acos(zSgn))
                                * rings2DivPi) * piDivRings2
                        end
                    else
                        incl = halfPi - acos(zSgn);
                    end

                    -- Convert spherical to Cartesian coordinates.
                    local cosIncl <const> = cos(incl)
                    xn = cosIncl * cos(azim)
                    yn = cosIncl * sin(azim)
                    zn = sin(incl)

                    -- Discontinuity in the return from atan2 can
                    -- lead to x, y being slightly off from pi, and
                    -- so 0x7f and 0x80 variants appear.
                    if abs(xn) < 0.0039216 then xn = 0.0 end
                    if abs(yn) < 0.0039216 then yn = 0.0 end
                    if abs(zn) < 0.0039216 then zn = 0.0 end
                end

                r8 = floor(xn * 127.5 + 128.0)
                g8 = floor(yn * 127.5 + 128.0)
                b8 = floor(zn * 127.5 + 128.0)
            end

            local n4 <const> = n * 4
            byteStrArr[1 + n4] = strchar(r8)
            byteStrArr[2 + n4] = strchar(g8)
            byteStrArr[3 + n4] = strchar(b8)
            byteStrArr[4 + n4] = strchar(a8)

            n = n + 1
        end

        local wheelImg <const> = Image(spec)
        wheelImg.bytes = table.concat(byteStrArr)

        wheelCel.image = wheelImg
        sprite.layers[1].name = "Wheel"

        if plotPalette then
            -- Unpack arguments.
            local strokeSize <const> = args.strokeSize
                or defaults.strokeSize --[[@as integer]]
            local fillSize <const> = args.fillSize
                or defaults.fillSize --[[@as integer]]

            local hexesPlot = hexesSrgb
            if correctPalette then
                ---@type integer[]
                hexesPlot = {}
                local lenHexesSrgb <const> = #hexesSrgb
                local h = 0
                local k = 0
                while h < lenHexesSrgb do
                    h = h + 1
                    local hexSrgb <const> = hexesSrgb[h]
                    if (hexSrgb & 0xff000000) ~= 0 then
                        local b <const> = (hexSrgb >> 0x10) & 0xff
                        local g <const> = (hexSrgb >> 0x08) & 0xff
                        local r <const> = hexSrgb & 0xff

                        local x <const> = (r + r - 255) * 0.003921568627451
                        local y <const> = (g + g - 255) * 0.003921568627451
                        local z <const> = (b + b - 255) * 0.003921568627451

                        local hexPlot = 0xff808080
                        local sqMag3d <const> = x * x + y * y + z * z
                        if sqMag3d > 0.000047 then
                            local invMag3d <const> = 127.5 / sqrt(sqMag3d)
                            hexPlot = 0xff000000
                                | (floor(z * invMag3d + 128.0) << 0x10)
                                | (floor(y * invMag3d + 128.0) << 0x08)
                                | floor(x * invMag3d + 128.0)
                        end

                        k = k + 1
                        hexesPlot[k] = hexPlot
                    end
                end
            end

            ---@type integer[]
            local xs <const> = {}
            ---@type integer[]
            local ys <const> = {}
            local lenHexesPlot <const> = #hexesPlot

            -- Find min and max.
            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            local center <const> = size // 2
            local xFlipScale <const> = xFlipNum / 255.0
            local yFlipScale <const> = yFlipNum / 255.0
            local zFlipScale <const> = zFlipNum / 255.0

            local i = 0
            while i < lenHexesPlot do
                i = i + 1
                local hexPlot <const> = hexesPlot[i]
                local xi = center
                local yi = center

                local r255 <const> = hexPlot & 0xff
                local g255 <const> = (hexPlot >> 0x08) & 0xff

                local x <const> = (r255 + r255 - 255) * xFlipScale
                local y <const> = (255 - (g255 + g255)) * yFlipScale

                local sqMag2d <const> = x * x + y * y
                if sqMag2d > 0.000031 then
                    local xu = 0.5
                    local yu = 0.5
                    if sqMag2d >= 1.0 then
                        -- Normalize by 2D magnitude.
                        local invMag2d <const> = 1.0 / sqrt(sqMag2d)
                        local xn2d <const> = x * invMag2d
                        local yn2d <const> = y * invMag2d

                        xu = xn2d * 0.5 + 0.5
                        yu = yn2d * 0.5 + 0.5
                    else
                        -- Normalize by 3D magnitude.
                        -- Simpler than using the trig identity
                        -- cos(asin(z)) = sqrt(1.0 - z * z) .
                        local b255 <const> = (hexPlot >> 0x10) & 0xff
                        local z <const> = (b255 + b255 - 255) * zFlipScale

                        -- By excluding zn3d, this projects a point
                        -- on a sphere onto a point on a circle.
                        local invMag3d <const> = 1.0 / sqrt(sqMag2d + z * z)
                        local xn3d <const> = x * invMag3d
                        local yn3d <const> = y * invMag3d

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
                local drawCircleFill <const> = AseUtilities.drawCircleFill
                local stroke2 <const> = strokeSize + strokeSize
                local xOff <const> = 1 + xMin - strokeSize
                local yOff <const> = 1 + yMin - strokeSize

                local wPlot <const> = (xMax - xMin) + stroke2 - 1
                local hPlot <const> = (yMax - yMin) + stroke2 - 1
                local plotSpec <const> = AseUtilities.createSpec(
                    wPlot, hPlot,
                    spec.colorMode,
                    spec.colorSpace,
                    spec.transparentColor)

                local plotImage <const> = Image(plotSpec)
                local plotPos <const> = Point(xOff, yOff)

                ---@type integer[]
                local plotPixels <const> = {}
                local lenPixels <const> = wPlot * hPlot * 4
                local j = 0
                while j < lenPixels do
                    j = j + 1
                    plotPixels[j] = 0
                end

                j = 0
                while j < lenHexesPlot do
                    j = j + 1
                    local hexPlot <const> = hexesPlot[j]
                    if (hexPlot & 0xff000000) ~= 0 then
                        local xi <const> = xs[j] - xOff
                        local yi <const> = ys[j] - yOff
                        drawCircleFill(plotPixels, wPlot, xi, yi, strokeSize,
                            255, 255, 255, 255)
                        drawCircleFill(plotPixels, wPlot, xi, yi, fillSize,
                            hexPlot & 0xff,
                            (hexPlot >> 0x08) & 0xff,
                            (hexPlot >> 0x10) & 0xff,
                            255)
                    end
                end

                AseUtilities.setPixels(plotImage, plotPixels)
                local plotPalLayer <const> = sprite:newLayer()
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

        app.layer = sprite.layers[1]
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