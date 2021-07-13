dofile("../../support/utilities.lua")

-- https://blog.johnnovak.net/2016/09/21/what-every-coder-should-know-about-gamma/
-- http://www.ericbrasseur.org/gamma.html

local invPowPrev = {
    Color(0xff000000),
    Color(0xff626262),
    Color(0xff888888),
    Color(0xffa4a4a4),
    Color(0xffbbbbbb),
    Color(0xffcfcfcf),
    Color(0xffe0e0e0),
    Color(0xfff0f0f0),
    Color(0xffffffff)
}

local linearPrev = {
    Color(0xff000000),
    Color(0xff1f1f1f),
    Color(0xff3f3f3f),
    Color(0xff5f5f5f),
    Color(0xff7f7f7f),
    Color(0xff9f9f9f),
    Color(0xffbfbfbf),
    Color(0xffdfdfdf),
    Color(0xffffffff)
}

local powerPrev = {
    Color(0xff000000),
    Color(0xff030303),
    Color(0xff0d0d0d),
    Color(0xff1d1d1d),
    Color(0xff363636),
    Color(0xff585858),
    Color(0xff858585),
    Color(0xffbcbcbc),
    Color(0xffffffff)
}

local dlg = Dialog { title = "sRGB Conversion" }

dlg:shades {
    id = "invPowPrev",
    label = "1.0 / 2.4:",
    colors = invPowPrev,
    mode = "pick",
    onclick = function(ev0)
        if ev0.button == MouseButton.LEFT then
            app.fgColor = ev0.color
        elseif ev0.button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = ev0.color
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "linearPrev",
    label = "1.0:",
    colors = linearPrev,
    mode = "pick",
    onclick = function(ev1)
        if ev1.button == MouseButton.LEFT then
            app.fgColor = ev1.color
        elseif ev1.button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = ev1.color
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "powerPrev",
    label = "2.4:",
    colors = powerPrev,
    mode = "pick",
    onclick = function(ev2)
        if ev2.button == MouseButton.LEFT then
            app.fgColor = ev2.color
        elseif ev2.button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = ev2.color
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "direction",
    label = "Direction:",
    option = "STANDARD_TO_LINEAR",
    options = { "LINEAR_TO_STANDARD", "STANDARD_TO_LINEAR" }
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    onclick = function()
        local args = dlg.data
        local sprite = app.activeSprite
        if sprite then
            local layer = app.activeLayer
            if layer and not layer.isGroup then
                local cel = app.activeCel
                if cel then
                    local oldMode = sprite.colorMode
                    app.command.ChangePixelFormat { format = "rgb" }
                    local image = cel.image
                    local pxitr = image:pixels()

                    local dir = args.direction
                    local lut = {}
                    if dir == "LINEAR_TO_STANDARD" then
                        lut = Utilities.LTS_LUT
                    else
                        lut = Utilities.STL_LUT
                    end

                    for clr in pxitr do
                        local hex = clr()
                        local a = hex >> 0x18 & 0xff

                        local bOrigin = hex >> 0x10 & 0xff
                        local gOrigin = hex >> 0x08 & 0xff
                        local rOrigin = hex & 0xff

                        local bDest = lut[1 + bOrigin]
                        local gDest = lut[1 + gOrigin]
                        local rDest = lut[1 + rOrigin]

                        clr(a << 0x18
                            | bDest << 0x10
                            | gDest << 0x08
                            | rDest)
                    end

                    if oldMode == ColorMode.INDEXED then
                        app.command.ChangePixelFormat { format = "indexed" }
                    elseif oldMode == ColorMode.GRAY then
                        app.command.ChangePixelFormat { format = "gray" }
                    end

                    app.refresh()
                else
                    app.alert("There is no active cel.")
                end
            else
                app.alert("There is no active layer.")
            end
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