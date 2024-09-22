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
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    pullFocus = true,
    gamutTol = 0.001
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
    id = "plotPalette",
    label = "Plot:",
    text = "Palette",
    selected = defaults.plotPalette,
    onclick = function()
        local args <const> = dlg.data
        local usePlot <const> = args.plotPalette --[[@as boolean]]
        local palType <const> = args.palType --[[@as string]]
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
        local state <const> = dlg.data.palType --[[@as string]]
        dlg:modify { id = "palFile", visible = state == "FILE" }
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
        local min <const> = math.min
        local max <const> = math.max
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local fromHex <const> = Clr.fromHexAbgr32
        local labTosRgba <const> = Clr.srLab2TosRgb
        local lchTosRgba <const> = Clr.srLchTosRgb
        local rgbIsInGamut <const> = Clr.rgbIsInGamut
        local sRgbaToLab <const> = Clr.sRgbToSrLab2

        local drawCircleFill <const> = AseUtilities.drawCircleFill
        local setPixels <const> = AseUtilities.setPixels

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
            end
        end

        -- Quantization calculations.
        local quantAzims <const> = sectorCount > 0
        local quantRad <const> = ringCount > 0
        local maxChroma <const> = Clr.SR_LCH_MAX_CHROMA
        local gamutTol <const> = defaults.gamutTol

        -- Depending on case, may be hue, radians or degrees.
        local azimAlpha <const> = sectorCount / 1.0
        local azimBeta <const> = quantAzims and 1.0 / sectorCount or 0.0
        local radAlpha <const> = ringCount / maxChroma
        local radBeta <const> = quantRad and maxChroma / ringCount or 0.0
        local szInv <const> = size ~= 0.0 and 1.0 / size or 0.0
        local szSq <const> = size * size

        -- Create sprite.
        local spec <const> = AseUtilities.createSpec(size, size)
        local sprite <const> = AseUtilities.createSprite(spec, "LCH Wheel")

        local reqFrames <const> = args.frames
            or defaults.frames --[[@as integer]]
        local iToStep <const> = reqFrames > 1
            and 1.0 / (reqFrames - 1.0) or 0.5

        ---@type Image[]
        local gamutImgs <const> = {}

        local idxFrame = 0
        while idxFrame < reqFrames do
            local iStep <const> = idxFrame * iToStep
            local light <const> = (1.0 - iStep) * minLight + iStep * maxLight

            ---@type string[]
            local pixels <const> = {}
            local j = 0
            while j < szSq do
                local y <const> = j // size
                local yNrm <const> = y * szInv
                local ySgn <const> = 1.0 - (yNrm + yNrm)
                local b <const> = ySgn * maxChroma

                local x <const> = j % size
                local xNrm <const> = x * szInv
                local xSgn <const> = xNrm + xNrm - 1.0
                local a <const> = xSgn * maxChroma

                local srgb = nil
                local csq <const> = a * a + b * b
                if csq > 0.0 then
                    local c = sqrt(csq)
                    local h = atan2(b, a) * 0.1591549430919

                    if quantRad then
                        c = floor(0.5 + c * radAlpha) * radBeta
                    end

                    if quantAzims then
                        h = floor(0.5 + h * azimAlpha) * azimBeta
                    end

                    srgb = lchTosRgba(light, c, h, 1.0)
                else
                    srgb = labTosRgba(light, 0.0, 0.0, 1.0)
                end

                local r8 <const> = floor(min(max(srgb.r, 0.0), 1.0) * 255 + 0.5)
                local g8 <const> = floor(min(max(srgb.g, 0.0), 1.0) * 255 + 0.5)
                local b8 <const> = floor(min(max(srgb.b, 0.0), 1.0) * 255 + 0.5)
                local a8 <const> = rgbIsInGamut(srgb, gamutTol) and 255 or outOfGamut

                j = j + 1
                pixels[j] = strpack("B B B B", r8, g8, b8, a8)
            end

            local gamutImg <const> = Image(spec)
            gamutImg.bytes = tconcat(pixels)
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
                "Gamut Sectors %d Rings %d",
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
            local g = 0
            while g < lenPixels do
                g = g + 1
                plotPixels[g] = 0
            end

            local k = 0
            while k < lenHexesSrgb do
                k = k + 1
                local hexSrgb <const> = hexesSrgb[k]
                if (hexSrgb & 0xff000000) ~= 0 then
                    local xi <const> = xs[k] - xOff
                    local yi <const> = ys[k] - yOff
                    local hexProfile <const> = hexesProfile[k]
                    local strokeColor <const> = strokes[k]
                    drawCircleFill(plotPixels, wPlot, xi, yi, strokeSize,
                        strokeColor & 0xff,
                        (strokeColor >> 0x08) & 0xff,
                        (strokeColor >> 0x10) & 0xff,
                        255)
                    drawCircleFill(plotPixels, wPlot, xi, yi, fillSize,
                        hexProfile & 0xff,
                        (hexProfile >> 0x08) & 0xff,
                        (hexProfile >> 0x10) & 0xff,
                        255)
                end
            end

            setPixels(plotImage, plotPixels)
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

        app.frame = sprite.frames[math.ceil(#sprite.frames / 2)]
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