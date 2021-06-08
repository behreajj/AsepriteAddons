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
    clr = Clr.clamp01(clr)

    dlg:modify{
        id = "clr",
        colors = {AseUtilities.clrToAseColor(clr)}
    }
end

dlg:shades{
    id = "clr",
    label = "Color:",
    mode = "pick",
    colors = {Color(255, 0, 125, 255)},
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            app.fgColor = ev.color
        elseif ev.button == MouseButton.RIGHT then
            app.bgColor = ev.color
        end
    end
}

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
    value = 132,
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

dlg:button{
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show{
    wait = false
}
