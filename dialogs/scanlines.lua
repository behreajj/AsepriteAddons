dofile("../support/aseutilities.lua")

local defaults = {
    frames = 24,
    advance = -1,
    skip = 8,
    thick = 1,
    clr = Color(0xcf202020)
}

local dlg = Dialog { title = "Scanlines" }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 120,
    value = defaults.frames
}

dlg:newrow { always = false }

dlg:slider {
    id = "advance",
    label = "Advance:",
    min = -16,
    max = 16,
    value = defaults.advance
}

dlg:newrow { always = false }

dlg:slider {
    id = "skip",
    label = "Skip:",
    min = 2,
    max = 96,
    value = defaults.skip
}

dlg:newrow { always = false }


dlg:slider {
    id = "thick",
    label = "Thickness:",
    min = 1,
    max = 8,
    value = defaults.thick
}

dlg:newrow { always = false }

dlg:color {
    id = "clr",
    label = "Color:",
    color = defaults.clr
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local clr = args.clr
            local clrhex = clr.rgbaPixel

            local sprite = AseUtilities.initCanvas(
                64, 64, "Scanlines",
                { clr })

            -- Create requested number of frames.
            local reqFrames = args.frames
            local oldLen = #sprite.frames
            local needed = math.max(0, reqFrames - oldLen)
            for i = 1, needed, 1 do
                sprite:newEmptyFrame()
            end

            local layerCount = #sprite.layers
            local layer = sprite.layers[layerCount]
            local skip = args.skip
            local advance = args.advance
            local thick = args.thick
            local w = sprite.width

            -- Loop over frames.
            local offset = 0
            for i = 0, reqFrames - 1, 1 do
                local frame = sprite.frames[1 + i]
                local cel = sprite:newCel(layer, frame)
                local img = cel.image

                -- Loop over pixels.
                local itr = img:pixels()
                local j = 0
                for elm in itr do
                    local x = j % w
                    local y = j // w

                    if ((offset + y) % skip) // thick == 0 then
                        elm(clrhex)
                    end

                    j = j + 1
                end

                offset = offset + advance
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