dofile("../../support/gradientutilities.lua")
dofile("../../support/canvasutilities.lua")

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local defaults <const> = {
    pullFocus = true
}

local dlg <const> = Dialog { title = "Linear Gradient" }

local gradient <const> = GradientUtilities.dialogWidgets(dlg, true)

CanvasUtilities.graphLine(
    dlg, "graphCart", "Graph:",
    128 // screenScale, 128 // screenScale,
    true, true, 7, -100, 0, 100, 0,
    app.theme.color.text,
    Color { r = 128, g = 128, b = 128 })

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local site <const> = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            activeSprite = AseUtilities.createSprite(
                AseUtilities.createSpec(), "Linear Gradient")
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
        end

        -- Early returns.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Cache methods.
        local max <const> = math.max
        local min <const> = math.min
        local strpack <const> = string.pack
        local toHex <const> = Clr.toHex
        local quantize <const> = Utilities.quantizeUnsigned

        -- Unpack arguments.
        local args <const> = dlg.data
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local areaSprite <const> = wSprite * hSprite
        local wn1 <const> = max(1.0, wSprite - 1.0)
        local hn1 <const> = max(1.0, hSprite - 1.0)

        -- Calculate origin and destination.
        -- Divide by 100 to account for percentage.
        local xOrig <const> = args.xOrig --[[@as integer]]
        local yOrig <const> = args.yOrig --[[@as integer]]
        local xDest <const> = args.xDest --[[@as integer]]
        local yDest <const> = args.yDest --[[@as integer]]

        local xOrPx = wn1 * (xOrig * 0.005 + 0.5)
        local xDsPx = wn1 * (xDest * 0.005 + 0.5)
        local yOrPx = hn1 * (0.5 - yOrig * 0.005)
        local yDsPx = hn1 * (0.5 - yDest * 0.005)

        local bx = xDsPx - xOrPx
        local by = yDsPx - yOrPx
        local invalidFlag <const> = (math.abs(bx) < 1)
            and (math.abs(by) < 1)
        if invalidFlag then
            xOrPx = 0
            yOrPx = 0
            xDsPx = wn1
            yDsPx = 0
            bx = xDsPx - xOrPx
            by = yDsPx - yOrPx
        end
        local bbDot <const> = bx * bx + by * by
        local bbInv = 0.0
        if bbDot ~= 0.0 then bbInv = 1.0 / bbDot end

        ---@type string[]
        local trgByteStr <const> = {}
        local linearEval <const> = function(x, y)
            local ax <const> = x - xOrPx
            local ay <const> = y - yOrPx
            local adotb <const> = (ax * bx + ay * by) * bbInv
            return min(max(adotb, 0.0), 1.0)
        end

        if stylePreset == "MIXED" then
            ---@type table<number, integer>
            local facDict <const> = {}
            local cgmix <const> = ClrGradient.eval
            local i = 0
            while i < areaSprite do
                local x <const> = i % wSprite
                local y <const> = i // wSprite
                local fac <const> = quantize(linearEval(x, y), levels)
                local trgAbgr32 = facDict[fac]
                if not trgAbgr32 then
                    trgAbgr32 = toHex(cgmix(gradient, fac, mixFunc))
                    facDict[fac] = trgAbgr32
                end
                i = i + 1
                trgByteStr[i] = strpack("<I4", trgAbgr32)
            end
        else
            local dither <const> = GradientUtilities.ditherFromPreset(
                stylePreset, bayerIndex, ditherPath)
            local i = 0
            while i < areaSprite do
                local x <const> = i % wSprite
                local y <const> = i // wSprite
                local fac <const> = linearEval(x, y)
                local trgAbgr32 <const> = toHex(dither(gradient, fac, x, y))
                i = i + 1
                trgByteStr[i] = strpack("<I4", trgAbgr32)
            end
        end

        local grdImg <const> = Image(spriteSpec)
        grdImg.bytes = table.concat(trgByteStr)

        app.transaction("Linear Gradient", function()
            local grdLayer <const> = activeSprite:newLayer()
            grdLayer.name = "Gradient Linear"
            if stylePreset == "MIXED" then
                grdLayer.name = grdLayer.name
                    .. " " .. clrSpacePreset
            end
            local activeFrame <const> = site.frame
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeFrame <const> = site.frame
            or activeSprite.frames[1] --[[@as Frame]]
        local trgPalette <const> = AseUtilities.getPalette(
            activeFrame, activeSprite.palettes)

        -- Unpack arguments.
        local args <const> = dlg.data
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local eval <const> = ClrGradient.eval
        local clrToAseColor <const> = AseUtilities.clrToAseColor

        -- Due to concerns with range sprite reference expiring,
        -- it's better to keep this to a simple append.
        local levels = args.quantize --[[@as integer]]
        if levels < 3 then levels = 5 end
        local jToFac <const> = 1.0 / (levels - 1.0)
        app.transaction("Append to Palette", function()
            local lenPalette <const> = #trgPalette
            trgPalette:resize(lenPalette + levels)
            local j = 0
            while j < levels do
                local jFac <const> = j * jToFac
                local clr <const> = eval(gradient, jFac, mixFunc)
                local aseColor <const> = clrToAseColor(clr)
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

dlg:show {
    autoscrollbars = true,
    wait = false
}