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
    brickClr = Color(203, 65, 84, 255),
    variance = 10
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
    decimals = 5
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
    text = string.format("%.1f", defaults.scale),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xOrigin",
    label = "Origin:",
    text = string.format("%.1f", defaults.xOrigin),
    decimals = 5
}

dlg:number {
    id = "yOrigin",
    text = string.format("%.1f", defaults.yOrigin),
    decimals = 5
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
    id = "varyHue",
    text = "H",
    selected = false
}

dlg:check {
    id = "varySat",
    text = "S",
    selected = true
}

dlg:check {
    id = "varyLight",
    text = "L",
    selected = true
}

dlg:newrow { always = false }

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

            local brickClr = args.brickClr
            local mortarClr = args.mortarClr

            local sprite = AseUtilities.initCanvas(
                64, 64, mesh.name,
                { brickClr, mortarClr })
            local layer = sprite.layers[#sprite.layers]

            -- TODO: Set this to current frame?
            local cel = sprite:newCel(layer, 1)
            local brush = Brush(args.mortarThick)

            if args.variance > 0 then

                -- Separate into HSLA.
                local hueBrick = brickClr.hslHue
                local satBrick = brickClr.hslSaturation
                local lgtBrick = brickClr.hslLightness
                local alpBrick = brickClr.alpha

                -- Calculate offset.
                local varNrm = args.variance * 0.01
                local vnHalf = varNrm * 0.5
                local varHue = varNrm * 360.0
                local vhHalf = varHue * 0.5

                -- Separate faces.
                local separated = Mesh2.separateFaces(mesh)
                local sepLen = #separated
                app.transaction(function()
                    for i = 1, sepLen, 1 do

                        local hue = hueBrick
                        if args.varyHue then
                            hue = (hueBrick +
                                (varHue * math.random() - vhHalf)) % 360.0
                        end

                        local saturation = satBrick
                        if args.varySat then
                            saturation = math.max(0.0, math.min(1.0,
                                satBrick + (varNrm * math.random() - vnHalf)))
                        end

                        local lightness = lgtBrick
                        if args.varyLight then
                            lightness = math.max(0.0, math.min(1.0,
                                lgtBrick + (varNrm * math.random() - vnHalf)))
                        end

                        -- Composite HSLA.
                        local variety = Color {
                            hue = hue,
                            saturation = saturation,
                            lightness = lightness,
                            alpha = alpBrick
                        }

                        AseUtilities.drawMesh2(
                            separated[i],
                            true, variety,
                            true, mortarClr,
                            brush, cel, layer)
                    end
                end)
            else
                AseUtilities.drawMesh2(
                    mesh,
                    true, brickClr,
                    true, mortarClr,
                    brush, cel, layer)
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