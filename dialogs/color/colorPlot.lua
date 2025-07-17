dofile("../../support/shapeutilities.lua")

local axisPresets <const> = {
    -- Lightness is z, hue is theta, chroma is rho.
    "LIGHTNESS",

    -- Chroma is z, hue is theta, lightness is rho.
    "CHROMA",

    -- Hue is z, chroma is x, lightness is y.
    "HUE",
}

local paletteTypes <const> = {
    "ACTIVE",
    "DEFAULT",
    "FILE",
    "PRESET",
}

local defaults <const> = {
    size = 256,
    frames = 36,
    fps = 24,
    outOfGamut = 64,

    axisPreset = "LIGHTNESS",

    -- Polar graphs (chroma, lightness):
    sectorCount = 0,
    ringCount = 0,

    -- Chroma only:
    minChroma = math.ceil(Lab.SR_MAX_CHROMA * 0.2),
    maxChroma = math.ceil(Lab.SR_MAX_CHROMA * 0.8),

    -- Lightness only:
    minLight = 5,
    maxLight = 95,

    -- Cartesian graphs (hue):
    quantization = 0,

    plotPalette = true,
    palType = "ACTIVE",
    palResource = "",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    gamutTol = 0.001,
    strokeWeight = 1,
}

local dlg <const> = Dialog { title = "Plot Lch Color" }

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
    id = "outOfGamut",
    label = "Out of Gamut:",
    min = 0,
    max = 255,
    value = defaults.outOfGamut
}

dlg:newrow { always = false }

dlg:combobox {
    id = "axisPreset",
    label = "Axis:",
    option = defaults.axisPreset,
    options = axisPresets,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.axisPreset --[[@as string]]

        local isChroma <const> = state == "CHROMA"
        local isHue <const> = state == "HUE"
        local isLight <const> = state == "LIGHTNESS"

        local isCartesian <const> = isHue
        local isPolar <const> = isChroma or isLight

        dlg:modify { id = "quantization", visible = isCartesian }

        dlg:modify { id = "sectorCount", visible = isPolar }
        dlg:modify { id = "ringCount", visible = isPolar }

        dlg:modify { id = "minChroma", visible = isChroma }
        dlg:modify { id = "maxChroma", visible = isChroma }

        dlg:modify { id = "minLight", visible = isLight }
        dlg:modify { id = "maxLight", visible = isLight }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization,
    visible = defaults.axisPreset == "HUE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectorCount",
    label = "Sectors:",
    min = 0,
    max = 32,
    value = defaults.sectorCount,
    visible = defaults.axisPreset == "CHROMA"
        or defaults.axisPreset == "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings:",
    min = 0,
    max = 16,
    value = defaults.ringCount,
    visible = defaults.axisPreset == "CHROMA"
        or defaults.axisPreset == "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 0,
    max = 99,
    value = defaults.minLight,
    visible = defaults.axisPreset == "LIGHTNESS"
}

dlg:slider {
    id = "maxLight",
    min = 1,
    max = 100,
    value = defaults.maxLight,
    visible = defaults.axisPreset == "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "minChroma",
    label = "Chroma:",
    min = 0,
    max = math.ceil(Lab.SR_MAX_CHROMA) - 1,
    value = defaults.minChroma,
    visible = defaults.axisPreset == "CHROMA"
}

dlg:slider {
    id = "maxChroma",
    min = 1,
    max = math.ceil(Lab.SR_MAX_CHROMA),
    value = defaults.maxChroma,
    visible = defaults.axisPreset == "CHROMA"
}

dlg:newrow { always = false }

dlg:check {
    id = "plotPalette",
    label = "Plot:",
    text = "Palette",
    selected = defaults.plotPalette,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local usePlot <const> = args.plotPalette --[[@as boolean]]
        local palType <const> = args.palType --[[@as string]]

        dlg:modify { id = "palType", visible = usePlot }
        dlg:modify { id = "palResource", visible = usePlot and palType == "PRESET" }
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
    hexpand = false,
    onchange = function()
        local state <const> = dlg.data.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
        dlg:modify { id = "palResource", visible = state == "PRESET" }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "palResource",
    text = defaults.palResource,
    visible = defaults.plotPalette
        and defaults.palType == "PRESET"
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    basepath = app.fs.joinPath(
        app.fs.userConfigPath, "palettes"),
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
    focus = true,
    onclick = function()
        -- Cache methods.
        local atan2 <const> = math.atan
        local cos <const> = math.cos
        local floor <const> = math.floor
        local sqrt <const> = math.sqrt
        local min <const> = math.min
        local max <const> = math.max
        local sin <const> = math.sin
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local fromHex <const> = Rgb.fromHexAbgr32
        local rgbIsInGamut <const> = Rgb.rgbIsInGamut
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local sRgbToLch <const> = ColorUtilities.sRgbToSrLchInternal
        local lchTosRgb <const> = ColorUtilities.srLchTosRgbInternal
        local quantize <const> = Utilities.quantizeUnsigned
        local rgbToAseColor <const> = AseUtilities.rgbToAseColor

        -- Unpack arguments.
        local args <const> = dlg.data
        local axisPreset <const> = args.axisPreset
            or defaults.axisPreset --[[@as string]]

        local size <const> = args.size
            or defaults.size --[[@as integer]]
        local reqFrames <const> = args.frames
            or defaults.frames --[[@as integer]]
        local fps <const> = args.fps
            or defaults.fps --[[@as integer]]
        local outOfGamut <const> = args.outOfGamut
            or defaults.outOfGamut --[[@as integer]]

        -- Polar graphs (chroma, lightness):
        local sectorCount <const> = args.sectorCount
            or defaults.sectorCount --[[@as integer]]
        local ringCount <const> = args.ringCount
            or defaults.ringCount --[[@as integer]]

        -- For plotting palette:
        local plotPalette <const> = args.plotPalette --[[@as boolean]]
        local strokeSize <const> = args.strokeSize
            or defaults.strokeSize --[[@as integer]]
        local fillSize <const> = args.fillSize
            or defaults.fillSize --[[@as integer]]

        -- Parameters not exposed to UI:
        local gamutTol <const> = defaults.gamutTol
        local strokeWeight <const> = defaults.strokeWeight
        local stroke2 <const> = strokeSize + strokeSize

        -- Variables derived from arguments.
        local axisIsChroma <const> = axisPreset == "CHROMA"
        local axisIsHue <const> = axisPreset == "HUE"
        local axisIsLight <const> = axisPreset == "LIGHTNESS"

        local plotIsCartesian <const> = axisIsHue
        local plotIsPolar <const> = axisIsChroma
            or axisIsLight

        -- For polar quantization.
        local quantAzims <const> = sectorCount > 0
        local quantRad <const> = ringCount > 0

        local szInv <const> = size ~= 0.0 and 1.0 / size or 0.0
        local szSq <const> = size * size
        local frameToStep <const> = plotIsCartesian
            and (reqFrames > 0
                and 1.0 / reqFrames or 0.5)
            or (reqFrames > 1
                and 1.0 / (reqFrames - 1.0) or 0.5)

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        if plotPalette then
            local palType <const> = args.palType
                or defaults.palType --[[@as string]]
            if palType ~= "DEFAULT" then
                local palFile <const> = args.palFile --[[@as string]]
                local palResource <const> = args.palResource
                    or defaults.palResource --[[@as string]]
                local palStart <const> = args.palStart
                    or defaults.palStart --[[@as integer]]
                local palCount <const> = args.palCount
                    or defaults.palCount --[[@as integer]]

                hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                    palType, palFile, palResource, palStart, palCount, true)
            else
                -- As of circa apiVersion 24, version v1.3-rc4.
                -- local defaultPalette <const> = app.defaultPalette
                -- if defaultPalette then
                -- hexesProfile = AseUtilities.asePaletteToHexArr(
                -- defaultPalette, 0, #defaultPalette)
                -- else
                local hexesDefault <const> = AseUtilities.DEFAULT_PAL_ARR
                local lenHexesDef <const> = #hexesDefault
                local i = 0
                while i < lenHexesDef do
                    i = i + 1
                    hexesProfile[i] = hexesDefault[i]
                end
                -- end

                hexesSrgb = hexesProfile
            end -- End palette type is not default
        end     -- End plot palette is true

        local lenHexesSrgb <const> = #hexesSrgb

        -- Create sprite.
        local gamutSpec <const> = AseUtilities.createSpec(size, size)
        local sprite <const> = AseUtilities.createSprite(
            gamutSpec, "LCH Plot", false)
        AseUtilities.setPalette(
            AseUtilities.DEFAULT_PAL_ARR, sprite, 1)

        ---@type Image[]
        local gamutImgs <const> = {}
        local gamutLayerName = "Layer"

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
        local plotIsValid = false

        ---@type Color[]
        local celColors <const> = {}

        if axisIsChroma then
            gamutLayerName = string.format(
                "Chroma Sectors %d Rings %d",
                sectorCount, ringCount)

            local minChroma <const> = args.minChroma
                or defaults.minChroma --[[@as integer]]
            local maxChroma <const> = args.maxChroma
                or defaults.maxChroma --[[@as integer]]

            local azimAlpha <const> = sectorCount / 1.0
            local azimBeta <const> = quantAzims
                and 1.0 / sectorCount
                or 0.0
            local radAlpha <const> = ringCount / 100.0
            local radBeta <const> = quantRad
                and 100.0 / ringCount
                or 0.0

            local idxFrame = 0
            while idxFrame < reqFrames do
                local frameStep <const> = idxFrame * frameToStep
                local chroma <const> = (1.0 - frameStep) * minChroma
                    + frameStep * maxChroma

                ---@type string[]
                local pixels <const> = {}
                local j = 0
                while j < szSq do
                    local y <const> = j // size
                    local yNrm <const> = y * szInv
                    local ySgn <const> = 1.0 - (yNrm + yNrm)
                    local yLgt <const> = ySgn * 100.0

                    local x <const> = j % size
                    local xNrm <const> = x * szInv
                    local xSgn <const> = xNrm + xNrm - 1.0
                    local xLgt <const> = xSgn * 100.0

                    local light = 100.0 - sqrt(xLgt * xLgt + yLgt * yLgt)
                    if quantRad then
                        light = floor(0.5 + light * radAlpha) * radBeta
                    end

                    local hue = atan2(ySgn, xSgn) * 0.1591549430919
                    if quantAzims then
                        hue = floor(0.5 + hue * azimAlpha) * azimBeta
                    end

                    local srgb <const> = lchTosRgb(light, chroma, hue, 1.0)
                    local r8 <const> = floor(min(max(srgb.r, 0.0), 1.0) * 255 + 0.5)
                    local g8 <const> = floor(min(max(srgb.g, 0.0), 1.0) * 255 + 0.5)
                    local b8 <const> = floor(min(max(srgb.b, 0.0), 1.0) * 255 + 0.5)
                    local a8 <const> = rgbIsInGamut(srgb, gamutTol)
                        and 255
                        or outOfGamut

                    j = j + 1
                    pixels[j] = strpack("B B B B", r8, g8, b8, a8)
                end

                local gamutImg <const> = Image(gamutSpec)
                gamutImg.bytes = tconcat(pixels)
                gamutImgs[1 + idxFrame] = gamutImg

                local celColor <const> = rgbToAseColor(
                    lchTosRgb(50.0, chroma, 0.0, 1.0))
                celColors[1 + idxFrame] = celColor

                idxFrame = idxFrame + 1
            end -- End frame loop

            if plotPalette then
                local center <const> = size // 2

                -- Lightness has an absolute lower and upper bound,
                -- unlike chroma.
                xMin = 0
                yMin = 0
                xMax = size - 1
                yMax = size - 1

                local j = 0
                while j < lenHexesSrgb do
                    j = j + 1
                    local hexSrgb <const> = hexesSrgb[j]
                    local xi = center
                    local yi = center

                    local stroke = 0x0
                    if hexSrgb & 0xff000000 ~= 0 then
                        plotIsValid = true
                        local lch <const> = sRgbToLch(fromHex(hexSrgb))

                        local l01 <const> = (100.0 - lch.l) * 0.01
                        local hRad <const> = lch.h * 6.2831853071796
                        local xNrm <const> = 0.5 + 0.5 * l01 * cos(hRad)
                        local yNrm <const> = 0.5 - 0.5 * l01 * sin(hRad)

                        -- From [0.0, 1.0] to [0, size].
                        xi = floor(0.5 + xNrm * size)
                        yi = floor(0.5 + yNrm * size)

                        if lch.l > 50.0 then
                            stroke = 0xff000000
                        else
                            stroke = 0xffffffff
                        end
                    end

                    strokes[j] = stroke
                    xs[j] = xi
                    ys[j] = yi
                end -- End swatches loop
            end     -- End plot palette
        elseif axisIsHue then
            local quantization <const> = args.quantization
                or defaults.quantization --[[@as integer]]
            local srMaxChroma <const> = Lab.SR_MAX_CHROMA

            gamutLayerName = string.format(
                "Hue Quantize %d",
                quantization)

            local idxFrame = 0
            while idxFrame < reqFrames do
                local frameStep <const> = idxFrame * frameToStep
                local hue = frameStep

                ---@type string[]
                local pixels <const> = {}
                local j = 0
                while j < szSq do
                    local y <const> = j // size
                    local yNrm <const> = quantize(y * szInv, quantization)
                    local light <const> = (1.0 - yNrm) * 100.0

                    local x <const> = j % size
                    local xNrm <const> = quantize(x * szInv, quantization)
                    local chroma <const> = xNrm * srMaxChroma

                    local srgb <const> = lchTosRgb(light, chroma, hue, 1.0)

                    local r8 <const> = floor(min(max(srgb.r, 0.0), 1.0) * 255 + 0.5)
                    local g8 <const> = floor(min(max(srgb.g, 0.0), 1.0) * 255 + 0.5)
                    local b8 <const> = floor(min(max(srgb.b, 0.0), 1.0) * 255 + 0.5)
                    local a8 <const> = rgbIsInGamut(srgb, gamutTol) and 255 or outOfGamut

                    j = j + 1
                    pixels[j] = strpack("B B B B", r8, g8, b8, a8)
                end

                local gamutImg <const> = Image(gamutSpec)
                gamutImg.bytes = tconcat(pixels)
                gamutImgs[1 + idxFrame] = gamutImg

                local celColor <const> = rgbToAseColor(
                    lchTosRgb(50.0, 50.0, hue, 1.0))
                celColors[1 + idxFrame] = celColor

                idxFrame = idxFrame + 1
            end -- End frame loop

            if plotPalette then
                local invMaxChroma <const> = 1.0 / srMaxChroma
                local invMaxLight <const> = 1.0 / 100.0

                local j = 0
                while j < lenHexesSrgb do
                    j = j + 1
                    local hexSrgb <const> = hexesSrgb[j]
                    local xi = 0
                    local yi = size
                    local stroke = 0x0
                    if (hexSrgb & 0xff000000) ~= 0 then
                        plotIsValid = true
                        local lch <const> = sRgbToLch(fromHex(hexSrgb))

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

                        if lch.l > 50.0 then
                            stroke = 0xff000000
                        else
                            stroke = 0xffffffff
                        end
                    end

                    strokes[j] = stroke
                    xs[j] = xi
                    ys[j] = yi
                end -- End swatches loop
            end     -- End plot palette
        else
            gamutLayerName = string.format(
                "Lightness Sectors %d Rings %d",
                sectorCount, ringCount)

            local minLight <const> = args.minLight
                or defaults.minLight --[[@as integer]]
            local maxLight <const> = args.maxLight
                or defaults.maxLight --[[@as integer]]

            local srMaxChroma <const> = Lab.SR_MAX_CHROMA
            local azimAlpha <const> = sectorCount / 1.0
            local azimBeta <const> = quantAzims
                and 1.0 / sectorCount
                or 0.0
            local radAlpha <const> = ringCount / srMaxChroma
            local radBeta <const> = quantRad
                and srMaxChroma / ringCount
                or 0.0

            local idxFrame = 0
            while idxFrame < reqFrames do
                local frameStep <const> = idxFrame * frameToStep
                local light <const> = (1.0 - frameStep) * minLight
                    + frameStep * maxLight

                ---@type string[]
                local pixels <const> = {}
                local j = 0
                while j < szSq do
                    local y <const> = j // size
                    local yNrm <const> = y * szInv
                    local ySgn <const> = 1.0 - (yNrm + yNrm)
                    local b <const> = ySgn * srMaxChroma

                    local x <const> = j % size
                    local xNrm <const> = x * szInv
                    local xSgn <const> = xNrm + xNrm - 1.0
                    local a <const> = xSgn * srMaxChroma

                    local srgb = nil
                    local sqChroma <const> = a * a + b * b
                    if sqChroma > 0.0 then
                        local chroma = sqrt(sqChroma)
                        local hue = atan2(b, a) * 0.1591549430919

                        if quantRad then
                            chroma = floor(0.5 + chroma * radAlpha) * radBeta
                        end

                        if quantAzims then
                            hue = floor(0.5 + hue * azimAlpha) * azimBeta
                        end

                        srgb = lchTosRgb(light, chroma, hue, 1.0)
                    else
                        srgb = lchTosRgb(light, 0.0, 0.0, 1.0)
                    end

                    local r8 <const> = floor(min(max(srgb.r, 0.0), 1.0) * 255 + 0.5)
                    local g8 <const> = floor(min(max(srgb.g, 0.0), 1.0) * 255 + 0.5)
                    local b8 <const> = floor(min(max(srgb.b, 0.0), 1.0) * 255 + 0.5)
                    local a8 <const> = rgbIsInGamut(srgb, gamutTol)
                        and 255
                        or outOfGamut

                    j = j + 1
                    pixels[j] = strpack("B B B B", r8, g8, b8, a8)
                end

                local gamutImg <const> = Image(gamutSpec)
                gamutImg.bytes = tconcat(pixels)
                gamutImgs[1 + idxFrame] = gamutImg

                local celColor <const> = rgbToAseColor(
                    lchTosRgb(light, 0.0, 0.0, 1.0))
                celColors[1 + idxFrame] = celColor

                idxFrame = idxFrame + 1
            end -- End frame loop

            if plotPalette then
                local invMaxChroma <const> = 0.5 / srMaxChroma
                local center <const> = size // 2

                local j = 0
                while j < lenHexesSrgb do
                    j = j + 1
                    local hexSrgb <const> = hexesSrgb[j]
                    local xi = center
                    local yi = center
                    local stroke = 0x0
                    if hexSrgb & 0xff000000 ~= 0 then
                        plotIsValid = true
                        local lab <const> = sRgbToLab(fromHex(hexSrgb))

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

                        if lab.l > 50.0 then
                            stroke = 0xff000000
                        else
                            stroke = 0xffffffff
                        end
                    end

                    strokes[j] = stroke
                    xs[j] = xi
                    ys[j] = yi
                end -- End swatches loop
            end     -- End plot palette
        end         -- End axis preset

        -- Create frames.
        local oldFrameLen <const> = #sprite.frames
        local needed <const> = math.max(0, reqFrames - oldFrameLen)
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
        gamutLayer.name = gamutLayerName

        -- Create gamut layer cels.
        app.transaction("New Cels", function()
            local spriteFrames <const> = sprite.frames
            local idxCel = 0
            while idxCel < reqFrames do
                idxCel = idxCel + 1
                local gamutCel <const> = sprite:newCel(
                    gamutLayer,
                    spriteFrames[idxCel],
                    gamutImgs[idxCel])
                gamutCel.color = celColors[idxCel]
            end
        end)

        if plotPalette and plotIsValid then
            if yMax == yMin then
                yMax = size
                yMin = 0
            end

            if xMax == xMin then
                xMax = size
                xMin = 0
            end

            local xTlPlot <const> = 1 + xMin - strokeSize
            local yTlPlot <const> = 1 + yMin - strokeSize
            local wPlot <const> = (xMax - xMin) + stroke2 - 1
            local hPlot <const> = (yMax - yMin) + stroke2 - 1

            local plotSpec <const> = AseUtilities.createSpec(
                wPlot, hPlot,
                gamutSpec.colorMode,
                gamutSpec.colorSpace,
                gamutSpec.transparentColor)
            local plotImg <const> = Image(plotSpec)

            local plotCtx <const> = plotImg.context
            if plotCtx then
                plotCtx.antialias = false
                plotCtx.blendMode = BlendMode.NORMAL
                local drawEllipse <const> = ShapeUtilities.drawEllipse
                local hexToColor <const> = AseUtilities.hexToAseColor

                local k = 0
                while k < lenHexesSrgb do
                    k = k + 1
                    local hexSrgb <const> = hexesSrgb[k]
                    local xc <const> = xs[k] - xTlPlot
                    local yc <const> = ys[k] - yTlPlot
                    drawEllipse(plotCtx,
                        xc, yc, fillSize, fillSize,
                        true, hexToColor(hexSrgb),
                        true, hexToColor(strokes[k]), strokeWeight,
                        false)
                end -- End draw swatch loop.

                local plotPalLayer <const> = sprite:newLayer()
                plotPalLayer.name = "Palette"

                app.transaction("Plot Palette", function()
                    AseUtilities.createCels(
                        sprite,
                        1, reqFrames,
                        plotPalLayer.stackIndex, 1,
                        plotImg, Point(xTlPlot, xTlPlot), 0x0)
                end)
            end -- End drawing canvas exists.

            -- This needs to be done at the very end because
            -- prependMask modifies hexesProfile.
            Utilities.prependMask(hexesProfile)
            AseUtilities.setPalette(hexesProfile, sprite, 1)
        end -- End valid plot

        app.frame = plotIsPolar
            and sprite.frames[math.ceil(#sprite.frames / 2)]
            or sprite.frames[1]
        app.layer = gamutLayer
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