dofile("../../support/aseutilities.lua")

-- https://blog.johnnovak.net/2016/09/21/what-every-coder-should-know-about-gamma/
-- http://www.ericbrasseur.org/gamma.html

local invPowPrev = {
    Color(  0,   0,   0, 255),
    Color( 98,  98,  98, 255),
    Color(136, 136, 136, 255),
    Color(164, 164, 164, 255),
    Color(187, 187, 187, 255),
    Color(207, 207, 207, 255),
    Color(224, 224, 224, 255),
    Color(240, 240, 240, 255),
    Color(255, 255, 255, 255)
}

local linearPrev = {
    Color(  0,   0,   0, 255),
    Color( 31,  31,  31, 255),
    Color( 63,  63,  63, 255),
    Color( 95,  95,  95, 255),
    Color(127, 127, 127, 255),
    Color(159, 159, 159, 255),
    Color(191, 191, 191, 255),
    Color(223, 223, 223, 255),
    Color(255, 255, 255, 255)
}

local powerPrev = {
    Color(  0,   0,   0, 255),
    Color(  3,   3,   3, 255),
    Color( 13,  13,  13, 255),
    Color( 29,  29,  29, 255),
    Color( 54,  54,  54, 255),
    Color( 88,  88,  88, 255),
    Color(133, 133, 133, 255),
    Color(188, 188, 188, 255),
    Color(255, 255, 255, 255)
}

local dlg = Dialog { title = "sRGB Conversion" }

dlg:shades {
    id = "invPowPrev",
    label = "1.0 / 2.4:",
    colors = invPowPrev,
    mode = "pick"
}

dlg:newrow { always = false }

dlg:shades {
    id = "linearPrev",
    label = "1.0:",
    colors = linearPrev,
    mode = "pick"
}

dlg:newrow { always = false }

dlg:shades {
    id = "powerPrev",
    label = "2.4:",
    colors = powerPrev,
    mode = "pick"
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

                    AseUtilities.changePixelFormat(oldMode)
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