local coords = { "CARTESIAN", "POLAR" }
local edgeTypes = { "CLAMP", "OMIT", "WRAP" }
local targets = { "ACTIVE", "ALL", "RANGE" }


local defaults = {
    -- TODO: Option to hide source layer, see
    -- layerMask dialog?
    target = "RANGE",
    edgeType = "OMIT",
    easeMethod = "NEAREST",
    coord = "POLAR",
    xOrigin = 0,
    yOrigin = 50,
    xDest = 100,
    yDest = 50,
    xCenter = 50,
    yCenter = 50,
    angle = 0,
    radius = 100,
    useInverse = false,
    trimCels = false,
    drawDiagnostic = false,
    pullFocus = true
}

local dlg = Dialog { title = "Mirror" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
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
    id = "coord",
    label = "Coords:",
    option = defaults.coord,
    options = coords,
    onchange = function()
        local args = dlg.data
        local coord = args.coord
        local isCart = coord == "CARTESIAN"
        dlg:modify { id = "xOrigin", visible = isCart }
        dlg:modify { id = "yOrigin", visible = isCart }
        dlg:modify { id = "xDest", visible = isCart }
        dlg:modify { id = "yDest", visible = isCart }

        local isPolr = coord == "POLAR"
        dlg:modify { id = "xCenter", visible = isPolr }
        dlg:modify { id = "yCenter", visible = isPolr }
        dlg:modify { id = "angle", visible = isPolr }
        dlg:modify { id = "radius", visible = isPolr }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "xOrigin",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrigin,
    visible = defaults.coord == "CARTESIAN"
}

dlg:slider {
    id = "yOrigin",
    min = 0,
    max = 100,
    value = defaults.yOrigin,
    visible = defaults.coord == "CARTESIAN"
}

dlg:newrow { always = false }

dlg:slider {
    id = "xDest",
    label = "Dest %:",
    min = 0,
    max = 100,
    value = defaults.xDest,
    visible = defaults.coord == "CARTESIAN"
}

dlg:slider {
    id = "yDest",
    min = 0,
    max = 100,
    value = defaults.yDest,
    visible = defaults.coord == "CARTESIAN"
}

dlg:newrow { always = false }

dlg:slider {
    id = "xCenter",
    label = "Center %:",
    min = 0,
    max = 100,
    value = defaults.xCenter,
    visible = defaults.coord == "POLAR"
}

dlg:slider {
    id = "yCenter",
    min = 0,
    max = 100,
    value = defaults.yCenter,
    visible = defaults.coord == "POLAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle,
    visible = defaults.coord == "POLAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "radius",
    label = "Radius:",
    min = 1,
    max = 100,
    value = defaults.radius,
    visible = defaults.coord == "POLAR"
}

dlg:newrow { always = false }

dlg:check {
    id = "useInverse",
    label = "Invert:",
    selected = defaults.useInverse
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
    id = "drawDiagnostic",
    label = "Draw:",
    text = "Diagnostic",
    selected = defaults.drawDiagnostic
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer." }
            return
        end

        -- Check for tile maps.
        local version = app.version
        local layerIsTilemap = false
        local tileSet = nil
        if version.major >= 1 and version.minor >= 3 then
            local activeLayer = app.activeLayer
            layerIsTilemap = activeLayer.isTilemap
            tileSet = activeLayer.tileset
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local edgeType = args.edgeType or defaults.edgeType
        local coord = args.coord or defaults.coord
        local useInverse = args.useInverse
        local trimCels = args.trimCels
        local drawDiagnostic = args.drawDiagnostic

        -- Whether to use greater than or less than to
        -- determine which side of the line to mirror.
        local flipSign = 1.0
        if useInverse then flipSign = -1.0 end

        -- Find frames from target.
        local frames = {}
        if target == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                frames[1] = activeFrame
            end
        elseif target == "RANGE" then
            local appRange = app.range
            local rangeFrames = appRange.frames
            local rangeFramesLen = #rangeFrames
            for i = 1, rangeFramesLen, 1 do
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        -- Determine how to wrap pixels.
        local wrapper = nil
        if edgeType == "CLAMP" then
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                return srcImg:getPixel(
                    math.min(math.max(x, 0), w - 1),
                    math.min(math.max(y, 0), h - 1))
            end
        elseif edgeType == "OMIT" then
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                if x >= 0 and x < w
                    and y >= 0 and y < h then
                    return srcImg:getPixel(x, y)
                else
                    return alphaMask
                end
            end
        else
            wrapper = function(x, y, w, h, srcImg, alphaMask)
                return srcImg:getPixel(x % w, y % h)
            end
        end

        local spriteSpec = activeSprite.spec
        local spriteWidth = spriteSpec.width
        local spriteHeight = spriteSpec.height
        local colorMode = spriteSpec.colorMode
        local alphaMask = spriteSpec.transparentColor

        local wn1 = math.max(1.0, spriteWidth - 1.0)
        local hn1 = math.max(1.0, spriteHeight - 1.0)
        local xOrPx = 0
        local yOrPx = 0
        local xDsPx = wn1
        local yDsPx = 0

        if coord == "POLAR" then
            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local angle = args.angle or defaults.angle
            local radius = args.radius or defaults.radius

            local xCtPx = xCenter * wn1 * 0.01
            local yCtPx = yCenter * hn1 * 0.01
            local r = radius * 0.005 * math.sqrt(
                wn1 * wn1 + hn1 * hn1)

            -- There's no benefit to dimetric angles here.
            local a = angle * 0.017453292519943
            local rtcos = r * math.cos(a)
            local rtsin = r * math.sin(a)

            xOrPx = xCtPx - rtcos
            yOrPx = yCtPx + rtsin
            xDsPx = xCtPx + rtcos
            yDsPx = yCtPx - rtsin
        else
            local xOrigin = args.xOrigin or defaults.xOrigin
            local yOrigin = args.yOrigin or defaults.yOrigin
            local xDest = args.xDest or defaults.xDest
            local yDest = args.yDest or defaults.yDest

            xOrPx = xOrigin * wn1 * 0.01
            yOrPx = yOrigin * hn1 * 0.01
            xDsPx = xDest * wn1 * 0.01
            yDsPx = yDest * hn1 * 0.01
        end

        -- Find vector between origin and destination.
        -- If the points are too close together, handle
        -- invalid condition.
        local dx = xDsPx - xOrPx
        local dy = yDsPx - yOrPx
        local invalidFlag = (math.abs(dx) < 1)
            and (math.abs(dy) < 1)
        if invalidFlag then
            xOrPx = 0
            yOrPx = 0
            xDsPx = wn1
            yDsPx = 0
            dx = xDsPx - xOrPx
            dy = yDsPx - yOrPx
        end
        local dInvMagSq = 1.0 / (dx * dx + dy * dy)

        -- Create target layer.
        local mirrLayer = activeSprite:newLayer()
        mirrLayer.opacity = srcLayer.opacity

        -- Used to include origin and destination coordinates.
        mirrLayer.name = string.format(
            "%s.Mirrored",
            srcLayer.name)

        -- Cache global methods.
        local floor = math.floor
        local trimAlpha = AseUtilities.trimImageAlpha

        local framesLen = #frames
        app.transaction(function()
            local i = 0
            while i < framesLen do
                i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    local srcPos = srcCel.position
                    local xSrcPos = srcPos.x
                    local ySrcPos = srcPos.y

                    if layerIsTilemap then
                        srcImg = AseUtilities.tilesToImage(
                            srcImg, tileSet, colorMode)
                    end

                    local wSrcImg = srcImg.width
                    local hSrcImg = srcImg.height
                    local flatImg = srcImg
                    if xSrcPos ~= 0
                        or ySrcPos ~= 0
                        or wSrcImg ~= spriteWidth
                        or hSrcImg ~= spriteHeight then
                        flatImg = Image(spriteSpec)
                        flatImg:drawImage(srcImg, srcPos)
                    end

                    local mirrImg = Image(spriteSpec)
                    local mirrPxItr = mirrImg:pixels()
                    for elm in mirrPxItr do
                        local cx = elm.x
                        local cy = elm.y
                        local ex = cx - xOrPx
                        local ey = cy - yOrPx
                        local cross = ex * dy - ey * dx
                        if flipSign * cross < 0.0 then
                            elm(flatImg:getPixel(cx, cy))
                        else
                            local t = (ex * dx + ey * dy) * dInvMagSq
                            local u = 1.0 - t
                            local pxProj = u * xOrPx + t * xDsPx
                            local pyProj = u * yOrPx + t * yDsPx
                            local pxOpp = pxProj + pxProj - cx
                            local pyOpp = pyProj + pyProj - cy

                            -- TODO: Support bilinear vs. nearest sampling?
                            -- If so, would have to change pixel format to RGB.
                            local ixOpp = floor(0.5 + pxOpp)
                            local iyOpp = floor(0.5 + pyOpp)

                            elm(wrapper(ixOpp, iyOpp,
                                spriteWidth, spriteHeight,
                                flatImg, alphaMask))
                        end
                    end

                    local xTrim = 0
                    local yTrim = 0
                    if trimCels then
                        mirrImg, xTrim, yTrim = trimAlpha(
                            mirrImg, 0, alphaMask)
                    end

                    activeSprite:newCel(
                        mirrLayer, srcFrame, mirrImg,
                        Point(xTrim, yTrim))
                end
            end
        end)

        if drawDiagnostic then
            local origin = Point(xOrPx, yOrPx)
            local dest = Point(xDsPx, yDsPx)

            -- Same as colors in drawknot2 (handles).
            local lineColor = Color(175, 175, 175, 255)
            local originColor = Color(2, 167, 235, 255)
            local destColor = Color(235, 26, 64, 255)
            local lineBrush = Brush(2)
            local pointBrush = Brush(7)

            app.transaction(function()
                local diagnosticLayer = activeSprite:newLayer()
                diagnosticLayer.name = "Mirror.Diagnostic"
                diagnosticLayer.opacity = 128

                local i = 0
                while i < framesLen do
                    i = i + 1
                    local srcFrame = frames[i]
                    app.useTool {
                        tool = "line",
                        brush = lineBrush,
                        color = lineColor,
                        layer = diagnosticLayer,
                        frame = srcFrame,
                        points = { origin, dest } }


                    app.useTool {
                        tool = "pencil",
                        brush = pointBrush,
                        color = originColor,
                        layer = diagnosticLayer,
                        frame = srcFrame,
                        points = { origin } }

                    app.useTool {
                        tool = "line",
                        brush = pointBrush,
                        color = destColor,
                        layer = diagnosticLayer,
                        frame = srcFrame,
                        points = { dest } }
                end
            end)
        end

        app.refresh()

        if invalidFlag then
            app.alert {
                title = "Warning",
                text = "Origin and destination are the same." }
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
