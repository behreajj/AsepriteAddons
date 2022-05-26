dofile("../../support/clr.lua")
dofile("../../support/aseutilities.lua")

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
    brickClr = Color(203, 65, 84, 255),
    variance = 10,
    varyHue = false,
    varyChroma = true,
    varyLight = true,
    pullFocus = false
}

local dlg = Dialog { title = "Brick" }

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
    id = "frequency",
    label = "Frequency:",
    min = 2,
    max = 8,
    value = defaults.frequency
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
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.3f", defaults.xOrigin),
    decimals = AseUtilities.DISPLAY_DECIMAL
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.3f", defaults.yOrigin),
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
    color = defaults.mortarClr
}

dlg:newrow { always = false }

dlg:color{
    id = "brickClr",
    label = "Brick Color:",
    color = defaults.brickClr
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
        local args = dlg.data
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

        local brickColor = args.brickClr or defaults.brickClr
        local mortarColor = args.mortarClr or defaults.mortarClr

        local sprite = AseUtilities.initCanvas(
            64, 64, mesh.name,
            { brickColor.rgbaPixel,
              mortarColor.rgbaPixel })
        local layer = sprite.layers[#sprite.layers]

        local frame = app.activeFrame or sprite.frames[1]
        local cel = sprite:newCel(layer, frame)
        local brush = Brush(args.mortarThick)

        if args.variance > 0 then

            -- Unpack arguments.
            local varyLight = args.varyLight
            local varyChroma = args.varyChroma
            local varyHue = args.varyHue

            -- Find LCHA.
            local clr = AseUtilities.aseColorToClr(brickColor)
            local lch = Clr.sRgbaToLch(clr)
            local lightBrick = lch.l
            local chromaBrick = lch.c
            local hueBrick = lch.h
            local alpBrick = lch.a

            -- Calculate offsets.
            local varNrm = args.variance * 0.01
            local vnHalf = varNrm * 0.5
            local varLgt = varNrm * 100.0
            local vlHalf = varLgt * 0.5
            local varCrm = varNrm * 135.0
            local vcHalf = varCrm * 0.5

            -- Separate faces.
            local separated = Mesh2.separateFaces(mesh)
            local sepLen = #separated

            -- Localize functions.
            local rng = math.random
            local max = math.max
            local min = math.min
            local drawMesh2 = AseUtilities.drawMesh2
            local lchTosRgba = Clr.lchTosRgba
            local clrToAseColor = AseUtilities.clrToAseColor

            app.transaction(function()
                for i = 1, sepLen, 1 do

                    local hVary = hueBrick
                    if varyHue then
                        hVary = (hueBrick + varNrm * rng() - vnHalf) % 1.0
                    end

                    local cVary = chromaBrick
                    if varyChroma then
                        cVary = max(0.0, min(135.0,
                            chromaBrick + varCrm * rng() - vcHalf))
                    end

                    local lVary = lightBrick
                    if varyLight then
                        lVary = max(0.0, min(100.0,
                            lightBrick + varLgt * rng() - vlHalf))
                    end

                    -- Don't use { hue, saturation, lightness, alpha }
                    -- Color constructor. There is a bug with the API.
                    local varyClr = lchTosRgba(lVary, cVary, hVary, alpBrick)
                    local variety = clrToAseColor(varyClr)

                    drawMesh2(
                        separated[i],
                        true, variety,
                        true, mortarColor,
                        brush, cel, layer)
                end
            end)
        else
            AseUtilities.drawMesh2(
                mesh,
                true, brickColor,
                true, mortarColor,
                brush, cel, layer)
        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }