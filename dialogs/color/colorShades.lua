dofile("../../support/aseutilities.lua")

local paletteTypes = { "ACTIVE", "DEFAULT", "FILE" }

local defaults = {
    size = 256,
    frames = 32,
    fps = 24,
    outOfGamut = 64,
    quantization = 0,
    maxLight = 100.0,
    useHueBar = false,
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    pullFocus = true
}

local dlg = Dialog { title = "Lch Color Shades" }

dlg:slider {
    id = "size",
    label = "Size:",
    min = 64,
    max = 512,
    value = defaults.size
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
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization
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

dlg:check {
    id = "useHueBar",
    label = "Hue Bar:",
    selected = defaults.useHueBar
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
        -- Cache methods
        local floor = math.floor
        local fromHex = Clr.fromHex
        local rgbIsInGamut = Clr.rgbIsInGamut
        local toHex = Clr.toHex
        local quantize = Utilities.quantizeUnsigned
        local drawCircleFill = AseUtilities.drawCircleFill
        local lchTosRgba = Clr.srLchTosRgb
        local sRgbaToLch = Clr.sRgbToSrLch

        -- Unpack arguments.
        local args = dlg.data
        local maxChroma = Clr.SR_LCH_MAX_CHROMA
        local maxLight = args.maxLight or defaults.maxLight
        local outOfGamut = args.outOfGamut or defaults.outOfGamut
        local useHueBar = args.useHueBar
        local plotPalette = args.plotPalette

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        if plotPalette then
            local palType = args.palType
                or defaults.palType --[[@as string]]
            if palType ~= "DEFAULT" then
                local palFile = args.palFile --[[@as string]]
                local palStart = args.palStart
                    or defaults.palStart --[[@as integer]]
                local palCount = args.palCount
                    or defaults.palCount --[[@as integer]]

                hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                    palType, palFile, palStart, palCount, true)
            else
                -- As of circa apiVersion 24, version v1.3-rc4.
                local defaultPalette = app.defaultPalette
                if defaultPalette then
                    hexesProfile = AseUtilities.asePaletteToHexArr(
                        defaultPalette, 0, #defaultPalette)
                else
                    local hexesDefault = AseUtilities.DEFAULT_PAL_ARR
                    local lenHexesDef = #hexesDefault
                    local i = 0
                    while i < lenHexesDef do
                        i = i + 1
                        hexesProfile[i] = hexesDefault[i]
                    end
                end

                hexesSrgb = hexesProfile
            end
        end

        -- Create sprite.
        local size = args.size or defaults.size --[[@as integer]]
        local szInv = 1.0 / size
        local spec = ImageSpec {
            width = size,
            height = size,
            colorMode = ColorMode.RGB
        }
        spec.colorSpace = ColorSpace { sRGB = true }
        local sprite = Sprite(spec)
        sprite.filename = "LCh Color Shades"

        -- Calculate frame count to normalization.
        local iToStep = 0.5
        local reqFrames = args.frames
            or defaults.frames --[[@as integer]]
        if reqFrames > 0 then
            -- Because hue is periodic, don't subtract 1.
            iToStep = 1.0 / reqFrames
        end

        ---@type Image[]
        local gamutImgs = {}
        local oogaNorm = outOfGamut * 0.003921568627451
        local oogaEps = 2.0 * 0.003921568627451
        local quantization = args.quantization
            or defaults.quantization --[[@as integer]]
        local idxFrame = 0
        while idxFrame < reqFrames do
            -- Convert i to a step, which will be its hue.
            local iStep = idxFrame * iToStep
            local hue = iStep

            local gamutImg = Image(spec)
            local pxItr = gamutImg:pixels()
            for pixel in pxItr do
                -- Convert coordinates from [0, size] to
                -- [0.0, 1.0], then to LCH.
                local xNrm = pixel.x * szInv
                xNrm = quantize(xNrm, quantization)
                local chroma = xNrm * maxChroma

                local yNrm = pixel.y * szInv
                yNrm = quantize(yNrm, quantization)
                local light = (1.0 - yNrm) * maxLight

                local clr = lchTosRgba(light, chroma, hue, 1.0)
                if not rgbIsInGamut(clr, oogaEps) then
                    clr.a = oogaNorm
                end

                pixel(toHex(clr))
            end

            idxFrame = idxFrame + 1
            gamutImgs[idxFrame] = gamutImg
        end

        -- Create frames.
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local fps = args.fps or defaults.fps --[[@as integer]]
        local duration = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        app.transaction("New Frames", function()
            AseUtilities.createFrames(sprite, needed, duration)
        end)

        -- Set first layer to gamut.
        -- These are not wrapped in a transaction because
        -- gamut layer needs to be available beyond the
        -- transaction scope.
        local gamutLayer = sprite.layers[1]
        if quantization > 0 then
            gamutLayer.name = string.format(
                "Gamut.Quantize%d",
                quantization)
        else
            gamutLayer.name = "Gamut"
        end

        -- Create gamut layer cels.
        app.transaction("New Cels", function()
            local idxCel = 0
            while idxCel < reqFrames do
                idxCel = idxCel + 1
                sprite:newCel(
                    gamutLayer,
                    sprite.frames[idxCel],
                    gamutImgs[idxCel])
            end
        end)

        if useHueBar then
            local hueBarLayer = sprite:newLayer()
            hueBarLayer.name = "Hue"

            local hueBarWidth = math.ceil(size / 24)
            local hueBarHeight = size
            if hueBarWidth < 8 then hueBarWidth = 8 end
            local hueBarSpec = ImageSpec {
                width = hueBarWidth,
                height = hueBarHeight,
                colorMode = ColorMode.RGB
            }
            spec.colorSpace = ColorSpace { sRGB = true }
            local hueBarImage = Image(hueBarSpec)

            local yToHue = 1.0 / (hueBarHeight - 1.0)
            local hueBarPixels = hueBarImage:pixels()
            local halfChroma = maxChroma * 0.5
            for pixel in hueBarPixels do
                local hue = 1.0 - pixel.y * yToHue
                pixel(toHex(lchTosRgba(50.0, halfChroma, hue, 1.0)))
            end

            app.transaction("Hue Bar", function()
                local huePoint = Point(size - hueBarWidth, 0)
                local strokeColor = 0xffffffff
                local xi = hueBarWidth // 2
                local strokeSize = hueBarWidth // 2
                local idxCel = 0
                local iToHue = hueBarHeight * 0.5
                if reqFrames > 0 then
                    iToHue = hueBarHeight / reqFrames
                end
                while idxCel < reqFrames do
                    local yi = size - floor(0.5 + idxCel * iToHue)
                    local hueClone = hueBarImage:clone()
                    drawCircleFill(hueClone, xi, yi, strokeSize, strokeColor)

                    idxCel = idxCel + 1
                    sprite:newCel(
                        hueBarLayer,
                        sprite.frames[idxCel],
                        hueClone,
                        huePoint)
                end
            end)
        end

        if plotPalette then
            -- Unpack arguments.
            local strokeSize = args.strokeSize
                or defaults.strokeSize --[[@as integer]]
            local fillSize = args.fillSize
                or defaults.fillSize --[[@as integer]]

            ---@type integer[]
            local strokes = {}
            ---@type integer[]
            local xs = {}
            ---@type integer[]
            local ys = {}

            -- Find min and max.
            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            local invMaxChroma = 1.0 / maxChroma
            local invMaxLight = 1.0 / maxLight

            local lenHexesSrgb = #hexesSrgb
            local j = 0
            while j < lenHexesSrgb do
                j = j + 1
                local hexSrgb = hexesSrgb[j]
                local xi = 0
                local yi = size
                local stroke = 0x0
                if (hexSrgb & 0xff000000) ~= 0 then
                    local lch = sRgbaToLch(fromHex(hexSrgb))

                    -- Convert chroma to [0.0, 1.0].
                    local xNrm = lch.c * invMaxChroma
                    local yNrm = 1.0 - (lch.l * invMaxLight)

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

            if xMax > xMin and yMax > yMin then
                local stroke2 = strokeSize + strokeSize
                local xOff = 1 + xMin - strokeSize
                local yOff = 1 + yMin - strokeSize

                local plotSpec = ImageSpec {
                    width = (xMax - xMin) + stroke2 - 1,
                    height = (yMax - yMin) + stroke2 - 1,
                    colorMode = spec.colorMode
                }
                plotSpec.colorSpace = spec.colorSpace
                local plotImage = Image(plotSpec)
                local plotPos = Point(xOff, yOff)

                local k = 0
                while k < lenHexesSrgb do
                    k = k + 1
                    local hexSrgb = hexesSrgb[k]
                    if (hexSrgb & 0xff000000) ~= 0 then
                        local xi = xs[k] - xOff
                        local yi = ys[k] - yOff
                        local hexProfile = hexesProfile[k]
                        local strokeColor = strokes[k]
                        drawCircleFill(plotImage, xi, yi, strokeSize, strokeColor)
                        drawCircleFill(plotImage, xi, yi, fillSize, hexProfile)
                    end
                end

                local plotPalLayer = sprite:newLayer()
                plotPalLayer.name = "Palette"

                app.transaction("Plot Palette", function()
                    AseUtilities.createCels(
                        sprite,
                        1, reqFrames,
                        plotPalLayer.stackIndex, 1,
                        plotImage, plotPos, 0x0)
                end)
            end

            -- This needs to be done at the very end because
            -- prependMask modifies hexesProfile.
            Utilities.prependMask(hexesProfile)
            AseUtilities.setPalette(hexesProfile, sprite, 1)
        else
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, sprite, 1)
        end

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