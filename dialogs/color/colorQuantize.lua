dofile("../../support/aseutilities.lua")
dofile("../../support/clr.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    levels = 16,
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

dlg:slider {
    target = "RANGE",
    id = "levels",
    label = "Levels:",
    min = 2,
    max = 64,
    value = 16
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:button {
    id = "ok",
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
        local levels = args.levels or defaults.levels
        local target = args.target or defaults.target
        local copyToLayer = args.copyToLayer

        -- Cache methods to local.
        local fromHex = Clr.fromHex
        local toHex = Clr.toHexUnchecked
        local quantize = Clr.quantizeInternal

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
                "%s.Quantized.%03d",
                trgLayer.name,
                levels)
            trgLayer.opacity = srcLayer.opacity
        end

        local framesLen = #frames
        local delta = 1.0 / levels
        local oldMode = sprite.colorMode
        app.command.ChangePixelFormat { format = "rgb" }

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
                        local srcClr = fromHex(k)
                        local qtzClr = quantize(srcClr, levels, delta)
                        trgDict[k] = toHex(qtzClr)
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