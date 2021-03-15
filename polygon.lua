dofile("./Support/mat3.lua")
dofile("./Support/mesh2.lua")
dofile("./Support/utilities.lua")
dofile("./Support/aseutilities.lua")

local defaults = {
    sides = 6,
    angle = 90,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    useFill = true,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(32, 32, 32, 255),
    fillClr = Color(255, 245, 215, 255)
}

local dlg = Dialog { title = "Convex Polygon" }

dlg:slider {
    id = "sides",
    label = "Sides:",
    min = 3,
    max = 16,
    value = defaults.sides
}

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.1f", defaults.scale),
    decimals = 5
}

dlg:number {
    id = "xOrigin",
    label = "Origin X:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    label = "Origin Y:",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
}

dlg:check {
    id = "useStroke",
    label = "Use Stroke:",
    selected = defaults.useStroke
}

dlg:slider {
    id = "strokeWeight",
    label = "Stroke Weight:",
    min = 1,
    max = 64,
    value = defaults.strokeWeight
}

dlg:color {
    id = "strokeClr",
    label = "Stroke Color:",
    color = defaults.strokeClr
}

dlg:check {
    id = "useFill",
    label = "Use Fill:",
    selected = defaults.useFill
}

dlg:color {
    id = "fillClr",
    label = "Fill Color:",
    color = defaults.fillClr
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()

    local args = dlg.data
    if args.ok then
        local mesh = Mesh2.polygon(args.sides)

        local t = Mat3.fromTranslation(
            args.xOrigin,
            args.yOrigin)
        local r = Mat3.fromRotZ(math.rad(args.angle))
        local sclval = args.scale
        if sclval < 2.0 then sclval = 2.0 end
        local s = Mat3.fromScale(sclval, -sclval)
        local mat = Mat3.mul(Mat3.mul(t, s), r)
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
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }