local dlg = Dialog { title="Palette Generator" }

local ryb = {
    Color(255, 0, 0, 255),
    Color(255, 64, 0, 255),
    Color(255, 128, 0, 255),
    Color(255, 191, 0, 255),
    Color(255, 255, 0, 255),
    Color(129, 212, 26, 255),
    Color(0, 169, 51, 255),
    Color(21, 132, 102, 255),
    Color(42, 96, 153, 255),
    Color(85, 48, 141, 255),
    Color(128, 0, 128, 255),
    Color(191, 0, 64, 255)
}

local viridis = {
    Color(68, 1, 84, 255),
    Color(72, 26, 107, 255),
    Color(70, 47, 124, 255),
    Color(65, 68, 135, 255),
    Color(57, 87, 140, 255),
    Color(49, 103, 141, 255),
    Color(42, 120, 142, 255),
    Color(36, 136, 141, 255),
    Color(31, 152, 138, 255),
    Color(36, 168, 132, 255),
    Color(54, 183, 120, 255),
    Color(83, 197, 104, 255),
    Color(122, 210, 81, 255),
    Color(165, 219, 53, 255),
    Color(210, 226, 29, 255),
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

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            -- TODO: Add include gray scale tick box.
            -- If true add ramp from black to white
            -- or min lum to max lum.
            -- hue shift for if lum is < or > 0.5?

            local lenHues = #args.hues
            local lenShades = args.shades
            local totLen = lenHues * lenShades
            local palette = Palette(totLen)

            local lmin = args.minLight * 0.01
            local lmax = args.maxLight * 0.01

            local k = 0
            for i = 1, lenHues, 1 do
                local clr = args.hues[i]
                local h = clr.hslHue
                local s = clr.hslSaturation
                local a = clr.alpha
                for j = 1, lenShades, 1 do
                    local t = (j - 1.0) / (lenShades - 1.0)
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

            app.activeSprite:setPalette(palette)
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