local defaults = {
    x = 0.0,
    y = 0.0,
    z = 1.0,
    azimuth = 0,
    inclination = 90,
    hexCode = "8080FF",
    rgbLabel = "128, 128, 255",
    showWheelSettings = false,
    sectors = 0,
    rings = 0,
    size = 512,
    minSize = 256,
    maxSize = 1024,
    maxSectors = 32,
    maxRings = 16,

    showGradientSettings = false,
    gradWidth = 256,
    gradHeight = 32,
    swatches = 8,
    aColor = Color(236, 36, 128, 255),
    bColor = Color(37, 218, 128, 255)
}

local function fromSpherical(az, incl)
    -- TODO: Replace with Vec3 func?
    local a = az * 0.017453292519943295
    local i = incl * 0.017453292519943295
    local cosIncl = math.cos(i)
    return cosIncl * math.cos(a),
        cosIncl * math.sin(a),
        math.sin(i)
end

local function toSpherical(x, y, z)
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.0 then
        local azRad = math.atan(y, x)
        local azDeg = azRad * 57.29577951308232

        local inclRad = math.acos(z / math.sqrt(sqMag))
        local inclDeg = inclRad * 57.29577951308232
        inclDeg = 90.0 - inclDeg

        return azDeg, inclDeg
    else
        return 0.0, 90.0
    end
end

local function colorToVec(clr, clampz)
    local r255 = 127.5
    local g255 = 127.5
    local b255 = 255.0

    if clr.alpha > 0 then
        r255 = clr.red
        g255 = clr.green
        b255 = clr.blue
    end

    if clampz then
        b255 = math.max(127.5, b255)
    end

    local r01 = r255 * 0.00392156862745098
    local g01 = g255 * 0.00392156862745098
    local b01 = b255 * 0.00392156862745098

    local x = r01 + r01 - 1.0
    local y = g01 + g01 - 1.0
    local z = b01 + b01 - 1.0

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

local function lerpToHex(
    ax, ay, az,
    bx, by, bz,
    t, omega, omSinInv)

    local aFac = math.sin((1.0 - t) * omega) * omSinInv
    local bFac = math.sin(t * omega) * omSinInv

    local cx = aFac * ax + bFac * bx
    local cy = aFac * ay + bFac * by
    local cz = aFac * az + bFac * bz

    -- Does c need to be normalized or clamped?
    local r01 = cx * 0.5 + 0.5
    local g01 = cy * 0.5 + 0.5
    local b01 = cz * 0.5 + 0.5

    local r255 = math.tointeger(0.5 + 255.0 * r01)
    local g255 = math.tointeger(0.5 + 255.0 * g01)
    local b255 = math.tointeger(0.5 + 255.0 * b01)

    return 0xff000000
        | (b255 << 0x10)
        | (g255 << 0x08)
        | r255
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

local function updateFromColor(dialog, clr)
    local x, y, z = colorToVec(clr, false)
    if x ~= 0.0 or y ~= 0.0 or z ~= 0.0 then
        dialog:modify { id = "x", text = string.format("%.5f", x) }
        dialog:modify { id = "y", text = string.format("%.5f", y) }
        dialog:modify { id = "z", text = string.format("%.5f", z) }

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

        local nr01 = x * 0.5 + 0.5
        local ng01 = y * 0.5 + 0.5
        local nb01 = z * 0.5 + 0.5

        local nr255 = math.tointeger(0.5 + 255.0 * nr01)
        local ng255 = math.tointeger(0.5 + 255.0 * ng01)
        local nb255 = math.tointeger(0.5 + 255.0 * nb01)

        dialog:modify {
            id = "normalColor",
            colors = { Color(nr255, ng255, nb255, 255) }
        }

        dialog:modify {
            id = "hexCode",
            text = string.format("%06X",
                (nr255 << 0x10 |
                ng255 << 0x08 |
                nb255))
        }

        dialog:modify {
            id = "rgbLabel",
            text = string.format("%d, %d, %d",
                nr255, ng255, nb255)
        }
    end
end

local dlg = Dialog { title = "Normal Color Calc" }

dlg:button {
    id = "getColorFore",
    label = "Get:",
    text = "F&ORE",
    onclick = function()
        updateFromColor(dlg, app.fgColor)
    end
}

dlg:button {
    id = "getColorBack",
    text = "B&ACK",
    onclick = function()
        app.command.SwitchColors()
        updateFromColor(dlg, app.fgColor)
        app.command.SwitchColors()
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "x",
    label = "Vector:",
    text = string.format("%.5f", defaults.x),
    decimals = 5,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "y",
    text = string.format("%.5f", defaults.y),
    decimals = 5,
    onchange = function()
        updateWidgetCart(dlg)
    end
}

dlg:number {
    id = "z",
    text = string.format("%.5f", defaults.z),
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
    value = defaults.inclination,
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

dlg: label {
    id = "hexCode",
    label = "Hex: #",
    text = defaults.hexCode
}

dlg:newrow { always = false }

dlg: label {
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

dlg:button {
    id = "setColorBack",
    text = "&BACK",
    onclick = function()
        local normalColors = dlg.data.normalColor
        if #normalColors > 0 then
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

dlg:newrow { always = false }

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
    end
}

dlg:check {
    id = "showGradientSettings",
    text = "Gradient",
    selected = defaults.showGradientSettings,
    onclick = function()
        local args = dlg.data
        local state = args.showGradientSettings
        dlg:modify { id = "aColor", visible = state }
        dlg:modify { id = "bColor", visible = state }
        dlg:modify { id = "swatches", visible = state }
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

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor,
    visible = defaults.showGradientSettings
}

dlg:color {
    id = "bColor",
    color = defaults.bColor,
    visible = defaults.showGradientSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "swatches",
    label = "Swatches:",
    min = 2,
    max = 32,
    value = defaults.swatches,
    visible = defaults.showGradientSettings
}

dlg:newrow { always = false }

dlg:button {
    id = "gradient",
    text = "&GRADIENT",
    focus = false,
    onclick = function()
        local args = dlg.data
        local aColor = args.aColor or defaults.aColor
        local bColor = args.bColor or defaults.bColor
        local swatches = args.swatches or defaults.swatches
        local swatchesInv = 1.0 / (swatches - 1.0)

        local ax, ay, az = colorToVec(aColor, false)
        local bx, by, bz = colorToVec(bColor, false)

        -- Because the vectors are already normalized
        -- and known to be non-zero, simplify angle
        -- between formula.
        local abDot = ax * bx + ay * by + az * bz
        abDot = math.max(-1.0, math.min(1.0, abDot))
        local omega = math.acos(abDot)
        local omSin = math.sin(omega)
        local omSinInv = 1.0
        if omSin ~= 0.0 then
            omSinInv = 1.0 / omSin
        end

        -- Create sprite.
        local gradWidth = defaults.gradWidth
        local gradHeight = defaults.gradHeight
        local gradSprite = Sprite(gradWidth, gradHeight)
        gradSprite.filename = "Normal Gradient"

        -- Create smooth image.
        local gradImg = Image(gradWidth, gradHeight // 2)
        local gradImgPxItr = gradImg:pixels()
        local xToFac = 1.0 / (gradWidth - 1.0)

        for elm in gradImgPxItr do
            local t = elm.x * xToFac
            elm(lerpToHex(
                ax, ay, az,
                bx, by, bz,
                t, omega, omSinInv))
        end

        gradSprite.cels[1].image = gradImg
        gradSprite.layers[1].name = "Gradient.Smooth"

        -- Create swatches.
        local segLayer = gradSprite:newLayer()
        segLayer.name = "Gradient.Swatches"
        local segImg = Image(gradWidth, gradHeight - gradHeight // 2)
        local segImgPxItr = segImg:pixels()

        local swatchesDict = {}
        local palIdx = 0
        for elm in segImgPxItr do
            local t = elm.x * xToFac
            t = math.max(0.0,
                (math.ceil(t * swatches) - 1.0)
                * swatchesInv)
            local hex = lerpToHex(
                ax, ay, az,
                bx, by, bz,
                t, omega, omSinInv)
            elm(hex)

            if not swatchesDict[hex] then
                swatchesDict[hex] = palIdx
                palIdx = palIdx + 1
            end
        end

        gradSprite:newCel(
            segLayer,
            gradSprite.frames[1],
            segImg,
            Point(0, gradHeight // 2))


        -- Set palette.
        local pal = Palette(swatches)
        for k, v in pairs(swatchesDict) do
            pal:setColor(v, k)
        end
        gradSprite:setPalette(pal)

        app.refresh()
    end
}

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

        -- Cache math constants.
        local pi = math.pi
        local tau = pi + pi
        local halfPi = pi / 2.0

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size
        local sectors = args.sectors or defaults.sectors
        local rings = args.rings or defaults.rings

        -- Create sprite.
        local sprite = Sprite(size, size)
        sprite.filename = "Normal Map Color Wheel"
        sprite:assignColorSpace(ColorSpace())
        local cel = sprite.cels[1]

        -- Discrete sectors (azimuths).
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
            -- Magnitude is correlated with inclination.
            local magSq = xSgn * xSgn + ySgn * ySgn
            if magSq > 0.0 and magSq <= 1.0 then
                local zSgn = sqrt(1.0 - magSq)

                local xn = xSgn
                local yn = ySgn
                local zn = zSgn

                -- Discrete swatches is more expensive because
                -- atan2, acos, cos and sin are used.
                if quantUse then
                    local azim = atan2(ySgn, xSgn)
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

        -- Use a palette with 32 swatches, plus the
        -- center swatch, plus alpha mask.
        local pal = Palette(34)
        pal:setColor( 0, Color(  0,  0,  0,    0))
        pal:setColor( 1, Color(128, 128, 255, 255))
        pal:setColor( 2, Color(255, 128, 128, 255))
        pal:setColor( 3, Color(218, 218, 128, 255))
        pal:setColor( 4, Color(128, 255, 128, 255))
        pal:setColor( 5, Color( 37, 218, 128, 255))
        pal:setColor( 6, Color(  0, 128, 128, 255))
        pal:setColor( 7, Color( 37,  37, 128, 255))
        pal:setColor( 8, Color(128,   0, 128, 255))
        pal:setColor( 9, Color(218,  37, 128, 255))
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

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }