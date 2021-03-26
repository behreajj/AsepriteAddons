dofile("../support/aseutilities.lua")

local dlg = Dialog { title = "Checker" }

dlg:slider {
    id = "cols",
    label = "Columns:",
    min = 2,
    max = 32,
    value = 8
}

dlg:slider {
    id = "rows",
    label = "Rows:",
    min = 2,
    max = 32,
    value = 8
}

dlg:color {
    id = "aClr",
    label = "Color A:",
    color = Color(170, 170, 170, 255)
}

dlg:color {
    id = "bClr",
    label = "Color B:",
    color = Color(85, 85, 85, 255)
}

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