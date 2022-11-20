dofile("../../support/aseutilities.lua")

local defaults = {
    x = 0.0,
    y = 0.0,
    z = 1.0,
    azimuth = 0,
    inclination = 90,
    hexCode = "8080FF",
    rgbLabel = "128, 128, 255",
}

local function colorToVec(clr)
    local r255 = 127.5
    local g255 = 127.5
    local b255 = 255.0

    if clr.alpha > 0 then
        r255 = clr.red
        g255 = clr.green
        b255 = clr.blue
    end

    local x = (r255 + r255 - 255) * 0.003921568627451
    local y = (g255 + g255 - 255) * 0.003921568627451
    local z = (b255 + b255 - 255) * 0.003921568627451

    -- The square magnitude for the color #808080
    -- is 0.000046 . Have to account for how 255
    -- is not divided cleanly by 2.
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.000047 then
        local magInv = 1.0 / math.sqrt(sqMag)
        return x * magInv,
            y * magInv,
            z * magInv
    else
        return 0.0, 0.0, 1.0
    end
end

local function vecToColor(x, y, z)
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.0 then
        local invMag = 127.5 / math.sqrt(sqMag)
        return Color {
            r = math.floor(x * invMag + 128.0),
            g = math.floor(y * invMag + 128.0),
            b = math.floor(z * invMag + 128.0)
        }
    else
        return Color { r = 128, g = 128, b = 255 }
    end
end

local function updateWidgetClr(dialog, clr)
    dialog:modify {
        id = "normalColor",
        colors = { clr }
    }

    dialog:modify {
        id = "hexCode",
        text = string.format(
            "%06X",
            (clr.red << 0x10 |
                clr.green << 0x08 |
                clr.blue))
    }

    dialog:modify {
        id = "rgbLabel",
        text = string.format(
            "%03d, %03d, %03d",
            clr.red,
            clr.green,
            clr.blue)
    }
end

local function updateWidgetCart(dialog)
    local args = dialog.data
    local x = args.x
    local y = args.y
    local z = args.z

    local sph = Vec3.toSpherical(Vec3.new(x, y, z))
    local a = sph.azimuth
    local i = sph.inclination
    a = Utilities.round(
        (a % 6.2831853071796) * 57.295779513082)
    i = Utilities.round(i * 57.295779513082)

    dialog:modify { id = "azimuth", value = a }
    dialog:modify { id = "inclination", value = i }

    local clr = vecToColor(x, y, z)
    updateWidgetClr(dialog, clr)
end

local function updateWidgetSphere(dialog)
    local args = dialog.data
    local az = args.azimuth
    local incl = args.inclination

    local v = Vec3.fromSpherical(
        az * 0.017453292519943,
        incl * 0.017453292519943,
        1.0)

    dialog:modify { id = "x", text = string.format("%.3f", v.x) }
    dialog:modify { id = "y", text = string.format("%.3f", v.y) }
    dialog:modify { id = "z", text = string.format("%.3f", v.z) }

    local clr = vecToColor(v.x, v.y, v.z)
    updateWidgetClr(dialog, clr)
end

local function updateFromColor(dialog, clr)
    local x, y, z = colorToVec(clr)
    if x ~= 0.0 or y ~= 0.0 or z ~= 0.0 then
        dialog:modify { id = "x", text = string.format("%.3f", x) }
        dialog:modify { id = "y", text = string.format("%.3f", y) }
        dialog:modify { id = "z", text = string.format("%.3f", z) }

        local sph = Vec3.toSpherical(Vec3.new(x, y, z))
        local a = sph.azimuth
        local i = sph.inclination
        a = Utilities.round(
            (a % 6.2831853071796) * 57.295779513082)
        i = Utilities.round(i * 57.295779513082)

        dialog:modify { id = "azimuth", value = a }
        dialog:modify { id = "inclination", value = i }

        local r = math.floor(x * 127.5 + 128.0)
        local g = math.floor(y * 127.5 + 128.0)
        local b = math.floor(z * 127.5 + 128.0)

        dialog:modify {
            id = "normalColor",
            colors = { Color { r = r, g = g, b = b } }
        }

        dialog:modify {
            id = "hexCode",
            text = string.format("%06X",
                (r << 0x10 | g << 0x08 | b))
        }

        dialog:modify {
            id = "rgbLabel",
            text = string.format("%03d, %03d, %03d",
                r, g, b)
        }
    end
end

local dlg = Dialog { title = "Normal Color Calc" }

dlg:button {
    id = "getColorFore",
    label = "Get:",
    text = "F&ORE",
    onclick = function()
        if app.activeSprite then
            updateFromColor(dlg, app.fgColor)
        end
    end
}

dlg:button {
    id = "getColorBack",
    text = "B&ACK",
    onclick = function()
        if app.activeSprite then
            -- Bug where assigning to app.bgColor leads
            -- to unlocked palette colors changing.
            app.command.SwitchColors()
            updateFromColor(dlg, app.fgColor)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "x",
    label = "Vector:",
    text = string.format("%.3f", defaults.x),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "y",
    text = string.format("%.3f", defaults.y),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "z",
    text = string.format("%.3f", defaults.z),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "azimuth",
    label = "Azimuth:",
    min = 0,
    max = 360,
    value = defaults.azimuth,
    onchange = function()
        updateWidgetSphere(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "inclination",
    label = "Inclination:",
    min = -90,
    max = 90,
    value = defaults.inclination,
    onchange = function()
        updateWidgetSphere(dlg)
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "hexCode",
    label = "Hex: #",
    text = defaults.hexCode
}

dlg:newrow { always = false }

dlg:label {
    id = "rgbLabel",
    label = "RGB:",
    text = defaults.rgbLabel
}

dlg:newrow { always = false }

dlg:shades {
    id = "normalColor",
    label = "Color:",
    mode = "sort",
    colors = { Color { r = 128, g = 128, b = 255 } }
}

dlg:newrow { always = false }

dlg:button {
    id = "setColorFore",
    label = "Set:",
    text = "&FORE",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if app.activeSprite and #normalColors > 0 then
            local n = normalColors[1]
            app.fgColor = Color {
                r = n.red,
                g = n.green,
                b = n.blue
            }
        end
    end
}

dlg:button {
    id = "setColorBack",
    text = "&BACK",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if app.activeSprite and #normalColors > 0 then
            local n = normalColors[1]
            app.command.SwitchColors()
            app.fgColor = Color {
                r = n.red,
                g = n.green,
                b = n.blue
            }
            app.command.SwitchColors()
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