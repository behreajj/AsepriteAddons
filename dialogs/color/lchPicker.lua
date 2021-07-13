dofile("../../support/clr.lua")
dofile("../../support/aseutilities.lua")

-- TODO: Make Get, set FG, BG buttons alt-hotkey friendly.

local harmonies = {
    "ANALOGOUS",
    "COMPLEMENT",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local defaults = {
    shade = Color(254, 2, 0, 255),
    hexCode = "#FE0200",
    lightness = 53,
    chroma = 104,
    hue = 40,
    alpha = 100,
    showHarmonies = false,
    harmonyType = "TRIADIC"
}

local dlg = Dialog {
    title = "CIE LCh Color Picker"
}

local function updateHarmonies(l, c, h, a)
    local oneThird = 1.0 / 3.0
    local oneTwelve = 1.0 / 12.0
    local splHue0 = 0.4166666666666667
    local splHue1 = 0.5833333333333334

    local ana0 = Clr.lchToRgba(l, c, h - oneTwelve, a)
    local ana1 = Clr.lchToRgba(l, c, h + oneTwelve, a)

    local tri0 = Clr.lchToRgba(l, c, h - oneThird, a)
    local tri1 = Clr.lchToRgba(l, c, h + oneThird, a)

    local split0 = Clr.lchToRgba(l, c, h + splHue0, a)
    local split1 = Clr.lchToRgba(l, c, h + splHue1, a)

    local square0 = Clr.lchToRgba(l, c, h + 0.25, a)
    local square1 = Clr.lchToRgba(l, c, h + 0.5, a)
    local square2 = Clr.lchToRgba(l, c, h + 0.75, a)

    local tris = {
        AseUtilities.clrToAseColor(Clr.clamp01(tri0)),
        AseUtilities.clrToAseColor(Clr.clamp01(tri1))
    }

    local analogues = {
        AseUtilities.clrToAseColor(Clr.clamp01(ana0)),
        AseUtilities.clrToAseColor(Clr.clamp01(ana1))
    }

    local splits = {
        AseUtilities.clrToAseColor(Clr.clamp01(split0)),
        AseUtilities.clrToAseColor(Clr.clamp01(split1))
    }

    local squares = {
        AseUtilities.clrToAseColor(Clr.clamp01(square0)),
        AseUtilities.clrToAseColor(Clr.clamp01(square1)),
        AseUtilities.clrToAseColor(Clr.clamp01(square2))
    }

    dlg:modify {
        id = "COMPLEMENT",
        colors = { squares[2] }
    }

    dlg:modify {
        id = "triadic",
        colors = tris
    }

    dlg:modify {
        id = "analogous",
        colors = analogues
    }

    dlg:modify {
        id = "split",
        colors = splits
    }

    dlg:modify {
        id = "square",
        colors = squares
    }
end


local function updateWarning(clr)
    if Clr.rgbIsInGamut(clr, 0.025) then
        dlg:modify {
            id = "warning0",
            visible = false
        }
        dlg:modify {
            id = "warning1",
            visible = false
        }
        dlg:modify {
            id = "warning2",
            visible = false
        }
    else
        dlg:modify {
            id = "warning0",
            visible = true
        }
        dlg:modify {
            id = "warning1",
            visible = true
        }
        dlg:modify {
            id = "warning2",
            visible = true
        }
    end
end

local function setFromAse(aseClr)
    local clr = AseUtilities.aseColorToClr(aseClr)
    updateWarning(clr)
    local lch = Clr.rgbaToLch(clr)
    local trunc = math.tointeger

    dlg:modify {
        id = "lightness",
        value = trunc(0.5 + lch.l)
    }

    dlg:modify {
        id = "chroma",
        value = trunc(0.5 + lch.c)
    }

    dlg:modify {
        id = "hue",
        value = trunc(0.5 + lch.h * 360.0)
        -- Familiar hue:
        -- value = (trunc(0.5 + lch.h * 360.0) - 40) % 360
    }

    dlg:modify {
        id = "alpha",
        value = trunc(0.5 + lch.a * 100.0)
    }

    dlg:modify {
        id = "clr",
        colors = { aseClr }
    }

    dlg:modify {
        id = "hexCode",
        text = Clr.toHexWeb(clr)
    }

    updateHarmonies(lch.l, lch.c, lch.h, lch.a)
end

local function updateClrs(data)
    local l = data.lightness
    local c = data.chroma
    local h = data.hue / 360.0
    -- Familiar hue:
    -- local h = ((data.hue + 40) % 360) / 360.0
    local a = data.alpha * 0.01

    local clr = Clr.lchToRgba(l, c, h, a)
    updateWarning(clr)

    -- See
    -- https://github.com/LeaVerou/css.land/issues/10
    clr = Clr.clamp01(clr)

    dlg:modify {
        id = "clr",
        colors = { AseUtilities.clrToAseColor(clr) }
    }

    dlg:modify {
        id = "hexCode",
        text = Clr.toHexWeb(clr)
    }

    updateHarmonies(l, c, h, a)
end

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "FG",
    focus = false,
    onclick = function()
       setFromAse(app.fgColor)
    end
}

dlg:button {
    id = "bgGet",
    text = "BG",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(app.fgColor)
       app.command.SwitchColors()
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "clr",
    label = "Preview:",
    mode = "sort",
    colors = { defaults.shade }
}

dlg:newrow { always = false }

-- TODO: Make this a text or number input field?
dlg:label {
    id = "hexCode",
    label = "Hex:",
    text = defaults.hexCode
}

dlg:newrow { always = false }

dlg:slider {
    id = "lightness",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.lightness,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider {
    id = "chroma",
    label = "Chroma:",
    min = 0,
    max = 132,
    value = defaults.chroma,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider {
    id = "hue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hue,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider {
    id = "alpha",
    label = "Alpha:",
    min = 0,
    max = 100,
    value = defaults.alpha,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "warning0",
    label = "Warning:",
    text = "Clipped to sRGB.",
    visible = false
}

dlg:newrow { always = false }

dlg:label {
    id = "warning1",
    text = "Hue may shift.",
    visible = false
}

dlg:newrow { always = false }

dlg:label {
    id = "warning2",
    text = "Reduce chroma.",
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "fgSet",
    label = "Set:",
    text = "FG",
    focus = false,
    onclick = function()
        app.fgColor = dlg.data.clr[1]
    end
}

dlg:button {
    id = "bgSet",
    text = "BG",
    focus = false,
    onclick = function()
        -- Bug where assigning to app.bgColor
        -- leads to unlocked palette colors
        -- being assigned instead.
        app.command.SwitchColors()
        app.fgColor = dlg.data.clr[1]
        app.command.SwitchColors()
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showHarmonies",
    label = "Harmonies:",
    selected = defaults.showHarmonies,
    onclick = function()
        local show = dlg.data.showHarmonies
        dlg:modify {
            id = "harmonyType",
            visible = show
        }

        local md = dlg.data.harmonyType
        dlg:modify {
            id = "COMPLEMENT",
            visible = show and md == "COMPLEMENT"
        }

        dlg:modify {
            id = "triadic",
            visible = show and md == "TRIADIC"
        }

        dlg:modify {
            id = "analogous",
            visible = show and md == "ANALOGOUS"
        }

        dlg:modify {
            id = "split",
            visible = show and md == "SPLIT"
        }

        dlg:modify {
            id = "square",
            visible = show and md == "SQUARE"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonies,
    visible = defaults.showHarmonies,
    onchange = function()
        local md = dlg.data.harmonyType
        dlg:modify {
            id = "COMPLEMENT",
            visible = md == "COMPLEMENT"
        }

        dlg:modify {
            id = "triadic",
            visible = md == "TRIADIC"
        }

        dlg:modify {
            id = "analogous",
            visible = md == "ANALOGOUS"
        }

        dlg:modify {
            id = "split",
            visible = md == "SPLIT"
        }

        dlg:modify {
            id = "square",
            visible = md == "SQUARE"
        }
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "COMPLEMENT",
    label = "Complement:",
    mode = "pick",
    colors = { Color(0xffffa100) },
    visible = defaults.showHarmonies
        and defaults.harmonyType == "COMPLEMENT",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(ev.color)
        elseif ev.button == MouseButton.RIGHT then
            app.fgColor = ev.color
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "triadic",
    label = "Triadic:",
    mode = "pick",
    colors = { Color(0xffff8200), Color(0xff3b9d00) },
    visible = defaults.showHarmonies
        and defaults.harmonyType == "TRIADIC",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(ev.color)
        elseif ev.button == MouseButton.RIGHT then
            app.fgColor = ev.color
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "analogous",
    label = "Analogous:",
    mode = "pick",
    colors = {
        Color(0xff6600ff),
        Color(0xff0062ca) },
    visible = defaults.showHarmonies
        and defaults.harmonyType == "ANALOGOUS",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(ev.color)
        elseif ev.button == MouseButton.RIGHT then
            app.fgColor = ev.color
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "split",
    label = "Split:",
    mode = "pick",
    colors = {
        Color(0xff9ca100),
        Color(0xffff9a00) },
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SPLIT",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(ev.color)
        elseif ev.button == MouseButton.RIGHT then
            app.fgColor = ev.color
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "square",
    label = "Square:",
    mode = "pick",
    colors = {
        Color(0xff009600),
        Color(0xffffa100),
        Color(0xffff519d) },
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SQUARE",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            setFromAse(ev.color)
        elseif ev.button == MouseButton.RIGHT then
            app.fgColor = ev.color
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
