dofile("../../support/aseutilities.lua")

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
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
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
    filetypes = { "aseprite", "gpl", "pal", "png", "webp" },
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
        local activeSprite = app.activeSprite
        if activeSprite then

            local oldMode = activeSprite.colorMode
            app.command.ChangePixelFormat { format = "rgb" }

            local aHexesProfile, _ = AseUtilities.asePaletteLoad(
                args.aPalType, args.aPalFile, args.aPalPreset, 0, 256, true)

            local bHexesProfile, _ = AseUtilities.asePaletteLoad(
                args.bPalType, args.bPalFile, args.bPalPreset, 0, 256, true)

            local aLen = #aHexesProfile
            local bLen = #bHexesProfile
            local cHexes = {}

            for i = 1, aLen, 1 do
                cHexes[i] = aHexesProfile[i]
            end

            for j = 1, bLen, 1 do
                cHexes[aLen + j] = bHexesProfile[j]
            end

            local uniquesOnly = args.uniquesOnly
            if uniquesOnly then
                local uniques, _ = Utilities.uniqueColors(cHexes, true)
                cHexes = uniques
            end

            local prependMask = args.prependMask
            if prependMask then
                Utilities.prependMask(cHexes)
            end

            local target = args.target
            if target == "SAVE" then
                local filepath = args.filepath
                if filepath and #filepath > 0 then
                    local cPal = AseUtilities.hexArrToAsePalette(cHexes)
                    cPal:saveAs(filepath)
                else
                    app.alert("Invalid filepath.")
                end
            else
                activeSprite:setPalette(AseUtilities.hexArrToAsePalette(cHexes))
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