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
    "DITHER_NOISE",
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
---@type number[][]
GradientUtilities.BAYER_MATRICES = {
    {
        0.125, 0.625,
        0.875, 0.375
    },
    {
        0.03125, 0.53125, 0.15625, 0.65625,
        0.78125, 0.28125, 0.90625, 0.40625,
        0.21875, 0.71875, 0.09375, 0.59375,
        0.96875, 0.46875, 0.84375, 0.34375
    },
    {
        0.007813, 0.507813, 0.132813, 0.632813, 0.039063, 0.539063, 0.164063, 0.664063,
        0.757813, 0.257813, 0.882813, 0.382813, 0.789063, 0.289063, 0.914063, 0.414063,
        0.195313, 0.695313, 0.070313, 0.570313, 0.226563, 0.726563, 0.101563, 0.601563,
        0.945313, 0.445313, 0.820313, 0.320313, 0.976563, 0.476563, 0.851563, 0.351563,
        0.054688, 0.554688, 0.179688, 0.679688, 0.023438, 0.523438, 0.148438, 0.648438,
        0.804688, 0.304688, 0.929688, 0.429688, 0.773438, 0.273438, 0.898438, 0.398438,
        0.242188, 0.742188, 0.117188, 0.617188, 0.210938, 0.710938, 0.085938, 0.585938,
        0.992188, 0.492188, 0.867188, 0.367188, 0.960938, 0.460938, 0.835938, 0.335938
    }
}

--- Maximum width or height for a custom dither image.
GradientUtilities.DITHER_MAX_SIZE = 64

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

    ---@type ClrKey[]
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
---@return fun(o: Clr, d: Clr, t: number): Clr
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
            local oldColors = args.shades --[=[@as Color[]]=]
            local lenOldColors = #oldColors

            ---@type Color[]
            local newColors = {}
            local h = 0
            while h < lenOldColors do
                h = h + 1
                newColors[h] = oldColors[h]
            end

            local activeSprite = app.site.sprite
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
                end -- End of invalid range check
            end     -- End of activeSprite check

            dlg:modify { id = "shades", colors = newColors }
        end
    }

    dlg:button {
        id = "flipButton",
        text = "&FLIP",
        focus = false,
        onclick = function()
            local args = dlg.data
            local s = args.shades --[=[@as Color[]]=]
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
            local oldColors = args.shades --[=[@as Color[]]=]
            local lenOldColors = #oldColors
            if lenOldColors < 2 then return end
            if lenOldColors > 64 then return end

            ---@type Color[]
            local newColors = {}

            -- Use LCH for two colors, otherwise use curve.
            if lenOldColors < 3 then
                local huePreset = args.huePreset --[[@as string]]
                local mixer = GradientUtilities.hueEasingFuncFromPreset(huePreset)
                local leftEdge = oldColors[1]
                local rightEdge = oldColors[2]

                newColors[1] = AseUtilities.aseColorCopy(
                    leftEdge, "UNBOUNDED")
                newColors[2] = AseUtilities.clrToAseColor(
                    Clr.mixSrLchInternal(
                        AseUtilities.aseColorToClr(leftEdge),
                        AseUtilities.aseColorToClr(rightEdge),
                        0.5, mixer))
                newColors[3] = AseUtilities.aseColorCopy(
                    rightEdge, "UNBOUNDED")
            else
                -- Cache methods used in loop.
                local floor = math.floor
                local eval = Curve3.eval
                local aseToClr = AseUtilities.aseColorToClr
                local clrToAse = AseUtilities.clrToAseColor
                local labTosRgb = Clr.srLab2TosRgb
                local sRgbToLab = Clr.sRgbToSrLab2

                local h = 0
                ---@type Vec3[]
                local points = {}
                ---@type number[]
                local alphas = {}
                while h < lenOldColors do
                    h = h + 1
                    local clr = aseToClr(oldColors[h])
                    local lab = sRgbToLab(clr)
                    points[h] = Vec3.new(lab.a, lab.b, lab.l)
                    alphas[h] = clr.a
                end

                local curve = Curve3.fromCatmull(false, points, 0.0)

                local sampleCount = math.min(math.max(
                    lenOldColors * 2 - 1, 3), 64)
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
                        local aFloor = floor(aScaled)
                        local aFrac = aScaled - aFloor;
                        alpha = (1.0 - aFrac) * alphas[1 + aFloor]
                            + aFrac * alphas[2 + aFloor]
                    end
                    local point = eval(curve, iFac)
                    i = i + 1
                    newColors[i] = clrToAse(labTosRgb(
                        point.z, point.x, point.y, alpha))
                end
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
---@return fun(t: number): number
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

---Finds the appropriate color gradient dither from
---a string preset. "DITHER_CUSTOM" will return a
---custom matrix loaded from an image file path.
---"DITHER_BAYER" returns a Bayer matrix.
---Defaults to a smooth mix.
---@param stylePreset string style preset
---@param bayerIndex integer? Bayer exponent, 2^1
---@param ditherPath string? dither image path
---@return fun(cg: ClrGradient, step: number, x: integer, y: integer): Clr
function GradientUtilities.ditherFromPreset(
    stylePreset, bayerIndex, ditherPath)
    if stylePreset == "DITHER_BAYER" then
        local biVrf = bayerIndex or 2
        local matrix = GradientUtilities.BAYER_MATRICES[biVrf]
        local bayerSize = 1 << biVrf

        return function(cg, step, x, y)
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

        return function(cg, step, x, y)
            return ClrGradient.dither(
                cg, step, matrix,
                x, y, c, r)
        end
    else
        return ClrGradient.noise
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

    if width > GradientUtilities.DITHER_MAX_SIZE
        or height > GradientUtilities.DITHER_MAX_SIZE
        or (width < 2 and height < 2) then
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    local colorMode = spec.colorMode
    local pxItr = image:pixels()
    ---@type number[]
    local matrix = {}
    local lenMat = 0

    if colorMode == ColorMode.RGB then
        -- Problem with this approach is that no one
        -- will agree on RGB to gray conversion.
        -- To unpack colors to floats, you could try, e.g.,
        -- string.unpack("f", string.pack("i", 0x40490FDB))
        local fromHex = Clr.fromHex
        local sRgbToLab = Clr.sRgbToSrLab2

        for pixel in pxItr do
            local hex = pixel()
            local srgb = fromHex(hex)
            local lab = sRgbToLab(srgb)
            local v = lab.l * 0.01
            lenMat = lenMat + 1
            matrix[lenMat] = v
        end
    elseif colorMode == ColorMode.GRAY then
        for pixel in pxItr do
            local hex = pixel()
            local v = (hex & 0xff) * 0.003921568627451
            lenMat = lenMat + 1
            matrix[lenMat] = v
        end
    elseif colorMode == ColorMode.INDEXED then
        -- https://github.com/aseprite/aseprite/
        -- issues/2573#issuecomment-736074731
        local mxElm = -2147483648
        local mnElm = 2147483647

        for pixel in pxItr do
            local i = pixel()
            if i > mxElm then mxElm = i end
            if i < mnElm then mnElm = i end
            lenMat = lenMat + 1
            matrix[lenMat] = i
        end

        -- Normalize. Include half edges.
        mnElm = mnElm - 0.5
        mxElm = mxElm + 0.5
        local range = math.abs(mxElm - mnElm)
        if range > 0.0 then
            local denom = 1.0 / range
            local j = 0
            while j < lenMat do
                j = j + 1
                matrix[j] = (matrix[j] - mnElm) * denom
            end
        end
    else
        return GradientUtilities.BAYER_MATRICES[2], 4, 4
    end

    return matrix, width, height
end

---Finds the appropriate easing function in HSL or HSV
---given a preset.
---@param preset string hue preset
---@return fun(o: number, d: number, t: number): number
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