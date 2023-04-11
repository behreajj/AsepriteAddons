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
    "CIRCLE_IN",
    "CIRCLE_OUT",
    "LINEAR",
    "SMOOTH",
    "SMOOTHER"
}

---Style presets.
GradientUtilities.STYLE_PRESETS = {
    "DITHER_BAYER",
    "DITHER_CUSTOM",
    "MIXED"
}

---Default color space preset.
GradientUtilities.DEFAULT_CLR_SPC = "SR_LCH"

---Default hue easing preset.
GradientUtilities.DEFAULT_HUE_EASING = "NEAR"

---Default linear easing preset.
GradientUtilities.DEFAULT_RGB_EASING = "LINEAR"

---Default style preset.
GradientUtilities.DEFAULT_STYLE = "MIXED"

---Bayer dithering matrices, in 2^1, 2^2, 2^3
---or 2x2, 4x4, 8x8. For matrix generators, see
---https://codegolf.stackexchange.com/q/259633
---and https://www.shadertoy.com/view/XtV3RG .
---More than 2^4 is overkill for 8-bit color.
---The largest element is rows * columns - 1.
---These are normalized in a non-standard way
---for the sake of consistency with custom
---dither matrices.
GradientUtilities.BAYER_MATRICES = {
    {
        0.2, 0.6,
        0.8, 0.4
    },
    {
        0.05882353, 0.52940776, 0.17646959, 0.64705382,
        0.76469988, 0.29411565, 0.88234594, 0.41176171,
        0.23528512, 0.70588435, 0.11763906, 0.58823829,
        0.94117647, 0.47059224, 0.82353041, 0.35293118
    },
    {
        0.01538462, 0.50768631, 0.13842854, 0.63079323, 0.04612985, 0.53843154, 0.16923677, 0.66153846,
        0.75383715, 0.26153546, 0.87694408, 0.38457938, 0.78464539, 0.29228069, 0.90768931, 0.41538762,
        0.19998200, 0.69228369, 0.07687508, 0.56923977, 0.23072723, 0.72309192, 0.10768331, 0.59998500,
        0.93849754, 0.44613285, 0.81539062, 0.32308892, 0.96924277, 0.47694108, 0.84613585, 0.35383415,
        0.06150246, 0.55386715, 0.18460938, 0.67691108, 0.03075723, 0.52305892, 0.15380115, 0.64616585,
        0.80001800, 0.30765331, 0.92306192, 0.43076023, 0.76920977, 0.27690808, 0.89231669, 0.40001500,
        0.24616285, 0.73846454, 0.12305592, 0.61535761, 0.21535461, 0.70771931, 0.09231069, 0.58461238,
        0.98461538, 0.49231369, 0.86157146, 0.36920677, 0.95387015, 0.46150546, 0.83076323, 0.33846154
    }
}

--- Maximum width or height for a custom dither image.
GradientUtilities.DITHER_MAX_SIZE = 32

---Converts an array of Aseprite colors to a
---ClrGradient. If the number of colors is less
---than one, returns a gradient with black and
---white. If the number is less than two, returns
---with the original color and its opaque variant.
---@param aseColors Color[] array of aseprite colors
---@return ClrGradient
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
    if clrSpcPreset == "LINEAR_RGB" then
        return Clr.mixsRgbInternal
    elseif clrSpcPreset == "NORMAL_MAP" then
        return Clr.mixNormal
    elseif clrSpcPreset == "SR_LAB_2" then
        return Clr.mixSrLab2Internal
    elseif clrSpcPreset == "SR_LCH" then
        local hef = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        return function(o, d, t)
            return Clr.mixSrLchInternal(o, d, t, hef)
        end
    else
        return Clr.mixlRgbaInternal
    end
end

---Generates the dialog widgets shared across
---gradient dialogs. Places a new row at the
---end of the widgets. The show style flag specifies
---whether to show the style combo box for gradients
---which allow dithered vs. mixed color.
---@param dlg Dialog dialog
---@param showStyle boolean? show style combo box
function GradientUtilities.dialogWidgets(dlg, showStyle)
    dlg:shades {
        id = "shades",
        label = "Colors:",
        mode = "sort",
        colors = {}
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
                local tlHidden = not app.preferences.general.visible_timeline
                if tlHidden then
                    app.command.Timeline { open = true }
                end

                -- Range colors do not seem to have the same issue as range
                -- layers and frames? They appear to be cleared automatically
                -- on sprite tab change.
                local appRange = app.range
                local validRange = false
                -- if appRange.sprite == activeSprite then
                local rangeColors = appRange.colors
                local lenRangeColors = #rangeColors
                if lenRangeColors > 0 then
                    validRange = true
                    local pal = AseUtilities.getPalette(
                        app.activeFrame, activeSprite.palettes)
                    local i = 0
                    while i < lenRangeColors do
                        i = i + 1
                        local idx = rangeColors[i]
                        local clr = pal:getColor(idx)
                        newColors[lenOldColors + i] = clr
                    end
                end
                -- end

                if tlHidden then
                    app.command.Timeline { close = true }
                end

                if not validRange then
                    -- If there are no colors in the shades,
                    -- then add both the back- and fore-colors.
                    if lenOldColors < 1 then
                        app.command.SwitchColors()
                        local bgClr = app.fgColor
                        newColors[#newColors + 1] = AseUtilities.aseColorCopy(
                            bgClr, "UNBOUNDED")
                        app.command.SwitchColors()
                    end

                    local fgClr = app.fgColor
                    newColors[#newColors + 1] = AseUtilities.aseColorCopy(
                        fgClr, "UNBOUNDED")
                end
            end --End of activeSprite check

            dlg:modify { id = "shades", colors = newColors }
        end
    }

    dlg:button {
        id = "flipButton",
        text = "&FLIP",
        focus = false,
        onclick = function()
            local s = dlg.data.shades --[[@as table]]
            dlg:modify {
                id = "shades",
                colors = Utilities.reverseTable(s)
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
        id = "stylePreset",
        label = "Style:",
        option = GradientUtilities.DEFAULT_STYLE,
        options = GradientUtilities.STYLE_PRESETS,
        visible = showStyle,
        onchange = function()
            local args = dlg.data

            local style = args.stylePreset --[[@as string]]
            local isMixed = style == "MIXED"
            local isBayer = style == "DITHER_BAYER"
            local isCustom = style == "DITHER_CUSTOM"

            local csp = args.clrSpacePreset --[[@as string]]
            local isPolar = csp == "SR_LCH"

            dlg:modify {
                id = "clrSpacePreset",
                visible = isMixed
            }
            dlg:modify {
                id = "huePreset",
                visible = isMixed and isPolar
            }
            dlg:modify {
                id = "easPreset",
                visible = isMixed and (not isPolar)
            }
            dlg:modify {
                id = "quantize",
                visible = isMixed
            }
            dlg:modify {
                id = "bayerIndex",
                visible = isBayer
            }
            dlg:modify {
                id = "ditherPath",
                visible = isCustom
            }
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "clrSpacePreset",
        label = "Space:",
        option = GradientUtilities.DEFAULT_CLR_SPC,
        options = GradientUtilities.CLR_SPC_PRESETS,
        visible = (not showStyle) or
            GradientUtilities.DEFAULT_STYLE == "MIXED",
        onchange = function()
            local args = dlg.data
            local style = args.stylePreset --[[@as string]]
            local csp = args.clrSpacePreset --[[@as string]]
            local isPolar = csp == "SR_LCH"
            local isMixed = style == "MIXED"
            dlg:modify {
                id = "huePreset",
                visible = isMixed and isPolar
            }
            dlg:modify {
                id = "easPreset",
                visible = isMixed and (not isPolar)
            }
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "huePreset",
        label = "Easing:",
        option = GradientUtilities.DEFAULT_HUE_EASING,
        options = GradientUtilities.HUE_EASING_PRESETS,
        visible = ((not showStyle)
            or GradientUtilities.DEFAULT_STYLE == "MIXED")
            and GradientUtilities.DEFAULT_CLR_SPC == "SR_LCH"
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "easPreset",
        label = "Easing:",
        option = GradientUtilities.DEFAULT_RGB_EASING,
        options = GradientUtilities.RGB_EASING_PRESETS,
        visible = ((not showStyle)
            or GradientUtilities.DEFAULT_STYLE == "MIXED")
            and GradientUtilities.DEFAULT_CLR_SPC ~= "SR_LCH"
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "quantize",
        label = "Quantize:",
        min = 0,
        max = 32,
        value = 0,
        visible = (not showStyle) or
            GradientUtilities.DEFAULT_STYLE == "MIXED"
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "bayerIndex",
        label = "Size (2^n):",
        min = 1,
        max = 3,
        value = 2,
        visible = showStyle
            and GradientUtilities.DEFAULT_STYLE == "DITHER_BAYER"
    }

    dlg:newrow { always = false }

    dlg:file {
        id = "ditherPath",
        label = "File:",
        filetypes = AseUtilities.FILE_FORMATS,
        open = true,
        focus = false,
        visible = showStyle
            and GradientUtilities.DEFAULT_STYLE == "DITHER_CUSTOM"
    }

    dlg:newrow { always = false }
end

---Returns a factor that eases in by a circular arc.
---@param t number factor
---@return number
function GradientUtilities.circleIn(t)
    return 1.0 - math.sqrt(1.0 - t * t)
end

---Returns a factor that eases out by a circular arc.
---@param t number factor
---@return number
function GradientUtilities.circleOut(t)
    local u = t - 1.0
    return math.sqrt(1.0 - u * u)
end

---Finds the appropriate easing function in RGB
---given a preset.
---@param preset string rgb preset
---@return function
function GradientUtilities.easingFuncFromPreset(preset)
    if preset == "CIRCLE_IN" then
        return GradientUtilities.circleIn
    elseif preset == "CIRCLE_OUT" then
        return GradientUtilities.circleOut
    elseif preset == "SMOOTH" then
        return GradientUtilities.smooth
    elseif preset == "SMOOTHER" then
        return GradientUtilities.smoother
    else
        return GradientUtilities.linear
    end
end

---Finds the appropriate color gradient easing function
---based on whether the gradient should mix colors or
---choose based on a dithering matrix.
---@param stylePreset string style preset
---@param bayerIndex integer? Bayer exponent, 2^1
---@param ditherPath string? dither image path
---@return function
function GradientUtilities.evalFromStylePreset(
    stylePreset, bayerIndex, ditherPath)
    if stylePreset == "DITHER_BAYER" then
        local matrix = GradientUtilities.BAYER_MATRICES[bayerIndex]
        local bayerSize = 2 ^ bayerIndex

        return function(cg, step, easing, x, y)
            return ClrGradient.dither(
                cg, step, matrix,
                x, y, bayerSize, bayerSize)
        end
    elseif stylePreset == "DITHER_CUSTOM" then
        local matrix = GradientUtilities.BAYER_MATRICES[2]
        local c = 4
        local r = 4

        if ditherPath and #ditherPath > 0
            and app.fs.isFile(ditherPath) then
            local image = Image { fromFile = ditherPath }
            if image then
                matrix, c, r = GradientUtilities.imageToMatrix(image)
            end -- End image exists check.
        end     -- End file path validity check.

        return function(cg, step, easing, x, y)
            return ClrGradient.dither(
                cg, step, matrix,
                x, y, c, r)
        end
    else
        -- Default to mix.
        return function(cg, step, easing, x, y)
            return ClrGradient.eval(cg, step, easing)
        end
    end
end

---Converts an Aseprite image to a dithering matrix. Returns
---the matrix along with its width (columns), height (rows)
---maximum and minimum element. Indexed images depend on
---a palette argument. If nil, then the image's indices will
---be used instead of their color referents. Images greater
---than the size limit will not be considered, and a default
---will be returned.
---@param image Image image
---@return number[] matrix
---@return integer columns
---@return integer rows
function GradientUtilities.imageToMatrix(image)
    -- Intended for use with:
    -- https://bitbucket.org/jjhaggar/aseprite-dithering-matrices,

    local spec = image.spec
    local width = spec.width
    local height = spec.height
    local mxElm = -2147483648
    local mnElm = 2147483647
    local uniques = {}
    local lenUniques = 0

    if width > GradientUtilities.DITHER_MAX_SIZE
        or height > GradientUtilities.DITHER_MAX_SIZE
        or (width < 2 and height < 2) then
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    local colorMode = spec.colorMode
    local pxItr = image:pixels()
    local matrix = {}

    local lenMat = 0
    if colorMode == ColorMode.RGB then
        local fromHex = Clr.fromHex
        local floor = math.floor
        local sRgbToLab = Clr.sRgbToSrLab2

        for pixel in pxItr do
            local hex = pixel()
            local c = fromHex(hex)
            local lab = sRgbToLab(c)
            local v = floor(lab.l * 25.5 + 0.5)
            if v > mxElm then mxElm = v end
            if v < mnElm then mnElm = v end
            if not uniques[v] then
                lenUniques = lenUniques + 1
                uniques[v] = true
            end
            lenMat = lenMat + 1
            matrix[lenMat] = v
        end
    elseif colorMode == ColorMode.GRAY then
        for pixel in pxItr do
            local hex = pixel()
            local v = hex & 0xff
            if v > mxElm then mxElm = v end
            if v < mnElm then mnElm = v end
            if not uniques[v] then
                lenUniques = lenUniques + 1
                uniques[v] = true
            end
            lenMat = lenMat + 1
            matrix[lenMat] = v
        end
    elseif colorMode == ColorMode.INDEXED then
        -- Apparently this is how indexed dithers are
        -- supposed to work.
        -- https://github.com/aseprite/aseprite/issues/2573#issuecomment-736074731
        for pixel in pxItr do
            local i = pixel()
            if i > mxElm then mxElm = i end
            if i < mnElm then mnElm = i end
            if not uniques[i] then
                lenUniques = lenUniques + 1
                uniques[i] = true
            end
            lenMat = lenMat + 1
            matrix[lenMat] = i
        end
    else
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    -- Normalize range.
    local range = math.abs(mxElm - mnElm)
    if range ~= 0 then
        local orig = 1.0 / (lenUniques + 1)
        local dest = 1.0 - orig
        local denom = 1.0 / range
        local j = 0
        while j < lenMat do
            j = j + 1
            local t = (matrix[j] - mnElm) * denom
            matrix[j] = (1.0 - t) * orig + t * dest
        end
    end

    return matrix, width, height
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
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueCcw(o, d, t)
    return Utilities.lerpAngleCcw(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the clockwise
---direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueCw(o, d, t)
    return Utilities.lerpAngleCw(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the far
---direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueFar(o, d, t)
    return Utilities.lerpAngleFar(o, d, t, 1.0)
end

---Interpolates a hue from an origin to a destination
---by a factor in [0.0, 1.0] in the near
---direction.
---@param o number origin
---@param d number destination
---@param t number factor
---@return number
function GradientUtilities.lerpHueNear(o, d, t)
    return Utilities.lerpAngleNear(o, d, t, 1.0)
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