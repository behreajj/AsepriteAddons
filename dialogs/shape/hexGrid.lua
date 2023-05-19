dofile("../../support/shapeutilities.lua")

local defaults = {
    rings = 4,
    xScale = 32,
    yScale = 32,
    useDimetric = false,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    useFill = true,
    pullFocus = false
}

local dlg = Dialog { title = "Hexagon Grid" }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 1,
    max = 32,
    value = defaults.rings
}

dlg:newrow { always = false }

dlg:number {
    id = "xScale",
    label = "Cell:",
    text = string.format("%.3f", defaults.xScale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yScale",
    text = string.format("%.3f", defaults.yScale),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:check {
    id = "useDimetric",
    label = "Dimetric:",
    text = "&Scale",
    selected = defaults.useDimetric
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

dlg:slider {
    id = "margin",
    label = "Margin:",
    min = 0,
    max = 100,
    value = defaults.margin
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
    color = app.preferences.color_bar.bg_color,
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
    color = app.preferences.color_bar.fg_color,
    visible = defaults.useFill
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local site = app.site
        local sprite = site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frame = site.frame
        if not frame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local args = dlg.data
        local rings = args.rings
            or defaults.rings --[[@as integer]]
        local xScale = args.xScale
            or defaults.xScale --[[@as number]]
        local yScale = args.yScale
            or defaults.yScale --[[@as number]]
        local useDimetric = args.useDimetric --[[@as boolean]]
        local xOrig = args.xOrig --[[@as number]]
        local yOrig = args.yOrig --[[@as number]]
        local margin100 = args.margin
            or defaults.margin --[[@as integer]]

        local useStroke = args.useStroke --[[@as boolean]]
        local strokeWeight = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor = args.strokeClr --[[@as Color]]
        local useFill = args.useFill --[[@as boolean]]
        local fillColor = args.fillClr --[[@as Color]]

        if xScale < 2.0 then xScale = 2.0 end
        if yScale < 2.0 then yScale = 2.0 end
        if useDimetric then
            -- sqrt(3) / 2 = 0.8660254
            xScale = xScale * 1.1547005383793
        end

        local mesh = Mesh2.gridHex(rings)

        local t = Mat3.fromTranslation(xOrig, yOrig)
        local s = Mat3.fromScale(xScale, -yScale)
        local mat = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        local margin = margin100 * 0.01
        if margin > 0.0 then
            margin = 1.0 - math.min(margin, 0.99)
            mesh:scaleFacesIndiv(margin)
        end

        local layer = nil
        app.transaction("New Layer", function()
            layer = sprite:newLayer()
            layer.name = mesh.name
        end)

        ShapeUtilities.drawMesh2(
            mesh, useFill, fillColor,
            useStroke, strokeColor,
            Brush { size = strokeWeight },
            frame, layer)

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

dlg:show { wait = false }