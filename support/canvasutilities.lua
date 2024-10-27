dofile("./clr.lua")
dofile("./utilities.lua")

CanvasUtilities = {}
CanvasUtilities.__index = CanvasUtilities

setmetatable(CanvasUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws a grid of overlapping horizontal and vertical lines. Turns off
---antialiasing. Sets color and stroke width.
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

    local floor <const> = math.floor

    local xbr <const> = w - 1.0
    local ybr <const> = h - 1.0
    local iToFac <const> = ybr / (count - 1.0)
    local jToFac <const> = xbr / (count - 1.0)

    -- Draw vertical grid lines.
    local i = 0
    while i < count do
        local y <const> = floor(i * iToFac)
        context:beginPath()
        context:moveTo(0, y)
        context:lineTo(xbr, y)
        context:stroke()
        i = i + 1
    end

    -- Draw horizontal grid lines.
    local j = 0
    while j < count do
        local x <const> = floor(j * jToFac)
        context:beginPath()
        context:moveTo(x, 0)
        context:lineTo(x, ybr)
        context:stroke()
        j = j + 1
    end
end

---Draws a polygon on a graphics context. Only creates the shape, does not
---assign fill or stroke. The rotation is expected in radians.
---@param context GraphicsContext canvas
---@param sides integer sides
---@param radius number radius
---@param x number x origin
---@param y number y origin
---@param rotation number? rotation
function CanvasUtilities.drawPolygon(
    context, sides, radius, x, y, rotation)
    local aVrf <const> = rotation or 0.0

    local iToTheta <const> = 6.2831853071796 / sides
    local cos <const> = math.cos
    local sin <const> = math.sin

    context:beginPath()
    context:moveTo(
        cos(aVrf) * radius + x,
        y - sin(aVrf) * radius)
    local i = 0
    while i < sides do
        i = i + 1
        local a <const> = i * iToTheta + aVrf
        context:lineTo(
            cos(a) * radius + x,
            y - sin(a) * radius)
    end
    context:closePath()
end

---Draws a filled reticle on a graphics context. The input factor is expected
---to be in the range [0.0, 1.0]. Draws two triangles on the top and bottom
---tracks of the slider bar.
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
    local x <const> = fac * (barWidth - 1.0)
    local trszvrf <const> = triSize or 3

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

---Generates the dialog widgets used by a Bezier curve. This includes a canvas,
---four number inputs for the two control points x and y coordinate. The ids
---for these sliders are "cp0x," "cp0y", "cp1x" and "cp1y."
---@param dialog Dialog dialog
---@param id string canvas id
---@param label string canvas label
---@param width integer canvas width
---@param height integer canvas height
---@param isVisible boolean? is visible
---@param visNumbers boolean? visible numbers
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
    isVisible, visNumbers, visButtons, visFuncs,
    allowApMove, gridCount,
    cp0xDef, cp0yDef, cp1xDef, cp1yDef,
    curveColor, gridColor, cp0Color, cp1Color)
    local screenScale = 1
    if app.preferences then
        local generalPrefs <const> = app.preferences.general
        if generalPrefs then
            local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
            if ssCand and ssCand > 0 then
                screenScale = ssCand
            end
        end
    end

    -- Constants.
    local swCurve <const> = 2
    local hotSpot <const> = 16 / screenScale
    local hotSpotSq <const> = hotSpot * hotSpot
    local polyRadius <const> = 4 * swCurve / screenScale
    local halfRadius <const> = polyRadius * 0.5

    -- Verify arguments.
    local cp1ClrVrf <const> = cp1Color or Color { r = 0, g = 132, b = 159 }
    local cp0ClrVrf <const> = cp0Color or Color { r = 168, g = 0, b = 51 }
    local gridClrVrf <const> = gridColor or Color { r = 128, g = 128, b = 128 }
    local curveClrVrf <const> = curveColor or Color { r = 255, g = 255, b = 255 }

    local grdCntVrf <const> = gridCount or 5
    local allowApVrf = false
    if allowApMove then allowApVrf = true end
    local visFuncsVrf = false
    if visFuncs then visFuncsVrf = true end
    local visButtonsVrf = false
    if visButtons then visButtonsVrf = true end
    local visNumsVrf = false
    if visNumbers then visNumsVrf = true end
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf <const> = height or 128
    local wVrf <const> = width or 128
    local idVrf <const> = id or "graphBezier"

    -- In case this widget is used more than once in a dialog,
    -- the widget ids need to be distinct from each other.
    local easeFuncsId <const> = idVrf .. "_easeFuncs"
    local fliphButtonId <const> = idVrf .. "_fliph"
    local flipvButtonId <const> = idVrf .. "_flipv"
    local straightButtonId <const> = idVrf .. "_straight"
    local parallelButtonId <const> = idVrf .. "_parallel"

    local idPts <const> = {
        idVrf .. "_ap0x",
        idVrf .. "_ap0y",
        idVrf .. "_cp0x",
        idVrf .. "_cp0y",
        idVrf .. "_cp1x",
        idVrf .. "_cp1y",
        idVrf .. "_ap1x",
        idVrf .. "_ap1y",
    }
    local lenIdPoints <const> = #idPts

    local labelPoints <const> = {
        "Anchor 0:",
        "Control 0:",
        "Control 1:",
        "Anchor 1:"
    }

    local valPts <const> = {
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
    local onMouseFunc <const> = function(event)
        -- TODO: How to handle canvas resize.
        if event.button ~= MouseButton.NONE then
            -- Unpack mouse event coordinates.
            local xMouse <const> = event.x
            local yMouse <const> = event.y

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr <const> = wVrf - 1
            local ybr <const> = hVrf - 1

            -- Convert mouse coordinate to [0.0, 1.0].
            -- Flip y axis.
            local xm01 = xMouse / xbr
            local ym01 = (ybr - yMouse) / ybr

            -- Clamp coordinates.
            xm01 = math.min(math.max(xm01, 0.0), 1.0)
            ym01 = math.min(math.max(ym01, 0.0), 1.0)

            -- Epsilon is inverse of max resolution (64).
            local clampEpsilon <const> = 1.0 / 64.0

            -- Control points take precedence over anchor points
            -- when it comes to selecting for mouse movement.
            ---@type string[][]
            local knotIds <const> = {
                { idPts[1], idPts[2], idPts[3], idPts[4] },
                { idPts[7], idPts[8], idPts[5], idPts[6] }
            }
            local lenKnotIds <const> = #knotIds
            local args <const> = dialog.data

            local i = 0
            while i < lenKnotIds do
                local isEven <const> = (i % 2) ~= 1
                i = i + 1
                local knot <const> = knotIds[i]

                local xAnchorId <const> = knot[1]
                local yAnchorId <const> = knot[2]
                local xAnchor <const> = args[xAnchorId] --[[@as number]]
                local yAnchor <const> = args[yAnchorId] --[[@as number]]

                local xControlId <const> = knot[3]
                local yControlId <const> = knot[4]
                local xControl <const> = args[xControlId] --[[@as number]]
                local yControl <const> = args[yControlId] --[[@as number]]

                local xCtrlPixel <const> = Utilities.round(xControl * xbr)
                local yCtrlPixel <const> = ybr - Utilities.round(yControl * ybr)

                local xCtrlDiff <const> = xCtrlPixel - xMouse
                local yCtrlDiff <const> = yCtrlPixel - yMouse
                local sqMagCtrl <const> = xCtrlDiff * xCtrlDiff + yCtrlDiff * yCtrlDiff
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
                    local xAnchPixel <const> = Utilities.round(xAnchor * xbr)
                    local yAnchPixel <const> = ybr - Utilities.round(yAnchor * ybr)

                    local xAnchDiff <const> = xAnchPixel - xMouse
                    local yAnchDiff <const> = yAnchPixel - yMouse
                    local sqMagAnch <const> = xAnchDiff * xAnchDiff + yAnchDiff * yAnchDiff
                    if sqMagAnch < hotSpotSq then
                        local xCtrlNew <const> = xm01 + (xControl - xAnchor)
                        local yCtrlNew <const> = ym01 + (yControl - yAnchor)
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
        autoscaling = false,
        onpaint = function(event)
            local context <const> = event.context

            -- Draw grid, then set antialiasing to
            -- true afterward.
            CanvasUtilities.drawGrid(context, grdCntVrf,
                wVrf, hVrf, gridClrVrf, 1)
            context.antialias = true

            -- Unpack arguments.
            local args <const> = dialog.data
            local ap0x <const> = args[idPts[1]] --[[@as number]]
            local ap0y <const> = args[idPts[2]] --[[@as number]]
            local cp0x <const> = args[idPts[3]] --[[@as number]]
            local cp0y <const> = args[idPts[4]] --[[@as number]]
            local cp1x <const> = args[idPts[5]] --[[@as number]]
            local cp1y <const> = args[idPts[6]] --[[@as number]]
            local ap1x <const> = args[idPts[7]] --[[@as number]]
            local ap1y <const> = args[idPts[8]] --[[@as number]]

            -- Convert from [0.0, 1.0] to canvas pixels.
            local xbr <const> = wVrf - 1
            local ybr <const> = hVrf - 1

            -- TODO: Seems wasteful to import Utilities file
            -- just to use round function... At the very least
            -- use the Curve2 class if you've got it.
            local ap0xPx <const> = Utilities.round(ap0x * xbr)
            local ap0yPx <const> = ybr - Utilities.round(ap0y * ybr)
            local cp0xPx <const> = Utilities.round(cp0x * xbr)
            local cp0yPx <const> = ybr - Utilities.round(cp0y * ybr)
            local cp1xPx <const> = Utilities.round(cp1x * xbr)
            local cp1yPx <const> = ybr - Utilities.round(cp1y * ybr)
            local ap1xPx <const> = Utilities.round(ap1x * xbr)
            local ap1yPx <const> = ybr - Utilities.round(ap1y * ybr)

            -- Draw curve.
            context.strokeWidth = swCurve
            context.color = curveClrVrf
            context:beginPath()
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

            local cp0Rot <const> = math.atan(cp0y - ap0y, cp0x - ap0x)
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

            local cp1Rot <const> = math.atan(cp1y - ap1y, cp1x - ap1x)
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
        local isEven <const> = j % 2 ~= 1
        local k <const> = j // 2
        j = j + 1
        local idPoint <const> = idPts[j]

        -- This string is nil in order to avoid line breaks between numbers.
        -- A zero length string, "", will trigger a line break.
        local labelPoint = nil
        if isEven then
            labelPoint = labelPoints[1 + k]
        end
        local valuePoint <const> = valPts[j]

        dialog:number {
            id = idPoint,
            ---@diagnostic disable-next-line: assign-type-mismatch
            label = labelPoint,
            text = string.format("%.5f", valuePoint),
            decimals = 5,
            focus = false,
            visible = isVisVrf and visNumsVrf,
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
            local args <const> = dialog.data
            local ap0x <const> = args[idPts[1]] --[[@as number]]
            local ap0y <const> = args[idPts[2]] --[[@as number]]
            local ap1x <const> = args[idPts[7]] --[[@as number]]
            local ap1y <const> = args[idPts[8]] --[[@as number]]

            local twoThirds <const> = 2.0 / 3.0
            local oneThird <const> = 1.0 / 3.0

            local cp0x <const> = twoThirds * ap0x + oneThird * ap1x
            local cp0y <const> = twoThirds * ap0y + oneThird * ap1y
            local cp1x <const> = twoThirds * ap1x + oneThird * ap0x
            local cp1y <const> = twoThirds * ap1y + oneThird * ap0y

            dialog:modify { id = idPts[3], text = string.format("%.5f", cp0x) }
            dialog:modify { id = idPts[4], text = string.format("%.5f", cp0y) }
            dialog:modify { id = idPts[5], text = string.format("%.5f", cp1x) }
            dialog:modify { id = idPts[6], text = string.format("%.5f", cp1y) }
            dialog:modify { id = easeFuncsId, option = "CUSTOM" }

            dialog:repaint()
        end
    }

    dialog:button {
        id = parallelButtonId,
        text = "&PARALLEL",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args <const> = dialog.data
            local ap0x <const> = args[idPts[1]] --[[@as number]]
            local ap0y <const> = args[idPts[2]] --[[@as number]]
            local ap1x <const> = args[idPts[7]] --[[@as number]]
            local ap1y <const> = args[idPts[8]] --[[@as number]]

            local k <const> = 0.55228474983079
            local l <const> = 1.0 - k

            local cp0x <const> = l * ap0x + k * ap1x
            local cp1x <const> = l * ap1x + k * ap0x

            dialog:modify { id = idPts[3], text = string.format("%.5f", cp0x) }
            dialog:modify { id = idPts[4], text = string.format("%.5f", ap0y) }
            dialog:modify { id = idPts[5], text = string.format("%.5f", cp1x) }
            dialog:modify { id = idPts[6], text = string.format("%.5f", ap1y) }
            dialog:modify { id = easeFuncsId, option = "CUSTOM" }

            dialog:repaint()
        end
    }

    dialog:newrow { always = false }

    dialog:button {
        id = fliphButtonId,
        text = "FLIP &H",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args <const> = dialog.data
            local ap0x <const> = args[idPts[1]] --[[@as number]]
            local ap0y <const> = args[idPts[2]] --[[@as number]]
            local cp0x <const> = args[idPts[3]] --[[@as number]]
            local cp0y <const> = args[idPts[4]] --[[@as number]]
            local cp1x <const> = args[idPts[5]] --[[@as number]]
            local cp1y <const> = args[idPts[6]] --[[@as number]]
            local ap1x <const> = args[idPts[7]] --[[@as number]]
            local ap1y <const> = args[idPts[8]] --[[@as number]]

            dialog:modify { id = idPts[1], text = string.format("%.5f", 1.0 - ap1x) }
            dialog:modify { id = idPts[2], text = string.format("%.5f", ap1y) }
            dialog:modify { id = idPts[3], text = string.format("%.5f", 1.0 - cp1x) }
            dialog:modify { id = idPts[4], text = string.format("%.5f", cp1y) }
            dialog:modify { id = idPts[5], text = string.format("%.5f", 1.0 - cp0x) }
            dialog:modify { id = idPts[6], text = string.format("%.5f", cp0y) }
            dialog:modify { id = idPts[7], text = string.format("%.5f", 1.0 - ap0x) }
            dialog:modify { id = idPts[8], text = string.format("%.5f", ap0y) }
            dialog:modify { id = easeFuncsId, option = "CUSTOM" }

            dialog:repaint()
        end
    }

    dialog:button {
        id = flipvButtonId,
        text = "FLIP &V",
        focus = false,
        visible = isVisVrf and visButtonsVrf,
        onclick = function()
            local args <const> = dialog.data
            local ap0y <const> = args[idPts[2]] --[[@as number]]
            local cp0y <const> = args[idPts[4]] --[[@as number]]
            local cp1y <const> = args[idPts[6]] --[[@as number]]
            local ap1y <const> = args[idPts[8]] --[[@as number]]

            dialog:modify { id = idPts[2], text = string.format("%.5f", 1.0 - ap0y) }
            dialog:modify { id = idPts[4], text = string.format("%.5f", 1.0 - cp0y) }
            dialog:modify { id = idPts[6], text = string.format("%.5f", 1.0 - cp1y) }
            dialog:modify { id = idPts[8], text = string.format("%.5f", 1.0 - ap1y) }
            dialog:modify { id = easeFuncsId, option = "CUSTOM" }

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
            local args <const> = dialog.data
            local easeFunc <const> = args[easeFuncsId] --[[@as string]]
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
                        id = idPts[i],
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

---Generates the dialog widgets used by a Cartesian graph. This includes a
---canvas, four sliders for the signed x axis in and y axis in [-100, 100]. The
---ids for these sliders are "xOrig," "yOrig", "xDest" and "yDest."
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

    local gridClrVrf <const> = gridColor or Color { r = 128, g = 128, b = 128 }
    local lineClrVrf <const> = lineColor or Color { r = 255, g = 255, b = 255 }
    local ydVrf <const> = yDest or 50
    local xdVrf <const> = xDest or 50
    local yoVrf <const> = yOrig or -50
    local xoVrf <const> = xOrig or -50
    local grdCntVrf <const> = gridCount or 5
    local visSlidersVrf = false
    if visSlide then visSlidersVrf = true end
    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf = height or 128
    local wVrf = width or 128
    local idVrf <const> = id or "graphCartesian"

    wVrf = math.max(8, wVrf)
    hVrf = math.max(8, hVrf)

    dialog:canvas {
        id = idVrf,
        label = label,
        width = wVrf,
        height = hVrf,
        visible = isVisVrf,
        autoscaling = false,
        onpaint = function(event)
            local context <const> = event.context

            CanvasUtilities.drawGrid(context, grdCntVrf,
                wVrf, hVrf, gridClrVrf, 1)

            -- Unpack arguments.
            local args <const> = dialog.data
            local xo100 <const> = args.xOrig --[[@as integer]]
            local yo100 <const> = args.yOrig --[[@as integer]]
            local xd100 <const> = args.xDest --[[@as integer]]
            local yd100 <const> = args.yDest --[[@as integer]]

            -- Convert from [-100, 100] to [-1.0, 1.0].
            local xoSigned <const> = xo100 * 0.01
            local yoSigned <const> = yo100 * 0.01
            local xdSigned <const> = xd100 * 0.01
            local ydSigned <const> = yd100 * 0.01

            -- Convert from [-1.0, 1.0] to [0.0, 1.0].
            local xoUnsigned <const> = xoSigned * 0.5 + 0.5
            local yoUnsigned <const> = 0.5 - yoSigned * 0.5
            local xdUnsigned <const> = xdSigned * 0.5 + 0.5
            local ydUnsigned <const> = 0.5 - ydSigned * 0.5

            -- Convert from [0.0, 1.0] to canvas pixels.
            local ybr <const> = hVrf - 1
            local xbr <const> = wVrf - 1
            local xoPx <const> = math.floor(xoUnsigned * xbr + 0.5)
            local yoPx <const> = math.floor(yoUnsigned * ybr + 0.5)
            local xdPx <const> = math.floor(xdUnsigned * xbr + 0.5)
            local ydPx <const> = math.floor(ydUnsigned * ybr + 0.5)

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
            local xVec <const> = xdSigned - xoSigned
            local yVec <const> = ydSigned - yoSigned
            local rot <const> = math.atan(yVec, xVec)

            local screenScale = 1
            if app.preferences then
                local generalPrefs <const> = app.preferences.general
                if generalPrefs then
                    local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
                    if ssCand and ssCand > 0 then
                        screenScale = ssCand
                    end
                end
            end

            local polyRadius <const> = 4 * context.strokeWidth / screenScale
            CanvasUtilities.drawPolygon(context, 4, polyRadius, xoPx, yoPx, rot)
            context:fill()
            CanvasUtilities.drawPolygon(context, 3, polyRadius, xdPx, ydPx, rot)
            context:fill()
        end,
        onmousemove = function(event)
            -- TODO: How to handle canvas resize.
            if event.button ~= MouseButton.NONE then
                local xMouse <const> = math.min(math.max(event.x, 0), wVrf - 1)
                local yMouse <const> = math.min(math.max(event.y, 0), hVrf - 1)
                local xdUnsigned <const> = xMouse / (wVrf - 1.0)
                local ydUnsigned <const> = yMouse / (hVrf - 1.0)
                local xdSigned = xdUnsigned + xdUnsigned - 1.0
                local ydSigned = 1.0 - (ydUnsigned + ydUnsigned)

                -- Quantize angle if the shift key is held down.
                if event.shiftKey then
                    -- Get the origin, convert from [-100, 100] to [-1.0, 1.0].
                    local args <const> = dialog.data
                    local xo100 <const> = args.xOrig --[[@as integer]]
                    local yo100 <const> = args.yOrig --[[@as integer]]
                    local xoSigned <const> = xo100 * 0.01
                    local yoSigned <const> = yo100 * 0.01

                    -- Find the difference from destination to origin
                    -- as a vector.
                    local xDiff <const> = xdSigned - xoSigned
                    local yDiff <const> = ydSigned - yoSigned

                    -- Find the square magnitude of the vector, i.e.,
                    -- the vector's dot product with itself.
                    local sqMag <const> = xDiff * xDiff + yDiff * yDiff
                    if sqMag > 0.000001 then
                        -- Convert vector from Cartesian to polar coordinates.
                        local mag <const> = math.sqrt(sqMag)
                        local angle <const> = math.atan(yDiff, xDiff)

                        -- Convert angle from [-pi, pi] to [-0.5, 0.5],
                        -- quantize, then convert back to original range.
                        local quantAngle <const> = 6.2831853071796 * Utilities.quantizeSigned(
                            angle * 0.1591549430919, gridCountPolar)

                        -- Convert vector from polar to Cartesian coordinates,
                        -- add to the origin to convert vector to point.
                        local cosqa <const> = math.cos(quantAngle)
                        local sinqa <const> = math.sin(quantAngle)
                        local xdPolar <const> = cosqa * mag + xoSigned
                        local ydPolar <const> = sinqa * mag + yoSigned

                        xdSigned = xdPolar
                        ydSigned = ydPolar
                    end
                end

                if event.ctrlKey then
                    local halfCart <const> = grdCntVrf // 2
                    xdSigned = Utilities.quantizeSigned(xdSigned, halfCart)
                    ydSigned = Utilities.quantizeSigned(ydSigned, halfCart)
                end

                local xi <const> = Utilities.round(xdSigned * 100.0)
                local yi <const> = Utilities.round(ydSigned * 100.0)
                dialog:modify { id = "xDest", value = xi }
                dialog:modify { id = "yDest", value = yi }
                dialog:repaint()
            end
        end,
        onmousedown = function(event)
            -- TODO: How to handle canvas resize.

            local xMouse <const> = math.min(math.max(event.x, 0), wVrf - 1)
            local yMouse <const> = math.min(math.max(event.y, 0), hVrf - 1)
            local xUnsigned <const> = xMouse / (wVrf - 1.0)
            local yUnsigned <const> = yMouse / (hVrf - 1.0)
            local xSigned = xUnsigned + xUnsigned - 1.0
            local ySigned = 1.0 - (yUnsigned + yUnsigned)

            if event.ctrlKey then
                local halfCart <const> = grdCntVrf // 2
                xSigned = Utilities.quantizeSigned(xSigned, halfCart)
                ySigned = Utilities.quantizeSigned(ySigned, halfCart)
            end

            local xi <const> = Utilities.round(xSigned * 100.0)
            local yi <const> = Utilities.round(ySigned * 100.0)
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

---Generates the dialog widgets used by an LCH spectrum. This includes a canvas
---and 4 numbers. The ids for these numbers are "spectrumHue", "spectrumChroma",
---"spectrumLight" and "spectrumAlpha".
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
    local aDefVrf <const> = aDef or 1.0
    local hDefVrf <const> = hDef or 0.0
    local cDefVrf <const> = cDef or (Clr.SR_LCH_MAX_CHROMA * 0.5)
    local lDefVrf <const> = lDef or 50.0

    local isVisVrf = false
    if isVisible then isVisVrf = true end
    local hVrf <const> = math.max(8, height or 128)
    local wVrf <const> = math.max(8, width or 128)
    local idVrf <const> = id or "spectrum"

    local spectrumHeight <const> = math.floor(0.5 + hVrf * (40.0 / 56.0))
    local chrBarHeight <const> = math.floor(0.5 + hVrf * (8.0 / 56.0))
    local alphaBarHeight <const> = chrBarHeight
    local chrBarThresh <const> = spectrumHeight + chrBarHeight

    local xToAlph01 <const> = 1.0 / (wVrf - 1.0)
    local xToAlpha255 <const> = 255.0 / (wVrf - 1.0)
    local yToLgt <const> = 100.0 / (spectrumHeight - 1.0)
    local xToChr <const> = Clr.SR_LCH_MAX_CHROMA / (wVrf - 1.0)
    local xToHue <const> = 1.0 / wVrf

    local inSpectrum = false
    local inChrBar = false
    local inAlphaBar = false

    ---@param event MouseEvent
    local onMouseFunc <const> = function(event)
        local xMouse <const> = event.x
        local yMouse <const> = event.y

        if inSpectrum or
            (not (inChrBar or inAlphaBar)
                and yMouse > 0
                and yMouse < spectrumHeight) then
            inSpectrum = true

            local hMouse <const> = (xMouse * xToHue) % 1.0
            local lMouse <const> = math.min(math.max(
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

            local sMouse <const> = math.min(math.max(
                xMouse * xToChr, 0.0), Clr.SR_LCH_MAX_CHROMA)
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

            local alphaf <const> = math.min(math.max(
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
        autoscaling = false,
        onpaint = function(event)
            local context <const> = event.context
            context.blendMode = BlendMode.SRC
            context.antialias = false

            local args <const> = dialog.data
            local lActive <const> = args.spectrumLight --[[@as number]]
            local cActive <const> = args.spectrumChroma --[[@as number]]
            local hActive <const> = args.spectrumHue --[[@as number]]
            local aActive <const> = args.spectrumAlpha --[[@as number]]

            local floor <const> = math.floor
            local strpack <const> = string.pack
            local lchTosRgb <const> = Clr.srLchTosRgb
            local toHex <const> = Clr.toHex

            ---@type string[]
            local byteArr <const> = {}
            local areaCanvas <const> = wVrf * hVrf
            local i = 0
            while i < areaCanvas do
                local x <const> = i % wVrf
                local y <const> = i // wVrf

                local hex = 0xff000000
                if y < spectrumHeight then
                    hex = toHex(lchTosRgb(
                        100.0 - y * yToLgt, cActive, x * xToHue, 1.0))
                elseif y < chrBarThresh then
                    hex = toHex(lchTosRgb(
                        lActive, x * xToChr, hActive, 1.0))
                else
                    local v <const> = floor(x * xToAlpha255 + 0.5)
                    hex = 0xff000000 | v << 0x10 | v << 0x08 | v
                end

                i = i + 1
                byteArr[i] = strpack("<I4", hex)
            end

            local image <const> = Image(wVrf, hVrf)
            image.bytes = table.concat(byteArr)
            context:drawImage(image,
                Rectangle(0, 0, wVrf, hVrf),
                Rectangle(0, 0, wVrf, hVrf))

            local black <const> = Color { r = 0, g = 0, b = 0, a = 255 }
            local white <const> = Color { r = 255, g = 255, b = 255, a = 255 }
            local reticleSize <const> = 4
            local retHalfSize <const> = reticleSize * 0.5

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

    -- TODO: These ids should be formatted based on the overall id to avoid
    -- contamination in case you have multiple widgets in one dialog.
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