dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local methods = { "SIGNED", "UNSIGNED" }
local levelsInputs = { "NON_UNIFORM", "UNIFORM" }

local defaults = {
    target = "RANGE",
    levelsUni = 15,
    rLevels = 15,
    gLevels = 15,
    bLevels = 15,
    aLevels = 15,
    levelsInput = "UNIFORM",
    minLevels = 2,
    maxLevels = 64,
    method = "UNSIGNED",
    useLinear = false,
    copyToLayer = true,
    pullFocus = false
}

local dlg = Dialog { title = "Quantize Color" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "method",
    label = "Method:",
    option = defaults.method,
    options = methods
}

dlg:newrow { always = false }

dlg:slider {
    id = "levelsUni",
    label = "Levels:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.levelsUni,
    visible = defaults.levelsInput == "UNIFORM",
    onchange = function()
        local uni = dlg.data.levelsUni
        dlg:modify { id = "rLevels", value = uni }
        dlg:modify { id = "gLevels", value = uni }
        dlg:modify { id = "bLevels", value = uni }
        dlg:modify { id = "aLevels", value = uni }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rLevels",
    -- label = "Levels:",
    -- text = "R",
    label = "Red:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.rLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
}

dlg:slider {
    id = "gLevels",
    -- text = "G",
    label = "Green:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.gLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
}

dlg:slider {
    id = "bLevels",
    -- text = "B",
    label = "Blue:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.bLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
}

dlg:slider {
    id = "aLevels",
    -- text = "A",
    label = "Alpha:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.aLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "levelsInput",
    option = defaults.levelsInput,
    options = levelsInputs,
    onchange = function()
        local md = dlg.data.levelsInput
        local isnu = md == "NON_UNIFORM"
        dlg:modify { id = "rLevels", visible = isnu }
        dlg:modify { id = "gLevels", visible = isnu }
        dlg:modify { id = "bLevels", visible = isnu }
        dlg:modify { id = "aLevels", visible = isnu }

        dlg:modify {
            id = "levelsUni",
            visible = not isnu
        }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useLinear",
    label = "Linear:",
    text = "RGB",
    selected = defaults.useLinear
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()

        local sprite = app.activeSprite
        if not sprite then
            app.alert("There is no active sprite.")
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert("There is no active layer.")
            return
        end

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local method = args.method or defaults.method
        local rLevels = args.rLevels or defaults.rLevels
        local gLevels = args.gLevels or defaults.gLevels
        local bLevels = args.bLevels or defaults.bLevels
        local aLevels = args.aLevels or defaults.aLevels
        local useLinear = args.useLinear
        local copyToLayer = args.copyToLayer

        -- Find frames from target.
        local frames = {}
        if target == "ACTIVE" then
            local activeFrame = app.activeFrame
            if activeFrame then
                frames[1] = activeFrame
            end
        elseif target == "RANGE" then
            local appRange = app.range
            local rangeFrames = appRange.frames
            local rangeFramesLen = #rangeFrames
            for i = 1, rangeFramesLen, 1 do
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = sprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        -- Create a new layer if necessary.
        local trgLayer = nil
        if copyToLayer then
            trgLayer = sprite:newLayer()
            trgLayer.name = string.format(
                "%s.Quantized.R%02d.G%02d.B%02d.A%02d",
                srcLayer.name,
                rLevels, gLevels, bLevels, aLevels)
            trgLayer.opacity = srcLayer.opacity
        end

        -- Cache methods & luts to local.
        local one255 = 1.0 / 255
        local stlLut = Utilities.STL_LUT
        local ltsLut = Utilities.LTS_LUT
        local trunc = math.tointeger
        local quantize = nil

        local rDelta = 0.0
        local gDelta = 0.0
        local bDelta = 0.0
        local aDelta = 0.0

        if method == "UNSIGNED" then
            quantize = Utilities.quantizeUnsignedInternal

            rDelta = 1.0 / (rLevels - 1.0)
            gDelta = 1.0 / (gLevels - 1.0)
            bDelta = 1.0 / (bLevels - 1.0)
            aDelta = 1.0 / (aLevels - 1.0)
        else
            quantize = Utilities.quantizeSignedInternal

            rLevels = rLevels - 1
            gLevels = gLevels - 1
            bLevels = bLevels - 1
            aLevels = aLevels - 1

            rDelta = 1.0 / rLevels
            gDelta = 1.0 / gLevels
            bDelta = 1.0 / bLevels
            aDelta = 1.0 / aLevels
        end

        local oldMode = sprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

        local framesLen = #frames
        app.transaction(function()
            for i = 1, framesLen, 1 do
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    local srcPxItr = srcImg:pixels()

                    -- Gather unique colors in image.
                    local srcDict = {}
                    for elm in srcPxItr do
                        srcDict[elm()] = true
                    end

                    -- Quantize colors, place in dictionary.
                    local trgDict = {}
                    if useLinear then
                        for k, _ in pairs(srcDict) do
                            local a = (k >> 0x18) & 0xff
                            local b = (k >> 0x10) & 0xff
                            local g = (k >> 0x08) & 0xff
                            local r = k & 0xff

                            local bLin = stlLut[1 + b]
                            local gLin = stlLut[1 + g]
                            local rLin = stlLut[1 + r]

                            local aQtz = quantize(a * one255, aLevels, aDelta)
                            local bQtz = quantize(bLin * one255, bLevels, bDelta)
                            local gQtz = quantize(gLin * one255, gLevels, gDelta)
                            local rQtz = quantize(rLin * one255, rLevels, rDelta)

                            aQtz = trunc(0.5 + 255.0 * aQtz)
                            bQtz = trunc(0.5 + 255.0 * bQtz)
                            gQtz = trunc(0.5 + 255.0 * gQtz)
                            rQtz = trunc(0.5 + 255.0 * rQtz)

                            local bStd = ltsLut[1 + bQtz]
                            local gStd = ltsLut[1 + gQtz]
                            local rStd = ltsLut[1 + rQtz]

                            local hex = (aQtz << 0x18)
                                | (bStd << 0x10)
                                | (gStd << 0x08)
                                | rStd

                            trgDict[k] = hex
                        end
                    else
                        for k, _ in pairs(srcDict) do
                            local a = (k >> 0x18) & 0xff
                            local b = (k >> 0x10) & 0xff
                            local g = (k >> 0x08) & 0xff
                            local r = k & 0xff

                            local aQtz = quantize(a * one255, aLevels, aDelta)
                            local bQtz = quantize(b * one255, bLevels, bDelta)
                            local gQtz = quantize(g * one255, gLevels, gDelta)
                            local rQtz = quantize(r * one255, rLevels, rDelta)

                            aQtz = trunc(0.5 + 255.0 * aQtz)
                            bQtz = trunc(0.5 + 255.0 * bQtz)
                            gQtz = trunc(0.5 + 255.0 * gQtz)
                            rQtz = trunc(0.5 + 255.0 * rQtz)

                            local hex = (aQtz << 0x18)
                                | (bQtz << 0x10)
                                | (gQtz << 0x08)
                                | rQtz

                            trgDict[k] = hex
                        end
                    end

                    -- Clone image, replace color with quantized.
                    local trgImg = srcImg:clone()
                    local trgpxitr = trgImg:pixels()
                    for elm in trgpxitr do
                        elm(trgDict[elm()])
                    end

                    if copyToLayer then
                        local trgCel = sprite:newCel(
                                    trgLayer, srcFrame,
                                    trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    else
                        srcCel.image = trgImg
                    end
                end
            end
        end)

        AseUtilities.changePixelFormat(oldMode)
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