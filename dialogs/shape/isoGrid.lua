dofile("../../support/shapeutilities.lua")

local defaults <const> = {
    cells = 8,
    margin = 0,
    useStroke = true,
    strokeWeight = 1,
    useFill = false,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Dimetric Grid" }

dlg:slider {
    id = "cells",
    label = "Cells:",
    min = 2,
    max = 32,
    value = defaults.cells
}

dlg:newrow { always = false }

dlg:number {
    id = "scale",
    label = "Scale:",
    text = string.format("%.3f", 2 * math.min(
        app.preferences.new_file.width,
        app.preferences.new_file.height)),
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
        local args <const> = dlg.data
        local useStroke <const> = args.useStroke --[[@as boolean]]
        local useFill <const> = args.useFill --[[@as boolean]]
        dlg:modify { id = "strokeWeight", visible = useStroke }
        dlg:modify { id = "strokeClr", visible = useStroke }
        dlg:modify { id = "useFill", visible = useStroke }
        dlg:modify { id = "fillClr", visible = useStroke and useFill }
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
    color = app.preferences.color_bar.fg_color --[[@as Color]],
    visible = defaults.useStroke
}

dlg:newrow { always = false }

dlg:check {
    id = "useFill",
    label = "Fill:",
    text = "Enable",
    selected = defaults.useFill,
    visible = defaults.useStroke,
    -- enabled = false,
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
    color = app.preferences.color_bar.bg_color --[[@as Color]],
    -- enabled = false,
    visible = defaults.useFill
        and defaults.useStroke
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
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
        local cells <const> = args.cells
            or defaults.cells --[[@as integer]]
        local margin100 <const> = args.margin
            or defaults.margin --[[@as integer]]

        local scale <const> = args.scale --[[@as number]]
        local xOrig <const> = args.xOrig --[[@as number]]
        local yOrig <const> = args.yOrig --[[@as number]]

        local useStroke <const> = args.useStroke --[[@as boolean]]
        local strokeWeight <const> = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor <const> = args.strokeClr --[[@as Color]]
        local useFill <const> = args.useFill --[[@as boolean]]
        local fillColor <const> = args.fillClr --[[@as Color]]

        local mesh <const> = Mesh2.gridDimetric(cells)

        -- Convert margin from [0, 100] to [0.0, 1.0].
        -- Ensure that it is less than 100%.
        if margin100 > 0 then
            local marginVerif = math.min(
                0.999999,
                margin100 * 0.01)
            Mesh2.uniformData(mesh, mesh)
            mesh:scaleFacesIndiv(1.0 - marginVerif)
        end
        local scaleVerif <const> = math.max(2.0, scale)

        -- Create transformation matrix.
        local t <const> = Mat3.fromTranslation(xOrig, yOrig)
        local s <const> = Mat3.fromScale(scaleVerif, -scaleVerif)
        local mat <const> = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        local layer <const> = sprite:newLayer()
        layer.name = mesh.name

        ShapeUtilities.drawMesh2(sprite,
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

dlg:show {
    autoscrollbars = true,
    wait = false
}