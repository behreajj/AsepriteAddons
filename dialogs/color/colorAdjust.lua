dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local targets = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes = { "LAB", "LCH" }

local defaults = {
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

local active = {
    lAdj = 0.0,
    cAdj = 0.0,
    hAdj = 0.5,
    aAdj = 0.0,
    bAdj = 0.0,
    alphaAdj = 0.0
}

local dlg = Dialog { title = "Adjust Color" }

local function setLightMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx100 = 200.0 * event.x / (bw - 1.0) - 100.0
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

local function setChromaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local clb = -defaults.maxChroma
        local cub = defaults.maxChroma
        local mx01 = event.x / (bw - 1.0)
        local mxc = (1.0 - mx01) * clb + mx01 * cub
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

local function setHueMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx01 = event.x / (bw - 1.0)
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

local function setAMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local alb = defaults.labAxisMin
        local aub = defaults.labAxisMax
        local mx01 = event.x / (bw - 1.0)
        local mxa = (1.0 - mx01) * alb + mx01 * aub
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

local function setBMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local blb = defaults.labAxisMin
        local bub = defaults.labAxisMax
        local mx01 = event.x / (bw - 1.0)
        local mxb = (1.0 - mx01) * blb + mx01 * bub
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

local function setAlphaMouseListen(event)
    if event.button ~= MouseButton.NONE then
        local bw = defaults.barWidth
        local mx01 = event.x / (bw - 1.0)
        local mxalpha = mx01 + mx01 - 1.0
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
        local args = dlg.data
        local isLch = args.mode == "LCH"
        local isLab = args.mode == "LAB"
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
    autoScaling = false,
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        -- The problem with coloring the light bar is that
        -- it is visible in both LAB and LCH mode.
        -- local c = 50.0
        -- local h = active.hAdj - 0.5
        local lchTosRgb = Clr.srLchTosRgb
        local toHex = Clr.toHex

        local xToLight = 100.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xLight = pixel.x * xToLight
            pixel(toHex(lchTosRgb(xLight, 0.0, 0.0, 1.0)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        ctx:drawImage(img, 0, 0)

        local lAdj = active.lAdj
        local l01 = lAdj * 0.005 + 0.5
        local black = Color { r = 0, g = 0, b = 0 }
        local white = Color { r = 255, g = 255, b = 255 }
        local fill = black
        if lAdj < 0.0 then
            fill = white
        end
        CanvasUtilities.drawSliderReticle(
            ctx, l01, barWidth, barHeight,
            fill, reticleSize)

        local strDisplay = string.format(
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
    autoScaling = false,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize
        local clb = -defaults.maxChroma
        local cub = defaults.maxChroma

        local h = active.hAdj - 0.5
        local lchTosRgb = Clr.srLchTosRgb
        local toHex = Clr.toHex

        local xToChroma = cub / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local c = pixel.x * xToChroma
            pixel(toHex(lchTosRgb(50.0, c, h, 1.0)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        local c01 = (active.cAdj - clb) / (cub - clb)
        local black = Color { r = 0, g = 0, b = 0 }
        local white = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img, 0, 0)
        CanvasUtilities.drawSliderReticle(
            ctx, c01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay = string.format(
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
    autoScaling = false,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        local c = 50.0
        local lchTosRgb = Clr.srLchTosRgb
        local toHex = Clr.toHex

        local xToHue = 1.0 / (barWidth - 1.0)
        local hAdj = active.hAdj - 0.5
        local img = Image(barWidth, 2, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xHue = pixel.x * xToHue + 0.5
            if pixel.y > 0 then xHue = xHue + hAdj end
            pixel(toHex(lchTosRgb(50.0, c, xHue, 1.0)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        local black = Color { r = 0, g = 0, b = 0 }
        local white = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img, 0, 0)
        CanvasUtilities.drawSliderReticle(
            ctx, active.hAdj, barWidth, barHeight,
            white, reticleSize)

        local strDisplay = string.format("%+04d",
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
    autoScaling = false,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize
        local alb = defaults.labAxisMin
        local aub = defaults.labAxisMax
        local visMin = defaults.labVisMin
        local visMax = defaults.labVisMax

        local labTosRgb = Clr.srLab2TosRgb
        local toHex = Clr.toHex

        local xToFac = 1.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xFac = pixel.x * xToFac
            local a = (1.0 - xFac) * visMin + xFac * visMax
            pixel(toHex(labTosRgb(50.0, a, 0.0, 1.0)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        local a01 = (active.aAdj - alb) / (aub - alb)
        local black = Color { r = 0, g = 0, b = 0 }
        local white = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img, 0, 0)
        CanvasUtilities.drawSliderReticle(
            ctx, a01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay = string.format(
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
    autoScaling = false,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize
        local blb = defaults.labAxisMin
        local bub = defaults.labAxisMax
        local visMin = defaults.labVisMin
        local visMax = defaults.labVisMax

        local labTosRgb = Clr.srLab2TosRgb
        local toHex = Clr.toHex

        local xToFac = 1.0 / (barWidth - 1.0)
        local img = Image(barWidth, 1, ColorMode.RGB)
        local pxItr = img:pixels()
        for pixel in pxItr do
            local xFac = pixel.x * xToFac
            local b = (1.0 - xFac) * visMin + xFac * visMax
            pixel(toHex(labTosRgb(50.0, 0.0, b, 1.0)))
        end
        img:resize(barWidth, barHeight)

        local ctx = event.context
        local b01 = (active.bAdj - blb) / (bub - blb)
        local black = Color { r = 0, g = 0, b = 0 }
        local white = Color { r = 255, g = 255, b = 255 }
        ctx:drawImage(img, 0, 0)
        CanvasUtilities.drawSliderReticle(
            ctx, b01, barWidth, barHeight,
            white, reticleSize)

        local strDisplay = string.format(
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
    autoScaling = false,
    onpaint = function(event)
        local barWidth = defaults.barWidth
        local barHeight = defaults.barHeight
        local reticleSize = defaults.reticleSize

        local bkgColor = app.theme.color.window_face
        local bBkg = bkgColor.blue * 0.003921568627451
        local gBkg = bkgColor.green * 0.003921568627451
        local rBkg = bkgColor.red * 0.003921568627451

        local bTrg = 0.0
        local gTrg = 0.0
        local rTrg = 0.0
        local white = Color { r = 255, g = 255, b = 255 }
        local black = Color { r = 0, g = 0, b = 0 }
        local textFill = black
        local textShadow = white
        local reticleBright = white
        local reticleShade = black

        local lAvg = (rBkg + gBkg + bBkg) / 3.0
        if lAvg <= 0.5 then
            bTrg = 1.0
            gTrg = 1.0
            rTrg = 1.0
            textFill = white
            textShadow = black
            reticleBright = black
            reticleShade = white
        end

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

        local reticleClr = white
        local a01 = active.alphaAdj * 0.5 + 0.5
        if a01 < 0.5 then
            reticleClr = reticleShade
        else
            reticleClr = reticleBright
        end

        CanvasUtilities.drawSliderReticle(
            ctx, a01, barWidth, barHeight,
            reticleClr, reticleSize)

        local strDisplay = string.format(
            "%+04d", Utilities.round(active.alphaAdj * 255))
        ctx.color = textShadow
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = textFill
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setAlphaMouseListen,
    onmousemove = setAlphaMouseListen
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
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Get the range as soon as possible, before any changes
        -- cause it to be removed or updated.
        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local isSelect = target == "SELECTION"
        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrames = #frames

        -- If isSelect is true, then a new layer will be created.
        local srcLayer = site.layer --[[@as Layer]]
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
        end

        local oldMode = activeSprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }
        local activeSpec = activeSprite.spec

        if isSelect then
            local sel = AseUtilities.getSelection(activeSprite)
            local selBounds = sel.bounds
            local xSel = selBounds.x
            local ySel = selBounds.y

            local alphaIndex = activeSpec.transparentColor
            local selSpec = ImageSpec {
                width = math.max(1, selBounds.width),
                height = math.max(1, selBounds.height),
                colorMode = ColorMode.RGB,
                transparentColor = alphaIndex
            }
            selSpec.colorSpace = activeSpec.colorSpace

            -- Blit flattened sprite to image.
            local selFrame = site.frame
                or activeSprite.frames[1] --[[@as Frame]]
            local selImage = Image(selSpec)
            selImage:drawSprite(
                activeSprite, selFrame, Point(-xSel, -ySel))

            -- Set pixels not in selection to alpha.
            local pxItr = selImage:pixels()
            for pixel in pxItr do
                local x = pixel.x + xSel
                local y = pixel.y + ySel
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
        local isTilemap = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        -- Unpack arguments.
        local mode = args.mode or defaults.mode --[[@as string]]
        local contrast = args.contrast or defaults.contrast --[[@as integer]]
        local normalize = args.normalize or defaults.normalize --[[@as integer]]
        local lInvert = args.lInvert --[[@as boolean]]
        local aInvert = args.aInvert --[[@as boolean]]
        local bInvert = args.bInvert --[[@as boolean]]
        local alphaInvert = args.alphaInvert --[[@as boolean]]

        local lAdj = active.lAdj
        local cAdj = active.cAdj
        local hAdj = active.hAdj - 0.5
        local aAdj = active.aAdj
        local bAdj = active.bAdj
        local alphaAdj = active.alphaAdj

        -- Cache booleans for whether or not adjustments
        -- will be made in loop.
        local useNormalize = normalize ~= 0
        local useContrast = contrast ~= 0
        local useLabInvert = bInvert or aInvert or lInvert

        local lAdjNonZero = lAdj ~= 0.0
        local alphaAdjNonZero = alphaAdj ~= 0.0
        local useLabAdj = mode == "LAB"
            and (lAdjNonZero
            or aAdj ~= 0.0
            or bAdj ~= 0.0
            or alphaAdjNonZero)
        local useLchAdj = mode == "LCH"
            and (lAdjNonZero
            or cAdj ~= 0.0
            or hAdj ~= 0.0
            or alphaAdjNonZero)

        -- Alpha invert is grouped with LAB invert, so
        -- the expectation is that it occurs after
        -- adjustment. Logically, though, alpha invert
        -- comes before.
        if alphaInvert then alphaAdj = -alphaAdj end
        local normFac = normalize * 0.01
        local normGtZero = normFac > 0.0
        local normLtZero = normFac < 0.0
        local absNormFac = math.abs(normFac)
        local complNormFac = 1.0 - absNormFac
        local contrastFac = 1.0 + contrast * 0.01
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
                "%s.Adjusted", srcLayerName)
            trgLayer.parent = srcLayer.parent
            trgLayer.opacity = srcLayer.opacity
            trgLayer.blendMode = srcLayer.blendMode
        end)

        -- Cache methods used in loops.
        local abs = math.abs
        local tilesToImage = AseUtilities.tilesToImage
        local fromHex = Clr.fromHex
        local toHex = Clr.toHex
        local sRgbaToLab = Clr.sRgbToSrLab2
        local labTosRgba = Clr.srLab2TosRgb
        local labToLch = Clr.srLab2ToSrLch
        local lchToLab = Clr.srLchToSrLab2
        local rgbColorMode = ColorMode.RGB
        local transact = app.transaction
        local strfmt = string.format

        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]
            local srcCel = srcLayer:cel(srcFrame)
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
                local srcDict = {}
                local srcPxItr = srcImg:pixels()
                for pixel in srcPxItr do
                    local h = pixel()
                    if (h & 0xff000000) == 0 then h = 0x0 end
                    srcDict[h] = true
                end
                srcDict[0x0] = true

                -- Convert unique colors to CIE LAB.
                -- Normalization should ignore transparent pixels.
                ---@type table<integer, table>
                local labDict = {}
                local minLum = 100.0
                local maxLum = 0.0
                local sumLum = 0.0
                local countLum = 0
                for key, _ in pairs(srcDict) do
                    local srgb = fromHex(key)
                    local lab = sRgbaToLab(srgb)
                    labDict[key] = lab

                    if key ~= 0 then
                        local lum = lab.l
                        if lum < minLum then minLum = lum end
                        if lum > maxLum then maxLum = lum end
                        sumLum = sumLum + lum
                        countLum = countLum + 1
                    end
                end

                if useNormalize then
                    local rangeLum = abs(maxLum - minLum)
                    if rangeLum > 0.07 then
                        -- When factor is less than zero, the average lum
                        -- can be multiplied by the factor prior to the loop.
                        local avgLum = 50.0
                        if countLum > 0 then avgLum = sumLum / countLum end
                        avgLum = absNormFac * avgLum

                        -- When factor is greater than zero.
                        local tDenom = absNormFac * (100.0 / rangeLum)
                        local lumMintDenom = minLum * tDenom

                        local normDict = {}
                        for key, value in pairs(labDict) do
                            local lOld = value.l
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
                    local aInvDict = {}
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
                    local contrDict = {}
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
                    local labAdjDict = {}
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
                    local lchAdjDict = {}
                    for key, value in pairs(labDict) do
                        local lch = labToLch(
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
                    local labInvDict = {}
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

                -- Convert CIE LAB to sRGBA hexadecimal.
                local trgDict = {}
                for key, value in pairs(labDict) do
                    trgDict[key] = toHex(labTosRgba(
                        value.l, value.a, value.b,
                        value.alpha))
                end

                local srcPos = srcCel.position
                local trgPos = srcPos
                local trgImg = nil
                if alphaInvert then
                    trgImg = Image(activeSpec)
                    trgImg:drawImage(srcImg, srcPos)
                    trgPos = Point(0, 0)
                else
                    trgImg = srcImg:clone()
                end

                local trgPxItr = trgImg:pixels()
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

dlg:show { wait = false }