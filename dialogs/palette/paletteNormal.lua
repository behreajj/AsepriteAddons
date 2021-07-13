local preview = {
    Color(255, 128, 128),
    Color(218, 218, 128),
    Color(127, 255, 128),
    Color( 37, 218, 128),
    Color(  0, 128, 128),
    Color( 37,  37, 128),
    Color(127,   0, 128),
    Color(218,  37, 128)
}

local defaults = {
    inclinations = 4,
    azimuths = 12,
    prependMask = true,
    target = "ACTIVE",
    pullFocus = false
}

local dlg = Dialog { title = "Normal Palette" }

dlg:shades {
    id = "preview",
    label = "Preview:",
    colors = preview,
    mode = "pick",
    onclick = function(ev)
        if ev.button == MouseButton.LEFT then
            app.fgColor = ev.color
        elseif ev.button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = ev.color
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "inclinations",
    label = "Latitudes:",
    min = 1,
    max = 32,
    value = defaults.inclinations
}

dlg:newrow { always = false }

dlg:slider {
    id = "azimuths",
    label = "Longitudes:",
    min = 1,
    max = 32,
    value = defaults.azimuths
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = defaults.prependMask,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = { "ACTIVE", "SAVE" },
    onchange = function()
        local md = dlg.data.target
        dlg:modify {
            id = "filepath",
            visible = md == "SAVE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "filepath",
    filetypes = { "gpl", "pal" },
    save = true,
    visible = defaults.target == "SAVE"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        local inclinations = args.inclinations
        local azimuths = args.azimuths
        local prependMask = args.prependMask
        local len = inclinations * azimuths
        local k = 0

        if prependMask then
            len = len + 1
            k = 1
        end

        local palette = Palette(len)

        local tau = math.pi * 2.0
        local halfPi = math.pi * 0.5
        local toPhi = halfPi / inclinations
        local toTheta = tau / azimuths

        local cos = math.cos
        local sin = math.sin
        local trunc = math.tointeger

        for i = 0, inclinations - 1, 1 do

            local phi = 3.141592653589793 - i * toPhi
            local cosPhi = cos(phi)
            local sinPhi = sin(phi)

            for j = 0, azimuths - 1, 1 do

                local theta = j * toTheta - 3.141592653589793
                local cosTheta = cos(theta)
                local sinTheta = sin(theta)

                local x = cosPhi * cosTheta
                local y = cosPhi * sinTheta
                local z = sinPhi

                local r01 = 0.5 + x * 0.5
                local g01 = 0.5 + y * 0.5
                local b01 = 0.5 + z * 0.5

                local r = trunc(r01 * 255.0 + 0.5)
                local g = trunc(g01 * 255.0 + 0.5)
                local b = trunc(b01 * 255.0 + 0.5)

                local clr = Color(r, g, b, 255)
                palette:setColor(k, clr)
                k = k + 1
            end
        end

        if prependMask then
            palette:setColor(0, 0x00000000)
        end

        local sprite = app.activeSprite
        if sprite == nil then
            sprite = Sprite(64, 64)
        end

        local oldMode = sprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local target = args.target
        if target == "SAVE" then
            local filepath = args.filepath
            palette:saveAs(filepath)
        else
            sprite:setPalette(palette)
        end

        if oldMode == ColorMode.INDEXED then
            app.command.ChangePixelFormat { format = "indexed" }
        elseif oldMode == ColorMode.GRAY then
            app.command.ChangePixelFormat { format = "gray" }
        end

        app.refresh()
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