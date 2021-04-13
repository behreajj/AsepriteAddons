dofile("../support/aseutilities.lua")
dofile("../support/curve2.lua")
dofile("../support/mat3.lua")
dofile("../support/utilities.lua")

local defaults = {
    resolution = 32,
    lbx = 5,
    lby = 5,
    ubx = 95,
    uby = 95,
    tl = 7,
    tr = 7,
    br = 7,
    bl = 7,
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

dlg:newrow { always = false }

dlg:slider {
    id = "lbx",
    label = "Horizontal %:",
    min = 0,
    max = 100,
    value = defaults.lbx
}

dlg:slider {
    id = "ubx",
    min = 0,
    max = 100,
    value = defaults.ubx
}

dlg:newrow { always = false }

dlg:slider {
    id = "lby",
    label = "Vertical %:",
    min = 0,
    max = 100,
    value = defaults.lby
}

dlg:slider {
    id = "uby",
    min = 0,
    max = 100,
    value = defaults.uby
}

dlg:newrow { always = false }

dlg:slider {
    id = "tl",
    label = "Corners %:",
    min = -50,
    max = 50,
    value = defaults.tl
}

dlg:slider {
    id = "tr",
    min = -50,
    max = 50,
    value = defaults.tr
}

dlg:newrow { always = false }

dlg:slider {
    id = "br",
    min = -50,
    max = 50,
    value = defaults.br
}

dlg:slider {
    id = "bl",
    min = -50,
    max = 50,
    value = defaults.bl
}

dlg:newrow { always = false }

dlg:check {
    id = "useStroke",
    label = "Stroke:",
    text = "Enable",
    selected = defaults.useStroke,
    onclick = function()
        dlg:modify {
            id = "strokeWeight",
            visible = dlg.data.useStroke
        }
        dlg:modify {
            id = "strokeClr",
            visible = dlg.data.useStroke
        }
    end
}

dlg:slider {
    id = "strokeWeight",
    min = 1,
    max = 64,
    value = defaults.strokeWeight,
    visible = defaults.useStroke
}

dlg:color {
    id = "strokeClr",
    color = defaults.strokeClr,
    visible = defaults.useStroke
}

dlg:newrow { always = false }

dlg:check {
    id = "useFill",
    label = "Fill:",
    text = "Enable",
    selected = defaults.useFill,
    onclick = function()
        dlg:modify {
            id = "fillClr",
            visible = dlg.data.useFill
        }
    end
}

dlg:color {
    id = "fillClr",
    color = defaults.fillClr,
    visible = defaults.useFill
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()

        local args = dlg.data
        if args.ok then
            local sprite = AseUtilities.initCanvas(
                64, 64, "Rectangle",
                { args.fillClr, args.strokeClr })
            local layer = sprite.layers[#sprite.layers]

            local wPrc = sprite.width * 0.01
            local hPrc = sprite.height * 0.01
            local prc = math.min(wPrc, hPrc)
            local curve = Curve2.rect(
                wPrc * args.lbx, hPrc * args.lby,
                wPrc * args.ubx, hPrc * args.uby,
                prc * args.bl, prc * args.br,
                prc * args.tr, prc * args.tl)

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