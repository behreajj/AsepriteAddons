local criteria = {
    "ALPHA",

    "HSL_HUE",
    "HSL_SATURATION",
    "HSL_LIGHTNESS",

    "HSV_HUE",
    "HSV_SATURATION",
    "HSV_VALUE",

    "LUMINANCE",

    "RED",
    "GREEN",
    "BLUE"
}

local defaults = {
    primary = "HSL_LIGHTNESS",
    secondary = "HSL_SATURATION",
    tertiary = "HSL_HUE"
}

local function quantize(x, levels)
    return math.floor(0.5 + x * levels) / levels
end

local function sRgbTolRgb(x)
    -- 1.0 / 12.92 = 0.07739938080495357
    -- 1.0 / 1.055 = 0.9478672985781991
    if x <= 0.04045 then
        return x * 0.07739938080495357
    else
        return ((x + 0.055) * 0.9478672985781991) ^ 2.4
    end
end

local function hslHueSorter(a, b)
    -- Hue depends on saturation being greater than 0
    -- and lightness being bewteen 0 and 1.
    local aSat = a.hslSaturation
    if aSat < 0.000001 then return 0 end
    local bSat = b.hslSaturation
    if bSat < 0.000001 then return 0 end

    local aLgt = a.hslLightness
    if aLgt < 0.000001 or aLgt > 0.999999 then
        return 0
    end
    local bLgt = b.hslLightness
    if bLgt < 0.000001 or bLgt > 0.999999 then
        return 0
    end

    local aHue = quantize(a.hslHue, 180)
    local bHue = quantize(b.hslHue, 180)
    if aHue > bHue then return 1
    elseif aHue < bHue then return -1
    else return 0 end
end

local function hslSatSorter(a, b)
    local aSat = a.hslSaturation
    local bSat = b.hslSaturation
    if aSat > bSat then return 1
    elseif aSat < bSat then return -1
    else return 0 end
end

local function hslLightSorter(a, b)
    local aLight = a.hslLightness
    local bLight = b.hslLightness
    if aLight > bLight then return 1
    elseif aLight < bLight then return -1
    else return 0 end
end

local function hsvHueSorter(a, b)
    local aSat = a.hsvSaturation
    if aSat < 0.000001 then return 0 end
    local bSat = b.hsvSaturation
    if bSat < 0.000001 then return 0 end

    local aVal = a.hsvValue
    if aVal < 0.000001 then return 0 end
    local bVal = b.hsvValue
    if bVal < 0.000001 then return 0 end

    local aHue = quantize(a.hsvHue, 180)
    local bHue = quantize(b.hsvHue, 180)
    if aHue > bHue then return 1
    elseif aHue < bHue then return -1
    else return 0 end
end

local function hsvSatSorter(a, b)
    local aSat = a.hsvSaturation
    local bSat = b.hsvSaturation
    if aSat > bSat then return 1
    elseif aSat < bSat then return -1
    else return 0 end
end

local function hsvValSorter(a, b)
    local aVal = a.hsvValue
    local bVal = b.hsvValue
    if aVal > bVal then return 1
    elseif aVal < bVal then return -1
    else return 0 end
end

local function lumSorter(a, b)
    -- Divide by 255 to convert to range [0.0, 1.0].
    local asr01 = 0.00392156862745098 * a.red
    local asg01 = 0.00392156862745098 * a.green
    local asb01 = 0.00392156862745098 * a.blue

    local bsr01 = 0.00392156862745098 * b.red
    local bsg01 = 0.00392156862745098 * b.green
    local bsb01 = 0.00392156862745098 * b.blue

    -- Convert from sRGB to linear RGB.
    local alr01 = sRgbTolRgb(asr01)
    local alg01 = sRgbTolRgb(asg01)
    local alb01 = sRgbTolRgb(asb01)

    local blr01 = sRgbTolRgb(bsr01)
    local blg01 = sRgbTolRgb(bsg01)
    local blb01 = sRgbTolRgb(bsb01)

    -- Convert to the Y in CIE XYZ. This is a
    -- matrix transformation of a vector.
    local aLum = 0.21264934272065283 * alr01
        + 0.7151691357059038 * alg01
        + 0.07218152157344333 * alb01

    local bLum = 0.21264934272065283 * blr01
        + 0.7151691357059038 * blg01
        + 0.07218152157344333 * blb01

    if aLum > bLum then return 1
    elseif aLum < bLum then return -1
    else return 0 end
end

local function redSorter(a, b)
    local aRed = a.red
    local bRed = b.red
    if aRed > bRed then return 1
    elseif aRed < bRed then return -1
    else return 0 end
end

local function greenSorter(a, b)
    local aGreen = a.green
    local bGreen = b.green
    if aGreen > bGreen then return 1
    elseif aGreen < bGreen then return -1
    else return 0 end
end

local function blueSorter(a, b)
    local aBlue = a.blue
    local bBlue = b.blue
    if aBlue > bBlue then return 1
    elseif aBlue < bBlue then return -1
    else return 0 end
end

local function alphaSorter(a, b)
    local aAlpha = a.alpha
    local bAlpha = b.alpha
    if aAlpha > bAlpha then return 1
    elseif aAlpha < bAlpha then return -1
    else return 0 end
end

local function presetToMethod(preset)
    if preset == "HSL_HUE" then
        return hslHueSorter
    elseif preset == "HSL_SATURATION" then
        return hslSatSorter
    elseif preset == "HSL_LIGHTNESS" then
        return hslLightSorter
    elseif preset == "HSV_HUE" then
        return hsvHueSorter
    elseif preset == "HSV_SATURATION" then
        return hsvSatSorter
    elseif preset == "HSV_VALUE" then
        return hsvValSorter
    elseif preset == "LUMINANCE" then
        return lumSorter
    elseif preset == "RED" then
        return redSorter
    elseif preset == "GREEN" then
        return greenSorter
    elseif preset == "BLUE" then
        return blueSorter
    else -- default to ALPHA
        return alphaSorter
    end
end

local dlg = Dialog { title = "Sort Palette Multiple Criteria" }

dlg:combobox {
    id = "primary",
    label = "Primary:",
    option = defaults.primary,
    options = criteria
}

dlg:newrow { always = false }

dlg:combobox {
    id = "secondary",
    label = "Secondary:",
    option = defaults.secondary,
    options = criteria
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tertiary",
    label = "Tertiary:",
    option = defaults.tertiary,
    options = criteria
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
    text = "OK",
    focus = true,
    onclick = function()
        local args = dlg.data
        if args.ok then
            local sprite = app.activeSprite
            if sprite then
                local oldMode = sprite.colorMode
                app.command.ChangePixelFormat { format = "rgb" }

                local srcPal = sprite.palettes[1] or Palette()
                local srcPalLen = #srcPal
                local palTable = {}
                for i = 1, srcPalLen, 1 do
                    palTable[i] = srcPal:getColor(i - 1)
                end

                local strPrimary = args.primary
                local strSecondary = args.secondary
                local strTertiary = args.tertiary

                local funcPrimary = presetToMethod(strPrimary)
                local funcSecondary = presetToMethod(strSecondary)
                local funcTertiary = presetToMethod(strTertiary)

                local funcs = {
                    funcPrimary,
                    funcSecondary,
                    funcTertiary
                }

                local sorter = function(a, b)
                    for i = 1, #funcs, 1 do
                        local eval = funcs[i](a, b)
                        if eval ~= 0 then
                            return eval < 0
                        end
                    end
                    return false
                end

                table.sort(palTable, sorter)

                local trgPal = Palette(srcPalLen)
                for i = 1, srcPalLen, 1 do
                    trgPal:setColor(i - 1, palTable[i])
                end
                sprite:setPalette(trgPal)

                -- QUERY: Alternatively, use index remap?
                if oldMode == ColorMode.INDEXED then
                    app.command.ChangePixelFormat { format = "indexed" }
                elseif oldMode == ColorMode.GRAY then
                    app.command.ChangePixelFormat { format = "gray" }
                end

                app.refresh()
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