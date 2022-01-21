dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local defaults = {
    xOrigin = 0,
    yOrigin = 50,
    xDest = 100,
    yDest = 50,
    quantization = 0,
    tweenOps = "PAIR",
    startIndex = 0,
    count = 256,
    aColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_STROKE),
    bColor = AseUtilities.hexToAseColor(AseUtilities.DEFAULT_FILL),
    clrSpacePreset = "S_RGB",
    easingFuncRGB = "LINEAR",
    easingFuncHue = "NEAR",
    pullFocus = false
}

local dlg = Dialog { title = "Linear Gradient" }

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
    id = "xDest",
    label = "Dest %:",
    min = 0,
    max = 100,
    value = defaults.xDest
}

dlg:slider {
    id = "yDest",
    min = 0,
    max = 100,
    value = defaults.yDest
}

dlg:newrow { always = false }

dlg:slider {
    id = "quantization",
    label = "Quantize:",
    min = 0,
    max = 32,
    value = defaults.quantization
}

dlg:newrow { always = false }

dlg:combobox {
    id = "tweenOps",
    label = "Tween:",
    option = defaults.tweenOps,
    options = GradientUtilities.TWEEN_PRESETS,
    onchange = function()
        local args = dlg.data
        local isPair = args.tweenOps == "PAIR"
        local isPalette = args.tweenOps == "PALETTE"
        local md = args.clrSpacePreset

        dlg:modify {
            id = "aColor",
            visible = isPair
        }

        dlg:modify {
            id = "bColor",
            visible = isPair
        }

        dlg:modify {
            id = "startIndex",
            visible = isPalette
        }

        dlg:modify {
            id = "count",
            visible = isPalette
        }

        dlg:modify {
            id = "easingFuncHue",
            visible = md == "CIE_LCH"
                or md == "HSL"
                or md == "HSV"
        }

        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB"
                or md == "LINEAR_RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:slider{
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:slider{
    id = "count",
    label = "Count:",
    min = 3,
    max = 256,
    value = defaults.count,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:color {
    id = "aColor",
    label = "Colors:",
    color = defaults.aColor,
    visible = defaults.tweenOps == "PAIR"
}

dlg:color {
    id = "bColor",
    color = defaults.bColor,
    visible = defaults.tweenOps == "PAIR"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = GradientUtilities.CLR_SPC_PRESETS,
    visible = defaults.tweenOps == "PAIR",
    onchange = function()
        local md = dlg.data.clrSpacePreset
        dlg:modify {
            id = "easingFuncHue",
            visible = md == "CIE_LCH"
                or md == "HSL"
                or md == "HSV"
        }
        dlg:modify {
            id = "easingFuncRGB",
            visible = md == "S_RGB"
                or md == "LINEAR_RGB"
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easingFuncHue",
    label = "Easing:",
    option = defaults.easingFuncHue,
    options = GradientUtilities.HUE_EASING_PRESETS,
    visible = defaults.clrSpacePreset == "CIE_LCH"
        or defaults.clrSpacePreset == "HSL"
        or defaults.clrSpacePreset == "HSV"
}

dlg:combobox {
    id = "easingFuncRGB",
    label = "Easing:",
    option = defaults.easingFuncRGB,
    options = GradientUtilities.RGB_EASING_PRESETS,
    visible = defaults.clrSpacePreset == "S_RGB"
        or defaults.clrSpacePreset == "LINEAR_RGB"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- These need to be cached prior to the potential
        -- creation of a new sprite, otherwise color chosen
        -- by palette index will be incorrect.
        local aColorAse = args.aColor
        local bColorAse = args.bColor
        local aClr = AseUtilities.aseColorToClr(aColorAse)
        local bClr = AseUtilities.aseColorToClr(bColorAse)

        local clrSpacePreset = args.clrSpacePreset
        local sprite = AseUtilities.initCanvas(
            64, 64, "Gradient.Linear." .. clrSpacePreset)
        if sprite.colorMode == ColorMode.RGB then
            local layer = sprite.layers[#sprite.layers]
            local frame = app.activeFrame or sprite.frames[1]

            --Easing mode.
            local tweenOps = args.tweenOps
            local rgbPreset = args.easingFuncRGB
            local huePreset = args.easingFuncHue

            local easeFuncFinal = nil
            if tweenOps == "PALETTE" then
                local startIndex = args.startIndex
                local count = args.count
                local pal = sprite.palettes[1]
                local clrArr = AseUtilities.asePaletteToClrArr(
                    pal, startIndex, count)

                local pairFunc = GradientUtilities.clrSpcFuncFromPreset(
                    clrSpacePreset,
                    rgbPreset,
                    huePreset)

                easeFuncFinal = function(t)
                    return Clr.mixArr(clrArr, t, pairFunc)
                end
            else
                local pairFunc = GradientUtilities.clrSpcFuncFromPreset(
                    clrSpacePreset,
                    rgbPreset,
                    huePreset)

                easeFuncFinal = function(t)
                    return pairFunc(aClr, bClr, t)
                end
            end

            local w = sprite.width
            local h = sprite.height

            local xOrigin = args.xOrigin
            local yOrigin = args.yOrigin
            local xDest = args.xDest
            local yDest = args.yDest

            local invalidFlag = xOrigin == xDest and yOrigin == yDest
            if invalidFlag then
                xOrigin = defaults.xOrigin
                yOrigin = defaults.yOrigin
                xDest = defaults.xDest
                yDest = defaults.yDest
            end

            -- Divide by 100 to account for percentage.
            local xOrPx = xOrigin * w * 0.01
            local yOrPx = yOrigin * h * 0.01
            local xDsPx = xDest * w * 0.01
            local yDsPx = yDest * h * 0.01

            local bx = xOrPx - xDsPx
            local by = yOrPx - yDsPx
            local bbInv = 1.0 / math.max(0.000001,
                bx * bx + by * by)

            local levels = args.quantization
            local quantize = Utilities.quantizeUnsigned
            local toHex = Clr.toHex

            local selection = AseUtilities.getSelection(sprite)
            local selBounds = selection.bounds
            local xCel = selBounds.x
            local yCel = selBounds.y
            local image = Image(selBounds.width, selBounds.height)
            local iterator = image:pixels()
            for elm in iterator do
                local x = elm.x + xCel
                local y = elm.y + yCel
                -- if selection:contains(x, y) then

                -- TODO: This is a little backwards... wouldn't it
                -- be (x, y) - origin, and then reverse b above to
                -- be origin - destination ?
                local cx = xOrPx - x
                local cy = yOrPx - y
                local cb = (cx * bx + cy * by) * bbInv

                -- Unsigned quantize will already clamp to
                -- 0.0 lower bound.
                local fac = quantize(cb, levels)
                if fac > 1.0 then fac = 1.0 end

                elm(toHex(easeFuncFinal(fac)))
                -- end
            end

            sprite:newCel(layer, frame, image, Point(xCel, yCel))
            app.refresh()

            if invalidFlag then
                app.alert("Origin and destination are the same.")
            end
        else
            app.alert("Only RGB color mode is supported.")
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }