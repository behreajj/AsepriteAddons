local dlg = Dialog { title = "Concatenate Palettes" }

dlg:combobox {
    id = "aPalType",
    label = "Palette A:",
    option = "ACTIVE",
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.aPalType

        dlg:modify {
            id = "aPalFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "aPalPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:file {
    id = "aPalFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = false
}

dlg:entry {
    id = "aPalPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "bPalType",
    label = "Palette B:",
    option = "FILE",
    options = { "ACTIVE", "FILE", "PRESET" },
    onchange = function()
        local state = dlg.data.bPalType

        dlg:modify {
            id = "bPalFile",
            visible = state == "FILE"
        }

        dlg:modify {
            id = "bPalPreset",
            visible = state == "PRESET"
        }
    end
}

dlg:file {
    id = "bPalFile",
    filetypes = { "gpl", "pal" },
    open = true,
    visible = true
}

dlg:entry {
    id = "bPalPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = false
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

                local aPal = nil
                local aPalType = args.aPalType
                if aPalType == "FILE" then
                    local afp = args.aPalFile
                    if afp and #afp > 0 then
                        aPal = Palette { fromFile = afp }
                    end
                elseif aPalType == "PRESET" then
                    local apr = args.aPalPreset
                    if apr and #apr > 0 then
                        aPal = Palette { fromResource = apr }
                    end
                else
                    aPal = sprite.palettes[1]
                end

                local bPal = nil
                local bPalType = args.bPalType
                if bPalType == "FILE" then
                    local bfp = args.bPalFile
                    if bfp and #bfp > 0 then
                        bPal = Palette { fromFile = bfp }
                    end
                elseif bPalType == "PRESET" then
                    local bpr = args.bPalPreset
                    if bpr and #bpr > 0 then
                        bPal = Palette { fromResource = bpr }
                    end
                else
                    bPal = sprite.palettes[1]
                end

                if aPal and bPal then
                    local oldMode = sprite.colorMode
                    app.command.ChangePixelFormat { format = "rgb" }

                    local cPal = nil
                    local aLen = #aPal
                    local bLen = #bPal

                    if args.uniquesOnly then

                        local clrKeys = {}
                        local idx = 0

                        for i = 0, aLen - 1, 1 do
                            local hex = aPal:getColor(i).rgbaPixel
                            if not clrKeys[hex] then
                                idx = idx + 1
                                clrKeys[hex] = idx
                            end
                        end

                        for j = 0, bLen - 1, 1 do
                            local hex = bPal:getColor(j).rgbaPixel
                            if not clrKeys[hex] then
                                idx = idx + 1
                                clrKeys[hex] = idx
                            end
                        end

                        local clrVals = {}
                        for k, m in pairs(clrKeys) do
                            clrVals[m] = k
                        end

                        local cLen = #clrVals
                        cPal = Palette(cLen)
                        for m = 0, cLen - 1, 1 do
                            cPal:setColor(m, Color(clrVals[m + 1]))
                        end
                    else
                        local cLen = aLen + bLen
                        cPal = Palette(cLen)

                        for i = 0, aLen - 1, 1 do
                            cPal:setColor(i, aPal:getColor(i))
                        end

                        for j = 0, bLen - 1, 1 do
                            local k = #aPal + j
                            cPal:setColor(k, bPal:getColor(j))
                        end
                    end

                    sprite:setPalette(cPal)

                    if oldMode == ColorMode.INDEXED then
                        app.command.ChangePixelFormat { format = "indexed" }
                    elseif oldMode == ColorMode.GRAY then
                        app.command.ChangePixelFormat { format = "gray" }
                    end
                else
                    app.alert("One of the palettes could not be found.")
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