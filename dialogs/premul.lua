local dlg = Dialog { title = "Pre-Multiply" }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local layers = sprite.layers
                local layerLen = #layers
                for i = 1, layerLen, 1 do
                    local layer = layers[i]
                    local cels = layer.cels
                    local celLen = #cels
                    for j = 1, celLen, 1 do
                        local cel = cels[j]
                        local image = cel.image
                        local pxitr = image:pixels()
                        for clr in pxitr do
                            local hex = clr()
                            local ai = hex >> 0x18 & 0xff

                            if ai < 0x1 then
                                clr(0x00000000)
                            elseif ai < 0xff then
                                local bi = hex >> 0x10 & 0xff
                                local gi = hex >> 0x08 & 0xff
                                local ri = hex & 0xff
                                local divisor = ai * 0.00392156862745098

                                clr(
                                    ai << 0x18
                                    | math.tointeger((bi * divisor + 0.5) << 0x10)
                                    | math.tointeger((gi * divisor + 0.5) << 0x08)
                                    | math.tointeger((ri * divisor + 0.5)))
                            end
                        end
                    end
                end
                app.refresh()
            else
                app.alert("No active sprite.")
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