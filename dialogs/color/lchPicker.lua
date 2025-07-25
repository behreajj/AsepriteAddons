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
    -- TODO: Make LCH sliders into a child dialog that pops up when
    -- a canvas representing a custom color widget is clicked. That
    -- way it can be used by color select and replace dialogs. Then
    -- make this a color wheel picker similar to Okhsl?

    -- TODO: Make backgrounds for colors with alpha consistent
    -- with gradient utilities UI.

    -- This does not support scroll wheel because the directionality
    -- is reversed and because there is too much debugging needed
    -- to stop mouse down from interfering with scroll wheel,
    -- particularly in normal wheel picker I.e., scroll wheel should
    -- only work when mouse button is up. That means separate
    -- functions would need to be made for scroll.
    lchTosRgb = ColorUtilities.srLchTosRgbInternal,
    labTosRgb = ColorUtilities.srLab2TosRgb,
    sRgbToLch = ColorUtilities.sRgbToSrLchInternal,
    sRgbToLab = ColorUtilities.sRgbToSrLab2Internal,
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
    chromaSpreadLgt = 12.5,
    lightSpread = 33.33,
    lIncrScale = 5,
    cIncrScale = 10,
    hIncrScale = 15,
    tIncrScale = 16
}

local active <const> = {
    l = 50.0,
    c = 30.0,
    h = 0.0,
    a = 1.0,
    lBarWidth = defaults.barWidth,
    cBarWidth = defaults.barWidth,
    hBarWidth = defaults.barWidth,
    aBarWidth = defaults.barWidth,
    swatchesWidth = defaults.barWidth,
    swatches = {}
}

local function assignFore()
    -- Ideally, if palette is unlocked, and color in palette at index is
    -- exact match of the fg/bg color, then set the palette at index.
    if app.site.sprite then
        local srgb <const> = defaults.lchTosRgb(
            active.l, active.c, active.h, active.a)
        app.fgColor = AseUtilities.rgbToAseColor(srgb)
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
    local str <const> = Rgb.toHexWeb(srgb)
    dialog:modify { id = "hexCode", text = str }
    return str
end

---@param dialog Dialog
---@param aseColor Color
local function setFromAse(dialog, aseColor)
    local srgb <const> = AseUtilities.aseColorToRgb(aseColor)
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
---@param frIdx integer
local function setFromSelect(dialog, sprite, frIdx)
    local lab <const> = AseUtilities.averageColor(sprite, frIdx)
    if lab.alpha > 0.0 then
        -- Average color uses SR LAB 2.
        local lch <const> = Lab.toLch(lab)

        active.l = lch.l
        active.c = lch.c
        active.h = lch.h
        active.a = lch.a

        dialog:repaint()
        updateHexCode(dialog, active.l, active.c, active.h)
    end
end

local dlg <const> = Dialog { title = "LCH Color Picker " }

---@param event MouseEvent
local function setAlphaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.aBarWidth
        local mx01 <const> = bw > 1
            and (event.x / (bw - 1.0))
            or 0.0
        if event.ctrlKey then
            active.a = 1.0
        elseif event.shiftKey then
            local incr = 0.003921568627451
            if math.abs(mx01 - active.a) > incr then
                if event.altKey then incr = incr * defaults.tIncrScale end
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
        local bw <const> = active.lBarWidth
        local mx100 <const> = bw > 1
            and (100.0 * event.x / (bw - 1.0))
            or 0.0
        if event.ctrlKey then
            active.l = 50.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx100 - active.l) > incr then
                if event.altKey then incr = incr * defaults.lIncrScale end
                if mx100 < active.l then incr = -incr end
                active.l = math.min(math.max(
                    active.l + incr, 0.0), 100.0)
            end
        else
            active.l = math.min(math.max(mx100, 0.0), 100.0)
        end
        dlg:repaint()

        -- TODO: This poses the biggest problem for abstracting these methods
        -- into a CanvasUtilities method.
        updateHexCode(dlg, active.l, active.c, active.h)
    end
end

---@param event MouseEvent
local function setChromaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.cBarWidth
        local maxChroma <const> = Lab.SR_MAX_CHROMA + 0.5
        local mx120 <const> = bw > 1
            and (maxChroma * event.x / (bw - 1.0))
            or 0.0
        if event.ctrlKey then
            local inGamutEps <const> = defaults.inGamutEps
            local incr <const> = 1.0

            local isInGamut <const> = Rgb.rgbIsInGamut
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
                if event.altKey then incr = incr * defaults.cIncrScale end
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
        local bw <const> = active.hBarWidth
        local mx01 <const> = bw > 1
            and (event.x / (bw - 1.0))
            or 0.0
        if event.ctrlKey then
            active.h = 0.0
        elseif event.shiftKey then
            local incr = 0.0027777777777778
            if math.abs(mx01 - active.h) > incr then
                if event.altKey then incr = incr * defaults.hIncrScale end
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
        local site <const> = app.site
        local sprite <const> = site.sprite
        local frObj <const> = site.frame
        if sprite and frObj then
            setFromSelect(dlg, sprite, frObj.frameNumber)
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

        -- Because the spacebar can be used as a function key similar to
        -- Shift, Ctrl and Alt, there's a risk of spaces being
        -- introduced by accident.
        local srgb <const> = Rgb.fromHexWeb(hexStr)
        local lch <const> = defaults.sRgbToLch(srgb)
        active.l = lch.l
        active.c = lch.c
        active.h = lch.h
        dlg:repaint()
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
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h
        local a <const> = active.a

        -- Manual alpha blend with theme bkg.
        local bkgColor <const> = app.theme.color.window_face
        local bkgClr <const> = AseUtilities.aseColorToRgb(bkgColor)
        local srgb <const> = defaults.lchTosRgb(l, c, h, 1.0)
        local alphaMix <const> = Rgb.mix(bkgClr, srgb, a)
        local srgbHex <const> = Rgb.toHex(alphaMix)

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
            "L:%03d C:%03d H:%03d A:%03d",
            math.floor(l + 0.5),
            math.floor(c + 0.5),
            math.floor(h * 360.0 + 0.5),
            math.floor(a * 255.0 + 0.5))

        -- Flip text colors for bright colors.
        if l < 54.0 then
            textShadow, textColor = textColor, textShadow
        end

        local wBarCenter <const> = barWidth * 0.5
        local hBarCenter <const> = barHeight * 0.5
        local strMeasure <const> = ctx:measureText(strDisplay)
        local wStrHalf <const> = strMeasure.width * 0.5
        local hStrHalf <const> = strMeasure.height * 0.5
        local xTextCenter <const> = math.floor(wBarCenter - wStrHalf)
        local yTextCenter <const> = math.floor(hBarCenter - hStrHalf)

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        ctx.color = AseUtilities.hexToAseColor(textShadow)
        ctx:fillText(strDisplay, xTextCenter + 1, yTextCenter + 1)
        ctx.color = AseUtilities.hexToAseColor(textColor)
        ctx:fillText(strDisplay, xTextCenter, yTextCenter)
    end,
    onmouseup = function(event)
        local button <const> = event.button
        local leftPressed <const> = button == MouseButton.LEFT
        local rightPressed <const> = button == MouseButton.RIGHT
        local ctrlKey <const> = event.ctrlKey

        -- TODO: It'd be nice to append to palette directly, both
        -- here and for harmony swatches. However, space bar cannot
        -- be used, since it opens combo box widget menus and
        -- adds superfluous spaces to text entry widgets.
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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local inGamutEps <const> = defaults.inGamutEps
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Rgb.rgbIsInGamut
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.lBarWidth = barWidth

        local xToLight <const> = barWidth > 1
            and 100.0 / (barWidth - 1.0)
            or 0.0

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xLight <const> = i * xToLight
            local srgb <const> = lchTosRgb(xLight, c, h, 1.0)
            local hex <const> = isInGamut(srgb, inGamutEps)
                and toHex(srgb)
                or bkgHex
            bytes[1 + i] = strpack("<I4", hex)
            i = i + 1
        end

        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill <const> = l < 54.0
            and Color { r = 255, g = 255, b = 255 }
            or Color { r = 0, g = 0, b = 0 }
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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local inGamutEps <const> = defaults.inGamutEps
        local maxChroma <const> = Lab.SR_MAX_CHROMA + 0.5
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Rgb.rgbIsInGamut
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.cBarWidth = barWidth

        local xToChroma <const> = barWidth > 1
            and maxChroma / (barWidth - 1.0)
            or 0.0

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xChroma <const> = i * xToChroma
            local srgb <const> = lchTosRgb(l, xChroma, h, 1.0)
            local hex <const> = isInGamut(srgb, inGamutEps)
                and toHex(srgb)
                or bkgHex
            bytes[1 + i] = strpack("<I4", hex)
            i = i + 1
        end

        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill <const> = l < 54.0
            and Color { r = 255, g = 255, b = 255 }
            or Color { r = 0, g = 0, b = 0 }
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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        -- Unpack theme.
        local bkgColor <const> = app.theme.color.window_face
        local bkgHex <const> = AseUtilities.aseColorToHex(
            bkgColor, ColorMode.RGB)

        -- Unpack defaults.
        local inGamutEps <const> = defaults.inGamutEps
        local reticleSize <const> = defaults.reticleSize

        -- Unpack active.
        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h

        -- Cache methods.
        local lchTosRgb <const> = defaults.lchTosRgb
        local isInGamut <const> = Rgb.rgbIsInGamut
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.hBarWidth = barWidth

        local xToHue <const> = barWidth > 1
            and 1.0 / (barWidth - 1.0)
            or 0.0

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xHue <const> = i * xToHue
            local srgb <const> = lchTosRgb(l, c, xHue, 1.0)
            local hex <const> = isInGamut(srgb, inGamutEps)
                and toHex(srgb)
                or bkgHex
            bytes[1 + i] = strpack("<I4", hex)
            i = i + 1
        end

        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill <const> = l < 54.0
            and Color { r = 255, g = 255, b = 255 }
            or Color { r = 0, g = 0, b = 0 }
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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.aBarWidth = barWidth

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
        srgb = Rgb.clamp01(srgb)
        local rTrg <const> = srgb.r
        local gTrg <const> = srgb.g
        local bTrg <const> = srgb.b

        local floor <const> = math.floor
        local strpack <const> = string.pack
        local xToFac <const> = barWidth > 1
            and 1.0 / (barWidth - 1.0)
            or 0.0
        local img <const> = Image(barWidth, 1, ColorMode.RGB)

        ---@type string[]
        local bytesArr <const> = {}
        local i = 0
        while i < barWidth do
            local t <const> = i * xToFac
            local u <const> = 1.0 - t

            local r <const> = floor((u * rBkg + t * rTrg) * 255 + 0.5)
            local g <const> = floor((u * gBkg + t * gTrg) * 255 + 0.5)
            local b <const> = floor((u * bBkg + t * bTrg) * 255 + 0.5)

            i = i + 1
            bytesArr[i] = strpack("B B B B", r, g, b, 255)
        end
        img.bytes = table.concat(bytesArr)

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local fill <const> = l < 54.0
            and Color { r = 255, g = 255, b = 255 }
            or Color { r = 0, g = 0, b = 0 }
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
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end

        local sprSpec <const> = sprite.spec
        local colorMode <const> = sprSpec.colorMode

        -- Use Aseprite color as an intermediary so as
        -- to support all color modes.
        local srgb <const> = defaults.lchTosRgb(
            active.l, active.c, active.h, active.a)
        local aseColor <const> = AseUtilities.rgbToAseColor(srgb)
        local hex <const> = AseUtilities.aseColorToHex(aseColor, colorMode)

        local sel <const>, _ <const> = AseUtilities.getSelection(sprite)
        local selBounds <const> = sel.bounds
        local xSel <const> = selBounds.x
        local ySel <const> = selBounds.y
        local wSel <const> = selBounds.width
        local hSel <const> = selBounds.height

        local alphaIndex <const> = sprSpec.transparentColor
        local alphaIndexVerif <const> = (colorMode ~= ColorMode.INDEXED
                or (alphaIndex >= 0 and alphaIndex < 256))
            and alphaIndex or 0

        local selSpec <const> = AseUtilities.createSpec(wSel, hSel,
            colorMode, sprSpec.colorSpace, alphaIndex)
        local selImage <const> = Image(selSpec)
        local selBpp <const> = selImage.bytesPerPixel
        local selFmt <const> = "<I" .. selBpp

        ---@type string[]
        local byteStrArr <const> = {}
        local strpack <const> = string.pack
        local areaSel <const> = wSel * hSel
        local h = 0
        while h < areaSel do
            local trg = alphaIndexVerif
            if sel:contains(xSel + h % wSel, ySel + h // wSel) then
                trg = hex
            end
            h = h + 1
            byteStrArr[h] = strpack(selFmt, trg)
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
                sprite:newCel(layer, frIdcs[i], selImage, tlSel)
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
    vexpand = false,
    onpaint = function(event)
        -- Unpack defaults.
        local inGamutEps <const> = defaults.inGamutEps

        -- Unpack dialog arguments.
        local args <const> = dlg.data
        local harmonyType <const> = args.harmonyType --[[@as string]]

        local l <const> = active.l
        local c <const> = active.c
        local h <const> = active.h
        local a <const> = active.a
        local labKey <const> = Lab.fromLch(l, c, h, 1.0, 0.5)

        ---@type Lab[]
        local swatches = {}
        if harmonyType == "ANALOGOUS" then
            swatches = Lab.harmonyAnalogous(labKey)
        elseif harmonyType == "COMPLEMENT" then
            swatches = Lab.harmonyComplement(labKey)
        elseif harmonyType == "SPLIT" then
            swatches = Lab.harmonySplit(labKey)
        elseif harmonyType == "SQUARE" then
            swatches = Lab.harmonySquare(labKey)
        elseif harmonyType == "TETRADIC" then
            swatches = Lab.harmonyTetradic(labKey)
        elseif harmonyType == "TRIADIC" then
            swatches = Lab.harmonyTriadic(labKey)
        else
            -- Unpack shading specific defaults.
            local shadeCount <const> = defaults.shadeCount
            local hueSpreadShd <const> = defaults.hueSpreadShd
            local hueSpreadLgt <const> = defaults.hueSpreadLgt
            local chromaSpreadShd <const> = defaults.chromaSpreadShd
            local chromaSpreadLgt <const> = defaults.chromaSpreadLgt
            local lightSpread <const> = defaults.lightSpread
            local hYellow <const> = Lab.SR_HUE_LIGHT
            local hViolet <const> = Lab.SR_HUE_SHADOW

            local minLight <const> = math.max(0.0, l - lightSpread)
            local maxLight <const> = math.min(100.0, l + lightSpread)
            local minChromaShd <const> = math.max(0.0, c - chromaSpreadShd)
            local minChromaLgt <const> = math.max(0.0, c - chromaSpreadLgt)
            local toShdFac <const> = math.abs(50.0 - minLight) * 0.02
            local toLgtFac <const> = math.abs(50.0 - maxLight) * 0.02

            local shdHue <const> = Utilities.lerpAngleNear(
                h, hViolet, hueSpreadShd * toShdFac, 1.0)
            local lgtHue <const> = Utilities.lerpAngleNear(
                h, hYellow, hueSpreadLgt * toLgtFac, 1.0)

            local shdCrm <const> = (1.0 - toShdFac) * c
                + toShdFac * minChromaShd
            local lgtCrm <const> = (1.0 - toLgtFac) * c
                + toLgtFac * minChromaLgt

            local labShd <const> = Lab.fromLch(minLight, shdCrm, shdHue, 1.0, 0.5)
            local labLgt <const> = Lab.fromLch(maxLight, lgtCrm, lgtHue, 1.0, 0.5)

            local pt0 <const> = Vec3.new(labShd.a, labShd.b, labShd.l)
            local pt1 <const> = Vec3.new(labKey.a, labKey.b, labKey.l)
            local pt2 <const> = Vec3.new(labLgt.a, labLgt.b, labLgt.l)

            local kn0 <const> = Knot3.new(
                pt0, pt1, Vec3.new(0.0, 0.0, 0.0))
            local kn1 <const> = Knot3.new(
                pt2, Vec3.new(0.0, 0.0, 0.0), pt1)
            kn0:mirrorHandlesForward()
            kn1:mirrorHandlesBackward()

            local curve <const> = Curve3.new(false, { kn0, kn1 }, "Shades")
            local toFac <const> = shadeCount > 1
                and 1.0 / (shadeCount - 1.0)
                or 1.0

            local i = 0
            while i < shadeCount do
                local v <const> = Curve3.eval(curve, i * toFac)
                i = i + 1
                swatches[i] = Lab.new(v.z, v.x, v.y, 1.0)
            end
        end
        active.swatches = swatches

        -- Display.
        local lenSwatches <const> = #swatches

        local ctx <const> = event.context
        ctx.blendMode = BlendMode.SRC
        ctx.antialias = false

        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.swatchesWidth = barWidth

        local wsw <const> = math.floor(barWidth / lenSwatches + 0.5)
        local hsw <const> = barHeight
        local swatchRect <const> = Rectangle(0, 0, wsw, hsw)

        local labTosRgb <const> = defaults.labTosRgb
        local isInGamut <const> = Rgb.rgbIsInGamut
        local clrToAseColor <const> = AseUtilities.rgbToAseColor

        local j = 0
        while j < lenSwatches do
            swatchRect.x = j * wsw
            j = j + 1
            local swatch <const> = swatches[j]
            local srgb <const> = labTosRgb(swatch)
            if isInGamut(srgb, inGamutEps) then
                ctx.color = clrToAseColor(srgb)
                ctx:fillRect(swatchRect)
            end
        end
    end,
    onmouseup = function(event)
        local fac <const> = event.x / (active.swatchesWidth - 1.0)
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
            local srgb <const> = defaults.labTosRgb(swatch)
            srgb.a = active.a
            local aseColor <const> = AseUtilities.rgbToAseColor(srgb)
            if event.button == MouseButton.RIGHT
                or event.ctrlKey then
                app.command.SwitchColors()
                app.fgColor = aseColor
                app.command.SwitchColors()
            else
                app.fgColor = aseColor
            end
        else
            local swatchLch <const> = Lab.toLch(swatch)
            active.l = swatchLch.l
            active.c = swatchLch.c
            active.h = swatchLch.h
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
    hexpand = false,
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
dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    16, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)