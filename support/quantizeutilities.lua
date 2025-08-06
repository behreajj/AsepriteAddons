--[[
Ditherpunk
https://surma.dev/things/ditherpunk/
Riemersma dither
https://www.compuphase.com/riemer.htm
Blue Noise dither
http://momentsingraphics.de/BlueNoise.html
Speeding up your code when multiple cores aren’t an option
https://pythonspeed.com/articles/optimizing-dithering/
]]

QuantizeUtilities = {}
QuantizeUtilities.__index = QuantizeUtilities

---Modes for handling alpha in dithers.
QuantizeUtilities.ALPHA_MODES = { "SOURCE", "THRESHOLD" }

---Default bits for alpha channel.
QuantizeUtilities.BITS_DEFAULT_A = 4

---Default bits for RGB channels.
QuantizeUtilities.BITS_DEFAULT_RGB = 4

---Maximum bits per color channel.
QuantizeUtilities.BITS_MAX = 8

---Minimum bits per color channel.
QuantizeUtilities.BITS_MIN = 1

---Patterns when dithering an image.
QuantizeUtilities.DITHER_PATTERNS = {
    "DITHER_BAYER",
    "DITHER_CUSTOM",
    "FLOYD_STEINBERG",
}

---Default display uniformity.
QuantizeUtilities.INPUT_DEFAULT = "UNIFORM"

---Channel display uniformity presets.
QuantizeUtilities.INPUTS = { "NON_UNIFORM", "UNIFORM" }

---Default levels for alpha channel.
QuantizeUtilities.LEVELS_DEFAULT_A = 16

---Default levels for RGB channels.
QuantizeUtilities.LEVELS_DEFAULT_RGB = 16

---Maximum levels per color channel.
QuantizeUtilities.LEVELS_MAX = 256

---Minimum levels per color channel.
QuantizeUtilities.LEVELS_MIN = 2

---Default quantization method.
QuantizeUtilities.METHOD_DEFAULT = "UNSIGNED"

---Quantization method presets.
QuantizeUtilities.METHODS = { "SIGNED", "UNSIGNED" }

---Default channel unit of measure.
QuantizeUtilities.UNIT_DEFAULT = "BITS"

---Channel unit of measure presets.
QuantizeUtilities.UNITS = { "BITS", "INTEGERS" }

setmetatable(QuantizeUtilities, {
    __call = function(cls, ...)
        return cls.new(...)
    end
})

---Finds an alpha function based on a preset.
---Presets include "THRESHOLD" and "SOURCE".
---Defaults to returning alpha source unchanged.
---@param preset string alpha preset
---@return fun(a8: integer): integer
function QuantizeUtilities.alphaFuncFromPreset(preset)
    if preset == "THRESHOLD" then
        return QuantizeUtilities.alphaFuncThreshold
    end
    return QuantizeUtilities.alphaFuncSource
end

---Returns the source alpha.
---@param a8 integer alpha source
---@return integer
---@nodiscard
function QuantizeUtilities.alphaFuncSource(a8)
    return a8
end

---Returns the thresholded alpha, 255 if the source is greater
---than or equal to the threshold. Otherwise, zero.
---Threshold defaults to 128
---@param a8 integer alpha source
---@return integer
---@nodiscard
function QuantizeUtilities.alphaFuncThreshold(a8)
    return a8 >= 128 and 255 or 0
end

---Generates the dialog widgets shared across color quantization dialogs.
---Places a new row at the end of the widgets. Enable alpha does not impact
---widget visibility, only functionality.
---@param dlg Dialog dialog
---@param isVisible boolean visible by default
---@param enableAlpha boolean enable alpha channel
function QuantizeUtilities.dialogWidgets(dlg, isVisible, enableAlpha)
    dlg:combobox {
        id = "method",
        label = "Method:",
        option = QuantizeUtilities.METHOD_DEFAULT,
        options = QuantizeUtilities.METHODS,
        focus = false,
        visible = isVisible,
        hexpand = false,
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "levelsInput",
        label = "Channels:",
        option = QuantizeUtilities.INPUT_DEFAULT,
        options = QuantizeUtilities.INPUTS,
        focus = false,
        visible = isVisible,
        hexpand = false,
        onchange = function()
            local args <const> = dlg.data

            local md <const> = args.levelsInput --[[@as string]]
            local isu <const> = md == "UNIFORM"
            local isnu <const> = md == "NON_UNIFORM"

            local unit <const> = args.unitsInput --[[@as string]]
            local isbit <const> = unit == "BITS"
            local isint <const> = unit == "INTEGERS"

            dlg:modify { id = "rBits", visible = isnu and isbit }
            dlg:modify { id = "gBits", visible = isnu and isbit }
            dlg:modify { id = "bBits", visible = isnu and isbit }
            dlg:modify { id = "aBits", visible = isnu and isbit }
            dlg:modify {
                id = "bitsUni",
                visible = isu and isbit
            }

            dlg:modify { id = "rLevels", visible = isnu and isint }
            dlg:modify { id = "gLevels", visible = isnu and isint }
            dlg:modify { id = "bLevels", visible = isnu and isint }
            dlg:modify { id = "aLevels", visible = isnu and isint }
            dlg:modify {
                id = "levelsUni",
                visible = isu and isint
            }
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "levelsUni",
        label = "Levels:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS",
        onchange = function()
            local args <const> = dlg.data
            local uni <const> = args.levelsUni --[[@as integer]]
            dlg:modify { id = "rLevels", value = uni }
            dlg:modify { id = "gLevels", value = uni }
            dlg:modify { id = "bLevels", value = uni }
            if enableAlpha then
                dlg:modify { id = "aLevels", value = uni }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "rLevels",
        label = "Red:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "gLevels",
        label = "Green:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "bLevels",
        label = "Blue:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:slider {
        id = "aLevels",
        label = "Alpha:",
        min = QuantizeUtilities.LEVELS_MIN,
        max = QuantizeUtilities.LEVELS_MAX,
        value = QuantizeUtilities.LEVELS_DEFAULT_A,
        focus = false,
        enabled = enableAlpha,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "INTEGERS"
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "bitsUni",
        label = "Bits:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local bd <const> = args.bitsUni --[[@as integer]]
            dlg:modify { id = "rBits", value = bd }
            dlg:modify { id = "gBits", value = bd }
            dlg:modify { id = "bBits", value = bd }
            if enableAlpha then
                dlg:modify { id = "aBits", value = bd }
            end

            local lv <const> = 1 << bd
            dlg:modify { id = "levelsUni", value = lv }
            dlg:modify { id = "rLevels", value = lv }
            dlg:modify { id = "gLevels", value = lv }
            dlg:modify { id = "bLevels", value = lv }
            if enableAlpha then
                dlg:modify { id = "aLevels", value = lv }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:slider {
        id = "rBits",
        label = "Red:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local rBits <const> = args.rBits --[[@as integer]]
            local lv <const> = 1 << rBits
            dlg:modify { id = "rLevels", value = lv }
        end
    }

    dlg:slider {
        id = "gBits",
        label = "Green:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local gBits <const> = args.gBits --[[@as integer]]
            local lv <const> = 1 << gBits
            dlg:modify { id = "gLevels", value = lv }
        end
    }

    dlg:slider {
        id = "bBits",
        label = "Blue:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_RGB,
        focus = false,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            local args <const> = dlg.data
            local bBits <const> = args.bBits --[[@as integer]]
            local lv <const> = 1 << bBits
            dlg:modify { id = "bLevels", value = lv }
        end
    }

    dlg:slider {
        id = "aBits",
        label = "Alpha:",
        min = QuantizeUtilities.BITS_MIN,
        max = QuantizeUtilities.BITS_MAX,
        value = QuantizeUtilities.BITS_DEFAULT_A,
        focus = false,
        enabled = enableAlpha,
        visible = isVisible
            and QuantizeUtilities.INPUT_DEFAULT == "NON_UNIFORM"
            and QuantizeUtilities.UNIT_DEFAULT == "BITS",
        onchange = function()
            if enableAlpha then
                local args <const> = dlg.data
                local aBits <const> = args.aBits --[[@as integer]]
                local lv <const> = 1 << aBits
                dlg:modify { id = "aLevels", value = lv }
            end
        end
    }

    dlg:newrow { always = false }

    dlg:combobox {
        id = "unitsInput",
        label = "Units:",
        option = QuantizeUtilities.UNIT_DEFAULT,
        options = QuantizeUtilities.UNITS,
        focus = false,
        visible = isVisible,
        hexpand = false,
        onchange = function()
            local args <const> = dlg.data

            local md <const> = args.levelsInput --[[@as string]]
            local isnu <const> = md == "NON_UNIFORM"
            local isu <const> = md == "UNIFORM"

            local unit <const> = args.unitsInput --[[@as string]]
            local isbit <const> = unit == "BITS"
            local isint <const> = unit == "INTEGERS"

            dlg:modify { id = "rBits", visible = isnu and isbit }
            dlg:modify { id = "gBits", visible = isnu and isbit }
            dlg:modify { id = "bBits", visible = isnu and isbit }
            dlg:modify { id = "aBits", visible = isnu and isbit }
            dlg:modify {
                id = "bitsUni",
                visible = isu and isbit
            }

            dlg:modify { id = "rLevels", visible = isnu and isint }
            dlg:modify { id = "gLevels", visible = isnu and isint }
            dlg:modify { id = "bLevels", visible = isnu and isint }
            dlg:modify { id = "aLevels", visible = isnu and isint }
            dlg:modify {
                id = "levelsUni",
                visible = isu and isint
            }
        end
    }

    dlg:newrow { always = false }
end

---Finds a dither function based on a preset.
---Presets include "ERROR_DIFFUSION" and "ORDERED".
---Defaults to Floyd Steinberg dither.
---@param preset string dither preset
---@return fun(pixels: integer[], w: integer, h: integer, bpp: integer, matrix: integer[], cols: integer, rows: integer, xOff: integer, yOff: integer, fac: number, closestFunc: fun(r8: integer, g8: integer, b8: integer, a8: integer): integer, integer, integer, integer)
function QuantizeUtilities.ditherFuncFromPreset(preset)
    if preset == "ORDERED" then
        return QuantizeUtilities.orderedDither
    end
    return QuantizeUtilities.fsDither
end

---Dithers an array of abgr32 colors with Floyd Steinberg error diffusion.
---Delays clamping error to gamut until the pixel is assigned to the array.
---Changes the array in place.
---Factor is expected to be in [0.0, 1.0], where 1.0 yields the full error
---diffusion pattern.
---See https://en.wikipedia.org/wiki/Floyd%E2%80%93Steinberg_dithering .
---@param pixels integer[] bytes of length w * h * bpp
---@param w integer source image width
---@param h integer source image height
---@param bpp integer source image bytes per pixel
---@param matrix number[] ordered matrix
---@param cols integer matrix columns count (unused)
---@param rows integer matrix rows count (unused)
---@param xOff integer x offset (unused)
---@param yOff integer y offset (unused)
---@param fac number dither factor
---@param closestFunc fun(r8: integer, g8: integer, b8: integer, a8: integer): integer, integer, integer, integer closest color function
function QuantizeUtilities.fsDither(
    pixels, w, h, bpp,
    matrix, cols, rows, xOff, yOff,
    fac, closestFunc)
    local fs_1_16 <const> = 0.0625 * fac
    local fs_3_16 <const> = 0.1875 * fac
    local fs_5_16 <const> = 0.3125 * fac
    local fs_7_16 <const> = 0.4375 * fac

    local bt1_16 <const> = math.floor(fs_1_16 * 255.0 + 0.5)
    local bt3_16 <const> = math.floor(fs_3_16 * 255.0 + 0.5)
    local bt5_16 <const> = math.floor(fs_5_16 * 255.0 + 0.5)
    local bt7_16 <const> = math.floor(fs_7_16 * 255.0 + 0.5)

    local areaImage <const> = w * h
    local i = 0
    while i < areaImage do
        local iBppSrc <const> = i * bpp

        local r8Src = pixels[1 + iBppSrc]
        local g8Src = pixels[2 + iBppSrc]
        local b8Src = pixels[3 + iBppSrc]
        local a8Src = pixels[4 + iBppSrc]

        if r8Src < 0 then r8Src = 0 elseif r8Src > 255 then r8Src = 255 end
        if g8Src < 0 then g8Src = 0 elseif g8Src > 255 then g8Src = 255 end
        if b8Src < 0 then b8Src = 0 elseif b8Src > 255 then b8Src = 255 end
        if a8Src < 0 then a8Src = 0 elseif a8Src > 255 then a8Src = 255 end

        local r8Trg <const>,
        g8Trg <const>,
        b8Trg <const>,
        a8Trg <const> = closestFunc(r8Src, g8Src, b8Src, a8Src)

        pixels[1 + iBppSrc] = r8Trg
        pixels[2 + iBppSrc] = g8Trg
        pixels[3 + iBppSrc] = b8Trg
        pixels[4 + iBppSrc] = a8Trg

        -- Find difference between palette color and source color.
        local rErr <const> = r8Src - r8Trg
        local gErr <const> = g8Src - g8Trg
        local bErr <const> = b8Src - b8Trg
        local aErr <const> = a8Src - a8Trg

        local x <const> = i % w
        local y <const> = i // w
        local xp1InBounds <const> = x + 1 < w
        local yp1InBounds <const> = y + 1 < h

        local xBpp <const> = x * bpp

        -- Find right neighbor.
        if xp1InBounds then
            local idxNgbr0 <const> = y * w * bpp + xBpp + bpp
            pixels[1 + idxNgbr0] = pixels[1 + idxNgbr0] + (rErr * bt7_16) // 255
            pixels[2 + idxNgbr0] = pixels[2 + idxNgbr0] + (gErr * bt7_16) // 255
            pixels[3 + idxNgbr0] = pixels[3 + idxNgbr0] + (bErr * bt7_16) // 255
            pixels[4 + idxNgbr0] = pixels[4 + idxNgbr0] + (aErr * bt7_16) // 255
        end

        if yp1InBounds then
            local yp1WSrcBpp <const> = (y + 1) * w * bpp

            -- Find bottom left neighbor.
            if x > 0 then
                local idxNgbr1 <const> = yp1WSrcBpp + xBpp - bpp
                pixels[1 + idxNgbr1] = pixels[1 + idxNgbr1] + (rErr * bt3_16) // 255
                pixels[2 + idxNgbr1] = pixels[2 + idxNgbr1] + (gErr * bt3_16) // 255
                pixels[3 + idxNgbr1] = pixels[3 + idxNgbr1] + (bErr * bt3_16) // 255
                pixels[4 + idxNgbr1] = pixels[4 + idxNgbr1] + (aErr * bt3_16) // 255
            end

            -- Find the bottom neighbor.
            local idxNgbr2 <const> = yp1WSrcBpp + xBpp
            pixels[1 + idxNgbr2] = pixels[1 + idxNgbr2] + (rErr * bt5_16) // 255
            pixels[2 + idxNgbr2] = pixels[2 + idxNgbr2] + (gErr * bt5_16) // 255
            pixels[3 + idxNgbr2] = pixels[3 + idxNgbr2] + (bErr * bt5_16) // 255
            pixels[4 + idxNgbr2] = pixels[4 + idxNgbr2] + (aErr * bt5_16) // 255

            -- Find bottom right neighbor.
            if xp1InBounds then
                local idxNgbr3 <const> = yp1WSrcBpp + xBpp + bpp
                pixels[1 + idxNgbr3] = pixels[1 + idxNgbr3] + (rErr * bt1_16) // 255
                pixels[2 + idxNgbr3] = pixels[2 + idxNgbr3] + (gErr * bt1_16) // 255
                pixels[3 + idxNgbr3] = pixels[3 + idxNgbr3] + (bErr * bt1_16) // 255
                pixels[4 + idxNgbr3] = pixels[4 + idxNgbr3] + (aErr * bt1_16) // 255
            end -- End x + 1 in bounds.
        end     -- End y + 1 in bounds.

        i = i + 1
    end -- End pixel loop.
end

---Dithers an array of abgr32 colors with a matrix (ordered dithering).
---Offsets to x and y compensate for cel position with trimmed images.
---Vertical offset assumes y axis points downward.
---Source alpha is dithered only if it is translucent, greater than 0
---and less than 255.
---Changes the array in place.
---Factor is expected to be in [0.0, 1.0], where 0.5 balances between the
---source color and 1.0 yields the strongest pattern at cost of accurate
---lightness.
---See https://en.wikipedia.org/wiki/Ordered_dithering .
---@param pixels integer[] bytes of length w * h * bpp
---@param w integer source image width
---@param h integer source image height
---@param bpp integer source image bytes per pixel
---@param matrix number[] ordered matrix
---@param cols integer matrix columns count
---@param rows integer matrix rows count
---@param xOff integer x offset
---@param yOff integer y offset
---@param fac number dither factor
---@param closestFunc fun(r8: integer, g8: integer, b8: integer, a8: integer): integer, integer, integer, integer closest color function
function QuantizeUtilities.orderedDither(
    pixels, w, h, bpp,
    matrix, cols, rows, xOff, yOff,
    fac, closestFunc)
    local floor <const> = math.floor
    local max <const> = math.max
    local min <const> = math.min

    local complFac <const> = 1.0 - fac

    local areaImage <const> = w * h
    local i = 0
    while i < areaImage do
        local iBppSrc <const> = i * bpp

        local r8Src <const> = pixels[1 + iBppSrc]
        local g8Src <const> = pixels[2 + iBppSrc]
        local b8Src <const> = pixels[3 + iBppSrc]
        local a8Src <const> = pixels[4 + iBppSrc]

        local x <const> = xOff + i % w
        local y <const> = yOff + i // w
        local mIdx <const> = (y % rows) * cols + (x % cols)
        local mFac <const> = matrix[1 + mIdx] - 0.5

        local a8Alt = a8Src
        if a8Src > 0 and a8Src < 255 then
            local a01Src <const> = a8Src / 255.0
            local a01Alt = min(max(a01Src + mFac, 0.0), 1.0)
            a8Alt = floor(a01Alt * 255.0 + 0.5)
        end

        local r01Src <const> = r8Src / 255.0
        local g01Src <const> = g8Src / 255.0
        local b01Src <const> = b8Src / 255.0

        -- Set the altered color to the relative luminance of the source.
        -- Because the alt color is just the source plus the matrix entry,
        -- the delta between source luma and alt luma is simplified. Then,
        -- because these are weighted to sum to 1, they can be discarded.
        -- https://www.w3.org/TR/compositing-1/#blendingnonseparable
        -- local yDelta <const> = (0.3 * mFac + 0.59 * mFac + 0.11 * mFac)
        --     * complFac
        local yDelta <const> = complFac * mFac

        local r01Alt <const> = min(max(r01Src + mFac - yDelta, 0.0), 1.0)
        local g01Alt <const> = min(max(g01Src + mFac - yDelta, 0.0), 1.0)
        local b01Alt <const> = min(max(b01Src + mFac - yDelta, 0.0), 1.0)

        local r8Trg <const>,
        g8Trg <const>,
        b8Trg <const>,
        a8Trg <const> = closestFunc(
            floor(r01Alt * 255.0 + 0.5),
            floor(g01Alt * 255.0 + 0.5),
            floor(b01Alt * 255.0 + 0.5),
            a8Alt)

        pixels[1 + iBppSrc] = r8Trg
        pixels[2 + iBppSrc] = g8Trg
        pixels[3 + iBppSrc] = b8Trg
        pixels[4 + iBppSrc] = a8Trg

        i = i + 1
    end
end

return QuantizeUtilities