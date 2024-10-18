dofile("../../support/gradientutilities.lua")

local defaults <const> = {
    -- Cannot use line graph widget because
    -- change in aspect ratio would distort angle.
    xOrig = 50,
    yOrig = 50,
    angle = 90,
    cw = false,
    isCyclic = false,
    pullFocus = true
}

local dlg <const> = Dialog { title = "Sweep Gradient" }

local gradient <const> = GradientUtilities.dialogWidgets(dlg, true)

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
        local site <const> = app.site
        local activeSprite = site.sprite
        if not activeSprite then
            activeSprite = AseUtilities.createSprite(
                AseUtilities.createSpec(), "Sweep Gradient")
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
        local atan2 <const> = math.atan
        local max <const> = math.max
        local strpack <const> = string.pack
        local toHex <const> = Clr.toHex

        -- Unpack arguments.
        local args <const> = dlg.data
        local stylePreset <const> = args.stylePreset --[[@as string]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local levels <const> = args.quantize --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]
        local isCyclic <const> = args.isCyclic --[[@as boolean]]
        local xOrig <const> = args.xOrig --[[@as integer]]
        local yOrig <const> = args.yOrig --[[@as integer]]
        local angDegrees <const> = args.angle --[[@as integer]]

        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)

        local wrap <const> = 6.2831853071796
        local toFac <const> = 0.1591549430919
        local quantize = nil
        if isCyclic then
            quantize = Utilities.quantizeSigned
        else
            quantize = Utilities.quantizeUnsigned
        end

        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height
        local areaSprite <const> = wSprite * hSprite
        local wn1 <const> = max(1.0, wSprite - 1.0)
        local hn1 <const> = max(1.0, hSprite - 1.0)

        local aspect <const> = wn1 / hn1
        local wInv <const> = aspect / wn1
        local hInv <const> = 1.0 / hn1

        -- Shift origin from [0, 100] to [0.0, 1.0].
        local xOrigNorm <const> = xOrig * 0.01 * aspect
        local yOrigNorm <const> = yOrig * 0.01

        -- Bring origin from [0.0, 1.0] to [-1.0, 1.0].
        local xOrigSigned <const> = xOrigNorm + xOrigNorm - 1.0
        local yOrigSigned <const> = 1.0 - (yOrigNorm + yOrigNorm)

        local query <const> = AseUtilities.DIMETRIC_ANGLES[angDegrees]
        local angRadians = angDegrees * 0.017453292519943
        if query then angRadians = query end
        local cw = 1.0
        if args.cw then cw = -1.0 end

        ---@type string[]
        local trgByteStr <const> = {}
        local sweepEval <const> = function(x, y)
            -- Bring coordinates into range [0.0, 1.0].
            local xNorm <const> = x * wInv
            local yNorm <const> = y * hInv

            -- Shift coordinates from [0.0, 1.0] to [-1.0, 1.0].
            local xSigned <const> = xNorm + xNorm - 1.0
            local ySigned <const> = 1.0 - (yNorm + yNorm)

            -- Subtract the origin.
            local xOffset <const> = xSigned - xOrigSigned
            local yOffset <const> = cw * (ySigned - yOrigSigned)

            -- Find the signed angle in [-math.pi, math.pi], subtract the angle.
            local angleSigned <const> = atan2(yOffset, xOffset) - angRadians

            -- Wrap by 360 degrees, so factor is in [0.0, 1.0].
            local angleWrapped <const> = angleSigned % wrap

            -- Divide by tau to bring into factor.
            return angleWrapped * toFac
        end

        if stylePreset == "MIXED" then
            ---@type table<number, integer>
            local facDict <const> = {}
            local cgmix <const> = ClrGradient.eval
            local i = 0
            while i < areaSprite do
                local x <const> = i % wSprite
                local y <const> = i // wSprite
                local fac <const> = quantize(sweepEval(x, y), levels)
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
                local fac <const> = sweepEval(x, y)
                local trgAbgr32 <const> = toHex(dither(gradient, fac, x, y))
                i = i + 1
                trgByteStr[i] = strpack("<I4", trgAbgr32)
            end
        end

        local grdImg <const> = Image(spriteSpec)
        grdImg.bytes = table.concat(trgByteStr)

        app.transaction("Sweep Gradient", function()
            local grdLayer <const> = activeSprite:newLayer()
            grdLayer.name = "Gradient Sweep"
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