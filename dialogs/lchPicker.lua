dofile("../support/clr.lua")
dofile("../support/aseutilities.lua")

local dlg = Dialog {
    title = "CIE LCh Color Picker"
}

local function updateClrs(data)
    local l = data.lightness
    local c = data.chroma
    local h = data.hue / 360.0
    local a = data.alpha * 0.01
    local clr = Clr.lchToRgba(l, c, h, a)

    if Clr.rgbaIsInGamut(clr) then
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
    label = "Color:",
    -- mode = "pick",
    mode = "sort",
    colors = {Color(230, 9, 122, 255)},
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
    text = "#E6097A"
}

-- dlg:button{
--     id = "swapClr",
--     label = "Fore-Back:",
--     text = "SWAP",
--     onclick = function()
--        app.command.SwitchColors()
--     end
-- }

dlg:slider{
    id = "lightness",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = 50,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider{
    id = "chroma",
    label = "Chroma:",
    min = 0,
    max = 132,
    value = 78,
    onchange = function()
        updateClrs(dlg.data)
    end
}

dlg:slider{
    id = "hue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = 0,
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
    id = "fg",
    text = "FG",
    focus = false,
    onclick = function()
        app.fgColor = dlg.data.clr[1]
    end
}

dlg:button{
    id = "bg",
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
