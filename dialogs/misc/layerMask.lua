dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
    trimCels = false,
    delOverLayer = false,
    delUnderLayer = false,
    pullFocus = false
}

local dlg = Dialog { title = "Layer Mask" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Edges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:check {
    id = "delOverLayer",
    label = "Delete:",
    text = "Mask",
    selected = defaults.delOverLayer
}

dlg:check {
    id = "delUnderLayer",
    text = "Source",
    selected = defaults.delUnderLayer
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        -- This could be done with a magic wand tool.

        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local colorMode = activeSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
            return
        end

        local overLayer = app.activeLayer
        if not overLayer then
            app.alert("There is no active layer.")
            return
        end

        local overIndex = overLayer.stackIndex
        if overIndex < 2 then
            app.alert("There must be a layer beneath the active layer.")
            return
        end

        -- A parent may be a sprite or a group layer.
        -- Over and under layer should belong to same group.
        local parent = overLayer.parent
        local underIndex = overIndex - 1
        local underLayer = parent.layers[underIndex]

        if overLayer.isGroup or underLayer.isGroup then
            app.alert("Group layers are not supported.")
            return
        end

        -- Cache global functions used in loop.
        local trim = AseUtilities.trimImageAlpha
        local min = math.min
        local max = math.max

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local trimCels = args.trimCels
        local delOverLayer = args.delOverLayer
            and (not overLayer.isReference)
        local delUnderLayer = args.delUnderLayer
            and (not underLayer.isBackground)
            and (not underLayer.isReference)

        -- Determine how a pixel is judged to be transparent.
        local alphaIndex = activeSprite.transparentColor

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
            local activeFrames = activeSprite.frames
            local activeFramesLen = #activeFrames
            for i = 1, activeFramesLen, 1 do
                frames[i] = activeFrames[i]
            end
        end

        local compLayer = activeSprite:newLayer()
        compLayer.name = string.format("Comp.%s.%s",
            underLayer.name, overLayer.name)
        compLayer.parent = parent

        local framesLen = #frames
        app.transaction(function()
            for i = 1, framesLen, 1 do
                local frame = frames[i]
                local overCel = overLayer:cel(frame)
                local underCel = underLayer:cel(frame)
                if overCel and underCel then
                    local overImg = overCel.image
                    local overPos = overCel.position
                    local xTlOver = overPos.x
                    local yTlOver = overPos.y

                    local widthOver = overImg.width
                    local heightOver = overImg.height
                    local xBrOver = xTlOver + widthOver
                    local yBrOver = yTlOver + heightOver

                    local underImg = underCel.image
                    local underPos = underCel.position
                    local xTlUnder = underPos.x
                    local yTlUnder = underPos.y

                    local widthUnder = underImg.width
                    local heightUnder = underImg.height
                    local xBrUnder = xTlUnder + widthUnder
                    local yBrUnder = yTlUnder + heightUnder

                    if trimCels then
                        local xTlOverShift = 0
                        local yTlOverShift = 0
                        local xTlUnderShift = 0
                        local yTlUnderShift = 0

                        overImg, xTlOverShift, yTlOverShift = trim(
                            overImg, 0, alphaIndex)
                        underImg, xTlUnderShift, yTlUnderShift = trim(
                            underImg, 0, alphaIndex)

                        xTlOver = xTlOver + xTlOverShift
                        yTlOver = yTlOver + yTlOverShift

                        xTlUnder = xTlUnder + xTlUnderShift
                        yTlUnder = yTlUnder + yTlUnderShift

                        widthOver = overImg.width
                        heightOver = overImg.height
                        xBrOver = xTlOver + widthOver
                        yBrOver = yTlOver + heightOver

                        widthUnder = underImg.width
                        heightUnder = underImg.height
                        xBrUnder = xTlUnder + widthUnder
                        yBrUnder = yTlUnder + heightUnder
                    end

                    -- Find intersection of over and under.
                    local xTlTarget = max(xTlOver, xTlUnder)
                    local yTlTarget = max(yTlOver, yTlUnder)
                    local xBrTarget = min(xBrOver, xBrUnder)
                    local yBrTarget = min(yBrOver, yBrUnder)

                    -- Intersection may be empty (invalid).
                    if xBrTarget > xTlTarget and yBrTarget > yTlTarget then
                        local widthTarget = xBrTarget - xTlTarget
                        local heightTarget = yBrTarget - yTlTarget
                        local trgImage = Image(widthTarget, heightTarget)
                        local trgPos = Point(xTlTarget, yTlTarget)

                        local trgItr = trgImage:pixels()
                        for elm in trgItr do
                            local xSprite = elm.x + xTlTarget
                            local ySprite = elm.y + yTlTarget

                            local xOver = xSprite - xTlOver
                            local yOver = ySprite - yTlOver
                            local overHex = overImg:getPixel(xOver, yOver)
                            local overAlpha = (overHex >> 0x18) & 0xff

                            if overAlpha > 0 then
                                local xUnder = xSprite - xTlUnder
                                local yUnder = ySprite - yTlUnder
                                local underHex = underImg:getPixel(xUnder, yUnder)
                                local underAlpha = (underHex >> 0x18) & 0xff

                                local compAlpha = (overAlpha * underAlpha) // 0xff
                                local compHex = (compAlpha << 0x18)
                                    | (underHex & 0x00ffffff)
                                elm(compHex)
                            end
                        end

                        activeSprite:newCel(
                            compLayer, frame,
                            trgImage, trgPos)
                    end
                end
            end
        end)

        if delOverLayer then activeSprite:deleteLayer(overLayer) end
        if delUnderLayer then activeSprite:deleteLayer(underLayer) end
        app.activeLayer = compLayer

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }