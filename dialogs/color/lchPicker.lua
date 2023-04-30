dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local harmonyTypes = {
    "ANALOGOUS",
    "COMPLEMENT",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local defaults = {
    -- lchTosRgb = Clr.cieLchTosRgb,
    -- sRgbToLch = Clr.sRgbToCieLch,
    -- sRgbToLab = Clr.sRgbToCieLab,
    -- labToLch = Clr.cieLabToCieLch,
    -- lchToLab = Clr.cieLchToCieLab,
    lchTosRgb = Clr.srLchTosRgb,
    sRgbToLch = Clr.sRgbToSrLch,
    sRgbToLab = Clr.sRgbToSrLab2,
    labToLch = Clr.srLab2ToSrLch,
    lchToLab = Clr.srLchToSrLab2,
    harmonyType = "SHADING",
    barWidth = 240 / screenScale,
    barHeight = 16 / screenScale,
    reticleSize = 3 / screenScale,
    inGamutEps = 0.115,
    maxChroma = 135,
    textShadow = 0xffe7e7e7,
    textColor = 0xff181818,
    shadeCount = 7,
    hueSpreadShd = 0.66666666666667,
    hueSpreadLgt = 0.33333333333333,
    chromaSpreadShd = 5.0,
    chromaSpreadLgt = 15.0,
    lightSpread = 37.5,
    hYellow = 0.28570825759858,
    hViolet = 0.78570825759858
}

local active = {
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

local function updateHexCode(dialog, l, c, h)
    local srgb = defaults.lchTosRgb(l, c, h, 1.0)
    local str = Clr.toHexWeb(srgb)
    dialog:modify { id = "hexCode", text = str }
    return str
end

local function setFromAse(dialog, aseColor)
    local srgb = AseUtilities.aseColorToClr(aseColor)
    local lch = defaults.sRgbToLch(srgb, 0.007072)
    active.l = lch.l
    active.c = lch.c
    if lch.c > 0.5 then
        active.h = lch.h
    end
    active.a = lch.a
    dialog:repaint()
    updateHexCode(dialog, active.l, active.c, active.h)
end

local function setFromSelect(dialog, sprite, frame)
    if not sprite then return end
    if not frame then return end

    local sel = AseUtilities.getSelection(sprite)
    local selBounds = sel.bounds
    local xSel = selBounds.x
    local ySel = selBounds.y

    local sprSpec = sprite.spec
    local colorMode = sprSpec.colorMode
    local selSpec = ImageSpec {
        width = math.max(1, selBounds.width),
        height = math.max(1, selBounds.height),
        colorMode = colorMode,
        transparentColor = sprSpec.transparentColor
    }
    selSpec.colorSpace = sprSpec.colorSpace
    local flatImage = Image(selSpec)

    -- This will ignore a reference image,
    -- meaning you can't sample it for color.
    flatImage:drawSprite(
        sprite, frame, Point(-xSel, -ySel))
    local pxItr = flatImage:pixels()

    -- The key is the color in hex; the value is a
    -- number of pixels with that color in the
    -- selection. This tally is for the average.
    ---@type table<integer, integer>
    local hexDict = {}
    local eval = nil
    if colorMode == ColorMode.RGB then
        eval = function(h, d)
            if (h & 0xff000000) ~= 0 then
                local q = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.GRAY then
        eval = function(gray, d)
            local a = (gray >> 0x08) & 0xff
            if a > 0 then
                local v = gray & 0xff
                local h = a << 0x18 | v << 0x10 | v << 0x08 | v
                local q = d[h]
                if q then d[h] = q + 1 else d[h] = 1 end
            end
        end
    elseif colorMode == ColorMode.INDEXED then
        eval = function(idx, d, pal)
            if idx > -1 and idx < #pal then
                local aseColor = pal:getColor(idx)
                local a = aseColor.alpha
                if a > 0 then
                    local h = aseColor.rgbaPixel
                    local q = d[h]
                    if q then d[h] = q + 1 else d[h] = 1 end
                end
            end
        end
    else
        -- Tile maps have a color mode of 4 in 1.3 beta.
        return
    end

    local palette = AseUtilities.getPalette(
        app.activeFrame, sprite.palettes)
    for pixel in pxItr do
        local x = pixel.x + xSel
        local y = pixel.y + ySel
        if sel:contains(x, y) then
            eval(pixel(), hexDict, palette)
        end
    end

    local lSum = 0.0
    local aSum = 0.0
    local bSum = 0.0
    local alphaSum = 0.0
    local count = 0

    local fromHex = Clr.fromHex
    local sRgbToLab = defaults.sRgbToLab

    for k, v in pairs(hexDict) do
        local srgb = fromHex(k)
        local lab = sRgbToLab(srgb)
        lSum = lSum + lab.l * v
        aSum = aSum + lab.a * v
        bSum = bSum + lab.b * v
        alphaSum = alphaSum + lab.alpha * v
        count = count + v
    end

    if alphaSum > 0 and count > 0 then
        local countInv = 1.0 / count
        local alphaAvg = alphaSum * countInv
        local lAvg = lSum * countInv
        local aAvg = aSum * countInv
        local bAvg = bSum * countInv

        local lch = defaults.labToLch(lAvg, aAvg, bAvg, alphaAvg)

        active.l = lch.l
        active.c = lch.c
        active.h = lch.h
        active.a = lch.a

        dialog:repaint()
        updateHexCode(dialog, active.l, active.c, active.h)
    end
    app.refresh()
end

local dlg = Dialog { title = "LCH Color Picker" }

local function setAlphaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx01 = event.x / (bw - 1.0)
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

local function setLightMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx100 = 100.0 * event.x / (bw - 1.0)
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

local function setChromaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mc = defaults.maxChroma
        local mx135 = mc * event.x / (bw - 1.0)
        if event.ctrlKey then
            local inGamutEps = defaults.inGamutEps
            local incr = 1.0

            local isInGamut = Clr.rgbIsInGamut
            local lchTosRgb = defaults.lchTosRgb

            local l = active.l
            local c = 0.0
            local h = active.h
            local a = active.a
            local clr = nil

            repeat
                c = c + incr
                clr = lchTosRgb(l, c, h, a)
            until (not isInGamut(clr, inGamutEps))
            active.c = c
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx135 - active.c) > incr then
                if mx135 < active.c then incr = -incr end
                active.c = math.min(math.max(
                    active.c + incr, 0.0), mc)
            end
        else
            active.c = math.min(math.max(mx135, 0.0), mc)
        end
        dlg:repaint()
        updateHexCode(dlg, active.l, active.c, active.h)
    end
end

local function setHueMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx01 = event.x / (bw - 1.0)
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
        if app.activeSprite then
            setFromAse(dlg, app.fgColor)
        end
    end
}

dlg:button {
    id = "bgGet",
    text = "B&ACK",
    focus = false,
    onclick = function()
        if app.activeSprite then
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
        setFromSelect(dlg,
            app.activeSprite,
            app.activeFrame)
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "hexCode",
    label = "#:",
    text = defaults.hexCode,
    focus = false,
    onchange = function()
        local args = dlg.data
        local hexStr = args.hexCode --[[@as string]]
        -- if #hexStr > 5 then
        local srgb = Clr.fromHexWeb(hexStr)
        local lch = defaults.sRgbToLch(srgb)
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
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local textColor = defaults.textColor
        local textShadow = defaults.textShadow

        -- Unpack active.
        local l = active.l
        local c = active.c
        local h = active.h
        local a = active.a

        -- Manual alpha blend with theme bkg.
        local bkgColor = app.theme.color.window_face
        local bkgClr = AseUtilities.aseColorToClr(bkgColor)
        local srgb = defaults.lchTosRgb(l, c, h, 1.0)
        local alphaMix = Clr.mix(bkgClr, srgb, a)
        local srgbHex = Clr.toHex(alphaMix)

        -- Fill image with color.
        local ctx = event.context
        local bkgImg = Image(barWidth, barHeight)
        bkgImg:clear(srgbHex)
        ctx:drawImage(bkgImg, 0, 0)

        -- Create display string.
        local strDisplay = string.format(
            "L:%03d C:%03d H:%03d A:%03d",
            math.floor(l + 0.5),
            math.floor(c + 0.5),
            math.floor(h * 360.0 + 0.5),
            math.floor(a * 255.0 + 0.5))
        local strMeasure = ctx:measureText(strDisplay)

        -- Flip text colors for bright colors.
        if l < 54.0 then
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
    id = "lightCanvas",
    label = "L:",
    width = defaults.barWidth,
    height = defaults.barheight,
    autoScaling = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor = app.theme.color.window_face
        local bkgHex = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local inGamutEps = defaults.inGamutEps
        local reticleSize = defaults.reticleSize

        -- Unpack active.
        local l = active.l
        local c = active.c
        local h = active.h

        -- Cache methods.
        local lchTosRgb = defaults.lchTosRgb
        local isInGamut = Clr.rgbIsInGamut
        local toHex = Clr.toHex

        local xToLight = 100.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xLight = pixel.x * xToLight
            local srgb = lchTosRgb(xLight, c, h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

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
        local bkgColor = app.theme.color.window_face
        local bkgHex = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local inGamutEps = defaults.inGamutEps
        local maxChroma = defaults.maxChroma
        local reticleSize = defaults.reticleSize

        -- Unpack active.
        local l = active.l
        local c = active.c
        local h = active.h

        -- Cache methods.
        local lchTosRgb = defaults.lchTosRgb
        local isInGamut = Clr.rgbIsInGamut
        local toHex = Clr.toHex

        local xToChroma = maxChroma / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xChroma = pixel.x * xToChroma
            local srgb = lchTosRgb(l, xChroma, h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

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
        local bkgColor = app.theme.color.window_face
        local bkgHex = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local inGamutEps = defaults.inGamutEps
        local reticleSize = defaults.reticleSize

        -- Unpack active.
        local l = active.l
        local c = active.c
        local h = active.h

        -- Cache methods.
        local lchTosRgb = defaults.lchTosRgb
        local isInGamut = Clr.rgbIsInGamut
        local toHex = Clr.toHex

        local xToHue = 1.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xHue = pixel.x * xToHue
            local srgb = lchTosRgb(l, c, xHue, 1.0)
            if isInGamut(srgb, inGamutEps) then
                pixel(toHex(srgb))
            else
                pixel(bkgHex)
            end
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

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
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        local bkgColor = app.theme.color.window_face
        local bBkg = bkgColor.blue * 0.003921568627451
        local gBkg = bkgColor.green * 0.003921568627451
        local rBkg = bkgColor.red * 0.003921568627451

        local l = active.l
        local c = active.c
        local h = active.h
        local a = active.a

        local srgb = defaults.lchTosRgb(l, c, h, a)
        srgb = Clr.clamp01(srgb)
        local rTrg = srgb.r
        local gTrg = srgb.g
        local bTrg = srgb.b

        local floor = math.floor
        local xToFac = 1.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local t = pixel.x * xToFac
            local u = 1.0 - t

            local b = floor((u * bBkg + t * bTrg) * 255 + 0.5)
            local g = floor((u * gBkg + t * gTrg) * 255 + 0.5)
            local r = floor((u * rBkg + t * rTrg) * 255 + 0.5)

            pixel(0xff000000 | b << 0x10 | g << 0x08 | r)
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

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
        local sprite = app.activeSprite
        if not sprite then return end

        local sprSpec = sprite.spec
        local colorMode = sprSpec.colorMode

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        local srgb = defaults.lchTosRgb(
            active.l, active.c, active.h, active.a)
        local aseColor = AseUtilities.clrToAseColor(srgb)
        local hex = AseUtilities.aseColorToHex(aseColor, colorMode)

        local sel = AseUtilities.getSelection(sprite)
        local selBounds = sel.bounds
        local xSel = selBounds.x
        local ySel = selBounds.y

        local selSpec = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = colorMode,
            transparentColor = sprSpec.transparentColor
        }
        selSpec.colorSpace = sprSpec.colorSpace
        local selImage = Image(selSpec)
        local pxItr = selImage:pixels()

        for pixel in pxItr do
            local x = pixel.x + xSel
            local y = pixel.y + ySel
            if sel:contains(x, y) then
                pixel(hex)
            end
        end

        app.transaction("Set Selection", function()
            -- This is an extra precaution because creating
            -- a new layer wipes out a range.
            local tlHidden = not app.preferences.general.visible_timeline
            if tlHidden then
                app.command.Timeline { open = true }
            end

            local frameIdcs = { app.activeFrame.frameNumber }
            local appRange = app.range
            if appRange.sprite == sprite then
                frameIdcs = AseUtilities.frameObjsToIdcs(appRange.frames)
            end

            if tlHidden then
                app.command.Timeline { close = true }
            end

            local lenFrames = #frameIdcs
            local sprFrames = sprite.frames
            local layer = sprite:newLayer()
            local tlSel = Point(xSel, ySel)
            layer.name = "Selection"
            local i = 0
            while i < lenFrames do
                i = i + 1
                local frameIdx = frameIdcs[i]
                local frameObj = sprFrames[frameIdx]
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
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local inGamutEps = defaults.inGamutEps

        -- Unpack dialog arguments.
        local args = dlg.data
        local harmonyType = args.harmonyType --[[@as string]]

        local l = active.l
        local c = active.c
        local h = active.h
        local a = active.a

        -- RYB wheel color theory based on the idea that
        -- 180 degrees from key color is also opposite light,
        -- e.g., dark violet is opposite bright yellow.
        -- (060.0 / 180.0) * l + (120.0 / 180.0) * (100.0 - l)
        -- (150.0 / 180.0) * l + (030.0 / 180.0) * (100.0 - l)
        -- (030.0 / 180.0) * l + (150.0 / 180.0) * (100.0 - l)
        local swatches = {}
        if harmonyType == "ANALOGOUS" then
            local lAna = (l + l + 50.0) / 3.0
            local h30 = 0.08333333333333
            swatches[1] = { l = lAna, c = c, h = (h + h30) % 1.0, a = a }
            swatches[2] = { l = lAna, c = c, h = (h - h30) % 1.0, a = a }
        elseif harmonyType == "COMPLEMENT" then
            swatches[1] = { l = 100.0 - l, c = c, h = (h + 0.5) % 1.0, a = a }
        elseif harmonyType == "SPLIT" then
            local lSpl = (250.0 - (l + l)) / 3.0
            local h150 = 0.41666666666667
            swatches[1] = { l = lSpl, c = c, h = (h + h150) % 1.0, a = a }
            swatches[2] = { l = lSpl, c = c, h = (h - h150) % 1.0, a = a }
        elseif harmonyType == "SQUARE" then
            swatches[1] = { l = 50.0, c = c, h = (h + 0.25) % 1.0, a = a }
            swatches[2] = { l = 100.0 - l, c = c, h = (h + 0.5) % 1.0, a = a }
            swatches[3] = { l = 50.0, c = c, h = (h - 0.25) % 1.0, a = a }
        elseif harmonyType == "TRIADIC" then
            local lTri = (200.0 - l) / 3.0
            local h120 = 0.3333333333333333
            swatches[1] = { l = lTri, c = c, h = (h + h120) % 1.0, a = a }
            swatches[2] = { l = lTri, c = c, h = (h - h120) % 1.0, a = a }
        else
            -- Unpack shading specific defaults.
            local shadeCount = defaults.shadeCount
            local hueSpreadShd = defaults.hueSpreadShd
            local hueSpreadLgt = defaults.hueSpreadLgt
            local chromaSpreadShd = defaults.chromaSpreadShd
            local chromaSpreadLgt = defaults.chromaSpreadLgt
            local lightSpread = defaults.lightSpread
            local hYellow = defaults.hYellow
            local hViolet = defaults.hViolet

            local minLight = math.max(0.0, l - lightSpread)
            local maxLight = math.min(100.0, l + lightSpread)
            local minChromaShd = math.max(0.0, c - chromaSpreadShd)
            local minChromaLgt = math.max(0.0, c - chromaSpreadLgt)
            local toShdFac = math.abs(50.0 - minLight) * 0.02
            local toLgtFac = math.abs(50.0 - maxLight) * 0.02

            local shdHue = Utilities.lerpAngleNear(h, hViolet, hueSpreadShd * toShdFac, 1.0)
            local lgtHue = Utilities.lerpAngleNear(h, hYellow, hueSpreadLgt * toLgtFac, 1.0)

            local shdCrm = (1.0 - toShdFac) * c + minChromaShd * toShdFac
            local lgtCrm = (1.0 - toLgtFac) * c + minChromaLgt * toLgtFac

            local labShd = defaults.lchToLab(minLight, shdCrm, shdHue, 1.0, 0.5)
            local labKey = defaults.lchToLab(l, c, h, 1.0, 0.5)
            local labLgt = defaults.lchToLab(maxLight, lgtCrm, lgtHue, 1.0, 0.5)

            local pt0 = Vec3.new(labShd.a, labShd.b, labShd.l)
            local pt1 = Vec3.new(labKey.a, labKey.b, labKey.l)
            local pt2 = Vec3.new(labLgt.a, labLgt.b, labLgt.l)

            local kn0 = Knot3.new(
                pt0, pt1, Vec3.new(0.0, 0.0, 0.0))
            local kn1 = Knot3.new(
                pt2, Vec3.new(0.0, 0.0, 0.0), pt1)
            kn0:mirrorHandlesForward()
            kn1:mirrorHandlesBackward()

            local eval = Curve3.eval
            local labToLch = defaults.labToLch
            local curve = Curve3.new(false, { kn0, kn1 }, "Shades")
            local toFac = 1.0
            if shadeCount > 1 then
                toFac = 1.0 / (shadeCount - 1.0)
            end
            local i = 0
            while i < shadeCount do
                local v = eval(curve, i * toFac)
                i = i + 1
                swatches[i] = labToLch(v.z, v.x, v.y, a)
            end
        end
        active.swatches = swatches

        -- Display.
        local lenSwatches = #swatches
        local wsw = math.floor(barWidth / lenSwatches + 0.5)
        local hsw = barHeight
        local ctx = event.context
        local swatchRect = Rectangle(0, 0, wsw, hsw)

        local lchTosRgb = defaults.lchTosRgb
        local isInGamut = Clr.rgbIsInGamut
        local clrToAseColor = AseUtilities.clrToAseColor

        local j = 0
        while j < lenSwatches do
            swatchRect.x = j * wsw
            j = j + 1
            local swatch = swatches[j]
            local srgb = lchTosRgb(swatch.l, swatch.c, swatch.h, 1.0)
            if isInGamut(srgb, inGamutEps) then
                ctx.color = clrToAseColor(srgb)
                ctx:fillRect(swatchRect)
            end
        end
    end,
    onmouseup = function(event)
        local x = event.x
        local fac = x / (defaults.barWidth - 1.0)
        local swatches = active.swatches
        local lenSwatches = #swatches

        local idx = 0
        if fac <= 0.0 then
            idx = 0
        elseif fac >= 1.0 then
            idx = lenSwatches - 1
        else
            idx = math.floor(fac * lenSwatches)
        end

        local swatch = swatches[1 + idx]
        if event.shiftKey then
            local srgb = defaults.lchTosRgb(
                swatch.l, swatch.c, swatch.h, swatch.a)
            local aseColor = AseUtilities.clrToAseColor(srgb)
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