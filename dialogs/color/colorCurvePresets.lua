dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local prsStrs = {
    "BEZIER",
    "LEVELS",
    "SINE_WAVE",
    "QUANTIZE"
}

local spaceStrs = {
    "S_RGB",
    "LINEAR_RGB"
}

local celsTargets = {
    "SELECTED",
    "ALL"
}

local defaults = {
    -- Sigmoid function?
    -- n <-- scalar * (tau * x - pi)
    -- s(n) <-- 1.0 / (1.0 + exp(-n))

    resolution = 16,
    spaceStr = "S_RGB",
    preset = "SINE_WAVE",
    useAlpha = false,
    celsTarget = "ALL",
    usePreview = true,

    -- Bezier fields:
    ap0x = 0.0,
    ap0y = 0.0,
    cp0x = 0.42,
    cp0y = 0.0,
    cp1x = 0.58,
    cp1y = 1.0,
    ap1x = 1.0,
    ap1y = 1.0,

    -- Levels fields:
    lbIn = 0,
    ubIn = 255,
    mid = 1.0,
    lbOut = 0,
    ubOut = 255,

    -- Quantize fields:
    quantization = 8,

    -- Sine Wave fields:
    phase = -90,
    freq = 0.5,
    sw_amp = 1.0,
    basis = 0.0
}

---@param x number
---@return number
local function stdToLin(x)
    if x <= 0.04045 then return x * 0.077399380804954 end
    return ((x + 0.055) * 0.9478672985782) ^ 2.4
end

---@param x number
---@return number
local function linToStd(x)
    if x <= 0.0031308 then return x * 12.92 end
    return (x ^ 0.41666666666667) * 1.055 - 0.055
end

---@param x number
---@param lbIn number
---@param ubIn number
---@param mid number
---@param lbOut number
---@param ubOut number
---@return number
local function levels(x, lbIn, ubIn, mid, lbOut, ubOut)
    local xRemapped = x - lbIn
    local rangeIn = ubIn - lbIn
    if rangeIn ~= 0.0 then
        xRemapped = (x - lbIn) / rangeIn
    end

    local xClamped = math.max(0.0, math.min(1.0, xRemapped))
    local xGamma = xClamped
    if mid ~= 0.0 then
        xGamma = xGamma ^ (1.0 / mid)
    end

    if ubOut >= lbOut then
        return lbOut + xGamma * (ubOut - lbOut)
    elseif ubOut < lbOut then
        return lbOut - xGamma * (lbOut - ubOut)
    end
    return xGamma
end

---@param x number
---@param levels integer
---@return number
local function quantize(x, levels)
    return math.max(0.0, math.min(1.0,
        (math.ceil(x * levels) - 1.0)
        / (levels - 1.0)))
end

---@param x number
---@param freq number
---@param phase number
---@param amp number
---@param basis number
---@return number
local function sineWave(x, freq, phase, amp, basis)
    return math.max(0.0, math.min(1.0,
        0.5 + 0.5 * (basis + amp * math.sin(
            6.2831853071796 * freq * x + phase))))
end

local dlg = Dialog { title = "Color Curve Presets" }

dlg:check {
    id = "usePreview",
    label = "Preview:",
    focus = true,
    selected = defaults.usePreview
}

dlg:newrow { always = false }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 2,
    max = 64,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:combobox {
    id = "spaceStr",
    label = "Space:",
    options = spaceStrs,
    option = defaults.spaceStr,
    visible = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "preset",
    label = "Preset:",
    options = prsStrs,
    option = defaults.preset,
    onchange = function()
        local prs = dlg.data.preset

        -- This would be a problem if you wanted the control
        -- point inputs for the compound widget to remain
        -- invisible.
        if prs == "BEZIER" then
            dlg:modify { id = "graphBezier", visible = true }
            dlg:modify { id = "graphBezier_ap0x", visible = true }
            dlg:modify { id = "graphBezier_ap0y", visible = true }
            dlg:modify { id = "graphBezier_cp0x", visible = true }
            dlg:modify { id = "graphBezier_cp0y", visible = true }
            dlg:modify { id = "graphBezier_cp1x", visible = true }
            dlg:modify { id = "graphBezier_cp1y", visible = true }
            dlg:modify { id = "graphBezier_ap1x", visible = true }
            dlg:modify { id = "graphBezier_ap1y", visible = true }
            dlg:modify { id = "graphBezier_easeFuncs", visible = true }
            dlg:modify { id = "graphBezier_flipv", visible = true }
            dlg:modify { id = "graphBezier_straight", visible = true }
            dlg:modify { id = "graphBezier_parallel", visible = true }
        else
            dlg:modify { id = "graphBezier", visible = false }
            dlg:modify { id = "graphBezier_ap0x", visible = false }
            dlg:modify { id = "graphBezier_ap0y", visible = false }
            dlg:modify { id = "graphBezier_cp0x", visible = false }
            dlg:modify { id = "graphBezier_cp0y", visible = false }
            dlg:modify { id = "graphBezier_cp1x", visible = false }
            dlg:modify { id = "graphBezier_cp1y", visible = false }
            dlg:modify { id = "graphBezier_ap1x", visible = false }
            dlg:modify { id = "graphBezier_ap1y", visible = false }
            dlg:modify { id = "graphBezier_easeFuncs", visible = false }
            dlg:modify { id = "graphBezier_flipv", visible = false }
            dlg:modify { id = "graphBezier_straight", visible = false }
            dlg:modify { id = "graphBezier_parallel", visible = false }
        end

        if prs == "LEVELS" then
            dlg:modify { id = "lbIn", visible = true }
            dlg:modify { id = "ubIn", visible = true }
            dlg:modify { id = "mid", visible = true }
            dlg:modify { id = "lbOut", visible = true }
            dlg:modify { id = "ubOut", visible = true }
            dlg:modify { id = "selGetLbIn", visible = true }
            dlg:modify { id = "selGetUbIn", visible = true }
        else
            dlg:modify { id = "lbIn", visible = false }
            dlg:modify { id = "ubIn", visible = false }
            dlg:modify { id = "mid", visible = false }
            dlg:modify { id = "lbOut", visible = false }
            dlg:modify { id = "ubOut", visible = false }
            dlg:modify { id = "selGetLbIn", visible = false }
            dlg:modify { id = "selGetUbIn", visible = false }
        end

        if prs == "QUANTIZE" then
            dlg:modify { id = "quantization", visible = true }
        else
            dlg:modify { id = "quantization", visible = false }
        end

        if prs == "SINE_WAVE" then
            dlg:modify { id = "phase", visible = true }
            dlg:modify { id = "freq", visible = true }
            dlg:modify { id = "sw_amp", visible = true }
            dlg:modify { id = "basis", visible = true }
        else
            dlg:modify { id = "phase", visible = false }
            dlg:modify { id = "freq", visible = false }
            dlg:modify { id = "sw_amp", visible = false }
            dlg:modify { id = "basis", visible = false }
        end
    end
}

dlg:newrow { always = false }

CanvasUtilities.graphBezier(
    dlg, "graphBezier", "Bezier:",
    128 // screenScale, 128 // screenScale,
    defaults.preset == "BEZIER",
    true, true, true, true, 5,
    defaults.cp0x, defaults.cp0y,
    defaults.cp1x, defaults.cp1y,
    app.theme.color.text,
    Color { r = 128, g = 128, b = 128 })

dlg:slider {
    id = "lbIn",
    label = "Inputs:",
    min = 0,
    max = 255,
    value = defaults.lbIn,
    visible = defaults.preset == "LEVELS"
}

dlg:slider {
    id = "ubIn",
    min = 0,
    max = 255,
    value = defaults.ubIn,
    visible = defaults.preset == "LEVELS"
}

dlg:newrow { always = false }

dlg:button {
    id = "selGetLbIn",
    text = "B&LACK",
    focus = false,
    visible = defaults.preset == "LEVELS",
    onclick = function()
        local site = app.site
        local sprite = site.sprite
        if not sprite then return end
        local frame = site.frame
        if not frame then return end
        local lab = AseUtilities.averageColor(sprite, frame)
        local gray = math.floor(lab.l * 2.55 + 0.5)
        dlg:modify { id = "lbIn", value = gray }
    end
}

dlg:button {
    id = "selGetUbIn",
    text = "&WHITE",
    focus = false,
    visible = defaults.preset == "LEVELS",
    onclick = function()
        local site = app.site
        local sprite = site.sprite
        if not sprite then return end
        local frame = site.frame
        if not frame then return end
        local lab = AseUtilities.averageColor(sprite, frame)
        local gray = math.floor(lab.l * 2.55 + 0.5)
        dlg:modify { id = "ubIn", value = gray }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "mid",
    label = "Midpoint:",
    text = string.format("%.1f", defaults.mid),
    decimals = 5,
    visible = defaults.preset == "LEVELS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "lbOut",
    label = "Outputs:",
    min = 0,
    max = 255,
    value = defaults.lbOut,
    visible = defaults.preset == "LEVELS"
}

dlg:slider {
    id = "ubOut",
    min = 0,
    max = 255,
    value = defaults.ubOut,
    visible = defaults.preset == "LEVELS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 2,
    max = 32,
    value = defaults.quantization,
    visible = defaults.preset == "QUANTIZE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "phase",
    label = "Phase:",
    min = -90,
    max = 90,
    value = defaults.phase,
    visible = defaults.preset == "SINE_WAVE"
}

dlg:newrow { always = false }

dlg:number {
    id = "freq",
    label = "Frequency:",
    text = string.format("%.1f", defaults.freq),
    decimals = 5,
    visible = defaults.preset == "SINE_WAVE"
}

dlg:newrow { always = false }

dlg:number {
    id = "sw_amp",
    label = "Amplitude:",
    text = string.format("%.1f", defaults.sw_amp),
    decimals = 5,
    visible = defaults.preset == "SINE_WAVE"
}

dlg:newrow { always = false }

dlg:number {
    id = "basis",
    label = "Basis:",
    text = string.format("%.1f", defaults.basis),
    decimals = 5,
    visible = defaults.preset == "SINE_WAVE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "celsTarget",
    label = "Target:",
    options = celsTargets,
    option = defaults.celsTarget
}

dlg:newrow { always = false }

dlg:check {
    id = "useRed",
    label = "Channels:",
    text = "&R",
    selected = app.preferences.new_file.color_mode == ColorMode.RGB
}

dlg:check {
    id = "useGreen",
    text = "&G",
    selected = app.preferences.new_file.color_mode == ColorMode.RGB
}

dlg:check {
    id = "useBlue",
    text = "&B",
    selected = app.preferences.new_file.color_mode == ColorMode.RGB
}

dlg:check {
    id = "useAlpha",
    text = "&A",
    selected = defaults.useAlpha
}

dlg:check {
    id = "useGray",
    text = "&K",
    selected = app.preferences.new_file.color_mode == ColorMode.GRAY
}

dlg:check {
    id = "useIdx",
    text = "&I",
    selected = app.preferences.new_file.color_mode == ColorMode.INDEXED
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local args = dlg.data

        local channels = 0x0
        if args.useRed then channels = channels | FilterChannels.RED end
        if args.useGreen then channels = channels | FilterChannels.GREEN end
        if args.useBlue then channels = channels | FilterChannels.BLUE end
        if args.useAlpha then channels = channels | FilterChannels.ALPHA end
        if args.useGray then channels = channels | FilterChannels.GRAY end
        if args.useIndex then channels = channels | FilterChannels.INDEX end

        local func = function(x)
            return math.max(0.0, math.min(1.0, x))
        end

        local preset = args.preset
        if preset == "BEZIER" then
            local ap0x = args.graphBezier_ap0x or defaults.ap0x --[[@as number]]
            local ap0y = args.graphBezier_ap0y or defaults.ap0y --[[@as number]]
            local cp0x = args.graphBezier_cp0x or defaults.cp0x --[[@as number]]
            local cp0y = args.graphBezier_cp0y or defaults.cp0y --[[@as number]]
            local cp1x = args.graphBezier_cp1x or defaults.cp1x --[[@as number]]
            local cp1y = args.graphBezier_cp1y or defaults.cp1y --[[@as number]]
            local ap1x = args.graphBezier_ap1x or defaults.ap1x --[[@as number]]
            local ap1y = args.graphBezier_ap1y or defaults.ap1y --[[@as number]]

            local curve = Curve2.new(false, {
                Knot2.new(
                    Vec2.new(ap0x, ap0y),
                    Vec2.new(cp0x, cp0y),
                    Vec2.new(0.0, ap0y)),
                Knot2.new(
                    Vec2.new(ap1x, ap1y),
                    Vec2.new(1.0, ap1y),
                    Vec2.new(cp1x, cp1y))
            })
            local totalLength, arcLengths = Curve2.arcLength(curve, 96)
            local paramPoints = Curve2.paramPoints(curve, totalLength, arcLengths, 96)
            local comparator = function(a, b) return a < b.x end

            func = function(x)
                if x <= ap0x then return ap0y, x end
                if x >= ap1x then return ap1y, x end
                local nearestIndex = Utilities.bisectRight(paramPoints, x, comparator)
                local point = paramPoints[nearestIndex]
                return point.y, point.x
            end
        elseif preset == "LEVELS" then
            local lbIn255 = args.lbIn or defaults.lbIn --[[@as integer]]
            local ubIn255 = args.ubIn or defaults.ubIn --[[@as integer]]
            local mid = args.mid or defaults.mid --[[@as integer]]
            local lbOut255 = args.lbOut or defaults.lbOut --[[@as integer]]
            local ubOut255 = args.ubOut or defaults.ubOut --[[@as integer]]

            local lbIn = lbIn255 / 255.0
            local ubIn = ubIn255 / 255.0
            local midVrf = math.max(0.000001, math.abs(mid))
            local lbOut = lbOut255 / 255.0
            local ubOut = ubOut255 / 255.0

            -- Swap if flipped.
            if ubIn < lbIn then lbIn, ubIn = ubIn, lbIn end

            func = function(x)
                return levels(x, lbIn, ubIn, midVrf, lbOut, ubOut)
            end
        elseif preset == "SINE_WAVE" then
            local freq = args.freq or defaults.freq --[[@as number]]
            local phaseDeg = args.phase or defaults.phase --[[@as integer]]
            local amp = args.sw_amp or defaults.sw_amp --[[@as number]]
            local basis = args.basis or defaults.basis --[[@as number]]

            local phaseRad = 0.017453292519943 * phaseDeg
            func = function(x)
                return sineWave(x, freq, phaseRad, amp, basis)
            end
        elseif preset == "QUANTIZE" then
            local levels = args.quantization or defaults.quantization --[[@as integer]]
            if levels > 1 then
                func = function(x)
                    return quantize(x, levels)
                end
            end
        end

        ---@type Point[]
        local points = {}
        local res = args.resolution or defaults.resolution --[[@as integer]]
        local tox = 1.0
        if res > 1 then
            tox = 1.0 / (res - 1.0)
        end

        local spaceStr = args.spaceStr or defaults.spaceStr --[[@as string]]
        if spaceStr == "LINEAR_RGB" then
            local i = 0
            while i < res do
                local xStd = i * tox
                local yLin, xLin = func(stdToLin(xStd))
                local yStd = linToStd(yLin)
                if xLin then
                    xStd = linToStd(xLin)
                end
                i = i + 1
                points[i] = Point(
                    math.floor(xStd * 255.0 + 0.5),
                    math.floor(yStd * 255.0 + 0.5))
            end
        else
            local i = 0
            while i < res do
                local x = i * tox
                local y, xp = func(x)
                if xp then x = xp end
                i = i + 1
                points[i] = Point(
                    math.floor(x * 255.0 + 0.5),
                    math.floor(y * 255.0 + 0.5))
            end
        end

        -- The toggle for selected vs. all is held in preferences
        -- as an integer or enumeration constant. Selected is the
        -- default as element zero. See
        -- https://github.com/aseprite/aseprite/blob/main/src/app/commands/filters/cels_target.h
        local target = args.celsTarget or defaults.celsTarget --[[@as string]]
        local usePreview = args.usePreview --[[@as boolean]]
        local targetEnum = 0
        if target == "ALL" then
            targetEnum = 1
        end
        local oldCelsTarget = app.preferences.filters.cels_target
        app.preferences.filters.cels_target = targetEnum

        app.command.ColorCurve {
            ui = usePreview,
            channels = channels,
            curve = points
        }

        app.preferences.filters.cels_target = oldCelsTarget
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