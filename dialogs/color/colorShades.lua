dofile("../../support/aseutilities.lua")

local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }

local defaults = {
    size = 256,
    frames = 32,
    fps = 24,
    outOfGamut = 64,
    quantization = 0,
    maxChroma = 135,
    maxLight = 100.0,
    plotPalette = true,
    palType = "ACTIVE",
    palStart = 0,
    palCount = 256,
    strokeSize = 6,
    fillSize = 5,
    pullFocus = false
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
        local args = dlg.data

        -- Cache methods
        local trunc = math.tointeger
        local drawCircleFill = AseUtilities.drawCircleFill

        -- Unpack arguments.
        local maxChroma = args.maxChroma or defaults.maxChroma
        local maxLight = args.maxLight or defaults.maxLight
        local outOfGamut = args.outOfGamut or defaults.outOfGamut

        -- Must be done before a new sprite is created.
        local hexesSrgb = {}
        local hexesProfile = {}
        local plotPalette = args.plotPalette
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

        -- Create sprite.
        local size = args.size
        local szInv = 1.0 / size
        local sprite = Sprite(size, size)
        sprite.filename = "LCh Color Shades"
        sprite:assignColorSpace(ColorSpace { sRGB = true })

        -- Calculate frame count to normalization.
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then
            -- Because hue is periodic, don't subtract 1.
            iToStep = 1.0 / reqFrames
        end

        local gamutImgs = {}
        local oogaNorm = outOfGamut * 0.00392156862745098
        local oogaEps = 2.0 * 0.00392156862745098
        local quantization = args.quantization or defaults.quantization
        for i = 1, reqFrames, 1 do
            -- Convert i to a step, which will be its hue.
            local iStep = (i - 1.0) * iToStep
            local hue = iStep

            local gamutImg = Image(size, size)
            local pxItr = gamutImg:pixels()
            for elm in pxItr do

                -- Convert coordinates from [0, size] to
                -- [0.0, 1.0], then to CIE LCH.
                local x = elm.x
                local xNrm = x * szInv
                xNrm = Utilities.quantizeUnsigned(xNrm, quantization)
                local chroma = xNrm * maxChroma

                local y = elm.y
                local yNrm = y * szInv
                yNrm = Utilities.quantizeUnsigned(yNrm, quantization)
                local light = (1.0 - yNrm) * maxLight

                local clr = Clr.lchTosRgba(light, chroma, hue, 1.0)
                if not Clr.rgbIsInGamut(clr, oogaEps) then
                    clr.a = oogaNorm
                end

                elm(Clr.toHex(clr))
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
            local plotImage = Image(size, size)
            local hexesSrgbLen = #hexesSrgb
            local invMaxChroma = 1.0 / maxChroma
            local invMaxLight = 1.0 / maxLight
            local strokeSize = args.strokeSize or defaults.strokeSize
            local fillSize = args.fillSize or defaults.fillSize
            local strokeColor = 0xffffffff
            for j = 1, hexesSrgbLen, 1 do
                local hexSrgb = hexesSrgb[j]
                if hexSrgb & 0xff000000 ~= 0 then
                    local lch = Clr.sRgbaToLch(Clr.fromHex(hexSrgb))

                    -- To [0.0, 1.0].
                    local xNrm = lch.c * invMaxChroma
                    local yNrm = 1.0 - (lch.l * invMaxLight)

                    -- From [0.0, 1.0] to [0, size].
                    local xPx = xNrm * size
                    local yPx = yNrm * size

                    local xi = trunc(0.5 + xPx)
                    local yi = trunc(0.5 + yPx)

                    local hexProfile = hexesProfile[j]
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
                plotImage)

            -- This needs to be done at the very end because
            -- prependMask modifies hexesProfile.
            Utilities.prependMask(hexesProfile)
            sprite:setPalette(
                AseUtilities.hexArrToAsePalette(hexesProfile))
        end

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