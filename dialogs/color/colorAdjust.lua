dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale <const> = app.preferences.general.screen_scale

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = { "LAB", "LCH" }

local defaults <const> = {
    -- Note: standardization is not the same as normalization.
    -- For standardization, a range's average must be found,
    -- then its standard deviation must be found:
    -- sqrt ( sum( ( arr[i] - mean ) ^ 2 / len ) )
    -- Then each element must be recalculated:
    -- elm[i]' = (elm[i] - mean) / std .
    target = "ACTIVE",
    mode = "LCH",
    contrast = 0,
    normalize = 0,
    lInvert = false,
    aInvert = false,
    bInvert = false,
    alphaInvert = false,
    pullFocus = false,
    barWidth = 240 / screenScale,
    barHeight = 16 / screenScale,
    reticleSize = 3 / screenScale,
    labAxisMin = -220.0,
    labAxisMax = 220.0,
    labVisMin = -80.0,
    labVisMax = 80.0,
    maxChroma = 135.0
}

local active <const> = {
    lAdj = 0.0,
    cAdj = 0.0,
    hAdj = 0.5,
    aAdj = 0.0,
    bAdj = 0.0,
    alphaAdj = 0.0,
    lBarWidth = defaults.barWidth,
    cBarWidth = defaults.barWidth,
    hBarWidth = defaults.barWidth,
    aBarWidth = defaults.barWidth,
    bBarWidth = defaults.barWidth,
    tBarWidth = defaults.barWidth,
}

local dlg <const> = Dialog { title = "Adjust Color" }

---@param event MouseEvent
local function setLightMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.lBarWidth
        local mx100 <const> = 200.0 * event.x / (bw - 1.0) - 100.0
        if event.ctrlKey then
            active.lAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx100 - active.lAdj) > incr then
                if mx100 < active.lAdj then incr = -incr end
                active.lAdj = math.min(math.max(
                    active.lAdj + incr, -100.0), 100.0)
            end
        else
            active.lAdj = math.min(math.max(
                mx100, -100.0), 100.0)
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setChromaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.cBarWidth
        local clb <const> = -defaults.maxChroma
        local cub <const> = defaults.maxChroma
        local mx01 <const> = event.x / (bw - 1.0)
        local mxc <const> = (1.0 - mx01) * clb + mx01 * cub
        if event.ctrlKey then
            active.cAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxc - active.cAdj) > incr then
                if mxc < active.cAdj then incr = -incr end
                active.cAdj = math.min(math.max(
                    active.cAdj + incr, clb), cub)
            end
        else
            active.cAdj = math.min(math.max(
                mxc, clb), cub)
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setHueMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.hBarWidth
        local mx01 <const> = event.x / (bw - 1.0)
        if event.ctrlKey then
            active.hAdj = 0.5
        elseif event.shiftKey then
            local incr = 0.0027777777777778
            if math.abs(mx01 - active.hAdj) > incr then
                if mx01 < active.hAdj then incr = -incr end
                active.hAdj = (active.hAdj + incr) % 1.0
            end
        else
            active.hAdj = mx01 % 1.0
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setAMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.aBarWidth
        local alb <const> = defaults.labAxisMin
        local aub <const> = defaults.labAxisMax
        local mx01 <const> = event.x / (bw - 1.0)
        local mxa <const> = (1.0 - mx01) * alb + mx01 * aub
        if event.ctrlKey then
            active.aAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxa - active.aAdj) > incr then
                if mxa < active.aAdj then incr = -incr end
                active.aAdj = math.min(math.max(
                    active.aAdj + incr, alb), aub)
            end
        else
            active.aAdj = math.min(math.max(
                mxa, alb), aub)
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setBMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.bBarWidth
        local blb <const> = defaults.labAxisMin
        local bub <const> = defaults.labAxisMax
        local mx01 <const> = event.x / (bw - 1.0)
        local mxb <const> = (1.0 - mx01) * blb + mx01 * bub
        if event.ctrlKey then
            active.bAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxb - active.bAdj) > incr then
                if mxb < active.bAdj then incr = -incr end
                active.bAdj = math.min(math.max(
                    active.bAdj + incr, blb), bub)
            end
        else
            active.bAdj = math.min(math.max(
                mxb, blb), bub)
        end
        dlg:repaint()
    end
end

---@param event MouseEvent
local function setAlphaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw <const> = active.tBarWidth
        local mx01 <const> = event.x / (bw - 1.0)
        local mxalpha <const> = mx01 + mx01 - 1.0
        if event.ctrlKey then
            active.alphaAdj = 0.0
        elseif event.shiftKey then
            local incr = 0.003921568627451
            if math.abs(mxalpha - active.alphaAdj) > incr then
                if mxalpha < active.alphaAdj then incr = -incr end
                active.alphaAdj = math.min(math.max(
                    active.alphaAdj + incr, -1.0), 1.0)
            end
        else
            active.alphaAdj = math.min(math.max(
                mxalpha, -1.0), 1.0)
        end
        dlg:repaint()
    end
end

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "normalize",
    label = "Normalize:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.normalize
}

dlg:newrow { always = false }

dlg:slider {
    id = "contrast",
    label = "Contrast:",
    focus = false,
    min = -100,
    max = 100,
    value = defaults.contrast
}

dlg:separator { id = "adjustSep" }

dlg:combobox {
    id = "mode",
    label = "Adjust:",
    focus = false,
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local isLch <const> = mode == "LCH"
        local isLab <const> = mode == "LAB"
        dlg:modify { id = "cAdjCanvas", visible = isLch }
        dlg:modify { id = "hAdjCanvas", visible = isLch }
        dlg:modify { id = "aAdjCanvas", visible = isLab }
        dlg:modify { id = "bAdjCanvas", visible = isLab }
    end
}

dlg:newrow { always = false }

dlg:canvas {
    id = "lAdjCanvas",
    label = "L:",
    width = defaults.barWidth,
    height = defaults.barheight,
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize

        -- The problem with coloring the light bar is that
        -- it is visible in both LAB and LCH mode.
        -- local c = 50.0
        -- local h = active.hAdj - 0.5
        local lchTosRgb <const> = Clr.srLchTosRgb
        local toHex <const> = Clr.toHex

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.lBarWidth = barWidth

        local xToLight <const> = 100.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xLight <const> = pixel.x * xToLight
            pixel(toHex(lchTosRgb(xLight, 0.0, 0.0, 1.0)))
        end

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local lAdj <const> = active.lAdj
        local l01 <const> = lAdj * 0.005 + 0.5
        local black <const> = Color { r = 0, g = 0, b = 0 }
        local white <const> = Color { r = 255, g = 255, b = 255 }
        local fill = black
        if lAdj < 0.0 then
            fill = white
        end
        CanvasUtilities.drawSliderReticle(
            ctx, l01, barWidth, barHeight,
            fill, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.lAdj))
        ctx.color = black
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = white
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setLightMouseListen,
    onmousemove = setLightMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "cAdjCanvas",
    label = "C:",
    width = defaults.barWidth,
    height = defaults.barheight,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local clb <const> = -defaults.maxChroma
        local cub <const> = defaults.maxChroma

        local h <const> = active.hAdj - 0.5
        local lchTosRgb <const> = Clr.srLchTosRgb
        local toHex <const> = Clr.toHex

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.cBarWidth = barWidth

        local xToChroma <const> = cub / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local c <const> = pixel.x * xToChroma
            pixel(toHex(lchTosRgb(50.0, c, h, 1.0)))
        end

        local c01 <const> = (active.cAdj - clb) / (cub - clb)
        local black <const> = Color { r = 0, g = 0, b = 0 }
        local white <const> = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))
        CanvasUtilities.drawSliderReticle(
            ctx, c01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.cAdj))
        ctx.color = black
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = white
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setChromaMouseListen,
    onmousemove = setChromaMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "hAdjCanvas",
    label = "H:",
    width = defaults.barWidth,
    height = defaults.barheight,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize

        local c <const> = 50.0
        local lchTosRgb <const> = Clr.srLchTosRgb
        local toHex <const> = Clr.toHex

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.hBarWidth = barWidth

        local xToHue <const> = 1.0 / (barWidth - 1.0)
        local hAdj <const> = active.hAdj - 0.5
        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xHue = pixel.x * xToHue + 0.5
            if pixel.y > 0 then xHue = xHue + hAdj end
            pixel(toHex(lchTosRgb(50.0, c, xHue, 1.0)))
        end

        local black <const> = Color { r = 0, g = 0, b = 0 }
        local white <const> = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))
        CanvasUtilities.drawSliderReticle(
            ctx, active.hAdj, barWidth, barHeight,
            white, reticleSize)

        local strDisplay <const> = string.format("%+04d",
            Utilities.round(hAdj * 360.0))
        ctx.color = black
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = white
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setHueMouseListen,
    onmousemove = setHueMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "aAdjCanvas",
    label = "A:",
    width = defaults.barWidth,
    height = defaults.barheight,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local alb <const> = defaults.labAxisMin
        local aub <const> = defaults.labAxisMax
        local visMin <const> = defaults.labVisMin
        local visMax <const> = defaults.labVisMax

        local labTosRgb <const> = Clr.srLab2TosRgb
        local toHex <const> = Clr.toHex

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.aBarWidth = barWidth

        local xToFac <const> = 1.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xFac <const> = pixel.x * xToFac
            local a <const> = (1.0 - xFac) * visMin + xFac * visMax
            pixel(toHex(labTosRgb(50.0, a, 0.0, 1.0)))
        end

        local a01 <const> = (active.aAdj - alb) / (aub - alb)
        local black <const> = Color { r = 0, g = 0, b = 0 }
        local white <const> = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))
        CanvasUtilities.drawSliderReticle(
            ctx, a01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.aAdj))
        ctx.color = black
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = white
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setAMouseListen,
    onmousemove = setAMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "bAdjCanvas",
    label = "B:",
    width = defaults.barWidth,
    height = defaults.barheight,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local blb <const> = defaults.labAxisMin
        local bub <const> = defaults.labAxisMax
        local visMin <const> = defaults.labVisMin
        local visMax <const> = defaults.labVisMax

        local labTosRgb <const> = Clr.srLab2TosRgb
        local toHex <const> = Clr.toHex

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.bBarWidth = barWidth

        local xToFac <const> = 1.0 / (barWidth - 1.0)
        local img <const> = Image(barWidth, 1, ColorMode.RGB)
        local pxItr <const> = img:pixels()
        for pixel in pxItr do
            local xFac <const> = pixel.x * xToFac
            local b <const> = (1.0 - xFac) * visMin + xFac * visMax
            pixel(toHex(labTosRgb(50.0, 0.0, b, 1.0)))
        end

        local b01 <const> = (active.bAdj - blb) / (bub - blb)
        local black <const> = Color { r = 0, g = 0, b = 0 }
        local white <const> = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))
        CanvasUtilities.drawSliderReticle(
            ctx, b01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.bAdj))
        ctx.color = black
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = white
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setBMouseListen,
    onmousemove = setBMouseListen
}

dlg:newrow { always = false }

dlg:canvas {
    id = "alphaAdjCanvas",
    label = "Alpha:",
    width = defaults.barWidth,
    height = defaults.barheight,
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize

        local bkgColor <const> = app.theme.color.window_face
        local bBkg <const> = bkgColor.blue / 255.0
        local gBkg <const> = bkgColor.green / 255.0
        local rBkg <const> = bkgColor.red / 255.0

        local bTrg = 0.0
        local gTrg = 0.0
        local rTrg = 0.0
        local white <const> = Color { r = 255, g = 255, b = 255 }
        local black <const> = Color { r = 0, g = 0, b = 0 }
        local textFill = black
        local textShadow = white
        local reticleBright = white
        local reticleShade = black

        local lAvg <const> = (rBkg + gBkg + bBkg) / 3.0
        if lAvg <= 0.5 then
            bTrg = 1.0
            gTrg = 1.0
            rTrg = 1.0
            textFill = white
            textShadow = black
            reticleBright = black
            reticleShade = white
        end

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.tBarWidth = barWidth

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

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 1),
            Rectangle(0, 0, barWidth, barHeight))

        local reticleClr = white
        local a01 <const> = active.alphaAdj * 0.5 + 0.5
        if a01 < 0.5 then
            reticleClr = reticleShade
        else
            reticleClr = reticleBright
        end

        CanvasUtilities.drawSliderReticle(
            ctx, a01, barWidth, barHeight,
            reticleClr, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.alphaAdj * 255))
        ctx.color = textShadow
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = textFill
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setAlphaMouseListen,
    onmousemove = setAlphaMouseListen
}

dlg:newrow { always = false }

dlg:button {
    id = "neutral",
    label = "Get:",
    text = "&GRAY",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local frame <const> = site.frame
        if not frame then return end

        local lab <const> = AseUtilities.averageColor(sprite, frame)

        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]

        -- Black and white buttons could also set
        -- the active lightness?
        if mode == "LCH" then
            local lch <const> = Clr.srLab2ToSrLch(
                lab.l, lab.a, lab.b, lab.alpha)
            active.cAdj = -lch.c
        else
            active.aAdj = -lab.a
            active.bAdj = -lab.b
        end
        dlg:repaint()
    end
}

dlg:separator { id = "invertSep" }

dlg:check {
    id = "lInvert",
    label = "Invert:",
    text = "&L",
    selected = defaults.lInvert
}

dlg:check {
    id = "aInvert",
    text = "&A",
    selected = defaults.aInvert
}

dlg:check {
    id = "bInvert",
    text = "&B",
    selected = defaults.bInvert
}

dlg:newrow { always = false }

dlg:check {
    id = "alphaInvert",
    text = "Al&pha",
    selected = defaults.alphaInvert
}

dlg:newrow { always = false }

dlg:button {
    id = "adjustButton",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrames <const> = #frames

        -- If isSelect is true, then a new layer will be created.
        local srcLayer = site.layer --[[@as Layer]]
        local isSelect <const> = target == "SELECTION"
        if not isSelect then
            if not srcLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
                }
                return
            end

            if srcLayer.isGroup then
                app.alert {
                    title = "Error",
                    text = "Group layers are not supported."
                }
                return
            end

            if srcLayer.isReference then
                app.alert {
                    title = "Error",
                    text = "Reference layers are not supported."
                }
                return
            end
        end

        local oldMode <const> = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }
        local activeSpec <const> = activeSprite.spec

        if isSelect then
            local sel <const>, _ <const> = AseUtilities.getSelection(activeSprite)
            local selBounds <const> = sel.bounds
            local xSel <const> = selBounds.x
            local ySel <const> = selBounds.y

            local alphaIndex <const> = activeSpec.transparentColor
            local selSpec <const> = AseUtilities.createSpec(
                selBounds.width, selBounds.height,
                ColorMode.RGB, activeSpec.colorSpace, alphaIndex)

            -- Blit flattened sprite to image.
            local selFrame <const> = site.frame
                or activeSprite.frames[1] --[[@as Frame]]
            local selImage <const> = Image(selSpec)
            selImage:drawSprite(
                activeSprite, selFrame, Point(-xSel, -ySel))

            -- Set pixels not in selection to alpha.
            local pxItr <const> = selImage:pixels()
            for pixel in pxItr do
                local x <const> = pixel.x + xSel
                local y <const> = pixel.y + ySel
                if not sel:contains(x, y) then
                    pixel(alphaIndex)
                end
            end

            -- Create new layer and cel.
            app.transaction("Selection Layer", function()
                srcLayer = activeSprite:newLayer()
                srcLayer.name = "Selection"
                activeSprite:newCel(
                    srcLayer, selFrame,
                    selImage, Point(xSel, ySel))
            end)
        end

        -- Check for tile map support.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Unpack arguments.
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]
        local contrast <const> = args.contrast
            or defaults.contrast --[[@as integer]]
        local normalize <const> = args.normalize
            or defaults.normalize --[[@as integer]]
        local lInvert <const> = args.lInvert --[[@as boolean]]
        local aInvert <const> = args.aInvert --[[@as boolean]]
        local bInvert <const> = args.bInvert --[[@as boolean]]
        local alphaInvert <const> = args.alphaInvert --[[@as boolean]]

        local lAdj <const> = active.lAdj
        local cAdj <const> = active.cAdj
        local hAdj <const> = active.hAdj - 0.5
        local aAdj <const> = active.aAdj
        local bAdj <const> = active.bAdj
        local alphaAdj = active.alphaAdj

        -- Cache booleans for whether or not adjustments
        -- will be made in loop.
        local useNormalize <const> = normalize ~= 0
        local useContrast <const> = contrast ~= 0
        local useLabInvert <const> = bInvert or aInvert or lInvert

        local lAdjNonZero <const> = lAdj ~= 0.0
        local alphaAdjNonZero <const> = alphaAdj ~= 0.0
        local useLabAdj <const> = mode == "LAB"
            and (lAdjNonZero
                or aAdj ~= 0.0
                or bAdj ~= 0.0
                or alphaAdjNonZero)
        local useLchAdj <const> = mode == "LCH"
            and (lAdjNonZero
                or cAdj ~= 0.0
                or hAdj ~= 0.0
                or alphaAdjNonZero)

        -- Alpha invert is grouped with LAB invert, so
        -- the expectation is that it occurs after
        -- adjustment. Logically, though, alpha invert
        -- comes before.
        if alphaInvert then alphaAdj = -alphaAdj end
        local normFac <const> = normalize * 0.01
        local normGtZero <const> = normFac > 0.0
        local normLtZero <const> = normFac < 0.0
        local absNormFac <const> = math.abs(normFac)
        local complNormFac <const> = 1.0 - absNormFac
        local contrastFac <const> = 1.0 + contrast * 0.01
        local aSign = 1.0
        local bSign = 1.0
        if aInvert then aSign = -1.0 end
        if bInvert then bSign = -1.0 end

        -- Create target layer.
        local trgLayer = nil
        app.transaction("Adjustment Layer", function()
            trgLayer = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s Adjusted", srcLayerName)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        -- Cache methods used in loops.
        local abs <const> = math.abs
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local fromHex <const> = Clr.fromHex
        local toHex <const> = Clr.toHex
        local sRgbaToLab <const> = Clr.sRgbToSrLab2
        local labTosRgba <const> = Clr.srLab2TosRgb
        local labToLch <const> = Clr.srLab2ToSrLch
        local lchToLab <const> = Clr.srLchToSrLab2
        local transact <const> = app.transaction
        local strfmt <const> = string.format

        local rgbColorMode <const> = ColorMode.RGB

        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                -- Find unique colors in image.
                -- A cel image may contain only opaque pixels, but
                -- occupy a small part of the canvas. Ensure that
                -- there is always a zero key for alpha invert.
                ---@type table<integer, boolean>
                local srcDict <const> = {}
                local srcPxItr <const> = srcImg:pixels()
                for pixel in srcPxItr do
                    local h = pixel()
                    if (h & 0xff000000) == 0 then h = 0x0 end
                    srcDict[h] = true
                end
                srcDict[0x0] = true

                -- Convert unique colors to LAB.
                -- Normalization should ignore transparent pixels.
                ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                local labDict = {}
                local minLum = 100.0
                local maxLum = 0.0
                local sumLum = 0.0
                local countLum = 0
                for key, _ in pairs(srcDict) do
                    local srgb <const> = fromHex(key)
                    local lab <const> = sRgbaToLab(srgb)
                    labDict[key] = lab

                    if key ~= 0 then
                        local lum <const> = lab.l
                        if lum < minLum then minLum = lum end
                        if lum > maxLum then maxLum = lum end
                        sumLum = sumLum + lum
                        countLum = countLum + 1
                    end
                end

                if useNormalize then
                    local rangeLum <const> = abs(maxLum - minLum)
                    if rangeLum > 0.07 then
                        -- When factor is less than zero, the average lum
                        -- can be multiplied by the factor prior to the loop.
                        local avgLum = 50.0
                        if countLum > 0 then avgLum = sumLum / countLum end
                        avgLum = absNormFac * avgLum

                        -- When factor is greater than zero.
                        local tDenom <const> = absNormFac * (100.0 / rangeLum)
                        local lumMintDenom <const> = minLum * tDenom

                        ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                        local normDict <const> = {}
                        for key, value in pairs(labDict) do
                            local lOld <const> = value.l
                            local lNew = lOld
                            if key ~= 0 then
                                if normGtZero then
                                    lNew = complNormFac * lOld
                                        + tDenom * lOld - lumMintDenom
                                elseif normLtZero then
                                    lNew = complNormFac * lOld + avgLum
                                end
                            end

                            normDict[key] = {
                                l = lNew,
                                a = value.a,
                                b = value.b,
                                alpha = value.alpha
                            }
                        end
                        labDict = normDict
                    end
                end

                if alphaInvert then
                    ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                    local aInvDict <const> = {}
                    for key, value in pairs(labDict) do
                        aInvDict[key] = {
                            l = value.l,
                            a = value.a,
                            b = value.b,
                            alpha = 1.0 - value.alpha
                        }
                    end
                    labDict = aInvDict
                end

                if useContrast then
                    ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                    local contrDict <const> = {}
                    for key, value in pairs(labDict) do
                        contrDict[key] = {
                            l = (value.l - 50.0) * contrastFac + 50.0,
                            a = value.a,
                            b = value.b,
                            alpha = value.alpha
                        }
                    end
                    labDict = contrDict
                end

                if useLabAdj then
                    ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                    local labAdjDict <const> = {}
                    for key, value in pairs(labDict) do
                        local al = value.alpha
                        if al > 0.0 then al = al + alphaAdj end
                        labAdjDict[key] = {
                            l = value.l + lAdj,
                            a = value.a + aAdj,
                            b = value.b + bAdj,
                            alpha = al
                        }
                    end
                    labDict = labAdjDict
                elseif useLchAdj then
                    ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                    local lchAdjDict <const> = {}
                    for key, value in pairs(labDict) do
                        local lch <const> = labToLch(
                            value.l,
                            value.a,
                            value.b,
                            value.alpha)
                        local al = lch.a
                        if al > 0.0 then al = al + alphaAdj end
                        lchAdjDict[key] = lchToLab(
                            lch.l + lAdj,
                            lch.c + cAdj,
                            lch.h + hAdj, al)
                    end
                    labDict = lchAdjDict
                end

                if useLabInvert then
                    ---@type table<integer, { l: number, a: number, b: number, alpha: number }>
                    local labInvDict <const> = {}
                    for key, value in pairs(labDict) do
                        local lNew = value.l
                        if lInvert then lNew = 100.0 - lNew end
                        labInvDict[key] = {
                            l = lNew,
                            a = value.a * aSign,
                            b = value.b * bSign,
                            alpha = value.alpha
                        }
                    end
                    labDict = labInvDict
                end

                ---@type table<integer, integer>
                local trgDict <const> = {}
                for key, value in pairs(labDict) do
                    trgDict[key] = toHex(labTosRgba(
                        value.l, value.a, value.b,
                        value.alpha))
                end

                local srcPos <const> = srcCel.position
                local trgPos = srcPos
                local trgImg = nil
                if alphaInvert then
                    trgImg = Image(activeSpec)
                    trgImg:drawImage(srcImg, srcPos)
                    trgPos = Point(0, 0)
                else
                    trgImg = srcImg:clone()
                end

                local trgPxItr <const> = trgImg:pixels()
                for pixel in trgPxItr do
                    local h = pixel()
                    if (h & 0xff000000) == 0 then h = 0x0 end
                    pixel(trgDict[h])
                end

                transact(
                    strfmt("Color Adjust %d", srcFrame),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, trgPos)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        if isSelect then
            activeSprite:deleteLayer(srcLayer)
        end

        AseUtilities.changePixelFormat(oldMode)
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}