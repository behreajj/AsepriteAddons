dofile("../../support/utilities.lua")
dofile("../../support/aseutilities.lua")

local hueEasing = { "FAR", "NEAR" }

local ryb = {
    Color(255,  0,    0), -- 0xFF0000FF
    Color(255,  80,   0), -- 0xFF0050FF
    Color(255, 134,   0), -- 0xFF0086FF
    Color(255, 174,   0), -- 0xFF00AEFF
    Color(255, 207,   0), -- 0xFF00CFFF
    Color(255, 243,   0), -- 0xFF00F3FF
    Color(192, 234,  13), -- 0xFF0DEAC0
    Color( 97, 201,  32), -- 0xFF20C961
    Color(  0, 169,  51), -- 0xFF33A900
    Color( 16, 141,  89), -- 0xFF598D10
    Color( 19, 110, 134), -- 0xFF866E13
    Color( 28,  77, 161), -- 0xFFA14D1C
    Color( 60,  42, 146), -- 0xFF922A3C
    Color( 94,  19, 136), -- 0xFF88135E
    Color(137,   6, 109), -- 0xFF6D0689
    Color(191,   0,  64), -- 0xFF4000BF
    Color(255,   0,   0)  -- 0xFF0000FF
}

local hues = {
    [0xFF0000FF] = 0.0,
    [0xFF0050FF] = 22.5,
    [0xFF0086FF] = 45.0,
    [0xFF00AEFF] = 67.5,
    [0xFF00CFFF] = 90.0,
    [0xFF00F3FF] = 112.5,
    [0xFF0DEAC0] = 135.0,
    [0xFF20C961] = 157.5,
    [0xFF33A900] = 180.0,
    [0xFF598D10] = 202.5,
    [0xFF866E13] = 225.0,
    [0xFFA14D1C] = 247.5,
    [0xFF922A3C] = 270.0,
    [0xFF88135E] = 292.5,
    [0xFF6D0689] = 315.0,
    [0xFF4000BF] = 337.5
}

local dlg = Dialog { title = "Palette Generator" }

dlg:shades {
    id = "hues",
    label = "Preview:",
    colors = ryb,
    mode = "pick",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            local hue = math.tointeger(hues[ev.color.rgbaPixel])
            dlg:modify {
                id = "hueStart",
                value = hue
            }
        elseif ev.button == MouseButton.RIGHT then
            local hue = math.tointeger(hues[ev.color.rgbaPixel])
            dlg:modify {
                id = "hueEnd",
                value = hue
            }
        end
    end
}

dlg:slider {
    id = "samples",
    label = "Samples:",
    min = 1,
    max = 32,
    value = 12
}

dlg:newrow { always = false }

dlg:slider {
    id = "shades",
    label = "Shades:",
    min = 1,
    max = 32,
    value = 7
}

dlg:newrow { always = false }

dlg:slider {
    id = "hueStart",
    label = "Hue:",
    min = 0,
    max = 360,
    value = 0
}

dlg:slider {
    id = "hueEnd",
    min = 0,
    max = 360,
    value = 359
}

dlg:newrow { always = false }

dlg:slider {
    id = "saturation",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = 100
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = 10
}

dlg:slider {
    id = "maxLight",
    min = 0,
    max = 100,
    value = 85
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingFuncHue",
    label = "Easing:",
    option = "FAR",
    options = hueEasing
}

dlg:newrow { always = false }

dlg:check {
    id = "inclGray",
    label = "Include Gray:",
    selected = false
}

dlg:newrow { always = false }

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
            end

            local oldMode = sprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local sat = args.saturation * 0.01

            local lenSamples = args.samples or 8
            local lenShades = args.shades or 8
            local inclGray = args.inclGray or (sat <= 0)
            local totLen = 0
            if sat > 0 then
                totLen = lenSamples * lenShades
            end
            local grayLen = 0
            if inclGray then grayLen = lenShades end
            local palette = Palette(totLen + grayLen)

            local hueStart = args.hueStart * 0.002777777777777778
            local hueEnd = args.hueEnd * 0.002777777777777778

            local hueFunc = nil
            if args.easingFuncHue == "NEAR" then
                hueFunc = function(a, b, t) 
                    return Utilities.lerpAngleNear(a, b, t, 1.0)
                end
            elseif args.easingFuncHue == "FAR" then
                hueFunc = function(a, b, t)
                    return Utilities.lerpAngleFar(a, b, t, 1.0)
                end
            end

            local lmin = args.minLight * 0.01
            local lmax = args.maxLight * 0.01

            local k = 0
            local jToFac = 1.0
            if lenShades > 1 then jToFac = 1.0 / (lenShades - 1.0) end

            -- TODO: Add option to saturate values as
            -- they get darker?
            if sat > 0 then
                local iToFac = 1.0
                if lenSamples > 1 then iToFac = 1.0 / (lenSamples - 1.0) end
                for i = 1, lenSamples, 1 do
                    local iFac = (i - 1.0) * iToFac
                    local hueFac = hueFunc(hueStart, hueEnd, iFac)
                    local hex = AseUtilities.lerpColorArr(ryb, hueFac)
                    local clr = Color(hex)

                    local h = clr.hslHue
                    local sold = clr.hslSaturation
                    local snew = sold * sat
                    local lold = clr.hslLightness
                    local diff = 0.5 * (0.5 - lold)
                    local a = clr.alpha

                    for j = 1, lenShades, 1 do
                        local jFac = (j - 1.0) * jToFac

                        local jFacAdj = math.min(1.0, math.max(0.0, jFac - diff))
                        jFacAdj = jFacAdj ^ (1.5)
                        local lnew = (1.0 - jFacAdj) * lmin + jFacAdj * lmax

                        local newclr = Color {
                            h = h,
                            s = snew,
                            l = lnew,
                            a = a }
                        palette:setColor(k, newclr)
                        k = k + 1
                    end
                end
            end

            if inclGray then
                for j = 1, lenShades, 1 do
                    local t = (j - 1.0) * jToFac
                    local u = 1.0 - t
                    local lnew = u * lmin + t * lmax
                    local grayClr = Color {
                        h = 0.0,
                        s = 0.0,
                        l = lnew,
                        a = 255 }
                    palette:setColor(k, grayClr)
                    k = k + 1
                end
            end

            sprite:setPalette(palette)

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()
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