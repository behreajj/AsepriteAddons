dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local defaults <const> = {
    barWidth = 240 // screenScale,
    barHeight = 16 // screenScale,
    reticleSize = 3 / screenScale,
    textShadow = 0xffe7e7e7,
    textColor = 0xff181818,
    x = 0.0,
    y = 0.0,
    z = 1.0,
    hexCode = "8080FF",
    azimIncrScale = 15,
    inclIncrScale = 15,
}

local active <const> = {
    azimuth = 0.0,
    inclination = 1.5707963267949,
    azBarWidth = defaults.barWidth,
    inBarWidth = defaults.barWidth
}

local function assignFore()
    if app.site.sprite then
        local v <const> = Vec3.fromSpherical(
            active.azimuth, active.inclination, 1.0)
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

---@param color Color
---@return number
---@return number
---@return number
local function colorToVec(color)
    local r8 = 127.5
    local g8 = 127.5
    local b8 = 255.0

    if color.alpha > 0 then
        r8 = color.red
        g8 = color.green
        b8 = color.blue
    end

    local x <const> = (r8 + r8 - 255) / 255.0
    local y <const> = (g8 + g8 - 255) / 255.0
    local z <const> = (b8 + b8 - 255) / 255.0

    -- The square magnitude for the color #808080
    -- is 0.000046 . Have to account for how 255
    -- is not divided cleanly by 2.
    local sqMag <const> = x * x + y * y + z * z
    if sqMag > 0.000047 then
        local invMag <const> = 1.0 / math.sqrt(sqMag)
        local xn = x * invMag
        local yn = y * invMag
        local zn = z * invMag
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
    local sqMag <const> = x * x + y * y + z * z
    if sqMag > 0.0 then
        local invMag <const> = 127.5 / math.sqrt(sqMag)
        return 0xff000000
            | math.floor(z * invMag + 128.0) << 0x10
            | math.floor(y * invMag + 128.0) << 0x08
            | math.floor(x * invMag + 128.0)
    end
    return 0xff808080
end

---@param x number
---@param y number
---@param z number
---@return string
local function vecToWebHex(x, y, z)
    -- This could be less redundant if it did not normalize.
    local sqMag <const> = x * x + y * y + z * z
    if sqMag > 0.0 then
        local invMag <const> = 127.5 / math.sqrt(sqMag)
        return string.format("%06X",
            math.floor(x * invMag + 128.0) << 0x10
            | math.floor(y * invMag + 128.0) << 0x08
            | math.floor(z * invMag + 128.0))
    end
    return defaults.hexCode
end

---@param dialog Dialog
local function updateFromCartesian(dialog)
    local args <const> = dialog.data
    local x <const> = args.x --[[@as number]]
    local y <const> = args.y --[[@as number]]
    local z <const> = args.z --[[@as number]]

    local azSigned <const> = math.atan(y, x)
    active.azimuth = azSigned % 6.2831853071796

    local sqMag <const> = x * x + y * y + z * z
    local inUnsigned = 1.5707963267949
    if sqMag > 0.0 then
        local invMag <const> = 1.0 / math.sqrt(sqMag)
        local zn <const> = z * invMag
        inUnsigned = math.acos(zn)
        dialog:modify { id = "hexCode", text = vecToWebHex(x, y, z) }
    else
        dialog:modify { id = "hexCode", text = defaults.hexCode }
    end
    active.inclination = 1.5707963267949 - inUnsigned

    dialog:repaint()
end

---@param dialog Dialog
---@param clr Color
local function updateFromColor(dialog, clr)
    local x <const>, y <const>, z <const> = colorToVec(clr)
    if x ~= 0.0 or y ~= 0.0 or z ~= 0.0 then
        dialog:modify { id = "x", text = string.format("%.3f", x) }
        dialog:modify { id = "y", text = string.format("%.3f", y) }
        dialog:modify { id = "z", text = string.format("%.3f", z) }
        dialog:modify { id = "hexCode", text = vecToWebHex(x, y, z) }

        local sph <const> = Vec3.toSpherical(Vec3.new(x, y, z))
        local i <const> = sph.inclination
        active.inclination = i

        -- Azimuth is undefined at sphere poles.
        if i < 1.5707963267949 and i > -1.5707963267949 then
            active.azimuth = sph.azimuth % 6.2831853071796
        end

        dialog:repaint()
    end
end

---@param dialog Dialog
---@param sprite Sprite
---@param frIdx integer
local function updateFromSelect(dialog, sprite, frIdx)
    local v = AseUtilities.averageNormal(sprite, frIdx)
    dialog:modify { id = "x", text = string.format("%.3f", v.x) }
    dialog:modify { id = "y", text = string.format("%.3f", v.y) }
    dialog:modify { id = "z", text = string.format("%.3f", v.z) }
    dialog:modify { id = "hexCode", text = vecToWebHex(v.x, v.y, v.z) }

    local sph <const> = Vec3.toSpherical(v)
    local i <const> = sph.inclination
    active.inclination = i

    -- Azimuth is undefined at sphere poles.
    if i < 1.5707963267949 and i > -1.5707963267949 then
        active.azimuth = sph.azimuth % 6.2831853071796
    end

    dialog:repaint()
end

local dlg = Dialog { title = "Normal Picker" }

---@param event MouseEvent
local function setAzimMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.azBarWidth
        local mxtau <const> = bw > 1
            and (6.2831853071796 * event.x / (bw - 1.0))
            or 0.0
        if event.ctrlKey then
            active.azimuth = 0.0
        elseif event.shiftKey then
            -- Increment is math.pi / 180.
            local incr = 0.017453292519943
            if event.altKey then incr = incr * defaults.azimIncrScale end
            if math.abs(mxtau - active.azimuth) > incr then
                if mxtau < active.azimuth then incr = -incr end
                active.azimuth = (active.azimuth + incr) % 6.2831853071796
            end
        else
            active.azimuth = mxtau % 6.2831853071796
        end
        dlg:repaint()

        local v <const> = Vec3.fromSpherical(
            active.azimuth, active.inclination, 1.0)
        dlg:modify { id = "x", text = string.format("%.3f", v.x) }
        dlg:modify { id = "y", text = string.format("%.3f", v.y) }
        dlg:modify { id = "z", text = string.format("%.3f", v.z) }
        dlg:modify { id = "hexCode", text = vecToWebHex(v.x, v.y, v.z) }
    end
end

---@param event MouseEvent
local function setInclMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.inBarWidth
        local halfPi <const> = 1.5707963267949
        local mxIncl <const> = bw > 1
            and (math.pi * event.x / (bw - 1.0) - halfPi)
            or 0.0
        if event.ctrlKey then
            active.inclination = 0.0
        elseif event.shiftKey then
            -- Increment is math.pi / 180.
            local incr = 0.017453292519943
            if event.altKey then incr = incr * defaults.inclIncrScale end
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

        local v <const> = Vec3.fromSpherical(
            active.azimuth, active.inclination, 1.0)
        dlg:modify { id = "x", text = string.format("%.3f", v.x) }
        dlg:modify { id = "y", text = string.format("%.3f", v.y) }
        dlg:modify { id = "z", text = string.format("%.3f", v.z) }
        dlg:modify { id = "hexCode", text = vecToWebHex(v.x, v.y, v.z) }
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

dlg:button {
    id = "selGet",
    text = "&SELECT",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        local frObj <const> = site.frame
        if sprite and frObj then
            if sprite.colorMode ~= ColorMode.RGB then
                app.alert {
                    title = "Error",
                    text = "Only RGB color mode is supported."
                }
                return
            end
            updateFromSelect(dlg, sprite, frObj.frameNumber)
        end
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "hexCode",
    label = "#:",
    text = defaults.hexCode
}

dlg:newrow { always = false }

dlg:number {
    id = "x",
    label = "Vector:",
    text = string.format("%.3f", defaults.x),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateFromCartesian(dlg)
    end
}

dlg:number {
    id = "y",
    text = string.format("%.3f", defaults.y),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateFromCartesian(dlg)
    end
}

dlg:number {
    id = "z",
    text = string.format("%.3f", defaults.z),
    decimals = AseUtilities.DISPLAY_DECIMAL,
    onchange = function()
        updateFromCartesian(dlg)
    end
}

dlg:newrow { always = false }

dlg:canvas {
    id = "previewCanvas",
    label = "Color:",
    width = defaults.barWidth,
    height = defaults.barHeight,
    vexpand = false,
    focus = true,
    onpaint = function(event)
        -- Unpack defaults.
        local textColor = defaults.textColor
        local textShadow = defaults.textShadow

        -- Unpack active.
        local azimuth <const> = active.azimuth
        local inclination <const> = active.inclination
        local cosIncl <const> = math.cos(inclination)
        local srgbHex <const> = vecToHex(
            cosIncl * math.cos(azimuth),
            cosIncl * math.sin(azimuth),
            math.sin(inclination))

        -- Fill image with color.
        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height

        local bkgImg <const> = Image(barWidth, barHeight)
        bkgImg:clear(srgbHex)
        ctx:drawImage(bkgImg,
            Rectangle(0, 0, barWidth, barHeight),
            Rectangle(0, 0, barWidth, barHeight))

        -- Create display string.
        local strDisplay <const> = string.format(
            "A:%03d I:%03d",
            Utilities.round(math.deg(azimuth)),
            Utilities.round(math.deg(inclination)))
        local strMeasure <const> = ctx:measureText(strDisplay)

        -- Find average brightness, flip text color if too bright.
        local r <const> = (srgbHex & 0xff) / 255.0
        local g <const> = (srgbHex >> 0x08 & 0xff) / 255.0
        local b <const> = (srgbHex >> 0x10 & 0xff) / 255.0
        local avgBri <const> = (r + g + b) / 3.0
        if avgBri < 0.5 then
            textShadow, textColor = textColor, textShadow
        end

        local wBarCenter <const> = barWidth * 0.5
        local wStrHalf <const> = strMeasure.width * 0.5
        local xTextCenter <const> = math.floor(wBarCenter - wStrHalf)

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        ctx.color = AseUtilities.hexToAseColor(textShadow)
        ctx:fillText(strDisplay, xTextCenter + 1, 2)
        ctx.color = AseUtilities.hexToAseColor(textColor)
        ctx:fillText(strDisplay, xTextCenter, 1)
    end,
    onmouseup = function(event)
        local button <const> = event.button
        local leftPressed <const> = button == MouseButton.LEFT
        local rightPressed <const> = button == MouseButton.RIGHT
        local ctrlKey <const> = event.ctrlKey

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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        -- Unpack defaults.
        local reticleSize <const> = defaults.reticleSize

        -- Cache methods.
        local cos <const> = math.cos
        local sin <const> = math.sin

        -- Unpack active.
        local azimuth <const> = active.azimuth
        local inclination <const> = active.inclination
        local cosIncl <const> = cos(inclination)
        local sinIncl <const> = sin(inclination)

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.azBarWidth = barWidth

        local xToAzimuth <const> = barWidth > 1
            and 6.2831853071796 / (barWidth - 1.0)
            or 0.0
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local az <const> = pixel.x * xToAzimuth
            pixel(vecToHex(
                cosIncl * cos(az),
                cosIncl * sin(az),
                sinIncl))
        end

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local az01 <const> = 0.1591549430919 * azimuth
        local fill <const> = Color { r = 255, g = 255, b = 255 }
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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        -- Unpack defaults.
        local reticleSize <const> = defaults.reticleSize

        -- Cache methods.
        local cos <const> = math.cos
        local sin <const> = math.sin

        -- Unpack active.
        local azimuth <const> = active.azimuth
        local inclination <const> = active.inclination
        local cosAzim <const> = cos(azimuth)
        local sinAzim <const> = sin(azimuth)

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.inBarWidth = barWidth

        local halfPi <const> = 1.5707963267949
        local xToIncl <const> = barWidth > 1
            and math.pi / (barWidth - 1.0)
            or 0.0
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local incl <const> = pixel.x * xToIncl - halfPi
            local cosIncl <const> = cos(incl)
            pixel(vecToHex(
                cosIncl * cosAzim,
                cosIncl * sinAzim,
                sin(incl)))
        end

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local in01 <const> = 0.5 + inclination / 3.1415926535898
        local fill <const> = Color { r = 255, g = 255, b = 255 }
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
    onclick = assignFore
}

dlg:button {
    id = "bgSet",
    text = "&BACK",
    focus = false,
    onclick = assignBack
}

dlg:button {
    id = "selSet",
    text = "S&ELECT",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end

        local sprSpec <const> = sprite.spec
        local colorMode <const> = sprSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local v <const> = Vec3.fromSpherical(
            active.azimuth, active.inclination, 1.0)
        local aseColor <const> = Color {
            r = math.floor(v.x * 127.5 + 128.0),
            g = math.floor(v.y * 127.5 + 128.0),
            b = math.floor(v.z * 127.5 + 128.0),
            a = 255
        }
        local hex <const> = AseUtilities.aseColorToHex(aseColor, colorMode)

        local sel <const>, _ <const> = AseUtilities.getSelection(sprite)
        local selBounds <const> = sel.bounds
        local xSel <const> = selBounds.x
        local ySel <const> = selBounds.y
        local wSel <const> = selBounds.width
        local hSel <const> = selBounds.height

        local selSpec <const> = AseUtilities.createSpec(wSel, hSel,
            colorMode, sprSpec.colorSpace, sprSpec.transparentColor)
        local selImage <const> = Image(selSpec)

        ---@type string[]
        local byteStrArr <const> = {}
        local strpack <const> = string.pack
        local areaSel <const> = wSel * hSel
        local h = 0
        while h < areaSel do
            local trg = 0
            if sel:contains(xSel + h % wSel, ySel + h // wSel) then
                trg = hex
            end
            h = h + 1
            byteStrArr[h] = strpack("<I4", trg)
        end
        selImage.bytes = table.concat(byteStrArr)

        app.transaction("Set Selection", function()
            local frIdcs = Utilities.flatArr2(AseUtilities.getFrames(
                sprite, "RANGE", false))
            if #frIdcs < 1 then frIdcs = { site.frame.frameNumber } end

            local lenFrIdcs <const> = #frIdcs
            local layer <const> = sprite:newLayer()
            layer.name = "Selection"
            local tlSel <const> = Point(xSel, ySel)

            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frIdx <const> = frIdcs[i]
                sprite:newCel(layer, frIdx, selImage, tlSel)
            end
        end)
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

updateFromColor(dlg, app.preferences.color_bar.fg_color)
dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    16, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)