dofile("./clr.lua")
dofile("./utilities.lua")

CanvasUtilities = {}
CanvasUtilities.__index = CanvasUtilities

setmetatable(CanvasUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws a grid of overlapping horizontal and vertical
---lines. Turns off antialiasing. Sets color and stroke
---width.
---@param context GraphicsContext canvas
---@param count integer grid line count
---@param w integer width
---@param h integer height
---@param color Color stroke
---@param sw integer stroke weight
function CanvasUtilities.drawGrid(context, count, w, h, color, sw)
    context.antialias = false
    context.color = color
    context.strokeWidth = sw

    local floor = math.floor

    local xbr = w - 1.0
    local ybr = h - 1.0
    local iToFac = ybr / (count - 1.0)
    local jToFac = xbr / (count - 1.0)

    -- Draw vertical grid lines.
    local i = 0
    while i < count do
        local y = floor(i * iToFac)
        context:beginPath()
        context:moveTo(0, y)
        context:lineTo(xbr, y)
        context:stroke()
        i = i + 1
    end

    -- Draw horizontal grid lines.
    local j = 0
    while j < count do
        local x = floor(j * jToFac)
        context:beginPath()
        context:moveTo(x, 0)
        context:lineTo(x, ybr)
        context:stroke()
        j = j + 1
    end
end

---Draws a polygon on a graphics context.
---Only creates the shape, does not assign
---fill or stroke. The rotation is expected
---in radians.
---@param context GraphicsContext canvas
---@param sides integer sides
---@param radius number radius
---@param x number x origin
---@param y number y origin
---@param rotation number? rotation
function CanvasUtilities.drawPolygon(
    context, sides, radius, x, y, rotation)
    local aVrf = rotation or 0.0

    local iToTheta = 6.2831853071796 / sides
    local cos = math.cos
    local sin = math.sin

    context:beginPath()
    context:moveTo(
        cos(aVrf) * radius + x,
        y - sin(aVrf) * radius)
    local i = 0
    while i < sides do
        i = i + 1
        local a = i * iToTheta + aVrf
        context:lineTo(
            cos(a) * radius + x,
            y - sin(a) * radius)
    end
    context:closePath()
end

---Draws a filled reticle on a graphics context.
---The input factor is expected to be in the range
---[0.0, 1.0]. Draws two triangles on the top
---and bottom tracks of the slider bar.
---@param context GraphicsContext canvas
---@param fac number normalized factor
---@param barWidth integer bar width
---@param barHeight integer bar height
---@param fillColor Color fill color
---@param triSize number? triangle size
function CanvasUtilities.drawSliderReticle(
    context, fac,
    barWidth, barHeight,
    fillColor, triSize)
    local x = fac * (barWidth - 1.0)
    local trszvrf = triSize or 3

    context.color = fillColor

    context:beginPath()
    context:moveTo(x - trszvrf, 0)
    context:lineTo(x, trszvrf)
    context:lineTo(x + trszvrf, 0)
    context:closePath()
    context:fill()

    context:beginPath()
    context:moveTo(x, barHeight - trszvrf)
    context:lineTo(x - trszvrf, barHeight)
    context:lineTo(x + trszvrf, barHeight)
    context:fill()
end

---Generates the dialog widgets used by a Bezier curve.
---This includes a canvas, four number inputs for
---the two control points x and y coordinate.
---The ids for these sliders are "cp0x," "cp0y",
---"cp1x" and "cp1y."
---@param dialog Dialog dialog
---@param id string canvas id
---@param label string canvas label
---@param width integer canvas width
---@param height integer canvas height
---@param isVisible boolean? is visible
---@param visCtrl boolean? visible numbers
---@param visButtons boolean? visible buttons
---@param visFuncs boolean? visible functions
---@param allowApMove boolean? allow anchor points
---@param gridCount integer? grid count
---@param cp0xDef number? x control point 0 default
---@param cp0yDef number? y control point 0 default
---@param cp1xDef number? x control point 1 default
---@param cp1yDef number? y control point 1 default
---@param curveColor Color? curve color
---@param gridColor Color? grid color
---@param cp0Color Color? control point 0 color
---@param cp1Color Color? control point 1 color
---@return Dialog
function CanvasUtilities.graphBezier(
    dialog, id, label, width, height,
    isVisible, visCtrl, visButtons, visFuncs,
    allowApMove, gridCount,
    cp0xDef, cp0yDef, cp1xDef, cp1yDef,
    curveColor, gridColor, cp0Color, cp1Color)
    -- Constants.
    local screenScale = app.preferences.general.screen_scale
    local swCurve = 2
    local hotSpot = 16 / screenScale
    local hotSpotSq = hotSpot * hotSpot
    local polyRadius = 4 * swCurve / screenScale
    local halfRadius = polyRadius * 0.5

    -- Verify arguments.
    local cp1ClrVrf = cp1Color or Color { r = 0, g = 132, b = 159 }
    local cp0ClrVrf = cp0Color or Color { r = 168, g = 0, b = 51 }
    local gridClrVrf = gridColor or Color { r = 128, g = 128, b = 128 }
    local curveClrVrf = curveColor or Color { r = 255, g = 255, b = 255 }

    local grdCntVrf = gridCount or 5
    local allowApVrf = false
    if allowApMove then allowApVrf = true end
    local visFuncsVrf = false
    if visFuncs then visFuncsVrf = true end
    local visButtonsVrf = false
    if visButtons then visButtonsVrf = true end
    local visCtrlVrf = false
    if visCtrl then visCtrlVrf = true end
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf = id or "graphBezier"

    -- In case this widget is used more than once in a dialog,
    -- the widget ids need to be distinct from each other.
    local easeFuncsId = idVrf .. "_easeFuncs"
    local flipvButtonId = idVrf .. "_flipv"
    local straightButtonId = idVrf .. "_straight"
    local parallelButtonId = idVrf .. "_parallel"

    local idPoints = {
        idVrf .. "_ap0x",
        idVrf .. "_ap0y",
        idVrf .. "_cp0x",
        idVrf .. "_cp0y",
        idVrf .. "_cp1x",
        idVrf .. "_cp1y",
        idVrf .. "_ap1x",
        idVrf .. "_ap1y",
    }
    local lenIdPoints = #idPoints

    local labelPoints = {
        "Anchor 0:",
        "Control 0:",
        "Control 1:",
        "Anchor 1:"
    }

    local valuePoints = {
        0.0,
        0.0,
        cp0xDef or 0.42,
        cp0yDef or 0.0,
        cp1xDef or 0.58,
        cp1yDef or 1.0,
        1.0,
        1.0
    }

    ---@param event MouseEvent
    local onMouseFunc = function(event)
        -- TODO: How to handle canvas resize.
        if event.button ~= MouseButton.NONE then
            -- Unpack mouse event coordinates.
            local xMouse = event.x
            local yMouse = event.y

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr = wVrf - 1
            local ybr = hVrf - 1

            -- Convert mouse coordinate to [0.0, 1.0].
            -- Flip y axis.
            local xm01 = xMouse / xbr
            local ym01 = (ybr - yMouse) / ybr

            -- Clamp coordinates.
            xm01 = math.min(math.max(xm01, 0.0), 1.0)
            ym01 = math.min(math.max(ym01, 0.0), 1.0)

            -- Epsilon is inverse of max resolution (64).
            local clampEpsilon = 1.0 / 64.0

            ---@type string[][]
            local args = dialog.data

            -- Control points take precedence over anchor points
            -- when it comes to selecting for mouse movement.
            local knotIds = {
                { idPoints[1], idPoints[2], idPoints[3], idPoints[4] },
                { idPoints[7], idPoints[8], idPoints[5], idPoints[6] }
            }
            local lenKnotIds = #knotIds

            local i = 0
            while i < lenKnotIds do
                local isEven = (i % 2) ~= 1
                i = i + 1
                local knot = knotIds[i]

                local xAnchorId = knot[1]
                local yAnchorId = knot[2]
                local xAnchor = args[xAnchorId] --[[@as number]]
                local yAnchor = args[yAnchorId] --[[@as number]]

                local xControlId = knot[3]
                local yControlId = knot[4]
                local xControl = args[xControlId] --[[@as number]]
                local yControl = args[yControlId] --[[@as number]]

                local xCtrlPixel = Utilities.round(xControl * xbr)
                local yCtrlPixel = ybr - Utilities.round(yControl * ybr)

                local xCtrlDiff = xCtrlPixel - xMouse
                local yCtrlDiff = yCtrlPixel - yMouse
                local sqMagCtrl = xCtrlDiff * xCtrlDiff + yCtrlDiff * yCtrlDiff
                if sqMagCtrl < hotSpotSq then
                    -- Prevent invalid outputs by limiting Bezier cage.
                    -- Even knots have outgoing tangents,
                    -- odd knots have incoming tangents.
                    local xClamped = xm01
                    if isEven then
                        xClamped = math.max(xm01, xAnchor + clampEpsilon)
                    else
                        xClamped = math.min(xm01, xAnchor - clampEpsilon)
                    end
                    dialog:modify { id = xControlId, text = string.format("%.5f", xClamped) }
                    dialog:modify { id = yControlId, text = string.format("%.5f", ym01) }
                    dialog:modify { id = easeFuncsId, option = "CUSTOM" }
                    dialog:repaint()
                    return
                end

                -- Prioritize interacting with control points over
                -- anchor points.
                if allowApVrf then
                    local xAnchPixel = Utilities.round(xAnchor * xbr)
                    local yAnchPixel = ybr - Utilities.round(yAnchor * ybr)

                    local xAnchDiff = xAnchPixel - xMouse
                    local yAnchDiff = yAnchPixel - yMouse
                    local sqMagAnch = xAnchDiff * xAnchDiff + yAnchDiff * yAnchDiff
                    if sqMagAnch < hotSpotSq then
                        local xCtrlNew = xm01 + (xControl - xAnchor)
                        local yCtrlNew = ym01 + (yControl - yAnchor)
                        dialog:modify { id = xAnchorId, text = string.format("%.5f", xm01) }
                        dialog:modify { id = yAnchorId, text = string.format("%.5f", ym01) }
                        dialog:modify { id = xControlId, text = string.format("%.5f", xCtrlNew) }
                        dialog:modify { id = yControlId, text = string.format("%.5f", yCtrlNew) }
                        dialog:modify { id = easeFuncsId, option = "CUSTOM" }
                        dialog:repaint()
                        return
                    end -- End point is in radius.
                end     -- End allow anchor point movement.
            end         -- End knots loop.
        end             -- End mouse button is not none.
    end                 -- End mouse listener function.

    dialog:canvas {
        id = idVrf,
        label = label,
        width = wVrf,
        height = hVrf,
        visible = isVisVrf,
        autoScaling = false,
        onpaint = function(event)
            local context = event.context

            -- Draw grid, then set antialiasing to
            -- true afterward.
            CanvasUtilities.drawGrid(context, grdCntVrf,
                wVrf, hVrf, gridClrVrf, 1)
            context.antialias = true

            -- Unpack arguments.
            local args = dialog.data
            local ap0x = args[idPoints[1]] --[[@as number]]
            local ap0y = args[idPoints[2]] --[[@as number]]
            local cp0x = args[idPoints[3]] --[[@as number]]
            local cp0y = args[idPoints[4]] --[[@as number]]
            local cp1x = args[idPoints[5]] --[[@as number]]
            local cp1y = args[idPoints[6]] --[[@as number]]
            local ap1x = args[idPoints[7]] --[[@as number]]
            local ap1y = args[idPoints[8]] --[[@as number]]

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr = wVrf - 1
            local ybr = hVrf - 1

            -- TODO: Seems wasteful to import Utilities file
            -- just to use round function... At the very least
            -- use the Curve2 class if you've got it.
            local ap0xPx = Utilities.round(ap0x * xbr)
            local ap0yPx = ybr - Utilities.round(ap0y * ybr)
            local cp0xPx = Utilities.round(cp0x * xbr)
            local cp0yPx = ybr - Utilities.round(cp0y * ybr)
            local cp1xPx = Utilities.round(cp1x * xbr)
            local cp1yPx = ybr - Utilities.round(cp1y * ybr)
            local ap1xPx = Utilities.round(ap1x * xbr)
            local ap1yPx = ybr - Utilities.round(ap1y * ybr)

            -- Draw curve.
            context.strokeWidth = swCurve
            context.color = curveClrVrf
            context:beginPath()
            -- TODO: Different extrapolate options?
            context:moveTo(0, ap0yPx)
            context:lineTo(ap0xPx, ap0yPx)
            context:cubicTo(
                cp0xPx, cp0yPx,
                cp1xPx, cp1yPx,
                ap1xPx, ap1yPx)
            context:lineTo(xbr, ap1yPx)
            context:stroke()

            -- Draw control point 0 diagnostic stem.
            context.strokeWidth = swCurve
            context.color = cp0ClrVrf
            context:beginPath()
            context:moveTo(ap0xPx, ap0yPx)
            context:lineTo(cp0xPx, cp0yPx)
            context:stroke()

            local cp0Rot = math.atan(cp0y - ap0y, cp0x - ap0x)
            CanvasUtilities.drawPolygon(context, 4, halfRadius,
                ap0xPx, ap0yPx, 0)
            context:fill()
            CanvasUtilities.drawPolygon(context, 3, polyRadius,
                cp0xPx, cp0yPx, cp0Rot)
            context:fill()

            -- Draw control point 1 diagnostic stem.
            context.strokeWidth = swCurve
            context.color = cp1ClrVrf
            context:beginPath()
            context:moveTo(ap1xPx, ap1yPx)
            context:lineTo(cp1xPx, cp1yPx)
            context:stroke()

            local cp1Rot = math.atan(cp1y - ap1y, cp1x - ap1x)
            CanvasUtilities.drawPolygon(context, 4, halfRadius,
                ap1xPx, ap1yPx, 0)
            context:fill()
            CanvasUtilities.drawPolygon(context, 3, polyRadius,
                cp1xPx, cp1yPx, cp1Rot)
            context:fill()
        end,
        onmousedown = onMouseFunc,
        onmousemove = onMouseFunc
    }

    dialog:newrow { always = false }

    -- Create number input widgets.
    local j = 0
    while j < lenIdPoints do
        local isEven = j % 2 ~= 1
        local k = j // 2
        j = j + 1
        local idPoint = idPoints[j]
        local labelPoint = nil
        if isEven then
            labelPoint = labelPoints[1 + k]
        end
        local valuePoint = valuePoints[j]

        dialog:number {
            id = idPoint,
            label = labelPoint,
            text = string.format("%.5f", valuePoint),
            decimals = 5,
            focus = false,
            visible = isVisVrf and visCtrlVrf,
            onchange = function()
                dialog:modify { id = easeFuncsId, option = "CUSTOM" }
                dialog:repaint()
            end
        }
        if not isEven then
            dialog:newrow { always = false }
        end
    end

    dialog:button {
        id = straightButtonId,
        text = "&STRAIGHT",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args = dialog.data
            local ap0x = args[idPoints[1]] --[[@as number]]
            local ap0y = args[idPoints[2]] --[[@as number]]
            local ap1x = args[idPoints[7]] --[[@as number]]
            local ap1y = args[idPoints[8]] --[[@as number]]

            local twoThirds = 2.0 / 3.0
            local oneThird = 1.0 / 3.0

            local cp0x = twoThirds * ap0x + oneThird * ap1x
            local cp0y = twoThirds * ap0y + oneThird * ap1y
            local cp1x = twoThirds * ap1x + oneThird * ap0x
            local cp1y = twoThirds * ap1y + oneThird * ap0y

            dialog:modify { id = idPoints[3], text = string.format("%.5f", cp0x) }
            dialog:modify { id = idPoints[4], text = string.format("%.5f", cp0y) }
            dialog:modify { id = idPoints[5], text = string.format("%.5f", cp1x) }
            dialog:modify { id = idPoints[6], text = string.format("%.5f", cp1y) }

            dialog:repaint()
        end
    }

    dialog:button {
        id = parallelButtonId,
        text = "&PARALLEL",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args = dialog.data
            local ap0x = args[idPoints[1]] --[[@as number]]
            local ap0y = args[idPoints[2]] --[[@as number]]
            local ap1x = args[idPoints[7]] --[[@as number]]
            local ap1y = args[idPoints[8]] --[[@as number]]

            local k = 0.55228474983079
            local l = 1.0 - k

            local cp0x = l * ap0x + k * ap1x
            local cp1x = l * ap1x + k * ap0x

            dialog:modify { id = idPoints[3], text = string.format("%.5f", cp0x) }
            dialog:modify { id = idPoints[4], text = string.format("%.5f", ap0y) }
            dialog:modify { id = idPoints[5], text = string.format("%.5f", cp1x) }
            dialog:modify { id = idPoints[6], text = string.format("%.5f", ap1y) }

            dialog:repaint()
        end
    }

    dialog:button {
        id = flipvButtonId,
        text = "FLIP &V",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args = dialog.data
            local ap0y = args[idPoints[2]] --[[@as number]]
            local cp0y = args[idPoints[4]] --[[@as number]]
            local cp1y = args[idPoints[6]] --[[@as number]]
            local ap1y = args[idPoints[8]] --[[@as number]]

            dialog:modify { id = idPoints[2], text = string.format("%.5f", 1.0 - ap0y) }
            dialog:modify { id = idPoints[4], text = string.format("%.5f", 1.0 - cp0y) }
            dialog:modify { id = idPoints[6], text = string.format("%.5f", 1.0 - cp1y) }
            dialog:modify { id = idPoints[8], text = string.format("%.5f", 1.0 - ap1y) }

            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    dialog:combobox {
        id = easeFuncsId,
        label = "Preset:",
        option = "CUSTOM",
        options = {
            "CUSTOM",
            "CIRC_IN",
            "CIRC_OUT",
            "EASE",
            "EASE_IN",
            "EASE_IN_OUT",
            "EASE_OUT",
            "LINEAR" },
        visible = isVisVrf and visFuncsVrf,
        onchange = function()
            local args = dialog.data
            local easeFunc = args[easeFuncsId] --[[@as string]]

            if easeFunc ~= "CUSTOM" then
                local presetPoints = {
                    0.0, 0.0,
                    0.33333, 0.33333,
                    0.66667, 0.66667,
                    1.0, 1.0 }
                if easeFunc == "EASE" then
                    presetPoints = { 0.0, 0.0, 0.25, 0.1, 0.25, 1.0, 1.0, 1.0 }
                elseif easeFunc == "EASE_IN" then
                    presetPoints = { 0.0, 0.0, 0.42, 0.0, 1.0, 1.0, 1.0, 1.0 }
                elseif easeFunc == "EASE_IN_OUT" then
                    presetPoints = { 0.0, 0.0, 0.42, 0.0, 0.58, 1.0, 1.0, 1.0 }
                elseif easeFunc == "EASE_OUT" then
                    presetPoints = { 0.0, 0.0, 0.0, 0.0, 0.58, 1.0, 1.0, 1.0 }
                elseif easeFunc == "CIRC_IN" then
                    presetPoints = { 0.0, 0.0, 0.0, 0.55228, 0.44772, 1.0, 1.0, 1.0 }
                elseif easeFunc == "CIRC_OUT" then
                    presetPoints = { 0.0, 0.0, 0.55228, 0.0, 1.0, 0.44772, 1.0, 1.0 }
                end

                local i = 0
                while i < lenIdPoints do
                    i = i + 1
                    dialog:modify {
                        id = idPoints[i],
                        text = string.format("%.5f", presetPoints[i])
                    }
                end
                dialog:repaint()
            end
        end
    }

    dialog:newrow { always = false }

    return dialog
end

---Generates the dialog widgets used by a Cartesian
---graph. This includes a canvas, four sliders for
---the signed x axis in and y axis in [-100, 100].
---The ids for these sliders are "xOrig," "yOrig",
---"xDest" and "yDest."
---@param dialog Dialog dialog
---@param id string canvas id
---@param label string canvas label
---@param width integer canvas width
---@param height integer canvas height
---@param isVisible boolean? is visible
---@param visSlide boolean? visible sliders
---@param gridCount integer? grid count
---@param lineColor Color? line color
---@param gridColor Color? grid color
---@param xOrig integer? x origin
---@param yOrig integer? y origin
---@param xDest integer? x destination
---@param yDest integer? y destination
---@return Dialog
function CanvasUtilities.graphLine(
    dialog, id, label, width, height,
    isVisible, visSlide, gridCount,
    xOrig, yOrig, xDest, yDest,
    lineColor, gridColor)
    local gridCountPolar = 16

    local gridClrVrf = gridColor or Color { r = 128, g = 128, b = 128 }
    local lineClrVrf = lineColor or Color { r = 255, g = 255, b = 255 }
    local ydVrf = yDest or 50
    local xdVrf = xDest or 50
    local yoVrf = yOrig or -50
    local xoVrf = xOrig or -50
    local grdCntVrf = gridCount or 5
    local visSlidersVrf = false
    if visSlide then visSlidersVrf = true end
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf = id or "graphCartesian"

    wVrf = math.max(8, wVrf)
    hVrf = math.max(8, hVrf)

    dialog:canvas {
        id = idVrf,
        label = label,
        width = wVrf,
        height = hVrf,
        visible = isVisVrf,
        autoScaling = false,
        onpaint = function(event)
            local context = event.context

            CanvasUtilities.drawGrid(context, grdCntVrf,
                wVrf, hVrf, gridClrVrf, 1)

            -- Unpack arguments.
            local args = dialog.data
            local xo100 = args.xOrig --[[@as integer]]
            local yo100 = args.yOrig --[[@as integer]]
            local xd100 = args.xDest --[[@as integer]]
            local yd100 = args.yDest --[[@as integer]]

            -- Convert from [-100, 100] to [-1.0, 1.0].
            local xoSigned = xo100 * 0.01
            local yoSigned = yo100 * 0.01
            local xdSigned = xd100 * 0.01
            local ydSigned = yd100 * 0.01

            -- Convert from [-1.0, 1.0] to [0.0, 1.0].
            local xoUnsigned = xoSigned * 0.5 + 0.5
            local yoUnsigned = 0.5 - yoSigned * 0.5
            local xdUnsigned = xdSigned * 0.5 + 0.5
            local ydUnsigned = 0.5 - ydSigned * 0.5

            -- Convert from [0.0, 1.0] to canvas pixels.
            local ybr = hVrf - 1
            local xbr = wVrf - 1
            local xoPx = math.floor(xoUnsigned * xbr + 0.5)
            local yoPx = math.floor(yoUnsigned * ybr + 0.5)
            local xdPx = math.floor(xdUnsigned * xbr + 0.5)
            local ydPx = math.floor(ydUnsigned * ybr + 0.5)

            -- Set context style.
            context.antialias = true
            context.color = lineClrVrf
            context.strokeWidth = 2

            -- Draw line.
            context:beginPath()
            context:moveTo(xoPx, yoPx)
            context:lineTo(xdPx, ydPx)
            context:stroke()

            -- Subtract origin from dest to create vector.
            -- Find heading of vector.
            local xVec = xdSigned - xoSigned
            local yVec = ydSigned - yoSigned
            local rot = math.atan(yVec, xVec)

            local screenScale = app.preferences.general.screen_scale
            local polyRadius = 4 * context.strokeWidth / screenScale
            CanvasUtilities.drawPolygon(context, 4, polyRadius, xoPx, yoPx, rot)
            context:fill()
            CanvasUtilities.drawPolygon(context, 3, polyRadius, xdPx, ydPx, rot)
            context:fill()
        end,
        onmousemove = function(event)
            -- TODO: How to handle canvas resize.
            if event.button ~= MouseButton.NONE then
                local xMouse = math.min(math.max(event.x, 0), wVrf - 1)
                local yMouse = math.min(math.max(event.y, 0), hVrf - 1)
                local xdUnsigned = xMouse / (wVrf - 1.0)
                local ydUnsigned = yMouse / (hVrf - 1.0)
                local xdSigned = xdUnsigned + xdUnsigned - 1.0
                local ydSigned = 1.0 - (ydUnsigned + ydUnsigned)

                -- Quantize angle if the shift key is held down.
                if event.shiftKey then
                    -- Get the origin, convert from [-100, 100] to [-1.0, 1.0].
                    local args = dialog.data
                    local xo100 = args.xOrig --[[@as integer]]
                    local yo100 = args.yOrig --[[@as integer]]
                    local xoSigned = xo100 * 0.01
                    local yoSigned = yo100 * 0.01

                    -- Find the difference from destination to origin
                    -- as a vector.
                    local xDiff = xdSigned - xoSigned
                    local yDiff = ydSigned - yoSigned

                    -- Find the square magnitude of the vector, i.e.,
                    -- the vector's dot product with itself.
                    local sqMag = xDiff * xDiff + yDiff * yDiff
                    if sqMag > 0.000001 then
                        -- Convert vector from Cartesian to polar coordinates.
                        local mag = math.sqrt(sqMag)
                        local angle = math.atan(yDiff, xDiff)

                        -- Convert angle from [-pi, pi] to [-0.5, 0.5],
                        -- quantize, then convert back to original range.
                        local quantAngle = 6.2831853071796 * Utilities.quantizeSigned(
                            angle * 0.1591549430919, gridCountPolar)

                        -- Convert vector from polar to Cartesian coordinates,
                        -- add to the origin to convert vector to point.
                        local cosqa = math.cos(quantAngle)
                        local sinqa = math.sin(quantAngle)
                        local xdPolar = cosqa * mag + xoSigned
                        local ydPolar = sinqa * mag + yoSigned

                        xdSigned = xdPolar
                        ydSigned = ydPolar
                    end
                end

                if event.ctrlKey then
                    local halfCart = grdCntVrf // 2
                    xdSigned = Utilities.quantizeSigned(xdSigned, halfCart)
                    ydSigned = Utilities.quantizeSigned(ydSigned, halfCart)
                end

                local xi = Utilities.round(xdSigned * 100.0)
                local yi = Utilities.round(ydSigned * 100.0)
                dialog:modify { id = "xDest", value = xi }
                dialog:modify { id = "yDest", value = yi }
                dialog:repaint()
            end
        end,
        onmousedown = function(event)
            -- TODO: How to handle canvas resize.

            local xMouse = math.min(math.max(event.x, 0), wVrf - 1)
            local yMouse = math.min(math.max(event.y, 0), hVrf - 1)
            local xUnsigned = xMouse / (wVrf - 1.0)
            local yUnsigned = yMouse / (hVrf - 1.0)
            local xSigned = xUnsigned + xUnsigned - 1.0
            local ySigned = 1.0 - (yUnsigned + yUnsigned)

            if event.ctrlKey then
                local halfCart = grdCntVrf // 2
                xSigned = Utilities.quantizeSigned(xSigned, halfCart)
                ySigned = Utilities.quantizeSigned(ySigned, halfCart)
            end

            local xi = Utilities.round(xSigned * 100.0)
            local yi = Utilities.round(ySigned * 100.0)
            dialog:modify { id = "xOrig", value = xi }
            dialog:modify { id = "yOrig", value = yi }
            dialog:modify { id = "xDest", value = xi }
            dialog:modify { id = "yDest", value = yi }
            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    dialog:slider {
        id = "xOrig",
        label = "Orig:",
        min = -100,
        max = 100,
        value = xoVrf,
        focus = false,
        visible = isVisVrf and visSlidersVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:slider {
        id = "yOrig",
        min = -100,
        max = 100,
        value = yoVrf,
        focus = false,
        visible = isVisVrf and visSlidersVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    dialog:slider {
        id = "xDest",
        label = "Dest:",
        min = -100,
        max = 100,
        value = xdVrf,
        focus = false,
        visible = isVisVrf and visSlidersVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:slider {
        id = "yDest",
        min = -100,
        max = 100,
        value = ydVrf,
        focus = false,
        visible = isVisVrf and visSlidersVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    return dialog
end

---Generates the dialog widgets used by an HSL
---spectrum. This includes a canvas and 4 numbers.
---The ids for these numbers are "spectrumHue",
---"spectrumChroma", "spectrumLight" and
---"spectrumAlpha".
---@param dialog Dialog dialog
---@param id string canvas id
---@param label string canvas label
---@param width integer canvas weight
---@param height integer canvas height
---@param isVisible boolean? is visible
---@param lDef number? lightness default
---@param cDef number? chroma default
---@param hDef number? hue default
---@param aDef number? alpha default
---@return Dialog
function CanvasUtilities.spectrum(
    dialog, id, label, width, height,
    isVisible, lDef, cDef, hDef, aDef)
    local aDefVrf = aDef or 1.0
    local hDefVrf = hDef or 0.0
    local cDefVrf = cDef or 67.5
    local lDefVrf = lDef or 50.0

    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf = id or "spectrum"

    wVrf = math.max(8, wVrf)
    hVrf = math.max(8, hVrf)

    local spectrumHeight = math.floor(0.5 + hVrf * (40.0 / 56.0))
    local chrBarHeight = math.floor(0.5 + hVrf * (8.0 / 56.0))
    local alphaBarHeight = chrBarHeight
    local chrBarThresh = spectrumHeight + chrBarHeight

    local xToAlph01 = 1.0 / (wVrf - 1.0)
    local xToAlpha255 = 255.0 / (wVrf - 1.0)
    local yToLgt = 100.0 / (spectrumHeight - 1.0)
    local xToChr = 135.0 / (wVrf - 1.0)
    local xToHue = 1.0 / wVrf

    local inSpectrum = false
    local inChrBar = false
    local inAlphaBar = false

    ---@param event MouseEvent
    local onMouseFunc = function(event)
        local xMouse = event.x
        local yMouse = event.y

        if inSpectrum or
            (not (inChrBar or inAlphaBar)
                and yMouse > 0
                and yMouse < spectrumHeight) then
            inSpectrum = true

            local hMouse = (xMouse * xToHue) % 1.0
            local lMouse = math.min(math.max(
                100.0 - yMouse * yToLgt, 0.0), 100.0)
            dialog:modify {
                id = "spectrumHue",
                text = string.format("%.5f", hMouse)
            }
            dialog:modify {
                id = "spectrumLight",
                text = string.format("%.5f", lMouse)
            }
        end

        if inChrBar or
            (not (inSpectrum or inAlphaBar)
                and yMouse >= spectrumHeight
                and yMouse < chrBarThresh) then
            inChrBar = true

            local sMouse = math.min(math.max(
                xMouse * xToChr, 0.0), 135.0)
            dialog:modify {
                id = "spectrumChroma",
                text = string.format("%.5f", sMouse)
            }
        end

        if inAlphaBar or
            (not (inSpectrum or inChrBar)
                and yMouse >= chrBarThresh
                and yMouse < hVrf) then
            inAlphaBar = true

            local alphaf = math.min(math.max(
                xMouse * xToAlph01, 0.0), 1.0)
            dialog:modify {
                id = "spectrumAlpha",
                text = string.format("%.5f", alphaf)
            }
        end

        dialog:repaint()
    end

    dialog:canvas {
        id = idVrf,
        label = label,
        width = wVrf,
        height = hVrf,
        visible = isVisVrf,
        autoScaling = false,
        onpaint = function(event)
            local context = event.context

            local args = dialog.data
            local lActive = args.spectrumLight --[[@as number]]
            local cActive = args.spectrumChroma --[[@as number]]
            local hActive = args.spectrumHue --[[@as number]]
            local aActive = args.spectrumAlpha --[[@as number]]

            local floor = math.floor
            local lchTosRgb = Clr.srLchTosRgb
            local toHex = Clr.toHex

            local image = Image(wVrf, hVrf)
            local pxItr = image:pixels()
            for pixel in pxItr do
                local x = pixel.x
                local y = pixel.y
                if y < spectrumHeight then
                    local l = 100.0 - y * yToLgt
                    local h = x * xToHue
                    local clr = lchTosRgb(l, cActive, h, 1.0)
                    pixel(toHex(clr))
                elseif y < chrBarThresh then
                    local c = x * xToChr
                    local clr = lchTosRgb(lActive, c, hActive, 1.0)
                    pixel(toHex(clr))
                else
                    local v = floor(x * xToAlpha255 + 0.5)
                    pixel(0xff000000 | v << 0x10 | v << 0x08 | v)
                end
            end
            context:drawImage(image, 0, 0)

            local black = Color { r = 0, g = 0, b = 0, a = 255 }
            local white = Color { r = 255, g = 255, b = 255, a = 255 }
            local reticleSize = 4
            local retHalfSize = reticleSize * 0.5

            if lActive > 0.5 then
                context.color = black
            else
                context.color = white
            end
            context:strokeRect(
                Rectangle(
                    math.floor(hActive / xToHue - retHalfSize),
                    math.floor((100.0 - lActive) / yToLgt - retHalfSize),
                    reticleSize, reticleSize))

            context:strokeRect(
                Rectangle(
                    math.floor(cActive / xToChr - retHalfSize),
                    math.floor(spectrumHeight + chrBarHeight * 0.5 - retHalfSize),
                    reticleSize, reticleSize))

            if aActive > 0.5 then
                context.color = black
            else
                context.color = white
            end
            context:strokeRect(
                Rectangle(
                    math.floor(aActive / xToAlph01 - retHalfSize),
                    math.floor(chrBarThresh + alphaBarHeight * 0.5 - retHalfSize),
                    reticleSize, reticleSize))
        end,
        onmousedown = function(event)
            onMouseFunc(event)
        end,
        onmousemove = function(event)
            if event.button ~= MouseButton.NONE then
                onMouseFunc(event)
            end
        end,
        onmouseup = function(event)
            onMouseFunc(event)
            inSpectrum = false
            inChrBar = false
            inAlphaBar = false
        end
    }

    -- TODO: These ids should be formatted based
    -- on the overall id to avoid contamination
    -- in case you have multiple widgets in one
    -- dialog.
    dialog:number {
        id = "spectrumLight",
        label = "Lightness:",
        text = string.format("%.5f", lDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumChroma",
        label = "Saturation:",
        text = string.format("%.5f", cDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumHue",
        label = "Hue:",
        text = string.format("%.5f", hDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumAlpha",
        label = "Alpha:",
        text = string.format("%.5f", aDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:newrow { always = false }

    return dialog
end

return CanvasUtilities