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
        local profileNone = ColorSpace()
        local profileSrgb = ColorSpace { sRGB = true }
        local profActive = profileSrgb

        local args = dlg.data
        local palType = args.palType or defaults.palType

        local activeSprite = app.activeSprite
        if activeSprite then
            profActive = activeSprite.colorSpace
        else
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local openSprites = app.sprites
        local openLen = #openSprites
        if openLen < 2 then
            app.alert {
                title = "Error",
                text = "There is only one open sprite."
            }
            return
        end

        local palFile = args.palFile
        local palPreset = args.palPreset
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

        local candidatesApprox = {}
        local candidatesExact = {}
        local rejected = {
            "Not all sprites were included by script.",
            "Check to see sprite is in RGB color mode",
            "and has a matching color profile. Excluded:"
        }

        local candLenApprox = 0
        local candLenExact = 0
        local rejLen = #rejected

        local errorFlag = false
        local h = 0
        while h < openLen do h = h + 1
            local sprite = openSprites[h]
            local colorMode = sprite.colorMode
            local profile = sprite.colorSpace
            local filename = app.fs.fileTitle(sprite.filename)

            if colorMode == ColorMode.RGB then

                if profile == profActive then

                    candLenExact = candLenExact + 1
                    candidatesExact[candLenExact] = sprite

                elseif (profile == nil
                    or profile == profileSrgb
                    or profile == profileNone) then

                    candLenApprox = candLenApprox + 1
                    candidatesApprox[candLenApprox] = sprite

                else

                    errorFlag = true
                    rejLen = rejLen + 1
                    rejected[rejLen] = filename

                end

            else
                errorFlag = true
                rejLen = rejLen + 1
                rejected[rejLen] = filename
            end
        end

        local i = 0
        while i < candLenApprox do i = i + 1
            local candidate = candidatesApprox[i]
            -- print(string.format("approx: %s", candidate.filename))

            local lenPals = #candidate.palettes
            -- This isn't as efficient as it could be
            -- because the same Aseprite Colors are
            -- recreated for each target palette when
            -- they are converted by value anyway.
            local j = 0
            while j < lenPals do j = j + 1
                AseUtilities.setPalette(
                    hexesSrgb, candidate, j)
            end
        end

        local k = 0
        while k < candLenExact do k = k + 1
            local candidate = candidatesExact[k]
            -- print(string.format("exact: %s", candidate.filename))

            local lenPals = #candidate.palettes
            local j = 0
            while j < lenPals do j = j + 1
                AseUtilities.setPalette(
                    hexesProfile, candidate, j)
            end
        end

        app.refresh()

        if errorFlag then
            app.alert {
                title = "Warning",
                text = rejected
            }
        else
            app.alert {
                title = "Success",
                text = "Palette shared."
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