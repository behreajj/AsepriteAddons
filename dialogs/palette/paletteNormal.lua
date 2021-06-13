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
    value = 4
}

dlg:newrow { always = false }

dlg:slider {
    id = "azimuths",
    label = "Longitudes:",
    min = 1,
    max = 32,
    value = 12
}

dlg:newrow { always = false }

dlg:check {
    id = "prependMask",
    label = "Prepend Mask:",
    selected = true,
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = false,
    onclick = function()
        local args = dlg.data
        if args.ok then
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
                -- TODO: Refactor to use one for loop?

                local phi = math.pi - i * toPhi
                local cosPhi = cos(phi)
                local sinPhi = sin(phi)

                for j = 0, azimuths - 1, 1 do

                    local theta = j * toTheta - math.pi
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

            sprite:setPalette(palette)

            if oldMode == ColorMode.INDEXED then
                app.command.ChangePixelFormat { format = "indexed" }
            elseif oldMode == ColorMode.GRAY then
                app.command.ChangePixelFormat { format = "gray" }
            end

            app.refresh()
        else
            app.alert("Dialog arguments are invalid.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }