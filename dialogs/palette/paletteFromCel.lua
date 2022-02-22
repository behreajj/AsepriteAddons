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
        local sprite = app.activeSprite
        if sprite then
            local cel = app.activeCel
            if cel then
                local colorMode = sprite.colorMode

                local args = dlg.data
                local removeAlpha = args.removeAlpha
                local target = args.target
                local clampTo256 = args.clampTo256
                local prependMask = args.prependMask

                local image = cel.image
                local itr = image:pixels()
                local dictionary = {}
                local idx = 1

                local alphaMask = 0
                if removeAlpha then
                    if colorMode == ColorMode.GRAY then
                        alphaMask = 0xff00
                    else
                        alphaMask = 0xff000000
                    end
                end

                if colorMode == ColorMode.INDEXED then
                    local srcPal = sprite.palettes[1]
                    local srcPalLen = #srcPal
                    for elm in itr do
                        local srcIndex = elm()
                        if srcIndex > -1 and srcIndex < srcPalLen then
                            local aseColor = srcPal:getColor(srcIndex)
                            if aseColor.alpha > 0 then
                                local hex = aseColor.rgbaPixel
                                hex = alphaMask | hex
                                if not dictionary[hex] then
                                    dictionary[hex] = idx
                                    idx = idx + 1
                                end
                            end
                        end
                    end
                elseif colorMode == ColorMode.GRAY then
                    for elm in itr do
                        local hexGray = elm()
                        if ((hexGray >> 0x08) & 0xff) > 0 then
                            hexGray = alphaMask | hexGray
                            local a = (hexGray >> 0x08) & 0xff
                            local v = hexGray & 0xff
                            local hex = a << 0x18 | v << 0x10 | v << 0x08 | v
                            if not dictionary[hex] then
                                dictionary[hex] = idx
                                idx = idx + 1
                            end
                        end
                    end
                else
                    for elm in itr do
                        local hex = elm()
                        if ((hex >> 0x18) & 0xff) > 0 then
                            hex = alphaMask | hex
                            if not dictionary[hex] then
                                dictionary[hex] = idx
                                idx = idx + 1
                            end
                        end
                    end
                end

                local hexes = {}
                for k, v in pairs(dictionary) do
                    hexes[v] = k
                end

                if prependMask then
                    local maskIdx = dictionary[0x0]
                    if maskIdx then
                        if maskIdx > 1 then
                            table.remove(hexes, maskIdx)
                            table.insert(hexes, 1, 0x0)
                        end
                    else
                        table.insert(hexes, 1, 0x0)
                    end
                end

                local hexesLen = #hexes
                if hexesLen > 0 then
                    local palLen = hexesLen
                    if clampTo256 then
                        palLen = math.min(256, hexesLen)
                    end

                    local palette = Palette(palLen)
                    for i = 1, palLen, 1 do
                        palette:setColor(i - 1,
                            AseUtilities.hexToAseColor(hexes[i]))
                    end

                    if target == "SAVE" then
                        local filepath = args.filepath
                        palette:saveAs(filepath)
                        app.alert("Palette saved.")
                    else
                        if colorMode == ColorMode.INDEXED then
                            -- Not sure how to get around this
                            -- for indexed...
                            app.command.ChangePixelFormat { format = "rgb" }
                            sprite:setPalette(palette)
                            app.command.ChangePixelFormat { format = "indexed" }
                        elseif colorMode == ColorMode.GRAY then
                            sprite:setPalette(palette)
                        else
                            sprite:setPalette(palette)
                        end

                    end
                end


                app.refresh()
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