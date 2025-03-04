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
    lDisplay = true,
    rDisplay = true,
    gDisplay = true,
    bDisplay = true,
    gridCount = 7
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
    id = "rDisplay",
    text = "&R",
    selected = defaults.rDisplay,
    focus = false,
    onclick = function()
        dlg:repaint()
    end
}

dlg:check {
    id = "gDisplay",
    text = "&G",
    selected = defaults.gDisplay,
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

dlg:canvas {
    id = "histogram",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onpaint = function(event)
        local ctx <const> = event.context
        local wCanvas <const> = ctx.width
        local hCanvas <const> = ctx.height
        if wCanvas <= 1 or hCanvas <= 1 then return end

        ctx.antialias = true

        local wn1 <const> = wCanvas - 1.0
        local hn1 <const> = hCanvas - 1.0

        ---@type table<integer, integer>
        local abgr32Tally <const> = {}
        flat:drawSprite(sprite, activeFrIdx)
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
            local palette <const> = sprite.palettes[1]
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

        ---@type table<integer, integer>
        local rBins <const> = {}
        ---@type table<integer, integer>
        local gBins <const> = {}
        ---@type table<integer, integer>
        local bBins <const> = {}
        ---@type table<integer, integer>
        local lBins <const> = {}

        local rgbMaxFreq = -2147483648
        local lMaxFreq = -2147483648

        local j = 0
        while j < 256 do
            j = j + 1
            rBins[j] = 0
            gBins[j] = 0
            bBins[j] = 0
            lBins[j] = 0
        end

        for abgr32, tally in pairs(abgr32Tally) do
            local t8 <const> = (abgr32 >> 0x18) & 0xff
            if t8 > 0 then
                local r8 <const> = (abgr32 >> 0x00) & 0xff
                local g8 <const> = (abgr32 >> 0x08) & 0xff
                local b8 <const> = (abgr32 >> 0x10) & 0xff
                local l8 <const> = (r8 * 30 + g8 * 59 + b8 * 11) // 100

                local rFreq <const> = rBins[1 + r8] + tally
                local gFreq <const> = gBins[1 + g8] + tally
                local bFreq <const> = bBins[1 + b8] + tally
                local lFreq <const> = lBins[1 + l8] + tally

                rBins[1 + r8] = rFreq
                gBins[1 + g8] = gFreq
                bBins[1 + b8] = bFreq
                lBins[1 + l8] = lFreq

                if rFreq > rgbMaxFreq then rgbMaxFreq = rFreq end
                if gFreq > rgbMaxFreq then rgbMaxFreq = gFreq end
                if bFreq > rgbMaxFreq then rgbMaxFreq = bFreq end
                if lFreq > lMaxFreq then lMaxFreq = lFreq end
            end
        end

        ---@type number[]
        local rPoints <const> = {}
        ---@type number[]
        local gPoints <const> = {}
        ---@type number[]
        local bPoints <const> = {}
        ---@type number[]
        local lPoints <const> = {}

        local rgbScalar <const> = rgbMaxFreq > 1
            and 1.0 / (rgbMaxFreq - 1.0)
            or 0.0
        local lScalar <const> = lMaxFreq > 1
            and 1.0 / (lMaxFreq - 1.0)
            or 0.0

        local k = 0
        while k < 256 do
            local x <const> = wn1 * (k / 255.0)

            local rFreq <const> = rBins[1 + k]
            local gFreq <const> = gBins[1 + k]
            local bFreq <const> = bBins[1 + k]
            local lFreq <const> = lBins[1 + k]

            local ry <const> = hn1 * (1.0 - rFreq * rgbScalar)
            local gy <const> = hn1 * (1.0 - gFreq * rgbScalar)
            local by <const> = hn1 * (1.0 - bFreq * rgbScalar)
            local ly <const> = hn1 * (1.0 - lFreq * lScalar)

            local k2 <const> = k * 2
            rPoints[1 + k2], rPoints[2 + k2] = x, ry
            gPoints[1 + k2], gPoints[2 + k2] = x, gy
            bPoints[1 + k2], bPoints[2 + k2] = x, by
            lPoints[1 + k2], lPoints[2 + k2] = x, ly

            k = k + 1
        end

        ctx.strokeWidth = 1
        ctx.color = Color { r = 85, g = 85, b = 85, a = 255 }
        local gridCount <const> = defaults.gridCount
        local i = 0
        while i < gridCount do
            local fac <const> = i / (gridCount - 1.0)
            local x <const> = fac * wn1

            ctx:beginPath()
            ctx:moveTo(x, 0)
            ctx:lineTo(x, hn1)
            ctx:stroke()

            local y <const> = fac * hn1
            ctx:beginPath()
            ctx:moveTo(0, y)
            ctx:lineTo(wn1, y)
            ctx:stroke()

            i = i + 1
        end

        ctx.strokeWidth = defaults.strokeWeight

        local args <const> = dlg.data
        local rDisplay <const> = args.rDisplay --[[@as boolean]]
        local gDisplay <const> = args.gDisplay --[[@as boolean]]
        local bDisplay <const> = args.bDisplay --[[@as boolean]]
        local lDisplay <const> = args.lDisplay --[[@as boolean]]

        if bDisplay then
            ctx.color = Color { r = 0, g = 0, b = 255, a = 255 }
            ctx:beginPath()
            ctx:moveTo(bPoints[1], bPoints[2])
            local m = 1
            while m < 256 do
                local m2 <const> = m * 2
                ctx:lineTo(bPoints[1 + m2], bPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end

        if rDisplay then
            ctx.color = Color { r = 255, g = 0, b = 0, a = 255 }
            ctx:beginPath()
            ctx:moveTo(rPoints[1], rPoints[2])
            local m = 1
            while m < 256 do
                local m2 <const> = m * 2
                ctx:lineTo(rPoints[1 + m2], rPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end

        if gDisplay then
            ctx.color = Color { r = 0, g = 255, b = 0, a = 255 }
            ctx:beginPath()
            ctx:moveTo(gPoints[1], gPoints[2])
            local m = 1
            while m < 256 do
                local m2 <const> = m * 2
                ctx:lineTo(gPoints[1 + m2], gPoints[2 + m2])
                m = m + 1
            end
            ctx:stroke()
        end

        if lDisplay then
            ctx.color = Color { r = 255, g = 255, b = 255, a = 255 }
            ctx:beginPath()
            ctx:moveTo(lPoints[1], lPoints[2])
            local m = 1
            while m < 256 do
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
        dlg:repaint()
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
    wait = true,
    hand = true,
}