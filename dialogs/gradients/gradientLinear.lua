dofile("../../support/gradientutilities.lua")
dofile("../../support/canvasutilities.lua")

local defaults = {
    pullFocus = true
}

local dlg = Dialog { title = "Linear Gradient" }

GradientUtilities.dialogWidgets(dlg, true)

CanvasUtilities.graphLine(
    dlg, "graphCart", "Graph:", 128, 128,
    true, true, 7, -100, 0, 100, 0,
    app.theme.color.text,
    Color { r = 128, g = 128, b = 128 })

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
        local max = math.max
        local min = math.min
        local toHex = Clr.toHex
        local quantize = Utilities.quantizeUnsigned

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

        if stylePreset ~= "MIXED" then levels = 0 end
        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local cgeval = GradientUtilities.evalFromStylePreset(
            stylePreset, bayerIndex, ditherPath)

        local wn1 = max(1.0, activeSprite.width - 1.0)
        local hn1 = max(1.0, activeSprite.height - 1.0)

        -- Calculate origin and destination.
        -- Divide by 100 to account for percentage.
        local xOrig = args.xOrig --[[@as integer]]
        local yOrig = args.yOrig --[[@as integer]]
        local xDest = args.xDest --[[@as integer]]
        local yDest = args.yDest --[[@as integer]]

        local xOrPx = wn1 * (xOrig * 0.005 + 0.5)
        local xDsPx = wn1 * (xDest * 0.005 + 0.5)
        local yOrPx = hn1 * (0.5 - yOrig * 0.005)
        local yDsPx = hn1 * (0.5 - yDest * 0.005)

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
        local bbDot = bx * bx + by * by
        local bbInv = 0.0
        if bbDot ~= 0.0 then bbInv = 1.0 / bbDot end

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
            local ax = x - xOrPx
            local ay = y - yOrPx
            local adotb = (ax * bx + ay * by) * bbInv
            local fac = min(max(adotb, 0.0), 1.0)
            fac = facAdjust(fac)
            fac = quantize(fac, levels)
            local clr = cgeval(gradient, fac, mixFunc, x, y)
            pixel(toHex(clr))
        end

        app.transaction("Linear Gradient", function()
            local grdLayer = activeSprite:newLayer()
            grdLayer.name = "Gradient.Linear"
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

        if invalidFlag then
            app.alert {
                title = "Warning",
                text = "Origin and destination are the same."
            }
        end
    end
}

dlg:button {
    id = "toPalette",
    text = "&PALETTE",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local activeFrame = app.activeFrame
            or activeSprite.frames[1] --[[@as Frame]]
        local trgPalette = AseUtilities.getPalette(
            activeFrame, activeSprite.palettes)

        -- Unpack arguments.
        local args = dlg.data
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local huePreset = args.huePreset --[[@as string]]
        local aseColors = args.shades --[[@as Color[] ]]

        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local eval = ClrGradient.eval
        local clrToAseColor = AseUtilities.clrToAseColor

        -- Due to concerns with range sprite reference expiring,
        -- it's better to keep this to a simple append.
        local levels = args.quantize --[[@as integer]]
        if levels < 3 then levels = 5 end
        local jToFac = 1.0 / (levels - 1.0)
        app.transaction("Append to Palette", function()
            local lenPalette = #trgPalette
            trgPalette:resize(lenPalette + levels)
            local j = 0
            while j < levels do
                local jFac = j * jToFac
                local clr = eval(gradient, jFac, mixFunc)
                local aseColor = clrToAseColor(clr)
                trgPalette:setColor(lenPalette + j, aseColor)
                j = j + 1
            end
        end)
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