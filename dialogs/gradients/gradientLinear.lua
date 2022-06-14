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
    pullFocus = true
}

local dlg = Dialog { title = "Linear Gradient" }

GradientUtilities.dialogWidgets(dlg)

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

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            local newSpec = ImageSpec{
                width = app.preferences.new_file.width,
                height = app.preferences.new_file.height,
                colorMode = ColorMode.RGB,
                transparentColor = 0 }
            activeSprite = Sprite(newSpec)
            AseUtilities.setSpritePalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported." }
            return
        end

        -- Cache methods.
        local max = math.max
        local min = math.min
        local toHex = Clr.toHex
        local quantize = Utilities.quantizeUnsigned
        local cgeval = ClrGradient.eval

        -- Unpack arguments.
        local args = dlg.data
        local clrSpacePreset = args.clrSpacePreset
        local aseColors = args.shades
        local levels = args.quantize

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        local wn1 = max(1.0, activeSprite.width - 1.0)
        local hn1 = max(1.0, activeSprite.height - 1.0)

        -- Calculate origin and destination.
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

        local bx = xDsPx - xOrPx
        local by = yDsPx - yOrPx
        local invalidFlag = (math.abs(bx) < 1)
            and (math.abs(by) < 1)
        if invalidFlag then
            xOrPx = 0
            yOrPx = 0
            xDsPx = wn1
            yDsPx = 0
            bx = xDsPx - xOrPx
            by = yDsPx - yOrPx
        end
        local bbInv = 1.0 / (bx * bx + by * by)

        local selection = AseUtilities.getSelection(activeSprite)
        local selBounds = selection.bounds
        local xSel = selBounds.x - xOrPx
        local ySel = selBounds.y - yOrPx

        local grdSpec = ImageSpec {
            width = math.max(1, selBounds.width),
            height = math.max(1, selBounds.height),
            colorMode = activeSpec.colorMode,
            transparentColor = activeSpec.transparentColor }
        grdSpec.colorSpace = activeSpec.colorSpace

        local grdImg = Image(grdSpec)
        local grdItr = grdImg:pixels()
        for elm in grdItr do
            local ax = elm.x + xSel
            local ay = elm.y + ySel
            local adotb = (ax * bx + ay * by) * bbInv
            local fac = min(max(adotb, 0.0), 1.0)
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            local clr = cgeval(gradient, fac, mixFunc)
            elm(toHex(clr))
        end

        app.transaction(function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Linear." .. clrSpacePreset
            local activeFrame = app.activeFrame
                or activeSprite.frames[1]
            activeSprite:newCel(
                grdLayer,
                activeFrame,
                grdImg,
                Point(selBounds.x, selBounds.y))
        end)
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
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }
