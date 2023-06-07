dofile("../../support/canvasutilities.lua")

local screenScale = app.preferences.general.screen_scale

local prsStrs = {
    "BEZIER",
    "GAMMA",
    "LINEAR",
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
    ap0x = 0.0,
    ap0y = 0.0,
    cp0x = 0.42,
    cp0y = 0.0,
    cp1x = 0.58,
    cp1y = 1.0,
    ap1x = 1.0,
    ap1y = 1.0,
    phase = -90,
    freq = 0.5,
    sw_amp = 1.0,
    basis = 0.0,
    slope = 1.0,
    intercept = 0.0,
    gamma = 2.2,
    amplitude = 1.0,
    offset = 0.0,
    quantization = 8
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

local function bezier(cp0x, cp0y, cp1x, cp1y, t)
    if t <= 0.0 then return 0.0, 0.0 end
    if t >= 1.0 then return 1.0, 1.0 end
    local u = 1.0 - t
    local tsq = t * t
    local usq3t = u * u * (t + t + t)
    local tsq3u = tsq * (u + u + u)
    local tcb = tsq * t
    return cp0y * usq3t + cp1y * tsq3u + tcb,
        cp0x * usq3t + cp1x * tsq3u + tcb
end

---@param x number
---@param c number
---@param amplitude number
---@param offset number
---@return number
local function gamma(x, c, amplitude, offset)
    return math.max(0.0, math.min(1.0,
        amplitude * (x ^ c) + offset))
end

---@param x number
---@param slope number
---@param intercept number
---@return number
local function linear(x, slope, intercept)
    return math.max(0.0, math.min(1.0,
        slope * x + intercept))
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
    option = defaults.spaceStr
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
            dlg:modify { id = "cp0x", visible = true }
            dlg:modify { id = "cp0y", visible = true }
            dlg:modify { id = "cp1x", visible = true }
            dlg:modify { id = "cp1y", visible = true }
            dlg:modify { id = "easeFuncs", visible = true }
        else
            dlg:modify { id = "graphBezier", visible = false }
            dlg:modify { id = "cp0x", visible = false }
            dlg:modify { id = "cp0y", visible = false }
            dlg:modify { id = "cp1x", visible = false }
            dlg:modify { id = "cp1y", visible = false }
            dlg:modify { id = "easeFuncs", visible = false }
        end

        if prs == "GAMMA" then
            dlg:modify { id = "gamma", visible = true }
            dlg:modify { id = "amplitude", visible = true }
            dlg:modify { id = "offset", visible = true }
        else
            dlg:modify { id = "gamma", visible = false }
            dlg:modify { id = "amplitude", visible = false }
            dlg:modify { id = "offset", visible = false }
        end

        if prs == "LINEAR" then
            dlg:modify { id = "slope", visible = true }
            dlg:modify { id = "intercept", visible = true }
        else
            dlg:modify { id = "slope", visible = false }
            dlg:modify { id = "intercept", visible = false }
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
    defaults.preset == "BEZIER", true, true, 5,
    defaults.cp0x, defaults.cp0y,
    defaults.cp1x, defaults.cp1y,
    app.theme.color.text,
    Color { r = 128, g = 128, b = 128 })

dlg:number {
    id = "gamma",
    label = "Gamma:",
    text = string.format("%.1f", defaults.gamma),
    decimals = 5,
    visible = defaults.preset == "GAMMA"
}

dlg:newrow { always = false }

dlg:number {
    id = "amplitude",
    label = "Amplitude:",
    text = string.format("%.1f", defaults.amplitude),
    decimals = 5,
    visible = defaults.preset == "GAMMA"
}

dlg:newrow { always = false }

dlg:number {
    id = "offset",
    label = "Offset:",
    text = string.format("%.1f", defaults.offset),
    decimals = 5,
    visible = defaults.preset == "GAMMA"
}

dlg:newrow { always = false }

dlg:number {
    id = "slope",
    label = "Slope:",
    text = string.format("%.1f", defaults.slope),
    decimals = 5,
    visible = defaults.preset == "LINEAR"
}

dlg:newrow { always = false }

dlg:number {
    id = "intercept",
    label = "Intercept:",
    text = string.format("%.1f", defaults.intercept),
    decimals = 5,
    visible = defaults.preset == "LINEAR"
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

        local slope = args.slope or defaults.slope --[[@as number]]
        local intercept = args.intercept or defaults.intercept --[[@as number]]
        local func = function(x)
            return linear(x, slope, intercept)
        end

        local preset = args.preset
        if preset == "BEZIER" then
            local cp0x = args.cp0x or defaults.cp0x --[[@as number]]
            local cp0y = args.cp0y or defaults.cp0y --[[@as number]]
            local cp1x = args.cp1x or defaults.cp1x --[[@as number]]
            local cp1y = args.cp1y or defaults.cp1y --[[@as number]]

            cp0x = math.min(math.max(cp0x, 0.0), 1.0)
            cp1x = math.min(math.max(cp1x, 0.0), 1.0)

            func = function(x)
                return bezier(cp0x, cp0y, cp1x, cp1y, x)
            end
        elseif preset == "GAMMA" then
            local g = 1.0
            if args.gamma ~= 0.0 then
                g = args.gamma --[[@as number]]
            end
            local amplitude = args.amplitude or defaults.amplitude --[[@as number]]
            local offset = args.offset or defaults.offset --[[@as number]]
            func = function(x)
                return gamma(x, g, amplitude, offset)
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