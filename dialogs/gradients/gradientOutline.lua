dofile("../../support/gradientutilities.lua")

-- local places = { "INSIDE", "OUTSIDE" }
local matrices = { "DIAMOND", "SQUARE", "HORIZONTAL", "VERTICAL" }
local tileModes = { "BOTH", "NONE", "X", "Y" }

local defaults = {
    iterations = 16,
    alphaFade = false,
    place = "OUTSIDE",
    matrix = "DIAMOND",
    tileMode = "NONE",
    useRed = true,
    useGreen = true,
    useBlue = true,
    useAlpha = true,
    useGray = false,
    useIdx = false,
    pullFocus = true
}

local dlg = Dialog { title = "Outline Gradient" }

GradientUtilities.dialogWidgets(dlg)

dlg:color {
    id = "bkgColor",
    label = "Background:",
    color = Color(0, 0, 0, 0)
}

dlg:newrow { always = false }

dlg:slider {
    id = "iterations",
    label = "Repeat:",
    min = 1,
    max = 64,
    value = defaults.iterations
}

-- dlg:newrow { always = false }

-- dlg:combobox {
--     id = "place",
--     label = "Place:",
--     option = defaults.place,
--     options = places
-- }

dlg:newrow { always = false }

dlg:check {
    id = "alphaFade",
    label = "Alpha:",
    text = "Auto Fade",
    selected = defaults.alphaFade
}

dlg:newrow { always = false }

dlg:combobox {
    id = "matrix",
    label = "Matrix:",
    option = defaults.matrix,
    options = matrices
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tileMode",
    label = "Tile:",
    option = defaults.tileMode,
    options = tileModes
}

dlg:newrow { always = false }

dlg:check {
    id = "useRed",
    label = "Channels:",
    text = "R",
    selected = defaults.useRed
}

dlg:check {
    id = "useGreen",
    text = "G",
    selected = defaults.useGreen
}

dlg:check {
    id = "useBlue",
    text = "B",
    selected = defaults.useBlue
}

dlg:check {
    id = "useAlpha",
    text = "A",
    selected = defaults.useAlpha
}

dlg:check {
    id = "useGray",
    text = "V",
    selected = defaults.useGray
}

dlg:check {
    id = "useIdx",
    text = "I",
    selected = defaults.useIdx
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported." }
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local alphaFade = args.alphaFade
        local clrSpacePreset = args.clrSpacePreset
        local aseColors = args.shades
        local levels = args.quantize
        local aseBkgColor = args.bkgColor
        local iterations = args.iterations or defaults.iterations
        local place = args.place or defaults.place
        local matrix = args.matrix or defaults.matrix
        local tileMode = args.tileMode or defaults.tileMode

        -- Composite color channels.
        local channels = 0x0
        if args.useRed then channels = channels | FilterChannels.RED end
        if args.useGreen then channels = channels | FilterChannels.GREEN end
        if args.useBlue then channels = channels | FilterChannels.BLUE end
        if args.useAlpha then channels = channels | FilterChannels.ALPHA end
        if args.useGray then channels = channels | FilterChannels.GRAY end
        if args.useIndex then channels = channels | FilterChannels.INDEX end

        -- Convert string enumeration constants.
        -- "DIAMOND" is a more accurate label than "CIRCLE"
        -- for the matrix's result.
        if matrix == "DIAMOND" then matrix = "CIRCLE" end
        matrix = string.lower(matrix)
        tileMode = string.lower(tileMode)
        place = string.lower(place)

        -- Cache methods.
        local quantize = Utilities.quantizeUnsigned
        local cgeval = ClrGradient.eval
        local toAse = AseUtilities.clrToAseColor
        local blend = Clr.blend
        local clrNew = Clr.new

        -- For auto alpha fade.
        -- The clr needs to be blended with the background.
        local alphaStart = 1.0
        local alphaEnd = 1.0 / iterations
        local bkgClr = AseUtilities.aseColorToClr(aseBkgColor)

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        local toFac = 1.0 / (iterations - 1.0)
        app.transaction(function()
            local i = 0
            while i < iterations do
                local fac = i * toFac
                fac = facAdjust(fac)
                fac = quantize(fac, levels)
                i = i + 1
                local clr = cgeval(gradient, fac, mixFunc)

                if alphaFade then
                    local a = (1.0 - fac) * alphaStart
                        + fac * alphaEnd
                    clr = clrNew(clr.r, clr.g, clr.b, a)
                    clr = blend(bkgClr, clr)
                end

                local aseColor = toAse(clr)
                app.command.Outline {
                    ui = false,
                    channels = channels,
                    place = place,
                    matrix = matrix,
                    tiledMode = tileMode,
                    color = aseColor,
                    bgColor = aseBkgColor }
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

dlg:show { wait = false }