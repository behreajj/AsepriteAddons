dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local methods = { "SIGNED", "UNSIGNED" }
local units = { "BITS", "INTEGERS" }
local levelsInputs = { "NON_UNIFORM", "UNIFORM" }

local defaults = {
    minLevels = 2,
    maxLevels = 256,
    minBits = 1,
    maxBits = 8,

    target = "RANGE",

    levelsUni = 16,
    rLevels = 16,
    gLevels = 16,
    bLevels = 16,
    aLevels = 256,

    bitsUni = 4,
    rBits = 4,
    gBits = 4,
    bBits = 4,
    aBits = 8,

    unit = "BITS",
    levelsInput = "UNIFORM",
    method = "UNSIGNED",
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
    visible = defaults.levelsInput == "UNIFORM"
        and defaults.unit == "INTEGERS",
    onchange = function()
        local args = dlg.data
        local uni = args.levelsUni
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
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "gLevels",
    -- text = "G",
    label = "Green:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.gLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "bLevels",
    -- text = "B",
    label = "Blue:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.bLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:slider {
    id = "aLevels",
    -- text = "A",
    label = "Alpha:",
    min = defaults.minLevels,
    max = defaults.maxLevels,
    value = defaults.aLevels,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "INTEGERS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "bitsUni",
    label = "Bits:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.bitsUni,
    visible = defaults.levelsInput == "UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local bd = dlg.data.bitsUni
        dlg:modify { id = "rBits", value = bd }
        dlg:modify { id = "gBits", value = bd }
        dlg:modify { id = "bBits", value = bd }
        dlg:modify { id = "aBits", value = bd }

        local lv = 2 ^ bd
        dlg:modify { id = "levelsUni", value = lv }
        dlg:modify { id = "rLevels", value = lv }
        dlg:modify { id = "gLevels", value = lv }
        dlg:modify { id = "bLevels", value = lv }
        dlg:modify { id = "aLevels", value = lv }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "rBits",
    -- text = "R",
    label = "Red:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.rBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local lv = 2 ^ dlg.data.rBits
        dlg:modify { id = "rLevels", value = lv }
    end
}

dlg:slider {
    id = "gBits",
    -- text = "G",
    label = "Green:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.gBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local lv = 2 ^ dlg.data.gBits
        dlg:modify { id = "gLevels", value = lv }
    end
}

dlg:slider {
    id = "bBits",
    -- text = "B",
    label = "Blue:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.bBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local lv = 2 ^ dlg.data.bBits
        dlg:modify { id = "bLevels", value = lv }
    end
}

dlg:slider {
    id = "aBits",
    -- text = "A",
    label = "Alpha:",
    min = defaults.minBits,
    max = defaults.maxBits,
    value = defaults.aBits,
    visible = defaults.levelsInput == "NON_UNIFORM"
        and defaults.unit == "BITS",
    onchange = function()
        local lv = 2 ^ dlg.data.aBits
        dlg:modify { id = "aLevels", value = lv }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "levelsInput",
    option = defaults.levelsInput,
    options = levelsInputs,
    onchange = function()
        local args = dlg.data

        local md = args.levelsInput
        local isnu = md == "NON_UNIFORM"

        local unit = args.unitsInput
        local isbit = unit == "BITS"
        local isint = unit == "INTEGERS"

        dlg:modify { id = "rBits", visible = isnu and isbit }
        dlg:modify { id = "gBits", visible = isnu and isbit }
        dlg:modify { id = "bBits", visible = isnu and isbit }
        dlg:modify { id = "aBits", visible = isnu and isbit }
        dlg:modify {
            id = "bitsUni",
            visible = (not isnu) and isbit
        }

        dlg:modify { id = "rLevels", visible = isnu and isint }
        dlg:modify { id = "gLevels", visible = isnu and isint }
        dlg:modify { id = "bLevels", visible = isnu and isint }
        dlg:modify { id = "aLevels", visible = isnu and isint }
        dlg:modify {
            id = "levelsUni",
            visible = (not isnu) and isint
        }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "unitsInput",
    label = "Units:",
    option = defaults.unit,
    options = units,
    onchange = function()
        local args = dlg.data

        local md = args.levelsInput
        local isnu = md == "NON_UNIFORM"

        local unit = args.unitsInput
        local isbit = unit == "BITS"
        local isint = unit == "INTEGERS"

        dlg:modify { id = "rBits", visible = isnu and isbit }
        dlg:modify { id = "gBits", visible = isnu and isbit }
        dlg:modify { id = "bBits", visible = isnu and isbit }
        dlg:modify { id = "aBits", visible = isnu and isbit }
        dlg:modify {
            id = "bitsUni",
            visible = (not isnu) and isbit
        }

        dlg:modify { id = "rLevels", visible = isnu and isint }
        dlg:modify { id = "gLevels", visible = isnu and isint }
        dlg:modify { id = "bLevels", visible = isnu and isint }
        dlg:modify { id = "aLevels", visible = isnu and isint }
        dlg:modify {
            id = "levelsUni",
            visible = (not isnu) and isint
        }
    end
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
        -- Early returns.
        local sprite = app.activeSprite
        if not sprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite." }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer." }
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
            local i = 0
            while i < rangeFramesLen do i = i + 1
                frames[i] = rangeFrames[i]
            end
        else
            local activeFrames = sprite.frames
            local activeFramesLen = #activeFrames
            local i = 0
            while i < activeFramesLen do i = i + 1
                frames[i] = activeFrames[i]
            end
        end

        -- Create a new layer if necessary.
        local trgLayer = nil
        if copyToLayer then
            trgLayer = sprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s.Quantized.R%02d.G%02d.B%02d.A%02d",
                srcLayerName,
                rLevels, gLevels, bLevels, aLevels)
            if srcLayer.opacity then
                trgLayer.opacity = srcLayer.opacity
            end
            if srcLayer.blendMode then
                trgLayer.blendMode = srcLayer.blendMode
            end
        end

        local one255 = 1.0 / 255
        local trunc = math.tointeger

        local rDelta = 0.0
        local gDelta = 0.0
        local bDelta = 0.0
        local aDelta = 0.0

        local quantize = nil
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
