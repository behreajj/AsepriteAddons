local dlg = Dialog { title = "Palette Subset" }

dlg:combobox {
    id = "palType",
    label = "Palette:",
    option = "ACTIVE",
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.palType

        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "palPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "...",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIdx",
    label = "Scaled Index:",
    min = 0,
    max = 32,
    value = 0
}

dlg:newrow { always = false }

dlg:slider {
    id = "stride",
    label = "Stride:",
    min = 2,
    max = 32,
    value = 8
}

dlg:newrow { always = false }

dlg:slider {
    id = "cycle",
    label = "Cycle:",
    min = 0,
    max = 32,
    value = 0
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
            if sprite then

                local srcPal = nil
                local palType = args.palType
                if palType == "FILE" then
                    srcPal = Palette { fromFile = args.palFile }
                elseif palType == "PRESET" then
                    srcPal = Palette { fromResource = args.palPreset }
                else
                    srcPal = sprite.palettes[1]
                end

                if srcPal then
                    local oldMode = sprite.colorMode
                    app.command.ChangePixelFormat { format = "rgb" }

                    local origin = args.startIdx
                    local stride = args.stride
                    local cycle = args.cycle
                    local sclOrig = stride * origin
                    local trgPal = Palette(stride)
                    local srcLen = #srcPal
                    for i = 0, stride - 1, 1 do
                        local j = (cycle + i) % stride
                        local k = (sclOrig + j) % srcLen
                        trgPal:setColor(i, srcPal:getColor(k))
                    end

                    sprite:setPalette(trgPal)

                    if oldMode == ColorMode.INDEXED then
                        app.command.ChangePixelFormat { format = "indexed" }
                    elseif oldMode == ColorMode.GRAY then
                        app.command.ChangePixelFormat { format = "gray" }
                    end
                end

            else
                app.alert("There is no active sprite.")
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