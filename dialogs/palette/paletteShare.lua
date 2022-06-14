local defaults = {
    palType = "ACTIVE",
    uniquesOnly = false,
    prependMask = true,
    startIndex = 0,
    count = 256,
    pullFocus = false
}

local dlg = Dialog { title = "Share Palette" }

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
    id = "uniquesOnly",
    label = "Uniques Only:",
    selected = defaults.uniquesOnly
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = false,
}

dlg:newrow { always = false }

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.count
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data
        local palFile = args.palFile
        local palPreset = args.palPreset
        local palType = args.palType or defaults.palType
        local prependMask = args.prependMask
        local startIndex = args.startIndex or defaults.startIndex
        local count = args.count or defaults.count

        local hexesProfile = {}
        local hexesSrgb = {}

        hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, palFile, palPreset,
            startIndex, count, true)

        local uniquesOnly = args.uniquesOnly
        if uniquesOnly then
            local uniques, _ = Utilities.uniqueColors(
                hexesSrgb, true)
            hexesSrgb = uniques
        end

        if prependMask then
            Utilities.prependMask(hexesSrgb)
        end

        local candidates = {}
        -- local rejected = {}
        local profileNone = ColorSpace()
        local profileSrgb = ColorSpace { sRGB = true }
        local openSprites = app.sprites
        local openLen = #openSprites
        local errorFlag = false
        local h = 0
        while h < openLen do h = h + 1
            local sprite = openSprites[h]
            local colorMode = sprite.colorMode
            local profile = sprite.colorSpace

            if colorMode == ColorMode.RGB
                and (profile == nil
                    or profile == profileNone
                    or profile == profileSrgb) then
                table.insert(candidates, sprite)
            else
                errorFlag = true
                -- table.insert(rejected, sprite)
            end
        end

        local candLen = #candidates
        local i = 0
        while i < candLen do i = i + 1
            local candidate = candidates[i]
            local lenPals = #candidate.palettes
            -- This isn't as efficient as it could be
            -- because the same Aseprite Colors are
            -- recreated for each target palette when
            -- they are converted by value anyway.
            local j = 0
            while j < lenPals do j = j + 1
                AseUtilities.setSpritePalette(
                    hexesSrgb, candidate, j)
            end
        end

        app.refresh()

        if errorFlag then
            app.alert {
                title = "Warning",
                text = {
                    "Not all sprites were included by script.",
                    "Check to see sprite is in RGB color mode",
                    "and has either None or SRGB color profile."
                }
            }
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
