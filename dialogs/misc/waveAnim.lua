dofile("../../support/aseutilities.lua")

local waveTypes = { "BILINEAR", "INTERLACED", "RADIAL" }
local interTypes = { "HORIZONTAL", "VERTICAL" }
local edgeTypes = { "CLAMP", "OMIT", "WRAP" }

local defaults = {
    waveType = "RADIAL",
    edgeType = "OMIT",
    frames = 32,
    fps = 24,
    timeScalar = 1,
    spaceScalar = 3,

    -- Interlaced
    interType = "HORIZONTAL",
    interOffOrig = 180,
    interOffDest = 180,

    -- Bilinear
    uDisplaceOrig = 5,
    uDisplaceDest = 5,
    xCenter = 50,
    yCenter = 50,

    -- Radial
    xDisplaceOrig = 5,
    yDisplaceOrig = 5,
    xDisplaceDest = 5,
    yDisplaceDest = 5,
    sustain = 25,
    -- TODO: Should warp be an animated property
    -- which uses lerpAngleNear?
    warp = 0,

    trimCels = true,
    printElapsed = false,
    pullFocus = false
}

local dlg = Dialog { title = "Wave" }

dlg:combobox {
    id = "waveType",
    label = "Type:",
    option = defaults.waveType,
    options = waveTypes,
    onchange = function()
        local args = dlg.data
        local waveType = args.waveType
        local interType = args.interType

        local isRadial = waveType == "RADIAL"
        dlg:modify { id = "uDisplaceOrig", visible = isRadial }
        dlg:modify { id = "uDisplaceDest", visible = isRadial }
        dlg:modify { id = "xCenter", visible = isRadial }
        dlg:modify { id = "yCenter", visible = isRadial }
        dlg:modify { id = "sustain", visible = isRadial }
        dlg:modify { id = "warp", visible = isRadial }

        local isInter = waveType == "INTERLACED"
        dlg:modify { id = "interType", visible = isInter }
        dlg:modify { id = "interOffOrig", visible = isInter }
        dlg:modify { id = "interOffDest", visible = isInter }

        local isHoriz = interType == "HORIZONTAL"
        local isVert = interType == "VERTICAL"
        local isBilinear = waveType == "BILINEAR"
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

dlg:combobox {
    id = "edgeType",
    label = "Edges:",
    option = defaults.edgeType,
    options = edgeTypes
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
    id = "timeScalar",
    label = "Frequency:",
    min = 1,
    max = 10,
    value = defaults.timeScalar
}

dlg:slider {
    id = "spaceScalar",
    min = 1,
    max = 10,
    value = defaults.spaceScalar
}

dlg:newrow { always = false }

dlg:slider {
    id = "xCenter",
    label = "Center %:",
    min = -50,
    max = 150,
    value = defaults.xCenter,
    visible = defaults.waveType == "RADIAL"
}

dlg:slider {
    id = "yCenter",
    min = -50,
    max = 150,
    value = defaults.yCenter,
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
    id = "warp",
    label = "Warp:",
    min = -180,
    max = 180,
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

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Edges",
    selected = defaults.trimCels
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
        local srcSprite = app.activeSprite
        if not srcSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Begin timing the function elapsed.
        local args = dlg.data
        local printElapsed = args.printElapsed
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then startTime = os.time() end

        -- Create source image.
        local srcSpec = srcSprite.spec
        local srcImg = Image(srcSpec)
        local activeFrame = app.activeFrame
            or srcSprite.frames[1]
        srcImg:drawSprite(srcSprite, activeFrame)

        -- Cache palette.
        local pal = AseUtilities.getPalette(
            activeFrame,
            srcSprite.palettes)
        local hexArr = AseUtilities.asePaletteToHexArr(pal)

        -- Constants.
        local pi = math.pi
        local tau = pi + pi
        local sqrt = math.sqrt
        local cos = math.cos
        local sin = math.sin
        local max = math.max
        local min = math.min
        local round = Utilities.round
        local trimImage = AseUtilities.trimImageAlpha

        -- Unpack arguments.
        local waveType = args.waveType or defaults.waveType
        local edgeType = args.edgeType or defaults.edgeType
        local reqFrames = args.frames or defaults.frames
        local fps = args.fps or defaults.fps
        local timeScalar = args.timeScalar or defaults.timeScalar
        local spaceScalar = args.spaceScalar or defaults.spaceScalar

        -- Derive values that remain constant in for loop.
        local srcWidth = srcSpec.width
        local srcHeight = srcSpec.height
        local alphaMask = srcSpec.transparentColor

        local magSq = function(x, y)
            return x * x + y * y
        end

        local toTimeAngle = timeScalar * tau / reqFrames
        local frameToFac = 0.0
        if reqFrames > 1 then
            frameToFac = 1.0 / (reqFrames - 1.0)
        end

        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function(x, y)
                local xc = x
                local yc = y
                if xc < 0 then
                    xc = 0
                elseif xc > srcWidth - 1 then
                    xc = srcWidth - 1
                end
                if yc < 0 then yc = 0
                elseif yc > srcHeight - 1 then
                    yc = srcHeight - 1
                end
                return srcImg:getPixel(xc, yc)
            end
        elseif edgeType == "OMIT" then
            wrapper = function(x, y)
                if x >= 0 and x < srcWidth
                    and y >= 0 and y < srcHeight then
                    return srcImg:getPixel(x, y)
                else
                    return alphaMask
                end
            end
        else
            wrapper = function(x, y)
                return srcImg:getPixel(x % srcWidth, y % srcHeight)
            end
        end

        local eval = nil
        if waveType == "INTERLACED" then
            local interType = args.interType or defaults.interType
            local interOffOrig = args.interOffOrig or defaults.interOffOrig
            local interOffDest = args.interOffDest or defaults.interOffDest
            local lacRadOrig = 0.017453292519943 * interOffOrig
            local lacRadDest = 0.017453292519943 * interOffDest
            if interType == "VERTICAL" then
                local yDisplaceOrig = args.yDisplaceOrig or defaults.yDisplaceOrig
                local yDisplaceDest = args.yDisplaceDest or defaults.yDisplaceDest
                local pxyDisplaceOrig = srcWidth * yDisplaceOrig * 0.005
                local pxyDisplaceDest = srcWidth * yDisplaceDest * 0.005
                local xToTheta = spaceScalar * tau / srcWidth
                eval = function(x, y, angle, t)
                    local xTheta = angle + x * xToTheta
                    if x % 2 ~= 0 then
                        local lacOrig = (1.0 - t) * lacRadOrig
                            + t * lacRadDest
                        xTheta = xTheta + lacOrig
                    end
                    local yDispScl = (1.0 - t) * pxyDisplaceOrig
                        + t * pxyDisplaceDest
                    local yOffset = yDispScl * cos(xTheta)
                    return x, y + yOffset
                end
            else
                local xDisplaceOrig = args.xDisplaceOrig or defaults.xDisplaceOrig
                local xDisplaceDest = args.xDisplaceDest or defaults.xDisplaceDest
                local pxxDisplaceOrig = srcHeight * xDisplaceOrig * 0.005
                local pxxDisplaceDest = srcHeight * xDisplaceDest * 0.005
                local yToTheta = spaceScalar * tau / srcHeight
                eval = function(x, y, angle, t)
                    local yTheta = angle + y * yToTheta
                    if y % 2 ~= 0 then
                        local lacOrig = (1.0 - t) * lacRadOrig
                            + t * lacRadDest
                        yTheta = yTheta + lacOrig
                    end
                    local xDispScl = (1.0 - t) * pxxDisplaceOrig
                        + t * pxxDisplaceDest
                    local xOffset = xDispScl * sin(yTheta)
                    return x + xOffset, y
                end
            end
        elseif waveType == "RADIAL" then
            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local uDisplaceOrig = args.uDisplaceOrig or defaults.uDisplaceOrig
            local uDisplaceDest = args.uDisplaceDest or defaults.uDisplaceDest
            local sustain = args.sustain or defaults.sustain
            local warp = args.warp or defaults.warp

            local maxDist = sqrt(magSq(srcWidth, srcHeight))
            local distToTheta = spaceScalar * tau / maxDist
            local distToFac = 1.0 / maxDist
            local sustFac = sustain * 0.01
            local warpRad = warp * 0.017453292519943
            local cosWarp = cos(warpRad)
            local sinWarp = sin(warpRad)

            local pxxCenter = srcWidth * xCenter * 0.01
            local pxyCenter = srcHeight * yCenter * 0.01
            local pxuDisplaceOrig = maxDist * uDisplaceOrig * 0.005
            local pxuDisplaceDest = maxDist * uDisplaceDest * 0.005

            eval = function(x, y, angle, t)
                local ax = x - pxxCenter
                local ay = y - pxyCenter
                local dSq = magSq(ax, ay)

                -- Normalize distance from center to point
                -- to get displacement direction.
                local nx = 0.0
                local ny = 0.0
                local d = 0.0
                if dSq > 0.0 then
                    d = sqrt(dSq)
                    nx = ax / d
                    ny = ay / d
                end

                -- Subtract space angle from time angle.
                -- Use - instead of + to make wave head
                -- away from the center instead of toward.
                local theta = angle - d * distToTheta

                -- Diminish displacement scale over time.
                local uDsplScl = (1.0 - t) * pxuDisplaceOrig
                    + t * pxuDisplaceDest

                -- Dminish displacement scale over space.
                -- Because center could be outside of canvas,
                -- this needs to be clamped to [0.0, 1.0].
                local fac = min(max(d * distToFac, 0.0), 1.0)
                local falloff = uDsplScl * (1.0 - fac)
                    + (uDsplScl * sustFac) * fac

                -- Rescale displacement vector by falloff.
                local offset = falloff * sin(theta)
                local xOff = nx * offset
                local yOff = ny * offset

                -- Rotate displacement vector by warp.
                local xWarp = cosWarp * xOff - sinWarp * yOff
                local yWarp = cosWarp * yOff + sinWarp * xOff

                return x + xWarp, y + yWarp
            end
        else
            local xDisplaceOrig = args.xDisplaceOrig or defaults.xDisplaceOrig
            local xDisplaceDest = args.xDisplaceDest or defaults.xDisplaceDest
            local yDisplaceOrig = args.yDisplaceOrig or defaults.yDisplaceOrig
            local yDisplaceDest = args.yDisplaceDest or defaults.yDisplaceDest

            local pxxDisplaceOrig = srcWidth * xDisplaceOrig * 0.005
            local pxxDisplaceDest = srcWidth * xDisplaceDest * 0.005
            local pxyDisplaceOrig = srcHeight * yDisplaceOrig * 0.005
            local pxyDisplaceDest = srcHeight * yDisplaceDest * 0.005

            local xToTheta = spaceScalar * tau / srcWidth
            local yToTheta = spaceScalar * tau / srcHeight

            eval = function(x, y, angle, t)
                local xTheta = angle + x * xToTheta
                local yTheta = angle + y * yToTheta
                local u = 1.0 - t
                local xDsplScl = u * pxxDisplaceOrig + t * pxxDisplaceDest
                local yDsplScl = u * pxyDisplaceOrig + t * pxyDisplaceDest
                local xOffset = xDsplScl * sin(yTheta)
                local yOffset = yDsplScl * cos(xTheta)
                return x + xOffset, y + yOffset
            end
        end

        local trgImages = {}
        local h = 0
        while h < reqFrames do
            local timeAngle = h * toTimeAngle
            local t = h * frameToFac
            -- t = t * t * (3.0 - (t + t))
            -- t = t * t

            local trgImage = Image(srcSpec)
            local trgItr = trgImage:pixels()
            for elm in trgItr do
                local x = elm.x
                local y = elm.y
                local xp, yp = eval(x, y, timeAngle, t)
                xp = round(xp)
                yp = round(yp)
                elm(wrapper(xp, yp))
            end

            h = h + 1
            trgImages[h] = trgImage
        end

        -- Create sprite, name sprite, set palette.
        local trgSprite = Sprite(srcSpec)
        trgSprite.filename = string.format(
            "wave_%s_%03d",
            Utilities.validateFilename(
                app.fs.fileTitle(srcSprite.filename)),
            activeFrame.frameNumber - 1)
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        -- Create frames.
        local needed = math.max(0, reqFrames - 1)
        local duration = 1.0 / math.max(1, fps)
        trgSprite.frames[1].duration = duration
        app.transaction(function()
            AseUtilities.createFrames(trgSprite, needed, duration)
        end)

        -- Create layer, name layer.
        local trimCels = args.trimCels
        local trgFrames = trgSprite.frames
        local trgLayer = trgSprite.layers[1]
        trgLayer.name = string.format(
            "Wave.%s.%s",
            waveType, edgeType)

        -- Create cels.
        -- app.transaction(function()
        local i = 0
        while i < reqFrames do i = i + 1
            local frame = trgFrames[i]
            local img = trgImages[i]
            local x = 0
            local y = 0
            if trimCels then
                img, x, y = trimImage(img, 0, alphaMask)
            end
            trgSprite:newCel(
                trgLayer, frame, img, Point(x, y))
        end
        -- end)

        app.activeFrame = trgSprite.frames[1]
        app.command.FitScreen()
        app.refresh()

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