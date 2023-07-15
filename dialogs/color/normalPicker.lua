dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local defaults = {
    -- Should this keep hexadecimal and RGB labels?
    -- Get and set select?
    barWidth = 240 / screenScale,
    barHeight = 16 / screenScale,
    reticleSize = 3 / screenScale,
    textShadow = 0xffe7e7e7,
    textColor = 0xff181818,
    x = 0.0,
    y = 0.0,
    z = 1.0
}

local active = {
    azimuth = 0.0,
    inclination = 1.5707963267949,
}

---@param color Color
---@return number
---@return number
---@return number
local function colorToVec(color)
    local r255 = 127.5
    local g255 = 127.5
    local b255 = 255.0

    if color.alpha > 0 then
        r255 = color.red
        g255 = color.green
        b255 = color.blue
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
        local xn = x * magInv
        local yn = y * magInv
        local zn = z * magInv
        if math.abs(xn) < 0.0039216 then xn = 0.0 end
        if math.abs(yn) < 0.0039216 then yn = 0.0 end
        if math.abs(zn) < 0.0039216 then zn = 0.0 end
        return xn, yn, zn
    else
        return 0.0, 0.0, 1.0
    end
end

---@param x number
---@param y number
---@param z number
---@return integer
local function vecToHex(x, y, z)
    local sqMag = x * x + y * y + z * z
    if sqMag > 0.0 then
        local invMag = 127.5 / math.sqrt(sqMag)
        return 0xff000000
            | math.floor(z * invMag + 128.0) << 0x10
            | math.floor(y * invMag + 128.0) << 0x08
            | math.floor(x * invMag + 128.0)
    end
    return 0xff808080
end

---@param dialog Dialog
local function updateWidgetCart(dialog)
    local args = dialog.data
    local x = args.x --[[@as number]]
    local y = args.y --[[@as number]]
    local z = args.z --[[@as number]]

    local azSigned = math.atan(y, x)
    active.azimuth = azSigned % 6.2831853071796

    local sqMag = x * x + y * y + z * z
    local inUnsigned = 1.5707963267949
    if sqMag > 0.0 then
        inUnsigned = math.acos(z / math.sqrt(sqMag))
    end
    active.inclination = 1.5707963267949 - inUnsigned

    dialog:repaint()
end

---@param dialog Dialog
---@param clr Color
local function updateFromColor(dialog, clr)
    local x, y, z = colorToVec(clr)
    if x ~= 0.0 or y ~= 0.0 or z ~= 0.0 then
        dialog:modify { id = "x", text = string.format("%.3f", x) }
        dialog:modify { id = "y", text = string.format("%.3f", y) }
        dialog:modify { id = "z", text = string.format("%.3f", z) }

        local sph = Vec3.toSpherical(Vec3.new(x, y, z))
        local i = sph.inclination
        active.inclination = i

        -- Azimuth is undefined at sphere poles.
        if i < 1.5707963267949 and i > -1.5707963267949 then
            active.azimuth = sph.azimuth % 6.2831853071796
        end

        dialog:repaint()
    end
end

local function assignFore()
    if app.site.sprite then
        local v = Vec3.fromSpherical(active.azimuth, active.inclination, 1.0)
        if math.abs(v.x) < 0.0039216 then v.x = 0.0 end
        if math.abs(v.y) < 0.0039216 then v.y = 0.0 end
        if math.abs(v.z) < 0.0039216 then v.z = 0.0 end
        app.fgColor = Color {
            r = math.floor(v.x * 127.5 + 128.0),
            g = math.floor(v.y * 127.5 + 128.0),
            b = math.floor(v.z * 127.5 + 128.0),
            a = 255
        }
    end
end

local function assignBack()
    -- Bug where assigning to app.bgColor leads
    -- to unlocked palette colors changing.
    app.command.SwitchColors()
    assignFore()
    app.command.SwitchColors()
end

local dlg = Dialog { title = "Normal Picker" }

---@param event MouseEvent
local function setAzimMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mxtau = 6.2831853071796 * event.x / (bw - 1.0)
        if event.ctrlKey then
            active.azimuth = 0.0
        elseif event.shiftKey then
            local incr = 0.0159154943092
            if math.abs(mxtau - active.azimuth) > incr then
                if mxtau < active.azimuth then incr = -incr end
                active.azimuth = (active.azimuth + incr) % 6.2831853071796
            end
        else
            active.azimuth = mxtau % 6.2831853071796
        end
        dlg:repaint()

        local v = Vec3.fromSpherical(active.azimuth, active.inclination, 1.0)
        dlg:modify { id = "x", text = string.format("%.3f", v.x) }
        dlg:modify { id = "y", text = string.format("%.3f", v.y) }
        dlg:modify { id = "z", text = string.format("%.3f", v.z) }
    end
end

---@param event MouseEvent
local function setInclMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local halfPi = 1.5707963267949
        local mxIncl = math.pi * event.x / (bw - 1.0) - halfPi
        if event.ctrlKey then
            active.inclination = 0.0
        elseif event.shiftKey then
            local incr = 0.0159154943092
            if math.abs(mxIncl - active.inclination) > incr then
                if mxIncl < active.inclination then incr = -incr end
                active.inclination = math.min(math.max(
                    active.inclination + incr,
                    -halfPi), halfPi)
            end
        else
            active.inclination = math.min(math.max(
                mxIncl, -halfPi), halfPi)
        end
        dlg:repaint()

        local v = Vec3.fromSpherical(active.azimuth, active.inclination, 1.0)
        dlg:modify { id = "x", text = string.format("%.3f", v.x) }
        dlg:modify { id = "y", text = string.format("%.3f", v.y) }
        dlg:modify { id = "z", text = string.format("%.3f", v.z) }
    end
end

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "F&ORE",
    focus = false,
    onclick = function()
        if app.site.sprite then
            updateFromColor(dlg, app.fgColor)
        end
    end
}

dlg:button {
    id = "bgGet",
    text = "B&ACK",
    focus = false,
    onclick = function()
        if app.site.sprite then
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

dlg:canvas {
    id = "previewCanvas",
    label = "Color:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    focus = true,
    onpaint = function(event)
        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local textColor = defaults.textColor
        local textShadow = defaults.textShadow

        -- Unpack active.
        local azimuth = active.azimuth
        local inclination = active.inclination
        local cosIncl = math.cos(inclination)
        local srgbHex = vecToHex(
            cosIncl * math.cos(azimuth),
            cosIncl * math.sin(azimuth),
            math.sin(inclination))

        -- Fill image with color.
        local ctx = event.context
        local bkgImg = Image(barWidth, barHeight)
        bkgImg:clear(srgbHex)
        ctx:drawImage(bkgImg, 0 ,0)

        -- Create display string.
        local strDisplay = string.format(
            "A:%03d I:%03d",
            Utilities.round(math.deg(azimuth)),
            Utilities.round(math.deg(inclination)))
        local strMeasure = ctx:measureText(strDisplay)

        -- Find average brightness, flip text color
        -- if too bright.
        local r = (srgbHex & 0xff) * 0.003921568627451
        local g = (srgbHex >> 0x08 & 0xff) * 0.003921568627451
        local b = (srgbHex >> 0x10 & 0xff) * 0.003921568627451
        local avgBri = (r + g + b) / 3.0
        if avgBri < 0.5 then
            textShadow, textColor = textColor, textShadow
        end

        local wBarCenter = barWidth * 0.5
        local wStrHalf = strMeasure.width * 0.5
        local xTextCenter = wBarCenter - wStrHalf

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        ctx.color = AseUtilities.hexToAseColor(textShadow)
        ctx:fillText(strDisplay, xTextCenter + 1, 2)
        ctx.color = AseUtilities.hexToAseColor(textColor)
        ctx:fillText(strDisplay, xTextCenter, 1)
    end,
    onmouseup = function(event)
        local button = event.button
        local leftPressed = button == MouseButton.LEFT
        local rightPressed = button == MouseButton.RIGHT
        local ctrlKey = event.ctrlKey

        if leftPressed and (not ctrlKey) then
            assignFore()
        end

        if rightPressed or (leftPressed and ctrlKey) then
            assignBack()
        end
    end
}

dlg:newrow { always = false }

dlg:canvas {
    id = "azimuthCanvas",
    label = "Azimuth:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        -- Cache methods.
        local cos = math.cos
        local sin = math.sin

        -- Unpack active.
        local azimuth = active.azimuth
        local inclination = active.inclination
        local cosIncl = cos(inclination)
        local sinIncl = sin(inclination)

        local xToAzimuth = 6.2831853071796 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local az = pixel.x * xToAzimuth
            pixel(vecToHex(
                cosIncl * cos(az),
                cosIncl * sin(az),
                sinIncl))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

        local az01 = 0.1591549430919 * azimuth
        local fill = Color { r = 255, g = 255, b = 255 }
        CanvasUtilities.drawSliderReticle(ctx,
            az01, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setAzimMouseListen,
    onmousemove = setAzimMouseListen
}

dlg:canvas {
    id = "inclCanvas",
    label = "Incline:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        -- Cache methods.
        local cos = math.cos
        local sin = math.sin

        -- Unpack active.
        local azimuth = active.azimuth
        local inclination = active.inclination
        local cosAzim = cos(azimuth)
        local sinAzim = sin(azimuth)

        local halfPi = 1.5707963267949
        local xToIncl = math.pi / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local incl = pixel.x * xToIncl - halfPi
            local cosIncl = cos(incl)
            pixel(vecToHex(
                cosIncl * cosAzim,
                cosIncl * sinAzim,
                sin(incl)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

        local in01 = 0.5 + inclination / 3.1415926535898
        local fill = Color { r = 255, g = 255, b = 255 }
        CanvasUtilities.drawSliderReticle(ctx,
            in01, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setInclMouseListen,
    onmousemove = setInclMouseListen
}

dlg:newrow { always = false }

dlg:button {
    id = "fgSet",
    label = "Set:",
    text = "&FORE",
    focus = false,
    visible = true,
    onclick = assignFore
}

dlg:button {
    id = "bgSet",
    text = "&BACK",
    focus = false,
    visible = true,
    onclick = assignBack
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

updateFromColor(dlg, app.preferences.color_bar.fg_color)
dlg:show { wait = false }