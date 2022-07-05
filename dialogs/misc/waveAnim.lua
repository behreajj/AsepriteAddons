dofile("../../support/aseutilities.lua")

local waveTypes = {
    "BILINEAR",
    "RADIAL"
}

local edgeTypes = {
    "CLAMP",
    "OMIT",
    "WRAP"
}

local defaults = {
    waveType = "RADIAL",
    frames = 32,
    fps = 24,
    timeScalar = 1,
    spaceScalar = 3,
    uDisplaceOrig = 5, -- radial
    uDisplaceDest = 5,
    xDisplaceOrig = 5,
    yDisplaceOrig = 5,
    xDisplaceDest = 5,
    yDisplaceDest = 5,
    xCenter = 50,
    yCenter = 50,
    sustain = 50,
    timeDecay = 100,
    spaceDecay = 100,
    edgeType = "OMIT",
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

        local isRadial = waveType == "RADIAL"
        dlg:modify { id = "uDisplaceOrig", visible = isRadial }
        dlg:modify { id = "uDisplaceDest", visible = isRadial }
        dlg:modify { id = "xCenter", visible = isRadial }
        dlg:modify { id = "yCenter", visible = isRadial }
        -- dlg:modify { id = "sustain", visible = isRadial }

        local isBilinear = waveType == "BILINEAR"
        dlg:modify { id = "xDisplaceOrig", visible = isBilinear }
        dlg:modify { id = "yDisplaceOrig", visible = isBilinear }
        dlg:modify { id = "xDisplaceDest", visible = isBilinear }
        dlg:modify { id = "yDisplaceDest", visible = isBilinear }
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

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "sustain",
--     label = "Sustain:",
--     min = 0,
--     max = 100,
--     value = defaults.sustain,
--     visible = defaults.waveType == "RADIAL"
-- }

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
    id = "xDisplaceOrig",
    label = "Displace X %:",
    min = 0,
    max = 100,
    value = defaults.xDisplaceOrig,
    visible = defaults.waveType == "BILINEAR"
}

dlg:slider {
    id = "xDisplaceDest",
    min = 0,
    max = 100,
    value = defaults.xDisplaceDest,
    visible = defaults.waveType == "BILINEAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "yDisplaceOrig",
    label = "Displace Y %:",
    min = 0,
    max = 100,
    value = defaults.yDisplaceOrig,
    visible = defaults.waveType == "BILINEAR"
}

dlg:slider {
    id = "yDisplaceDest",
    min = 0,
    max = 100,
    value = defaults.yDisplaceDest,
    visible = defaults.waveType == "BILINEAR"
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
                text = "There is no active sprite." }
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

        local dist = function(x, y)
            return math.sqrt(x * x + y * y)
        end

        local toTimeAngle = timeScalar * tau / reqFrames
        local frameToFac = 1.0 / (reqFrames - 1.0)

        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function(x, y)
                return srcImg:getPixel(
                    math.min(math.max(x, 0), srcWidth - 1),
                    math.min(math.max(y, 0), srcHeight - 1))
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
        if waveType == "RADIAL" then
            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local pxxCenter = srcWidth * xCenter * 0.01
            local pxyCenter = srcHeight * yCenter * 0.01

            local maxDist = dist(srcWidth, srcHeight)
            local distToTheta = spaceScalar * tau / maxDist

            local uDisplaceOrig = args.uDisplaceOrig or defaults.uDisplaceOrig
            local uDisplaceDest = args.uDisplaceDest or defaults.uDisplaceDest
            local pxuDisplaceOrig = maxDist * uDisplaceOrig * 0.005
            local pxuDisplaceDest = maxDist * uDisplaceDest * 0.005
            eval = function(x, y, angle, t)
                local d = dist(x - pxxCenter, y - pxyCenter)
                local theta = angle + d * distToTheta
                local uDispScl = (1.0 - t) * pxuDisplaceOrig
                    + t * pxuDisplaceDest
                local yOffset = uDispScl * math.sin(theta)
                return x, y + yOffset
            end
        else
            local xToTheta = spaceScalar * tau / srcWidth
            local yToTheta = spaceScalar * tau / srcHeight
            local xDisplaceOrig = args.xDisplaceOrig or defaults.xDisplaceOrig
            local yDisplaceOrig = args.yDisplaceOrig or defaults.yDisplaceOrig
            local xDisplaceDest = args.xDisplaceDest or defaults.xDisplaceDest
            local yDisplaceDest = args.yDisplaceDest or defaults.yDisplaceDest
            local pxxDisplaceOrig = srcWidth * xDisplaceOrig * 0.005
            local pxyDisplaceOrig = srcHeight * yDisplaceOrig * 0.005
            local pxxDisplaceDest = srcWidth * xDisplaceDest * 0.005
            local pxyDisplaceDest = srcHeight * yDisplaceDest * 0.005
            eval = function(x, y, angle, t)
                local xTheta = angle + x * xToTheta
                local yTheta = angle + y * yToTheta
                local u = 1.0 - t
                local xDispScl = u * pxxDisplaceOrig + t * pxxDisplaceDest
                local yDispScl = u * pxyDisplaceOrig + t * pxyDisplaceDest
                local xOffset = xDispScl * math.sin(yTheta)
                local yOffset = yDispScl * math.cos(xTheta)
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

        local trgSprite = Sprite(srcSpec)
        trgSprite.filename = "Wave"
        AseUtilities.setPalette(hexArr, trgSprite, 1)

        -- Create frames.
        local needed = math.max(0, reqFrames - 1)
        local duration = 1.0 / math.max(1, fps)
        trgSprite.frames[1].duration = duration
        app.transaction(function()
            AseUtilities.createFrames(trgSprite, needed, duration)
        end)

        -- Create cels.
        -- app.transaction(function()
        local trimCels = args.trimCels
        local trgFrames = trgSprite.frames
        local trgLayer = trgSprite.layers[1]
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
