dofile("../../support/shapeutilities.lua")

local defaults <const> = {
    sides = 6,
    skip = 0,
    pick = 0,
    inset = 50,
    resolution = 16,
    angle = 90,
    scale = 32,
    useStroke = false,
    strokeWeight = 1,
    useFill = true,
    useAntialias = false,
}

local dlg <const> = Dialog { title = "Polygon" }

dlg:slider {
    id = "sides",
    label = "Sides:",
    min = 3,
    max = 32,
    value = defaults.sides,
    focus = true
}

dlg:newrow { always = false }

dlg:slider {
    id = "skip",
    label = "Skip:",
    min = 0,
    max = 10,
    value = defaults.skip,
    onchange = function()
        local args <const> = dlg.data
        local skip <const> = args.skip --[[@as integer]]
        local pick <const> = args.pick --[[@as integer]]
        dlg:modify {
            id = "inset",
            visible = skip > 0 and pick > 0
        }
    end
}

dlg:slider {
    id = "pick",
    min = 0,
    max = 10,
    value = defaults.pick,
    onchange = function()
        local args <const> = dlg.data
        local skip <const> = args.skip --[[@as integer]]
        local pick <const> = args.pick --[[@as integer]]
        dlg:modify {
            id = "inset",
            visible = skip > 0 and pick > 0
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "inset",
    label = "Inset:",
    min = 0,
    max = 100,
    value = defaults.inset,
    visible = defaults.skip > 0
        and defaults.pick > 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
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
    selected = defaults.useAntialias
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
        local sectors <const> = args.sides or defaults.sides --[[@as integer]]
        local skip <const> = args.skip or defaults.skip --[[@as integer]]
        local pick <const> = args.pick or defaults.pick --[[@as integer]]
        local inset <const> = args.inset or defaults.inset --[[@as integer]]

        local degrees <const> = args.angle or defaults.angle --[[@as integer]]
        local scale <const> = args.scale or defaults.scale --[[@as number]]
        local xOrig <const> = args.xOrig --[[@as number]]
        local yOrig <const> = args.yOrig --[[@as number]]

        local useStroke <const> = args.useStroke --[[@as boolean]]
        local strokeWeight <const> = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor <const> = args.strokeClr --[[@as Color]]
        local useFill <const> = args.useFill --[[@as boolean]]
        local fillColor <const> = args.fillClr --[[@as Color]]
        local useAntialias <const> = args.useAntialias --[[@as boolean]]

        -- Create transform matrix.
        local t <const> = Mat3.fromTranslation(xOrig, yOrig)

        local query <const> = AseUtilities.DIMETRIC_ANGLES[degrees]
        local a <const> = query
            or (0.017453292519943 * degrees)
        local r <const> = Mat3.fromRotZ(a)

        local sclVerif <const> = math.max(2.0, scale)
        local s <const> = Mat3.fromScale(sclVerif, -sclVerif)

        local mat <const> = Mat3.mul(Mat3.mul(t, s), r)

        local mesh <const> = Mesh2.star(
            sectors, skip, pick, inset * 0.01)
        Utilities.mulMat3Mesh2(mat, mesh)

        local layer <const> = sprite:newLayer()
        layer.name = mesh.name

        local useTrim <const> = true
        ShapeUtilities.drawMesh2(sprite, mesh, useFill, fillColor,
            useStroke, strokeColor, strokeWeight, frame, layer,
            useAntialias, useTrim)

        app.refresh()
    end
}

dlg:button {
    id = "brush",
    text = "&BRUSH",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local sectors <const> = args.sides or defaults.sides --[[@as integer]]
        local skip <const> = args.skip or defaults.skip --[[@as integer]]
        local pick <const> = args.pick or defaults.pick --[[@as integer]]
        local inset <const> = args.inset or defaults.inset --[[@as integer]]

        local degrees <const> = args.angle or defaults.angle --[[@as integer]]
        local scale <const> = args.scale or defaults.scale --[[@as number]]

        local useStroke <const> = args.useStroke --[[@as boolean]]
        local strokeWeight <const> = args.strokeWeight
            or defaults.strokeWeight --[[@as integer]]
        local strokeColor <const> = args.strokeClr --[[@as Color]]
        local useFill <const> = args.useFill --[[@as boolean]]
        local fillColor <const> = args.fillClr --[[@as Color]]
        local useAntialias <const> = args.useAntialias --[[@as boolean]]

        local r <const> = Mat3.fromRotZ(degrees * 0.017453292519943)
        local sclVerif <const> = math.max(2.0, scale)
        local s <const> = Mat3.fromScale(sclVerif, -sclVerif)

        -- The brush image size must account for the stroke, and to center
        -- the mesh within the image, the translation must use image size.
        -- Fudge factor needed for, e.g., triangle corners.
        local wImage <const> = math.ceil(sclVerif + strokeWeight + 5)
        local hImage <const> = math.ceil(sclVerif + strokeWeight + 5)
        local t <const> = Mat3.fromTranslation(
            wImage * 0.5, hImage * 0.5)

        local mat <const> = Mat3.mul(Mat3.mul(t, s), r)
        local mesh <const> = Mesh2.star(
            sectors, skip, pick, inset * 0.01)
        Utilities.mulMat3Mesh2(mat, mesh)

        local alphaIndex = 0
        local colorMode = ColorMode.RGB
        local colorSpace = ColorSpace { sRGB = false }
        local activeSprite <const> = app.sprite
        if activeSprite then
            local activeSpec <const> = activeSprite.spec
            alphaIndex = activeSpec.transparentColor
            colorMode = activeSpec.colorMode
            colorSpace = activeSpec.colorSpace
        end

        local refSpec <const> = AseUtilities.createSpec(
            wImage, hImage, colorMode, colorSpace, alphaIndex)
        local trimmed <const>,
        _ <const>,
        _ <const> = ShapeUtilities.rasterizeMesh2(
            mesh, refSpec,
            useFill, fillColor,
            useStroke, strokeColor, strokeWeight,
            useAntialias, true)

        AseUtilities.setBrush(AseUtilities.imageToBrush(trimmed))
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