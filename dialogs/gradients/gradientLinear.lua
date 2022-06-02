dofile("../../support/aseutilities.lua")
dofile("../../support/gradientutilities.lua")

local coords = { "CARTESIAN", "POLAR" }

local defaults = {
    coord = "CARTESIAN",
    xOrigin = 0,
    yOrigin = 50,
    xDest = 100,
    yDest = 50,
    xCenter = 50,
    yCenter = 50,
    angle = 0,
    radius = 100,
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

dlg:combobox {
    id = "coord",
    label = "Coords:",
    option = defaults.coord,
    options = coords,
    onchange = function()
        local args = dlg.data
        local coord = args.coord
        local isCart = coord == "CARTESIAN"
        dlg:modify { id = "xOrigin", visible = isCart }
        dlg:modify { id = "yOrigin", visible = isCart }
        dlg:modify { id = "xDest", visible = isCart }
        dlg:modify { id = "yDest", visible = isCart }

        local isPolr = coord == "POLAR"
        dlg:modify { id = "xCenter", visible = isPolr }
        dlg:modify { id = "yCenter", visible = isPolr }
        dlg:modify { id = "angle", visible = isPolr }
        dlg:modify { id = "radius", visible = isPolr }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "xOrigin",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrigin,
    visible = defaults.coord == "CARTESIAN"
}

dlg:slider {
    id = "yOrigin",
    min = 0,
    max = 100,
    value = defaults.yOrigin,
    visible = defaults.coord == "CARTESIAN"
}

dlg:newrow { always = false }

dlg:slider {
    id = "xDest",
    label = "Dest %:",
    min = 0,
    max = 100,
    value = defaults.xDest,
    visible = defaults.coord == "CARTESIAN"
}

dlg:slider {
    id = "yDest",
    min = 0,
    max = 100,
    value = defaults.yDest,
    visible = defaults.coord == "CARTESIAN"
}

dlg:newrow { always = false }

dlg:slider {
    id = "xCenter",
    label = "Center %:",
    min = 0,
    max = 100,
    value = defaults.xCenter,
    visible = defaults.coord == "POLAR"
}

dlg:slider {
    id = "yCenter",
    min = 0,
    max = 100,
    value = defaults.yCenter,
    visible = defaults.coord == "POLAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle,
    visible = defaults.coord == "POLAR"
}

dlg:newrow { always = false }

dlg:slider {
    id = "radius",
    label = "Radius:",
    min = 1,
    max = 100,
    value = defaults.radius,
    visible = defaults.coord == "POLAR"
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

dlg:slider {
    id = "startIndex",
    label = "Start:",
    min = 0,
    max = 255,
    value = defaults.startIndex,
    visible = defaults.tweenOps == "PALETTE"
}

dlg:newrow { always = false }

dlg:slider {
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

        if sprite.colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported." }
            return
        end

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

            local palettes = sprite.palettes
            local lenPalettes = #palettes
            local actFrIdx = 1
            if app.activeFrame then
                actFrIdx = app.activeFrame.frameNumber
                if actFrIdx > lenPalettes then actFrIdx = 1 end
            end
            local pal = palettes[actFrIdx]

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

        local wn1 = sprite.width - 1.0
        local hn1 = sprite.height - 1.0

        -- Divide by 100 to account for percentage.
        local xOrPx = 0
        local yOrPx = 0
        local xDsPx = wn1
        local yDsPx = 0

        local coord = args.coord or defaults.coord
        if coord == "POLAR" then
            local xCenter = args.xCenter or defaults.xCenter
            local yCenter = args.yCenter or defaults.yCenter
            local angle = args.angle or defaults.angle
            local radius = args.radius or defaults.radius

            local xCtPx = xCenter * wn1 * 0.01
            local yCtPx = yCenter * hn1 * 0.01
            local r = radius * 0.005 * math.max(wn1, hn1)
            local a = angle * 0.017453292519943
            local rtcos = r * math.cos(a)
            local rtsin = r * math.sin(a)

            xOrPx = xCtPx - rtcos
            yOrPx = yCtPx + rtsin
            xDsPx = xCtPx + rtcos
            yDsPx = yCtPx - rtsin
        else
            local xOrigin = args.xOrigin or defaults.xOrigin
            local yOrigin = args.yOrigin or defaults.yOrigin
            local xDest = args.xDest or defaults.xDest
            local yDest = args.yDest or defaults.yDest

            xOrPx = xOrigin * wn1 * 0.01
            yOrPx = yOrigin * hn1 * 0.01
            xDsPx = xDest * wn1 * 0.01
            yDsPx = yDest * hn1 * 0.01
        end

        local invalidFlag = (math.abs(xOrPx - xDsPx) < 1)
            and (math.abs(yOrPx - yDsPx) < 1)
        if invalidFlag then
            xOrPx = 0
            yOrPx = 0
            xDsPx = wn1
            yDsPx = 0
        end

        local bx = xDsPx - xOrPx
        local by = yDsPx - yOrPx
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
            local ax = x - xOrPx
            local ay = y - yOrPx
            local adotb = (ax * bx + ay * by) * bbInv

            -- Unsigned quantize will already clamp to
            -- 0.0 lower bound.
            local fac = quantize(adotb, levels)
            if fac > 1.0 then fac = 1.0 end

            elm(toHex(easeFuncFinal(fac)))
            -- end
        end

        sprite:newCel(layer, frame, image, Point(xCel, yCel))
        app.refresh()

        if invalidFlag then
            app.alert {
                title = "Warning",
                text = "Origin and destination are the same." }
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
