dofile("./vec2.lua")
dofile("./mesh2.lua")

AseUtilities = {}
AseUtilities.__index = AseUtilities

setmetatable(AseUtilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

---Houses utility methods for scripting
---Aseprite add-ons.
---@return table
function AseUtilities.new()
    local inst = {}
    setmetatable(inst, AseUtilities)
    return inst
end

---Draws a mesh in Aseprite with the contour tool.
---@param mesh table
---@param useFill boolean
---@param fillClr table
---@param useStroke boolean
---@param strokeClr table
---@param brsh table
---@param cel table
---@param layer table
function AseUtilities.drawMesh(
    mesh,
    useFill,
    fillClr,
    useStroke,
    strokeClr,
    brsh,
    cel,
    layer)

    -- Convert Vec2s to Points.
    -- Round Vec2 for improved accuracy.
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    for i = 1, vsLen, 1 do
        local v = Vec2.round(vs[i])
        table.insert(pts, Point(v.x, v.y))
    end

    -- Group points by face.
    local fs = mesh.fs
    local fsLen = #fs
    local ptsGrouped = {}
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f
        local ptsFace = {}
        for j = 1, fLen, 1 do
            table.insert(ptsFace, pts[f[j]])
        end
        table.insert(ptsGrouped, ptsFace)
    end

    -- Group fills into one transaction.
    if useFill then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                app.useTool {
                    tool = "contour",
                    color = fillClr,
                    brush = brsh,
                    points = ptsGrouped[i],
                    cel = cel,
                    layer = layer }
            end
        end)
    end

    -- Group strokes into one transaction.
    -- Draw strokes line by line.
    if useStroke then
        app.transaction(function()
            for i = 1, fsLen, 1 do
                local ptGroup = ptsGrouped[i]
                local ptgLen = #ptGroup
                local ptPrev = ptGroup[ptgLen]
                for j = 1, ptgLen, 1 do
                    local ptCurr = ptGroup[j]
                    app.useTool {
                        tool = "line",
                        color = strokeClr,
                        brush = brsh,
                        points = { ptPrev, ptCurr },
                        cel = cel,
                        layer = layer }
                    ptPrev = ptCurr
                end
            end
        end)
    end

    app.refresh()
end