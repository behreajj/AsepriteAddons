dofile("../../support/gradientutilities.lua")

local defaults = {
    -- Cannot use line graph widget because
    -- change in aspect ratio would distort angle.
    xOrig = 50,
    yOrig = 50,
    angle = 90,
    cw = false,
    isCyclic = false,
    pullFocus = true
}

local dlg = Dialog { title = "Sweep Gradient" }

GradientUtilities.dialogWidgets(dlg, true)

-- This is not updated when quantize changes
-- because that slider comes from GradientUtilities.
dlg:check {
    id = "isCyclic",
    label = "Cyclic:",
    selected = defaults.isCyclic
}

dlg:newrow { always = false }

dlg:slider {
    id = "xOrig",
    label = "Origin %:",
    min = 0,
    max = 100,
    value = defaults.xOrig
}

dlg:slider {
    id = "yOrig",
    min = 0,
    max = 100,
    value = defaults.yOrig
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

        -- Unpack arguments.
        local args = dlg.data
        local stylePreset = args.stylePreset --[[@as string]]
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local easPreset = args.easPreset --[[@as string]]
        local huePreset = args.huePreset --[[@as string]]
        local aseColors = args.shades --[[@as Color[] ]]
        local levels = args.quantize --[[@as integer]]
        local bayerIndex = args.bayerIndex --[[@as integer]]
        local ditherPath = args.ditherPath --[[@as string]]
        local isCyclic = args.isCyclic --[[@as boolean]]
        local xOrig = args.xOrig --[[@as integer]]
        local yOrig = args.yOrig --[[@as integer]]
        local angDegrees = args.angle --[[@as integer]]

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(
            easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

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
        local xOrigNorm = xOrig * 0.01 * aspect
        local yOrigNorm = yOrig * 0.01

        -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
        local xOrigSigned = xOrigNorm + xOrigNorm - 1.0
        local yOrigSigned = 1.0 - (yOrigNorm + yOrigNorm)

        local query = AseUtilities.DIMETRIC_ANGLES[angDegrees]
        local angRadians = angDegrees * 0.017453292519943
        if query then angRadians = query end
        local cw = 1.0
        if args.cw then cw = -1.0 end

        local grdSpec = ImageSpec {
            width = max(1, activeSprite.width),
            height = max(1, activeSprite.height),
            colorMode = activeSpec.colorMode,
            transparentColor = activeSpec.transparentColor
        }
        grdSpec.colorSpace = activeSpec.colorSpace

        local grdImg = Image(grdSpec)
        local grdItr = grdImg:pixels()

        local sweepEval = function(x, y)
            -- Bring coordinates into range [0.0, 1.0].
            local xNorm = x * wInv
            local yNorm = y * hInv

            -- Shift coordinates from [0.0, 1.0] to [-1.0, 1.0].
            local xSigned = xNorm + xNorm - 1.0
            local ySigned = 1.0 - (yNorm + yNorm)

            -- Subtract the origin.
            local xOffset = xSigned - xOrigSigned
            local yOffset = cw * (ySigned - yOrigSigned)

            -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
            local angleSigned = atan2(yOffset, xOffset) - angRadians

            -- Wrap by 360 degrees, so factor is in [0.0, 1.0].
            local angleWrapped = angleSigned % wrap

            -- Divide by tau to bring into factor.
            return angleWrapped * toFac
        end

        if stylePreset == "MIXED" then
            local facDict = {}
            local cgmix = ClrGradient.eval

            for pixel in grdItr do
                local fac = sweepEval(pixel.x, pixel.y)
                fac = facAdjust(fac)
                fac = quantize(fac, levels)

                if facDict[fac] then
                    pixel(facDict[fac])
                else
                    local clr = cgmix(gradient, fac, mixFunc)
                    local hex = toHex(clr)
                    pixel(hex)
                    facDict[fac] = hex
                end
            end
        else
            local dither = GradientUtilities.ditherFromPreset(
                stylePreset, bayerIndex, ditherPath)
            for pixel in grdItr do
                local x = pixel.x
                local y = pixel.y
                local fac = sweepEval(x, y)
                local clr = dither(gradient, fac, x, y)
                pixel(toHex(clr))
            end
        end

        app.transaction("Sweep Gradient", function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Sweep"
            if stylePreset == "MIXED" then
                grdLayer.name = grdLayer.name
                    .. "." .. clrSpacePreset
            end
            local activeFrame = app.activeFrame
                or activeSprite.frames[1] --[[@as Frame]]
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