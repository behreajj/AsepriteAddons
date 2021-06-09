dofile("../support/clr.lua")
dofile("../support/aseutilities.lua")

local dlg = Dialog {
    title = "CIE LCh Color Picker"
}

local function setFromAse(aseClr)
    local clr = AseUtilities.aseColorToClr(aseClr)
    local lch = Clr.rgbaToLch(clr)
    local trunc = math.tointeger

    dlg:modify{
        id = "lightness",
        value = trunc(0.5 + lch.l)
    }

    dlg:modify{
        id = "chroma",
        value = trunc(0.5 + lch.c)
    }

    dlg:modify{
        id = "hue",
        value = trunc(0.5 + lch.h * 360.0)
    }

    dlg:modify{
        id = "alpha",
        value = trunc(0.5 + lch.a * 100.0)
    }

    dlg:modify{
        id = "clr",
        colors = {aseClr}
    }

    dlg:modify{
        id = "hexCode",
        text = Clr.toHexWeb(clr)
    }
end

local function updateClrs(data)
    local l = data.lightness
    local c = data.chroma
    local h = data.hue / 360.0
    local a = data.alpha * 0.01
    local clr = Clr.lchToRgba(l, c, h, a)
    if Clr.rgbIsInGamut(clr, 0.000001) then
        dlg:modify{
            id = "warning0",
            visible = false
        }
        dlg:modify{
            id = "warning1",
            visible = false
        }
        dlg:modify{
            id = "warning2",
            visible = false
        }
    else
        dlg:modify{
            id = "warning0",
            visible = true
        }
        dlg:modify{
            id = "warning1",
            visible = true
        }
        dlg:modify{
            id = "warning2",
            visible = true
        }
    end

    -- See
    -- https://github.com/LeaVerou/css.land/issues/10
    clr = Clr.clamp01(clr)

    dlg:modify{
        id = "clr",
        colors = {AseUtilities.clrToAseColor(clr)}
    }

    dlg:modify{
        id = "hexCode",
        text = Clr.toHexWeb(clr)
    }
end

dlg:shades{
    id = "clr",
    label = "Preview:",
    -- mode = "pick",
    mode = "sort",
    colors = {Color(253, 10, 2, 255)},
    -- onclick = function(ev)
    --     if ev.button == MouseButton.LEFT then
    --         app.fgColor = ev.color
    --     elseif ev.button == MouseButton.RIGHT then
    --         app.command.SwitchColors()
    --         app.fgColor = ev.color
    --         app.command.SwitchColors()
    --     end
    -- end
}

dlg:label{
    id = "hexCode",
    label = "Hex:",
    text = "#FD0A02"
}

dlg:newrow{
    always = false
}

dlg:button{
    id = "fgGet",
    label = "Get:",
    text = "FG",
    focus = false,
    onclick = function()
       setFromAse(app.fgColor)
    end
}

dlg:button{
    id = "bgGet",
    text = "BG",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(app.fgColor)
       app.command.SwitchColors()
    end
}

dlg:newrow{
    always = false
}

dlg:slider{
    id = "lightness",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = 53,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider{
    id = "chroma",
    label = "Chroma:",
    min = 0,
    max = 132,
    value = 103,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider{
    id = "hue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = 40,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider{
    id = "alpha",
    label = "Alpha:",
    min = 0,
    max = 100,
    value = 100,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:newrow{
    always = false
}

dlg:label{
    id = "warning0",
    label = "Warning:",
    text = "Clipped to sRGB.",
    visible = false
}

dlg:newrow{
    always = false
}

dlg:label{
    id = "warning1",
    text = "Hue may shift.",
    visible = false
}

dlg:newrow{
    always = false
}

dlg:label{
    id = "warning2",
    text = "Reduce chroma.",
    visible = false
}

dlg:newrow{
    always = false
}

dlg:button{
    id = "fgSet",
    label = "Set:",
    text = "FG",
    focus = false,
    onclick = function()
        app.fgColor = dlg.data.clr[1]
    end
}

dlg:button{
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

dlg:newrow{
    always = false
}

dlg:button{
    id = "cancel",
    text = "CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show{
    wait = false
}
