dofile("./aseutilities.lua")

ShapeUtilities = {}
ShapeUtilities.__index = ShapeUtilities

setmetatable(ShapeUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws a curve in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param curve Curve2 curve
---@param resolution integer curve resolution
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param brsh Brush brush
---@param cel Cel cel
---@param layer Layer layer
function ShapeUtilities.drawCurve2(
    curve, resolution,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)
    local vres = 2
    if resolution > 2 then vres = resolution end

    local toPoint = AseUtilities.vec2ToPoint
    local bezier = Vec2.bezierPoint

    local isLoop = curve.closedLoop
    local kns = curve.knots
    local knsLen = #kns
    local toPercent = 1.0 / vres
    local start = 2
    local prevKnot = kns[1]
    if isLoop then
        start = 1
        prevKnot = kns[knsLen]
    end

    ---@type Point[]
    local pts = {}
    local h = start - 1
    local j = 0
    while h < knsLen do
        h = h + 1
        local currKnot = kns[h]

        local coPrev = prevKnot.co
        local fhPrev = prevKnot.fh
        local rhNext = currKnot.rh
        local coNext = currKnot.co

        j = j + 1
        pts[j] = toPoint(coPrev)
        local i = 0
        while i < vres do
            i = i + 1
            j = j + 1
            pts[j] = toPoint(bezier(
                coPrev, fhPrev,
                rhNext, coNext,
                i * toPercent))
        end

        prevKnot = currKnot
    end

    -- Draw fill.
    local useTool = app.useTool
    if isLoop and useFill then
        app.transaction("Draw Curve Fill", function()
            useTool {
                tool = "contour",
                color = fillClr,
                brush = brsh,
                points = pts,
                cel = cel,
                layer = layer,
                freehandAlgorithm = 1
            }
        end)
    end

    -- Draw stroke.
    if useStroke then
        app.transaction("Draw Curve Stroke", function()
            local ptPrev = pts[1]
            local ptsLen = #pts
            if isLoop then
                ptPrev = pts[ptsLen]
            end

            local k = start - 1
            while k < ptsLen do
                k = k + 1
                local ptCurr = pts[k]
                useTool {
                    tool = "line",
                    color = strokeClr,
                    brush = brsh,
                    points = { ptPrev, ptCurr },
                    cel = cel,
                    layer = layer,
                    freehandAlgorithm = 1
                }
                ptPrev = ptCurr
            end
        end)
    end
end

---Draws the knot handles of a curve.
---Color arguments are optional.
---@param curve Curve2 curve
---@param cel Cel cel
---@param layer Layer layer
---@param lnClr Color? line color
---@param coClr Color? coordinate color
---@param fhClr Color? fore handle color
---@param rhClr Color? rear handle color
function ShapeUtilities.drawHandles2(
    curve, cel, layer,
    lnClr, coClr, fhClr, rhClr)
    local kns = curve.knots
    local knsLen = #kns
    local drawKnot = ShapeUtilities.drawKnot2
    app.transaction("Draw Curve Handles", function()
        local i = 0
        while i < knsLen do
            i = i + 1
            drawKnot(
                kns[i], cel, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes.
---Color arguments are optional.
---@param knot Knot2 knot
---@param cel Cel cel
---@param layer Layer layer
---@param lnClr Color? line color
---@param coClr Color? coordinate color
---@param fhClr Color? fore handle color
---@param rhClr Color? rear handle color
function ShapeUtilities.drawKnot2(
    knot, cel, layer,
    lnClr, coClr, fhClr, rhClr)
    local lnClrVal = lnClr or Color { r = 175, g = 175, b = 175 }
    local rhClrVal = rhClr or Color { r = 2, g = 167, b = 235 }
    local coClrVal = coClr or Color { r = 235, g = 225, b = 40 }
    local fhClrVal = fhClr or Color { r = 235, g = 26, b = 64 }

    local lnBrush = Brush { size = 1 }
    local rhBrush = Brush { size = 4 }
    local coBrush = Brush { size = 6 }
    local fhBrush = Brush { size = 5 }

    local coPt = AseUtilities.vec2ToPoint(knot.co)
    local fhPt = AseUtilities.vec2ToPoint(knot.fh)
    local rhPt = AseUtilities.vec2ToPoint(knot.rh)

    app.transaction("Draw Knot Handles", function()
        -- Line from rear handle to coordinate.
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            cel = cel,
            layer = layer
        }

        -- Line from coordinate to fore handle.
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            cel = cel,
            layer = layer
        }

        -- Rear handle point.
        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            cel = cel,
            layer = layer
        }

        -- Coordinate point.
        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            cel = cel,
            layer = layer
        }

        -- Fore handle point.
        app.useTool {
            tool = "pencil",
            color = fhClrVal,
            brush = fhBrush,
            points = { fhPt },
            cel = cel,
            layer = layer
        }
    end)
end

---Draws a mesh in Aseprite with the contour tool.
---If a stroke is used, draws the stroke line by line.
---@param mesh Mesh2 mesh
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param brsh Brush brush
---@param cel Cel cel
---@param layer Layer layer
function ShapeUtilities.drawMesh2(
    mesh,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, cel, layer)
    -- Convert Vec2s to Points.
    ---@type Point[]
    local pts = {}
    local vs = mesh.vs
    local vsLen = #vs
    local toPt = AseUtilities.vec2ToPoint
    local idx0 = 0
    while idx0 < vsLen do
        idx0 = idx0 + 1
        pts[idx0] = toPt(vs[idx0])
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    ---@type Point[][]
    local ptsGrouped = {}
    local idx1 = 0
    while idx1 < fsLen do
        idx1 = idx1 + 1
        local f = fs[idx1]
        local fLen = #f
        ---@type Point[]
        local ptsFace = {}
        local idx2 = 0
        while idx2 < fLen do
            idx2 = idx2 + 1
            ptsFace[idx2] = pts[f[idx2]]
        end
        ptsGrouped[idx1] = ptsFace
    end

    -- Group fills into one transaction.
    local useTool = app.useTool
    if useFill then
        app.transaction("Mesh Fill", function()
            local idx3 = 0
            while idx3 < fsLen do
                idx3 = idx3 + 1
                useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[idx3],
                    cel = cel,
                    layer = layer
                }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction("Mesh Stroke", function()
            local idx4 = 0
            while idx4 < fsLen do
                idx4 = idx4 + 1
                local ptGroup = ptsGrouped[idx4]
                local lenPtGrp = #ptGroup
                local ptPrev = ptGroup[lenPtGrp]
                local idx5 = 0
                while idx5 < lenPtGrp do
                    idx5 = idx5 + 1
                    local ptCurr = ptGroup[idx5]
                    useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        cel = cel,
                        layer = layer
                    }
                    ptPrev = ptCurr
                end
            end
        end)
    end
end

return ShapeUtilities