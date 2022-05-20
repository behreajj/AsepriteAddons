dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local delTargets = { "DELETE_CELS", "DELETE_LAYER", "NONE" }

local defaults = {
    target = "RANGE",
    trimCels = false,
    delOver = "NONE",
    delUnder = "NONE",
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

dlg:combobox {
    id = "delOver",
    label = "Over:",
    text = "Mask",
    option = defaults.delOver,
    options = delTargets
}

dlg:combobox {
    id = "delUnder",
    label = "Under:",
    text = "Source",
    option = defaults.delUnder,
    options = delTargets
}

dlg:newrow { always = false }

dlg:label {
    id = "clarify",
    label = "Note:",
    text = "Select the mask layer."
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
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
        local min = math.min
        local max = math.max
        local tilesToImage = AseUtilities.tilesToImage
        local trim = AseUtilities.trimImageAlpha

        -- Unpack arguments.
        local args = dlg.data
        local target = args.target or defaults.target
        local trimCels = args.trimCels
        local delOverStr = args.delOver or defaults.delOver
        local delUnderStr = args.delUnder or defaults.delUnder

        local overIsValidTrg = (not overLayer.isReference)
        local underIsValidTrg = (not underLayer.isBackground)
            and (not underLayer.isReference)

        local delOverLayer = delOverStr == "DELETE_LAYER"
            and overIsValidTrg
        local delUnderLayer = delUnderStr == "DELETE_LAYER"
            and underIsValidTrg

        local delOverCels = delOverStr == "DELETE_CELS"
            and overIsValidTrg
        local delUnderCels = delUnderStr == "DELETE_CELS"
            and underIsValidTrg

        -- Determine how a pixel is judged to be transparent.
        local alphaIndex = activeSprite.transparentColor
        local colorSpace = activeSprite.colorSpace

        -- Version specific.
        local overIsTile = false
        local tileSetOver = nil
        local underIsTile = false
        local tileSetUnder = nil
        local version = app.version
        if version.major >= 1 and version.minor >= 3 then
            overIsTile = overLayer.isTilemap
            if overIsTile then
                tileSetOver = overLayer.tileset
            end
            underIsTile = underLayer.isTilemap
            if underIsTile then
                tileSetUnder = underLayer.tileset
            end
        end

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

        -- Unpack layer opacity.
        local overLyrOpacity = 0xff
        local underLyrOpacity = 0xff
        if overLayer.opacity then overLyrOpacity = overLayer.opacity end
        if underLayer.opacity then underLyrOpacity = underLayer.opacity end

        -- Create new layer.
        local compLayer = activeSprite:newLayer()
        compLayer.name = string.format("Comp.%s.%s",
            overLayer.name, underLayer.name)
        compLayer.parent = parent

        local framesLen = #frames
        app.transaction(function()
            for i = 1, framesLen, 1 do
                local frame = frames[i]
                local overCel = overLayer:cel(frame)
                local underCel = underLayer:cel(frame)
                if overCel and underCel then
                    local imgOver = overCel.image
                    if overIsTile then
                        imgOver = tilesToImage(
                            imgOver, tileSetOver, colorMode)
                    end
                    local posOver = overCel.position
                    local xTlOver = posOver.x
                    local yTlOver = posOver.y

                    local widthOver = imgOver.width
                    local heightOver = imgOver.height
                    local xBrOver = xTlOver + widthOver
                    local yBrOver = yTlOver + heightOver

                    local imgUnder = underCel.image
                    if underIsTile then
                        imgUnder = tilesToImage(
                            imgUnder, tileSetUnder, colorMode)
                    end
                    local posUnder = underCel.position
                    local xTlUnder = posUnder.x
                    local yTlUnder = posUnder.y

                    local widthUnder = imgUnder.width
                    local heightUnder = imgUnder.height
                    local xBrUnder = xTlUnder + widthUnder
                    local yBrUnder = yTlUnder + heightUnder

                    if trimCels then
                        local xTlOverShift = 0
                        local yTlOverShift = 0
                        local xTlUnderShift = 0
                        local yTlUnderShift = 0

                        imgOver, xTlOverShift, yTlOverShift = trim(
                            imgOver, 0, alphaIndex)
                        imgUnder, xTlUnderShift, yTlUnderShift = trim(
                            imgUnder, 0, alphaIndex)

                        xTlOver = xTlOver + xTlOverShift
                        yTlOver = yTlOver + yTlOverShift

                        xTlUnder = xTlUnder + xTlUnderShift
                        yTlUnder = yTlUnder + yTlUnderShift

                        widthOver = imgOver.width
                        heightOver = imgOver.height
                        xBrOver = xTlOver + widthOver
                        yBrOver = yTlOver + heightOver

                        widthUnder = imgUnder.width
                        heightUnder = imgUnder.height
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

                        local overCelOpacity = overCel.opacity
                        local underCelOpacity = underCel.opacity
                        local overCompOpacity = (overLyrOpacity * overCelOpacity) // 0xff
                        local underCompOpacity = (underLyrOpacity * underCelOpacity) // 0xff

                        local widthTarget = xBrTarget - xTlTarget
                        local heightTarget = yBrTarget - yTlTarget

                        local trgSpec = ImageSpec {
                            width = widthTarget,
                            height = heightTarget,
                            colorMode = ColorMode.RGB,
                            transparentColor = alphaIndex }
                        trgSpec.colorSpace = colorSpace
                        local trgImage = Image(trgSpec)
                        local trgPos = Point(xTlTarget, yTlTarget)

                        local trgItr = trgImage:pixels()
                        for elm in trgItr do
                            local xSprite = elm.x + xTlTarget
                            local ySprite = elm.y + yTlTarget

                            local xOver = xSprite - xTlOver
                            local yOver = ySprite - yTlOver
                            local hexOver = imgOver:getPixel(xOver, yOver)
                            local alphaOver = (hexOver >> 0x18) & 0xff
                            alphaOver = (alphaOver * overCompOpacity) // 0xff

                            if alphaOver > 0 then
                                local xUnder = xSprite - xTlUnder
                                local yUnder = ySprite - yTlUnder
                                local hexUnder = imgUnder:getPixel(xUnder, yUnder)
                                local alphaUnder = (hexUnder >> 0x18) & 0xff
                                alphaUnder = (alphaUnder * underCompOpacity) // 0xff

                                local alphaComp = (alphaOver * alphaUnder) // 0xff
                                local hexComp = (alphaComp << 0x18)
                                    | (hexUnder & 0x00ffffff)
                                elm(hexComp)
                            end
                        end

                        activeSprite:newCel(
                            compLayer, frame,
                            trgImage, trgPos)
                    end
                end
            end
        end)

        -- Beware: it's possible to delete all layers
        -- in a sprite with Sprite:deleteLayer.
        if delOverLayer then
            activeSprite:deleteLayer(overLayer)
        elseif delOverCels then
            app.transaction(function()
                for i = 1, framesLen, 1 do
                    local frame = frames[i]
                    -- API reports an error if a cel cannot be
                    -- found, so the layer needs to check that
                    -- it has a cel first.
                    if overLayer:cel(frame) then
                        activeSprite:deleteCel(overLayer, frame)
                    end
                end
            end)
        end

        if delUnderLayer then
            activeSprite:deleteLayer(underLayer)
        elseif delUnderCels then
            app.transaction(function()
                for i = 1, framesLen, 1 do
                    local frame = frames[i]
                    if underLayer:cel(frame) then
                        activeSprite:deleteCel(underLayer, frame)
                    end
                end
            end)
        end

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
