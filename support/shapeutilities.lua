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
---@param frame Frame frame
---@param layer Layer layer
function ShapeUtilities.drawCurve2(
    curve, resolution,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, frame, layer)
    local vres = 2
    if resolution > 2 then vres = resolution end

    local toPoint <const> = AseUtilities.vec2ToPoint
    local bezier <const> = Vec2.bezierPoint

    local isLoop <const> = curve.closedLoop
    local kns <const> = curve.knots
    local knsLen <const> = #kns
    local toPercent <const> = 1.0 / vres
    local start = 2
    local prevKnot = kns[1]
    if isLoop then
        start = 1
        prevKnot = kns[knsLen]
    end

    ---@type Point[]
    local pts <const> = {}
    local h = start - 1
    local j = 0
    while h < knsLen do
        h = h + 1
        local currKnot <const> = kns[h]

        local coPrev <const> = prevKnot.co
        local fhPrev <const> = prevKnot.fh
        local rhNext <const> = currKnot.rh
        local coNext <const> = currKnot.co

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
    ---@diagnostic disable-next-line: deprecated
    local useTool <const> = app.useTool
    if isLoop and useFill then
        app.transaction("Draw Curve Fill", function()
            useTool {
                tool = "contour",
                color = fillClr,
                brush = brsh,
                points = pts,
                frame = frame,
                layer = layer,
                freehandAlgorithm = 1
            }
        end)
    end

    -- Draw stroke.
    if useStroke then
        app.transaction("Draw Curve Stroke", function()
            local ptPrev = pts[1]
            local ptsLen <const> = #pts
            if isLoop then
                ptPrev = pts[ptsLen]
            end

            local k = start - 1
            while k < ptsLen do
                k = k + 1
                local ptCurr <const> = pts[k]
                useTool {
                    tool = "line",
                    color = strokeClr,
                    brush = brsh,
                    points = { ptPrev, ptCurr },
                    frame = frame,
                    layer = layer,
                    freehandAlgorithm = 1
                }
                ptPrev = ptCurr
            end
        end)
    end
end

---Draws the knot handles of a curve. Color arguments are optional.
---@param curve Curve2 curve
---@param frame Frame frame
---@param layer Layer layer
---@param lnClr Color? line color
---@param coClr Color? coordinate color
---@param fhClr Color? fore handle color
---@param rhClr Color? rear handle color
function ShapeUtilities.drawHandles2(
    curve, frame, layer,
    lnClr, coClr, fhClr, rhClr)
    local kns <const> = curve.knots
    local knsLen <const> = #kns
    local drawKnot <const> = ShapeUtilities.drawKnot2
    app.transaction("Draw Curve Handles", function()
        local i = 0
        while i < knsLen do
            i = i + 1
            drawKnot(
                kns[i], frame, layer,
                lnClr, coClr,
                fhClr, rhClr)
        end
    end)
end

---Draws a knot for diagnostic purposes. Color arguments are optional.
---@param knot Knot2 knot
---@param frame Frame frame
---@param layer Layer layer
---@param lnClr Color? line color
---@param coClr Color? coordinate color
---@param fhClr Color? fore handle color
---@param rhClr Color? rear handle color
function ShapeUtilities.drawKnot2(
    knot, frame, layer,
    lnClr, coClr, fhClr, rhClr)
    local lnClrVal <const> = lnClr or Color { r = 175, g = 175, b = 175 }
    local rhClrVal <const> = rhClr or Color { r = 2, g = 167, b = 235 }
    local coClrVal <const> = coClr or Color { r = 235, g = 225, b = 40 }
    local fhClrVal <const> = fhClr or Color { r = 235, g = 26, b = 64 }

    local lnBrush <const> = Brush { size = 1 }
    local rhBrush <const> = Brush { size = 4 }
    local coBrush <const> = Brush { size = 6 }
    local fhBrush <const> = Brush { size = 5 }

    local coPt <const> = AseUtilities.vec2ToPoint(knot.co)
    local fhPt <const> = AseUtilities.vec2ToPoint(knot.fh)
    local rhPt <const> = AseUtilities.vec2ToPoint(knot.rh)

    app.transaction("Draw Knot Handles", function()
        -- Line from rear handle to coordinate.
        ---@diagnostic disable-next-line: deprecated
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { rhPt, coPt },
            frame = frame,
            layer = layer
        }

        -- Line from coordinate to fore handle.
        ---@diagnostic disable-next-line: deprecated
        app.useTool {
            tool = "line",
            color = lnClrVal,
            brush = lnBrush,
            points = { coPt, fhPt },
            frame = frame,
            layer = layer
        }

        -- Rear handle point.
        ---@diagnostic disable-next-line: deprecated
        app.useTool {
            tool = "pencil",
            color = rhClrVal,
            brush = rhBrush,
            points = { rhPt },
            frame = frame,
            layer = layer
        }

        -- Coordinate point.
        ---@diagnostic disable-next-line: deprecated
        app.useTool {
            tool = "pencil",
            color = coClrVal,
            brush = coBrush,
            points = { coPt },
            frame = frame,
            layer = layer
        }

        -- Fore handle point.
        ---@diagnostic disable-next-line: deprecated
        app.useTool {
            tool = "pencil",
            color = fhClrVal,
            brush = fhBrush,
            points = { fhPt },
            frame = frame,
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
---@param frame Frame frame
---@param layer Layer layer
function ShapeUtilities.drawMesh2(
    mesh,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, frame, layer)
    -- Convert Vec2s to Points.
    ---@type Point[]
    local pts <const> = {}
    local vs <const> = mesh.vs
    local vsLen <const> = #vs
    local toPt <const> = AseUtilities.vec2ToPoint
    local idx0 = 0
    while idx0 < vsLen do
        idx0 = idx0 + 1
        pts[idx0] = toPt(vs[idx0])
    end

    -- Group points by face.
    local fs <const> = mesh.fs
    local fsLen <const> = #fs
    ---@type Point[][]
    local ptsGrouped <const> = {}
    local idx1 = 0
    while idx1 < fsLen do
        idx1 = idx1 + 1
        local f <const> = fs[idx1]
        local fLen <const> = #f
        ---@type Point[]
        local ptsFace <const> = {}
        local idx2 = 0
        while idx2 < fLen do
            idx2 = idx2 + 1
            ptsFace[idx2] = pts[f[idx2]]
        end
        ptsGrouped[idx1] = ptsFace
    end

    -- Group fills into one transaction.
    ---@diagnostic disable-next-line: deprecated
    local useTool <const> = app.useTool
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
                    frame = frame,
                    layer = layer,
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
                local ptGroup <const> = ptsGrouped[idx4]
                local lenPtGrp <const> = #ptGroup
                local ptPrev = ptGroup[lenPtGrp]
                local idx5 = 0
                while idx5 < lenPtGrp do
                    idx5 = idx5 + 1
                    local ptCurr <const> = ptGroup[idx5]
                    useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        frame = frame,
                        layer = layer
                    }
                    ptPrev = ptCurr
                end
            end
        end)
    end
end

return ShapeUtilities