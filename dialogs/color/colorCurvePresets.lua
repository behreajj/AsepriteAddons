local prsStrs = {
    "BEZIER",
    "GAMMA",
    "LINEAR",
    "SINE_WAVE",
    "QUANTIZE"
}

local defaults = {
    -- Sigmoid function?
    -- n <-- scalar * (tau * x - pi)
    -- s(n) <-- 1.0 / (1.0 + exp(-n))

    resolution = 16,
    preset = "SINE_WAVE",
    useRed = true,
    useGreen = true,
    useBlue = true,
    useAlpha = false,
    useGray = true,
    useIdx = false,

    cp0x = 0.33333333333333,
    cp0y = 0.0,
    cp1x = 0.66666666666667,
    cp1y = 1.0,

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

local function gamma(x, c, amplitude, offset)
    return math.max(0.0, math.min(1.0,
        amplitude * (x ^ c) + offset))
end

local function linear(x, slope, intercept)
    return math.max(0.0, math.min(1.0,
        slope * x + intercept))
end

local function quantize(x, levels)
    return math.max(0.0, math.min(1.0,
        (math.ceil(x * levels) - 1.0)
        / (levels - 1.0)))
end

local function sineWave(x, freq, phase, amp, basis)
    return math.max(0.0, math.min(1.0,
        0.5 + 0.5 * (basis + amp * math.sin(
            6.2831853071796 * freq * x + phase))))
end

local dlg = Dialog { title = "Color Curve Presets" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 2,
    max = 64,
    value = defaults.resolution
}

dlg:newrow { always = false }

dlg:combobox {
    id = "preset",
    label = "Preset:",
    options = prsStrs,
    option = defaults.preset,
    onchange = function()
        local prs = dlg.data.preset

        if prs == "BEZIER" then
            dlg:modify { id = "cp0x", visible = true }
            dlg:modify { id = "cp0y", visible = true }
            dlg:modify { id = "cp1x", visible = true }
            dlg:modify { id = "cp1y", visible = true }
        else
            dlg:modify { id = "cp0x", visible = false }
            dlg:modify { id = "cp0y", visible = false }
            dlg:modify { id = "cp1x", visible = false }
            dlg:modify { id = "cp1y", visible = false }
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

dlg:number {
    id = "cp0x",
    label = "Control 0:",
    text = string.format("%.5f", defaults.cp0x),
    decimals = 5,
    visible = defaults.preset == "BEZIER"
}

dlg:number {
    id = "cp0y",
    text = string.format("%.5f", defaults.cp0y),
    decimals = 5,
    visible = defaults.preset == "BEZIER"
}

dlg:newrow { always = false }

dlg:number {
    id = "cp1x",
    label = "Control 1:",
    text = string.format("%.5f", defaults.cp1x),
    decimals = 5,
    visible = defaults.preset == "BEZIER"
}

dlg:number {
    id = "cp1y",
    text = string.format("%.5f", defaults.cp1y),
    decimals = 5,
    visible = defaults.preset == "BEZIER"
}

dlg:newrow { always = false }

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

dlg:check {
    id = "useRed",
    label = "Channels:",
    text = "R",
    selected = defaults.useRed
}

dlg:check {
    id = "useGreen",
    text = "G",
    selected = defaults.useGreen
}

dlg:check {
    id = "useBlue",
    text = "B",
    selected = defaults.useBlue
}

dlg:check {
    id = "useAlpha",
    text = "A",
    selected = defaults.useAlpha
}

dlg:check {
    id = "useGray",
    text = "V",
    selected = defaults.useGray
}

dlg:check {
    id = "useIdx",
    text = "I",
    selected = defaults.useIdx
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

        local slope = args.slope or defaults.slope
        local intercept = args.intercept or defaults.intercept
        local func = function(x)
            return linear(x, slope, intercept)
        end

        local preset = args.preset
        if preset == "BEZIER" then
            local cp0x = args.cp0x or defaults.cp0x
            local cp0y = args.cp0y or defaults.cp0y
            local cp1x = args.cp1x or defaults.cp1x
            local cp1y = args.cp1y or defaults.cp1y

            cp0x = math.min(math.max(cp0x, 0.0), 1.0)
            cp1x = math.min(math.max(cp1x, 0.0), 1.0)

            func = function(x)
                return bezier(cp0x, cp0y, cp1x, cp1y, x)
            end
        elseif preset == "GAMMA" then
            local g = 1.0
            if args.gamma ~= 0.0 then g = args.gamma end
            local amplitude = args.amplitude or defaults.amplitude
            local offset = args.offset or defaults.offset
            func = function(x)
                return gamma(x, g, amplitude, offset)
            end
        elseif preset == "SINE_WAVE" then
            local freq = args.freq or defaults.freq
            local phase = args.phase or defaults.phase
            phase = 0.017453292519943 * phase
            local amp = args.sw_amp or defaults.sw_amp
            local basis = args.basis or defaults.basis

            func = function(x)
                return sineWave(x, freq, phase, amp, basis)
            end
        elseif preset == "QUANTIZE" then
            if args.quantization > 1 then
                func = function(x)
                    return quantize(x, args.quantization)
                end
            end
        end

        local points = {}
        local res = args.resolution
        local tox = 1.0 / (res - 1.0)

        local i = 0
        while i < res do
            local x = i * tox
            local y, xp = func(x)
            if xp then x = xp end
            local point = Point(
                math.floor(x * 0xff + 0.5),
                math.floor(y * 0xff + 0.5))
            i = i + 1
            points[i] = point
        end

        app.command.ColorCurve {
            ui = true,
            channels = channels,
            curve = points
        }
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