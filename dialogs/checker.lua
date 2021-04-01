dofile("../support/aseutilities.lua")

local defaults = {
    cols = 8,
    rows = 8,
    aClr = Color(170, 170, 170, 255),
    bClr = Color(85, 85, 85, 255)
}

local dlg = Dialog { title = "Checker" }

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

dlg:color {
    id = "aClr",
    label = "Colors:",
    color = defaults.aClr
}

dlg:color {
    id = "bClr",
    color = defaults.bClr
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = AseUtilities.initCanvas(
                64, 64, "Checker",
                { args.aClr, args.bClr })
            local layer = sprite.layers[#sprite.layers]
            local cel = sprite:newCel(layer, 1)
            local image = cel.image

            local w = image.width
            local h = image.height

            -- Get integer hexadecimal from each color.
            local aClr = args.aClr.rgbaPixel
            local bClr = args.bClr.rgbaPixel

            -- Find size of each checker.
            local wch = w // args.cols
            local hch = h // args.rows

            local i = 0
            local iterator = image:pixels()
            for elm in iterator do
                local x = i % w
                local y = i // w

                -- Divide coordinate by checker size.
                local xmd = x // wch
                local ymd = y // hch

                -- If both x and y are even, then use color.
                if (xmd + ymd) % 2 == 0 then elm(bClr)
                else elm(aClr) end

                i = i + 1
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