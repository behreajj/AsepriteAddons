dofile("./mat3.lua")
dofile("./mesh2.lua")
dofile("./aseutilities.lua")

local defaults = {
    cols = 8,
    rows = 8,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(128, 119, 102, 255),
    useFill = true,
    fillClr = Color(255, 245, 215, 255)}

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
    text=string.format("%.1f", defaults.scale),
    decimals=5}

dlg:number{
    id="xOrigin",
    label="Origin X: ",
    text=string.format("%.1f", defaults.xOrigin),
    decimals=5}

dlg:number{
    id="yOrigin",
    label="Origin Y: ",
    text=string.format("%.1f", defaults.yOrigin),
    decimals=5}

dlg:slider{
    id="margin",
    label="Margin: ",
    min=0,
    max=100,
    value=defaults.margin}

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
    focus=true,
    onclick=function()

    local args = dlg.data

    local mesh = Mesh2.gridDimetric(
        args.cols,
        args.rows)

    local sclval = args.scale
    if sclval < 2.0 then
        sclval = 2.0
    end

    -- Convert margin from [0, 100] to [0.0, 1.0].
    -- Ensure that it is less than 100%.
    local mrgval = args.margin * 0.01
    if mrgval > 0.0 then
        mrgval = math.min(mrgval, 0.99)
        Mesh2.uniformData(mesh, mesh)

        -- TODO: Deal with cases like a 2x1 square
        -- where inset amt would be greater.
        mesh:scaleFacesIndiv(1.0 - mrgval)
    end

    local t = Mat3.fromTranslation(
        args.xOrigin,
        args.yOrigin)
    local s = Mat3.fromScale(sclval)
    local mat = Mat3.mul(t, s)
    mesh:transform(mat)

    local brsh = Brush(args.strokeWeight)
    local sprite = app.activeSprite
    local layer = sprite:newLayer()
    layer.name = "Dimetric Grid"
    local cel = sprite:newCel(layer, 1)

    AseUtilities.drawMesh(
        mesh,
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