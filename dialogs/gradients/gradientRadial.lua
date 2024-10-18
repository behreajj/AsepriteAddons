dofile("../../support/gradientutilities.lua")

-- Canberra distance is also an option.
local metrics <const> = {
    "CHEBYSHEV",
    "EUCLIDEAN",
    "MANHATTAN",
    "MINKOWSKI"
}

local defaults <const> = {
    xOrig = 50,
    yOrig = 50,
    minRad = 0,
    maxRad = 100,
    distMetric = "EUCLIDEAN",
    minkExp = 2.0,
    pullFocus = true
}

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
local function chebDist(ax, ay, bx, by)
    return math.max(
        math.abs(bx - ax),
        math.abs(by - ay))
end

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
local function euclDist(ax, ay, bx, by)
    local dx <const> = bx - ax
    local dy <const> = by - ay
    return math.sqrt(dx * dx + dy * dy)
end

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
local function manhDist(ax, ay, bx, by)
    return math.abs(bx - ax)
        + math.abs(by - ay)
end

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param c number
---@param d number
---@return number
local function minkDist(ax, ay, bx, by, c, d)
    return (math.abs(bx - ax) ^ c
            + math.abs(by - ay) ^ c)
        ^ d
end

---@param distMetric string
---@param me number
---@return fun(ax: number, ay: number, bx: number, by: number): number
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

local dlg <const> = Dialog { title = "Radial Gradient" }

local gradient <const> = GradientUtilities.dialogWidgets(dlg, true)

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
        local args <const> = dlg.data
        local distMetric <const> = args.distMetric --[[@as string]]
        dlg:modify {
            id = "minkExp",
            visible = distMetric == "MINKOWSKI"
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
        local site <const> = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            activeSprite = AseUtilities.createSprite(
                AseUtilities.createSpec(), "Radial Gradient")
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
        end

        -- Early returns.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Cache methods.
        local max <const> = math.max
        local min <const> = math.min
        local strpack <const> = string.pack
        local toHex <const> = Clr.toHex
        local quantize <const> = Utilities.quantizeUnsigned

        -- Unpack arguments.
        local args <const> = dlg.data
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]
        local mnr100 <const> = args.minRad
            or defaults.minRad --[[@as integer]]
        local mxr100 <const> = args.maxRad
            or defaults.maxRad --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

        -- Choose distance metric based on preset.
        local distMetric <const> = args.distMetric
            or defaults.distMetric --[[@as string]]
        local minkExp <const> = args.minkExp
            or defaults.minkExp --[[@as number]]
        local distFunc <const> = distFuncFromPreset(distMetric, minkExp)

        -- Validate minimum and maximum radii.
        local minRad = 0.01 * min(mnr100, mxr100)
        local maxRad = 0.01 * max(mnr100, mxr100)

        -- If radii are approximately equal, offset.
        if math.abs(maxRad - minRad) <= 0.000001 then
            minRad = minRad - 0.01
            maxRad = maxRad + 0.01
        end

        local diffRad <const> = maxRad - minRad
        local linDenom <const> = 1.0 / diffRad

        -- Shift origin from [0, 100] to [0.0, 1.0].
        local xOrig100 <const> = args.xOrig
            or defaults.xOrig --[[@as integer]]
        local yOrig100 <const> = args.yOrig
            or defaults.yOrig --[[@as integer]]
        local xOrig <const> = 0.01 * xOrig100
        local yOrig <const> = 0.01 * yOrig100

        -- Convert from normalized to pixel size.
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local areaSprite <const> = wSprite * hSprite
        local wn1 <const> = max(1.0, wSprite - 1.0)
        local hn1 <const> = max(1.0, hSprite - 1.0)
        local xOrigPx <const> = xOrig * wn1
        local yOrigPx <const> = yOrig * hn1

        -- Need a scalar to normalize distance to [0.0, 1.0]
        local normDist <const> = 2.0 / (maxRad * distFunc(0.0, 0.0, wn1, hn1))

        ---@type string[]
        local trgByteStr <const> = {}
        local function radialEval(x, y)
            local dst <const> = distFunc(x, y, xOrigPx, yOrigPx)
            local fac = dst * normDist
            fac = (fac - minRad) * linDenom
            return min(max(fac, 0.0), 1.0)
        end

        if stylePreset == "MIXED" then
            ---@type table<number, integer>
            local facDict <const> = {}
            local cgmix <const> = ClrGradient.eval
            local i = 0
            while i < areaSprite do
                local x <const> = i % wSprite
                local y <const> = i // wSprite
                local fac <const> = quantize(radialEval(x, y), levels)
                local trgAbgr32 = facDict[fac]
                if not trgAbgr32 then
                    trgAbgr32 = toHex(cgmix(gradient, fac, mixFunc))
                    facDict[fac] = trgAbgr32
                end
                i = i + 1
                trgByteStr[i] = strpack("<I4", trgAbgr32)
            end
        else
            local dither <const> = GradientUtilities.ditherFromPreset(
                stylePreset, bayerIndex, ditherPath)
            local i = 0
            while i < areaSprite do
                local x <const> = i % wSprite
                local y <const> = i // wSprite
                local fac <const> = radialEval(x, y)
                local trgAbgr32 <const> = toHex(dither(gradient, fac, x, y))
                i = i + 1
                trgByteStr[i] = strpack("<I4", trgAbgr32)
            end
        end

        local grdImg <const> = Image(spriteSpec)
        grdImg.bytes = table.concat(trgByteStr)

        app.transaction("Radial Gradient", function()
            local grdLayer <const> = activeSprite:newLayer()
            grdLayer.name = "Gradient Radial"
            if stylePreset == "MIXED" then
                grdLayer.name = grdLayer.name
                    .. " " .. clrSpacePreset
            end
            local activeFrame <const> = site.frame
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

dlg:show {
    autoscrollbars = true,
    wait = false
}