dofile("./aseutilities.lua")
dofile("./clrkey.lua")
dofile("./clrgradient.lua")
dofile("./curve3.lua")

GradientUtilities = {}
GradientUtilities.__index = GradientUtilities

setmetatable(GradientUtilities, {
    -- Previous version at commit:
    -- cb2f20dab3dcb1cf58a7fc664c2de13570506ebc
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Color spaces presets.
GradientUtilities.CLR_SPC_PRESETS = {
    "LINEAR_RGB",
    "NORMAL_MAP",
    "S_RGB",
    "SR_LAB_2",
    "SR_LCH"
}

---Hue easing function presets.
GradientUtilities.HUE_EASING_PRESETS = {
    "CCW",
    "CW",
    "FAR",
    "NEAR"
}

---Style presets.
GradientUtilities.STYLE_PRESETS = {
    "DITHER_BAYER",
    "DITHER_CUSTOM",
    "DITHER_NOISE",
    "MIXED"
}

---Default color space preset.
GradientUtilities.DEFAULT_CLR_SPC = "SR_LCH"

---Default hue easing preset.
GradientUtilities.DEFAULT_HUE_EASING = "NEAR"

---Default style preset.
GradientUtilities.DEFAULT_STYLE = "MIXED"

---Bayer dithering matrices, in 2^1, 2^2, 2^3 or 2x2, 4x4, 8x8. For matrix
---generators, see https://codegolf.stackexchange.com/q/259633 and
---https://www.shadertoy.com/view/XtV3RG . More than 2^4 is overkill for
---8-bit color. The largest element is rows * columns - 1. These are normalized
---in a non-standard way for the sake of consistency with custom dithers.
---@type number[][]
GradientUtilities.BAYER_MATRICES = {
    {
        0.125, 0.625,
        0.875, 0.375
    },
    {
        0.03125, 0.53125, 0.15625, 0.65625,
        0.78125, 0.28125, 0.90625, 0.40625,
        0.21875, 0.71875, 0.09375, 0.59375,
        0.96875, 0.46875, 0.84375, 0.34375
    },
    {
        0.007813, 0.507813, 0.132813, 0.632813, 0.039063, 0.539063, 0.164063, 0.664063,
        0.757813, 0.257813, 0.882813, 0.382813, 0.789063, 0.289063, 0.914063, 0.414063,
        0.195313, 0.695313, 0.070313, 0.570313, 0.226563, 0.726563, 0.101563, 0.601563,
        0.945313, 0.445313, 0.820313, 0.320313, 0.976563, 0.476563, 0.851563, 0.351563,
        0.054688, 0.554688, 0.179688, 0.679688, 0.023438, 0.523438, 0.148438, 0.648438,
        0.804688, 0.304688, 0.929688, 0.429688, 0.773438, 0.273438, 0.898438, 0.398438,
        0.242188, 0.742188, 0.117188, 0.617188, 0.210938, 0.710938, 0.085938, 0.585938,
        0.992188, 0.492188, 0.867188, 0.367188, 0.960938, 0.460938, 0.835938, 0.335938
    }
}

--- Maximum width or height for a custom dither image.
GradientUtilities.DITHER_MAX_SIZE = 64

---Maximum number of keys for gradient interface.
GradientUtilities.MAX_KEYS = 32

---Clears a gradient to an initial state.
---@param gr ClrGradient
---@return ClrGradient
function GradientUtilities.clearGradient(gr)
    local origKeys <const> = {}
    local sprite <const> = app.sprite
    if sprite then
        local aseColorToClr <const> = AseUtilities.aseColorToClr
        local lenOrigKeys = 0

        local appRange <const> = app.range
        if appRange.sprite == sprite then
            local frame <const> = app.frame or sprite.frames[1]
            local palette <const> = AseUtilities.getPalette(
                frame, sprite.palettes)
            local lenPalette <const> = #palette

            ---@type Clr[]
            local validColors <const> = {}
            local lenValidColors = 0
            local rangeClrIdcs <const> = appRange.colors
            local lenRangeClrIdcs <const> = #rangeClrIdcs

            if lenRangeClrIdcs > GradientUtilities.MAX_KEYS then
                local floor <const> = math.floor
                local mix <const> = Clr.mixSrLab2Internal
                local toFac <const> = 1.0 / (GradientUtilities.MAX_KEYS - 1.0)

                local idxFirst <const> = rangeClrIdcs[1]
                local clrFirst <const> = (idxFirst >= 0 and idxFirst < lenPalette)
                    and aseColorToClr(palette:getColor(idxFirst))
                    or Clr.new(0.0, 0.0, 0.0, 1.0)

                local idxLast <const> = rangeClrIdcs[lenRangeClrIdcs]
                local clrLast <const> = (idxLast >= 0 and idxLast < lenPalette)
                    and aseColorToClr(palette:getColor(idxLast))
                    or Clr.new(1.0, 1.0, 1.0, 1.0)

                local h = 0
                while h < GradientUtilities.MAX_KEYS do
                    local t <const> = h * toFac
                    if t <= 0.0 then
                        lenValidColors = lenValidColors + 1
                        validColors[lenValidColors] = clrFirst
                    elseif t >= 1.0 then
                        lenValidColors = lenValidColors + 1
                        validColors[lenValidColors] = clrLast
                    else
                        local tScaled <const> = t * (lenRangeClrIdcs - 1)
                        local i <const> = floor(tScaled)
                        local idxOrig <const> = rangeClrIdcs[1 + i]
                        local idxDest <const> = rangeClrIdcs[2 + i]
                        if idxOrig >= 0 and idxOrig < lenPalette
                            and idxDest >= 0 and idxDest < lenPalette then
                            local mixed <const> = mix(aseColorToClr(
                                palette:getColor(idxOrig)), aseColorToClr(
                                palette:getColor(idxDest)), tScaled - i)
                            lenValidColors = lenValidColors + 1
                            validColors[lenValidColors] = mixed
                        end
                    end

                    h = h + 1
                end
            else
                local h = 0
                while h < lenRangeClrIdcs do
                    h = h + 1
                    local rangeClrIdx <const> = rangeClrIdcs[h]
                    if rangeClrIdx >= 0 and rangeClrIdx < lenPalette then
                        local aseColor <const> = palette:getColor(rangeClrIdx)
                        local clr <const> = aseColorToClr(aseColor)
                        lenValidColors = lenValidColors + 1
                        validColors[lenValidColors] = clr
                    end -- End index is valid.
                end     -- End range colors loop.
            end         -- End max count check.

            local iToFac <const> = lenValidColors > 1
                and 1.0 / (lenValidColors - 1.0)
                or 0.0
            local i = 0
            while i < lenValidColors do
                local fac <const> = i * iToFac
                lenOrigKeys = lenOrigKeys + 1
                origKeys[lenOrigKeys] = ClrKey.new(fac, validColors[1 + i])
                i = i + 1
            end
        end -- End range sprite is sprite.

        if lenOrigKeys < 2 then
            local fgClr <const> = aseColorToClr(app.fgColor)
            app.command.SwitchColors()
            local bgClr <const> = aseColorToClr(app.fgColor)
            app.command.SwitchColors()

            local fgHex <const> = Clr.toHex(fgClr)
            local bgHex <const> = Clr.toHex(bgClr)
            if fgHex == bgHex
                and fgHex ~= 0x00000000
                and fgHex ~= 0xff000000
                and fgHex ~= 0xffffffff then
                origKeys[1] = ClrKey.new(0.0, Clr.new(0.0, 0.0, 0.0, fgClr.a))
                origKeys[2] = ClrKey.new(0.5, fgClr)
                origKeys[3] = ClrKey.new(1.0, Clr.new(1.0, 1.0, 1.0, fgClr.a))
            else
                origKeys[1] = ClrKey.new(0.0, fgClr)
                origKeys[2] = ClrKey.new(1.0, bgClr)
            end
        end
    else
        origKeys[1] = ClrKey.new(0.0, Clr.new(0.0, 0.0, 0.0, 1.0))
        origKeys[2] = ClrKey.new(1.0, Clr.new(1.0, 1.0, 1.0, 1.0))
    end

    gr:setKeys(origKeys)
    return gr
end

---Finds the appropriate color easing function based on the color space preset
---and hue preset.
---@param clrSpcPreset string color space preset
---@param huePreset string hue preset
---@return fun(o: Clr, d: Clr, t: number): Clr
---@nodiscard
function GradientUtilities.clrSpcFuncFromPreset(clrSpcPreset, huePreset)
    if clrSpcPreset == "LINEAR_RGB" then
        return Clr.mixsRgbInternal
    elseif clrSpcPreset == "NORMAL_MAP" then
        return Clr.mixNormal
    elseif clrSpcPreset == "SR_LAB_2" then
        return Clr.mixSrLab2Internal
    elseif clrSpcPreset == "SR_LCH" then
        local hef <const> = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(o, d, t)
            return Clr.mixSrLchInternal(o, d, t, hef)
        end
    else
        return Clr.mixlRgbaInternal
    end
end

---Generates the dialog widgets shared across gradient dialogs. Places a new
---row at the end of the widgets. The show style flag specifies whether to show
---the style combo box for gradients which allow dithered vs. mixed color.
---@param dlg Dialog dialog
---@param showStyle boolean show style combo box
---@return ClrGradient
---@nodiscard
function GradientUtilities.dialogWidgets(dlg, showStyle)
    local gradient <const> = ClrGradient.newInternal({})
    GradientUtilities.clearGradient(gradient)

    local screenScale = 1
    local aHex = 0xff808080
    local bHex = 0xffcacaca
    if app.preferences then
        local generalPrefs <const> = app.preferences.general
        if generalPrefs then
            local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
            if ssCand and ssCand > 0 then
                screenScale = ssCand
            end
        end

        -- If you wanted to set the checkers to the document preferenes,
        -- it could be done here.
    end

    local grdUtlActive <const> = {
        wCanvas = 240 // screenScale,
        hCanvas = 16 // screenScale,
        mousePressed = false,
        isDragging = false,
        idxCurrent = -1,
        idxHover = -1,
        reticleSize = 10 // screenScale,
        wCheck = 8,
        hCheck = 8,
    }

    ---@param event { context: GraphicsContext }
    local function onPaintGradient(event)
        local ctx <const> = event.context
        ctx.antialias = false
        ctx.blendMode = BlendMode.SRC

        local wCanvas <const> = ctx.width
        local hCanvas <const> = ctx.height
        if wCanvas <= 1 or hCanvas <= 1 then return end
        grdUtlActive.wCanvas = wCanvas
        grdUtlActive.hCanvas = hCanvas

        local args <const> = dlg.data
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]

        ---@type string[]
        local grdChars <const> = {}
        local iToFac <const> = wCanvas > 1 and 1.0 / (wCanvas - 1.0) or 0.0
        local lvVerif <const> = stylePreset == "MIXED" and levels or 0

        local max <const> = math.max
        local min <const> = math.min
        local floor <const> = math.floor
        local strchar <const> = string.char
        local cgmix <const> = ClrGradient.eval
        local quantize <const> = Utilities.quantizeUnsigned
        local clrToAseColor <const> = AseUtilities.clrToAseColor

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

        local i = 0
        while i < wCanvas do
            local t <const> = i * iToFac
            local tq <const> = quantize(t, lvVerif)
            local c <const> = cgmix(gradient, tq, mixFunc)

            local r8 <const> = floor(min(max(c.r, 0.0), 1.0) * 255.0 + 0.5)
            local g8 <const> = floor(min(max(c.g, 0.0), 1.0) * 255.0 + 0.5)
            local b8 <const> = floor(min(max(c.b, 0.0), 1.0) * 255.0 + 0.5)
            local a8 <const> = floor(min(max(c.a, 0.0), 1.0) * 255.0 + 0.5)

            local i4 <const> = i * 4
            grdChars[1 + i4] = strchar(r8)
            grdChars[2 + i4] = strchar(g8)
            grdChars[3 + i4] = strchar(b8)
            grdChars[4 + i4] = strchar(a8)

            i = i + 1
        end

        local gradientSpec <const> = ImageSpec {
            width = wCanvas,
            height = 1,
            colorMode = ColorMode.RGB,
            transparentColor = 0
        }
        local gradientImage <const> = Image(gradientSpec)
        gradientImage.bytes = table.concat(grdChars)

        local wCheck <const> = grdUtlActive.wCheck
        local hCheck <const> = grdUtlActive.hCheck
        local bkgImage <const> = AseUtilities.checkerImage(
            wCanvas, hCanvas, wCheck, hCheck, aHex, bHex)

        gradientImage:resize(wCanvas, hCanvas)
        bkgImage:drawImage(gradientImage, Point(0, 0),
            255, BlendMode.NORMAL)
        local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
        ctx:drawImage(bkgImage, drawRect, drawRect)

        local reticleSize <const> = grdUtlActive.reticleSize
        local reticleHalf <const> = reticleSize // 2
        local y <const> = hCanvas // 2 - reticleHalf
        local aseWhite = Color { r = 255, g = 255, b = 255 }
        local aseBlack = Color { r = 0, g = 0, b = 0 }

        local keys <const> = gradient:getKeys()
        local lenKeys <const> = #keys
        local j = 0
        while j < lenKeys do
            j = j + 1
            local key <const> = keys[j]
            local keyStep <const> = key.step
            local keyClr <const> = key.clr

            local x <const> = floor(keyStep * (wCanvas - 1.0) + 0.5)

            local avgLight <const> = (keyClr.r + keyClr.g + keyClr.b) / 3.0
            local tagColor <const> = avgLight >= 0.5 and aseBlack or aseWhite
            local aseColor <const> = clrToAseColor(keyClr)

            ctx.color = tagColor
            ctx:strokeRect(Rectangle(
                x - reticleHalf, y,
                reticleSize, reticleSize))

            ctx.color = aseColor
            ctx:fillRect(Rectangle(
                1 + x - reticleHalf, 1 + y,
                reticleSize - 2, reticleSize - 2))
        end -- End keys loop.

        if grdUtlActive.idxHover ~= -1 then
            local keyHover <const> = gradient:getKey(grdUtlActive.idxHover)
            local stepHover <const> = keyHover.step
            local clrHover <const> = keyHover.clr
            local avgLight <const> = (clrHover.r + clrHover.g + clrHover.b) / 3.0
            local tagColor <const> = avgLight >= 0.5 and aseBlack or aseWhite
            local x <const> = floor(stepHover * (wCanvas - 1.0) + 0.5)

            ctx.color = tagColor
            ctx:strokeRect(Rectangle(
                x - 2 - reticleHalf, y - 2,
                reticleSize + 4, reticleSize + 4))

            -- ctx.color = tagColor
            -- ctx:fillText(string.format("%d", grdUtlActive.idxHover),
            --     2 + x - reticleHalf, 2 + y)

            grdUtlActive.idxHover = -1
        end -- End hover reticle.
    end

    ---@param event MouseEvent
    local function onMouseDownGradient(event)
        local quantizeUnsigned <const> = Utilities.quantizeUnsigned

        local wCanvas <const> = grdUtlActive.wCanvas
        local xNorm <const> = wCanvas > 1
            and event.x / (wCanvas - 1.0)
            or 0.0
        local maxKeys <const> = 3 * GradientUtilities.MAX_KEYS
        local xq <const> = quantizeUnsigned(xNorm, maxKeys)

        local keys <const> = gradient:getKeys()
        local lenKeys <const> = #keys

        local i = 0
        while grdUtlActive.idxCurrent == -1
            and i < lenKeys do
            i = i + 1
            if xq == quantizeUnsigned(keys[i].step, maxKeys) then
                grdUtlActive.idxCurrent = i
            end
        end

        grdUtlActive.mousePressed = true
    end

    ---@param event MouseEvent
    local function onMouseMoveGradient(event)
        local eventButton <const> = event.button
        local x <const> = event.x
        local y <const> = event.y

        local wCanvas <const> = grdUtlActive.wCanvas
        local hCanvas <const> = grdUtlActive.hCanvas

        if x < 0 then return end
        if x >= wCanvas then return end

        local quantizeUnsigned <const> = Utilities.quantizeUnsigned
        local maxKeys <const> = 3 * GradientUtilities.MAX_KEYS

        local xNorm <const> = wCanvas > 1
            and x / (wCanvas - 1.0)
            or 0.0
        local xq <const> = quantizeUnsigned(xNorm, maxKeys)

        local keys <const> = gradient:getKeys()
        local lenKeys <const> = #keys

        if y >= 0 and y < hCanvas then
            local search = true
            local j = 0
            while search and j < lenKeys do
                j = j + 1
                if xq == quantizeUnsigned(keys[j].step, maxKeys) then
                    grdUtlActive.idxHover = j
                    search = false
                end
            end
        end

        if eventButton == MouseButton.LEFT
            and grdUtlActive.idxCurrent ~= -1 then
            grdUtlActive.isDragging = true

            local conflictingKeyIndex = -1
            local i = 0
            while conflictingKeyIndex == -1
                and i < lenKeys do
                i = i + 1
                if xq == quantizeUnsigned(keys[i].step, maxKeys) then
                    conflictingKeyIndex = i
                end
            end

            if conflictingKeyIndex ~= -1 then
                local temp <const> = keys[conflictingKeyIndex].clr
                keys[conflictingKeyIndex].clr = keys[grdUtlActive.idxCurrent].clr
                keys[grdUtlActive.idxCurrent].clr = temp

                grdUtlActive.idxCurrent = conflictingKeyIndex
            end

            keys[grdUtlActive.idxCurrent].step = xNorm
        end

        dlg:repaint()
    end

    ---@param event MouseEvent
    local function onMouseUpGradient(event)
        local eventButton <const> = event.button
        if eventButton == MouseButton.NONE then return end

        if eventButton == MouseButton.RIGHT
            or (event.ctrlKey and eventButton == MouseButton.LEFT) then
            if grdUtlActive.isDragging == false then
                if grdUtlActive.idxCurrent ~= -1 then
                    -- Remove the active key.
                    gradient:removeKeyAt(grdUtlActive.idxCurrent)
                end -- End has current key.
            end     -- End not dragging.
        elseif eventButton == MouseButton.LEFT then
            if grdUtlActive.isDragging == false then
                if grdUtlActive.idxCurrent ~= -1 then
                    -- Update the active key's color.
                    if event.altKey then
                        app.command.SwitchColors()
                        local newClr <const> = AseUtilities.aseColorToClr(app.fgColor)
                        gradient:getKey(grdUtlActive.idxCurrent).clr = newClr
                        app.command.SwitchColors()
                    else
                        local newClr <const> = AseUtilities.aseColorToClr(app.fgColor)
                        gradient:getKey(grdUtlActive.idxCurrent).clr = newClr
                    end
                else
                    -- Add a new key.
                    local wCanvas <const> = grdUtlActive.wCanvas
                    local xNorm <const> = wCanvas > 1
                        and event.x / (wCanvas - 1.0)
                        or 0.0
                    local xq <const> = Utilities.quantizeUnsigned(
                        xNorm, GradientUtilities.MAX_KEYS)

                    local args <const> = dlg.data
                    local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
                    local huePreset <const> = args.huePreset --[[@as string]]
                    local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
                        clrSpacePreset, huePreset)

                    local newClr <const> = ClrGradient.eval(gradient, xq, mixFunc)
                    gradient:insortRight(ClrKey.new(xq, newClr))
                end -- End has current key.
            end     -- End not dragging.
        end         -- End mouse button check.

        grdUtlActive.idxCurrent = -1
        grdUtlActive.isDragging = false
        grdUtlActive.mousePressed = false

        dlg:repaint()
    end

    dlg:canvas {
        id = "gradientCanvas",
        label = "Gradient:",
        focus = true,
        width = grdUtlActive.wCanvas,
        height = grdUtlActive.hCanvas,
        onpaint = onPaintGradient,
        onmousemove = onMouseMoveGradient,
        onmouseup = onMouseUpGradient,
        onmousedown = onMouseDownGradient
    }

    dlg:newrow { always = false }

    dlg:button {
        id = "flipButton",
        text = "&FLIP",
        focus = false,
        onclick = function()
            gradient:reverse()
            dlg:repaint()
        end
    }

    dlg:button {
        id = "spreadButton",
        text = "&SPREAD",
        focus = false,
        onclick = function()
            local keys <const> = gradient:getKeys()
            local lenKeys <const> = #keys
            local iToFac <const> = lenKeys > 1 and 1.0 / (lenKeys - 1.0) or 0.0
            local i = 0
            while i < lenKeys do
                keys[1 + i].step = i * iToFac
                i = i + 1
            end
            dlg:repaint()
        end
    }

    dlg:button {
        id = "splineButton",
        text = "&DIVIDE",
        focus = false,
        onclick = function()
            local args <const> = dlg.data
            local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
            local huePreset <const> = args.huePreset --[[@as string]]
            local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
                clrSpacePreset, huePreset)
            local cgeval <const> = ClrGradient.eval

            ---@type ClrKey[]
            local newKeys <const> = {}
            local lenGradient <const> = #gradient
            if lenGradient < 3 then
                local hMixFunc <const> = GradientUtilities.hueEasingFuncFromPreset(huePreset)
                newKeys[1] = ClrKey.new(0.0, cgeval(gradient, 0.0, mixFunc))
                newKeys[3] = ClrKey.new(1.0, cgeval(gradient, 1.0, mixFunc))
                newKeys[2] = ClrKey.new(0.5, Clr.mixSrLch(
                    newKeys[1].clr, newKeys[3].clr, 0.5, hMixFunc))
            else
                -- Cache methods used in loop.
                local floor <const> = math.floor
                local labTosRgb <const> = Clr.srLab2TosRgb
                local sRgbToLab <const> = Clr.sRgbToSrLab2
                local crveval <const> = Curve3.eval

                ---@type Vec3[]
                local points <const> = {}
                ---@type number[]
                local alphas <const> = {}

                local sampleCount <const> = math.min(math.max(
                    lenGradient * 2 - 1, 3), GradientUtilities.MAX_KEYS)
                local iToFac <const> = 1.0 / (sampleCount - 1.0)

                local h = 0
                while h < sampleCount do
                    local hFac <const> = h * iToFac
                    local clr <const> = cgeval(gradient, hFac, mixFunc)
                    local lab <const> = sRgbToLab(clr)
                    points[1 + h] = Vec3.new(lab.a, lab.b, lab.l)
                    alphas[1 + h] = clr.a
                    h = h + 1
                end

                local curve <const> = Curve3.fromCatmull(false, points, 0.0)

                local i = 0
                while i < sampleCount do
                    local iFac <const> = i * iToFac
                    local alpha = 1.0
                    if iFac <= 0.0 then
                        alpha = alphas[1]
                    elseif iFac >= 1.0 then
                        alpha = alphas[sampleCount]
                    else
                        local aScaled <const> = iFac * (sampleCount - 1)
                        local aFloor <const> = floor(aScaled)
                        local aFrac <const> = aScaled - aFloor
                        alpha = (1.0 - aFrac) * alphas[1 + aFloor]
                            + aFrac * alphas[2 + aFloor]
                    end
                    local point <const> = crveval(curve, iFac)
                    i = i + 1
                    newKeys[i] = ClrKey.new(iFac, labTosRgb(
                        point.z, point.x, point.y, alpha))
                end
            end

            gradient:setKeys(newKeys)
            dlg:repaint()
        end
    }

    dlg:button {
        id = "clearButton",
        text = "C&LEAR",
        focus = false,
        onclick = function()
            GradientUtilities.clearGradient(gradient)
            dlg:repaint()
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "stylePreset",
        label = "Style:",
        option = GradientUtilities.DEFAULT_STYLE,
        options = GradientUtilities.STYLE_PRESETS,
        visible = showStyle,
        onchange = function()
            local args <const> = dlg.data

            local style <const> = args.stylePreset --[[@as string]]
            local isMixed <const> = style == "MIXED"
            local isBayer <const> = style == "DITHER_BAYER"
            local isCustom <const> = style == "DITHER_CUSTOM"

            local csp <const> = args.clrSpacePreset --[[@as string]]
            local isPolar <const> = csp == "SR_LCH"

            dlg:modify { id = "clrSpacePreset", visible = isMixed }
            dlg:modify { id = "huePreset", visible = isMixed and isPolar }
            dlg:modify { id = "quantize", visible = isMixed }
            dlg:modify { id = "bayerIndex", visible = isBayer }
            dlg:modify { id = "ditherPath", visible = isCustom }
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "clrSpacePreset",
        label = "Space:",
        option = GradientUtilities.DEFAULT_CLR_SPC,
        options = GradientUtilities.CLR_SPC_PRESETS,
        visible = (not showStyle) or
            GradientUtilities.DEFAULT_STYLE == "MIXED",
        onchange = function()
            local args <const> = dlg.data
            local style <const> = args.stylePreset --[[@as string]]
            local csp <const> = args.clrSpacePreset --[[@as string]]
            local isPolar <const> = csp == "SR_LCH"
            local isMixed <const> = style == "MIXED"
            dlg:modify { id = "huePreset", visible = isMixed and isPolar }
            dlg:repaint()
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "huePreset",
        label = "Hue:",
        option = GradientUtilities.DEFAULT_HUE_EASING,
        options = GradientUtilities.HUE_EASING_PRESETS,
        visible = ((not showStyle)
                or GradientUtilities.DEFAULT_STYLE == "MIXED")
            and GradientUtilities.DEFAULT_CLR_SPC == "SR_LCH",
        onchange = function()
            dlg:repaint()
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "quantize",
        label = "Quantize:",
        min = 0,
        max = 32,
        value = 0,
        visible = (not showStyle) or
            GradientUtilities.DEFAULT_STYLE == "MIXED",
        onchange = function()
            dlg:repaint()
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "bayerIndex",
        label = "Size (2^n):",
        min = 1,
        max = 3,
        value = 2,
        visible = showStyle
            and GradientUtilities.DEFAULT_STYLE == "DITHER_BAYER"
    }

    dlg:newrow { always = false }

    dlg:file {
        id = "ditherPath",
        label = "File:",
        filetypes = AseUtilities.FILE_FORMATS_OPEN,
        open = true,
        focus = false,
        visible = showStyle
            and GradientUtilities.DEFAULT_STYLE == "DITHER_CUSTOM"
    }

    dlg:newrow { always = false }

    return gradient
end

---Finds the appropriate color gradient dither from a string preset.
---"DITHER_CUSTOM" returns a custom matrix loaded from an image file path.
---"DITHER_BAYER" returns a Bayer matrix.
---Defaults to a smooth mix.
---@param stylePreset string style preset
---@param bayerIndex integer? Bayer exponent, 2^1
---@param ditherPath string? dither image path
---@return fun(cg: ClrGradient, step: number, x: integer, y: integer): Clr
---@nodiscard
function GradientUtilities.ditherFromPreset(
    stylePreset, bayerIndex, ditherPath)
    if stylePreset == "DITHER_BAYER" then
        local biVrf <const> = bayerIndex or 2
        local matrix <const> = GradientUtilities.BAYER_MATRICES[biVrf]
        local bayerSize <const> = 1 << biVrf

        return function(cg, step, x, y)
            return ClrGradient.dither(
                cg, step, matrix,
                x, y, bayerSize, bayerSize)
        end
    elseif stylePreset == "DITHER_CUSTOM" then
        local matrix = GradientUtilities.BAYER_MATRICES[2]
        local c = 4
        local r = 4

        if ditherPath and #ditherPath > 0
            and app.fs.isFile(ditherPath) then
            -- Disable asking about color profiles when loading these images.
            local oldAskProfile = 0
            local oldAskMissing = 0
            local appPrefs <const> = app.preferences
            if appPrefs then
                local cmPrefs <const> = appPrefs.color
                if cmPrefs then
                    oldAskProfile = cmPrefs.files_with_profile or 0 --[[@as integer]]
                    oldAskMissing = cmPrefs.missing_profile or 0 --[[@as integer]]

                    cmPrefs.files_with_profile = 0
                    cmPrefs.missing_profile = 0
                end
            end

            local image <const> = Image { fromFile = ditherPath }

            if appPrefs then
                local cmPrefs <const> = appPrefs.color
                if cmPrefs then
                    cmPrefs.files_with_profile = oldAskProfile
                    cmPrefs.missing_profile = oldAskMissing
                end
            end

            if image then
                matrix, c, r = GradientUtilities.imageToMatrix(image)
            end -- End image exists check.
        end     -- End file path validity check.

        return function(cg, step, x, y)
            return ClrGradient.dither(
                cg, step, matrix,
                x, y, c, r)
        end
    else
        return ClrGradient.noise
    end
end

---Converts an Aseprite image to a dithering matrix. Returns the matrix along
---with its width (columns), height (rows) maximum and minimum element. RGB
---images use a grayscale conversion. Grayscale images use the gray value as is.
---Indexed images find the minimum and maximum index used, then normalize.
---Images greater than the size limit will return a default instead.
---@param image Image image
---@return number[] matrix
---@return integer columns
---@return integer rows
function GradientUtilities.imageToMatrix(image)
    -- Intended for use with:
    -- https://bitbucket.org/jjhaggar/aseprite-dithering-matrices,

    local spec <const> = image.spec
    local width <const> = spec.width
    local height <const> = spec.height

    if width > GradientUtilities.DITHER_MAX_SIZE
        or height > GradientUtilities.DITHER_MAX_SIZE
        or (width < 2 and height < 2) then
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    ---@type number[]
    local matrix <const> = {}
    local lenMat <const> = width * height
    local bytes <const> = image.bytes
    local strbyte <const> = string.byte

    local colorMode <const> = spec.colorMode
    if colorMode == ColorMode.RGB then
        -- Problem with this approach is that no one will agree on RGB to gray
        -- conversion. To unpack colors to floats, you could try, e.g.,
        -- string.unpack("f", string.pack("i", 0x40490FDB)) to read,
        -- string.unpack("i", string.pack("f", 3.1415927410126)) to write.
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local clrnew <const> = Clr.new

        local h = 0
        while h < lenMat do
            local h4 <const> = h * 4
            local r <const>, g <const>, b <const> = strbyte(bytes, 1 + h4, 3 + h4)
            local srgb <const> = clrnew(r / 255.0, g / 255.0, b / 255.0, 1.0)
            local lab <const> = sRgbToLab(srgb)
            local v <const> = lab.l * 0.01
            h = h + 1
            matrix[h] = v
        end
    elseif colorMode == ColorMode.GRAY then
        local h = 0
        while h < lenMat do
            local h2 <const> = h * 2
            local v <const> = strbyte(bytes, 1 + h2) / 255.0
            h = h + 1
            matrix[h] = v
        end
    elseif colorMode == ColorMode.INDEXED then
        -- https://github.com/aseprite/aseprite/issues/2573#issuecomment-736074731
        local mxElm = -2147483648
        local mnElm = 2147483647

        local h = 0
        while h < lenMat do
            local idx <const> = strbyte(bytes, 1 + h)
            if idx > mxElm then mxElm = idx end
            if idx < mnElm then mnElm = idx end
            h = h + 1
            matrix[h] = idx
        end

        -- Normalize. Include half edges.
        mnElm = mnElm - 0.5
        mxElm = mxElm + 0.5
        local range <const> = math.abs(mxElm - mnElm)
        if range > 0.0 then
            local denom <const> = 1.0 / range
            local j = 0
            while j < lenMat do
                j = j + 1
                matrix[j] = (matrix[j] - mnElm) * denom
            end
        end
    else
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    return matrix, width, height
end

---Finds the appropriate easing function in HSL or HSV given a preset.
---@param preset string hue preset
---@return fun(o: number, d: number, t: number): number
---@nodiscard
function GradientUtilities.hueEasingFuncFromPreset(preset)
    if preset == "CCW" then
        return GradientUtilities.lerpHueCcw
    elseif preset == "CW" then
        return GradientUtilities.lerpHueCw
    elseif preset == "FAR" then
        return GradientUtilities.lerpHueFar
    else
        return GradientUtilities.lerpHueNear
    end
end

---Interpolates a hue from an origin to a destination by a factor in [0.0, 1.0]
---in the counter-clockwise direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
---@nodiscard
function GradientUtilities.lerpHueCcw(o, d, t)
    return Utilities.lerpAngleCcw(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination by a factor in [0.0, 1.0]
---in the clockwise direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
---@nodiscard
function GradientUtilities.lerpHueCw(o, d, t)
    return Utilities.lerpAngleCw(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination by a factor in [0.0, 1.0]
---in the far direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
---@nodiscard
function GradientUtilities.lerpHueFar(o, d, t)
    return Utilities.lerpAngleFar(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination by a factor in [0.0, 1.0]
---in the near direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
---@nodiscard
function GradientUtilities.lerpHueNear(o, d, t)
    return Utilities.lerpAngleNear(o, d, t, 1.0)
end

return GradientUtilities