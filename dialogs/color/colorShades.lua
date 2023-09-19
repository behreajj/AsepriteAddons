dofile("../../support/aseutilities.lua")

local paletteTypes <const> = { "ACTIVE", "DEFAULT", "FILE" }

local defaults <const> = {
    size = 256,
    frames = 36,
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

local dlg <const> = Dialog { title = "Lch Color Shades" }

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
    max = 108,
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
        local floor <const> = math.floor

        local fromHex <const> = Clr.fromHex
        local lchTosRgba <const> = Clr.srLchTosRgb
        local rgbIsInGamut <const> = Clr.rgbIsInGamut
        local sRgbaToLch <const> = Clr.sRgbToSrLch
        local toHex <const> = Clr.toHex

        local drawCircleFill <const> = AseUtilities.drawCircleFill
        local quantize <const> = Utilities.quantizeUnsigned

        -- Unpack arguments.
        local args <const> = dlg.data
        local maxChroma <const> = Clr.SR_LCH_MAX_CHROMA
        local maxLight <const> = args.maxLight
            or defaults.maxLight --[[@as integer]]
        local outOfGamut <const> = args.outOfGamut
            or defaults.outOfGamut --[[@as integer]]
        local useHueBar <const> = args.useHueBar --[[@as boolean]]
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

        -- Create sprite.
        local size <const> = args.size
            or defaults.size --[[@as integer]]
        local szInv <const> = 1.0 / size
        local spec = ImageSpec {
            width = size,
            height = size,
            colorMode = ColorMode.RGB
        }
        spec.colorSpace = ColorSpace { sRGB = true }
        local sprite <const> = Sprite(spec)
        sprite.filename = "LCh Color Shades"

        -- Calculate frame count to normalization.
        local iToStep = 0.5
        local reqFrames <const> = args.frames
            or defaults.frames --[[@as integer]]
        if reqFrames > 0 then
            -- Because hue is periodic, don't subtract 1 from denominator.
            iToStep = 1.0 / reqFrames
        end

        ---@type Image[]
        local gamutImgs <const> = {}
        local oogaNorm <const> = outOfGamut * 0.003921568627451
        local oogaEps <const> = 0.0
        local quantization <const> = args.quantization
            or defaults.quantization --[[@as integer]]
        local idxFrame = 0
        while idxFrame < reqFrames do
            -- Convert i to a step, which will be its hue.
            local iStep <const> = idxFrame * iToStep
            local hue <const> = iStep

            local gamutImg <const> = Image(spec)
            local pxItr <const> = gamutImg:pixels()
            for pixel in pxItr do
                -- Convert coordinates from [0, size] to [0.0, 1.0] then to LCH.
                local xNrm = pixel.x * szInv
                xNrm = quantize(xNrm, quantization)
                local chroma <const> = xNrm * maxChroma

                local yNrm = pixel.y * szInv
                yNrm = quantize(yNrm, quantization)
                local light <const> = (1.0 - yNrm) * maxLight

                local clr <const> = lchTosRgba(light, chroma, hue, 1.0)
                if not rgbIsInGamut(clr, oogaEps) then
                    -- TODO: This breaks the general rules of good code
                    -- in this repository, as it should be assumed
                    -- that colors are immutable.
                    clr.a = oogaNorm
                end

                pixel(toHex(clr))
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
        if quantization > 0 then
            gamutLayer.name = string.format(
                "Gamut.Quantize%d",
                quantization)
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

        if useHueBar then
            local hueBarLayer <const> = sprite:newLayer()
            hueBarLayer.name = "Hue"

            local hueBarWidth = math.ceil(size / 24)
            local hueBarHeight <const> = size
            if hueBarWidth < 8 then hueBarWidth = 8 end
            local hueBarSpec <const> = ImageSpec {
                width = hueBarWidth,
                height = hueBarHeight,
                colorMode = ColorMode.RGB
            }
            spec.colorSpace = ColorSpace { sRGB = true }
            local hueBarImage <const> = Image(hueBarSpec)

            local yToHue <const> = 1.0 / (hueBarHeight - 1.0)
            local hueBarPixels <const> = hueBarImage:pixels()
            local halfChroma <const> = maxChroma * 0.5
            for pixel in hueBarPixels do
                local hue <const> = 1.0 - pixel.y * yToHue
                pixel(toHex(lchTosRgba(50.0, halfChroma, hue, 1.0)))
            end

            app.transaction("Hue Bar", function()
                local huePoint <const> = Point(size - hueBarWidth, 0)
                local strokeColor <const> = 0xffffffff
                local xi <const> = hueBarWidth // 2
                local strokeSize <const> = hueBarWidth // 2
                local idxCel = 0
                local iToHue = hueBarHeight * 0.5
                if reqFrames > 0 then
                    iToHue = hueBarHeight / reqFrames
                end
                local spriteFrames <const> = sprite.frames
                while idxCel < reqFrames do
                    local yi <const> = size - floor(0.5 + idxCel * iToHue)
                    local hueClone <const> = hueBarImage:clone()
                    drawCircleFill(hueClone, xi, yi, strokeSize, strokeColor)

                    idxCel = idxCel + 1
                    sprite:newCel(
                        hueBarLayer,
                        spriteFrames[idxCel],
                        hueClone,
                        huePoint)
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

            local invMaxChroma <const> = 1.0 / maxChroma
            local invMaxLight <const> = 1.0 / maxLight

            local lenHexesSrgb <const> = #hexesSrgb
            local j = 0
            while j < lenHexesSrgb do
                j = j + 1
                local hexSrgb <const> = hexesSrgb[j]
                local xi = 0
                local yi = size
                local stroke = 0x0
                if (hexSrgb & 0xff000000) ~= 0 then
                    local lch <const> = sRgbaToLch(fromHex(hexSrgb))

                    -- Convert chroma to [0.0, 1.0].
                    local xNrm <const> = lch.c * invMaxChroma
                    local yNrm <const> = 1.0 - (lch.l * invMaxLight)

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