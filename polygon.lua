local defaults = {
    sides = 6,
    angle = -90,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useFill = true,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    fillClr = Color(255, 245, 215, 255)
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

dlg:check{
    id="useFill",
    label="Use Fill: ",
    selected=defaults.useFill}

dlg:color{
    id="fillClr",
    label="Fill Color: ",
    color=defaults.fillClr}

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
        local pts = {}

        local toTheta = 6.283185307179586 / sides
        for i = 0, sides - 1, 1 do
            local theta = rads + i * toTheta
            -- print(theta)
            local pt = Point(
                xo + math.cos(theta) * scale,
                yo + math.sin(theta) * scale)
            -- print(pt)
            table.insert(pts, pt)
        end

        -- local brush = app.activeBrush
        local brsh = Brush(args.strokeWeight)

        local sprite = app.activeSprite
        local layer = sprite:newLayer()
        local cel = sprite:newCel(layer, 1)

        layer.name = "Polygon"
        if sides == 3 then
            layer.name = "Triangle"
        elseif sides == 4 then
            layer.name = "Quadrilateral"
        elseif sides == 5 then
            layer.name = "Pentagon"
        elseif sides == 6 then
            layer.name = "Hexagon"
        elseif sides == 7 then
            layer.name = "Heptagon"
        elseif sides == 8 then
            layer.name = "Octagon"
        elseif sides == 9 then
            layer.name = "Nonagon"
        end

        -- Polygon tool doesn't work with this?
        -- app.useTool{
        --     tool="polygon",
        --     color=args.strokeClr,
        --     bgColor=args.fillClr,
        --     brush=brush,
        --     points=points,
        --     cel=cel,
        --     layer=layer}

        local ptsLen = #pts
        local prev = pts[ptsLen]
        for i = 1, ptsLen, 1 do
            local curr = pts[i]
            app.useTool{
                tool="line",
                color=args.strokeClr,
                brush=brsh,
                points={prev, curr},
                cel=cel,
                layer=layer}
            prev = curr
        end

        if args.useFill then
            app.useTool{
                tool="paint_bucket",
                color=args.fillClr,
                points={Point(xo, yo)},
                cel=cel,
                layer=layer}
        end

        app.refresh()
    end}

    dlg:show{wait=false}