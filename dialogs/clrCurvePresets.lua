local prsStrs = {
    "GAMMA",
    "LINEAR",
    "PINGPONG",
    "QUANTIZE",
    "SMOOTH",
    "SMOOTHER"
}

local defaults = {
    resolution = 16,
    preset = "SMOOTHER",
    useRed = true,
    useGreen = true,
    useBlue = true,
    useAlpha = false,
    useGray = true,
    useIdx = false,
    gamma = 2.2,
    quantization = 0
}

local function quantize(x, levels)
    return math.floor(0.5 + x * levels) / levels
end

local function gamma(x, c)
    return math.max(0.0, math.min(1.0, x ^ c))
end

local function linear(x)
    return math.max(0.0, math.min(1.0, x))
end

local function pingPong(x)
    return 0.5 + 0.5 * math.cos(
        6.283185307179586 * x - math.pi)
end

local function smoothStep(x)
    return math.max(0.0, math.min(1.0,
        x * x * (3.0 - (x + x))))
end

local function smootherStep(x)
    return math.max(0.0, math.min(1.0,
        x * x * x * (x * (x * 6.0 - 15.0) + 10.0)))
end

local dlg = Dialog { title = "Color Curve Presets" }

dlg:slider {
    id = "resolution",
    label = "Resolution:",
    min = 1,
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
        if prs == "GAMMA" then
            dlg:modify {
                id = "gamma",
                visible = true
            }
        else
            dlg:modify {
                id = "gamma",
                visible = false
            }
        end

        if prs == "QUANTIZE" then
            dlg:modify {
                id = "quantization",
                visible = true
            }
        else
            dlg:modify {
                id = "quantization",
                visible = false
            }
        end
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "gamma",
    label = "Gamma:",
    text = string.format("%.1f", defaults.gamma),
    decimals = 5,
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization,
    visible = false
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
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local channels = 0x0
            if args.useRed then channels = channels | FilterChannels.RED end
            if args.useGreen then channels = channels | FilterChannels.GREEN end
            if args.useBlue then channels = channels | FilterChannels.BLUE end
            if args.useAlpha then channels = channels | FilterChannels.ALPHA end
            if args.useGray then channels = channels | FilterChannels.GRAY end
            if args.useIndex then channels = channels | FilterChannels.INDEX end

            local func = linear
            local preset = args.preset
            if preset == "SMOOTH" then
                func = smoothStep
            elseif preset == "SMOOTHER" then
                func = smootherStep
            elseif preset == "PINGPONG" then
                func = pingPong
            elseif preset == "QUANTIZE" then
                if args.quantization > 0 then
                    func = function(x)
                        return quantize(x, args.quantization)
                    end
                end
            elseif preset == "GAMMA" then
                local g = 1.0
                if args.gamma ~= 0.0 then g = args.gamma end
                func = function(x)
                    return gamma(x, g)
                end
            end

            local points = {}
            local res = args.resolution
            local tox = 1.0 / (res - 1.0)

            for i = 0, res - 1, 1 do
                local x = i * tox
                local y = func(x)
                local point = Point(
                    math.tointeger(0.5 + 255.0 * x),
                    math.tointeger(0.5 + 255.0 * y))
                points[i] = point
            end

            app.command.ColorCurve {
                ui = true,
                channels = channels,
                curve = points
            }

        end
    end
}

dlg:button {
    id = "cancel",
    text = "CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }