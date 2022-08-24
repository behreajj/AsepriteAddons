dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local edgeTypes = { "CLAMP", "OMIT", "WRAP" }
local interTypes = { "HORIZONTAL", "VERTICAL" }
local waveTypes = { "BILINEAR", "INTERLACED", "RADIAL" }

local defaults = {
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

    printElapsed = false,
    pullFocus = false
}

local function wrapClamp(x, y, img)
    local xc = x
    local yc = y
    local wn1 = img.width - 1
    local hn1 = img.height - 1
    if xc < 0 then
        xc = 0
    elseif xc > wn1 then
        xc = wn1
    end
    if yc < 0 then
        yc = 0
    elseif yc > hn1 then
        yc = hn1
    end
    return img:getPixel(xc, yc)
end

local function wrapOmit(x, y, img)
    if y >= 0 and y < img.height
        and x >= 0 and x < img.width then
        return img:getPixel(x, y)
    end
    return img.spec.transparentColor
end

local function wrapMod(x, y, img)
    return img:getPixel(x % img.width, y % img.height)
end

local dlg = Dialog { title = "Wave" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args = dlg.data
        local isActive = args.target == "ACTIVE"
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

dlg:slider {
    id = "spaceScalar",
    label = "Period:",
    min = 1,
    max = 10,
    value = defaults.spaceScalar
}

dlg:slider {
    id = "timeScalar",
    min = 1,
    max = 10,
    value = defaults.timeScalar
}

dlg:newrow { always = false }

dlg:combobox {
    id = "waveType",
    label = "Type:",
    option = defaults.waveType,
    options = waveTypes,
    onchange = function()
        local args = dlg.data
        local waveType = args.waveType
        local interType = args.interType

        local isInter = waveType == "INTERLACED"
        local isBilinear = waveType == "BILINEAR"
        local isRadial = waveType == "RADIAL"

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

        local isHoriz = interType == "HORIZONTAL"
        local isVert = interType == "VERTICAL"

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
        local args = dlg.data
        local interType = args.interType

        local isHoriz = interType == "HORIZONTAL"
        local isVert = interType == "VERTICAL"
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

dlg:check {
    id = "printElapsed",
    label = "Print Diagnostic:",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Begin timing the function elapsed.
        local args = dlg.data
        local printElapsed = args.printElapsed
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.time() end

        -- Early returns.
        local srcSprite = app.activeSprite
        if not srcSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local srcSpec = srcSprite.spec
        local colorMode = srcSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Cache palette, preserve fore and background.
        AseUtilities.preserveForeBack()
        local hexArr = AseUtilities.asePalettesToHexArr(
            srcSprite.palettes)

        local target = args.target or defaults.target
        local srcFrames = srcSprite.frames
        local lenSrcFrames = #srcFrames
        local isActive = target == "ACTIVE"

        local selFrames = AseUtilities.getFrames(srcSprite, target)

        local timeOffsetDeg = defaults.timeOffset
        local timeOffset = timeOffsetDeg * 0.017453292519943
        local timeScalar = args.timeScalar or defaults.timeScalar

        -- Flatten sprite to images, associate with a factor
        -- and an angle theta.
        local packets = {}
        if isActive then
            local frameCount = args.frameCount or defaults.frameCount
            local fps = args.fps or defaults.fps

            local selFrame = selFrames[1]
            local selImg = Image(srcSpec)
            selImg:drawSprite(srcSprite, selFrame)

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
                local fac = j * frameToFac
                local theta = timeOffset + j * frameToTheta
                local packet = {
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

            local timeStamps = {}
            local totalDuration = 0
            local i = 0
            while i < lenSrcFrames do i = i + 1
                local srcFrame = srcFrames[i]
                local duration = srcFrame.duration
                timeStamps[i] = totalDuration
                totalDuration = totalDuration + duration
            end

            local timeToFac = 0.0
            local finalDuration = timeStamps[lenSrcFrames]
            if finalDuration and finalDuration ~= 0.0 then
                timeToFac = 1.0 / finalDuration
            end

            local timeToTheta = 0.0
            if totalDuration > 0.0 then
                timeToTheta = timeScalar * 6.2831853071796 / totalDuration
            end

            local lenSelFrames = #selFrames
            local j = 0
            while j < lenSelFrames do j = j + 1
                local selFrame = selFrames[j]
                local selDuration = selFrame.duration
                local selFrameNo = selFrame.frameNumber

                local selImg = Image(srcSpec)
                selImg:drawSprite(srcSprite, selFrame)

                local selTime = timeStamps[selFrameNo]
                local fac = selTime * timeToFac
                local theta = timeOffset + selTime * timeToTheta

                local packet = {
                    duration = selDuration,
                    image = selImg,
                    fac = fac,
                    theta = theta
                }
                packets[j] = packet
            end
        end

        -- Cache methods.
        local round = Utilities.round
        local abs = math.abs
        local cos = math.cos
        local sin = math.sin
        local max = math.max
        local min = math.min
        local sqrt = math.sqrt
        local trimImage = AseUtilities.trimImageAlpha

        -- Determine how to wrap out of bounds pixels.
        local edgeType = args.edgeType or defaults.edgeType
        local wrapper = wrapMod
        if edgeType == "CLAMP" then
            wrapper = wrapClamp
        elseif edgeType == "OMIT" then
            wrapper = wrapOmit
        end

        local spaceScalar = args.spaceScalar or defaults.spaceScalar
        local waveType = args.waveType or defaults.waveType

        local srcWidth = srcSpec.width
        local srcHeight = srcSpec.height
        local wn1 = srcWidth - 1
        local hn1 = srcHeight - 1

        -- Determine which wave function the user wants.
        local eval = nil
        if waveType == "BILINEAR" then

            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local pxxCenter = xCenter * 0.01 * srcWidth
            local pxyCenter = yCenter * 0.01 * srcHeight

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
            local xDisplaceOrig = args.xDisplaceOrig or defaults.xDisplaceOrig
            local xDisplaceDest = args.xDisplaceDest or defaults.xDisplaceDest
            local yDisplaceOrig = args.yDisplaceOrig or defaults.yDisplaceOrig
            local yDisplaceDest = args.yDisplaceDest or defaults.yDisplaceDest

            local pxxDisplaceOrig = srcWidth * xDisplaceOrig * 0.005
            local pxxDisplaceDest = srcWidth * xDisplaceDest * 0.005
            local pxyDisplaceOrig = srcHeight * yDisplaceOrig * 0.005
            local pxyDisplaceDest = srcHeight * yDisplaceDest * 0.005

            local xToTheta = spaceScalar * 6.2831853071796 / srcWidth
            local yToTheta = spaceScalar * 6.2831853071796 / srcHeight

            eval = function(x, y, angle, t)
                local dx = x - pxxCenter
                local dy = pxyCenter - y
                local fac = toFac * max(abs(dx), abs(dy))
                fac = min(max(fac, 0.0), 1.0)
                local xSst = (1.0 - fac) + fac * xBaseSustain
                local ySst = (1.0 - fac) + fac * yBaseSustain

                local u = 1.0 - t
                local xDsplScl = u * pxxDisplaceOrig + t * pxxDisplaceDest
                local yDsplScl = u * pxyDisplaceOrig + t * pxyDisplaceDest

                local xTheta = angle - x * xToTheta
                local yTheta = angle + y * yToTheta
                local xWarp = xDsplScl * xSst * sin(yTheta)
                local yWarp = yDsplScl * ySst * cos(xTheta)
                return x + xWarp, y + yWarp
            end

        elseif waveType == "INTERLACED" then

            -- wn1 and hn1 work better for sprites with even width, height
            -- when converting to theta.s
            local interType = args.interType or defaults.interType
            local interOffOrig = args.interOffOrig or defaults.interOffOrig
            local interOffDest = args.interOffDest or defaults.interOffDest
            local skip = args.interSkip or defaults.interSkip
            local pick = args.interPick or defaults.interPick

            -- Pattern is sum of both on/off: e.g., 001110011100,
            -- pick 2 skip 3, is 5 total. Modulo all to repeat
            -- pattern, then check if lt pick.
            local all = pick + skip
            local lacRadOrig = 0.017453292519943 * interOffOrig
            local lacRadDest = 0.017453292519943 * interOffDest

            if interType == "VERTICAL" then

                local yDisplaceOrig = args.yDisplaceOrig or defaults.yDisplaceOrig
                local yDisplaceDest = args.yDisplaceDest or defaults.yDisplaceDest
                local pxyDisplaceOrig = srcWidth * yDisplaceOrig * 0.005
                local pxyDisplaceDest = srcWidth * yDisplaceDest * 0.005

                local xToTheta = spaceScalar * 6.2831853071796
                if wn1 > 0 then
                    xToTheta = xToTheta / wn1
                end

                eval = function(x, y, angle, t)
                    local u = 1.0 - t
                    local xTheta = angle + x * xToTheta
                    if x % all < pick then
                        local lacOrig = u * lacRadOrig
                            + t * lacRadDest
                        xTheta = xTheta + lacOrig
                    end
                    local yDsplScl = u * pxyDisplaceOrig
                        + t * pxyDisplaceDest
                    return x, y + yDsplScl * cos(xTheta)
                end

            else

                -- Default to horizontal.
                local xDisplaceOrig = args.xDisplaceOrig or defaults.xDisplaceOrig
                local xDisplaceDest = args.xDisplaceDest or defaults.xDisplaceDest
                local pxxDisplaceOrig = srcHeight * xDisplaceOrig * 0.005
                local pxxDisplaceDest = srcHeight * xDisplaceDest * 0.005

                local yToTheta = spaceScalar * 6.2831853071796
                if hn1 > 0 then
                    yToTheta = yToTheta / hn1
                end

                eval = function(x, y, angle, t)
                    local u = 1.0 - t
                    local yTheta = angle + y * yToTheta
                    if y % all < pick then
                        local lacOrig = u * lacRadOrig
                            + t * lacRadDest
                        yTheta = yTheta + lacOrig
                    end
                    local xDsplScl = u * pxxDisplaceOrig
                        + t * pxxDisplaceDest
                    return x + xDsplScl * sin(yTheta), y
                end

            end

        else

            -- Default to radial wave.
            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local uDisplaceOrig = args.uDisplaceOrig or defaults.uDisplaceOrig
            local uDisplaceDest = args.uDisplaceDest or defaults.uDisplaceDest
            local sustain = args.sustain or defaults.sustain
            local warp = args.warp or defaults.warp

            -- Working on what would be most intuitive.
            local maxDist = 0.0
            local distToFac = 0.0
            local shortEdge = min(srcWidth, srcHeight)
            if yCenter <= -50 or yCenter >= 150
                or xCenter <= -50 or xCenter >= 150 then
                local se3 = shortEdge * 3
                maxDist = sqrt(se3 * se3 + se3 * se3)
                if maxDist ~= 0.0 then
                    distToFac = 2.8284 / maxDist
                end
            elseif yCenter <= 0 or yCenter >= 100
                or xCenter <= 0 or xCenter >= 100 then
                local se2 = shortEdge * 2
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

            local pxxCenter = wn1 * xCenter * 0.01
            local pxyCenter = hn1 * yCenter * 0.01
            local pxuDisplaceOrig = maxDist * uDisplaceOrig * 0.005
            local pxuDisplaceDest = maxDist * uDisplaceDest * 0.005

            local distToTheta = spaceScalar * 6.2831853071796 / maxDist
            local sustFac = sustain * 0.01
            local warpRad = warp * 0.017453292519943
            local cosWarp = cos(warpRad)
            local sinWarp = sin(warpRad)

            eval = function(x, y, angle, t)
                local ax = x - pxxCenter
                local ay = y - pxyCenter
                local dSq = ax * ax + ay * ay

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
                local fac = min(max(d * distToFac, 0.0), 1.0)
                local falloff = (1.0 - fac) + fac * sustFac

                -- Subtract space angle from time angle.
                -- Use - instead of + to make wave head
                -- away from the center instead of toward.
                local theta = angle - d * distToTheta

                -- Diminish displacement scale over time.
                local uDsplScl = (1.0 - t) * pxuDisplaceOrig
                    + t * pxuDisplaceDest

                -- Rescale displacement vector by falloff.
                local offset = falloff * uDsplScl * sin(theta)
                local xOff = nx * offset
                local yOff = ny * offset

                -- Rotate displacement vector by warp.
                local xWarp = cosWarp * xOff - sinWarp * yOff
                local yWarp = cosWarp * yOff + sinWarp * xOff

                return x + xWarp, y + yWarp
            end
        end

        -- Create wave images from packet data.
        local trgImages = {}
        local lenPackets = #packets
        local h = 0
        while h < lenPackets do h = h + 1
            local packet = packets[h]
            local fac = packet.fac
            local theta = packet.theta
            local srcImg = packet.image

            local trgImg = Image(srcSpec)
            local trgItr = trgImg:pixels()

            for elm in trgItr do
                local xp, yp = eval(elm.x, elm.y, theta, fac)
                xp = round(xp)
                yp = round(yp)
                elm(wrapper(xp, yp, srcImg))
            end

            trgImages[h] = trgImg
        end

        -- Create sprite, name sprite, set palette.
        local trgSprite = Sprite(srcSpec)
        trgSprite.filename = "Wave"
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        -- Create frames.
        app.transaction(function()
            trgSprite.frames[1].duration = packets[1].duration
            local i = 1
            while i < lenPackets do i = i + 1
                local frame = trgSprite:newEmptyFrame()
                frame.duration = packets[i].duration
            end
        end)

        -- Rename layer.
        local trgLayer = trgSprite.layers[1]
        trgLayer.name = string.format(
            "Wave.%s.%s",
            waveType, edgeType)

        -- Create cels.
        local trimCels = true
        local trgFrames = trgSprite.frames
        local alphaMask = srcSpec.transparentColor
        local j = 0
        while j < lenPackets do j = j + 1
            local frame = trgFrames[j]
            local img = trgImages[j]
            local x = 0
            local y = 0
            if trimCels then
                img, x, y = trimImage(img, 0, alphaMask)
            end
            trgSprite:newCel(
                trgLayer, frame, img, Point(x, y))
        end

        app.activeFrame = trgFrames[1]
        app.command.FitScreen()
        app.refresh()

        -- Report elapsed time.
        if printElapsed then
            endTime = os.time()
            elapsed = os.difftime(endTime, startTime)

            local txtArr = {
                string.format("Start: %d", startTime),
                string.format("End: %d", endTime),
                string.format("Elapsed: %d", elapsed),
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

dlg:show { wait = false }