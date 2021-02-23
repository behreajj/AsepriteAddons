local defaults = {
    sides = 6,
    angle = 90,
    scale = math.min(app.activeImage.width,
                     app.activeImage.height) / 3,
    xOrigin = app.activeSprite.width / 2,
    yOrigin = app.activeSprite.height / 2,
    strokeClr = app.fgColor,
    fillClr = app.bgColor
}

local dlg = Dialog{
    title="Convex Polygon"}

dlg:slider{
    id="sides",
    label="Sides: ",
    min=3,
    max=16,
    value=defaults.sides}

dlg:slider{
    id="angle",
    label="Angle:",
    min=-180,
    max=180,
    value=defaults.angle}

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

dlg:color{
    id="strokeClr",
    label="Stroke Color: ",
    color=defaults.strokeClr}

dlg:color{
    id="fillClr",
    label="Fill Color: ",
    color=defaults.fillClr}

dlg:button{
    id="ok",
    text="OK",
    onclick=function()
        local args = dlg.data

        local sides = args.sides
        local scale = args.scale
        local rads = math.rad(args.angle)
        local xo = args.xOrigin
        local yo = args.yOrigin
        local points = {}

        local toTheta = 6.283185307179586 / sides
        for i=0,sides,1 do
            local theta = rads + i * toTheta
            local point = Point(
                xo + math.cos(theta) * scale,
                yo + math.sin(theta) * scale)
            table.insert(points, point)
        end

        -- local brush = app.activeBrush
        local brush = Brush{
            type=BrushType.CIRCLE,
            size=1.0}

        -- TODO: More options for useTool,
        -- brush that allows strokeweight?
        local prev = points[sides]
        for i=1,sides + 1,1 do
            local curr = points[i]
            app.useTool{
                tool="line",
                color=args.strokeClr,
                brush=brush,
                points={prev, curr}}
            prev = curr
        end
        
        app.useTool{
            tool="paint_bucket",
            color=args.fillClr,
            points={Point(xo, yo)}
        }

        app.refresh()
    end}

    dlg:show{wait=false}