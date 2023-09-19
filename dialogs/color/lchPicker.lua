dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale <const> = app.preferences.general.screen_scale

local harmonyTypes <const> = {
    "ANALOGOUS",
    "COMPLEMENT",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TETRADIC",
    "TRIADIC"
}

local defaults <const> = {
    lchTosRgb = Clr.srLchTosRgb,
    sRgbToLch = Clr.sRgbToSrLch,
    sRgbToLab = Clr.sRgbToSrLab2,
    labToLch = Clr.srLab2ToSrLch,
    lchToLab = Clr.srLchToSrLab2,
    harmonyType = "SHADING",
    barWidth = 240 // screenScale,
    barHeight = 16 // screenScale,
    reticleSize = 3 // screenScale,
    inGamutEps = 0.115,
    textShadow = 0xffe7e7e7,
    textColor = 0xff181818,
    shadeCount = 7,
    hueSpreadShd = 0.66666666666667,
    hueSpreadLgt = 0.33333333333333,
    chromaSpreadShd = 5.0,
    chromaSpreadLgt = 15.0,
    lightSpread = 33.33,
    hYellow = 0.30922841685655,
    hViolet = 0.80922841685655
}

local active <const> = {
    l = 50.0,
    c = 30.0,
    h = 0.0,
    a = 1.0,
    swatches = {}
}

local function assignFore()
    if app.activeSprite then
        local srgb = defaults.lchTosRgb(
            active.l, active.c, active.h, active.a)
        app.fgColor = AseUtilities.clrToAseColor(srgb)
    end
end

local function assignBack()
    -- Bug where assigning to app.bgColor leads
    -- to unlocked palette colors changing.
    app.command.SwitchColors()
    assignFore()
    app.command.SwitchColors()
end

---@param dialog Dialog
---@param l number
---@param c number
---@param h number
---@return string
local function updateHexCode(dialog, l, c, h)
    local srgb <const> = defaults.lchTosRgb(l, c, h, 1.0)
    local str <const> = Clr.toHexWeb(srgb)
    dialog:modify { id = "hexCode", text = str }
    return str
end

---@param dialog Dialog
---@param aseColor Color
local function setFromAse(dialog, aseColor)
    local srgb <const> = AseUtilities.aseColorToClr(aseColor)
    local lch <const> = defaults.sRgbToLch(srgb, 0.007072)
    active.l = lch.l
    active.c = lch.c
    if lch.c > 0.5 then
        active.h = lch.h
    end
    active.a = lch.a
    dialog:repaint()
    updateHexCode(dialog, active.l, active.c, active.h)
end

---@param dialog Dialog
---@param sprite Sprite
---@param frame integer|Frame
local function setFromSelect(dialog, sprite, frame)
    local lab <const> = AseUtilities.averageColor(sprite, frame)
    if lab.alpha > 0.0 then
        -- Average color uses SR LAB 2.
        local lch <const> = Clr.srLab2ToSrLch(
            lab.l, lab.a, lab.b, lab.alpha)

        active.l = lch.l
        active.c = lch.c
        active.h = lch.h
        active.a = lch.a

        dialog:repaint()
        updateHexCode(dialog, active.l, active.c, active.h)
    end
    app.refresh()
end

local dlg <const> = Dialog { title = "LCH Color Picker" }

---@param event MouseEvent
local function setAlphaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = defaults.barWidth
        local mx01 <const> = event.x / (bw - 1.0)
        if event.ctrlKey then
            active.a = 1.0
        elseif event.shiftKey then
            local incr = 0.003921568627451
            if math.abs(mx01 - active.a) > incr then
                if mx01 < active.a then incr = -incr end
                active.a = math.min(math.max(
                    active.a + incr, 0.0), 1.0)
            end
        else
            active.a = math.min(math.max(mx01, 0.0), 1.0)
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setLightMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = defaults.barWidth
        local mx100 <const> = 100.0 * event.x / (bw - 1.0)
        if event.ctrlKey then
            active.l = 50.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx100 - active.l) > incr then
                if mx100 < active.l then incr = -incr end
                active.l = math.min(math.max(
                    active.l + incr, 0.0), 100.0)
            end
        else
            active.l = math.min(math.max(mx100, 0.0), 100.0)
        end
        dlg:repaint()
        updateHexCode(dlg, active.l, active.c, active.h)
    end
end

---@param event MouseEvent
local function setChromaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = defaults.barWidth
        local maxChroma <const> = Clr.SR_LCH_MAX_CHROMA + 0.5
        local mx120 <const> = maxChroma * event.x / (bw - 1.0)
        if event.ctrlKey then
            local inGamutEps <const> = defaults.inGamutEps
            local incr <const> = 1.0

            local isInGamut <const> = Clr.rgbIsInGamut
            local lchTosRgb <const> = defaults.lchTosRgb

            local l <const> = active.l
            local c = 0.0
            local h <const> = active.h
            local a <const> = active.a
            local clr = nil

            repeat
                c = c + incr
                clr = lchTosRgb(l, c, h, a)
            until (not isInGamut(clr, inGamutEps))
            active.c = c
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx120 - active.c) > incr then
                if mx120 < active.c then incr = -incr end
                active.c = math.min(math.max(
                    active.c + incr, 0.0), maxChroma)
            end
        else
            active.c = math.min(math.max(mx120, 0.0), maxChroma)
        end
        dlg:repaint()
        updateHexCode(dlg, active.l, active.c, active.h)
    end
end

---@param event MouseEvent
local function setHueMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = defaults.barWidth
        local mx01 <const> = event.x / (bw - 1.0)
        if event.ctrlKey then
            active.h = 0.0
        elseif event.shiftKey then
            local incr = 0.0027777777777778
            if math.abs(mx01 - active.h) > incr then
                if mx01 < active.h then incr = -incr end
                active.h = (active.h + incr) % 1.0
            end
        else
            active.h = mx01 % 1.0
        end
        dlg:repaint()
        updateHexCode(dlg, active.l, active.c, active.h)
    end
end

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "F&ORE",
    focus = false,
    onclick = function()
        if app.site.sprite then
            setFromAse(dlg, app.fgColor)
        end
    end
}

dlg:button {
    id = "bgGet",
    text = "B&ACK",
    focus = false,
    onclick = function()
        if app.site.sprite then
            app.command.SwitchColors()
            setFromAse(dlg, app.fgColor)
            app.command.SwitchColors()
        end
    end
}

dlg:button {
    id = "selGet",
    text = "&SELECT",
    focus = false,
    onclick = function()
        local site = app.site
        local sprite = site.sprite
        local frame = site.frame
        if sprite and frame then
            setFromSelect(dlg, sprite, frame)
        end
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "hexCode",
    label = "#:",
    text = defaults.hexCode,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local hexStr <const> = args.hexCode --[[@as string]]
        -- if #hexStr > 5 then
        local srgb <const> = Clr.fromHexWeb(hexStr)
        local lch <const> = defaults.sRgbToLch(srgb)
        active.l = lch.l
        active.c = lch.c
        active.h = lch.h
        dlg:repaint()
        -- end
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
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local textColor = defaults.textColor
        local textShadow = defaults.textShadow

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h
        local a <const> = active.a

        -- Manual alpha blend with theme bkg.
        local bkgColor <const> = app.theme.color.window_face
        local bkgClr <const> = AseUtilities.aseColorToClr(bkgColor)
        local srgb <const> = defaults.lchTosRgb(l, c, h, 1.0)
        local alphaMix <const> = Clr.mix(bkgClr, srgb, a)
        local srgbHex <const> = Clr.toHex(alphaMix)

        -- Fill image with color.
        local ctx <const> = event.context
        local bkgImg <const> = Image(barWidth, barHeight)
        bkgImg:clear(srgbHex)
        ctx:drawImage(bkgImg,
            Rectangle(0, 0, barWidth, barHeight),
            Rectangle(0, 0, barWidth, barHeight))

        -- Create display string.
        local strDisplay <const> = string.format(
            "L:%03d C:%03d H:%03d A:%03d",
            math.floor(l + 0.5),
            math.floor(c + 0.5),
            math.floor(h * 360.0 + 0.5),
            math.floor(a * 255.0 + 0.5))
        local strMeasure <const> = ctx:measureText(strDisplay)

        -- Flip text colors for bright colors.
        if l < 54.0 then
            textShadow, textColor = textColor, textShadow
        end

        local wBarCenter <const> = barWidth * 0.5
        local wStrHalf <const> = strMeasure.width * 0.5
        local xTextCenter <const> = wBarCenter - wStrHalf

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
    id = "lightCanvas",
    label = "L:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local inGamutEps <const> = defaults.inGamutEps
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Clr.rgbIsInGamut
        local toHex <const> = Clr.toHex

        local xToLight <const> = 100.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xLight <const> = pixel.x * xToLight
            local srgb <const> = lchTosRgb(xLight, c, h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end

        local ctx <const> = event.context
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill = Color { r = 0, g = 0, b = 0 }
        if l < 54.0 then
            fill = Color { r = 255, g = 255, b = 255 }
        end
        CanvasUtilities.drawSliderReticle(
            ctx, l * 0.01, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setLightMouseListen,
    onmousemove = setLightMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "chromaCanvas",
    label = "C:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local inGamutEps <const> = defaults.inGamutEps
        local maxChroma <const> = Clr.SR_LCH_MAX_CHROMA + 0.5
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Clr.rgbIsInGamut
        local toHex <const> = Clr.toHex

        local xToChroma <const> = maxChroma / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xChroma <const> = pixel.x * xToChroma
            local srgb <const> = lchTosRgb(l, xChroma, h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end

        local ctx <const> = event.context
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill = Color { r = 0, g = 0, b = 0 }
        if l < 54.0 then
            fill = Color { r = 255, g = 255, b = 255 }
        end
        CanvasUtilities.drawSliderReticle(
            ctx, c / maxChroma, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setChromaMouseListen,
    onmousemove = setChromaMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "hueCanvas",
    label = "H:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local inGamutEps <const> = defaults.inGamutEps
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Clr.rgbIsInGamut
        local toHex <const> = Clr.toHex

        local xToHue <const> = 1.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xHue <const> = pixel.x * xToHue
            local srgb <const> = lchTosRgb(l, c, xHue, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end

        local ctx <const> = event.context
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill = Color { r = 0, g = 0, b = 0 }
        if l < 54.0 then
            fill = Color { r = 255, g = 255, b = 255 }
        end
        CanvasUtilities.drawSliderReticle(
            ctx, h, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setHueMouseListen,
    onmousemove = setHueMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "alphaCanvas",
    label = "Alpha:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local reticleSize <const> = defaults.reticleSize

        local bkgColor <const> = app.theme.color.window_face
        local bBkg <const> = bkgColor.blue * 0.003921568627451
        local gBkg <const> = bkgColor.green * 0.003921568627451
        local rBkg <const> = bkgColor.red * 0.003921568627451

        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h
        local a <const> = active.a

        local srgb = defaults.lchTosRgb(l, c, h, a)
        srgb = Clr.clamp01(srgb)
        local rTrg <const> = srgb.r
        local gTrg <const> = srgb.g
        local bTrg <const> = srgb.b

        local floor <const> = math.floor
        local xToFac <const> = 1.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local t <const> = pixel.x * xToFac
            local u <const> = 1.0 - t

            local b <const> = floor((u * bBkg + t * bTrg) * 255 + 0.5)
            local g <const> = floor((u * gBkg + t * gTrg) * 255 + 0.5)
            local r <const> = floor((u * rBkg + t * rTrg) * 255 + 0.5)

            pixel(0xff000000 | b << 0x10 | g << 0x08 | r)
        end

        local ctx <const> = event.context
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill = Color { r = 0, g = 0, b = 0 }
        if l < 54.0 then
            fill = Color { r = 255, g = 255, b = 255 }
        end
        CanvasUtilities.drawSliderReticle(
            ctx, a, barWidth, barHeight,
            fill, reticleSize)
    end,
    onmousedown = setAlphaMouseListen,
    onmousemove = setAlphaMouseListen
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

dlg:button {
    id = "selSet",
    text = "S&ELECT",
    focus = false,
    onclick = function()
        if active.a <= 0.0 then return end
        local sprite <const> = app.site.sprite
        if not sprite then return end

        local sprSpec <const> = sprite.spec
        local colorMode <const> = sprSpec.colorMode

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        local srgb <const> = defaults.lchTosRgb(
            active.l, active.c, active.h, active.a)
        local aseColor <const> = AseUtilities.clrToAseColor(srgb)
        local hex <const> = AseUtilities.aseColorToHex(aseColor, colorMode)

        local sel <const>, _ <const> = AseUtilities.getSelection(sprite)
        local selBounds <const> = sel.bounds
        local xSel <const> = selBounds.x
        local ySel <const> = selBounds.y

        local selSpec <const> = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = colorMode,
            transparentColor = sprSpec.transparentColor
        }
        selSpec.colorSpace = sprSpec.colorSpace
        local selImage <const> = Image(selSpec)
        local pxItr <const> = selImage:pixels()

        for pixel in pxItr do
            local x <const> = pixel.x + xSel
            local y <const> = pixel.y + ySel
            if sel:contains(x, y) then
                pixel(hex)
            end
        end

        app.transaction("Set Selection", function()
            -- This is an extra precaution because creating
            -- a new layer wipes out a range.
            local tlHidden <const> = not app.preferences.general.visible_timeline
            if tlHidden then
                app.command.Timeline { open = true }
            end

            local frameIdcs = { app.activeFrame.frameNumber }
            local appRange <const> = app.range
            if appRange.sprite == sprite then
                frameIdcs = AseUtilities.frameObjsToIdcs(appRange.frames)
            end

            if tlHidden then
                app.command.Timeline { close = true }
            end

            local lenFrames <const> = #frameIdcs
            local sprFrames <const> = sprite.frames
            local layer <const> = sprite:newLayer()
            local tlSel <const> = Point(xSel, ySel)
            layer.name = "Selection"
            local i = 0
            while i < lenFrames do
                i = i + 1
                local frameIdx <const> = frameIdcs[i]
                local frameObj <const> = sprFrames[frameIdx]
                sprite:newCel(
                    layer, frameObj,
                    selImage, tlSel)
            end
        end)
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:canvas {
    id = "harmonyCanvas",
    label = "Swatch:",
    width = defaults.barWidth,
    height = defaults.barHeight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack defaults.
        local barWidth <const> = defaults.barWidth
        local barHeight <const> = defaults.barHeight
        local inGamutEps <const> = defaults.inGamutEps

        -- Unpack dialog arguments.
        local args <const> = dlg.data
        local harmonyType <const> = args.harmonyType --[[@as string]]

        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h
        local a <const> = active.a

        -- RYB wheel color theory based on the idea that
        -- 180 degrees from key color is also opposite light,
        -- e.g., dark violet is opposite bright yellow.
        -- (120.0 / 180.0) * l + (060.0 / 180.0) * (100.0 - l)
        -- (060.0 / 180.0) * l + (120.0 / 180.0) * (100.0 - l)
        -- (150.0 / 180.0) * l + (030.0 / 180.0) * (100.0 - l)
        -- (030.0 / 180.0) * l + (150.0 / 180.0) * (100.0 - l)
        ---@type { l: number, c: number, h: number, a: number }[]
        local swatches <const> = {}
        if harmonyType == "ANALOGOUS" then
            local lAna <const> = (l + l + 50.0) / 3.0
            local h30 <const> = 0.08333333333333
            swatches[1] = { l = lAna, c = c, h = (h + h30) % 1.0, a = a }
            swatches[2] = { l = lAna, c = c, h = (h - h30) % 1.0, a = a }
        elseif harmonyType == "COMPLEMENT" then
            swatches[1] = { l = 100.0 - l, c = c, h = (h + 0.5) % 1.0, a = a }
        elseif harmonyType == "SPLIT" then
            local lSpl <const> = (250.0 - (l + l)) / 3.0
            local h150 <const> = 0.41666666666667
            swatches[1] = { l = lSpl, c = c, h = (h + h150) % 1.0, a = a }
            swatches[2] = { l = lSpl, c = c, h = (h - h150) % 1.0, a = a }
        elseif harmonyType == "SQUARE" then
            swatches[1] = { l = 50.0, c = c, h = (h + 0.25) % 1.0, a = a }
            swatches[2] = { l = 100.0 - l, c = c, h = (h + 0.5) % 1.0, a = a }
            swatches[3] = { l = 50.0, c = c, h = (h - 0.25) % 1.0, a = a }
        elseif harmonyType == "TETRADIC" then
            local lTri <const> = (200.0 - l) / 3.0
            local lTet <const> = (100.0 + l) / 3.0
            local h120 <const> = 0.33333333333333
            local h60 <const> = 0.16666666666667
            swatches[1] = { l = lTri, c = c, h = (h + h120) % 1.0, a = a }
            swatches[2] = { l = 100.0 - l, c = c, h = (h + 0.5) % 1.0, a = a }
            swatches[3] = { l = lTet, c = c, h = (h - h60) % 1.0, a = a }
        elseif harmonyType == "TRIADIC" then
            local lTri <const> = (200.0 - l) / 3.0
            local h120 <const> = 0.33333333333333
            swatches[1] = { l = lTri, c = c, h = (h + h120) % 1.0, a = a }
            swatches[2] = { l = lTri, c = c, h = (h - h120) % 1.0, a = a }
        else
            -- Unpack shading specific defaults.
            local shadeCount <const> = defaults.shadeCount
            local hueSpreadShd <const> = defaults.hueSpreadShd
            local hueSpreadLgt <const> = defaults.hueSpreadLgt
            local chromaSpreadShd <const> = defaults.chromaSpreadShd
            local chromaSpreadLgt <const> = defaults.chromaSpreadLgt
            local lightSpread <const> = defaults.lightSpread
            local hYellow <const> = defaults.hYellow
            local hViolet <const> = defaults.hViolet

            local minLight <const> = math.max(0.0, l - lightSpread)
            local maxLight <const> = math.min(100.0, l + lightSpread)
            local minChromaShd <const> = math.max(0.0, c - chromaSpreadShd)
            local minChromaLgt <const> = math.max(0.0, c - chromaSpreadLgt)
            local toShdFac <const> = math.abs(50.0 - minLight) * 0.02
            local toLgtFac <const> = math.abs(50.0 - maxLight) * 0.02

            local shdHue <const> = Utilities.lerpAngleNear(h, hViolet, hueSpreadShd * toShdFac, 1.0)
            local lgtHue <const> = Utilities.lerpAngleNear(h, hYellow, hueSpreadLgt * toLgtFac, 1.0)

            local shdCrm <const> = (1.0 - toShdFac) * c + minChromaShd * toShdFac
            local lgtCrm <const> = (1.0 - toLgtFac) * c + minChromaLgt * toLgtFac

            local labShd <const> = defaults.lchToLab(minLight, shdCrm, shdHue, 1.0, 0.5)
            local labKey <const> = defaults.lchToLab(l, c, h, 1.0, 0.5)
            local labLgt <const> = defaults.lchToLab(maxLight, lgtCrm, lgtHue, 1.0, 0.5)

            local pt0 <const> = Vec3.new(labShd.a, labShd.b, labShd.l)
            local pt1 <const> = Vec3.new(labKey.a, labKey.b, labKey.l)
            local pt2 <const> = Vec3.new(labLgt.a, labLgt.b, labLgt.l)

            local kn0 <const> = Knot3.new(
                pt0, pt1, Vec3.new(0.0, 0.0, 0.0))
            local kn1 <const> = Knot3.new(
                pt2, Vec3.new(0.0, 0.0, 0.0), pt1)
            kn0:mirrorHandlesForward()
            kn1:mirrorHandlesBackward()

            local eval <const> = Curve3.eval
            local labToLch <const> = defaults.labToLch
            local curve <const> = Curve3.new(false, { kn0, kn1 }, "Shades")
            local toFac = 1.0
            if shadeCount > 1 then
                toFac = 1.0 / (shadeCount - 1.0)
            end
            local i = 0
            while i < shadeCount do
                local v <const> = eval(curve, i * toFac)
                i = i + 1
                swatches[i] = labToLch(v.z, v.x, v.y, a)
            end
        end
        active.swatches = swatches

        -- Display.
        local lenSwatches <const> = #swatches
        local wsw <const> = math.floor(barWidth / lenSwatches + 0.5)
        local hsw <const> = barHeight
        local ctx <const> = event.context
        local swatchRect <const> = Rectangle(0, 0, wsw, hsw)

        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Clr.rgbIsInGamut
        local clrToAseColor <const> = AseUtilities.clrToAseColor

        local j = 0
        while j < lenSwatches do
            swatchRect.x = j * wsw
            j = j + 1
            local swatch <const> = swatches[j]
            local srgb <const> = lchTosRgb(swatch.l, swatch.c, swatch.h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                ctx.color = clrToAseColor(srgb)
                ctx:fillRect(swatchRect)
            end
        end
    end,
    onmouseup = function(event)
        local x <const> = event.x
        local fac <const> = x / (defaults.barWidth - 1.0)
        local swatches <const> = active.swatches
        local lenSwatches <const> = #swatches

        local idx = 0
        if fac <= 0.0 then
            idx = 0
        elseif fac >= 1.0 then
            idx = lenSwatches - 1
        else
            idx = math.floor(fac * lenSwatches)
        end

        local swatch <const> = swatches[1 + idx]
        if event.shiftKey then
            local srgb <const> = defaults.lchTosRgb(
                swatch.l, swatch.c, swatch.h, swatch.a)
            local aseColor <const> = AseUtilities.clrToAseColor(srgb)
            if event.button == MouseButton.RIGHT
                or event.ctrlKey then
                app.command.SwitchColors()
                app.fgColor = aseColor
                app.command.SwitchColors()
            else
                app.fgColor = aseColor
            end
        else
            active.l = swatch.l
            active.c = swatch.c
            active.h = swatch.h
            updateHexCode(dlg, active.l, active.c, active.h)
            dlg:repaint()
        end
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    option = defaults.harmonyType,
    options = harmonyTypes,
    onchange = function()
        dlg:repaint()
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

setFromAse(dlg, app.preferences.color_bar.fg_color)
dlg:show { wait = false }