dofile("./aseutilities.lua")

ShapeUtilities = {}
ShapeUtilities.__index = ShapeUtilities

setmetatable(ShapeUtilities, {
    -- Last commit with old drawCurve2:
    -- 91c2511cc032c2fa95d4271102fc0411dba286c1
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Draws a mesh with app.useTool.
---@param sprite Sprite sprite
---@param mesh Mesh2 mesh
---@param useFill boolean use fill
---@param fillClr Color fill color
---@param useStroke boolean use stroke
---@param strokeClr Color stroke color
---@param brsh Brush brush
---@param frame Frame frame
---@param layer Layer layer
function ShapeUtilities.drawMesh2(
    sprite, mesh,
    useFill, fillClr,
    useStroke, strokeClr,
    brsh, frame, layer)
    local docPrefs <const> = app.preferences.document(sprite)
    local symmetryPrefs <const> = docPrefs.symmetry
    local oldSymmetry <const> = symmetryPrefs.mode or 0 --[[@as integer]]
    symmetryPrefs.mode = 0

    local toPt <const> = AseUtilities.vec2ToPoint
    local round <const> = Utilities.round

    -- Convert Vec2s to Points.
    ---@type Point[]
    local pts <const> = {}
    local vs <const> = mesh.vs
    local vsLen <const> = #vs

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

    -- Find centers for paint bucket.
    ---@type Point[]
    local centers <const> = {}

    local idx1 = 0
    while idx1 < fsLen do
        idx1 = idx1 + 1
        local f <const> = fs[idx1]
        local fLen <const> = #f
        ---@type Point[]
        local ptsFace <const> = {}

        local xSum = 0
        local ySum = 0

        local idx2 = 0
        while idx2 < fLen do
            idx2 = idx2 + 1
            local pt <const> = pts[f[idx2]]
            ptsFace[idx2] = pt
            xSum = xSum + pt.x
            ySum = ySum + pt.y
        end

        ptsGrouped[idx1] = ptsFace
        centers[idx1] = Point(
            fLen >= 3 and round(xSum / fLen) or 0,
            fLen >= 3 and round(ySum / fLen) or 0)
    end

    -- Group fills into one transaction.
    ---@diagnostic disable-next-line: deprecated
    local useTool <const> = app.useTool
    local simpleInk <const> = Ink.SIMPLE

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
                        brush = brsh,
                        color = strokeClr,
                        frame = frame,
                        ink = simpleInk,
                        layer = layer,
                        points = { ptPrev, ptCurr },
                    }
                    ptPrev = ptCurr
                end -- End vertices loop.
            end     -- End faces loop.
        end)        -- End transaction.

        if useFill and strokeClr.alpha > 0 then
            local paintPrefs <const> = app.preferences.tool("paint_bucket")
            local floodPrefs <const> = paintPrefs.floodfill

            local oldStopAtGrid <const> = floodPrefs.stop_at_grid or 0 --[[@as integer]]
            local oldReferTo <const> = floodPrefs.refer_to or 0 --[[@as integer]]
            local oldPxMatrix <const> = floodPrefs.pixel_connectivity or 0 --[[@as integer]]

            floodPrefs.stop_at_grid = 0       -- Never
            floodPrefs.refer_to = 0           -- Active Layer
            floodPrefs.pixel_connectivity = 0 -- Four connected

            app.transaction("Mesh Fill", function()
                local paintBrush <const> = Brush { size = 1 }
                local idx3 = 0
                while idx3 < fsLen do
                    idx3 = idx3 + 1
                    local f <const> = fs[idx3]
                    local fLen <const> = #f
                    if fLen >= 3 then
                        useTool {
                            tool = "paint_bucket",
                            brush = paintBrush,
                            color = fillClr,
                            contiguous = true,
                            frame = frame,
                            ink = simpleInk,
                            layer = layer,
                            points = { centers[idx3] },
                            tolerance = 0,
                        }
                    end -- End valid face check.
                end     -- End faces loop.
            end)        -- End transaction.

            floodPrefs.stop_at_grid = oldStopAtGrid
            floodPrefs.refer_to = oldReferTo
            floodPrefs.pixel_connectivity = oldPxMatrix
        end -- End use fill.
    end     -- End use stroke.

    symmetryPrefs.mode = oldSymmetry
end

return ShapeUtilities