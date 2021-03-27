dofile("../support/aseutilities.lua")

local easingModes = { "RGB", "HSL", "HSV", "VIRIDIS" }
local rgbEasing = { "LINEAR", "SMOOTH" }
local hueEasing = { "NEAR", "FAR" }
local methods = { "AVERAGE", "HSV", "HSL", "REC_240", "REC_601", "REC_709" }

local viridis = {
    Color(68, 1, 84, 255),
    Color(70, 50, 126, 255),
    Color(54, 92, 140, 255),
    Color(39, 127, 142, 255),
    Color(34, 161, 135, 255),
    Color(75, 193, 109, 255),
    Color(159, 217, 57, 255),
    Color(253, 231, 37, 255)
}

local defaults = {
    standard = "REC_709",
    gamma = 1.0,
    blk = Color(0, 0, 0, 255),
    wht = Color(255, 255, 255, 255),
    easingMode = "RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR"
}

local dlg = Dialog { title = "Remap Luminance" }

dlg:combobox {
    id = "standard",
    label = "Standard:",
    option = defaults.standard,
    options = methods
}

dlg:number {
    id = "gamma",
    label = "Gamma:",
    text = string.format("%.1f", defaults.gamma),
    decimals = 5
}

dlg:combobox {
    id = "easingMode",
    label = "Easing Mode:",
    option = defaults.easingMode,
    options = easingModes
}

dlg:combobox {
    id = "easingFuncHue",
    label = "Hue Easing:",
    option = defaults.easingFuncHue,
    options = hueEasing
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "RGB Easing:",
    option = defaults.easingFuncRGB,
    options = rgbEasing
}

dlg:color {
    id = "blk",
    label = "Black:",
    color = defaults.blk
}

dlg:color {
    id = "wht",
    label = "White:",
    color = defaults.wht
}

local function rec240(r01, g01, b01)
    return 0.212 * r01
         + 0.701 * g01
         + 0.087 * b01
end

local function rec601(r01, g01, b01)
    return 0.299 * r01
         + 0.587 * g01
         + 0.114 * b01
end

local function rec709(r01, g01, b01)
    return 0.2126 * r01
         + 0.7152 * g01
         + 0.0722 * b01
end

local function arithMean(r01, g01, b01)
    return (r01 + g01 + b01) * 0.3333333333333333
end

local function hsvVal(r01, g01, b01)
    return math.max(r01, g01, b01)
end

local function hslLight(r01, g01, b01)
    return 0.5 * (math.max(r01, g01, b01)
                + math.min(r01, g01, b01))
end

local function lerpViridis(
    ah, as, av, aa,
    bh, bs, bv, ba, t)
    if t <= 0.0  then
        return viridis[1].rgbaPixel
    end

    if t >= 1.0 then
        return viridis[#viridis].rgbaPixel
    end

    local tScaled = t * (#viridis - 1)
    local i = math.tointeger(tScaled)
    local a = viridis[1 + i]
    local b = viridis[2 + i]
    return AseUtilities.lerpRgba(
        a.red, a.green, a.blue, a.alpha,
        b.red, b.green, b.blue, b.alpha,
        tScaled - i)
end

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then

            local stdstr = args.standard
            local gm = args.gamma
            local blk = args.blk
            local wht = args.wht
            local easingMode = args.easingMode

            -- Determine method by standard.
            local lmethod = rec709
            if stdstr == "AVERAGE" then
                lmethod = arithMean
            elseif stdstr == "HSV" then
                lmethod = hsvVal
            elseif stdstr == "HSL" then
                lmethod = hslLight
            elseif stdstr == "REC_240" then
                lmethod = rec240
            elseif stdstr == "REC_601" then
                lmethod = rec601
            end

            -- Determine category of easing func.
            local easingPreset = args.easingFuncRGB
            if easingMode == "HSV" then
                easingPreset = args.easingFuncHue
            elseif easingMode == "HSL" then
                easingPreset = args.easingFuncHue
            end

            -- Choose channels and easing based on color mode.
            local a0 = 0
            local a1 = 0
            local a2 = 0
            local a3 = 255

            local b0 = 0
            local b1 = 0
            local b2 = 0
            local b3 = 255

            local easing = AseUtilities.lerpRgba
            if easingMode == "HSV" then

                a0 = blk.hsvHue
                a1 = blk.hsvSaturation
                a2 = blk.hsvValue
                a3 = blk.alpha

                b0 = wht.hsvHue
                b1 = wht.hsvSaturation
                b2 = wht.hsvValue
                b3 = wht.alpha

                if easingPreset and easingPreset == "FAR" then
                    easing = AseUtilities.lerpHsvaFar
                else
                    easing = AseUtilities.lerpHsvaNear
                end

            elseif easingMode == "HSL" then

                a0 = blk.hslHue
                a1 = blk.hslSaturation
                a2 = blk.hslLightness
                a3 = blk.alpha

                b0 = wht.hslHue
                b1 = wht.hslSaturation
                b2 = wht.hslLightness
                b3 = wht.alpha

                if easingPreset and easingPreset == "FAR" then
                    easing = AseUtilities.lerpHslaFar
                else
                    easing = AseUtilities.lerpHslaNear
                end

            elseif easingMode == "VIRIDIS" then

                easing = lerpViridis

            else

                a0 = blk.red
                a1 = blk.green
                a2 = blk.blue
                a3 = blk.alpha

                b0 = wht.red
                b1 = wht.green
                b2 = wht.blue
                b3 = wht.alpha

                if easingPreset and easingPreset == "SMOOTH" then
                    easing = AseUtilities.smoothRgba
                end

            end

            local sprite = app.activeSprite
            if sprite then
                local srcLyr = app.activeLayer
                if srcLyr and not srcLyr.isGroup then
                    local srcCel = app.activeCel
                    if srcCel then
                        local srcImg = srcCel.image
                        local srcItr = srcImg:pixels()

                        local i = 1
                        local px = {}
                        for srcClr in srcItr do
                            local hex = srcClr()
                            local b = (hex >> 0x10 & 0xff) * 0.00392156862745098
                            local g = (hex >> 0x08 & 0xff) * 0.00392156862745098
                            local r = (hex >> 0x00 & 0xff) * 0.00392156862745098

                            r = r ^ gm
                            g = g ^ gm
                            b = b ^ gm

                            local lum = lmethod(r, g, b)
                            local gryclr = easing(
                                a0, a1, a2, a3,
                                b0, b1, b2, b3,
                                lum)

                            px[i] = (0xff000000 & hex)
                                  | (0x00ffffff & gryclr)

                            i = i + 1
                        end

                        local trgLyr = sprite:newLayer()
                        trgLyr.name = args.standard

                        local trgCel = sprite:newCel(trgLyr, 1)
                        trgCel.position = srcCel.position
                        trgCel.image = srcImg:clone()

                        local trgImg = trgCel.image
                        local trgItr = trgImg:pixels()

                        i = 1
                        for trgClr in trgItr do
                            trgClr(px[i])
                            i = i + 1
                        end

                        app.activeLayer = srcLyr
                        app.activeCel = srcCel
                        app.refresh()
                    else
                        app.alert("There is no active cel.")
                    end
                else
                    app.alert("There is no active layer.")
                end
            else
                app.alert("There is no active sprite.")
            end
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