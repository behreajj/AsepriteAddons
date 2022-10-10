dofile("./aseutilities.lua")
dofile("./clrkey.lua")
dofile("./clrgradient.lua")
dofile("./curve3.lua")

GradientUtilities = {}
GradientUtilities.__index = GradientUtilities

setmetatable(GradientUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Color spaces presets.
GradientUtilities.CLR_SPC_PRESETS = {
    "HSL",
    "HSV",
    "LINEAR_RGB",
    "NORMAL_MAP",
    "S_RGB",
    "SR_LAB_2",
    "SR_LCH"
}

---Hue easing function presets.
GradientUtilities.HUE_EASING_PRESETS = {
    "CCW",
    "CW",
    "FAR",
    "NEAR"
}

---Easing function presets for non-polar
---color representations.
GradientUtilities.RGB_EASING_PRESETS = {
    "EASE_IN_CIRC",
    "EASE_OUT_CIRC",
    "LINEAR",
    "SMOOTH",
    "SMOOTHER"
}

---Default color space preset.
GradientUtilities.DEFAULT_CLR_SPC = "SR_LCH"

---Default hue easing preset.
GradientUtilities.DEFAULT_HUE_EASING = "NEAR"

---Default linear easing preset.
GradientUtilities.DEFAULT_RGB_EASING = "LINEAR"

---Converts an array of Aseprite colors to a
---ClrGradient. If the number of colors is less
---than one, returns a gradient with black and
---white. If the number is less than two, returns
---with the original color and its opaque variant.
---@param aseColors table array of Aseprite colors
---@return table
function GradientUtilities.aseColorsToClrGradient(aseColors)
    -- Different from ClrGradient.fromColors due to
    -- Gradient Outline. Avoid zero alpha colors because
    -- iterations are lost if background is zero.
    local clrKeys = {}
    local lenColors = #aseColors
    if lenColors < 1 then
        clrKeys[1] = ClrKey.newByRef(0.0, Clr.black())
        clrKeys[2] = ClrKey.newByRef(1.0, Clr.white())
    elseif lenColors < 2 then
        local c = AseUtilities.aseColorToClr(aseColors[1])
        clrKeys[1] = ClrKey.newByRef(0.0, c)
        clrKeys[2] = ClrKey.newByRef(1.0, Clr.new(c.r, c.g, c.b, 1.0))
    else
        local toStep = 1.0 / (lenColors - 1)
        local i = 0
        while i < lenColors do
            local step = i * toStep
            i = i + 1
            local c = AseUtilities.aseColorToClr(aseColors[i])
            clrKeys[i] = ClrKey.newByRef(step, c)
        end
    end
    return ClrGradient.newInternal(clrKeys)
end

---Finds the appropriate color easing function based on
---the color space preset and hue preset.
---@param clrSpcPreset string color space preset
---@param huePreset string hue preset
---@return function
function GradientUtilities.clrSpcFuncFromPreset(clrSpcPreset, huePreset)
    if clrSpcPreset == "HSL" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixHslInternal(a, b, t, hef)
        end
    elseif clrSpcPreset == "HSV" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixHsvInternal(a, b, t, hef)
        end
    elseif clrSpcPreset == "LINEAR_RGB" then
        return Clr.mixsRgbInternal
    elseif clrSpcPreset == "NORMAL_MAP" then
        return Clr.mixNormal
    elseif clrSpcPreset == "SR_LAB_2" then
        return Clr.mixSrLab2Internal
    elseif clrSpcPreset == "SR_LCH" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixSrLchInternal(a, b, t, hef)
        end
    else
        return Clr.mixlRgbaInternal
    end
end

---Generates the dialog widgets shared across
---gradient dialogs. Places a new row at the
---end of the widgets.
---@param dlg userdata dialog
function GradientUtilities.dialogWidgets(dlg)
    dlg:shades {
        id = "shades",
        label = "Colors:",
        mode = "sort",
        colors = {
            AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
            AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL)
        }
    }

    dlg:newrow { always = false }

    dlg:button {
        id = "appendButton",
        text = "&ADD",
        focus = false,
        onclick = function()
            local args = dlg.data
            local oldColors = args.shades
            local lenOldColors = #oldColors

            local newColors = {}
            local h = 0
            while h < lenOldColors do
                h = h + 1
                newColors[h] = oldColors[h]
            end

            local activeSprite = app.activeSprite
            if activeSprite then
                local range = app.range
                local rangeColors = range.colors
                local lenRangeColors = #rangeColors
                if lenRangeColors > 0 then
                    local pal = AseUtilities.getPalette(
                        app.activeFrame, activeSprite.palettes)
                    local i = 0
                    while i < lenRangeColors do i = i + 1
                        local idx = rangeColors[i]
                        local clr = pal:getColor(idx)
                        newColors[lenOldColors + i] = clr
                    end
                else
                    -- If there are no colors in the shades,
                    -- then add both the back- and fore-colors.
                    if lenOldColors < 1 then
                        app.command.SwitchColors()
                        local bgClr = app.fgColor
                        table.insert(newColors, AseUtilities.aseColorCopy(
                            bgClr, "UNBOUNDED"))
                        app.command.SwitchColors()
                    end

                    local fgClr = app.fgColor
                    table.insert(newColors, AseUtilities.aseColorCopy(
                        fgClr, "UNBOUNDED"))

                end
            end

            dlg:modify { id = "shades", colors = newColors }
        end
    }

    dlg:button {
        id = "flipButton",
        text = "&FLIP",
        focus = false,
        onclick = function()
            dlg:modify {
                id = "shades",
                colors = Utilities.reverseTable(dlg.data.shades)
            }
        end
    }

    dlg:button {
        id = "splineButton",
        text = "&SMOOTH",
        focus = false,
        onclick = function()
            local args = dlg.data
            local oldColors = args.shades
            local lenOldColors = #oldColors
            if lenOldColors < 2 then return end
            if lenOldColors > 64 then return end

            local h = 0
            local points = {}
            local alphas = {}
            while h < lenOldColors do
                h = h + 1
                local clr = AseUtilities.aseColorToClr(oldColors[h])
                local lab = Clr.sRgbToSrLab2(clr)
                points[h] = Vec3.new(lab.a, lab.b, lab.l)
                alphas[h] = clr.a
            end

            local curve = Curve3.fromCatmull(false, points, 0.0)

            local sampleCount = math.min(math.max(
                lenOldColors * 2 - 1, 3), 64)
            local newColors = {}
            local i = 0
            local iToFac = 1.0 / (sampleCount - 1.0)
            local locn1 = lenOldColors - 1
            while i < sampleCount do
                local iFac = i * iToFac
                local alpha = 1.0
                if iFac <= 0.0 then
                    alpha = alphas[1]
                elseif iFac >= 1.0 then
                    alpha = alphas[lenOldColors]
                else
                    local aScaled = iFac * locn1
                    local aFloor = math.floor(aScaled)
                    local aFrac = aScaled - aFloor;
                    alpha = (1.0 - aFrac) * alphas[1 + aFloor]
                        + aFrac * alphas[2 + aFloor]
                end
                local point = Curve3.eval(curve, iFac)
                i = i + 1
                newColors[i] = AseUtilities.clrToAseColor(
                    Clr.srLab2TosRgb(
                        point.z, point.x, point.y, alpha))
            end

            dlg:modify { id = "shades", colors = newColors }
        end
    }

    dlg:button {
        id = "clearButton",
        text = "C&LEAR",
        focus = false,
        onclick = function()
            dlg:modify { id = "shades", colors = {} }
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "clrSpacePreset",
        label = "Space:",
        option = GradientUtilities.DEFAULT_CLR_SPC,
        options = GradientUtilities.CLR_SPC_PRESETS,
        onchange = function()
            local md = dlg.data.clrSpacePreset
            dlg:modify {
                id = "huePreset",
                visible = md == "HSL"
                    or md == "HSV"
                    or md == "SR_LCH"
            }
            dlg:modify {
                id = "easPreset",
                visible = md == "LINEAR_RGB"
                    or md == "NORMAL_MAP"
                    or md == "S_RGB"
                    or md == "SR_LAB_2"
            }
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "huePreset",
        label = "Easing:",
        option = GradientUtilities.DEFAULT_HUE_EASING,
        options = GradientUtilities.HUE_EASING_PRESETS,
        visible = true
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "easPreset",
        label = "Easing:",
        option = GradientUtilities.DEFAULT_RGB_EASING,
        options = GradientUtilities.RGB_EASING_PRESETS,
        visible = false
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "quantize",
        label = "Quantize:",
        min = 0,
        max = 32,
        value = 0
    }

    dlg:newrow { always = false }
end

---Returns a factor that eases in by a circular arc.
---@param t number factor
---@return number
function GradientUtilities.easeInCirc(t)
    return 1.0 - math.sqrt(1.0 - t * t)
end

---Returns a factor that eases out by a circular arc.
---@param t number factor
---@return number
function GradientUtilities.easeOutCirc(t)
    local u = t - 1.0
    return math.sqrt(1.0 - u * u)
end

---Finds the appropriate easing function in RGB
---given a preset.
---@param preset string rgb preset
---@return function
function GradientUtilities.easingFuncFromPreset(preset)
    if preset == "EASE_IN_CIRC" then
        return GradientUtilities.easeInCirc
    elseif preset == "EASE_OUT_CIRC" then
        return GradientUtilities.easeOutCirc
    elseif preset == "SMOOTH" then
        return GradientUtilities.smooth
    elseif preset == "SMOOTHER" then
        return GradientUtilities.smoother
    else
        return GradientUtilities.linear
    end
end

---Finds the appropriate easing function in HSL or HSV
---given a preset.
---@param preset string hue preset
---@return function
function GradientUtilities.hueEasingFuncFromPreset(preset)
    if preset == "CCW" then
        return GradientUtilities.lerpHueCcw
    elseif preset == "CW" then
        return GradientUtilities.lerpHueCw
    elseif preset == "FAR" then
        return GradientUtilities.lerpHueFar
    else
        return GradientUtilities.lerpHueNear
    end
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the counter-clockwise
---direction.
---@param a number origin
---@param b number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueCcw(a, b, t)
    return Utilities.lerpAngleCcw(a, b, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the clockwise
---direction.
---@param a number origin
---@param b number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueCw(a, b, t)
    return Utilities.lerpAngleCw(a, b, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the far
---direction.
---@param a number origin
---@param b number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueFar(a, b, t)
    return Utilities.lerpAngleFar(a, b, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the near
---direction.
---@param a number origin
---@param b number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueNear(a, b, t)
    return Utilities.lerpAngleNear(a, b, t, 1.0)
end

---Returns a linear step factor.
---@param t number factor
---@return number
function GradientUtilities.linear(t)
    return t
end

---Returns a smooth step factor.
---@param t number factor
---@return number
function GradientUtilities.smooth(t)
    return t * t * (3.0 - (t + t))
end

---Returns a smoother step factor.
---@param t number factor
---@return number
function GradientUtilities.smoother(t)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
end

return GradientUtilities