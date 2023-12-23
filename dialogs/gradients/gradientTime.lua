dofile("../../support/gradientutilities.lua")

local frameTargetOptions <const> = { "ALL", "MANUAL", "RANGE" }

local defaults <const> = {
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "4,6:9,13",
    isCyclic = false,
    pullFocus = true
}

local dlg <const> = Dialog { title = "Time Gradient" }

GradientUtilities.dialogWidgets(dlg, true)

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args <const> = dlg.data
        local state <const> = args.frameTarget --[[@as string]]
        local isManual <const> = state == "MANUAL"
        dlg:modify { id = "rangeStr", visible = isManual }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Entry:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.frameTarget == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:check {
    id = "isCyclic",
    label = "Cyclic:",
    selected = defaults.isCyclic
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.site.sprite
        if not activeSprite then
            activeSprite = AseUtilities.createSprite(
                AseUtilities.createSpec(), "Time Gradient")
            AseUtilities.setPalette(
                AseUtilities.DEFAULT_PAL_ARR, activeSprite, 1)
            app.transaction("New Frames", function()
                AseUtilities.createFrames(
                    activeSprite, 32 - 1, 1.0 / 12.0)
            end)
        end

        -- Early returns.
        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local args <const> = dlg.data
        local isCyclic <const> = args.isCyclic --[[@as boolean]]
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr <const> = args.rangeStr
            or defaults.rangeStr --[[@as string]]

        local stylePreset <const> = args.stylePreset --[[@as string]]
        local clrSpacePreset <const> = args.clrSpacePreset --[[@as string]]
        local easPreset <const> = args.easPreset --[[@as string]]
        local huePreset <const> = args.huePreset --[[@as string]]
        local aseColors <const> = args.shades --[=[@as Color[]]=]
        local levels <const> = args.quantize --[[@as integer]]
        local bayerIndex <const> = args.bayerIndex --[[@as integer]]
        local ditherPath <const> = args.ditherPath --[[@as string]]

        local useMixed <const> = stylePreset == "MIXED"
        local gradient <const> = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust <const> = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc <const> = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local toHex <const> = Clr.toHex

        -- Frames are potentially discontinuous, but for now assume
        -- that, if so, user intended them to be that way?
        local frIdcs <const> = Utilities.flatArr2(AseUtilities.getFrames(
            activeSprite, frameTarget,
            false, rangeStr, activeSprite.tags))
        local lenFrIdcs <const> = #frIdcs
        local frObjs <const> = activeSprite.frames

        ---@type number[]
        local timeStamps <const> = {}
        local totalDuration = 0
        local h = 0
        while h < lenFrIdcs do
            h = h + 1
            local frIdx <const> = frIdcs[h]
            local frObj <const> = frObjs[frIdx]
            local duration <const> = frObj.duration
            timeStamps[h] = totalDuration
            totalDuration = totalDuration + duration
        end

        local timeToFac = 0.0
        if isCyclic then
            if totalDuration ~= 0.0 then
                timeToFac = 1.0 / totalDuration
            end
        else
            local finalDuration = timeStamps[lenFrIdcs]
            if finalDuration ~= 0.0 then
                timeToFac = 1.0 / finalDuration
            end
        end

        ---@type Image[]
        local trgImages <const> = {}
        if useMixed then
            -- Cache methods used in loop.
            local cgmix <const> = ClrGradient.eval
            local quantize = nil
            if isCyclic then
                quantize = Utilities.quantizeSigned
            else
                quantize = Utilities.quantizeUnsigned
            end

            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local timeStamp <const> = timeStamps[i]
                local fac = timeStamp * timeToFac
                fac = facAdjust(fac)
                fac = quantize(fac, levels)
                local trgClr <const> = cgmix(
                    gradient, fac, mixFunc)
                local trgHex <const> = toHex(trgClr)
                local trgImage <const> = Image(activeSpec)
                trgImage:clear(trgHex)
                trgImages[i] = trgImage
            end
        else
            local dither <const> = GradientUtilities.ditherFromPreset(
                stylePreset, bayerIndex, ditherPath)
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local timeStamp <const> = timeStamps[i]
                local fac <const> = timeStamp * timeToFac
                local trgImage <const> = Image(activeSpec)
                local trgItr <const> = trgImage:pixels()
                -- Could optimize this by only looping over the gradient for
                -- the size of the matrix, then repeating. Maybe update
                -- ditherFromPreset to return that info? The only issue would
                -- be IGN doesn't fit with the others...
                for pixel in trgItr do
                    local x <const> = pixel.x
                    local y <const> = pixel.y
                    local clr <const> = dither(gradient, fac, x, y)
                    -- Time-based IGN is not worth it -- the changing pattern
                    -- flickers in such a way that it hurts the eyes.
                    pixel(toHex(clr))
                end
                trgImages[i] = trgImage
            end
        end

        -- Create target layer.
        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = "Gradient.Time"
            if useMixed then
                trgLayer.name = trgLayer.name
                    .. " " .. clrSpacePreset
            end
        end)

        app.transaction("Time Gradient", function()
            local j = 0
            while j < lenFrIdcs do
                j = j + 1
                activeSprite:newCel(trgLayer, frIdcs[j], trgImages[j])
            end
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