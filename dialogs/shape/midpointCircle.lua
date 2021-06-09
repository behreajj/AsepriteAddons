local function midPointCircleFill(image, clr, xOrigin, yOrigin, radius)
    local r = radius or 16
    if r < 0 then r = -r end
    if r == 0 then r = 1 end

    local yo = yOrigin or 0
    local xo = xOrigin or 0
    local hex = clr or 0xffffffff

    local rsq = r * r
    for y = -r, r, 1 do
        for x = -r, r, 1 do
            if (x * x + y * y) < rsq then
                image:drawPixel(xo + x, yo + y, hex)
            end
        end
    end
end

local function midPointCircleStroke(image, clr, xOrigin, yOrigin, radius)

    -- Validate for edges?
    local r = radius or 16
    if r < 0 then r = -r end
    if r == 0 then r = 1 end

    local yo = yOrigin or 0
    local xo = xOrigin or 0
    local hex = clr or 0xffffffff

    local x = r
    local y = 0

    image:drawPixel(xo + r, yo, hex)
    image:drawPixel(xo - r, yo, hex)
    image:drawPixel(xo, yo + r, hex)
    image:drawPixel(xo, yo - r, hex)

    local p = 1 - r
    while x > y do
        y = y + 1
        if p <= 0 then
            p = p + 2 * y + 1
        else
            x = x - 1
            p = p + 2 * y - 2 * x + 1
        end

        if x < y then
            break
        end

        image:drawPixel(xo + x, yo + y, hex)
        image:drawPixel(xo - x, yo + y, hex)
        image:drawPixel(xo + x, yo - y, hex)
        image:drawPixel(xo - x, yo - y, hex)

        if x ~= y then
            image:drawPixel(xo + y, yo + x, hex)
            image:drawPixel(xo - y, yo + x, hex)
            image:drawPixel(xo + y, yo - x, hex)
            image:drawPixel(xo - y, yo - x, hex)
        end
    end
end

local dlg = Dialog {
    title = "Midpoint Circle"
}

dlg:number{
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:number{
    id = "yOrigin",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:number{
    id = "radius",
    label = "Radius:",
    text = string.format("%.1f", 32),
    decimals = 5
}

dlg:color{
    id = "strokeClr",
    label = "Stroke:",
    color = Color(255, 255, 255, 255)
}

dlg:color{
    id = "fillClr",
    label = "Fill:",
    color = Color(255, 0, 0, 255)
}

dlg:button{
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                -- Create layer, cel.
                local layer = sprite:newLayer()
                local frame = app.activeFrame or 1
                local cel = sprite:newCel(layer, frame)
                local image = Image(sprite.width, sprite.height)

                midPointCircleFill(
                    image,
                    args.fillClr.rgbaPixel,
                    math.tointeger(args.xOrigin),
                    math.tointeger(args.yOrigin),
                    math.tointeger(args.radius))

                midPointCircleStroke(
                    image,
                    args.strokeClr.rgbaPixel,
                    args.xOrigin,
                    args.yOrigin,
                    args.radius)

                cel.image = image

                app.refresh()
            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button{
    id = "cancel",
    text = "CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show{
    wait = false
}
