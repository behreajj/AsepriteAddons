dofile("../../../support/aseutilities.lua")
dofile("../../../support/canvasutilities.lua")

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

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = { "LAB", "LCH" }

local defaults <const> = {
    target = "ACTIVE",
    mode = "LCH",
    barWidth = 240 // screenScale,
    barHeight = 16 // screenScale,
    reticleSize = 3 / screenScale,
    labAxisMin = -120.0,
    labAxisMax = 120.0,
    labVisMin = -80.0,
    labVisMax = 80.0,
    maxChroma = 135.0,
    lIncrScale = 5,
    cIncrScale = 10,
    hIncrScale = 15,
    abIncrScale = 10,
    printElapsed = false,
}

local active <const> = {
    lAdj = 0.0,
    cAdj = 0.0,
    hAdj = 0.5,
    aAdj = 0.0,
    bAdj = 0.0,
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
        local mx100 <const> = bw > 1
            and (200.0 * event.x / (bw - 1.0) - 100.0)
            or 0.0
        if event.ctrlKey then
            active.lAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mx100 - active.lAdj) > incr then
                if event.altKey then incr = incr * defaults.lIncrScale end
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
        local mx01 <const> = bw > 1 and (event.x / (bw - 1.0)) or 0.0
        local mxc <const> = (1.0 - mx01) * clb + mx01 * cub
        if event.ctrlKey then
            active.cAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxc - active.cAdj) > incr then
                if event.altKey then incr = incr * defaults.cIncrScale end
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
        local mx01 <const> = bw > 1 and (event.x / (bw - 1.0)) or 0.0
        if event.ctrlKey then
            active.hAdj = 0.5
        elseif event.shiftKey then
            local incr = 0.0027777777777778
            if math.abs(mx01 - active.hAdj) > incr then
                if event.altKey then incr = incr * defaults.hIncrScale end
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
        local mx01 <const> = bw > 1 and (event.x / (bw - 1.0)) or 0.0
        local mxa <const> = (1.0 - mx01) * alb + mx01 * aub
        if event.ctrlKey then
            active.aAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxa - active.aAdj) > incr then
                if event.altKey then incr = incr * defaults.abIncrScale end
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
        local mx01 <const> = bw > 1 and (event.x / (bw - 1.0)) or 0.0
        local mxb <const> = (1.0 - mx01) * blb + mx01 * bub
        if event.ctrlKey then
            active.bAdj = 0.0
        elseif event.shiftKey then
            local incr = 1.0
            if math.abs(mxb - active.bAdj) > incr then
                if event.altKey then incr = incr * defaults.abIncrScale end
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

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

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
    height = defaults.barHeight,
    vexpand = false,
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize

        -- The problem with coloring the light bar is that
        -- it is visible in both LAB and LCH mode.
        -- local c = 50.0
        -- local h = active.hAdj - 0.5
        local lchTosRgb <const> = ColorUtilities.srLchTosRgbInternal
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.lBarWidth = barWidth

        local xtol <const> = barWidth > 1 and 100.0 / (barWidth - 1.0) or 0.0
        local lAdj <const> = active.lAdj

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xl <const> = i * xtol
            local h0 <const> = toHex(lchTosRgb(xl, 0.0, 0.0, 1.0))
            bytes[1 + i] = strpack("<I4", h0)

            local h1 <const> = toHex(lchTosRgb(xl + lAdj, 0.0, 0.0, 1.0))
            bytes[barWidth + 1 + i] = strpack("<I4", h1)
            i = i + 1
        end

        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))

        local l01 <const> = lAdj * 0.005 + 0.5
        local bk <const> = Color { r = 0, g = 0, b = 0, a = 255 }
        local wt <const> = Color { r = 255, g = 255, b = 255, a = 255 }
        local fill = lAdj < 0.0 and wt or bk
        CanvasUtilities.drawSliderReticle(
            ctx, l01, barWidth, barHeight,
            fill, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.lAdj))
        ctx.color = bk
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = wt
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
    height = defaults.barHeight,
    vexpand = false,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local clb <const> = -defaults.maxChroma
        local cub <const> = defaults.maxChroma

        local h <const> = active.hAdj - 0.5
        local lchTosRgb <const> = ColorUtilities.srLchTosRgbInternal
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.cBarWidth = barWidth

        local xtoc <const> = barWidth > 1 and cub / (barWidth - 1.0) or 0.0
        local cAdj <const> = active.cAdj

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xc <const> = i * xtoc
            local h0 <const> = toHex(lchTosRgb(50.0, xc, h, 1.0))
            bytes[1 + i] = strpack("<I4", h0)

            local h1 <const> = toHex(lchTosRgb(50.0, xc + cAdj, h, 1.0))
            bytes[barWidth + 1 + i] = strpack("<I4", h1)
            i = i + 1
        end

        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))

        local c01 <const> = (cAdj - clb) / (cub - clb)
        local wt <const> = Color { r = 255, g = 255, b = 255, a = 255 }
        CanvasUtilities.drawSliderReticle(
            ctx, c01, barWidth, barHeight,
            wt, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.cAdj))
        ctx.color = Color { r = 0, g = 0, b = 0, a = 255 }
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = wt
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
    height = defaults.barHeight,
    vexpand = false,
    visible = defaults.mode == "LCH",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize

        local c <const> = 50.0
        local lchTosRgb <const> = ColorUtilities.srLchTosRgbInternal
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.hBarWidth = barWidth

        local xToHue <const> = barWidth > 1 and 1.0 / (barWidth - 1.0) or 0.0
        local hAdj <const> = active.hAdj - 0.5

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xHue <const> = i * xToHue + 0.5
            local h0 <const> = toHex(lchTosRgb(50.0, c, xHue, 1.0))
            bytes[1 + i] = strpack("<I4", h0)

            local h1 <const> = toHex(lchTosRgb(50.0, c, xHue + hAdj, 1.0))
            bytes[barWidth + 1 + i] = strpack("<I4", h1)

            i = i + 1
        end

        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        img.bytes = table.concat(bytes)

        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))
        local wt <const> = Color { r = 255, g = 255, b = 255, a = 255 }
        CanvasUtilities.drawSliderReticle(
            ctx, active.hAdj, barWidth, barHeight,
            wt, reticleSize)

        local strDisplay <const> = string.format("%+04d",
            Utilities.round(hAdj * 360.0))
        ctx.color = Color { r = 0, g = 0, b = 0, a = 255 }
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = wt
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
    height = defaults.barHeight,
    vexpand = false,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local alb <const> = defaults.labAxisMin
        local aub <const> = defaults.labAxisMax
        local visMin <const> = defaults.labVisMin
        local visMax <const> = defaults.labVisMax

        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local labnew <const> = Lab.new
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.aBarWidth = barWidth

        local xToFac <const> = barWidth > 1 and 1.0 / (barWidth - 1.0) or 0.0
        local aAdj <const> = active.aAdj
        local bAdj <const> = active.bAdj

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xFac <const> = i * xToFac
            local a <const> = (1.0 - xFac) * visMin + xFac * visMax
            local h0 <const> = toHex(labTosRgb(labnew(50.0, a, 0.0, 1.0)))
            bytes[1 + i] = strpack("<I4", h0)

            local h1 <const> = toHex(labTosRgb(labnew(50.0, a + aAdj, bAdj, 1.0)))
            bytes[barWidth + 1 + i] = strpack("<I4", h1)
            i = i + 1
        end

        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))

        local a01 <const> = (aAdj - alb) / (aub - alb)
        local wt <const> = Color { r = 255, g = 255, b = 255, a = 255 }
        CanvasUtilities.drawSliderReticle(
            ctx, a01, barWidth, barHeight,
            wt, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.aAdj))
        ctx.color = Color { r = 0, g = 0, b = 0, a = 255 }
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = wt
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
    height = defaults.barHeight,
    vexpand = false,
    visible = defaults.mode == "LAB",
    onpaint = function(event)
        local reticleSize <const> = defaults.reticleSize
        local blb <const> = defaults.labAxisMin
        local bub <const> = defaults.labAxisMax
        local visMin <const> = defaults.labVisMin
        local visMax <const> = defaults.labVisMax

        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local labnew <const> = Lab.new
        local toHex <const> = Rgb.toHex
        local strpack <const> = string.pack

        local ctx <const> = event.context
        local barWidth <const> = ctx.width
        local barHeight <const> = ctx.height
        active.bBarWidth = barWidth

        local xToFac <const> = barWidth > 1 and 1.0 / (barWidth - 1.0) or 0.0
        local aAdj <const> = active.aAdj
        local bAdj <const> = active.bAdj

        ---@type string[]
        local bytes <const> = {}
        local i = 0
        while i < barWidth do
            local xFac <const> = i * xToFac
            local b <const> = (1.0 - xFac) * visMin + xFac * visMax
            local h0 <const> = toHex(labTosRgb(labnew(50.0, 0.0, b, 1.0)))
            bytes[1 + i] = strpack("<I4", h0)

            local h1 <const> = toHex(labTosRgb(labnew(50.0, aAdj, b + bAdj, 1.0)))
            bytes[barWidth + 1 + i] = strpack("<I4", h1)
            i = i + 1
        end

        local img <const> = Image(barWidth, 2, ColorMode.RGB)
        img.bytes = table.concat(bytes)
        ctx:drawImage(img,
            Rectangle(0, 0, barWidth, 2),
            Rectangle(0, 0, barWidth, barHeight))

        local wt <const> = Color { r = 255, g = 255, b = 255, a = 255 }
        local b01 <const> = (active.bAdj - blb) / (bub - blb)
        CanvasUtilities.drawSliderReticle(
            ctx, b01, barWidth, barHeight,
            wt, reticleSize)

        local strDisplay <const> = string.format(
            "%+04d", Utilities.round(active.bAdj))
        ctx.color = Color { r = 0, g = 0, b = 0, a = 255 }
        ctx:fillText(strDisplay, 2, 2)
        ctx.color = wt
        ctx:fillText(strDisplay, 1, 1)
    end,
    onmousedown = setBMouseListen,
    onmousemove = setBMouseListen
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
        local frObj <const> = site.frame
        if not frObj then return end

        local lab <const> = AseUtilities.averageColor(sprite, frObj.frameNumber)

        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]

        -- Black and white buttons could also set
        -- the active lightness?
        if mode == "LCH" then
            local lch <const> = Lab.toLch(lab)
            active.cAdj = -lch.c
        else
            active.aAdj = -lab.a
            active.bAdj = -lab.b
        end
        dlg:repaint()
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "adjustButton",
    text = "&OK",
    focus = false,
    onclick = function()
        local startTime <const> = os.clock()

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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrIdcs <const> = #frIdcs

        local srcLayer = site.layer --[[@as Layer]]
        local removeSrcLayer = false

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
            removeSrcLayer = true
        else
            if not srcLayer then
                app.alert {
                    title = "Error",
                    text = "There is no active layer."
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

            if srcLayer.isGroup then
                app.transaction("Flatten Group", function()
                    srcLayer = AseUtilities.flattenGroup(
                        activeSprite, srcLayer, frIdcs)
                    removeSrcLayer = true
                end)
            end
        end

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        local lAdj <const> = active.lAdj
        local cAdj <const> = active.cAdj
        local hAdj <const> = active.hAdj - 0.5
        local aAdj <const> = active.aAdj
        local bAdj <const> = active.bAdj

        local useLchAdj <const> = mode == "LCH"
            and (lAdj ~= 0.0
                or cAdj ~= 0.0
                or hAdj ~= 0.0)

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local labToLch <const> = Lab.toLch
        local lchToLab <const> = Lab.fromLchInternal
        local labnew <const> = Lab.new
        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat

        app.transaction("Adjust Layer", function()
            local trgLayer <const> = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            if mode == "LCH" then
                trgLayer.name = string.format(
                    "%s L %d C %d H %d",
                    srcLayerName,
                    Utilities.round(lAdj),
                    Utilities.round(cAdj),
                    Utilities.round(hAdj * 360.0))
            elseif mode == "LAB" then
                trgLayer.name = string.format(
                    "%s L %d A %d B %d",
                    srcLayerName,
                    Utilities.round(lAdj),
                    Utilities.round(aAdj),
                    Utilities.round(bAdj))
            else
                trgLayer.name = string.format(
                    "%s Adjusted", srcLayerName)
            end
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            -- Do not copy blend mode, it only confuses things.

            ---@type table<integer, integer>
            local srcToTrg <const> = {}

            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frIdx <const> = frIdcs[i]
                local srcCel <const> = srcLayer:cel(frIdx)
                if srcCel then
                    local srcImg = srcCel.image
                    if isTileMap then
                        srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                    end

                    local srcBytes <const> = srcImg.bytes
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local area <const> = wSrc * hSrc

                    ---@type string[]
                    local trgByteArr <const> = {}

                    local j = 0
                    while j < area do
                        local j4 <const> = j * 4
                        local srcAbgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local trgAbgr32 = 0

                        if srcToTrg[srcAbgr32] then
                            trgAbgr32 = srcToTrg[srcAbgr32]
                        else
                            local srcSrgb <const> = fromHex(srcAbgr32)
                            if srcSrgb.a > 0.0 then
                                local srcLab <const> = sRgbToLab(srcSrgb)
                                if useLchAdj then
                                    local lch <const> = labToLch(srcLab)
                                    local labAdj <const> = lchToLab(
                                        lch.l + lAdj,
                                        lch.c + cAdj,
                                        lch.h + hAdj,
                                        lch.a)
                                    trgAbgr32 = toHex(labTosRgb(labAdj))
                                else
                                    trgAbgr32 = toHex(labTosRgb(labnew(
                                        srcLab.l + lAdj,
                                        srcLab.a + aAdj,
                                        srcLab.b + bAdj,
                                        srcLab.alpha)))
                                end -- Lch v. Lab adjust.
                            end     -- Non zero alpha.
                            srcToTrg[srcAbgr32] = trgAbgr32
                        end         -- Dictionary check.

                        j = j + 1
                        trgByteArr[j] = strpack("<I4", trgAbgr32)
                    end -- End pixels loop.

                    local trgImg <const> = Image(srcSpec)
                    trgImg.bytes = tconcat(trgByteArr)

                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, srcCel.position)
                    trgCel.opacity = srcCel.opacity
                end -- End source cel exists.
            end     -- End frames loop.

            app.layer = trgLayer
        end) -- End transaction.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed)
                }
            }
        end
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
    autoscrollbars = false,
    wait = false
}