dofile("../Support/mat3.lua")
dofile("../Support/mesh2.lua")
dofile("../Support/utilities.lua")
dofile("../Support/aseutilities.lua")

local defaults = {
    startAngle = 0,
    stopAngle = 90,
    startWeight = 50,
    stopWeight = 50,
    sectors = 32,
    margin = 0,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useFill = true,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    fillClr = Color(255, 245, 215, 255)}

local dlg = Dialog{
    title="Arc"}

dlg:slider{
    id="startAngle",
    label="Start Angle:",
    min=0,
    max=360,
    value=defaults.startAngle}

dlg:slider{
    id="stopAngle",
    label="Stop Angle:",
    min=0,
    max=360,
    value=defaults.stopAngle}

dlg:slider{
    id="startWeight",
    label="Start Weight:",
    min=0,
    max=100,
    value=defaults.startWeight}

dlg:slider{
    id="stopWeight",
    label="Stop Weight:",
    min=0,
    max=100,
    value=defaults.stopWeight}

dlg:slider{
    id="sectors",
    label="Sectors: ",
    min=3,
    max=64,
    value=defaults.sectors}

dlg:slider{
    id="margin",
    label="Margin: ",
    min=0,
    max=100,
    value=defaults.margin}

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
    local useQuads = args.margin > 0
    local mesh = Mesh2.arc(
        math.rad(args.startAngle),
        math.rad(args.stopAngle),
        0.01 * args.startWeight,
        0.01 * args.stopWeight,
        args.sectors,
        useQuads)

    local sclval = args.scale
    if sclval < 2.0 then
        sclval = 2.0
    end

    local mrgval = args.margin * 0.01
    if mrgval > 0.0 then
        mrgval = math.min(mrgval, 0.99)
        Mesh2.uniformData(mesh, mesh)
        mesh:scaleFacesIndiv(1.0 - mrgval)
    end

    local t = Mat3.fromTranslation(
        args.xOrigin,
        args.yOrigin)
    local s = Mat3.fromScale(sclval, -sclval)
    local mat = Mat3.mul(t, s)
    Utilities.mulMat3Mesh2(mat, mesh)

    local sprite = app.activeSprite
    if sprite == nil then
        sprite = Sprite(64, 64)
        app.activeSprite = sprite
    end

    local layer = sprite:newLayer()
    layer.name = mesh.name

    AseUtilities.drawMesh2(
        mesh,
        args.useFill,
        args.fillClr,
        args.useStroke,
        args.strokeClr,
        Brush(args.strokeWeight),
        sprite:newCel(layer, 1),
        layer)

    end}

dlg:button{
    id="cancel",
    text="CANCEL",
    onclick=function()
        dlg:close()
    end}

dlg:show{wait=false}