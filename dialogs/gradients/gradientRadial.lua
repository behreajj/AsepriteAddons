dofile("../../support/gradientutilities.lua")

local metrics = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI"
}

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
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

GradientUtilities.dialogWidgets(dlg)

dlg:slider {
    id = "xOrigin",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrigin
}

dlg:slider {
    id = "yOrigin",
    min = 0,
    max = 100,
    value = defaults.yOrigin
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
                colorMode = ColorMode.RGB,
                transparentColor = 0 }
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
                text = "Only RGB color mode is supported." }
            return
        end

        -- Cache methods.
        local max = math.max
        local min = math.min
        local toHex = Clr.toHex
        local quantize = Utilities.quantizeUnsigned
        local cgeval = ClrGradient.eval

        -- Unpack arguments.
        local args = dlg.data
        local clrSpacePreset = args.clrSpacePreset
        local aseColors = args.shades
        local levels = args.quantize

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        -- Choose distance metric based on preset.
        local distMetric = args.distMetric
        local minkExp = args.minkExp
        local distFunc = distFuncFromPreset(distMetric, minkExp)

        -- Validate minimum and maximum radii.
        local minRad = 0.01 * min(
            args.minRad, args.maxRad)
        local maxRad = 0.01 * max(
            args.minRad, args.maxRad)

        -- If radii are approximately equal, offset.
        if math.abs(maxRad - minRad) <= 0.000001 then
            minRad = minRad - 0.01
            maxRad = maxRad + 0.01
        end

        local diffRad = maxRad - minRad
        local linDenom = 1.0 / diffRad

        -- Shift origin from [0, 100] to [0.0, 1.0].
        local xOrigin = 0.01 * args.xOrigin
        local yOrigin = 0.01 * args.yOrigin

        -- Convert from normalized to pixel size.
        local wn1 = max(1.0, activeSprite.width - 1.0)
        local hn1 = max(1.0, activeSprite.height - 1.0)
        local xOrigPx = xOrigin * wn1
        local yOrigPx = yOrigin * hn1

        -- Need a scalar to normalize distance to [0.0, 1.0]
        local normDist = 2.0 / (maxRad * distFunc(0.0, 0.0, wn1, hn1))

        local selection = AseUtilities.getSelection(activeSprite)
        local selBounds = selection.bounds
        local xSel = selBounds.x
        local ySel = selBounds.y

        local grdSpec = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = activeSpec.colorMode,
            transparentColor = activeSpec.transparentColor }
        grdSpec.colorSpace = activeSpec.colorSpace

        local grdImg = Image(grdSpec)
        local grdItr = grdImg:pixels()
        for elm in grdItr do
            local x = elm.x + xSel
            local y = elm.y + ySel
            local dst = distFunc(x, y, xOrigPx, yOrigPx)
            local fac = dst * normDist
            fac = (fac - minRad) * linDenom
            fac = min(max(fac, 0.0), 1.0)
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            local clr = cgeval(gradient, fac, mixFunc)
            elm(toHex(clr))
        end

        app.transaction(function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Radial." .. clrSpacePreset
            local activeFrame = app.activeFrame
                or activeSprite.frames[1]
            activeSprite:newCel(
                grdLayer,
                activeFrame,
                grdImg,
                Point(xSel, ySel))
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
