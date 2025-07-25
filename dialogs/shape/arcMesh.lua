dofile("../../support/shapeutilities.lua")

local defaults <const> = {
    -- TODO: Brush button similar to polygon?
    startAngle = 0,
    stopAngle = 90,
    startWeight = 50,
    stopWeight = 50,
    sectors = 32,
    margin = 0,
    scale = 32,
    useStroke = false,
    strokeWeight = 1,
    useFill = true,
    useAntialias = false,
}

local dlg <const> = Dialog { title = "Mesh Arc" }

dlg:slider {
    id = "startAngle",
    label = "Angles:",
    min = 0,
    max = 360,
    value = defaults.startAngle
}

dlg:slider {
    id = "stopAngle",
    text = "Stop",
    min = 0,
    max = 360,
    value = defaults.stopAngle
}

dlg:newrow { always = false }

dlg:slider {
    id = "startWeight",
    label = "Weights:",
    min = 0,
    max = 100,
    value = defaults.startWeight
}

dlg:slider {
    id = "stopWeight",
    min = 0,
    max = 100,
    value = defaults.stopWeight
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 3,
    max = 64,
    value = defaults.sectors
}

dlg:newrow { always = false }

dlg:slider {
    id = "margin",
    label = "Margin:",
    min = 0,
    max = 100,
    value = defaults.margin,
}

dlg:newrow { always = false }

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.3f", defaults.scale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrig",
    label = "Origin:",
    text = string.format("%.3f",
        app.preferences.new_file.width * 0.5),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yOrig",
    text = string.format("%.3f",
        app.preferences.new_file.height * 0.5),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:check {
    id = "useStroke",
    label = "Stroke:",
    text = "Enable",
    selected = defaults.useStroke,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local useStroke <const> = args.useStroke --[[@as boolean]]
        dlg:modify { id = "strokeWeight", visible = useStroke }
        dlg:modify { id = "strokeClr", visible = useStroke }
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
    color = app.preferences.color_bar.bg_color --[[@as Color]],
    visible = defaults.useStroke
}

dlg:newrow { always = false }

dlg:check {
    id = "useFill",
    label = "Fill:",
    text = "Enable",
    selected = defaults.useFill,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local useFill <const> = args.useFill --[[@as boolean]]
        dlg:modify {
            id = "fillClr",
            visible = useFill
        }
    end
}

dlg:color {
    id = "fillClr",
    color = app.preferences.color_bar.fg_color --[[@as Color]],
    visible = defaults.useFill
}

dlg:newrow { always = false }

dlg:check {
    id = "useAntialias",
    label = "Antialias:",
    text = "Enable",
    selected = defaults.useAntialias,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frame <const> = site.frame
        if not frame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args <const> = dlg.data
        local startAngle <const> = args.startAngle
            or defaults.startAngle --[[@as integer]]
        local stopAngle <const> = args.stopAngle
            or defaults.stopAngle --[[@as integer]]
        local sectors <const> = args.sectors
            or defaults.sectors --[[@as integer]]
        local startWeight <const> = args.startWieght
            or defaults.startWeight --[[@as integer]]
        local stopWeight <const> = args.stopWieght
            or defaults.stopWeight --[[@as integer]]
        local margin <const> = args.margin
            or defaults.margin --[[@as integer]]

        local scale <const> = args.scale
            or defaults.scale --[[@as number]]
        local xOrig <const> = args.xOrig --[[@as number]]
        local yOrig <const> = args.yOrig --[[@as number]]

        local useStroke <const> = args.useStroke --[[@as boolean]]
        local strokeWeight <const> = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor <const> = args.strokeClr --[[@as Color]]
        local useFill <const> = args.useFill --[[@as boolean]]
        local fillColor <const> = args.fillClr --[[@as Color]]
        local useAntialias <const> = args.useAntialias --[[@as boolean]]

        local useQuads <const> = margin > 0
        local mesh <const> = Mesh2.arc(
            0.017453292519943 * startAngle,
            0.017453292519943 * stopAngle,
            0.01 * startWeight,
            0.01 * stopWeight,
            sectors,
            useQuads)

        local scaleVerif <const> = math.max(2.0, scale)
        local marginVerif = margin * 0.01
        if marginVerif > 0.0 then
            marginVerif = math.min(marginVerif, 0.99)
            Mesh2.uniformData(mesh, mesh)
            mesh:scaleFacesIndiv(1.0 - marginVerif)
        end

        local t <const> = Mat3.fromTranslation(xOrig, yOrig)
        local s <const> = Mat3.fromScale(scaleVerif, -scaleVerif)
        local mat <const> = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        local name <const> = string.format(
            "Arc %d to %d",
            startAngle, stopAngle)
        app.transaction(name, function()
            -- TODO: Parent layer to earliest visible parent?
            local layer <const> = sprite:newLayer()
            layer.name = name
            ShapeUtilities.drawMesh2(sprite, mesh, useFill, fillColor,
                useStroke, strokeColor, strokeWeight, frame, layer,
                useAntialias, true)
        end)

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}