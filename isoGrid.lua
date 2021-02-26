dofile("./vec2.lua")
dofile("./mat3.lua")
dofile("./mesh2.lua")

---Draws a mesh in Aseprite with the contour tool.
---@param mesh table
---@param useFill boolean
---@param fillClr table
---@param useStroke boolean
---@param strokeClr table
---@param brsh table
---@param cel table
---@param layer table
local function drawMesh(
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
        local pt = Point(
            math.tointeger(v.x),
            math.tointeger(v.y))
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

local defaults = {
    cols = 8,
    rows = 8,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    useFill = true,
    fillClr = Color(255, 245, 215, 255)
}

local dlg = Dialog{
    title="Dimetric Grid"}

dlg:slider{
    id="cols",
    label="Columns: ",
    min=2,
    max=32,
    value=defaults.cols}

dlg:slider{
    id="rows",
    label="Rows: ",
    min=2,
    max=32,
    value=defaults.rows}

dlg:number{
    id="scale",
    label="Scale: ",
    text=string.format("%.2f", defaults.scale),
    decimals=5}

dlg:number{
    id="xOrigin",
    label="Origin X: ",
    text=string.format("%.2f", defaults.xOrigin),
    decimals=5}

dlg:number{
    id="yOrigin",
    label="Origin Y: ",
    text=string.format("%.2f", defaults.yOrigin),
    decimals=5}

dlg:check{
    id="useStroke",
    label="Use Stroke: ",
    selected=defaults.useStroke}

dlg:slider{
    id="strokeWeight",
    label="Stroke Weight:",
    min=1,
    max=64,
    value=defaults.strokeWeight}

dlg:color{
    id="strokeClr",
    label="Stroke Color: ",
    color=defaults.strokeClr}

dlg:check{
    id="useFill",
    label="Use Fill: ",
    selected=defaults.useFill}

dlg:color{
    id="fillClr",
    label="Fill Color: ",
    color=defaults.fillClr}

dlg:button{
    id="ok",
    text="OK",
    onclick=function()

    local args = dlg.data

    local mesh = Mesh2:gridDimetric(
        args.cols,
        args.rows)

    local sclval = args.scale
    if sclval < 2.0 then
        sclval = 2.0
    end

    local t = Mat3:fromTranslation(
        args.xOrigin,
        args.yOrigin)
    local s = Mat3:fromScale(sclval)
    local m = Mat3:mul(t, s)
    local trMesh = Mesh2:transform(mesh, m)

    local brsh = Brush(args.strokeWeight)
    local sprite = app.activeSprite
    local layer = sprite:newLayer()
    layer.name = "Dimetric Grid"
    local cel = sprite:newCel(layer, 1)

    drawMesh(
        trMesh,
        args.useFill,
        args.fillClr,
        args.useStroke,
        args.strokeClr,
        brsh,
        cel,
        layer)

    end}

dlg:button{
    id="cancel",
    text="CANCEL",
    onclick=function()
        dlg:close()
    end}

dlg:show{wait=false}