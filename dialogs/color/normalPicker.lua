dofile("../../support/aseutilities.lua")

local defaults = {
    x = 0.0,
    y = 0.0,
    z = 1.0,
    azimuth = 0,
    inclination = 90,
    hexCode = "8080FF",
    rgbLabel = "128, 128, 255",

    showWheelSettings = false,
    size = 512,
    sectors = 0,
    rings = 0,
    xFlip = false,
    yFlip = false,
    zFlip = false,
    minSize = 64,
    maxSize = 2048,
    maxSectors = 32,
    maxRings = 16
}

local normalsPal = {
    0x00000000, 0xffff8080,
    0xff8080ff, 0xff80dada, 0xff80ff80, 0xff80da25,
    0xff808000, 0xff802525, 0xff800080, 0xff8025da,
    0xffb080f5, 0xffb0d3d3, 0xffb0f580, 0xffb0d32c,
    0xffb0800a, 0xffb02c2c, 0xffb00a80, 0xffb02cd3,
    0xffda80da, 0xffdabfbf, 0xffdada80, 0xffdabf40,
    0xffda8025, 0xffda4040, 0xffda2580, 0xffda40bf,
    0xfff580b0, 0xfff5a2a2, 0xfff5b080, 0xfff5a25d,
    0xfff5804f, 0xfff55d5d, 0xfff54f80, 0xfff55da2
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
        return Color(
            math.floor(x * invMag + 128.0),
            math.floor(y * invMag + 128.0),
            math.floor(z * invMag + 128.0),
            255)
    else
        return Color(128, 128, 255, 255)
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

        local r255 = math.floor(x * 127.5 + 128.0)
        local g255 = math.floor(y * 127.5 + 128.0)
        local b255 = math.floor(z * 127.5 + 128.0)

        dialog:modify {
            id = "normalColor",
            colors = { Color(r255, g255, b255, 255) }
        }

        dialog:modify {
            id = "hexCode",
            text = string.format("%06X",
                (r255 << 0x10 | g255 << 0x08 | b255))
        }

        dialog:modify {
            id = "rgbLabel",
            text = string.format("%03d, %03d, %03d",
                r255, g255, b255)
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
    colors = { Color(128, 128, 255, 255) }
}

dlg:newrow { always = false }

dlg:button {
    id = "setColorFore",
    label = "Set:",
    text = "&FORE",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if app.activeSprite and #normalColors > 0 then
            local normalColor = normalColors[1]
            app.fgColor = Color(
                normalColor.red,
                normalColor.green,
                normalColor.blue,
                255)
        end
    end
}

dlg:button {
    id = "setColorBack",
    text = "&BACK",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if app.activeSprite and #normalColors > 0 then
            local normalColor = normalColors[1]
            app.command.SwitchColors()
            app.fgColor = Color(
                normalColor.red,
                normalColor.green,
                normalColor.blue,
                255)
            app.command.SwitchColors()
        end
    end
}

dlg:check {
    id = "showWheelSettings",
    label = "Settings:",
    text = "Wheel",
    selected = defaults.showWheelSettings,
    onclick = function()
        local args = dlg.data
        local state = args.showWheelSettings
        dlg:modify { id = "sectors", visible = state }
        dlg:modify { id = "rings", visible = state }
        dlg:modify { id = "size", visible = state }

        dlg:modify { id = "xFlip", visible = state }
        dlg:modify { id = "yFlip", visible = state }
        dlg:modify { id = "zFlip", visible = state }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "size",
    label = "Size:",
    min = defaults.minSize,
    max = defaults.maxSize,
    value = defaults.size,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectors",
    label = "Sectors:",
    min = 0,
    max = defaults.maxSectors,
    value = defaults.sectors,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "rings",
    label = "Rings:",
    min = 0,
    max = defaults.maxRings,
    value = defaults.rings,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:check {
    id = "xFlip",
    label = "Flip:",
    text = "X",
    selected = defaults.xFlip,
    visible = defaults.showWheelSettings
}

dlg:check {
    id = "yFlip",
    text = "Y",
    selected = defaults.yFlip,
    visible = defaults.showWheelSettings
}

dlg:check {
    id = "zFlip",
    text = "Z",
    selected = defaults.zFlip,
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
        local max = math.max
        local min = math.min

        -- Cache math constants.
        local pi = math.pi
        local tau = pi + pi
        local halfPi = pi * 0.5

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size
        local sectors = args.sectors or defaults.sectors
        local rings = args.rings or defaults.rings
        local xFlip = args.xFlip
        local yFlip = args.yFlip
        local zFlip = args.zFlip

        -- Create sprite.
        local sprite = Sprite(size, size)
        sprite.filename = "Normal Map Color Wheel"
        sprite:assignColorSpace(ColorSpace())
        local cel = sprite.cels[1]

        -- For flipping the wheel orientation.
        local hexDefault = 0xffff8080
        local zFlipNum = 1
        local yFlipNum = 1
        local xFlipNum = 1

        if zFlip then
            zFlipNum = -1
            hexDefault = 0xff008080
        end
        if yFlip then yFlipNum = -1 end
        if xFlip then xFlipNum = -1 end

        -- Discrete sectors (azimuths).
        -- To quantize, values need to be in [0.0, 1.0].
        -- That's why alpha divides by tau and beta
        -- multiplies by tau after the floor.
        local azimAlpha = sectors / tau
        local azimBeta = 0.0
        local quantAzims = sectors > 0
        if quantAzims then
            azimBeta = tau / sectors
        end

        -- Discrete rings (inclinations).
        local inclAlpha = rings / halfPi
        local inclBeta = 0.0
        local quantIncls = rings > 0
        if quantIncls then
            inclBeta = halfPi / rings
        end

        -- Create image, prepare for loop.
        local quantUse = quantAzims or quantIncls
        local szInv = 1.0 / (size - 1.0)

        local imgSpec = ImageSpec { width = size, height = size }
        imgSpec.colorSpace = ColorSpace()
        local img = Image(imgSpec)

        local pxItr = img:pixels()
        for elm in pxItr do

            -- Find rise and run.
            local yNrm = elm.y * szInv
            local ySgn = yFlipNum * (1.0 - (yNrm + yNrm))
            local xNrm = elm.x * szInv
            local xSgn = xFlipNum * (xNrm + xNrm - 1.0)

            -- Find square magnitude.
            -- Magnitude is correlated with inclination.
            -- Epsilon = 2 * ((1 / 255) ^ 2) = 0.000031
            local magSq = xSgn * xSgn + ySgn * ySgn
            if magSq > 0.000031 and magSq <= 1.0 then
                local zSgn = zFlipNum * sqrt(1.0 - magSq)

                local xn = xSgn
                local yn = ySgn
                local zn = zSgn

                -- Discrete swatches are more expensive because
                -- atan2, acos, cos and sin are used.
                if quantUse then
                    local azim = atan2(ySgn, xSgn)
                    -- Are max and min necessary?
                    local incl = halfPi - acos(max(-1.0, min(1.0, zSgn)))

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

                elm(0xff000000
                    | (floor(zn * 127.5 + 128.0) << 0x10)
                    | (floor(yn * 127.5 + 128.0) << 0x08)
                    | floor(xn * 127.5 + 128.0))
            else
                elm(hexDefault)
            end
        end

        cel.image = img
        AseUtilities.setPalette(normalsPal, sprite, 1)
        app.command.FitScreen()
        app.refresh()
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