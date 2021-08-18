local palTypes = { "ACTIVE", "FILE", "PRESET" }

local defaults = {
    aPalType = "ACTIVE",
    bPalType = "FILE",
    uniquesOnly = true,
    prependMask = true,
    target = "ACTIVE",
    pullFocus = false
}

local dlg = Dialog { title = "Concatenate Palettes" }

dlg:combobox {
    id = "aPalType",
    label = "Source A:",
    option = defaults.aPalType,
    options = palTypes,
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
    filetypes = { "aseprite", "gpl", "pal" },
    open = true,
    visible = defaults.aPalType == "FILE"
}

dlg:entry {
    id = "aPalPreset",
    text = "",
    focus = false,
    visible = defaults.aPalType == "PRESET"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "bPalType",
    label = "Source B:",
    option = defaults.bPalType,
    options = palTypes,
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
    filetypes = { "aseprite", "gpl", "pal" },
    open = true,
    visible = defaults.bPalType == "FILE"
}

dlg:entry {
    id = "bPalPreset",
    text = "",
    focus = false,
    visible = defaults.bPalType == "PRESET"
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = defaults.uniquesOnly
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
    filetypes = { "aseprite", "gpl", "pal", "png" },
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

                local prependMask = args.prependMask
                local uniquesOnly = args.uniquesOnly

                if uniquesOnly then

                    local clrKeys = {}
                    local idx = 0
                    if prependMask then
                        idx = 1
                    end

                    for i = 0, aLen - 1, 1 do
                        local hex = aPal:getColor(i).rgbaPixel
                        local alpha = hex & 0xff000000
                        if alpha == 0 then hex = 0x00000000 end
                        if not clrKeys[hex] then
                            idx = idx + 1
                            clrKeys[hex] = idx
                        end
                    end

                    for j = 0, bLen - 1, 1 do
                        local hex = bPal:getColor(j).rgbaPixel
                        local alpha = hex & 0xff000000
                        if alpha == 0 then hex = 0x00000000 end
                        if not clrKeys[hex] then
                            idx = idx + 1
                            clrKeys[hex] = idx
                        end
                    end

                    if prependMask then
                        clrKeys[0] = 1
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
                    local offset = 0
                    local noMask = aPal:getColor(0).rgbaPixel ~= 0
                    if prependMask and noMask then
                        offset = 1
                        cLen = cLen + 1
                    end
                    cPal = Palette(cLen)

                    for i = 0, aLen - 1, 1 do
                        cPal:setColor(offset + i, aPal:getColor(i))
                    end

                    for j = 0, bLen - 1, 1 do
                        local k = #aPal + j
                        cPal:setColor(offset + k, bPal:getColor(j))
                    end

                    if prependMask and noMask then
                        cPal:setColor(0, Color(0, 0, 0, 0))
                    end
                end

                local target = args.target
                if target == "SAVE" then
                    local filepath = args.filepath
                    if filepath and #filepath > 0 then
                        cPal:saveAs(filepath)
                    else
                        app.alert("Invalid filepath.")
                    end
                else
                    sprite:setPalette(cPal)
                end

                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()
            else
                app.alert("One of the palettes could not be found.")
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