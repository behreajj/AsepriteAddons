local defaults = {
    sides = 3,
    scale = math.min(app.activeImage.width,
                     app.activeImage.height) / 3,
    angle = 90,
    xOrigin = app.activeSprite.width / 2,
    yOrigin = app.activeSprite.height / 2,
}

local dlg = Dialog{
    title="Convex Polygon"}

dlg:slider{
    id="sides",
    label="Sides: ",
    min=6,
    max=16,
    value=defaults.sides}

dlg:slider{
    id="scale",
    label="Scale: ",
    min=1,
    max=256,
    value=defaults.scale}

dlg:slider{
    id="angle",
    label="Angle:",
    min=-180,
    max=180,
    value=defaults.angle}

-- TODO: Make these number inputs, not sliders
dlg:slider{
    id="xOrigin",
    label="Origin X:",
    min=0,
    max=app.activeSprite.width,
    value=defaults.xOrigin}

dlg:slider{
    id="yOrigin",
    label="Origin Y:",
    min=0,
    max=app.activeSprite.height,
    value=defaults.yOrigin}

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

        -- TODO: More options for useTool,
        -- brush that allows strokeweight?
        local prev = points[sides]
        for i=1,sides + 1,1 do
            local curr = points[i]
            app.useTool{
                tool="line",
                color=app.fgColor,
                bgColor=app.bgColor,
                points={prev, curr},
                contiguous=true
            }
            prev = curr
        end
        
        app.refresh()
    end}

    dlg:show{wait=false}