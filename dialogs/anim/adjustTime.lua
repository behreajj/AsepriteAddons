dofile("../../support/aseutilities.lua")
dofile("../../support/canvasutilities.lua")
dofile("../../support/clrgradient.lua")

local modes <const> = {
    "ADD",
    "DIVIDE",
    "MIX",
    "MULTIPLY",
    "REMAP",
    "SET",
    "SUBTRACT"
}

local targets <const> = { "ACTIVE", "ALL", "MANUAL", "RANGE" }

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
    mode = "SET",
    alpSampleCount = 96,

    frameOrig = 1,
    durOrig = 100,

    frameDest = 1,
    durDest = 100,

    target = "ALL",
    rangeStr = "",
    strExample = "4,6:9,13",

    lbDur = 0.001,
    ubDur = 65.535,
}

---Durations need to be rounded after scaling due to precision differences
---between seconds (internal) and milliseconds (UI).
---@param duration number
---@param scalar number
---@return number
---@nodiscard
local function mulRoundDur(duration, scalar)
    local durNew <const> = duration * scalar
    local durNewMs <const> = math.floor(durNew * 1000.0 + 0.5)
    return math.min(math.max(durNewMs * 0.001, 0.001), 65.535)
end

---@return integer frIdx
---@return number duration
local function getDurAtFrame()
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return 1, 0.1 end

    local docPrefs <const> = app.preferences.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local frIdx = frameUiOffset + 1
    local activeFrame <const> = site.frame
    if activeFrame then
        frIdx = activeFrame.frameNumber + frameUiOffset
        return frIdx, activeFrame.duration
    end
    return frIdx, 0.1
end

local dlg <const> = Dialog { title = "Adjust Time" }

dlg:combobox {
    id = "mode",
    label = "Mode:",
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local target <const> = args.target --[[@as string]]
        local isManual <const> = target == "MANUAL"
        local isMix <const> = mode == "MIX"
        local notRemap <const> = mode ~= "REMAP"
        local isOp <const> = not isMix

        dlg:modify { id = "easeCurve", visible = isMix }
        dlg:modify { id = "easeCurve_easeFuncs", visible = isMix }

        dlg:modify { id = "frameOrig", visible = isMix }
        dlg:modify { id = "durOrig", visible = isMix }
        dlg:modify { id = "getOrig", visible = isMix }

        dlg:modify { id = "frameDest", visible = isMix }
        dlg:modify { id = "durDest", visible = isMix }
        dlg:modify { id = "getDest", visible = isMix }

        dlg:modify { id = "opNum", visible = isOp }
        dlg:modify { id = "target", visible = isOp and notRemap }
        dlg:modify { id = "rangeStr", visible = isOp and notRemap and isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "getOrig",
    label = "Get:",
    text = "&FROM",
    onclick = function()
        local frIdx <const>, dur <const> = getDurAtFrame()
        dlg:modify { id = "frameOrig", text = string.format("%d", frIdx) }
        dlg:modify {
            id = "durOrig",
            text = string.format("%d", math.floor(1000.0 * dur + 0.5))
        }
    end,
    visible = defaults.mode == "MIX"
}

dlg:button {
    id = "getDest",
    text = "&TO",
    onclick = function()
        local frIdx <const>, dur <const> = getDurAtFrame()
        dlg:modify { id = "frameDest", text = string.format("%d", frIdx) }
        dlg:modify {
            id = "durDest",
            text = string.format("%d", math.floor(1000.0 * dur + 0.5))
        }
    end,
    visible = defaults.mode == "MIX"
}

dlg:newrow { always = false }

dlg:number {
    id = "frameOrig",
    label = "From:",
    text = string.format("%d", defaults.frameOrig),
    decimals = 0,
    focus = false,
    visible = defaults.mode == "MIX"
}

dlg:number {
    id = "durOrig",
    label = "Duration:",
    text = string.format("%d", defaults.durOrig),
    decimals = 0,
    focus = false,
    visible = defaults.mode == "MIX"
}

dlg:newrow { always = false }

dlg:number {
    id = "frameDest",
    label = "To:",
    text = string.format("%d", defaults.frameDest),
    decimals = 0,
    focus = false,
    visible = defaults.mode == "MIX"
}

dlg:number {
    id = "durDest",
    label = "Duration:",
    text = string.format("%d", defaults.durDest),
    decimals = 0,
    focus = false,
    visible = defaults.mode == "MIX"
}

CanvasUtilities.graphBezier(
    dlg, "easeCurve", "Easing:",
    128 // screenScale,
    128 // screenScale,
    defaults.mode == "MIX",
    false, false, true, false,
    5, 0.25, 0.1, 0.25, 1.0,
    curveColor, gridColor)

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    focus = false,
    visible = defaults.mode ~= "MIX"
        and defaults.mode ~= "REMAP",
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local isManual <const> = target == "MANUAL"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Frames:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.mode ~= "MIX"
        and defaults.mode ~= "REMAP"
        and defaults.target == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:number {
    id = "opNum",
    label = "Number:",
    text = string.format("%d",
        (defaults.mode == "ADD" or defaults.mode == "SUBTRACT")
        and 0 or ((defaults.mode == "MULTIPLY" or defaults.mode == "DIVIDE")
            and 1 or 100)),
    decimals = 0,
    focus = defaults.mode ~= "MIX",
    visible = defaults.mode ~= "MIX"
}

dlg:newrow { always = false }

dlg:button {
    id = "heatMap",
    text = "&HEAT MAP",
    label = "Diagnostic:",
    focus = false,
    onclick = function()
        local sprite <const> = app.site.sprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local frObjs <const> = sprite.frames
        local lenFrames <const> = #frObjs

        ---@type number[]
        local durations <const> = {}
        local durMin = 2147483647
        local durMax = -2147483648

        local h = 0
        while h < lenFrames do
            h = h + 1
            local frObj <const> = frObjs[h]
            local dur <const> = frObj.duration
            durations[h] = dur
            if dur < durMin then durMin = dur end
            if dur > durMax then durMax = dur end
        end

        local durRange = durMax - durMin
        if durRange < 0.000001 then
            app.alert {
                title = "Error",
                text = "No difference in frame durations."
            }
            return
        end

        local durToFac <const> = 1.0 / durRange

        local easing <const> = Clr.mixlRgb
        local cgeval <const> = ClrGradient.eval
        local clrToAseColor <const> = AseUtilities.clrToAseColor

        local leaves <const> = AseUtilities.getLayerHierarchy(
            sprite, true, true, true, true)
        local lenLeaves <const> = #leaves

        local t <const> = 2.0 / 3.0
        local cg <const> = ClrGradient.new({
            ClrKey.new(0.0, Clr.new(0.266667, 0.003922, 0.329412, t)),
            ClrKey.new(0.06666667, Clr.new(0.282353, 0.100131, 0.420654, t)),
            ClrKey.new(0.13333333, Clr.new(0.276078, 0.184575, 0.487582, t)),
            ClrKey.new(0.2, Clr.new(0.254902, 0.265882, 0.527843, t)),
            ClrKey.new(0.26666667, Clr.new(0.221961, 0.340654, 0.549281, t)),
            ClrKey.new(0.33333333, Clr.new(0.192157, 0.405229, 0.554248, t)),
            ClrKey.new(0.4, Clr.new(0.164706, 0.469804, 0.556863, t)),
            ClrKey.new(0.46666667, Clr.new(0.139869, 0.534379, 0.553464, t)),
            ClrKey.new(0.53333333, Clr.new(0.122092, 0.595033, 0.543007, t)),
            ClrKey.new(0.6, Clr.new(0.139608, 0.658039, 0.516863, t)),
            ClrKey.new(0.66666667, Clr.new(0.210458, 0.717647, 0.471895, t)),
            ClrKey.new(0.73333333, Clr.new(0.326797, 0.773595, 0.407582, t)),
            ClrKey.new(0.8, Clr.new(0.477647, 0.821961, 0.316863, t)),
            ClrKey.new(0.86666667, Clr.new(0.648366, 0.858039, 0.208889, t)),
            ClrKey.new(0.93333333, Clr.new(0.825098, 0.884967, 0.114771, t)),
            ClrKey.new(1.0, Clr.new(0.992157, 0.905882, 0.145098, t))
        })

        app.transaction("Time Heat Map", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local dur <const> = durations[i]
                local fac <const> = (dur - durMin) * durToFac
                local clr <const> = cgeval(cg, fac, easing)
                local ase <const> = clrToAseColor(clr)
                local j = 0
                while j < lenLeaves do
                    j = j + 1
                    local cel <const> = leaves[j]:cel(i)
                    if cel then
                        cel.color = ase
                    end
                end
            end
        end)

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local lbDur <const> = defaults.lbDur
        local ubDur <const> = defaults.ubDur

        local abs <const> = math.abs
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local eval <const> = Curve2.eval

        local frObjs <const> = activeSprite.frames
        local lenFrObjs <const> = #frObjs

        local args <const> = dlg.data
        local mode <const> = args.mode
        if mode == "MIX" then
            local docPrefs <const> = app.preferences.document(activeSprite)
            local tlPrefs <const> = docPrefs.timeline
            local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

            local frIdxOrig <const> = args.frameOrig
                or defaults.frameOrig --[[@as integer]]
            local frIdxDest <const> = args.frameDest
                or defaults.frameDest --[[@as integer]]
            local durOrigMillis <const> = args.durOrig
                or defaults.durOrig --[[@as integer]]
            local durDestMillis <const> = args.durDest
                or defaults.durDest --[[@as integer]]

            local durOrig = math.min(math.max(
                durOrigMillis * 0.001, 0.001), 65.535)
            local durDest = math.min(math.max(
                durDestMillis * 0.001, 0.001), 65.535)

            local frIdxOrigVerif = math.min(math.max(
                frIdxOrig - frameUiOffset, 1), lenFrObjs)
            local frIdxDestVerif = math.min(math.max(
                frIdxDest - frameUiOffset, 1), lenFrObjs)

            -- Unlike tween functions, do not assume all sprite
            -- frames when origin and destination are equal.
            if frIdxDestVerif < frIdxOrigVerif then
                frIdxOrigVerif, frIdxDestVerif = frIdxDestVerif, frIdxOrigVerif
                durOrig, durDest = durDest, durOrig
            end
            local countFrames <const> = 1 + frIdxDestVerif - frIdxOrigVerif

            local ap0x <const> = args.easeCurve_ap0x --[[@as number]]
            local ap0y <const> = args.easeCurve_ap0y --[[@as number]]
            local cp0x <const> = args.easeCurve_cp0x --[[@as number]]
            local cp0y <const> = args.easeCurve_cp0y --[[@as number]]
            local cp1x <const> = args.easeCurve_cp1x --[[@as number]]
            local cp1y <const> = args.easeCurve_cp1y --[[@as number]]
            local ap1x <const> = args.easeCurve_ap1x --[[@as number]]
            local ap1y <const> = args.easeCurve_ap1y --[[@as number]]

            local kn0 <const> = Knot2.new(
                Vec2.new(ap0x, ap0y),
                Vec2.new(cp0x, cp0y),
                Vec2.new(0.0, ap0y))
            local kn1 <const> = Knot2.new(
                Vec2.new(ap1x, ap1y),
                Vec2.new(1.0, ap1y),
                Vec2.new(cp1x, cp1y))
            local curve = Curve2.new(false, { kn0, kn1 }, "pos easing")

            local alpSampleCount <const> = defaults.alpSampleCount
            local totalLength <const>, arcLengths <const> = Curve2.arcLength(
                curve, alpSampleCount)
            local samples <const> = Curve2.paramPoints(
                curve, totalLength, arcLengths, alpSampleCount)

            local jToFac <const> = countFrames > 1
                and 1.0 / (countFrames - 1.0) or 0.0
            local jFacOff <const> = countFrames > 1 and 0.0 or 0.5

            app.transaction("Tween Duration", function()
                local j = 0
                while j < countFrames do
                    local frObj <const> = frObjs[frIdxOrigVerif + j]
                    local fac <const> = j * jToFac + jFacOff
                    local t = eval(curve, fac).x
                    if fac > 0.000001 and fac < 0.999999 then
                        local tScale <const> = t * (alpSampleCount - 1)
                        local tFloor <const> = floor(tScale)
                        local tFrac <const> = tScale - tFloor
                        local left <const> = samples[1 + tFloor].y
                        local right <const> = samples[2 + tFloor].y
                        t = (1.0 - tFrac) * left + tFrac * right
                    end
                    local dur <const> = (1.0 - t) * durOrig + t * durDest
                    frObj.duration = dur

                    j = j + 1
                end
            end)
        elseif mode == "REMAP" then
            local opNum <const> = args.opNum --[[@as number]]
            local opNumVerif <const> = math.floor(math.abs(opNum) + 0.5)
            if opNumVerif < lenFrObjs then
                app.alert {
                    title = "Error",
                    text = "Each frame must be at least 1 millisecond."
                }
                return
            end
            local opNumSecs <const> = opNumVerif * 0.001

            local totalDuration = 0.0
            local i = 0
            while i < lenFrObjs do
                i = i + 1
                local frObj <const> = frObjs[i]
                local duration <const> = frObj.duration
                totalDuration = totalDuration + duration
            end

            local ratio <const> = opNumSecs / totalDuration

            app.transaction("Remap Duration", function()
                local j = 0
                while j < lenFrObjs do
                    j = j + 1
                    local frObj <const> = frObjs[j]
                    -- frObj.duration = frObj.duration * ratio
                    frObj.duration = mulRoundDur(frObj.duration, ratio)
                end
            end)
        else
            local target <const> = args.target
                or defaults.target --[[@as string]]
            local opNum <const> = args.opNum --[[@as number]]
            local rangeStr <const> = args.rangeStr
                or defaults.rangeStr --[[@as string]]

            local frIdcs <const> = Utilities.flatArr2(
                AseUtilities.getFrames(activeSprite, target, false, rangeStr, nil))
            local lenFrIdcs <const> = #frIdcs

            if mode == "ADD" then
                app.transaction("Add Duration", function()
                    local i = 0
                    while i < lenFrIdcs do
                        i = i + 1
                        local frObj <const> = frObjs[frIdcs[i]]
                        local durms <const> = floor(frObj.duration * 1000.0 + 0.5)
                        frObj.duration = min(max((durms + opNum) * 0.001, lbDur), ubDur)
                    end
                end)
            elseif mode == "SUBTRACT" then
                app.transaction("Subtract Duration", function()
                    local i = 0
                    while i < lenFrIdcs do
                        i = i + 1
                        local frObj <const> = frObjs[frIdcs[i]]
                        local durms <const> = floor(frObj.duration * 1000.0 + 0.5)
                        frObj.duration = min(max((durms - opNum) * 0.001, lbDur), ubDur)
                    end
                end)
            elseif mode == "MULTIPLY" then
                local opNumAbs <const> = abs(opNum)
                app.transaction("Multiply Duration", function()
                    local i = 0
                    while i < lenFrIdcs do
                        i = i + 1
                        local frObj <const> = frObjs[frIdcs[i]]
                        frObj.duration = min(max(frObj.duration * opNumAbs, lbDur), ubDur)
                    end
                end)
            elseif mode == "DIVIDE" then
                local opNumAbs <const> = abs(opNum)
                app.transaction("Divide Duration", function()
                    local i = 0
                    while i < lenFrIdcs do
                        i = i + 1
                        local frObj <const> = frObjs[frIdcs[i]]
                        frObj.duration = min(max(frObj.duration / opNumAbs, lbDur), ubDur)
                    end
                end)
            else
                -- Default to set.
                local opNumVrf <const> = min(max(abs(opNum) * 0.001, lbDur), ubDur)
                app.transaction("Set Duration", function()
                    local i = 0
                    while i < lenFrIdcs do
                        i = i + 1
                        frObjs[frIdcs[i]].duration = opNumVrf
                    end
                end) -- End set transaction.
            end      -- End operation.
        end          -- End mix check.

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