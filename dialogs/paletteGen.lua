local dlg = Dialog { title="Palette Generator" }

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
}

local rgb = {
    Color(255,   0,   0, 255), -- Red
    Color(255, 128,   0, 255), -- Orange
    Color(255, 255,   0, 255), -- Yellow
    Color(128, 255,   0, 255),
    Color(  0, 255,   0, 255), -- Green
    Color(  0, 255, 128, 255),
    Color(  0, 255, 255, 255), -- Cyan
    Color(  0, 128, 255, 255),
    Color(  0,   0, 255, 255), -- Blue
    Color(128,   0, 255, 255),
    Color(255,   0, 255, 255), -- Magenta
    Color(255,   0, 128, 255)
}

dlg:shades {
    id = "hues",
    label = "Hues:",
    colors = ryb,
    -- mode = "pick",
    mode = "sort",
    onclick = function(ev)

        -- Needs to be "sort" to iterate over
        -- in OK, but needs to be "pick" to fire this.

        if ev.button == MouseButton.LEFT then
            app.fgColor = ev.color
        elseif ev.button == MouseButton.RIGHT then
            app.bgColor = ev.color
        end
    end
}

dlg:slider {
    id = "shades",
    label = "Shades:",
    min = 1,
    max = 32,
    value = 8
}

dlg:newrow { always = false }

dlg:slider {
    id = "saturation",
    label = "Saturation:",
    min = 1,
    max = 100,
    value = 100
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 1,
    max = 100,
    value = 15
}

dlg:slider {
    id = "maxLight",
    min = 0,
    max = 99,
    value = 85
}

dlg:newrow { always = false }

dlg:check {
    id = "inclGray",
    label = "Include Gray: ",
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

            local lenHues = #args.hues
            local lenShades = args.shades or 8
            local inclGray = args.inclGray or false
            local totLen = lenHues * lenShades
            local grayLen = 0
            if inclGray then grayLen = lenShades end
            local palette = Palette(totLen + grayLen)

            local lmin = args.minLight * 0.01
            local lmax = args.maxLight * 0.01

            local sat = args.saturation * 0.01

            local k = 0
            local jToFac = 1.0 / (lenShades - 1.0)
            for i = 1, lenHues, 1 do
                local clr = args.hues[i]
                local h = clr.hslHue
                local sold = clr.hslSaturation
                local a = clr.alpha
                local snew = sold * sat
                for j = 1, lenShades, 1 do
                    local t = (j - 1.0) * jToFac
                    local u = 1.0 - t
                    local lnew = u * lmin + t * lmax

                    local newclr = Color {
                        h = h,
                        s = snew,
                        l = lnew,
                        a = a }
                    palette:setColor(k, newclr)
                    k = k + 1
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

            app.activeSprite:setPalette(palette)
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