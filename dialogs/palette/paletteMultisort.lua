local criteria = {
    "ALPHA",

    "HSL_HUE",
    "HSL_SATURATION",
    "HSL_LIGHTNESS",

    "HSV_HUE",
    "HSV_SATURATION",
    "HSV_VALUE",

    -- Disable for now.
    -- "LUMINANCE",

    "RED",
    "GREEN",
    "BLUE"
}

local defaults = {
    stride = 6,
    primary = "HSL_HUE",
    secondary = "HSL_LIGHTNESS"
}

local function sRgbTolRgb(x)
    -- 1.0 / 12.92 = 0.07739938080495357
    -- 1.0 / 1.055 = 0.9478672985781991
    if x <= 0.04045 then
        return x * 0.07739938080495357
    else
        return ((x + 0.055) * 0.9478672985781991) ^ 2.4
    end
end

local function lumSorter1(a, b)
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

    return aLum < bLum
end

local function quantize(x, levels)
    return math.floor(0.5 + x * levels) / levels
end

local function hslHueSorter1(a, b)
    -- local aHue = quantize(a.hslHue, 180)
    -- local bHue = quantize(b.hslHue, 180)
    local aHue = a.hslHue
    local bHue = b.hslHue
    return aHue < bHue
end

local function hslSatSorter1(a, b)
    local aSat = a.hslSaturation
    local bSat = b.hslSaturation
    return aSat < bSat
end

local function hslLightSorter1(a, b)
    local aLight = a.hslLightness
    local bLight = b.hslLightness
    return aLight < bLight
end

local function hsvHueSorter1(a, b)
    local aHue = a.hsvHue
    local bHue = b.hsvHue
    return aHue < bHue
end

local function hsvSatSorter1(a, b)
    local aSat = a.hsvSaturation
    local bSat = b.hsvSaturation
    return aSat < bSat
end

local function hsvValSorter1(a, b)
    local aVal = a.hsvValue
    local bVal = b.hsvValue
    return aVal < bVal
end

local function redSorter1(a, b)
    local aRed = a.red
    local bRed = b.red
    return aRed < bRed
end

local function greenSorter1(a, b)
    local aGreen = a.green
    local bGreen = b.green
    return aGreen < bGreen
end

local function blueSorter1(a, b)
    local aBlue = a.blue
    local bBlue = b.blue
    return aBlue < bBlue
end

local function alphaSorter1(a, b)
    local aAlpha = a.alpha
    local bAlpha = b.alpha
    return aAlpha < bAlpha
end

local function avgHslHue(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hslHue
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgHslSat(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hslSaturation
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgHslLight(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hslLightness
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgHsvHue(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hsvHue
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgHsvSat(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hsvSaturation
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgHsvVal(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].hsvValue
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgRed(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].red
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgGreen(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].green
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgBlue(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].blue
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function avgAlpha(arr)
    local avg = 0
    local lenarr = #arr
    for i = 1, #arr, 1 do
         avg = avg + arr[i].alpha
    end

    if lenarr > 0 then
        avg = avg / lenarr
    end
    return avg
end

local function hslHueSorter2(a, b)
    local aVal = avgHslHue(a)
    local bVal = avgHslHue(b)
    return aVal < bVal
end

local function hslSatSorter2(a, b)
    local aVal = avgHslSat(a)
    local bVal = avgHslSat(b)
    return aVal < bVal
end

local function hslLightSorter2(a, b)
    local aVal = avgHslLight(a)
    local bVal = avgHslLight(b)
    return aVal < bVal
end

local function hsvHueSorter2(a, b)
    local aHue = avgHsvHue(a)
    local bHue = avgHsvHue(b)
    return aHue < bHue
end

local function hsvSatSorter2(a, b)
    local aSat = avgHsvSat(a)
    local bSat = avgHsvSat(b)
    return aSat < bSat
end

local function hsvValSorter2(a, b)
    local aVal = avgHsvVal(a)
    local bVal = avgHsvVal(b)
    return aVal < bVal
end

local function redSorter2(a, b)
    local aRed = avgRed(a)
    local bRed = avgRed(b)
    return aRed < bRed
end

local function greenSorter2(a, b)
    local aGreen = avgGreen(a)
    local bGreen = avgGreen(b)
    return aGreen < bGreen
end

local function blueSorter2(a, b)
    local aBlue = avgBlue(a)
    local bBlue = avgBlue(b)
    return aBlue < bBlue
end

local function alphaSorter2(a, b)
    local aAlpha = avgAlpha(a)
    local bAlpha = avgAlpha(b)
    return aAlpha < bAlpha
end

local function presetToMethod1(preset)
    if preset == "HSL_HUE" then
        return hslHueSorter1
    elseif preset == "HSL_SATURATION" then
        return hslSatSorter1
    elseif preset == "HSL_LIGHTNESS" then
        return hslLightSorter1
    elseif preset == "HSV_HUE" then
        return hsvHueSorter1
    elseif preset == "HSV_SATURATION" then
        return hsvSatSorter1
    elseif preset == "HSV_VALUE" then
        return hsvValSorter1
    -- elseif preset == "LUMINANCE" then
    --     return lumSorter1
    elseif preset == "RED" then
        return redSorter1
    elseif preset == "GREEN" then
        return greenSorter1
    elseif preset == "BLUE" then
        return blueSorter1
    else -- default to ALPHA
        return alphaSorter1
    end
end

local function presetToMethod2(preset)
    if preset == "HSL_HUE" then
        return hslHueSorter2
    elseif preset == "HSL_SATURATION" then
        return hslSatSorter2
    elseif preset == "HSL_LIGHTNESS" then
        return hslLightSorter2
    elseif preset == "HSV_HUE" then
        return hsvHueSorter2
    elseif preset == "HSV_SATURATION" then
        return hsvSatSorter2
    elseif preset == "HSV_VALUE" then
        return hsvValSorter2
    elseif preset == "RED" then
        return redSorter2
    elseif preset == "GREEN" then
        return greenSorter2
    elseif preset == "BLUE" then
        return blueSorter2
    else -- default to ALPHA
        return alphaSorter2
    end
end

local dlg = Dialog { title = "Sort Palette Multiple Criteria" }

dlg:newrow { always = false }

dlg:slider {
    id = "stride",
    label = "Stride:",
    value = defaults.stride,
    min = 2,
    max = 32
}

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

                local stride = args.stride

                local srcPal = sprite.palettes[1] or Palette()
                local srcPalLen = #srcPal
                local pal2d = {}
                -- local rowCount = srcPalLen // stride
                local rowCount = math.ceil(srcPalLen / stride)
                for i = 1, rowCount, 1 do
                    pal2d[i] = {}
                end

                local idxfl0 = 0
                for i = 1, rowCount, 1 do
                    local row = pal2d[i]
                    for j = 1, stride, 1 do
                        if idxfl0 < srcPalLen then
                            local aseColor = srcPal:getColor(idxfl0)
                            row[j] = aseColor
                            -- print(i .. ", " .. j .. ": " ..
                            --     string.format("%X", aseColor.rgbaPixel))
                        end
                        idxfl0 = idxfl0 + 1
                    end
                end

                local strPrimary = args.primary
                local funcPrimary = presetToMethod2(strPrimary)
                table.sort(pal2d, funcPrimary)

                -- Sort inner arrays.
                local strSecondary = args.secondary
                local funcSecondary = presetToMethod1(strSecondary)
                for i = 1, rowCount, 1 do
                    local row = pal2d[i]
                    if row then
                        table.sort(row, funcSecondary)
                    end
                end

                -- Flatten out sorted 2d array to a palette.
                local newLen = rowCount * stride
                local trgPal = Palette(newLen)
                for i = 1, rowCount, 1 do
                    local row = pal2d[i]
                    for j = 1, stride, 1 do
                        local idxfl1 = ((i - 1) * stride + (j - 1))
                        if idxfl1 < newLen then
                            trgPal:setColor(idxfl1, row[j])
                        else
                            trgPal:setColor(idxfl1, Color(0, 0, 0, 0))
                        end
                    end
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