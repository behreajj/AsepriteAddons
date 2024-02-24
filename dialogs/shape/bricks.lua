dofile("../../support/shapeutilities.lua")

local defaults <const> = {
    cols = 8,
    rows = 8,
    offset = 50,
    aspect = 2.0,
    skip = 1,
    pick = 1,
    mortarThick = 1,
    mortarClr = 0xffe7e7e7,
    brickClr = 0xff5441cb,
    variance = 10,
    varyHue = false,
    varyChroma = true,
    varyLight = true,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Brick" }

dlg:slider {
    id = "cols",
    label = "Cells:",
    min = 2,
    max = 32,
    value = defaults.cols
}

dlg:slider {
    id = "rows",
    min = 2,
    max = 32,
    value = defaults.rows
}

dlg:newrow { always = false }

dlg:slider {
    id = "offset",
    label = "Offset %:",
    min = -50,
    max = 50,
    value = defaults.offset
}

dlg:newrow { always = false }

dlg:number {
    id = "aspect",
    label = "Aspect:",
    text = string.format("%.1f", defaults.aspect),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:newrow { always = false }

dlg:slider {
    id = "skip",
    label = "Skip:",
    min = 1,
    max = 8,
    value = defaults.skip
}

dlg:slider {
    id = "pick",
    min = 1,
    max = 8,
    value = defaults.pick,
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
    id = "mortarThick",
    label = "Mortar Thickness:",
    min = 1,
    max = 64,
    value = defaults.mortarThick
}

dlg:newrow { always = false }

dlg:color {
    id = "mortarClr",
    label = "Mortar Color:",
    color = AseUtilities.hexToAseColor(defaults.mortarClr)
}

dlg:newrow { always = false }

dlg:color {
    id = "brickClr",
    label = "Brick Color:",
    color = AseUtilities.hexToAseColor(defaults.brickClr)
}

dlg:newrow { always = false }

dlg:slider {
    id = "variance",
    label = "Variance:",
    min = 0,
    max = 100,
    value = defaults.variance
}

dlg:newrow { always = false }

dlg:check {
    id = "varyLight",
    text = "L",
    selected = defaults.varyLight
}

dlg:check {
    id = "varyChroma",
    text = "C",
    selected = defaults.varyChroma
}

dlg:check {
    id = "varyHue",
    text = "H",
    selected = defaults.varyHue
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
        local cols <const> = args.cols or defaults.cols --[[@as integer]]
        local rows <const> = args.rows or defaults.rows --[[@as integer]]
        local off100 <const> = args.offset or defaults.offset --[[@as integer]]
        local aspect <const> = args.aspect or defaults.aspect --[[@as number]]
        local skip <const> = args.skip or defaults.skip --[[@as integer]]
        local pick <const> = args.pick or defaults.pick --[[@as integer]]
        local scale <const> = args.scale --[[@as number]]
        local mortarThick <const> = args.mortarThick
            or defaults.mortarThick --[[@as integer]]
        local xOrig <const> = args.xOrig --[[@as number]]
        local yOrig <const> = args.yOrig --[[@as number]]
        local brickColor <const> = args.brickClr --[[@as Color]]
        local mortarColor <const> = args.mortarClr --[[@as Color]]
        local vari100 <const> = args.variance
            or defaults.variance --[[@as integer]]

        local offset <const> = off100 * 0.01
        local sclval <const> = math.max(2.0, scale)

        local mesh <const> = Mesh2.gridBricks(
            cols, rows, offset, aspect, skip, pick)

        local t <const> = Mat3.fromTranslation(xOrig, yOrig)
        local s <const> = Mat3.fromScale(sclval, -sclval)
        local mat <const> = Mat3.mul(t, s)
        Utilities.mulMat3Mesh2(mat, mesh)

        local layer = nil
        app.transaction("New Layer", function()
            layer = sprite:newLayer()
            layer.name = mesh.name
        end)

        local brush <const> = Brush { size = mortarThick }

        local docPrefs <const> = app.preferences.document(sprite)
        local symmetryPrefs <const> = docPrefs.symmetry
        local oldSymmetry <const> = symmetryPrefs.mode
        symmetryPrefs.mode = 0

        if vari100 > 0 then
            -- time returns an integer, clock returns a number.
            math.randomseed(os.time())

            -- Unpack arguments.
            local varyLight <const> = args.varyLight --[[@as boolean]]
            local varyChroma <const> = args.varyChroma --[[@as boolean]]
            local varyHue <const> = args.varyHue --[[@as boolean]]

            -- Localize functions.
            local rng <const> = math.random
            local max <const> = math.max
            local min <const> = math.min
            local drawMesh2 <const> = ShapeUtilities.drawMesh2
            local lchTosRgba <const> = Clr.srLchTosRgb
            local clrToAseColor <const> = AseUtilities.clrToAseColor

            -- Find LCHA.
            local clr <const> = AseUtilities.aseColorToClr(brickColor)
            local lch <const> = Clr.sRgbToSrLch(clr, 0.007072)
            local lightBrick <const> = lch.l
            local chromaBrick <const> = lch.c
            local hueBrick <const> = lch.h
            local alpBrick <const> = lch.a

            -- Calculate offsets.
            local varNrm <const> = vari100 * 0.01
            local vnHalf <const> = varNrm * 0.5
            local varLgt <const> = varNrm * 100.0
            local vlHalf <const> = varLgt * 0.5
            local mxCrm <const> = Clr.SR_LCH_MAX_CHROMA
            local varCrm <const> = varNrm * mxCrm
            local vcHalf <const> = varCrm * 0.5

            -- Separate faces.
            local separated <const> = Mesh2.separateFaces(mesh)
            local sepLen <const> = #separated

            app.transaction("Bricks", function()
                local i = 0
                while i < sepLen do
                    i = i + 1
                    local hVary = hueBrick
                    if varyHue then
                        hVary = (hueBrick + varNrm * rng() - vnHalf) % 1.0
                    end

                    local cVary = chromaBrick
                    if varyChroma then
                        cVary = max(0.0, min(mxCrm,
                            chromaBrick + varCrm * rng() - vcHalf))
                    end

                    local lVary = lightBrick
                    if varyLight then
                        lVary = max(0.0, min(100.0,
                            lightBrick + varLgt * rng() - vlHalf))
                    end

                    local varyClr <const> = lchTosRgba(lVary, cVary, hVary, alpBrick)
                    local variety <const> = clrToAseColor(varyClr)

                    drawMesh2(
                        separated[i],
                        true, variety,
                        true, mortarColor,
                        brush, frame, layer)
                end
            end)
        else
            ShapeUtilities.drawMesh2(
                mesh,
                true, brickColor,
                true, mortarColor,
                brush, frame, layer)
        end

        symmetryPrefs.mode = oldSymmetry

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