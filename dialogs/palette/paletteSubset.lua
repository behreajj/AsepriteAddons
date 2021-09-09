dofile("../../support/aseutilities.lua")

local dlg = Dialog { title = "Palette Subset" }

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
    filetypes = { "aseprite", "gpl", "pal" },
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

dlg:slider {
        id = "startIdx",
        label = "Start Index:",
        min = 0,
        max = 255,
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

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = true,
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
    filetypes = { "aseprite", "gpl", "pal" },
    save = true,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        local activeSprite = app.activeSprite
        if activeSprite then

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
                args.palType, args.palFile, args.palPreset, 0, 256, true)

            local origin = args.startIdx
            local stride = args.stride
            local srcLen = #hexesProfile

            local trgHexes = {}
            for i = 0, stride - 1, 1 do
                local j = i % stride
                local k = (origin + j) % srcLen
                trgHexes[1 + i] = hexesProfile[1 + k]
            end

            local prependMask = args.prependMask
            if prependMask then
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