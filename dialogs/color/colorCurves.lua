dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local channels <const> = { "L", "A", "B", "Alpha" }

local idPrefixes <const> = {
    "lCurve",
    "aCurve",
    "bCurve",
    "tCurve"
}
local lenIdPrefixes <const> = #idPrefixes

local coPostfixes <const> = {
    [1] = "ap0x",
    [2] = "ap0y",
    [3] = "cp0x",
    [4] = "cp0y",
    [5] = "cp1x",
    [6] = "cp1y",
    [7] = "ap1x",
    [8] = "ap1y",
}
local lenCoPostfixes <const> = #coPostfixes

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

local curveColor = Color { r = 13, g = 13, b = 13 }
local gridColor <const> = Color { r = 128, g = 128, b = 128 }
if app.theme then
    local theme <const> = app.theme
    if theme then
        local themeColor <const> = theme.color
        if themeColor then
            local textColor <const> = themeColor.text --[[@as Color]]
            if textColor and textColor.alpha > 0 then
                curveColor = AseUtilities.aseColorCopy(textColor, "")
            end
        end
    end
end

local defaults <const> = {
    target = "ACTIVE",
    channel = "L",
    useRelative = false,
    printElapsed = false,
    alpSampleCount = 256,
    aAbsMin = -104.18850360397,
    aAbsRange = 208.37700720794,
    bAbsMin = -110.47816964815,
    bAbsRange = 220.9563392963
}

local dlg <const> = Dialog { title = "Color Curves" }

---@param srcImg Image
---@return table<integer, { l: number, a: number, b: number, alpha: number }> hexToLabDict
---@return number aMin
---@return number aMax
---@return number bMin
---@return number bMax
local function auditImage(srcImg)
    local sRgbaToLab <const> = Clr.sRgbToSrLab2
    local strbyte <const> = string.byte
    local clrnew <const> = Clr.new

    ---@type table<integer, {l: number, a: number, b: number, alpha: number}>
    local hexToLabDict <const> = {}
    local labZero <const> = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }
    local aMin = 2147483647
    local bMin = 2147483647
    local aMax = -2147483648
    local bMax = -2147483648

    local srcBytes <const> = srcImg.bytes
    local lenSrcImg <const> = srcImg.width * srcImg.height
    local j = 0
    while j < lenSrcImg do
        local j4 <const> = j * 4
        local r8 <const>, g8 <const>, b8 <const>, a8 <const> = strbyte(
            srcBytes, 1 + j4, 4 + j4)

        local h32 <const> = a8 << 0x18 | b8 << 0x10 | g8 << 0x08 | r8

        if not hexToLabDict[h32] then
            hexToLabDict[h32] = labZero
            if a8 > 0 then
                -- This could be placed outside of the a8 > 0 check if you
                -- wanted zero alpha colors to preserve their RGB components.
                -- See colorAdjust for consistency.
                local srgbSrc <const> = clrnew(
                    r8 / 255.0,
                    g8 / 255.0,
                    b8 / 255.0,
                    a8 / 255.0)
                local labSrc <const> = sRgbaToLab(srgbSrc)
                hexToLabDict[h32] = labSrc

                local aSrc <const> = labSrc.a
                local bSrc <const> = labSrc.b

                if aSrc < aMin then aMin = aSrc end
                if aSrc > aMax then aMax = aSrc end
                if bSrc < bMin then bMin = bSrc end
                if bSrc > bMax then bMax = bSrc end
            end
        end
        j = j + 1
    end

    return hexToLabDict, aMin, aMax, bMin, bMax
end

---@param coPostfix string
local function setInputFromColor(coPostfix)
    local site <const> = app.site
    local sprite <const> = site.sprite
    if not sprite then return end
    local frObj <const> = site.frame
    if not frObj then return end

    local lab <const> = AseUtilities.averageColor(sprite, frObj.frameNumber)

    local args <const> = dlg.data
    local channel <const> = args.channel --[[@as string]]

    local idPrefix = ""
    local val = 0.0
    if channel == "L" then
        idPrefix = idPrefixes[1]
        val = lab.l * 0.01
    elseif channel == "A" then
        idPrefix = idPrefixes[2]
        val = (lab.a - defaults.aAbsMin) / defaults.aAbsRange
    elseif channel == "B" then
        idPrefix = idPrefixes[3]
        val = (lab.b - defaults.bAbsMin) / defaults.bAbsRange
    elseif channel == "Alpha" then
        idPrefix = idPrefixes[4]
        val = lab.alpha
    end

    local id <const> = idPrefix .. "_" .. coPostfix
    dlg:modify { id = id, text = string.format("%.5f", val) }
    dlg:repaint()
end

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "channel",
    label = "Channel:",
    options = channels,
    option = defaults.channel,
    onchange = function()
        local args <const> = dlg.data
        local channel <const> = args.channel --[[@as string]]
        local bools <const> = {
            channel == "L",
            channel == "A",
            channel == "B",
            channel == "Alpha"
        }

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix <const> = idPrefixes[i]
            local bool <const> = bools[i]

            local j = 0
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix <const> = coPostfixes[j]
                local id <const> = idPrefix .. "_" .. coPostfix
                dlg:modify { id = id, visible = bool }
            end

            dlg:modify { id = idPrefix, visible = bool }
            dlg:modify { id = idPrefix .. "_easeFuncs", visible = bool }
            dlg:modify { id = idPrefix .. "_fliph", visible = bool }
            dlg:modify { id = idPrefix .. "_flipv", visible = bool }
            dlg:modify { id = idPrefix .. "_straight", visible = bool }
            dlg:modify { id = idPrefix .. "_parallel", visible = bool }
        end

        -- Get white and black point work with A and B, but they are hidden to
        -- conserve space and because how they work is not intuitive.
        local aorb <const> = bools[2] or bools[3]
        dlg:modify { id = "useRelative", visible = aorb }
        dlg:modify { id = "selGetLbIn", visible = not aorb }
        dlg:modify { id = "selGetUbIn", visible = not aorb }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useRelative",
    label = "Bounds:",
    text = "Relative",
    selected = defaults.useRelative,
    visible = defaults.channel == "A"
        or defaults.channel == "B"
}

dlg:newrow { always = false }

dlg:button {
    id = "selGetLbIn",
    label = "Get:",
    text = "BLAC&K",
    focus = false,
    onclick = function()
        setInputFromColor(coPostfixes[1])
    end
}

dlg:button {
    id = "selGetUbIn",
    text = "&WHITE",
    focus = false,
    onclick = function()
        setInputFromColor(coPostfixes[7])
    end
}

dlg:newrow { always = false }

local h = 0
while h < lenIdPrefixes do
    h = h + 1
    local currChannel <const> = channels[h]
    CanvasUtilities.graphBezier(
        dlg,
        idPrefixes[h],
        currChannel .. ":",
        128 // screenScale,
        128 // screenScale,
        defaults.channel == currChannel,
        true, true, true, true,
        5, 0.33333, 0.33333, 0.66667, 0.66667,
        curveColor, gridColor)
end

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        -- Begin timing the function elapsed.
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
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

        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local target <const> = args.target
            or defaults.target --[[@as string]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrames <const> = #frames

        -- If isSelect is true, then a new layer will be created.
        local srcLayer = site.layer --[[@as Layer]]

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frames, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
        else
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

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        -- Create target layer.
        -- Do not copy source layer blend mode.
        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end

            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.name = string.format(
                "%s Curves", srcLayerName)
        end)

        ---@type Vec2[][]
        local curveSamples <const> = {}
        local alpSampleCount <const> = defaults.alpSampleCount
        local samplesCompare <const> = function(a, b) return a < b.x end

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix <const> = idPrefixes[i]

            ---@type number[]
            local nums <const> = {}
            local j = 0
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix <const> = coPostfixes[j]
                local id <const> = idPrefix .. "_" .. coPostfix
                local num <const> = args[id] --[[@as number]]
                nums[j] = num
            end

            local co0 <const> = Vec2.new(nums[1], nums[2])
            local fh0 <const> = Vec2.new(nums[3], nums[4])
            local rh0 <const> = Vec2.new(0.0, co0.y)

            local co1 <const> = Vec2.new(nums[7], nums[8])
            local fh1 <const> = Vec2.new(1.0, co1.y)
            local rh1 <const> = Vec2.new(nums[5], nums[6])

            local kn0 <const> = Knot2.new(co0, fh0, rh0)
            local kn1 <const> = Knot2.new(co1, fh1, rh1)
            -- kn0:mirrorHandlesForward()
            -- kn1:mirrorHandlesBackward()

            local curve <const> = Curve2.new(false, { kn0, kn1 }, idPrefix)

            local totalLength <const>, arcLengths <const> = Curve2.arcLength(
                curve, alpSampleCount)
            local paramPoints <const> = Curve2.paramPoints(
                curve, totalLength, arcLengths, alpSampleCount)
            curveSamples[i] = paramPoints

            -- local strs = {}
            -- for n, v in ipairs(paramPoints) do
            --     strs[n] = n .. ": " .. Vec2.toJson(v)
            -- end
            -- print(table.concat(strs, ",\n"))
        end

        local useRelative <const> = args.useRelative --[[@as boolean]]
        local aAbsMin <const> = defaults.aAbsMin
        local aAbsMax <const> = -defaults.aAbsMin
        local aAbsRange <const> = aAbsMax - aAbsMin
        local aAbsDenom <const> = 1.0 / aAbsRange

        local bAbsMin <const> = defaults.bAbsMin
        local bAbsMax <const> = -defaults.bAbsMin
        local bAbsRange <const> = bAbsMax - bAbsMin
        local bAbsDenom <const> = 1.0 / bAbsRange

        -- Cache methods.
        local strfmt <const> = string.format
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local transact <const> = app.transaction
        local labTosRgb <const> = Clr.srLab2TosRgb
        local toHex <const> = Clr.toHex
        local bisectRight <const> = Utilities.bisectRight
        local min <const> = math.min
        local max <const> = math.max

        local k = 0
        while k < lenFrames do
            k = k + 1
            local srcFrame <const> = frames[k]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                local aMin = aAbsMin
                local aMax = aAbsMax
                local aRange = aAbsRange
                local aViable = true
                local aDenom = aAbsDenom

                local bMin = bAbsMin
                local bMax = bAbsMax
                local bRange = bAbsRange
                local bViable = true
                local bDenom = bAbsDenom

                local hexToLabDict = {}
                if useRelative then
                    -- For animations this will cause flickering because each
                    -- image is independent from the prior frame. Would need a
                    -- preliminary loop to build a dict across frames.
                    hexToLabDict, aMin, aMax, bMin, bMax = auditImage(srcImg)
                    aRange = aMax - aMin
                    aViable = aRange > 0.5
                    aDenom = 0.0
                    if aViable then aDenom = 1.0 / aRange end

                    bRange = bMax - bMin
                    bViable = bRange > 0.5
                    bDenom = 0.0
                    if bViable then bDenom = 1.0 / bRange end
                else
                    hexToLabDict, _, _, _, _ = auditImage(srcImg)
                end

                ---@type table<integer, integer>
                local srcToTrgDict <const> = {}
                for hex, lab in pairs(hexToLabDict) do
                    -- Lightness.
                    local lTrg = lab.l
                    local lx <const> = lab.l * 0.01
                    local lSamples <const> = curveSamples[1]
                    local li = bisectRight(
                        lSamples, lx, samplesCompare)
                    li = min(max(li, 1), alpSampleCount)
                    local ly <const> = lSamples[li].y
                    lTrg = ly * 100.0

                    -- A (green to magenta).
                    local aTrg = lab.a
                    if aViable then
                        local ax <const> = (lab.a - aMin) * aDenom
                        local aSamples <const> = curveSamples[2]
                        local ai = bisectRight(
                            aSamples, ax, samplesCompare)
                        ai = min(max(ai, 1), alpSampleCount)
                        local ay <const> = aSamples[ai].y
                        aTrg = ay * aRange + aMin
                    end

                    -- B (blue to yellow).
                    local bTrg = lab.b
                    if bViable then
                        local bx <const> = (lab.b - bMin) * bDenom
                        local bSamples <const> = curveSamples[3]
                        local bi = bisectRight(
                            bSamples, bx, samplesCompare)
                        bi = min(max(bi, 1), alpSampleCount)
                        local by <const> = bSamples[bi].y
                        bTrg = by * bRange + bMin
                    end

                    -- Transparency.
                    local tTrg = lab.alpha
                    local tx <const> = lab.alpha
                    local tSamples <const> = curveSamples[4]
                    local ti = bisectRight(
                        tSamples, tx, samplesCompare)
                    ti = min(max(ti, 1), alpSampleCount)
                    local ty <const> = tSamples[ti].y
                    tTrg = ty

                    local clrTrg <const> = labTosRgb(lTrg, aTrg, bTrg, tTrg)
                    srcToTrgDict[hex] = toHex(clrTrg)
                end

                local trgImg <const> = srcImg:clone()
                local trgPxItr <const> = trgImg:pixels()
                for trgPixel in trgPxItr do
                    trgPixel(srcToTrgDict[trgPixel()])
                end

                transact(strfmt("Levels Adjust %d", srcFrame),
                    function()
                        local trgCel <const> = activeSprite:newCel(
                            trgLayer, srcFrame, trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        if isSelect then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.layer = trgLayer
        app.refresh()

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
    id = "reset",
    text = "&RESET",
    focus = false,
    onclick = function()
        local init <const> = {
            0.0, 0.0,
            0.33333, 0.33333,
            0.66667, 0.66667,
            1.0, 1.0
        }
        local strfmt <const> = string.format

        local i = 0
        while i < lenIdPrefixes do
            i = i + 1
            local idPrefix <const> = idPrefixes[i]

            local j = 0
            while j < lenCoPostfixes do
                j = j + 1
                local coPostfix <const> = coPostfixes[j]
                local id <const> = idPrefix .. "_" .. coPostfix
                dlg:modify { id = id, text = strfmt("%.5f", init[j]) }
            end

            local easeFuncsId <const> = idPrefix .. "_easeFuncs"
            dlg:modify { id = easeFuncsId, option = "LINEAR" }
        end
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
    autoscrollbars = true,
    wait = false
}