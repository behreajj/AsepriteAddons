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
---@param visFuncs boolean? visible functions
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
    isVisible, visCtrl, visFuncs, gridCount,
    cp0xDef, cp0yDef, cp1xDef, cp1yDef,
    curveColor, gridColor, cp0Color, cp1Color)
    -- Constants.
    local screenScale = app.preferences.general.screen_scale
    local swCurve = 2
    local hotSpot = 16 / screenScale
    local hotSpotSq = hotSpot * hotSpot
    local polyRadius = 4 * swCurve / screenScale

    -- Verify arguments.
    local cp1ClrVrf = cp1Color or Color { r = 0, g = 132, b = 159 }
    local cp0ClrVrf = cp0Color or Color { r = 168, g = 0, b = 51 }
    local gridClrVrf = gridColor or Color { r = 128, g = 128, b = 128 }
    local curveClrVrf = curveColor or Color { r = 255, g = 255, b = 255 }

    local cp1yVrf = cp1yDef or 1.0
    local cp1xVrf = cp1xDef or 0.58
    local cp0yVrf = cp0yDef or 0.0
    local cp0xVrf = cp0xDef or 0.42

    local grdCntVrf = gridCount or 5
    local visFuncsVrf = false
    if visFuncs then visFuncsVrf = true end
    local visCtrlVrf = false
    if visCtrl then visCtrlVrf = true end
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf = id or "graphBezier"

    ---@param event MouseEvent
    local onMouseFunc = function(event)
        -- TODO: How to handle canvas resize.
        if event.button ~= MouseButton.NONE then
            -- Unpack mouse event coordinates.
            local xMouse = event.x
            local yMouse = event.y

            -- Unpack arguments.
            local args = dialog.data
            local cp0x = args.cp0x --[[@as number]]
            local cp0y = args.cp0y --[[@as number]]
            local cp1x = args.cp1x --[[@as number]]
            local cp1y = args.cp1y --[[@as number]]

            -- Clamp x control points to [0.0, 1.0].
            cp0x = math.min(math.max(cp0x, 0.0), 1.0)
            cp1x = math.min(math.max(cp1x, 0.0), 1.0)

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr = wVrf - 1
            local ybr = hVrf - 1

            -- Test if mouse is near control point 0.
            local cp0xPx = Utilities.round(cp0x * xbr)
            local cp0yPx = ybr - Utilities.round(cp0y * ybr)
            local xCp0Diff = cp0xPx - xMouse
            local yCp0Diff = cp0yPx - yMouse
            local cp0dSqMag = xCp0Diff * xCp0Diff + yCp0Diff * yCp0Diff
            if cp0dSqMag < hotSpotSq then
                -- Convert mouse coordinate to [0.0, 1.0].
                -- Flip y axis.
                local x01 = xMouse / xbr
                local y01 = (ybr - yMouse) / ybr

                -- Clamp coordinates.
                x01 = math.min(math.max(x01, 0.0), 1.0)
                y01 = math.min(math.max(y01, 0.0), 1.0)

                -- Modify number input widgets. Repaint canvas.
                dialog:modify { id = "cp0x", text = string.format("%.5f", x01) }
                dialog:modify { id = "cp0y", text = string.format("%.5f", y01) }
                dialog:repaint()
                return
            end

            -- Test if mouse is near control point 1.
            local cp1xPx = Utilities.round(cp1x * xbr)
            local cp1yPx = ybr - Utilities.round(cp1y * ybr)
            local xCp1Diff = cp1xPx - xMouse
            local yCp1Diff = cp1yPx - yMouse
            local cp1dSqMag = xCp1Diff * xCp1Diff + yCp1Diff * yCp1Diff
            if cp1dSqMag < hotSpotSq then
                local x01 = xMouse / xbr
                local y01 = (ybr - yMouse) / ybr
                x01 = math.min(math.max(x01, 0.0), 1.0)
                y01 = math.min(math.max(y01, 0.0), 1.0)
                dialog:modify { id = "cp1x", text = string.format("%.5f", x01) }
                dialog:modify { id = "cp1y", text = string.format("%.5f", y01) }
                dialog:repaint()
                return
            end
        end
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

            -- Draw grid, then set antialiasing to
            -- true afterward.
            CanvasUtilities.drawGrid(context, grdCntVrf,
                wVrf, hVrf, gridClrVrf, 1)
            context.antialias = true

            -- Unpack arguments.
            local args = dialog.data
            local cp0x = args.cp0x --[[@as number]]
            local cp0y = args.cp0y --[[@as number]]
            local cp1x = args.cp1x --[[@as number]]
            local cp1y = args.cp1y --[[@as number]]

            -- Clamp x control points to [0.0, 1.0].
            cp0x = math.min(math.max(cp0x, 0.0), 1.0)
            cp1x = math.min(math.max(cp1x, 0.0), 1.0)

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr = wVrf - 1
            local ybr = hVrf - 1

            local ap0xPx = 0
            local ap0yPx = ybr
            local cp0xPx = Utilities.round(cp0x * xbr)
            local cp0yPx = ybr - Utilities.round(cp0y * ybr)
            local cp1xPx = Utilities.round(cp1x * xbr)
            local cp1yPx = ybr - Utilities.round(cp1y * ybr)
            local ap1xPx = xbr
            local ap1yPx = 0

            -- Draw curve.
            context.strokeWidth = swCurve
            context.color = curveClrVrf
            context:beginPath()
            context:moveTo(ap0xPx, ap0yPx)
            context:cubicTo(
                cp0xPx, cp0yPx,
                cp1xPx, cp1yPx,
                ap1xPx, ap1yPx)
            context:stroke()

            -- Draw control point 0 diagnostic stem.
            context.strokeWidth = swCurve
            context.color = cp0ClrVrf
            context:beginPath()
            context:moveTo(ap0xPx, ap0yPx)
            context:lineTo(cp0xPx, cp0yPx)
            context:stroke()

            local cp0Rot = math.atan(cp0y, cp0x)
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

            local cp1Rot = math.atan(cp1y - 1.0, cp1x - 1.0)
            CanvasUtilities.drawPolygon(context, 3, polyRadius,
                cp1xPx, cp1yPx, cp1Rot)
            context:fill()
        end,
        onmousedown = onMouseFunc,
        onmousemove = onMouseFunc
    }

    dialog:newrow { always = false }

    dialog:number {
        id = "cp0x",
        label = "Control 0:",
        text = string.format("%.5f", cp0xVrf),
        decimals = 5,
        focus = false,
        visible = isVisVrf and visCtrlVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:number {
        id = "cp0y",
        text = string.format("%.5f", cp0yVrf),
        decimals = 5,
        focus = false,
        visible = isVisVrf and visCtrlVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    dialog:number {
        id = "cp1x",
        label = "Control 1:",
        text = string.format("%.5f", cp1xVrf),
        decimals = 5,
        focus = false,
        visible = isVisVrf and visCtrlVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:number {
        id = "cp1y",
        text = string.format("%.5f", cp1yVrf),
        decimals = 5,
        focus = false,
        visible = isVisVrf and visCtrlVrf,
        onchange = function()
            dialog:repaint()
        end
    }

    dialog:combobox {
        id = "easeFuncs",
        label = "Function:",
        option = "CUSTOM",
        options = {
            "CUSTOM",
            "EASE",
            "EASE_IN",
            "EASE_IN_OUT",
            "EASE_OUT",
            "LINEAR" },
        visible = isVisVrf and visFuncsVrf,
        onchange = function()
            local args = dialog.data
            local easeFunc = args.easeFuncs --[[@as string]]
            if easeFunc == "EASE" then
                dialog:modify { id = "cp0x", text = string.format("%.2f", 0.25) }
                dialog:modify { id = "cp0y", text = string.format("%.1f", 0.1) }
                dialog:modify { id = "cp1x", text = string.format("%.2f", 0.25) }
                dialog:modify { id = "cp1y", text = string.format("%.1f", 1.0) }
            elseif easeFunc == "EASE_IN" then
                dialog:modify { id = "cp0x", text = string.format("%.2f", 0.42) }
                dialog:modify { id = "cp0y", text = string.format("%.1f", 0.0) }
                dialog:modify { id = "cp1x", text = string.format("%.1f", 1.0) }
                dialog:modify { id = "cp1y", text = string.format("%.1f", 1.0) }
            elseif easeFunc == "EASE_IN_OUT" then
                dialog:modify { id = "cp0x", text = string.format("%.2f", 0.42) }
                dialog:modify { id = "cp0y", text = string.format("%.1f", 0.0) }
                dialog:modify { id = "cp1x", text = string.format("%.2f", 0.58) }
                dialog:modify { id = "cp1y", text = string.format("%.1f", 1.0) }
            elseif easeFunc == "EASE_OUT" then
                dialog:modify { id = "cp0x", text = string.format("%.1f", 0.0) }
                dialog:modify { id = "cp0y", text = string.format("%.1f", 0.0) }
                dialog:modify { id = "cp1x", text = string.format("%.2f", 0.58) }
                dialog:modify { id = "cp1y", text = string.format("%.1f", 1.0) }
            elseif easeFunc == "LINEAR" then
                dialog:modify { id = "cp0x", text = string.format("%.5f", 0.33333) }
                dialog:modify { id = "cp0y", text = string.format("%.5f", 0.33333) }
                dialog:modify { id = "cp1x", text = string.format("%.5f", 0.66667) }
                dialog:modify { id = "cp1y", text = string.format("%.5f", 0.66667) }
            end
            dialog:repaint()
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
---"spectrumSat", "spectrumLight" and
---"spectrumAlpha".
---@param dialog Dialog dialog
---@param id string canvas id
---@param label string canvas label
---@param width integer canvas weight
---@param height integer canvas height
---@param isVisible boolean? is visible
---@param hDef number? hue default
---@param sDef number? saturation default
---@param lDef number? lightness default
---@param aDef number? alpha default
---@return Dialog
function CanvasUtilities.spectrum(
    dialog, id, label, width, height,
    isVisible, hDef, sDef, lDef, aDef)
    local aDefVrf = aDef or 255
    local lDefVrf = lDef or 0.5
    local sDefVrf = sDef or 1.0
    local hDefVrf = hDef or 0.0
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf = id or "spectrum"

    wVrf = math.max(8, wVrf)
    hVrf = math.max(8, hVrf)

    local spectrumHeight = math.floor(0.5 + hVrf * (40.0 / 56.0))
    local satBarHeight = math.floor(0.5 + hVrf * (8.0 / 56.0))
    local alphaBarHeight = satBarHeight
    local satBarThresh = spectrumHeight + satBarHeight

    local xToHue = 360.0 / wVrf
    local xToSat = 1.0 / (wVrf - 1.0)
    local xToVal = 255.0 / (wVrf - 1.0)
    local yToLgt = 1.0 / (spectrumHeight - 1.0)

    local inSpectrum = false
    local inSatBar = false
    local inAlphaBar = false

    ---@param event MouseEvent
    local onMouseFunc = function(event)
        local xMouse = event.x
        local yMouse = event.y

        if inSpectrum or
            (not (inSatBar or inAlphaBar)
            and yMouse > 0
            and yMouse < spectrumHeight) then
            inSpectrum = true

            local hMouse = (xMouse * xToHue) % 360.0
            local lMouse = math.min(math.max(
                1.0 - yMouse * yToLgt, 0.0), 1.0)
            dialog:modify {
                id = "spectrumHue",
                text = string.format("%.5f", hMouse)
            }
            dialog:modify {
                id = "spectrumLight",
                text = string.format("%.5f", lMouse)
            }
        end

        if inSatBar or
            (not (inSpectrum or inAlphaBar)
            and yMouse >= spectrumHeight
            and yMouse < satBarThresh) then
            inSatBar = true

            local sMouse = math.min(math.max(
                xMouse * xToSat, 0.0), 1.0)
            dialog:modify {
                id = "spectrumSat",
                text = string.format("%.5f", sMouse)
            }
        end

        if inAlphaBar or
            (not (inSpectrum or inSatBar)
            and yMouse >= satBarThresh
            and yMouse < hVrf) then
            inAlphaBar = true

            local alphaf = math.min(math.max(
                xMouse * xToVal, 0.0), 255.0)
            local alphai = math.floor(alphaf + 0.5)
            dialog:modify {
                id = "spectrumAlpha",
                text = string.format("%d", alphai)
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
            local hActive = args.spectrumHue --[[@as number]]
            local sActive = args.spectrumSat --[[@as number]]
            local lActive = args.spectrumLight --[[@as number]]
            local aActive = args.spectrumAlpha --[[@as number]]

            local floor = math.floor
            local image = Image(wVrf, hVrf)
            local pxItr = image:pixels()
            for pixel in pxItr do
                local x = pixel.x
                local y = pixel.y
                if y < spectrumHeight then
                    pixel(Color {
                            hue = x * xToHue,
                            saturation = sActive,
                            lightness = 1.0 - y * yToLgt,
                            alpha = 255 }
                        .rgbaPixel)
                elseif y < satBarThresh then
                    pixel(Color {
                            hue = hActive,
                            saturation = x * xToSat,
                            lightness = lActive,
                            alpha = 255 }
                        .rgbaPixel)
                else
                    local v = floor(x * xToVal + 0.5)
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
                    math.floor((1.0 - lActive) / yToLgt - retHalfSize),
                    reticleSize, reticleSize))

            context:strokeRect(
                Rectangle(
                    math.floor(sActive / xToSat - retHalfSize),
                    math.floor(spectrumHeight + satBarHeight * 0.5 - retHalfSize),
                    reticleSize, reticleSize))

            if aActive > 127.5 then
                context.color = black
            else
                context.color = white
            end
            context:strokeRect(
                Rectangle(
                    math.floor(aActive / xToVal - retHalfSize),
                    math.floor(satBarThresh + alphaBarHeight * 0.5 - retHalfSize),
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
            inSatBar = false
            inAlphaBar = false
        end
    }

    -- TODO: These ids should be formatted based
    -- on the overall id to avoid contamination
    -- in case you have multiple widgets in one
    -- dialog.
    dialog:number {
        id = "spectrumHue",
        label = "Hue:",
        text = string.format("%.5f", hDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumSat",
        label = "Saturation:",
        text = string.format("%.5f", sDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumLight",
        label = "Lightness:",
        text = string.format("%.5f", lDefVrf),
        decimals = 5,
        focus = false,
        visible = false
    }

    dialog:number {
        id = "spectrumAlpha",
        label = "Alpha:",
        text = string.format("%d", aDefVrf),
        decimals = 0,
        focus = false,
        visible = false
    }

    dialog:newrow { always = false }

    return dialog
end

return CanvasUtilities