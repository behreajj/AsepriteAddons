local defaults = {
    sectors = 0,
    rings = 0,
    size = 512,
    showWheelSettings = false
}

local function fromSpherical(az, incl)
    local a = az * math.pi / 180.0
    local i = incl * math.pi / 180.0
    local cosIncl = math.cos(i)
    return cosIncl * math.cos(a),
        cosIncl * math.sin(a),
        math.sin(i)
end

local function toSpherical(x, y, z)
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.0 then
        local azRad = math.atan(y, x)
        local azDeg = azRad * 180.0 / math.pi

        local inclRad = math.acos(z / math.sqrt(sqMag))
        local inclDeg = inclRad * 180.0 / math.pi
        inclDeg = 90.0 - inclDeg

        return azDeg, inclDeg
    else
        return 0.0, 90.0
    end
end

local function vecToColor(x, y, z)
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.0 then
        local mag = math.sqrt(sqMag)

        local xn = x / mag
        local yn = y / mag
        local zn = z / mag

        local r01 = xn * 0.5 + 0.5
        local g01 = yn * 0.5 + 0.5
        local b01 = zn * 0.5 + 0.5

        local r255 = math.tointeger(0.5 + 255.0 * r01)
        local g255 = math.tointeger(0.5 + 255.0 * g01)
        local b255 = math.tointeger(0.5 + 255.0 * b01)

        return Color(r255, g255, b255, 255)
    else
        return Color(128, 128, 255, 255)
    end
end

local function updateWidgetClr(dialog, clr)
    dialog:modify {
        id = "normalColor",
        colors = { clr } }

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
            "%d, %d, %d",
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

    local a, i = toSpherical(x, y, z)
    if a < -0.0 then a = a - 0.5 end
    if a > 0.0 then a = a + 0.5 end
    if i < -0.0 then i = i - 0.5 end
    if i > 0.0 then i = i + 0.5 end

    dialog:modify {
        id = "azimuth",
        value = math.tointeger(a)
    }

    dialog:modify {
        id = "inclination",
        value = math.tointeger(i)
    }

    local clr = vecToColor(x, y, z)
    updateWidgetClr(dialog, clr)
end

local function updateWidgetSphere(dialog)
    local args = dialog.data
    local az = args.azimuth
    local incl = args.inclination
    local x, y, z = fromSpherical(az, incl)

    dialog:modify { id = "x", text = string.format("%.5f", x) }
    dialog:modify { id = "y", text = string.format("%.5f", y) }
    dialog:modify { id = "z", text = string.format("%.5f", z) }

    local clr = vecToColor(x, y, z)
    updateWidgetClr(dialog, clr)
end

local dlg = Dialog { title = "Normal Color Calc" }

dlg:newrow { always = false }

dlg:number {
    id = "x",
    label = "Vector:",
    text = string.format("%.5f", 0.0),
    decimals = 5,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "y",
    text = string.format("%.5f", 0.0),
    decimals = 5,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "z",
    text = string.format("%.5f", 1.0),
    decimals = 5,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "azimuth",
    label = "Azimuth:",
    min = -180,
    max = 180,
    value = 0,
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
    value = 90,
    onchange = function()
        updateWidgetSphere(dlg)
    end
}

dlg:newrow { always = false }

dlg: label {
    id = "hexCode",
    label = "Hex: #",
    text = "8080FF"
}

dlg:newrow { always = false }

dlg: label {
    id = "rgbLabel",
    label = "RGB:",
    text = "128, 128, 255"
}

dlg:newrow { always = false }

dlg:shades {
    id = "normalColor",
    label = "Color:",
    mode = "sort",
    colors = { Color(128, 128, 255, 255) }
}

dlg:newrow { always = false }

dlg:button {
    id = "getColor",
    text = "&GET",
    onclick = function()
        local clr = app.fgColor

        local r255 = clr.red
        local g255 = clr.green
        local b255 = clr.blue

        if clr.alpha < 1 then
            r255 = 128
            g255 = 128
            b255 = 255
        end

        local r01 = r255 / 255.0
        local g01 = g255 / 255.0
        local b01 = b255 / 255.0

        local x = r01 + r01 - 1.0
        local y = g01 + g01 - 1.0
        local z = b01 + b01 - 1.0

        local sqmag = x * x + y * y + z * z
        if sqmag > 0.0 then
            local xn = x
            local yn = y
            local zn = z

            local mag = math.sqrt(sqmag)
            xn = x / mag
            yn = y / mag
            zn = z / mag

            dlg:modify { id = "x", text = string.format("%.5f", xn) }
            dlg:modify { id = "y", text = string.format("%.5f", yn) }
            dlg:modify { id = "z", text = string.format("%.5f", zn) }

            local a, i = toSpherical(xn, yn, zn)
            if a < -0.0 then a = a - 0.5 end
            if a > 0.0 then a = a + 0.5 end
            if i < -0.0 then i = i - 0.5 end
            if i > 0.0 then i = i + 0.5 end

            dlg:modify {
                id = "azimuth",
                value = math.tointeger(a)
            }

            dlg:modify {
                id = "inclination",
                value = math.tointeger(i)
            }

            local nr01 = xn * 0.5 + 0.5
            local ng01 = yn * 0.5 + 0.5
            local nb01 = zn * 0.5 + 0.5

            local nr255 = math.tointeger(0.5 + 255.0 * nr01)
            local ng255 = math.tointeger(0.5 + 255.0 * ng01)
            local nb255 = math.tointeger(0.5 + 255.0 * nb01)

            dlg:modify {
                id = "normalColor",
                colors = { Color(nr255, ng255, nb255, 255) }
            }

            dlg:modify {
                id = "hexCode",
                text = string.format("%06X",
                    (nr255 << 0x10 |
                    ng255 << 0x08 |
                    nb255))
            }

            dlg:modify {
                id = "rgbLabel",
                text = string.format("%d, %d, %d",
                    nr255, ng255, nb255)
            }
        end
    end
}

dlg:button {
    id = "setColor",
    text = "&SET",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if #normalColors > 0 then
            local normalColor = normalColors[1]
            app.fgColor = Color(
                normalColor.red,
                normalColor.green,
                normalColor.blue,
                255)
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showWheelSettings",
    label = "Show:",
    text = "Wheel Settings",
    selected = defaults.showWheelSettings,
    onclick = function()
        local args = dlg.data
        local state = args.showWheelSettings
        dlg:modify { id = "sectors", visible = state }
        dlg:modify { id = "rings", visible = state }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 0,
    max = 32,
    value = defaults.sectors,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 0,
    max = 16,
    value = defaults.rings,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:button {
    id = "wheel",
    text = "&WHEEL",
    focus = false,
    onclick = function()

        -- Cache methods.
        local cos = math.cos
        local sin = math.sin
        local sqrt = math.sqrt
        local atan2 = math.atan
        local acos = math.acos
        local floor = math.floor
        local trunc = math.tointeger
        local max = math.max
        local min = math.min
        local pi = math.pi
        local tau = pi + pi
        local half_pi = pi / 2.0

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size
        local sectors = args.sectors or defaults.sectors
        local rings = args.rings or defaults.rings
        local szInv = 1.0 / (size - 1.0)

        local sprite = Sprite(size, size)
        sprite.filename = "Normal Map Color Wheel"
        sprite:assignColorSpace(ColorSpace())
        local cel = sprite.cels[1]

        local quantAzims = sectors > 0
        local quantIncls = rings > 0
        local quantUse = quantAzims or quantIncls

        local azimAlpha = 0.0
        local azimBeta = 0.0
        if quantAzims then
            azimAlpha = sectors / tau
            azimBeta = tau / sectors
        end

        local inclAlpha = 0.0
        local inclBeta = 0.0
        if quantIncls then
            inclAlpha = rings / half_pi
            inclBeta = half_pi / rings
        end

        local img = Image(size, size)
        local pxitr = img:pixels()
        for elm in pxitr do

            -- Find rise.
            local y = elm.y
            local yNrm = y * szInv
            local ySgn = 1.0 - (yNrm + yNrm)

            -- Find run.
            local x = elm.x
            local xNrm = x * szInv
            local xSgn = xNrm + xNrm - 1.0

            -- Find square magnitude.
            -- Magnitude correlates with saturation.
            local magSq = xSgn * xSgn + ySgn * ySgn
            if magSq > 0.0 and magSq <= 1.0 then
                local zSgn = sqrt(1.0 - magSq)

                local xn = xSgn
                local yn = ySgn
                local zn = zSgn

                if quantUse then
                    local azim = atan2(ySgn, xSgn)
                    local incl = half_pi - acos(max(-1.0, min(1.0, zSgn)))

                    if quantAzims then
                        azim = floor(0.5 + azim * azimAlpha) * azimBeta
                    end

                    if quantIncls then
                        incl = floor(0.5 + incl * inclAlpha) * inclBeta
                    end

                    local cosIncl = cos(incl)
                    xn = cosIncl * cos(azim)
                    yn = cosIncl * sin(azim)
                    zn = sin(incl)
                end

                local r01 = xn * 0.5 + 0.5
                local g01 = yn * 0.5 + 0.5
                local b01 = zn * 0.5 + 0.5

                local r255 = trunc(r01 * 255.0 + 0.5)
                local g255 = trunc(g01 * 255.0 + 0.5)
                local b255 = trunc(b01 * 255.0 + 0.5)

                local hex = 0xff000000
                    | (b255 << 0x10)
                    | (g255 << 0x08)
                    | r255
                elm(hex)
            else
                elm(0xffff8080)
            end
        end

        cel.image = img

        local pal = Palette(34)
        pal:setColor(0, Color(  0,  0,  0,    0))
        pal:setColor(1, Color(128, 128, 255, 255))
        pal:setColor(2, Color(255, 128, 128, 255))
        pal:setColor(3, Color(218, 218, 128, 255))
        pal:setColor(4, Color(128, 255, 128, 255))
        pal:setColor(5, Color( 37, 218, 128, 255))
        pal:setColor(6, Color(  0, 128, 128, 255))
        pal:setColor(7, Color( 37,  37, 128, 255))
        pal:setColor(8, Color(128,   0, 128, 255))
        pal:setColor(9, Color(218,  37, 128, 255))
        pal:setColor(10, Color(245, 128, 176, 255))
        pal:setColor(11, Color(211, 211, 176, 255))
        pal:setColor(12, Color(128, 245, 176, 255))
        pal:setColor(13, Color( 44, 211, 176, 255))
        pal:setColor(14, Color( 10, 128, 176, 255))
        pal:setColor(15, Color( 44,  44, 176, 255))
        pal:setColor(16, Color(128,  10, 176, 255))
        pal:setColor(17, Color(211,  44, 176, 255))
        pal:setColor(18, Color(218, 128, 218, 255))
        pal:setColor(19, Color(191, 191, 218, 255))
        pal:setColor(20, Color(128, 218, 218, 255))
        pal:setColor(21, Color( 64, 191, 218, 255))
        pal:setColor(22, Color( 37, 128, 218, 255))
        pal:setColor(23, Color( 64,  64, 218, 255))
        pal:setColor(24, Color(128,  37, 218, 255))
        pal:setColor(25, Color(191,  64, 218, 255))
        pal:setColor(26, Color(176, 128, 245, 255))
        pal:setColor(27, Color(162, 162, 245, 255))
        pal:setColor(28, Color(128, 176, 245, 255))
        pal:setColor(29, Color( 93, 162, 245, 255))
        pal:setColor(30, Color( 79, 128, 245, 255))
        pal:setColor(31, Color( 93,  93, 245, 255))
        pal:setColor(32, Color(128,  79, 245, 255))
        pal:setColor(33, Color(162,  93, 245, 255))
        sprite:setPalette(pal)

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