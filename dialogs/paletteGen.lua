local dlg = Dialog { title="Palette Generator" }

local ryb = {
    Color(255,   0,   0, 255),
    Color(255, 125,   0, 255),
    Color(255, 192,   0, 255),
    Color(255, 255,   0, 255),
    Color( 86, 198,  34, 255),
    Color( 14, 144,  85, 255),
    Color( 17,  89, 166, 255),
    Color( 75,  32, 142, 255),
    Color(148,   4, 101, 255)
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

local viridis = {
    Color(68, 1, 84, 255),
    Color(70, 50, 126, 255),
    Color(54, 92, 140, 255),
    Color(39, 127, 142, 255),
    Color(34, 161, 135, 255),
    Color(75, 193, 109, 255),
    Color(159, 217, 57, 255),
    Color(253, 231, 37, 255)
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

dlg:slider {
    id = "minLight",
    label = "Min Light:",
    min = 0,
    max = 100,
    value = 15
}

dlg:slider {
    id = "maxLight",
    label = "Max Light:",
    min = 0,
    max = 100,
    value = 85
}

dlg:check {
    id = "inclGray",
    label = "Include Gray: ",
    selected = true
}

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

            local k = 0
            local jToFac = 1.0 / (lenShades - 1.0)
            for i = 1, lenHues, 1 do
                local clr = args.hues[i]
                local h = clr.hslHue
                local s = clr.hslSaturation
                local a = clr.alpha
                for j = 1, lenShades, 1 do
                    local t = (j - 1.0) * jToFac
                    local u = 1.0 - t
                    local lnew = u * lmin + t * lmax

                    local newclr = Color {
                        h = h,
                        s = s,
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