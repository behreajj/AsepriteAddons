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

local directions = { "LINEAR_TO_STANDARD", "STANDARD_TO_LINEAR" }
local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ALL",
    direction = "STANDARD_TO_LINEAR",
    pullFocus = false
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
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "direction",
    label = "Direction:",
    option = defaults.direction,
    options = directions
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert{
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        if activeSprite.colorMode ~= ColorMode.RGB then
            app.alert{
                title = "Error",
                text = "Only RGB color mode is supported." }
            return
        end

        local args = dlg.data
        local target = args.target or defaults.target
        local direction = args.direction or defaults.target

        local cels = {}
        if target == "ACTIVE" then
            local activeCel = app.activeCel
            if activeCel then
                cels[1] = activeCel
            end
        elseif target == "RANGE" then
            cels = app.range.cels
        else
            cels = activeSprite.cels
        end

        local lut = {}
        if direction == "LINEAR_TO_STANDARD" then
            lut = Utilities.LTS_LUT
        else
            lut = Utilities.STL_LUT
        end

        local celsLen = #cels
        app.transaction(function()
            for i = 1, celsLen, 1 do
                local cel = cels[i]
                if cel then
                    local srcImg = cel.image
                    local pxitr = srcImg:pixels()
                    for elm in pxitr do
                        local hex = elm()
                        local a = hex >> 0x18 & 0xff
                        if a > 0 then
                            local bOrigin = hex >> 0x10 & 0xff
                            local gOrigin = hex >> 0x08 & 0xff
                            local rOrigin = hex & 0xff

                            local bDest = lut[1 + bOrigin]
                            local gDest = lut[1 + gOrigin]
                            local rDest = lut[1 + rOrigin]

                            elm(a << 0x18
                                | bDest << 0x10
                                | gDest << 0x08
                                | rDest)
                        else
                            elm(0x0)
                        end
                    end
                end
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