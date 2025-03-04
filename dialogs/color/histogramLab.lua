dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local site <const> = app.site
local sprite <const> = site.sprite
if not sprite then return end

local spriteFrames <const> = sprite.frames
local lenSpriteFrames <const> = #spriteFrames
local activeFrObj <const> = site.frame or spriteFrames[1]
local activeFrIdx = activeFrObj.frameNumber

local spriteSpec <const> = sprite.spec
local wImage <const> = spriteSpec.width
local hImage <const> = spriteSpec.height
local colorMode <const> = spriteSpec.colorMode

local areaImage <const> = wImage * hImage
local flat <const> = Image(spriteSpec)

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
    wCanvas = 256 // screenScale,
    hCanvas = 256 // screenScale,
    strokeWeight = math.max(1.0, 1.5 / screenScale),
    binCount = 256,

    aMin = -82.709187739605,
    aMax = 104.18850360397,
    bMin = -110.47816964815,
    bMax = 94.903461003717,
    cMax = 119.07602046756,

    lDisplay = true,
    aDisplay = false,
    bDisplay = false,
    cDisplay = true,
    hDisplay = false,
}

local active <const> = {
    binCount = defaults.binCount,
    wCanvas = defaults.wCanvas,
    hCanvas = defaults.hCanvas,
    xCanvas = 0,
    yCanvas = 0,
}

local dlg <const> = Dialog { title = "Histogram" }

dlg:check {
    id = "lDisplay",
    text = "&L",
    selected = defaults.lDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:check {
    id = "aDisplay",
    text = "&A",
    selected = defaults.aDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:check {
    id = "bDisplay",
    text = "&B",
    selected = defaults.bDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:check {
    id = "cDisplay",
    text = "&C",
    selected = defaults.cDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:check {
    id = "hDisplay",
    text = "&H",
    selected = defaults.hDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:canvas {
    id = "histogram",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onpaint = function(event)
        local ctx <const> = event.context
        local wCanvas <const> = ctx.width
        local hCanvas <const> = ctx.height
        active.wCanvas = wCanvas
        active.hCanvas = hCanvas
        if wCanvas <= 1 or hCanvas <= 1 then return end

        ---@type table<integer, integer>
        local lBins <const> = {}
        ---@type table<integer, integer>
        local aBins <const> = {}
        ---@type table<integer, integer>
        local bBins <const> = {}
        ---@type table<integer, integer>
        local cBins <const> = {}
        ---@type table<integer, integer>
        local hBins <const> = {}

        local lScalar = 0.0
        local abScalar = 0.0
        local cScalar = 0.0
        local hScalar = 0.0

        local wn1 <const> = wCanvas - 1.0
        local hn1 <const> = hCanvas - 1.0
        local binCount <const> = active.binCount
        local bn1 <const> = binCount - 1

        ---@type number[]
        local lPoints <const> = {}
        ---@type number[]
        local aPoints <const> = {}
        ---@type number[]
        local bPoints <const> = {}
        ---@type number[]
        local cPoints <const> = {}
        ---@type number[]
        local hPoints <const> = {}

        flat:drawSprite(sprite, activeFrIdx)

        ---@type table<integer, integer>
        local abgr32Tally <const> = {}
        local srcBytes <const> = flat.bytes

        local strbyte <const> = string.byte
        local strunpack <const> = string.unpack
        local strsub <const> = string.sub

        if colorMode == ColorMode.GRAY then
            local i = 0
            while i < areaImage do
                local i2 <const> = i * 2
                local av16 <const> = strunpack("<I2", strsub(
                    srcBytes, 1 + i2, 2 + i2))
                local r8, g8, b8 = 0, 0, 0
                local t8 <const> = (av16 >> 0x08) & 0xff
                if t8 > 0 then
                    local v8 <const> = av16 & 0xff
                    r8, g8, b8 = v8, v8, v8
                end
                local abgr32 <const> = t8 << 0x18
                    | b8 << 0x10
                    | g8 << 0x08
                    | r8
                local tally <const> = abgr32Tally[abgr32] or 0
                abgr32Tally[abgr32] = tally + 1
                i = i + 1
            end
        elseif colorMode == ColorMode.INDEXED then
            local palette <const> = AseUtilities.getPalette(
                activeFrIdx, sprite.palettes)
            local lenPalette <const> = #palette
            local alphaIndex <const> = spriteSpec.transparentColor
            local hasBkg <const> = sprite.backgroundLayer ~= nil

            local i = 0
            while i < areaImage do
                i = i + 1
                local idx <const> = strbyte(srcBytes, i)
                local r8, g8, b8, t8 = 0, 0, 0, 0
                if (idx ~= alphaIndex or hasBkg)
                    and idx < lenPalette
                    and idx >= 0 then
                    local aseColor <const> = palette:getColor(idx)
                    t8 = aseColor.alpha
                    if t8 > 0 then
                        r8 = aseColor.red
                        g8 = aseColor.green
                        b8 = aseColor.blue
                    end
                end

                local abgr32 <const> = t8 << 0x18
                    | b8 << 0x10
                    | g8 << 0x08
                    | r8
                local tally <const> = abgr32Tally[abgr32] or 0
                abgr32Tally[abgr32] = tally + 1
            end
        else
            local i = 0
            while i < areaImage do
                local i4 <const> = i * 4
                local abgr32 <const> = strunpack("<I4", strsub(
                    srcBytes, 1 + i4, 4 + i4))
                local tally <const> = abgr32Tally[abgr32] or 0
                abgr32Tally[abgr32] = tally + 1
                i = i + 1
            end
        end

        local atan2 <const> = math.atan
        local floor <const> = math.floor
        local sqrt <const> = math.sqrt
        local fromHex <const> = Clr.fromHexAbgr32
        local sRgbToLab <const> = Clr.sRgbToSrLab2Internal

        local aMin <const> = defaults.aMin
        local aMax <const> = defaults.aMax
        local aRange <const> = math.abs(aMax - aMin)

        local bMin <const> = defaults.bMin
        local bMax <const> = defaults.bMax
        local bRange <const> = math.abs(bMax - bMin)

        local cMax <const> = defaults.cMax

        local j = 0
        while j < binCount do
            j = j + 1
            lBins[j] = 0
            aBins[j] = 0
            bBins[j] = 0
            cBins[j] = 0
            hBins[j] = 0
        end

        local lMaxFreq = -2147483648
        local abMaxFreq = -2147483648
        local cMaxFreq = -2147483648
        local hMaxFreq = -2147483648

        for abgr32, tally in pairs(abgr32Tally) do
            local srgb <const> = fromHex(abgr32)
            local t01 <const> = srgb.a

            if t01 > 0 then
                local lab <const> = sRgbToLab(srgb)
                local l <const> = lab.l
                local a <const> = lab.a
                local b <const> = lab.b
                local c <const> = sqrt(a * a + b * b)

                local l01 <const> = l * 0.01
                local a01 <const> = (a - aMin) / aRange
                local b01 <const> = (b - bMin) / bRange
                local c01 <const> = c / cMax

                -- Should this bias by 0.5 or no?
                local lBin <const> = floor(l01 * bn1 + 0.5)
                local aBin <const> = floor(a01 * bn1 + 0.5)
                local bBin <const> = floor(b01 * bn1 + 0.5)
                local cBin <const> = floor(c01 * bn1 + 0.5)

                local lFreq <const> = lBins[1 + lBin] + tally
                local aFreq <const> = aBins[1 + aBin] + tally
                local bFreq <const> = bBins[1 + bBin] + tally
                local cFreq <const> = cBins[1 + cBin] + tally

                lBins[1 + lBin] = lFreq
                aBins[1 + aBin] = aFreq
                bBins[1 + bBin] = bFreq
                cBins[1 + cBin] = cFreq

                if lFreq > lMaxFreq then lMaxFreq = lFreq end
                if aFreq > abMaxFreq then abMaxFreq = aFreq end
                if bFreq > abMaxFreq then abMaxFreq = bFreq end
                if cFreq > cMaxFreq then cMaxFreq = cFreq end

                if c > 0.0 then
                    local h <const> = atan2(b, a)
                    local h01 <const> = (h / 6.2831853071796) % 1.0
                    local hBin <const> = floor(h01 * bn1 + 0.5)
                    local hFreq <const> = hBins[1 + hBin] + tally
                    hBins[1 + hBin] = hFreq
                    if hFreq > hMaxFreq then hMaxFreq = hFreq end
                end
            end
        end

        lScalar = lMaxFreq > 1
            and 1.0 / (lMaxFreq - 1.0)
            or 0.0
        abScalar = abMaxFreq > 1
            and 1.0 / (abMaxFreq - 1.0)
            or 0.0
        cScalar = cMaxFreq > 1
            and 1.0 / (cMaxFreq - 1.0)
            or 0.0
        hScalar = hMaxFreq > 1
            and 1.0 / (hMaxFreq - 1.0)
            or 0.0

        local k = 0
        while k < binCount do
            local x <const> = wn1 * (k / bn1)

            local lFreq <const> = lBins[1 + k]
            local aFreq <const> = aBins[1 + k]
            local bFreq <const> = bBins[1 + k]
            local cFreq <const> = cBins[1 + k]
            local hFreq <const> = hBins[1 + k]

            local ly <const> = hn1 * (1.0 - lFreq * lScalar)
            local ay <const> = hn1 * (1.0 - aFreq * abScalar)
            local by <const> = hn1 * (1.0 - bFreq * abScalar)
            local cy <const> = hn1 * (1.0 - cFreq * cScalar)
            local hy <const> = hn1 * (1.0 - hFreq * hScalar)

            local k2 <const> = k * 2
            lPoints[1 + k2], lPoints[2 + k2] = x, ly
            aPoints[1 + k2], aPoints[2 + k2] = x, ay
            bPoints[1 + k2], bPoints[2 + k2] = x, by
            cPoints[1 + k2], cPoints[2 + k2] = x, cy
            hPoints[1 + k2], hPoints[2 + k2] = x, hy

            k = k + 1
        end

        CanvasUtilities.drawGrid(
            ctx, 7,
            ctx.width, ctx.height,
            Color { r = 92, g = 92, b = 92, a = 255 }, 1)

        ctx.antialias = true
        ctx.strokeWidth = defaults.strokeWeight

        local args <const> = dlg.data
        local lDisplay <const> = args.lDisplay --[[@as boolean]]
        local aDisplay <const> = args.aDisplay --[[@as boolean]]
        local bDisplay <const> = args.bDisplay --[[@as boolean]]
        local cDisplay <const> = args.cDisplay --[[@as boolean]]
        local hDisplay <const> = (args.hDisplay --[[@as boolean]])
            and colorMode ~= ColorMode.GRAY

        if aDisplay then
            local ro <const>,
            go <const>,
            bo <const> = 0, 157 / 255, 116 / 255
            local rd <const>,
            gd <const>,
            bd <const> = 218 / 255, 46 / 255, 122 / 255

            local xPrev = aPoints[1]
            local yPrev = aPoints[2]
            local m = 1
            while m < binCount do
                local t <const> = (m - 1.0) / bn1
                local u <const> = 1.0 - t

                local r <const> = u * ro + t * rd
                local g <const> = u * go + t * gd
                local b <const> = u * bo + t * bd

                local aseColor <const> = Color {
                    r = floor(r * 255 + 0.5),
                    g = floor(g * 255 + 0.5),
                    b = floor(b * 255 + 0.5),
                    a = 255 }

                local m2 <const> = m * 2
                local xCurr <const> = aPoints[1 + m2]
                local yCurr <const> = aPoints[2 + m2]

                ctx.color = aseColor
                ctx:beginPath()
                ctx:moveTo(xPrev, yPrev)
                ctx:lineTo(xCurr, yCurr)
                ctx:stroke()

                xPrev = xCurr
                yPrev = yCurr

                m = m + 1
            end
        end

        if bDisplay then
            local ro <const>,
            go <const>,
            bo <const> = 69 / 255, 106 / 255, 255 / 255
            local rd <const>,
            gd <const>,
            bd <const> = 171 / 255, 103 / 255, 0

            local xPrev = bPoints[1]
            local yPrev = bPoints[2]
            local m = 1
            while m < binCount do
                local t <const> = (m - 1.0) / bn1
                local u <const> = 1.0 - t

                local r <const> = u * ro + t * rd
                local g <const> = u * go + t * gd
                local b <const> = u * bo + t * bd

                local aseColor <const> = Color {
                    r = floor(r * 255 + 0.5),
                    g = floor(g * 255 + 0.5),
                    b = floor(b * 255 + 0.5),
                    a = 255 }

                local m2 <const> = m * 2
                local xCurr <const> = bPoints[1 + m2]
                local yCurr <const> = bPoints[2 + m2]

                ctx.color = aseColor
                ctx:beginPath()
                ctx:moveTo(xPrev, yPrev)
                ctx:lineTo(xCurr, yCurr)
                ctx:stroke()

                xPrev = xCurr
                yPrev = yCurr

                m = m + 1
            end
        end

        if hDisplay then
            ctx.color = Color { r = 0, g = 128, b = 255, a = 255 }
            ctx:beginPath()
            ctx:moveTo(hPoints[1], hPoints[2])
            local m = 1
            while m < binCount do
                local m2 <const> = m * 2
                ctx:lineTo(hPoints[1 + m2], hPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end

        if cDisplay then
            ctx.color = Color { r = 255, g = 128, b = 0, a = 255 }
            ctx:beginPath()
            ctx:moveTo(cPoints[1], cPoints[2])
            local m = 1
            while m < binCount do
                local m2 <const> = m * 2
                ctx:lineTo(cPoints[1 + m2], cPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end

        if lDisplay then
            ctx.color = Color { r = 255, g = 255, b = 255, a = 255 }
            ctx:beginPath()
            ctx:moveTo(lPoints[1], lPoints[2])
            local m = 1
            while m < binCount do
                local m2 <const> = m * 2
                ctx:lineTo(lPoints[1 + m2], lPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end
    end
}

dlg:button {
    id = "prevFrame",
    text = "&<",
    focus = false,
    onclick = function()
        activeFrIdx = 1 + (activeFrIdx - 2) % lenSpriteFrames
        app.frame = spriteFrames[activeFrIdx]
        app.refresh()
        active.triggerRepaint = true
        dlg:repaint()
    end
}

dlg:button {
    id = "nextFrame",
    text = "&>",
    focus = false,
    onclick = function()
        activeFrIdx = 1 + activeFrIdx % lenSpriteFrames
        app.frame = spriteFrames[activeFrIdx]
        app.refresh()
        active.triggerRepaint = true
        dlg:repaint()
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = false,
    wait = true,
    hand = true,
}