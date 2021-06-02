local dlg = Dialog { title = "Palette From Cel" }

dlg:check {
   id = "removeAlpha",
   label = "Remove Alpha:",
   selected = true
}

dlg:check {
    id = "clampTo256",
    label = "Clamp To 256:",
    selected = true
 }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local cel = app.activeCel
                if cel then
                    local image = cel.image
                    if image then
                        local oldMode = sprite.colorMode
                        app.command.ChangePixelFormat { format = "rgb" }

                        local itr = image:pixels()
                        local dictionary = {}
                        local idx = 0
                        local removeAlpha = args.removeAlpha

                        if removeAlpha then
                            for elm in itr do
                                local hex = elm()
                                if hex ~= 0x00000000 then
                                    local hexNoAlpha = hex | 0xff000000
                                    if not dictionary[hexNoAlpha] then
                                        idx = idx + 1
                                        dictionary[hexNoAlpha] = idx
                                    end
                                end
                            end
                        else
                            for elm in itr do
                                local hex = elm()
                                if not dictionary[hex] then
                                    local alpha = hex & 0xff000000
                                    if alpha > 0 then
                                        idx = idx + 1
                                        dictionary[hex] = idx
                                    end
                                end
                            end
                        end

                        if idx > 0 then
                            local len = idx
                            if args.clampTo256 then
                                len = math.min(256, len)
                            end
                            local palette = Palette(len)
                            for hex, i in pairs(dictionary) do
                                local j = i - 1
                                if j < len then
                                    palette:setColor(j, hex)
                                end
                            end
                            sprite:setPalette(palette)
                        end

                        if oldMode == ColorMode.INDEXED then
                            app.command.ChangePixelFormat { format = "indexed" }
                        elseif oldMode == ColorMode.GRAY then
                            app.command.ChangePixelFormat { format = "gray" }
                        end

                        app.refresh()
                    else
                        app.alert("Cel does not contain an image.")
                    end
                else
                    app.alert("There is no active cel.")
                end
            else
                app.alert("There is no active sprite.")
            end
        else
            app.alert("Dialog arguments are invalid.")
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