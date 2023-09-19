dofile("../../support/aseutilities.lua")

local paletteTypes <const> = { "ACTIVE", "DEFAULT", "FILE" }

local defaults <const> = {
    size = 256,
    minLight = 5,
    maxLight = 95,
    frames = 32,
    fps = 24,
    outOfGamut = 64,
    sectorCount = 0,
    ringCount = 0,
    useLightBar = false,
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    pullFocus = true
}

local dlg <const> = Dialog { title = "Lch Color Wheel" }

dlg:slider {
    id = "size",
    label = "Size:",
    min = 64,
    max = 512,
    value = defaults.size
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 1,
    max = 98,
    value = defaults.minLight
}

dlg:slider {
    id = "maxLight",
    min = 2,
    max = 99,
    value = defaults.maxLight
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

dlg:slider {
    id = "outOfGamut",
    label = "Out of Gamut:",
    min = 0,
    max = 255,
    value = defaults.outOfGamut
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectorCount",
    label = "Sectors:",
    min = 0,
    max = 32,
    value = defaults.sectorCount
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings:",
    min = 0,
    max = 16,
    value = defaults.ringCount
}

dlg:newrow { always = false }

dlg:check {
    id = "useLightBar",
    label = "Light Bar:",
    selected = defaults.useLightBar
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
        dlg:modify { id = "palType", visible = usePlot }
        dlg:modify { id = "palFile", visible = usePlot and palType == "FILE" }
    end
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
        local atan2 <const> = math.atan
        local floor <const> = math.floor
        local sqrt <const> = math.sqrt

        local fromHex <const> = Clr.fromHex
        local labTosRgba <const> = Clr.srLab2TosRgb
        local lchTosRgba <const> = Clr.srLchTosRgb
        local rgbIsInGamut <const> = Clr.rgbIsInGamut
        local sRgbaToLab <const> = Clr.sRgbToSrLab2
        local toHex <const> = Clr.toHex

        local drawCircleFill <const> = AseUtilities.drawCircleFill

        -- Unpack arguments.
        local args <const> = dlg.data
        local size <const> = args.size
            or defaults.size --[[@as integer]]
        local ringCount <const> = args.ringCount
            or defaults.ringCount --[[@as integer]]
        local sectorCount <const> = args.sectorCount
            or defaults.sectorCount --[[@as integer]]
        local minLight <const> = args.minLight
            or defaults.minLight --[[@as integer]]
        local maxLight <const> = args.maxLight
            or defaults.maxLight --[[@as integer]]
        local outOfGamut <const> = args.outOfGamut
            or defaults.outOfGamut --[[@as integer]]
        local useLightBar <const> = args.useLightBar --[[@as boolean]]
        local plotPalette <const> = args.plotPalette --[[@as boolean]]

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        if plotPalette then
            local palType <const> = args.palType
                or defaults.palType --[[@as string]]
            if palType ~= "DEFAULT" then
                local palFile <const> = args.palFile --[[@as string]]
                local palStart <const> = args.palStart
                    or defaults.palStart --[[@as integer]]
                local palCount <const> = args.palCount
                    or defaults.palCount --[[@as integer]]

                hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                    palType, palFile, palStart, palCount, true)
            else
                -- As of circa apiVersion 24, version v1.3-rc4.
                local defaultPalette <const> = app.defaultPalette
                if defaultPalette then
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        defaultPalette, 0, #defaultPalette)
                else
                    local hexesDefault <const> = AseUtilities.DEFAULT_PAL_ARR
                    local lenHexesDef <const> = #hexesDefault
                    local i = 0
                    while i < lenHexesDef do
                        i = i + 1
                        hexesProfile[i] = hexesDefault[i]
                    end
                end

                hexesSrgb = hexesProfile
            end
        end

        -- Quantization calculations.
        local quantAzims <const> = sectorCount > 0
        local quantRad <const> = ringCount > 0
        local maxChroma <const> = Clr.SR_LCH_MAX_CHROMA

        -- Depending on case, may be hue, radians or degrees.
        local azimAlpha <const> = sectorCount / 1.0
        local azimBeta = 0.0
        if quantAzims then
            azimBeta = 1.0 / sectorCount
        end

        local radAlpha <const> = ringCount / maxChroma
        local radBeta = 0.0
        if quantRad then
            radBeta = maxChroma / ringCount
        end

        -- Create sprite.
        local spec <const> = ImageSpec {
            width = size,
            height = size,
            colorMode = ColorMode.RGB
        }
        spec.colorSpace = ColorSpace { sRGB = true }
        local sprite <const> = Sprite(spec)
        sprite.filename = "LCh Color Wheel"

        -- Create color field images.
        ---@type Image[]
        local gamutImgs <const> = {}
        local szInv <const> = 1.0 / size
        local iToStep = 0.5
        local reqFrames <const> = args.frames
            or defaults.frames --[[@as integer]]
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end

        local oogamask <const> = outOfGamut << 0x18
        local idxFrame = 0
        while idxFrame < reqFrames do
            -- Convert i to a step, then lerp from minimum
            -- to maximum light.
            local iStep <const> = idxFrame * iToStep
            local light <const> = (1.0 - iStep) * minLight + iStep * maxLight

            local gamutImg <const> = Image(spec)
            local pxItr <const> = gamutImg:pixels()
            for pixel in pxItr do
                -- Convert coordinates from [0, size] to [0.0, 1.0], then to
                -- [-1.0, 1.0], then to LAB range [-111.0, 111.0].
                local xNrm <const> = pixel.x * szInv
                local xSgn <const> = xNrm + xNrm - 1.0
                local a <const> = xSgn * maxChroma

                local yNrm <const> = pixel.y * szInv
                local ySgn <const> = 1.0 - (yNrm + yNrm)
                local b <const> = ySgn * maxChroma

                local clr = nil
                local csq <const> = a * a + b * b
                if csq > 0.0 then
                    local c = sqrt(csq)
                    local h = atan2(b, a) * 0.1591549430919

                    if quantAzims then
                        h = floor(0.5 + h * azimAlpha) * azimBeta
                    end

                    if quantRad then
                        -- Use unsigned?
                        c = floor(0.5 + c * radAlpha) * radBeta
                    end

                    clr = lchTosRgba(light, c, h, 1.0)
                else
                    clr = labTosRgba(light, 0.0, 0.0, 1.0)
                end

                -- If color is within SRGB gamut, then display
                -- at full opacity. Otherwise, display at reduced
                -- alpha. Find the valid boundary of the gamut.
                local hex <const> = toHex(clr)
                if rgbIsInGamut(clr, 0.0) then
                    pixel(hex)
                else
                    pixel(oogamask | (hex & 0x00ffffff))
                end
            end

            idxFrame = idxFrame + 1
            gamutImgs[idxFrame] = gamutImg
        end

        -- Create frames.
        local oldFrameLen <const> = #sprite.frames
        local needed <const> = math.max(0, reqFrames - oldFrameLen)
        local fps <const> = args.fps or defaults.fps --[[@as integer]]
        local duration <const> = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        app.transaction("New Frames", function()
            AseUtilities.createFrames(sprite, needed, duration)
        end)

        -- Set first layer to gamut.
        -- These are not wrapped in a transaction because
        -- gamut layer needs to be available beyond the
        -- transaction scope.
        local gamutLayer <const> = sprite.layers[1]
        if quantAzims or quantRad then
            gamutLayer.name = string.format(
                "Gamut.Sectors%d.Rings%d",
                sectorCount, ringCount)
        else
            gamutLayer.name = "Gamut"
        end

        -- Create gamut layer cels.
        app.transaction("New Cels", function()
            local spriteFrames <const> = sprite.frames
            local idxCel = 0
            while idxCel < reqFrames do
                idxCel = idxCel + 1
                sprite:newCel(
                    gamutLayer,
                    spriteFrames[idxCel],
                    gamutImgs[idxCel])
            end
        end)

        if useLightBar then
            local lightBarLayer <const> = sprite:newLayer()
            lightBarLayer.name = "Light"

            local lightBarWidth = math.ceil(size / 24)
            local lightBarHeight <const> = size
            if lightBarWidth < 8 then lightBarWidth = 8 end
            local lightBarSpec <const> = ImageSpec {
                width = lightBarWidth,
                height = lightBarHeight,
                colorMode = ColorMode.RGB
            }
            spec.colorSpace = ColorSpace { sRGB = true }
            local lightBarImage <const> = Image(lightBarSpec)
            local yToLight <const> = 100.0 / (lightBarHeight - 1.0)

            local lightBarPixels <const> = lightBarImage:pixels()
            for pixel in lightBarPixels do
                local light <const> = 100.0 - pixel.y * yToLight
                pixel(toHex(labTosRgba(light, 0.0, 0.0, 1.0)))
            end

            app.transaction("Light Bar", function()
                local lightPoint <const> = Point(size - lightBarWidth, 0)
                local halfHeight <const> = lightBarHeight // 2
                local xi <const> = lightBarWidth // 2
                local strokeSize <const> = lightBarWidth // 2
                local idxCel = 0
                local iToFac = 0.5
                if reqFrames > 1 then
                    iToFac = 1.0 / (reqFrames - 1.0)
                end
                local yMin <const> = minLight * lightBarHeight * 0.01
                local yMax <const> = maxLight * lightBarHeight * 0.01
                local spriteFrames <const> = sprite.frames
                while idxCel < reqFrames do
                    local fac <const> = idxCel * iToFac
                    local yf <const> = (1.0 - fac) * yMin + fac * yMax
                    local yi <const> = size - floor(0.5 + yf)
                    local lightClone <const> = lightBarImage:clone()
                    local strokeColor = 0xffffffff
                    if yi < halfHeight then strokeColor = 0xff000000 end
                    drawCircleFill(lightClone, xi, yi, strokeSize, strokeColor)

                    idxCel = idxCel + 1
                    sprite:newCel(
                        lightBarLayer,
                        spriteFrames[idxCel],
                        lightClone,
                        lightPoint)
                end
            end)
        end

        if plotPalette then
            -- Unpack arguments.
            local strokeSize <const> = args.strokeSize
                or defaults.strokeSize --[[@as integer]]
            local fillSize <const> = args.fillSize
                or defaults.fillSize --[[@as integer]]

            ---@type integer[]
            local strokes <const> = {}
            ---@type integer[]
            local xs <const> = {}
            ---@type integer[]
            local ys <const> = {}

            -- Find min and max.
            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            local invMaxChroma <const> = 0.5 / maxChroma
            local center <const> = size // 2

            local lenHexesSrgb <const> = #hexesSrgb
            local j = 0
            while j < lenHexesSrgb do
                j = j + 1
                local hexSrgb <const> = hexesSrgb[j]
                local xi = center
                local yi = center
                local stroke = 0x0
                if hexSrgb & 0xff000000 ~= 0 then
                    local lab <const> = sRgbaToLab(fromHex(hexSrgb))

                    -- From [0.0, chroma] to [0.0, 1.0]
                    local xNrm <const> = lab.a * invMaxChroma + 0.5
                    local yNrm <const> = 0.5 - lab.b * invMaxChroma

                    -- From [0.0, 1.0] to [0, size].
                    xi = floor(0.5 + xNrm * size)
                    yi = floor(0.5 + yNrm * size)

                    if xi < xMin then xMin = xi end
                    if xi > xMax then xMax = xi end
                    if yi < yMin then yMin = yi end
                    if yi > yMax then yMax = yi end

                    if hexSrgb == 0xffffffff then
                        stroke = 0xff000000
                    else
                        stroke = 0xffffffff
                    end
                end

                strokes[j] = stroke
                xs[j] = xi
                ys[j] = yi
            end

            if yMax == yMin then
                yMax = size
                yMin = 0
            end

            if xMax == xMin then
                xMax = size
                xMin = 0
            end

            local stroke2 <const> = strokeSize + strokeSize
            local xOff <const> = 1 + xMin - strokeSize
            local yOff <const> = 1 + yMin - strokeSize

            local plotSpec <const> = ImageSpec {
                width = (xMax - xMin) + stroke2 - 1,
                height = (yMax - yMin) + stroke2 - 1,
                colorMode = spec.colorMode
            }
            plotSpec.colorSpace = spec.colorSpace
            local plotImage <const> = Image(plotSpec)
            local plotPos <const> = Point(xOff, yOff)

            local k = 0
            while k < lenHexesSrgb do
                k = k + 1
                local hexSrgb <const> = hexesSrgb[k]
                if (hexSrgb & 0xff000000) ~= 0 then
                    local xi <const> = xs[k] - xOff
                    local yi <const> = ys[k] - yOff
                    local hexProfile <const> = hexesProfile[k]
                    local strokeColor <const> = strokes[k]
                    drawCircleFill(plotImage, xi, yi, strokeSize, strokeColor)
                    drawCircleFill(plotImage, xi, yi, fillSize, hexProfile)
                end
            end

            local plotPalLayer <const> = sprite:newLayer()
            plotPalLayer.name = "Palette"

            app.transaction("Plot Palette", function()
                AseUtilities.createCels(
                    sprite,
                    1, reqFrames,
                    plotPalLayer.stackIndex, 1,
                    plotImage, plotPos, 0x0)
            end)

            -- This needs to be done at the very end because
            -- prependMask modifies hexesProfile.
            Utilities.prependMask(hexesProfile)
            AseUtilities.setPalette(hexesProfile, sprite, 1)
        else
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, sprite, 1)
        end

        app.activeFrame = sprite.frames[math.ceil(#sprite.frames / 2)]
        app.activeLayer = gamutLayer
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