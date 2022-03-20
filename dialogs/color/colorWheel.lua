dofile("../../support/aseutilities.lua")

local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }

local defaults = {
    size = 256,
    minLight = 5,
    maxLight = 95,
    frames = 32,
    fps = 24,
    outOfGamut = 64,
    sectorCount = 0,
    ringCount = 0,
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    maxChroma = 135.0,
    pullFocus = false
}

local dlg = Dialog { title = "Lch Color Wheel" }

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
    id = "plotPalette",
    label = "Plot Palette:",
    selected = defaults.plotPalette,
    onclick = function()
        local args = dlg.data
        local usePlot = args.plotPalette
        local palType = args.palType
        dlg:modify { id = "palType", visible = usePlot }
        dlg:modify { id = "palFile", visible = usePlot and palType == "FILE" }
        dlg:modify { id = "palPreset", visible = usePlot and palType == "PRESET" }
        dlg:modify { id = "palStart", visible = usePlot }
        dlg:modify { id = "palCount", visible = usePlot }
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
        dlg:modify { id = "palPreset", visible = state == "PRESET" }
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

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()

        -- Cache methods.
        local atan2 = math.atan
        local floor = math.floor
        local sqrt = math.sqrt
        local trunc = math.tointeger

        local fromHex = Clr.fromHex
        local labTosRgba = Clr.labTosRgba
        local lchTosRgba = Clr.lchTosRgba
        local rgbIsInGamut = Clr.rgbIsInGamut
        local sRgbaToLab = Clr.sRgbaToLab
        local toHex = Clr.toHex

        local drawCircleFill = AseUtilities.drawCircleFill

        -- Unpack arguments.
        local args = dlg.data
        local plotPalette = args.plotPalette
        local size = args.size or defaults.size
        local ringCount = args.ringCount or defaults.ringCount
        local sectorCount = args.sectorCount or defaults.sectorCount
        local minLight = args.minLight or defaults.minLight
        local maxLight = args.maxLight or defaults.maxLight
        local outOfGamut = args.outOfGamut or defaults.outOfGamut

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
                -- Since a palette will be created immediately after, pbr.
                -- If this changes, and arrays are modified, then this
                -- will need to be a copy.
                hexesProfile = AseUtilities.DEFAULT_PAL_ARR
                hexesSrgb = hexesProfile
            end
        end

        -- Quantization calculations.
        local quantAzims = sectorCount > 0
        local quantRad = ringCount > 0
        local maxChroma = defaults.maxChroma

        -- Depending on case, may be hue, radians or degrees.
        local azimAlpha = sectorCount / 1.0
        local azimBeta = 0.0
        if quantAzims then
            azimBeta = 1.0 / sectorCount
        end

        local radAlpha = ringCount / maxChroma
        local radBeta = 0.0
        if quantRad then
            radBeta = maxChroma / ringCount
        end

        -- Create new sprite.
        local spec = ImageSpec {
            width = size,
            height = size,
            colorMode = ColorMode.RGB }
        spec.colorSpace = ColorSpace { sRGB = true }
        local sprite = Sprite(spec)
        sprite.filename = "LCh Color Wheel"

        -- Create color field images.
        local gamutImgs = {}
        local szInv = 1.0 / size
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end

        local oogamask = outOfGamut << 0x18
        for i = 1, reqFrames, 1 do

            -- Convert i to a step, then lerp from
            -- minimum light to maximum light.
            local iStep = (i - 1.0) * iToStep
            local light = (1.0 - iStep) * minLight + iStep * maxLight

            local gamutImg = Image(spec)
            local pxItr = gamutImg:pixels()
            for elm in pxItr do

                -- Convert coordinates from [0, size] to
                -- [0.0, 1.0], then to [-1.0, 1.0], then
                -- to CIE LAB range [-110.0, 110.0].
                -- local x = elm.x
                local xNrm = elm.x * szInv
                local xSgn = xNrm + xNrm - 1.0
                local a = xSgn * maxChroma

                -- local y = elm.y
                local yNrm = elm.y * szInv
                local ySgn = 1.0 - (yNrm + yNrm)
                local b = ySgn * maxChroma

                local clr = nil
                local csq = a * a + b * b
                if csq > 0.0 then
                    local c = sqrt(csq)
                    local h = atan2(b, a) * 0.15915494309189535

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
                -- at full opacity; otherwise display at reduced
                -- alpha. Find the valid boundary of the gamut.
                local hex = toHex(clr)
                if rgbIsInGamut(clr) then
                    elm(hex)
                else
                    elm(oogamask | (hex & 0x00ffffff))
                end
            end

            gamutImgs[i] = gamutImg
        end

        -- Create frames.
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        AseUtilities.createNewFrames(sprite, needed, duration)

        -- Set first layer to gamut.
        -- These are not wrapped in a transaction because
        -- gamut layer needs to be available beyond the
        -- transaction scope.
        local gamutLayer = sprite.layers[1]
        gamutLayer.name = "Gamut"

        -- Create gamut layer cels.
        app.transaction(function()
            for i = 1, reqFrames, 1 do
                sprite:newCel(
                    gamutLayer,
                    sprite.frames[i],
                    gamutImgs[i])
            end
        end)

        if plotPalette then

            -- Unpack arguments.
            local strokeSize = args.strokeSize or defaults.strokeSize
            local fillSize = args.fillSize or defaults.fillSize

            -- Find min and max.
            local xs = {}
            local ys = {}
            local strokes = {}

            local xMin = 2147483647
            local yMin = 2147483647
            local xMax = -2147483648
            local yMax = -2147483648

            local invMaxChroma = 0.5 / maxChroma
            local center = size // 2

            local hexesSrgbLen = #hexesSrgb
            for j = 1, hexesSrgbLen, 1 do
                local hexSrgb = hexesSrgb[j]
                local xi = center
                local yi = center
                local stroke = 0x0
                if hexSrgb & 0xff000000 ~= 0 then
                    local lab = sRgbaToLab(fromHex(hexSrgb))

                    -- From [0.0, chroma] to [0.0, 1.0]
                    local xNrm = lab.a * invMaxChroma + 0.5
                    local yNrm = 0.5 - lab.b * invMaxChroma

                    -- From [0.0, 1.0] to [0, size].
                    xi = trunc(0.5 + xNrm * size)
                    yi = trunc(0.5 + yNrm * size)

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

                local plotSpec =  ImageSpec {
                    width = (xMax - xMin) + stroke2 - 1,
                    height = (yMax - yMin) + stroke2 - 1,
                    colorMode = spec.colorMode }
                plotSpec.colorSpace = spec.colorSpace
                local plotImage = Image(plotSpec)
                local plotPos = Point(xOff, yOff)

                for j = 1, hexesSrgbLen, 1 do
                    local hexSrgb = hexesSrgb[j]
                    if hexSrgb & 0xff000000 ~= 0 then
                        local xi = xs[j] - xOff
                        local yi = ys[j] - yOff
                        local hexProfile = hexesProfile[j]
                        local strokeColor = strokes[j]
                        drawCircleFill(plotImage, xi, yi, strokeSize, strokeColor)
                        drawCircleFill(plotImage, xi, yi, fillSize, hexProfile)
                    end
                end

                local plotPalLayer = sprite:newLayer()
                plotPalLayer.name = "Palette"

                AseUtilities.createNewCels(
                    sprite,
                    1, reqFrames,
                    plotPalLayer.stackIndex, 1,
                    plotImage, plotPos)
            end

            -- This needs to be done at the very end because
            -- prependMask modifies hexesProfile.
            Utilities.prependMask(hexesProfile)
            sprite:setPalette(
                AseUtilities.hexArrToAsePalette(hexesProfile))
        else
            sprite:setPalette(
                AseUtilities.hexArrToAsePalette(
                    AseUtilities.DEFAULT_PAL_ARR))
        end

        app.activeFrame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        app.activeLayer = gamutLayer
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }