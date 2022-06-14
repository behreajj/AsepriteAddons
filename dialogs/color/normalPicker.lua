dofile("../../support/aseutilities.lua")

local defaults = {
    x = 0.0,
    y = 0.0,
    z = 1.0,
    azimuth = 0,
    inclination = 90,
    hexCode = "8080FF",
    rgbLabel = "128, 128, 255",

    showGradientSettings = false,
    gradWidth = 256,
    gradHeight = 32,
    swatches = 8,
    aColor = Color(238, 64, 128, 255),
    bColor = Color(128, 255, 128, 255),

    showWheelSettings = false,
    size = 512,
    sectors = 0,
    rings = 0,
    xFlip = false,
    yFlip = false,
    zFlip = false,
    minSize = 256,
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
    0xfff5804f, 0xfff55d5d, 0xfff54f80, 0xfff55da2 }

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
            math.tointeger(x * invMag + 128.0),
            math.tointeger(y * invMag + 128.0),
            math.tointeger(z * invMag + 128.0),
            255)
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

    -- Does c need to be normalized or clamped?
    local cx = aFac * ax + bFac * bx
    local cy = aFac * ay + bFac * by
    local cz = aFac * az + bFac * bz

    local r255 = math.tointeger(cx * 127.5 + 128.0)
    local g255 = math.tointeger(cy * 127.5 + 128.0)
    local b255 = math.tointeger(cz * 127.5 + 128.0)

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

        local r255 = math.tointeger(x * 127.5 + 128.0)
        local g255 = math.tointeger(y * 127.5 + 128.0)
        local b255 = math.tointeger(z * 127.5 + 128.0)

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
    id = "showGradientSettings",
    label = "Settings:",
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

dlg:check {
    id = "showWheelSettings",
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
    min = 3,
    max = 32,
    value = defaults.swatches,
    visible = defaults.showGradientSettings
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
    id = "gradient",
    text = "&GRADIENT",
    focus = false,
    onclick = function()
        local args = dlg.data
        local aColor = args.aColor or defaults.aColor
        local bColor = args.bColor or defaults.bColor
        local swatches = args.swatches or defaults.swatches
        local swatchesInv = 1.0 / (swatches - 1.0)

        local ax, ay, az = colorToVec(aColor)
        local bx, by, bz = colorToVec(bColor)

        -- Because the vectors are already normalized
        -- and known to be non-zero, simplify angle
        -- between formula.
        local abDot = ax * bx + ay * by + az * bz

        -- Gray will result if colors are exactly at
        -- positive or negative one, i.e. vectors
        -- are parallel.
        abDot = math.max(-0.999999,
            math.min(0.999999, abDot))
        local omega = math.acos(abDot)
        local omSin = math.sin(omega)
        local omSinInv = 1.0
        if omSin ~= 0.0 then
            omSinInv = 1.0 / omSin
        end

        -- Create sprite.
        local gradWidth = defaults.gradWidth
        local gradHeight = defaults.gradHeight

        local colorSpaceNone = ColorSpace()
        local gradSprite = Sprite(
            gradWidth,
            gradHeight)
        gradSprite:assignColorSpace(colorSpaceNone)
        gradSprite.filename = "Normal Gradient"

        -- Create smooth image.
        local gradSpec = ImageSpec {
            width = gradWidth,
            height = gradHeight // 2 }
        gradSpec.colorSpace = colorSpaceNone
        local gradImg = Image(gradSpec)
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

        local segSpec = ImageSpec {
            width = gradWidth,
            height = gradHeight - gradHeight // 2 }
        segSpec.colorSpace = colorSpaceNone
        local segImg = Image(segSpec)
        local segImgPxItr = segImg:pixels()

        local swatchesDict = {}
        swatchesDict[0x0] = 1
        local palIdx = 2
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
        local pal = {}
        for k, v in pairs(swatchesDict) do
            pal[v] = k
        end
        AseUtilities.setSpritePalette(pal, gradSprite, 1)

        -- If colors were chosen by index, they will be
        -- blank when new sprite is created, even if
        -- they were accurate vectors.
        dlg:modify {
            id = "aColor",
            color = vecToColor(ax, ay, az)
        }
        dlg:modify {
            id = "bColor",
            color = vecToColor(bx, by, bz)
        }

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
        local max = math.max
        local min = math.min
        local trunc = math.tointeger

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

        -- TODO: Add rotation functionality?
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
                    | (trunc(zn * 127.5 + 128.0) << 0x10)
                    | (trunc(yn * 127.5 + 128.0) << 0x08)
                    | trunc(xn * 127.5 + 128.0))
            else
                elm(hexDefault)
            end
        end

        cel.image = img
        AseUtilities.setSpritePalette(normalsPal, sprite, 1)
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
