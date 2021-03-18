dofile("../Support/mat3.lua")
dofile("../Support/mesh2.lua")
dofile("../Support/utilities.lua")
dofile("../Support/aseutilities.lua")

local defaults = {
    rings = 4,
    scale = 32,
    xOrigin = 0,
    yOrigin = 0,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(128, 119, 102, 255),
    useFill = true,
    fillClr = Color(255, 245, 215, 255)
}

local dlg = Dialog { title="Hexagon Grid" }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 1,
    max = 32,
    value = defaults.rings
}

dlg:number {
    id = "scale",
    label = "Cell Size:",
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
    id = "margin",
    label = "Margin:",
    min = 0,
    max = 100,
    value = defaults.margin
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
            local mesh = Mesh2.gridHex(args.rings)

            local sclval = args.scale
            if sclval < 2.0 then
                sclval = 2.0
            end

            -- Convert margin from [0, 100] to [0.0, 1.0].
            -- Ensure that it is less than 100%.
            local mrgval = args.margin * 0.01
            if mrgval > 0.0 then
                mrgval = math.min(mrgval, 0.99)
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
            layer.name = "Hexagon Grid"

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