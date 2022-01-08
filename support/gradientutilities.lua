dofile("./utilities.lua")
dofile("./clr.lua")

GradientUtilities = {}
GradientUtilities.__index = GradientUtilities

setmetatable(GradientUtilities, {
    __call = function (cls, ...)
        return cls.new(...)
    end})

GradientUtilities.CLR_SPC_PRESETS = {
    "CIE_LAB",
    "CIE_LCH",
    "CIE_XYZ",
    "HSL",
    "HSV",
    "LINEAR_RGB",
    "S_RGB"
}

GradientUtilities.HUE_EASING_PRESETS = {
    "CCW",
    "CW",
    "FAR",
    "NEAR"
}

GradientUtilities.RGB_EASING_PRESETS = {
    "EASE_IN_CIRC",
    "EASE_OUT_CIRC",
    "LINEAR",
    "SMOOTH",
    "SMOOTHER"
}

GradientUtilities.TWEEN_PRESETS = {
    "PAIR",
    "PALETTE"
}

---Finds the appropriate color easing function based on
---the color space preset, RGB preset and hue preset.
---@param clrSpcPreset string color space preset
---@param rgbPreset string rgb preset
---@param huePreset string hue preset
---@return function
function GradientUtilities.clrSpcFuncFromPreset(clrSpcPreset, rgbPreset, huePreset)
    if clrSpcPreset == "CIE_LAB" then
        -- TODO: Support rgbEasingFuncs?
        return Clr.mixLabInternal
    elseif clrSpcPreset == "CIE_LCH" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixLchInternal(a, b, t, hef)
        end
    elseif clrSpcPreset == "CIE_XYZ" then
        return Clr.mixXyzInternal
    elseif clrSpcPreset == "HSL" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixHslaInternal(a, b, t, hef)
        end
    elseif clrSpcPreset == "HSV" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(a, b, t)
            return Clr.mixHsvaInternal(a, b, t, hef)
        end
    elseif clrSpcPreset == "LINEAR_RGB" then
        local rgbef = GradientUtilities.rgbEasingFuncFromPreset(rgbPreset)
        return function(a, b, t)
            return Clr.mixsRgbaInternal(a, b, rgbef(t))
        end
    else
        local rgbef = GradientUtilities.rgbEasingFuncFromPreset(rgbPreset)
        return function(a, b, t)
            return Clr.mixlRgbaInternal(a, b, rgbef(t))
        end
    end
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

---Finds the appropriate easing function in RGB
---given a preset.
---@param preset string rgb preset
---@return function
function GradientUtilities.rgbEasingFuncFromPreset(preset)
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