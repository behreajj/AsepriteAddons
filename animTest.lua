local defaults = {
    frames = 8,
    brushSize = 16,
    clr = Color(32, 32, 32, 255)
}

local dlg = Dialog{
    title="Anim Test"}

dlg:slider{
    id="frames",
    label="Frames:",
    min=2,
    max=24,
    value=defaults.frames}

dlg:slider{
    id="brushSize",
    label="Brush Size:",
    min=2,
    max=64,
    value=defaults.brushSize}

dlg:color{
    id="clr",
    label="Color: ",
    color=defaults.clr}

dlg:button{
    id="ok",
    text="OK",
    focus=true,
    onclick=function()
        local args = dlg.data
        local sprite = app.activeSprite

        -- Add requested number of frames.
        local currLen = #sprite.frames
        local needed = math.max(0, args.frames - currLen)
        for i = 1, needed, 1 do
            sprite:newEmptyFrame()
        end

        -- Create new layer.
        local layer = sprite:newLayer()
        layer.name = "Test Animation"
        local brsh = Brush(args.brushSize)
        local spr = app.activeSprite
        local xCenter = spr.width / 2
        local yCenter = spr.height / 2
        local scl = math.min(xCenter, yCenter) - args.brushSize

        local newLen = #sprite.frames
        local toTheta = (2.0 * math.pi) / newLen
        for i = 1, newLen, 1 do
            local cel = sprite:newCel(layer, sprite.frames[i])
            local theta = (i - 1) * toTheta
            local pt = Point(
                xCenter + scl * math.cos(theta),
                yCenter + scl * math.sin(theta))

            app.useTool{
                tool="pencil",
                color=args.clr,
                brush=brsh,
                points={pt},
                cel=cel,
                layer=layer}
        end
        app.refresh()
    end}

dlg:button{
    id="cancel",
    text="CANCEL",
    onclick=function()
        dlg:close()
    end}

dlg:show{wait=false}