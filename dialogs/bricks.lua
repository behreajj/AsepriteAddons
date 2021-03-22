dofile("../support/mat3.lua")
dofile("../support/mesh2.lua")
dofile("../support/utilities.lua")
dofile("../support/aseutilities.lua")

local defaults = {
    cols = 8,
    rows = 8,
    offset = 50,
    aspect = 2.0,
    frequency = 2,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    mortarThick = 1,
    mortarClr = Color(231, 231, 231, 255),
    brickClr = Color(203, 65, 84, 255)
}

local dlg = Dialog { title="Brick" }

dlg:slider {
    id = "cols",
    label = "Columns:",
    min = 2,
    max = 32,
    value = defaults.cols
}

dlg:slider {
    id = "rows",
    label = "Rows:",
    min = 2,
    max = 32,
    value = defaults.rows
}

dlg:slider {
    id = "offset",
    label = "Offset:",
    min = -50,
    max = 50,
    value = defaults.offset
}

dlg:number {
    id = "aspect",
    label = "Aspect:",
    text = string.format("%.1f", defaults.aspect),
    decimals = 5
}

dlg:slider {
    id = "frequency",
    label = "Frequency:",
    min = 2,
    max = 8,
    value = defaults.frequency
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

dlg:slider {
    id = "mortarThick",
    label = "Mortar Thickness:",
    min = 1,
    max = 64,
    value = defaults.mortarThick
}

dlg:color {
    id = "mortarClr",
    label = "Mortar Color:",
    color = defaults.mortarClr
}

dlg:color{
    id = "brickClr",
    label = "Brick Color:",
    color = defaults.brickClr
}

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local mesh = Mesh2.gridBricks(
                args.cols,
                args.rows,
                0.01 * args.offset,
                args.aspect,
                args.frequency)

            local t = Mat3.fromTranslation(
                args.xOrigin,
                args.yOrigin)
            local sclval = args.scale
            if sclval < 2.0 then sclval = 2.0 end
            local s = Mat3.fromScale(sclval, -sclval)
            local mat = Mat3.mul(t, s)
            Utilities.mulMat3Mesh2(mat, mesh)

            local sprite = AseUtilities.initCanvas(
                64, 64,
                mesh.name,
                { args.fillClr, args.strokeClr })
            local layer = sprite.layers[#sprite.layers]

            AseUtilities.drawMesh2(
                mesh,
                true,
                args.brickClr,
                true,
                args.mortarClr,
                Brush(args.mortarThick),
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