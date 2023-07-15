dofile("../../support/gradientutilities.lua")

local frameTargetOptions = { "ALL", "MANUAL", "RANGE" }

local defaults = {
    frameTarget = "ALL",
    rangeStr = "",
    strExample = "4,6:9,13",
    isCyclic = false,
    pullFocus = true
}

local dlg = Dialog { title = "Time Gradient" }

GradientUtilities.dialogWidgets(dlg, true)

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions,
    onchange = function()
        local args = dlg.data
        local state = args.frameTarget --[[@as string]]
        local isManual = state == "MANUAL"
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
        -- Early returns.
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
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

        local args = dlg.data
        local isCyclic = args.isCyclic --[[@as boolean]]
        local frameTarget = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local rangeStr = args.rangeStr
            or defaults.rangeStr --[[@as string]]

        local stylePreset = args.stylePreset --[[@as string]]
        local clrSpacePreset = args.clrSpacePreset --[[@as string]]
        local easPreset = args.easPreset --[[@as string]]
        local huePreset = args.huePreset --[[@as string]]
        local aseColors = args.shades --[=[@as Color[]]=]
        local levels = args.quantize --[[@as integer]]
        local bayerIndex = args.bayerIndex --[[@as integer]]
        local ditherPath = args.ditherPath --[[@as string]]

        local useMixed = stylePreset == "MIXED"
        local gradient = GradientUtilities.aseColorsToClrGradient(aseColors)
        local facAdjust = GradientUtilities.easingFuncFromPreset(easPreset)
        local mixFunc = GradientUtilities.clrSpcFuncFromPreset(
            clrSpacePreset, huePreset)
        local toHex = Clr.toHex

        -- Frames are potentially discontinuous, but for now assume
        -- that, if so, user intended them to be that way?
        local frIdcs = Utilities.flatArr2(AseUtilities.getFrames(
            activeSprite, frameTarget,
            false, rangeStr, activeSprite.tags))
        local lenFrIdcs = #frIdcs
        local frObjs = activeSprite.frames

        ---@type number[]
        local timeStamps = {}
        local totalDuration = 0
        local h = 0
        while h < lenFrIdcs do
            h = h + 1
            local frIdx = frIdcs[h]
            local frObj = frObjs[frIdx]
            local duration = frObj.duration
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
        local trgImages = {}
        if useMixed then
            -- Cache methods used in loop.
            local cgmix = ClrGradient.eval
            local quantize = nil
            if isCyclic then
                quantize = Utilities.quantizeSigned
            else
                quantize = Utilities.quantizeUnsigned
            end

            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local timeStamp = timeStamps[i]
                local fac = timeStamp * timeToFac
                fac = facAdjust(fac)
                fac = quantize(fac, levels)
                local trgClr = cgmix(
                    gradient, fac, mixFunc)
                local trgHex = toHex(trgClr)
                local trgImage = Image(activeSpec)
                trgImage:clear(trgHex)
                trgImages[i] = trgImage
            end
        else
            local dither = GradientUtilities.ditherFromPreset(
                stylePreset, bayerIndex, ditherPath)
            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local timeStamp = timeStamps[i]
                local fac = timeStamp * timeToFac
                local trgImage = Image(activeSpec)
                local trgItr = trgImage:pixels()
                -- TODO: Could optimize this by only looping over
                -- the gradient for the size of the matrix, then
                -- repeating. Maybe update ditherFromPreset to return
                -- that info? The only issue would be IGN doesn't fit
                -- with the others...
                for pixel in trgItr do
                    local x = pixel.x
                    local y = pixel.y
                    local clr = dither(gradient, fac, x, y)
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
                    .. "." .. clrSpacePreset
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

dlg:show { wait = false }