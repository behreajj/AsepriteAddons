dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local edgeTypes <const> = { "CLAMP", "OMIT", "WRAP" }
local interTypes <const> = { "HORIZONTAL", "VERTICAL" }
local waveTypes <const> = { "BILINEAR", "GERSTNER", "INTERLACED", "RADIAL" }

local defaults <const> = {
    target = "ACTIVE",
    frameCount = 8,
    fps = 24,
    edgeType = "OMIT",
    waveType = "RADIAL",
    timeOffset = -90,
    timeScalar = 1,
    spaceScalar = 3,
    -- Radial
    xCenter = 50,
    yCenter = 50,
    uDisplaceOrig = 5,
    uDisplaceDest = 5,
    sustain = 25,
    warp = 0,
    -- Bilinear
    xDisplaceOrig = 5,
    yDisplaceOrig = 5,
    xDisplaceDest = 5,
    yDisplaceDest = 5,
    -- xSustain = 100,
    ySustain = 100,
    -- Interlaced
    interType = "HORIZONTAL",
    interOffOrig = 180,
    interOffDest = 180,
    interSkip = 1,
    interPick = 1,
    -- Gerstner
    gerstItrs = 3,
    gerstWaveLen = 0.3,
    gerstSteep = 0.375,
    gerstSpeed = 1.0,
    gerstAngle = 90,
    gravity = 9.81,

    printElapsed = false
}

local dlg <const> = Dialog { title = "Wave" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local isActive <const> = target == "ACTIVE"
        dlg:modify { id = "frameCount", visible = isActive }
        dlg:modify { id = "fps", visible = isActive }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "frameCount",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frameCount,
    visible = defaults.target == "ACTIVE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "fps",
    label = "FPS:",
    min = 1,
    max = 50,
    value = defaults.fps,
    visible = defaults.target == "ACTIVE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "edgeType",
    label = "Edges:",
    option = defaults.edgeType,
    options = edgeTypes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "waveType",
    label = "Type:",
    option = defaults.waveType,
    options = waveTypes,
    onchange = function()
        local args <const> = dlg.data
        local waveType <const> = args.waveType --[[@as string]]
        local interType <const> = args.interType --[[@as string]]

        local isInter <const> = waveType == "INTERLACED"
        local isBilinear <const> = waveType == "BILINEAR"
        local isRadial <const> = waveType == "RADIAL"
        local isGerst <const> = waveType == "GERSTNER"

        dlg:modify { id = "spaceScalar", visible = not isGerst }
        dlg:modify { id = "timeScalar", visible = not isGerst }

        dlg:modify { id = "xCenter", visible = isRadial or isBilinear }
        dlg:modify { id = "yCenter", visible = isRadial or isBilinear }
        dlg:modify { id = "uDisplaceOrig", visible = isRadial }
        dlg:modify { id = "uDisplaceDest", visible = isRadial }
        dlg:modify { id = "sustain", visible = isRadial }
        dlg:modify { id = "warp", visible = isRadial }

        -- dlg:modify { id = "xSustain", visible = isBilinear }
        dlg:modify { id = "ySustain", visible = isBilinear }

        dlg:modify { id = "interType", visible = isInter }
        dlg:modify { id = "interOffOrig", visible = isInter }
        dlg:modify { id = "interOffDest", visible = isInter }
        dlg:modify { id = "interSkip", visible = isInter }
        dlg:modify { id = "interPick", visible = isInter }

        dlg:modify { id = "gerstItrs", visible = isGerst }
        dlg:modify { id = "gerstWaveLen", visible = isGerst }
        dlg:modify { id = "gerstSteep", visible = isGerst }
        dlg:modify { id = "gerstSpeed", visible = isGerst }
        dlg:modify { id = "gerstAngle", visible = isGerst }

        local isHoriz <const> = interType == "HORIZONTAL"
        local isVert <const> = interType == "VERTICAL"

        dlg:modify {
            id = "xDisplaceOrig",
            visible = isBilinear or (isInter and isHoriz)
        }
        dlg:modify {
            id = "xDisplaceDest",
            visible = isBilinear or (isInter and isHoriz)
        }
        dlg:modify {
            id = "yDisplaceOrig",
            visible = isBilinear or (isInter and isVert)
        }
        dlg:modify {
            id = "yDisplaceDest",
            visible = isBilinear or (isInter and isVert)
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "spaceScalar",
    label = "Period:",
    min = 1,
    max = 10,
    value = defaults.spaceScalar,
    visible = defaults.waveType ~= "GERSTNER"
}

dlg:slider {
    id = "timeScalar",
    min = 1,
    max = 10,
    value = defaults.timeScalar,
    visible = defaults.waveType ~= "GERSTNER"
}

dlg:newrow { always = false }

dlg:slider {
    id = "xCenter",
    label = "Center %:",
    min = -100,
    max = 200,
    value = defaults.xCenter,
    visible = defaults.waveType == "RADIAL"
        or defaults.waveType == "BILINEAR"
}

dlg:slider {
    id = "yCenter",
    min = -100,
    max = 200,
    value = defaults.yCenter,
    visible = defaults.waveType == "RADIAL"
        or defaults.waveType == "BILINEAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "uDisplaceOrig",
    label = "Displace %:",
    min = 0,
    max = 100,
    value = defaults.uDisplaceOrig,
    visible = defaults.waveType == "RADIAL"
}

dlg:slider {
    id = "uDisplaceDest",
    min = 0,
    max = 100,
    value = defaults.uDisplaceDest,
    visible = defaults.waveType == "RADIAL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "sustain",
    label = "Sustain %:",
    min = 0,
    max = 100,
    value = defaults.sustain,
    visible = defaults.waveType == "RADIAL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "warp",
    label = "Warp:",
    min = 0,
    max = 360,
    value = defaults.warp,
    visible = defaults.waveType == "RADIAL"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "interType",
    label = "Orientation:",
    option = defaults.interType,
    options = interTypes,
    visible = defaults.waveType == "INTERLACED",
    onchange = function()
        local args <const> = dlg.data
        local interType <const> = args.interType --[[@as string]]

        local isHoriz <const> = interType == "HORIZONTAL"
        local isVert <const> = interType == "VERTICAL"
        dlg:modify { id = "xDisplaceOrig", visible = isHoriz }
        dlg:modify { id = "xDisplaceDest", visible = isHoriz }
        dlg:modify { id = "yDisplaceOrig", visible = isVert }
        dlg:modify { id = "yDisplaceDest", visible = isVert }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "xDisplaceOrig",
    label = "Displace X %:",
    min = 0,
    max = 100,
    value = defaults.xDisplaceOrig,
    visible = defaults.waveType == "BILINEAR"
        or (defaults.waveType == "INTERLACED"
            and defaults.interType == "HORIZONTAL")
}

dlg:slider {
    id = "xDisplaceDest",
    min = 0,
    max = 100,
    value = defaults.xDisplaceDest,
    visible = defaults.waveType == "BILINEAR"
        or (defaults.waveType == "INTERLACED"
            and defaults.interType == "HORIZONTAL")
}

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "xSustain",
--     label = "Sustain X %:",
--     min = 0,
--     max = 100,
--     value = defaults.xSustain,
--     visible = defaults.waveType == "BILINEAR"
-- }

dlg:newrow { always = false }

dlg:slider {
    id = "yDisplaceOrig",
    label = "Displace Y %:",
    min = 0,
    max = 100,
    value = defaults.yDisplaceOrig,
    visible = defaults.waveType == "BILINEAR"
        or (defaults.waveType == "INTERLACED"
            and defaults.interType == "VERTICAL")
}

dlg:slider {
    id = "yDisplaceDest",
    min = 0,
    max = 100,
    value = defaults.yDisplaceDest,
    visible = defaults.waveType == "BILINEAR"
        or (defaults.waveType == "INTERLACED"
            and defaults.interType == "VERTICAL")
}

dlg:newrow { always = false }

dlg:slider {
    id = "ySustain",
    -- label = "Sustain Y %:",
    label = "Sustain %:",
    min = 0,
    max = 100,
    value = defaults.ySustain,
    visible = defaults.waveType == "BILINEAR"
}

dlg:slider {
    id = "interOffOrig",
    label = "Offset:",
    min = -180,
    max = 180,
    value = defaults.interOffOrig,
    visible = defaults.waveType == "INTERLACED"
}

dlg:slider {
    id = "interOffDest",
    min = -180,
    max = 180,
    value = defaults.interOffDest,
    visible = defaults.waveType == "INTERLACED"
}

dlg:newrow { always = false }

dlg:slider {
    id = "interSkip",
    label = "Skip:",
    min = 1,
    max = 8,
    value = defaults.interSkip,
    visible = defaults.waveType == "INTERLACED"
}

dlg:slider {
    id = "interPick",
    min = 1,
    max = 8,
    value = defaults.interPick,
    visible = defaults.waveType == "INTERLACED"
}

dlg:newrow { always = false }

dlg:slider {
    id = "gerstItrs",
    label = "Count:",
    min = 1,
    max = 5,
    value = defaults.gerstItrs,
    visible = defaults.waveType == "GERSTNER"
}

dlg:newrow { always = false }

dlg:number {
    id = "gerstWaveLen",
    label = "Wave Length:",
    text = string.format("%.3f", defaults.gerstWaveLen),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.waveType == "GERSTNER"
}

dlg:newrow { always = false }

dlg:number {
    id = "gerstSteep",
    label = "Steepness:",
    text = string.format("%.3f", defaults.gerstSteep),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.waveType == "GERSTNER"
}

dlg:newrow { always = false }

dlg:number {
    id = "gerstSpeed",
    label = "Speed:",
    text = string.format("%.3f", defaults.gerstSpeed),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    visible = defaults.waveType == "GERSTNER"
}

dlg:newrow { always = false }

dlg:slider {
    id = "gerstAngle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.gerstAngle,
    visible = defaults.waveType == "GERSTNER"
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- Begin timing the function elapsed.
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime <const> = os.clock()

        -- Early returns.
        local srcSprite <const> = app.site.sprite
        if not srcSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcSpec <const> = srcSprite.spec
        local colorMode <const> = srcSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Transfer grid from source to target sprite.
        local srcGrid <const> = srcSprite.gridBounds
        local wGrid <const> = math.max(1, math.abs(srcGrid.width))
        local hGrid <const> = math.max(1, math.abs(srcGrid.height))
        local xGrid <const> = srcGrid.x
        local yGrid <const> = srcGrid.y

        -- Cache palette, preserve fore and background.
        AseUtilities.preserveForeBack()
        local hexArr <const> = AseUtilities.asePalettesToHexArr(
            srcSprite.palettes)

        local target <const> = args.target
            or defaults.target --[[@as string]]
        local srcFrames <const> = srcSprite.frames
        local lenSrcFrames <const> = #srcFrames
        local isActive <const> = target == "ACTIVE"

        local selFrames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(srcSprite, target))

        local timeOffsetDeg <const> = defaults.timeOffset
        local timeOffset <const> = timeOffsetDeg * 0.017453292519943
        local timeScalar <const> = args.timeScalar
            or defaults.timeScalar --[[@as integer]]

        -- Flatten sprite to images, associate with a factor
        -- and an angle theta.

        -- TODO: Destructure this to an array of
        -- durations, images, factors, thetas?
        ---@type {duration: number, image: Image, fac: number, theta: number}[]
        local packets <const> = {}
        if isActive then
            local frameCount <const> = args.frameCount
                or defaults.frameCount --[[@as integer]]
            local fps <const> = args.fps
                or defaults.fps --[[@as integer]]

            local selImg <const> = Image(srcSpec)
            selImg:drawSprite(srcSprite, selFrames[1])

            local frameToFac = 0.0
            if frameCount > 1 then
                frameToFac = 1.0 / (frameCount - 1.0)
            end

            local frameToTheta = 0.0
            if frameCount > 0 then
                frameToTheta = timeScalar * 6.2831853071796 / frameCount
            end

            local duration = 1.0
            if fps > 1 then duration = 1.0 / fps end

            local j = 0
            while j < frameCount do
                local fac <const> = j * frameToFac
                local theta <const> = timeOffset + j * frameToTheta
                local packet <const> = {
                    duration = duration,
                    image = selImg,
                    fac = fac,
                    theta = theta
                }
                j = j + 1
                packets[j] = packet
            end
        else
            -- Should range give you the option to use
            -- DURATION based time or COUNT based time?
            -- If there's no room for that, check to see if
            -- range is contiguous (1,2,3,4) or not (1,5,3,10).

            ---@type number[]
            local timeStamps <const> = {}
            local totalDuration = 0.0
            local i = 0
            while i < lenSrcFrames do
                i = i + 1
                local srcFrame <const> = srcFrames[i]
                local duration <const> = srcFrame.duration
                timeStamps[i] = totalDuration
                totalDuration = totalDuration + duration
            end

            local timeToFac = 0.0
            local finalDuration <const> = timeStamps[lenSrcFrames]
            if finalDuration and finalDuration ~= 0.0 then
                timeToFac = 1.0 / finalDuration
            end

            local timeToTheta = 0.0
            if totalDuration > 0.0 then
                timeToTheta = timeScalar * 6.2831853071796 / totalDuration
            end

            local lenSelFrames <const> = #selFrames
            local j = 0
            while j < lenSelFrames do
                j = j + 1
                local selFrameIdx <const> = selFrames[j]
                local selFrameObj <const> = srcFrames[selFrameIdx]
                local selDuration <const> = selFrameObj.duration

                local selImg <const> = Image(srcSpec)
                selImg:drawSprite(srcSprite, selFrameIdx)

                local selTime <const> = timeStamps[selFrameIdx]
                local fac <const> = selTime * timeToFac
                local theta <const> = timeOffset + selTime * timeToTheta

                local packet <const> = {
                    duration = selDuration,
                    image = selImg,
                    fac = fac,
                    theta = theta
                }
                packets[j] = packet
            end
        end

        -- Cache methods.
        local abs <const> = math.abs
        local cos <const> = math.cos
        local sin <const> = math.sin
        local max <const> = math.max
        local min <const> = math.min
        local sqrt <const> = math.sqrt
        local strfmt <const> = string.format
        local transact <const> = app.transaction
        local tconcat <const> = table.concat
        local round <const> = Utilities.round
        local trimImage <const> = AseUtilities.trimImageAlpha

        local edgeType <const> = args.edgeType
            or defaults.edgeType --[[@as string]]
        local getPixel = Utilities.getPixelOmit
        if edgeType == "CLAMP" then
            getPixel = Utilities.getPixelClamp
        elseif edgeType == "WRAP" then
            getPixel = Utilities.getPixelWrap
        end

        local spaceScalar <const> = args.spaceScalar
            or defaults.spaceScalar --[[@as integer]]
        local waveType <const> = args.waveType
            or defaults.waveType --[[@as string]]

        local srcWidth <const> = srcSpec.width
        local srcHeight <const> = srcSpec.height
        local wn1 <const> = srcWidth - 1
        local hn1 <const> = srcHeight - 1

        ---@type fun(x: integer, y: integer, angle: number, t: number): number, number
        local eval = nil

        -- Determine which wave function the user wants.
        if waveType == "BILINEAR" then
            local xCenter <const> = args.xCenter
                or defaults.xCenter --[[@as integer]]
            local yCenter <const> = args.yCenter
                or defaults.yCenter --[[@as integer]]
            local pxxCenter <const> = xCenter * 0.01 * srcWidth
            local pxyCenter <const> = yCenter * 0.01 * srcHeight

            local maxChebyshev = 0.0
            if xCenter <= 0 or yCenter <= 0
                or xCenter >= 100 or yCenter >= 100 then
                maxChebyshev = max(wn1 * 2, hn1 * 2)
            else
                maxChebyshev = max(wn1, hn1)
            end
            local toFac = 0.0
            if maxChebyshev ~= 0.0 then toFac = 2.0 / maxChebyshev end

            -- Simplify UI by having only one sustain input slider,
            -- even though sustain per axis is possible.
            -- local xBaseSustain = args.xSustain or defaults.xSustain
            local yBaseSustain = args.ySustain or defaults.ySustain
            local xBaseSustain = yBaseSustain
            yBaseSustain = yBaseSustain * 0.01
            xBaseSustain = xBaseSustain * 0.01

            -- This was tested to make sure it tiles correctly.
            local xDisplaceOrig <const> = args.xDisplaceOrig
                or defaults.xDisplaceOrig --[[@as integer]]
            local xDisplaceDest <const> = args.xDisplaceDest
                or defaults.xDisplaceDest --[[@as integer]]
            local yDisplaceOrig <const> = args.yDisplaceOrig
                or defaults.yDisplaceOrig --[[@as integer]]
            local yDisplaceDest <const> = args.yDisplaceDest
                or defaults.yDisplaceDest --[[@as integer]]

            local pxxDisplaceOrig <const> = srcWidth * xDisplaceOrig * 0.005
            local pxxDisplaceDest <const> = srcWidth * xDisplaceDest * 0.005
            local pxyDisplaceOrig <const> = srcHeight * yDisplaceOrig * 0.005
            local pxyDisplaceDest <const> = srcHeight * yDisplaceDest * 0.005

            local xToTheta <const> = spaceScalar * 6.2831853071796 / srcWidth
            local yToTheta <const> = spaceScalar * 6.2831853071796 / srcHeight

            eval = function(x, y, angle, t)
                local dx <const> = x - pxxCenter
                local dy <const> = pxyCenter - y
                local fac = toFac * max(abs(dx), abs(dy))
                fac = min(max(fac, 0.0), 1.0)
                local xSst <const> = (1.0 - fac) + fac * xBaseSustain
                local ySst <const> = (1.0 - fac) + fac * yBaseSustain

                local u <const> = 1.0 - t
                local xDsplScl <const> = u * pxxDisplaceOrig
                    + t * pxxDisplaceDest
                local yDsplScl <const> = u * pxyDisplaceOrig
                    + t * pxyDisplaceDest

                local xTheta <const> = angle - x * xToTheta
                local yTheta <const> = angle + y * yToTheta
                local xWarp <const> = xDsplScl * xSst * sin(yTheta)
                local yWarp <const> = yDsplScl * ySst * cos(xTheta)
                return x + xWarp, y + yWarp
            end
        elseif waveType == "GERSTNER" then
            -- See:
            -- https://catlikecoding.com/unity/tutorials/flow/waves/
            -- https://en.wikipedia.org/wiki/Trochoidal_wave
            -- https://www.shadertoy.com/view/7djGRR
            -- https://www.youtube.com/watch?v=PH9q0HNBjT4

            local gerstItrs <const> = args.gerstItrs
                or defaults.gerstItrs --[[@as integer]]
            local gerstWaveLen <const> = args.gerstWaveLen
                or defaults.gerstWaveLen --[[@as number]]
            local gerstSteep <const> = args.gerstSteep
                or defaults.gerstSteep --[[@as number]]
            local gerstSpeed <const> = args.gerstSpeed
                or defaults.gerstSpeed --[[@as number]]
            local gerstAngle <const> = args.gerstAngle
                or defaults.gerstAngle --[[@as integer]]
            local gravity <const> = defaults.gravity

            ---@type Vec2[]
            local directions <const> = {}
            ---@type number[]
            local ks <const> = {}
            ---@type number[]
            local cs <const> = {}
            ---@type number[]
            local as <const> = {}

            -- Parameters per iteration. The first iteration
            -- is handled by the user, the rest are random.
            directions[1] = Vec2.fromPolar(
                0.017453292519943 * gerstAngle, 1.0)
            ks[1] = 6.2831853071796
            if gerstWaveLen ~= 0.0 then
                ks[1] = 6.2831853071796 / gerstWaveLen
            end
            cs[1] = math.sqrt(gravity / ks[1])
            as[1] = gerstSteep / ks[1]

            -- print(string.format(
            --     "direction: (%.6f, %.6f) mag: %.6f, waveLen: %.3f, steep: %.3f",
            --     directions[1].x, directions[1].y, Vec2.mag(directions[1]),
            --     gerstWaveLen, gerstSteep))

            -- Scale randomness by user input.
            --Add option for random seed input?
            local hToFac = 1.0 / gerstItrs
            local minSteep <const> = gerstSteep * 0.667
            local maxSteep <const> = gerstSteep * 1.5
            local minWaveLen <const> = gerstWaveLen * 0.5
            local maxWaveLen <const> = gerstWaveLen * 2.0

            local h = 1
            while h < gerstItrs do
                local hFac <const> = h * hToFac
                h = h + 1

                local x <const> = Utilities.gaussian()
                local y <const> = Utilities.gaussian()
                local sqMag <const> = x * x + y * y
                local xn = 0.0
                local yn = 1.0
                if sqMag > 0.0 then
                    local invMag <const> = 1.0 / sqrt(sqMag)
                    xn = x * invMag
                    yn = y * invMag
                end
                directions[h] = Vec2.new(xn, yn)

                local waveLenFac <const> = math.random()
                local waveLenRnd = (1.0 - waveLenFac) * minWaveLen
                    + waveLenFac * maxWaveLen
                waveLenRnd = (1.0 - hFac) * waveLenRnd

                local k <const> = 6.2831853071796 / waveLenRnd
                ks[h] = k
                cs[h] = sqrt(gravity / k)

                local steepFac <const> = math.random()
                local steepRnd = (1.0 - steepFac) * minSteep
                    + steepFac * maxSteep

                -- Make randomness less noticeable as iterations
                -- progress to simulate finer details.
                steepRnd = (1.0 - hFac) * steepRnd

                as[h] = steepRnd / k

                -- print(string.format(
                --     "direction: (%.6f, %.6f) mag: %.6f, waveLen: %.3f, steep: %.3f",
                --     directions[h].x, directions[h].y, Vec2.mag(directions[h]),
                --     waveLenRnd, steepRnd))
            end

            local aspect <const> = wn1 / hn1
            local wInv <const> = aspect / wn1
            local hInv <const> = 1.0 / hn1
            local wn1Aspect <const> = wn1 / aspect

            eval = function(x, y, angle, t)
                local tSpeed <const> = t * gerstSpeed
                local xSgn <const> = x * wInv * 2.0 - 1.0
                local ySgn <const> = y * hInv * 2.0 - 1.0
                local xSum = xSgn
                local ySum = ySgn
                local i = 0
                while i < gerstItrs do
                    i = i + 1
                    local k <const> = ks[i]
                    local c <const> = cs[i]
                    local a <const> = as[i]
                    local d <const> = directions[i]
                    local dotcod <const> = d.x * xSgn + d.y * ySgn
                    local f <const> = k * (dotcod - c * tSpeed)

                    -- cos(a) == cos(-a), sin(a) ~= sin(-a),
                    -- so prefer latter to flip y axis.
                    local asinf <const> = a * sin(f)
                    xSum = xSum + d.x * asinf
                    ySum = ySum - d.y * asinf
                end
                return (xSum * 0.5 + 0.5) * wn1Aspect,
                    (ySum * 0.5 + 0.5) * hn1
            end
        elseif waveType == "INTERLACED" then
            -- wn1 and hn1 work better for sprites with even width, height
            -- when converting to theta.
            local interType <const> = args.interType
                or defaults.interType --[[@as string]]
            local interOffOrig <const> = args.interOffOrig
                or defaults.interOffOrig --[[@as integer]]
            local interOffDest <const> = args.interOffDest
                or defaults.interOffDest --[[@as integer]]
            local skip <const> = args.interSkip
                or defaults.interSkip --[[@as integer]]
            local pick <const> = args.interPick
                or defaults.interPick --[[@as integer]]

            -- Pattern is sum of both on/off: e.g., 001110011100,
            -- pick 2 skip 3, is 5 total. Modulo all to repeat
            -- pattern, then check if lt pick.
            local all <const> = pick + skip
            local lacRadOrig <const> = 0.017453292519943 * interOffOrig
            local lacRadDest <const> = 0.017453292519943 * interOffDest

            if interType == "VERTICAL" then
                local yDisplaceOrig <const> = args.yDisplaceOrig
                    or defaults.yDisplaceOrig --[[@as integer]]
                local yDisplaceDest <const> = args.yDisplaceDest
                    or defaults.yDisplaceDest --[[@as integer]]
                local pxyDisplaceOrig <const> = srcWidth * yDisplaceOrig * 0.005
                local pxyDisplaceDest <const> = srcWidth * yDisplaceDest * 0.005

                local xToTheta = spaceScalar * 6.2831853071796
                if wn1 > 0 then
                    xToTheta = xToTheta / wn1
                end

                eval = function(x, y, angle, t)
                    local u <const> = 1.0 - t
                    local xTheta = angle + x * xToTheta
                    if x % all < pick then
                        local lacOrig <const> = u * lacRadOrig
                            + t * lacRadDest
                        xTheta = xTheta + lacOrig
                    end
                    local yDsplScl <const> = u * pxyDisplaceOrig
                        + t * pxyDisplaceDest
                    return x, y + yDsplScl * cos(xTheta)
                end
            else
                -- Default to horizontal.
                local xDisplaceOrig <const> = args.xDisplaceOrig
                    or defaults.xDisplaceOrig --[[@as integer]]
                local xDisplaceDest <const> = args.xDisplaceDest
                    or defaults.xDisplaceDest --[[@as integer]]
                local pxxDisplaceOrig <const> = srcHeight * xDisplaceOrig * 0.005
                local pxxDisplaceDest <const> = srcHeight * xDisplaceDest * 0.005

                local yToTheta = spaceScalar * 6.2831853071796
                if hn1 > 0 then
                    yToTheta = yToTheta / hn1
                end

                eval = function(x, y, angle, t)
                    local u <const> = 1.0 - t
                    local yTheta = angle + y * yToTheta
                    if y % all < pick then
                        local lacOrig <const> = u * lacRadOrig
                            + t * lacRadDest
                        yTheta = yTheta + lacOrig
                    end
                    local xDsplScl <const> = u * pxxDisplaceOrig
                        + t * pxxDisplaceDest
                    return x + xDsplScl * sin(yTheta), y
                end
            end
        else
            -- Default to radial wave.
            local xCenter <const> = args.xCenter
                or defaults.xCenter --[[@as integer]]
            local yCenter <const> = args.yCenter
                or defaults.yCenter --[[@as integer]]
            local uDisplaceOrig <const> = args.uDisplaceOrig
                or defaults.uDisplaceOrig --[[@as integer]]
            local uDisplaceDest <const> = args.uDisplaceDest
                or defaults.uDisplaceDest --[[@as integer]]
            local sustain <const> = args.sustain
                or defaults.sustain --[[@as integer]]
            local warp <const> = args.warp
                or defaults.warp --[[@as integer]]

            -- Working on what would be most intuitive.
            local maxDist = 0.0
            local distToFac = 0.0
            local shortEdge <const> = min(srcWidth, srcHeight)
            if yCenter <= -50 or yCenter >= 150
                or xCenter <= -50 or xCenter >= 150 then
                local se3 <const> = shortEdge * 3
                maxDist = sqrt(se3 * se3 + se3 * se3)
                if maxDist ~= 0.0 then
                    distToFac = 2.8284 / maxDist
                end
            elseif yCenter <= 0 or yCenter >= 100
                or xCenter <= 0 or xCenter >= 100 then
                local se2 <const> = shortEdge * 2
                maxDist = sqrt(se2 * se2 + se2 * se2)
                if maxDist ~= 0.0 then
                    distToFac = 2.8284 / maxDist
                end
            else
                maxDist = sqrt(shortEdge * shortEdge
                    + shortEdge * shortEdge)
                if maxDist ~= 0.0 then
                    distToFac = 2.0 / maxDist
                end
            end

            local pxxCenter <const> = wn1 * xCenter * 0.01
            local pxyCenter <const> = hn1 * yCenter * 0.01
            local pxuDisplaceOrig <const> = maxDist * uDisplaceOrig * 0.005
            local pxuDisplaceDest <const> = maxDist * uDisplaceDest * 0.005

            local distToTheta <const> = spaceScalar * 6.2831853071796 / maxDist
            local sustFac <const> = sustain * 0.01
            local warpRad <const> = warp * 0.017453292519943
            local cosWarp <const> = cos(warpRad)
            local sinWarp <const> = sin(warpRad)

            eval = function(x, y, angle, t)
                local ax <const> = x - pxxCenter
                local ay <const> = y - pxyCenter
                local dSq <const> = ax * ax + ay * ay

                -- Normalize distance from center to point
                -- to get displacement direction.
                local nx = 0.0
                local ny = 0.0
                local d = 0.0
                if dSq > 1.414 then
                    d = sqrt(dSq)
                    nx = ax / d
                    ny = ay / d
                end

                -- Dminish displacement scale over space.
                -- Because center could be outside of canvas,
                -- this needs to be clamped to [0.0, 1.0].
                local fac <const> = min(max(d * distToFac, 0.0), 1.0)
                local falloff <const> = (1.0 - fac) + fac * sustFac

                -- Subtract space angle from time angle.
                -- Use - instead of + to make wave head
                -- away from the center instead of toward.
                local theta <const> = angle - d * distToTheta

                -- Diminish displacement scale over time.
                local uDsplScl <const> = (1.0 - t) * pxuDisplaceOrig
                    + t * pxuDisplaceDest

                -- Rescale displacement vector by falloff.
                local offset <const> = falloff * uDsplScl * sin(theta)
                local xOff <const> = nx * offset
                local yOff <const> = ny * offset

                -- Rotate displacement vector by warp.
                local xWarp <const> = cosWarp * xOff - sinWarp * yOff
                local yWarp <const> = cosWarp * yOff + sinWarp * xOff

                return x + xWarp, y + yWarp
            end
        end

        -- Create wave images from packet data.
        ---@type Image[]
        local trgImages <const> = {}
        local lenPackets <const> = #packets
        local alphaIndex <const> = srcSpec.transparentColor < 256
            and srcSpec.transparentColor
            or 0
        local h = 0
        while h < lenPackets do
            h = h + 1
            local packet <const> = packets[h]
            local fac <const> = packet.fac
            local theta <const> = packet.theta
            local srcImg <const> = packet.image

            local srcBytes <const> = srcImg.bytes
            local srcBpp <const> = srcImg.bytesPerPixel
            local pxAlpha <const> = string.pack(
                "<I" .. srcBpp, alphaIndex)

            local wSrc <const> = srcImg.width
            local hSrc <const> = srcImg.height
            local lenFlat <const> = wSrc * hSrc

            ---@type string[]
            local byteArr <const> = {}
            local i = 0
            while i < lenFlat do
                local x <const> = i % wSrc
                local y <const> = i // wSrc
                local xp, yp = eval(x, y, theta, fac)
                xp = round(xp)
                yp = round(yp)
                i = i + 1
                byteArr[i] = getPixel(srcBytes, xp, yp, wSrc, hSrc, srcBpp, pxAlpha)
            end

            local trgImg <const> = Image(srcSpec)
            trgImg.bytes = tconcat(byteArr, "")
            trgImages[h] = trgImg
        end

        -- Create sprite, name sprite, set palette.
        local trgSprite <const> = AseUtilities.createSprite(srcSpec, "Wave")
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        app.transaction("Set Grid", function()
            trgSprite.gridBounds = Rectangle(xGrid, yGrid, wGrid, hGrid)
        end)

        -- Create frames.
        app.transaction("New Frames", function()
            trgSprite.frames[1].duration = packets[1].duration
            local i = 1
            while i < lenPackets do
                i = i + 1
                local frame <const> = trgSprite:newEmptyFrame()
                frame.duration = packets[i].duration
            end
        end)

        -- Rename layer.
        local trgLayer <const> = trgSprite.layers[1]
        trgLayer.name = string.format(
            "%s %s",
            waveType, edgeType)

        -- Create cels.
        local trimCels <const> = true
        local trgFrames <const> = trgSprite.frames
        local j = 0
        while j < lenPackets do
            j = j + 1
            local trgFrame <const> = trgFrames[j]
            local img = trgImages[j]
            local x = 0
            local y = 0
            if trimCels then
                img, x, y = trimImage(img, 0, alphaIndex)
            end
            transact(strfmt("Wave %d", trgFrame.frameNumber),
                function()
                    trgSprite:newCel(
                        trgLayer, trgFrame, img, Point(x, y))
                end)
        end

        app.frame = trgFrames[1]
        app.refresh()

        -- Report elapsed time.
        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime

            local txtArr <const> = {
                string.format("Start: %.2f", startTime),
                string.format("End: %.2f", endTime),
                string.format("Elapsed: %.6f", elapsed),
            }
            app.alert { title = "Diagnostic", text = txtArr }
        end
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