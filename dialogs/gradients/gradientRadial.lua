dofile("../../support/gradientutilities.lua")

-- Canberra distance is also an option.
local metrics = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI"
}

local defaults = {
    xOrig = 50,
    yOrig = 50,
    minRad = 0,
    maxRad = 100,
    distMetric = "EUCLIDEAN",
    minkExp = 2.0,
    pullFocus = true
}

local function chebDist(ax, ay, bx, by)
    return math.max(
        math.abs(bx - ax),
        math.abs(by - ay))
end

local function euclDist(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function manhDist(ax, ay, bx, by)
    return math.abs(bx - ax)
        + math.abs(by - ay)
end

local function minkDist(ax, ay, bx, by, c, d)
    return (math.abs(bx - ax) ^ c
        + math.abs(by - ay) ^ c)
        ^ d
end

local function distFuncFromPreset(distMetric, me)
    if distMetric == "CHEBYSHEV" then
        return chebDist
    elseif distMetric == "MANHATTAN" then
        return manhDist
    elseif distMetric == "MINKOWSKI" then
        local minkExp = 2.0
        local invMinkExp = 0.5

        if me ~= 0.0 then
            minkExp = me
            invMinkExp = 1.0 / minkExp
        end

        return function(ax, ay, bx, by)
            return minkDist(ax, ay, bx, by,
                minkExp, invMinkExp)
        end
    else
        return euclDist
    end
end

local dlg = Dialog { title = "Radial Gradient" }

GradientUtilities.dialogWidgets(dlg, true)

dlg:slider {
    id = "xOrig",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrig
}

dlg:slider {
    id = "yOrig",
    min = 0,
    max = 100,
    value = defaults.yOrig
}

dlg:newrow { always = false }

dlg:slider {
    id = "minRad",
    label = "Radii %:",
    min = 0,
    max = 100,
    value = defaults.minRad
}

dlg:slider {
    id = "maxRad",
    min = 0,
    max = 100,
    value = defaults.maxRad
}

dlg:newrow { always = false }

dlg:combobox {
    id = "distMetric",
    label = "Metric:",
    option = defaults.distMetric,
    options = metrics,
    onchange = function()
        dlg:modify {
            id = "minkExp",
            visible = dlg.data.distMetric == "MINKOWSKI"
        }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "minkExp",
    label = "Exponent:",
    text = string.format("%.1f", defaults.minkExp),
    decimals = 6,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            local newSpec = ImageSpec {
                width = app.preferences.new_file.width,
                height = app.preferences.new_file.height,
                colorMode = ColorMode.RGB
            }
            newSpec.colorSpace = ColorSpace { sRGB = true }
            activeSprite = Sprite(newSpec)
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Cache methods.
        local max = math.max
        local min = math.min
        local toHex = Clr.toHex
        local quantize = Utilities.quantizeUnsigned

        -- Unpack arguments.
        local args = dlg.data
        local stylePreset = args.stylePreset --[[@as string]]
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local easPreset = args.easPreset --[[@as string]]
        local huePreset = args.huePreset --[[@as string]]
        local aseColors = args.shades --[[@as Color[] ]]
        local levels = args.quantize --[[@as integer]]
        local mnr100 = args.minRad --[[@as integer]]
        local mxr100 = args.maxRad --[[@as integer]]
        local bayerIndex = args.bayerIndex --[[@as integer]]
        local ditherPath = args.ditherPath --[[@as string]]

        if stylePreset ~= "MIXED" then levels = 0 end
        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local cgeval = GradientUtilities.evalFromStylePreset(
            stylePreset, bayerIndex, ditherPath)

        -- Choose distance metric based on preset.
        local distMetric = args.distMetric
        local minkExp = args.minkExp
        local distFunc = distFuncFromPreset(distMetric, minkExp)

        -- Validate minimum and maximum radii.
        local minRad = 0.01 * min(mnr100, mxr100)
        local maxRad = 0.01 * max(mnr100, mxr100)

        -- If radii are approximately equal, offset.
        if math.abs(maxRad - minRad) <= 0.000001 then
            minRad = minRad - 0.01
            maxRad = maxRad + 0.01
        end

        local diffRad = maxRad - minRad
        local linDenom = 1.0 / diffRad

        -- Shift origin from [0, 100] to [0.0, 1.0].
        local xOrig = 0.01 * args.xOrig
        local yOrig = 0.01 * args.yOrig

        -- Convert from normalized to pixel size.
        local wn1 = max(1.0, activeSprite.width - 1.0)
        local hn1 = max(1.0, activeSprite.height - 1.0)
        local xOrigPx = xOrig * wn1
        local yOrigPx = yOrig * hn1

        -- Need a scalar to normalize distance to [0.0, 1.0]
        local normDist = 2.0 / (maxRad * distFunc(0.0, 0.0, wn1, hn1))

        local grdSpec = ImageSpec {
            width = math.max(1, activeSprite.width),
            height = math.max(1, activeSprite.height),
            colorMode = activeSpec.colorMode,
            transparentColor = activeSpec.transparentColor
        }
        grdSpec.colorSpace = activeSpec.colorSpace

        local grdImg = Image(grdSpec)
        local pxItr = grdImg:pixels()
        for pixel in pxItr do
            local x = pixel.x
            local y = pixel.y
            local dst = distFunc(x, y, xOrigPx, yOrigPx)
            local fac = dst * normDist
            fac = (fac - minRad) * linDenom
            fac = min(max(fac, 0.0), 1.0)
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            local clr = cgeval(gradient, fac, mixFunc, x, y)
            pixel(toHex(clr))
        end

        app.transaction("Radial Gradient", function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Radial"
            if stylePreset == "MIXED" then
                grdLayer.name = grdLayer.name
                    .. "." .. clrSpacePreset
            end
            local activeFrame = app.activeFrame
                or activeSprite.frames[1] --[[@as Frame]]
            activeSprite:newCel(
                grdLayer, activeFrame, grdImg)
        end)
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