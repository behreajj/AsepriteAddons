local function bresenham(image, clr, x0, y0, x1, y1)
    if x0 == x1 and y0 == y1 then return end
    local hex = clr or 0xffffffff
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local x = x0
    local y = y0
    local sx = 0
    local sy = 0

    if x0 < x1 then sx = 1 else sx = -1 end
    if y0 < y1 then sy = 1 else sy = -1 end

    local err = 0
    if dx > dy then err = dx // 2
    else err = -dy // 2 end
    local e2 = 0

    while true do
        -- print("(" .. x .. ", " .. y .. ")")
        image:drawPixel(x, y, hex)
        if x == x1 and y == y1 then break end
        e2 = err
        if e2 > -dx then
            err = err - dy
            x = x + sx
        end
        if e2 < dy then
            err = err + dx
            y = y + sy
        end
    end
end

local dlg = Dialog {
    title = "Bresenham Line"
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
    id = "xDest",
    label = "Destination:",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:number{
    id = "yDest",
    text = string.format("%.1f", 0),
    decimals = 5
}

dlg:color{
    id = "strokeClr",
    label = "Stroke:",
    color = Color(255, 255, 255, 255)
}

dlg:button{
    id = "confirm",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then
            -- Create layer, cel.
            local layer = sprite:newLayer()
            local frame = app.activeFrame or 1
            local cel = sprite:newCel(layer, frame)
            local image = Image(sprite.width, sprite.height)

            bresenham(
                image,
                args.strokeClr.rgbaPixel,
                args.xOrigin,
                args.yOrigin,
                args.xDest,
                args.yDest)

            cel.image = image

            app.refresh()
        else
            app.alert("There is no active sprite.")
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
