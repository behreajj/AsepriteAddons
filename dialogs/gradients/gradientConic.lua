dofile("../../support/gradientutilities.lua")

local defaults = {
    xOrigin = 50,
    yOrigin = 50,
    angle = 90,
    cw = false,
    isCyclic = false,
    pullFocus = true
}

local dlg = Dialog { title = "Conic Gradient" }

GradientUtilities.dialogWidgets(dlg)

dlg:check {
    id = "isCyclic",
    label = "Cyclic:",
    selected = defaults.isCyclic
}

dlg:newrow { always = false }

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
    id = "angle",
    label = "Angle:",
    min = 0,
    max = 360,
    value = defaults.angle
}

dlg:newrow { always = false }

dlg:check {
    id = "cw",
    label = "Flip Y:",
    selected = defaults.cw
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
            local newSpec = ImageSpec {
                width = app.preferences.new_file.width,
                height = app.preferences.new_file.height,
                colorMode = ColorMode.RGB
            }
            newSpec.colorSpace = ColorSpace { sRGB = true }
            activeSprite = Sprite(newSpec)
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
        end

        local activeSpec = activeSprite.spec
        local colorMode = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Cache methods.
        local atan2 = math.atan
        local max = math.max
        local toHex = Clr.toHex
        local cgeval = ClrGradient.eval

        -- Unpack arguments.
        local args = dlg.data
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local aseColors = args.shades --[[@as Color[] ]]
        local levels = args.quantize --[[@as integer]]
        local isCyclic = args.isCyclic

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            args.easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, args.huePreset)

        local wrap = 6.2831853071796
        local toFac = 0.1591549430919
        local quantize = nil
        if isCyclic then
            quantize = Utilities.quantizeSigned
        else
            quantize = Utilities.quantizeUnsigned
        end

        local wn1 = max(1.0, activeSprite.width - 1.0)
        local hn1 = max(1.0, activeSprite.height - 1.0)

        local aspect = wn1 / hn1
        local wInv = aspect / wn1
        local hInv = 1.0 / hn1

        -- Shift origin from [0, 100] to [0.0, 1.0].
        local xOrigin = 0.01 * args.xOrigin
        local yOrigin = 0.01 * args.yOrigin
        local xOriginNorm = xOrigin * aspect
        local yOriginNorm = yOrigin

        -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
        local xOriginSigned = xOriginNorm + xOriginNorm - 1.0
        local yOriginSigned = 1.0 - (yOriginNorm + yOriginNorm)

        local angDegrees = args.angle or defaults.angle
        local query = AseUtilities.DIMETRIC_ANGLES[angDegrees]
        local angRadians = angDegrees * 0.017453292519943
        if query then angRadians = query end
        local cw = 1.0
        if args.cw then cw = -1.0 end

        local grdSpec = ImageSpec {
            width = math.max(1, activeSprite.width),
            height = math.max(1, activeSprite.height),
            colorMode = activeSpec.colorMode,
            transparentColor = activeSpec.transparentColor
        }
        grdSpec.colorSpace = activeSpec.colorSpace

        local grdImg = Image(grdSpec)
        local grdItr = grdImg:pixels()
        for pixel in grdItr do
            local x = pixel.x
            local y = pixel.y

            -- Bring coordinates into range [0.0, 1.0].
            local xNorm = x * wInv
            local yNorm = y * hInv

            -- Shift coordinates from [0.0, 1.0] to [-1.0, 1.0].
            local xSigned = xNorm + xNorm - 1.0
            local ySigned = 1.0 - (yNorm + yNorm)

            -- Subtract the origin.
            local xOffset = xSigned - xOriginSigned
            local yOffset = cw * (ySigned - yOriginSigned)

            -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
            local angleSigned = atan2(yOffset, xOffset) - angRadians

            -- Wrap by 360 degrees or 361, so factor is in [0.0, 1.0].
            local angleWrapped = angleSigned % wrap

            -- Divide by tau to bring into factor.
            local fac = angleWrapped * toFac
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            local clr = cgeval(gradient, fac, mixFunc)
            pixel(toHex(clr))
        end

        app.transaction(function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Conic." .. clrSpacePreset
            local activeFrame = app.activeFrame
                or activeSprite.frames[1]
            activeSprite:newCel(
                grdLayer, activeFrame, grdImg)
        end)
        app.refresh()
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