dofile("../../support/aseutilities.lua")

local defaults = {
    removeAlpha = true,
    clampTo256 = true,
    prependMask = true,
    target = "ACTIVE",
    pullFocus = false
}

local dlg = Dialog { title = "Palette From Cel" }

dlg:check {
   id = "removeAlpha",
   label = "Opaque Colors:",
   selected = defaults.removeAlpha
}

dlg:check {
    id = "clampTo256",
    label = "Clamp To 256:",
    selected = defaults.clampTo256
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = { "ACTIVE", "SAVE" },
    onchange = function()
        local md = dlg.data.target
        dlg:modify {
            id = "filepath",
            visible = md == "SAVE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    save = true,
    visible = defaults.target == "SAVE"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
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

                    local prependMask = args.prependMask
                    if prependMask then
                        idx = idx + 1
                        dictionary[0x00000000] = idx
                    end

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
                                if alpha ~= 0 then
                                    idx = idx + 1
                                    dictionary[hex] = idx
                                end
                            end
                        end
                    end

                    if idx > 0 then
                        local len = idx
                        local clampTo256 = args.clampTo256
                        if clampTo256 then
                            len = math.min(256, len)
                        end

                        local palette = Palette(len)
                        for hex, i in pairs(dictionary) do
                            local j = i - 1
                            if j < len then
                                palette:setColor(j, AseUtilities.hexToAseColor(hex))
                            end
                        end

                        local target = args.target
                        if target == "SAVE" then
                            local filepath = args.filepath
                            palette:saveAs(filepath)
                            app.alert("Palette saved.")
                        else
                            sprite:setPalette(palette)
                        end
                    end

                    AseUtilities.changePixelFormat(oldMode)
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
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }