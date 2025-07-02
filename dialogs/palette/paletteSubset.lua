dofile("../../support/aseutilities.lua")

local targets <const> = { "MANUAL", "RANGE" }

local defaults <const> = {
    target = "RANGE",
    rangeStr = "",
    strExample = "4,6:9,13",
    uniquesOnly = false,
    prependMask = true,
}

local dlg <const> = Dialog { title = "Palette Subset" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    focus = false,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local isManual <const> = target == "MANUAL"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Indices:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.target == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "uniquesOnly",
    label = "Filter:",
    text = "Uniques",
    selected = defaults.uniquesOnly,
    hexpand = false,
    focus = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Mask:",
    text = "Prepend",
    selected = defaults.prependMask,
    hexpand = false,
    focus = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeFrame <const> = site.frame
        if not activeFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
            }
            return
        end

        local spec <const> = activeSprite.spec
        local colorMode <const> = spec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local prependMask <const> = args.prependMask --[[@as boolean]]
        local uniquesOnly <const> = args.uniquesOnly --[[@as boolean]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]

        local palettes <const> = activeSprite.palettes
        local palette <const> = AseUtilities.getPalette(activeFrame, palettes)
        local lenPalette <const> = #palette

        ---@type integer[]
        local chosenIdcs = {}

        if target == "RANGE" then
            local range <const> = app.range
            if range.sprite == activeSprite then
                local rangeColors <const> = range.colors
                local lenRangeColors <const> = #rangeColors
                local h = 0
                while h < lenRangeColors do
                    h = h + 1
                    chosenIdcs[h] = rangeColors[h]
                end
            else
                app.alert {
                    title = "Error",
                    text = "Range sprite doesn't match active sprite."
                }
                return
            end
        else
            chosenIdcs = Utilities.parseRangeStringUnique(
                rangeStr, lenPalette - 1, 0)
        end

        local lenChosenIdcs <const> = #chosenIdcs
        if lenChosenIdcs <= 0 then
            app.alert {
                title = "Error",
                text = "No swatches were chosen."
            }
            return
        end

        if lenPalette <= 1 then
            app.alert {
                title = "Error",
                text = "Palette has only one color."
            }
            return
        end

        AseUtilities.preserveForeBack()

        ---@type integer[]
        local abgr32s = {}
        local i = 0
        while i < lenChosenIdcs do
            i = i + 1
            local idx <const> = chosenIdcs[i]
            local aseColor <const> = palette:getColor(idx)
            abgr32s[i] = AseUtilities.aseColorToHex(aseColor, ColorMode.RGB)
        end

        if uniquesOnly then
            local abgr32sUnique <const>,
            _ <const> = Utilities.uniqueColors(abgr32s, true)
            abgr32s = abgr32sUnique
        end

        if prependMask then
            Utilities.prependMask(abgr32s)
        end

        app.transaction("Palette Subset", function()
            local lenAbgr32s <const> = #abgr32s
            palette:resize(lenAbgr32s)
            local j = 0
            while j < lenAbgr32s do
                j = j + 1
                local aseColor <const> = AseUtilities.hexToAseColor(abgr32s[j])
                palette:setColor(j - 1, aseColor)
            end
        end)

        app.refresh()
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