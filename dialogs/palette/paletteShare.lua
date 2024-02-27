local palTypes <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    palType = "ACTIVE",
    uniquesOnly = false,
    prependMask = true,
    startIndex = 0,
    count = 256,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Share Palette" }

dlg:combobox {
    id = "palType",
    label = "Source:",
    option = "ACTIVE",
    options = palTypes,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.palType --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = state == "FILE"
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
    value = defaults.startIndex,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "count",
    label = "Count:",
    min = 1,
    max = 256,
    value = defaults.count,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local profileNone <const> = ColorSpace()
        local profileSrgb <const> = ColorSpace { sRGB = true }
        local profActive = profileSrgb
        local cmActive = ColorMode.RGB

        local activeSprite <const> = app.site.sprite
        if activeSprite then
            profActive = activeSprite.colorSpace
            -- TODO: Allow palettes to be shared between indexed cm sprites?
            if activeSprite.colorMode ~= ColorMode.INDEXED then
                cmActive = activeSprite.colorMode
            end
        else
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        AseUtilities.preserveForeBack()
        local openSprites <const> = app.sprites
        local openLen <const> = #openSprites

        local args <const> = dlg.data
        local palType <const> = args.palType
            or defaults.palType --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local prependMask <const> = args.prependMask --[[@as boolean]]
        local startIndex <const> = args.startIndex
            or defaults.startIndex --[[@as integer]]
        local count <const> = args.count
            or defaults.count --[[@as integer]]

        local hexesProfile = {}
        local hexesSrgb = {}
        hexesProfile, hexesSrgb = AseUtilities.asePaletteLoad(
            palType, palFile, startIndex, count, true)

        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        if uniquesOnly then
            local uniques <const>, _ <const> = Utilities.uniqueColors(
                hexesSrgb, true)
            hexesSrgb = uniques
        end

        if prependMask then
            Utilities.prependMask(hexesSrgb)
        end

        ---@type Sprite[]
        local candidatesApprox <const> = {}
        ---@type Sprite[]
        local candidatesExact <const> = {}
        local rejected <const> = {
            "Not all sprites were included. Check to see",
            "if the sprite has a matching color mode and",
            "color profile. Excluded sprites are:"
        }

        local candLenApprox = 0
        local candLenExact = 0
        local rejLen = #rejected

        local errorFlag = false
        local h = 0
        while h < openLen do
            h = h + 1
            local sprite <const> = openSprites[h]
            local colorMode <const> = sprite.colorMode
            local filename <const> = app.fs.fileTitle(sprite.filename)

            if colorMode == cmActive then
                local profile <const> = sprite.colorSpace
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
        while i < candLenApprox do
            i = i + 1
            local candidate <const> = candidatesApprox[i]
            local lenPals <const> = #candidate.palettes
            -- This isn't as efficient as it could be because the same
            -- Aseprite Colors are recreated for each target palette when they
            -- are converted by value anyway.
            local j = 0
            while j < lenPals do
                j = j + 1
                AseUtilities.setPalette(hexesSrgb, candidate, j)
            end
        end

        local k = 0
        while k < candLenExact do
            k = k + 1
            local candidate <const> = candidatesExact[k]
            local lenPals <const> = #candidate.palettes
            local j = 0
            while j < lenPals do
                j = j + 1
                AseUtilities.setPalette(hexesProfile, candidate, j)
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

dlg:show {
    autoscrollbars = true,
    wait = false
}