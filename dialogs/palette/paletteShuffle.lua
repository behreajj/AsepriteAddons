dofile("../../support/aseutilities.lua")

local dlg = Dialog { title = "Palette Shuffle" }

dlg:combobox {
    id = "palType",
    label = "Source:",
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
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
    open = true,
    visible = false
}

dlg:newrow { always = false }

dlg:entry {
    id = "palPreset",
    text = "",
    focus = false,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = "ACTIVE",
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
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local args = dlg.data
            local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                args.palType, args.palFile, args.palPreset, 0, 256, true)

            local trgHexes = Utilities.shuffle(hexesProfile)

            if args.prependMask then
                Utilities.prependMask(trgHexes)
            end

            local target = args.target
            if target == "SAVE" then
                local filepath = args.filepath
                if filepath and #filepath > 0 then
                    local targetPal = AseUtilities.hexArrToAsePalette(trgHexes)
                    targetPal:saveAs(filepath)
                else
                    app.alert("Invalid filepath.")
                end
            else
                activeSprite:setPalette(
                    AseUtilities.hexArrToAsePalette(trgHexes))
            end

            AseUtilities.changePixelFormat(oldMode)
            app.refresh()
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