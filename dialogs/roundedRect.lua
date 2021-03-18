dofile("../Support/mat3.lua")
dofile("../Support/curve2.lua")
dofile("../Support/utilities.lua")
dofile("../Support/aseutilities.lua")

local defaults = {
    resolution = 32,
    lbx = 5,
    lby = 5,
    ubx = 95,
    uby = 95,
    tl = 0,
    tr = 0,
    br = 0,
    bl = 0,
    useFill = true,
    useStroke = true,
    strokeWeight = 1,
    strokeClr = Color(255, 245, 215, 255),
    fillClr = Color(32, 32, 32, 255),
    handles = 0
}

local dlg = Dialog { title = "Rounded Rectangle" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
    max = 64,
    value = defaults.resolution
}

dlg:slider {
    id = "handles",
    label = "Handles:",
    min = 0,
    max = 255,
    value = defaults.handles
}

dlg:separator {
    id = "separator1",
    text = "Edges"
}

dlg:slider {
    id = "lbx",
    label = "Left %:",
    min = 0,
    max = 100,
    value = defaults.lbx
}

dlg:slider {
    id = "lby",
    label = "Top %:",
    min = 0,
    max = 100,
    value = defaults.lby
}

dlg:slider {
    id = "ubx",
    label = "Right %:",
    min = 0,
    max = 100,
    value = defaults.ubx
}

dlg:slider {
    id = "uby",
    label = "Bottom %:",
    min = 0,
    max = 100,
    value = defaults.uby
}

dlg:separator {
    id = "separator2",
    text = "Corners"
}

dlg:slider {
    id = "tl",
    label = "Top Left %:",
    min = -50,
    max = 50,
    value = defaults.tl
}

dlg:slider {
    id = "tr",
    label = "Top Right %:",
    min = -50,
    max = 50,
    value = defaults.tr
}

dlg:slider {
    id = "br",
    label = "Bottom Right %:",
    min = -50,
    max = 50,
    value = defaults.br
}

dlg:slider {
    id = "bl",
    label = "Bottom Left %:",
    min = -50,
    max = 50,
    value = defaults.bl
}

dlg:separator {
    id = "separator3",
    text = "Display"
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
            local sprite = app.activeSprite
            if sprite == nil then
                sprite = Sprite(64, 64)
                app.activeSprite = sprite
            end

            local wPrc = sprite.width * 0.01
            local hPrc = sprite.height * 0.01
            local prc = math.min(wPrc, hPrc)
            local curve = Curve2.rect(
                wPrc * args.lbx, hPrc * args.lby,
                wPrc * args.ubx, hPrc * args.uby,
                prc * args.bl, prc * args.br,
                prc * args.tr, prc * args.tl)

            local layer = sprite:newLayer()
            layer.name = curve.name

            AseUtilities.drawCurve2(
                curve,
                args.resolution,
                args.useFill,
                args.fillClr,
                args.useStroke,
                args.strokeClr,
                Brush(args.strokeWeight),
                sprite:newCel(layer, 1),
                layer
            )

            if args.handles > 0 then
                local hlLyr = sprite:newLayer()
                hlLyr.name = curve.name .. ".Handles"
                hlLyr.opacity = args.handles
                AseUtilities.drawHandles2(
                    curve,
                    sprite:newCel(hlLyr, 1),
                    hlLyr)
            end

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