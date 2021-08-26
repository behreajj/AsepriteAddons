dofile("../../support/clr.lua")
dofile("../../support/utilities.lua")
dofile("../../support/aseutilities.lua")

local paletteTypes = { "ACTIVE", "DEFAULT", "FILE", "PRESET" }
local centers = { "ABSOLUTE", "RELATIVE" }

local defaults = {
    size = 256,
    minLight = 5,
    maxLight = 95,
    frames = 32,
    duration = 100,
    outOfGamut = 64,
    hueOverlay = true,
    offsetDeg = 40,
    ringCount = 1,
    sectorCount = 1,
    hueCenter = "ABSOLUTE",
    plotPalette = true,
    palType = "DEFAULT",
    palStart = 0,
    palCount = 256,
    pullFocus = false
}

local dlg = Dialog {
    title = "Color Wheel"
}

dlg:newrow { always = false }

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

dlg:number {
    id = "duration",
    label = "Duration:",
    text = string.format("%.1f", defaults.duration),
    decimals = 1
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
    id = "hueOverlay",
    label = "Overlay:",
    selected = defaults.hueOverlay,
    onclick = function()
        local args = dlg.data
        local overlay = args.hueOverlay
        dlg:modify { id = "ringCount", visible = overlay }
        dlg:modify { id = "sectorCount", visible = overlay }
        dlg:modify { id = "hueCenter", visible = overlay }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings",
    min = 1,
    max = 16,
    value = defaults.ringCount,
    visible = defaults.hueOverlay
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectorCount",
    label = "Sectors",
    min = 0,
    max = 16,
    value = defaults.sectorCount,
    visible = defaults.hueOverlay
}

dlg:newrow { always = false }

dlg:combobox {
    id = "hueCenter",
    label = "Center:",
    option = defaults.hueCenter,
    options = centers,
    visible = defaults.hueOverlay
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
    filetypes = { "aseprite", "gpl", "pal", "png" },
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

        -- Cache methods.
        local cos = math.cos
        local sin = math.sin
        local sqrt = math.sqrt
        local trunc = math.tointeger
        local labTosRgba = Clr.labTosRgba
        local rgbIsInGamut = Clr.rgbIsInGamut
        local toHex = Clr.toHex
        local fromHex = Clr.fromHex
        local sRgbaToLab = Clr.sRgbaToLab
        local drawCircleFill = AseUtilities.drawCircleFill

        -- Create sprite.
        local size = args.size
        local xAbsCenter = trunc(0.5 + size * 0.5)
        local yAbsCenter = trunc(0.5 + size * 0.5)
        local sprite = Sprite(size, size)
        sprite.filename = "LCh Color Wheel"
        sprite:assignColorSpace(ColorSpace { sRGB = true })

        -- Create color field images.
        local gamutImgs = {}
        local xRelCenters = {}
        local yRelCenters = {}
        local fixedRads = {}
        local movingRads = {}
        local szInv = 1.0 / size
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end
        local minLight = args.minLight or defaults.minLight
        local maxLight = args.maxLight or defaults.maxLight
        local outOfGamut = args.outOfGamut or defaults.outOfGamut
        local oogamask = outOfGamut << 0x18
        for i = 1, reqFrames, 1 do

            -- Cache extrema so as to find relative center.
            local xMin = 999999
            local yMin = 999999
            local xMax = -999999
            local yMax = -999999
            local xSum = 0
            local ySum = 0
            local validCount = 0
            local xsValid = {}
            local ysValid = {}

            local gamutImg = Image(size, size)
            local pxItr = gamutImg:pixels()
            for elm in pxItr do

                -- Convert coordinates from [0, size] to
                -- [0.0, 1.0], then to [-1.0, 1.0], then
                -- to CIE LAB range [-110.0, 110.0].
                local x = elm.x
                local xNrm = x * szInv
                local xSgn = xNrm + xNrm - 1.0

                local y = elm.y
                local yNrm = y * szInv
                local ySgn = 1.0 - (yNrm + yNrm)

                -- Convert i to a step, then lerp from
                -- minimum light to maximum light.
                local t = (i - 1.0) * iToStep
                local light = (1.0 - t) * minLight + t * maxLight
                local clr = labTosRgba(
                    light,
                    xSgn * 110.0,
                    ySgn * 110.0,
                    1.0)
                local hex = toHex(clr)

                -- If color is within SRGB gamut, then display
                -- at full opacity; otherwise display at reduced
                -- alpha. Find the valid boundary of the gamut.
                if rgbIsInGamut(clr) then
                    elm(hex)

                    if x < xMin then xMin = x end
                    if x > xMax then xMax = x end
                    if y < yMin then yMin = y end
                    if y > yMax then yMax = y end

                    xSum = xSum + x
                    ySum = ySum + y

                    validCount = validCount + 1
                    xsValid[validCount] = x
                    ysValid[validCount] = y
                else
                    elm(oogamask | (hex & 0x00ffffff))
                end
            end

            local xRelCenter = xAbsCenter
            local yRelCenter = yAbsCenter
            local movingRad = 2
            local fixedRad = 2
            if validCount > 0 then
                local invValCount = 1.0 / validCount
                xRelCenter = xSum * invValCount
                yRelCenter = ySum * invValCount
                local movingBrSq = -999999
                local fixedBrSq = -999999

                for j = 1, validCount, 1 do
                    local xCurr = xsValid[j]
                    local yCurr = ysValid[j]

                    -- Find difference from point to relative center.
                    local xDiffRel = xCurr - xRelCenter
                    local yDiffRel = yCurr - yRelCenter
                    local distSqRel = xDiffRel * xDiffRel
                        + yDiffRel * yDiffRel
                    if distSqRel > movingBrSq then
                        movingBrSq = distSqRel
                    end

                    -- Find difference from point to fixed center.
                    local xDiffAbs = xCurr - xAbsCenter
                    local yDiffAbs = yCurr - yAbsCenter
                    local distSqFixed = xDiffAbs * xDiffAbs
                        + yDiffAbs * yDiffAbs
                    if distSqFixed > fixedBrSq then
                        fixedBrSq = distSqFixed
                    end
                end

                movingRad = sqrt(movingBrSq)
                fixedRad = sqrt(fixedBrSq)
            end

            xRelCenters[i] = xRelCenter
            yRelCenters[i] = yRelCenter
            fixedRads[i] = fixedRad
            movingRads[i] = movingRad
            gamutImgs[i] = gamutImg
        end

        -- Create frames.
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local duration = args.duration or defaults.duration
        duration = duration * 0.001
        sprite.frames[1].duration = duration
        app.transaction(function()
            for _ = 1, needed, 1 do
                local frame = sprite:newEmptyFrame()
                frame.duration = duration
            end
        end)

        -- Set first layer to gamut.
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

        local hueOverlay = args.hueOverlay
        if hueOverlay then

            local hueOverlayLayer = sprite:newLayer()
            hueOverlayLayer.name = "Overlay"

            -- Create gamut layer cels first, as this needs
            -- to be done with app.useTool.
            local overlayCels = {}
            app.transaction(function()
                for i = 1, reqFrames, 1 do
                    overlayCels[i] = sprite:newCel(
                        hueOverlayLayer,
                        sprite.frames[i])
                end
            end)

            local ringCount = args.ringCount or defaults.ringCount
            local sectorCount = args.sectorCount or defaults.sectorCount
            local centerPreset = args.hueCenter or defaults.hueCenter
            local isRelative = centerPreset == "RELATIVE"
            local overlayHex = 0xafffffff
            local offsetDeg = 0.0
            if not isRelative then
                offsetDeg = args.offsetDeg or defaults.offsetDeg
            end
            local offsetRad = math.rad(offsetDeg)

            local overlayAseClr = Color(overlayHex)
            local overlayBrush = Brush(1)
            local reticuleBrush = Brush(3)

            app.transaction( function()
                for i = 1, reqFrames, 1 do
                    local xCenter = xAbsCenter
                    local yCenter = yAbsCenter
                    local maxRadius = 2
                    if isRelative then
                        xCenter = xRelCenters[i]
                        yCenter = yRelCenters[i]
                        maxRadius = movingRads[i]
                    else
                        maxRadius = fixedRads[i]
                    end

                    local overCel = overlayCels[i]
                    local currFrame = sprite.frames[i]

                    if ringCount > 1 then
                        -- local jToPercent = 1.0 / ringCount
                        local jToRadius = maxRadius / ringCount
                        for j = 1, ringCount, 1 do
                            -- local t = j * jToPercent
                            -- local rad = maxRadius * t
                            local rad = j * jToRadius
                            app.useTool {
                                tool = "ellipse",
                                color = overlayAseClr,
                                brush = overlayBrush,
                                points = {
                                    Point(
                                        xCenter - rad,
                                        yCenter + rad),
                                    Point(
                                        xCenter + rad,
                                        yCenter - rad) },
                                cel = overCel,
                                frame = currFrame,
                                layer = hueOverlayLayer
                            }
                        end
                    else
                        app.useTool {
                            tool = "ellipse",
                            color = overlayAseClr,
                            brush = overlayBrush,
                            points = {
                                Point(
                                    xCenter - maxRadius,
                                    yCenter + maxRadius),
                                Point(
                                    xCenter + maxRadius,
                                    yCenter - maxRadius) },
                            cel = overCel,
                            frame = currFrame,
                            layer = hueOverlayLayer
                        }
                    end

                    local centerPoint = Point(xCenter, yCenter)
                    if sectorCount > 0 then
                        local jToTheta = 6.283185307179586 / sectorCount
                        for j = 0, sectorCount - 1, 1 do
                            local theta = offsetRad + j * jToTheta
                            local cosTheta = cos(theta)
                            local sinTheta = sin(theta)

                            app.useTool {
                                tool = "line",
                                color = overlayAseClr,
                                brush = overlayBrush,
                                points = {
                                    centerPoint,
                                    Point(
                                        xCenter + maxRadius * cosTheta,
                                        yCenter - maxRadius * sinTheta) },
                                cel = overCel,
                                frame = currFrame,
                                layer = hueOverlayLayer
                            }
                        end
                    else
                        app.useTool {
                            tool = "pencil",
                            color = overlayAseClr,
                            brush = reticuleBrush,
                            points = { centerPoint },
                            cel = overCel,
                            frame = currFrame,
                            layer = hueOverlayLayer
                        }
                    end
                end
            end)
        end

        local plotPalette = args.plotPalette or defaults.plotPalette
        if plotPalette then

            local palType = args.palType or defaults.palType
            local hexesSrgb = {}
            local hexesProfile = {}

            if palType ~= "DEFAULT" then
                local palFile = args.palFile
                local palPreset = args.palPreset
                local palStart = args.palStart or defaults.palStart
                local palCount = args.palCount or defaults.palCount

                hexesSrgb, hexesProfile = AseUtilities.asePaletteLoad(
                    palType, palFile, palPreset, palStart, palCount, true)

                -- Check for a valid alpha mask at index 0.
                if hexesProfile[1] ~= 0x0 then
                    table.insert(hexesProfile, 1, 0x0)
                end

                if hexesSrgb[1] ~= 0x0 then
                    table.insert(hexesSrgb, 1, 0x0)
                end
            else
                -- Since a palette will be created immediately after, pbr.
                -- If this changes, and arrays are modified, then this
                -- will need to be a copy.
                hexesProfile = AseUtilities.DEFAULT_PAL_ARR
                hexesSrgb = hexesProfile
            end

            sprite:setPalette(
                AseUtilities.hexArrToAsePalette(hexesProfile))

            local plotImage = Image(size, size)
            local hexesSrgbLen = #hexesSrgb
            local inv110 = 1.0 / 110.0
            local strokeSize = 6
            local fillSize = 5
            local strokeColor = 0xcfffffff
            for j = 1, hexesSrgbLen, 1 do
                local hex = hexesSrgb[j]
                local lab = sRgbaToLab(fromHex(hex))
                -- labs[i] = lab

                -- From [-110.0, 110.0] To [-1.0, 1.0].
                local xSgn = lab.a * inv110
                local ySgn = lab.b * inv110

                -- From [-1.0, 1.0] to [0.0, 1.0].
                local xNrm = xSgn * 0.5 + 0.5
                local yNrm = 0.5 - ySgn * 0.5

                -- From [0.0, 1.0] to [0, size].
                local xPx = xNrm * size
                local yPx = yNrm * size

                local xi = trunc(0.5 + xPx)
                local yi = trunc(0.5 + yPx)

                drawCircleFill(plotImage, xi, yi, strokeSize, strokeColor)
                drawCircleFill(plotImage, xi, yi, fillSize, hex)
            end

            local plotPalLayer = sprite:newLayer()
            plotPalLayer.name = "Palette"

            local palCels = {}
            app.transaction(function()
                for i = 1, reqFrames, 1 do
                    palCels[i] = sprite:newCel(
                        plotPalLayer,
                        sprite.frames[i],
                        plotImage)
                end
            end)
        end

        app.activeFrame = sprite.frames[
            math.max(1, #sprite.frames // 2)]
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