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
    local vs = mesh.vs
    local vsLen = #vs
    local pts = {}
    for i = 1, vsLen, 1 do
        local v = vs[i]
        -- local v = Vec2.round(vs[i])
        local pt = Point(v.x, v.y)
        table.insert(pts, pt)
    end

    -- Loop over faces.
    local fs = mesh.fs
    local fsLen = #fs
    for i = 1, fsLen, 1 do
        local f = fs[i]
        local fLen = #f

        -- Group points by face.
        local ptsFace = {}
        for j = 1, fLen, 1 do
            local vert = f[j]
            local pt = pts[vert]
            table.insert(ptsFace, pt)
        end

        -- Draw fill with contour tool.
        if useFill then
            app.useTool{
                tool="contour",
                color=fillClr,
                brush=brsh,
                points=ptsFace,
                cel=cel,
                contiguous=true,
                layer=layer}
        end

        -- Draw stroke with line tool, per edge.
        if useStroke then
            local ptPrev = ptsFace[fLen]
            for j = 1, fLen, 1 do
                local ptCurr = ptsFace[j]
                app.useTool{
                    tool="line",
                    color=strokeClr,
                    brush=brsh,
                    points={ptPrev, ptCurr},
                    cel=cel,
                    layer=layer}
                ptPrev = ptCurr
            end
        end
    end

    app.refresh()
end