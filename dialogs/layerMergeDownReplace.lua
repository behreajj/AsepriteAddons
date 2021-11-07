dofile("../support/aseutilities.lua")

local defaults = {
    trimCels = false,
    bakeLayerAlpha = true,
    pullFocus = false
}

local dlg = Dialog { title = "Layer Merge Down Replace" }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Edges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:check {
    id = "bakeLayerAlpha",
    label = "Bake:",
    text = "Layer Opacity",
    selected = defaults.bakeLayerAlpha
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local overLayer = app.activeLayer
            if overLayer then
                local overIndex = overLayer.stackIndex
                if overIndex > 1 then

                    -- TODO: Possible to not require this change?
                    local oldMode = activeSprite.colorMode
                    app.command.ChangePixelFormat { format = "rgb" }
                    local alphaIndex = activeSprite.transparentColor

                    local eval = function(hex)
                        return hex & 0xff000000 ~= 0
                    end

                    -- Unpack arguments.
                    local args = dlg.data
                    local trimCels = args.trimCels

                    -- Cache global functions used in loop.
                    local trim = AseUtilities.trimImageAlpha
                    local min = math.min
                    local max = math.max

                    -- Groups are not allowed because then you'd have to
                    -- worry about all the other blend modes that'd go
                    -- into flattening the group into a new layer.
                    local overIsGroup = overLayer.isGroup
                    if overIsGroup then
                        app.alert("Group layers are not supported.")
                        dlg:close()
                        return
                    end

                    local underIndex = overIndex - 1
                    local underLayer = activeSprite.layers[underIndex]
                    local underIsGroup = underLayer.isGroup
                    if underIsGroup then
                        app.alert("Group layers are not supported.")
                        dlg:close()
                        return
                    end

                    app.transaction(function()
                        local targetLayer = activeSprite:newLayer()
                        targetLayer.name = overLayer.name .. ".Merged"

                        local frames = activeSprite.frames
                        local frameLen = #frames

                        local bakeLayerAlpha = args.bakeLayerAlpha
                        if bakeLayerAlpha then
                            AseUtilities.bakeLayerOpacity(overLayer)
                            AseUtilities.bakeLayerOpacity(underLayer)
                        end

                        for i = 1, frameLen, 1 do
                            local frame = frames[i]
                            -- local frameNumber = frame.frameNumber
                            local overCel = overLayer:cel(frame)
                            local underCel = underLayer:cel(frame)

                            if overCel and underCel then
                                -- print(string.format("%d: Both over and under detected.", frameNumber))

                                local overImage = overCel.image
                                local overPos = overCel.position
                                local xTlOver = overPos.x
                                local yTlOver = overPos.y

                                local widthOver = overImage.width
                                local heightOver = overImage.height
                                local xBrOver = xTlOver + widthOver
                                local yBrOver = yTlOver + heightOver

                                local underImage = underCel.image
                                local underPos = underCel.position
                                local xTlUnder = underPos.x
                                local yTlUnder = underPos.y

                                local widthUnder = underImage.width
                                local heightUnder = underImage.height
                                local xBrUnder = xTlUnder + widthUnder
                                local yBrUnder = yTlUnder + heightUnder

                                if trimCels then
                                    local xTlOverShift = 0
                                    local yTlOverShift = 0
                                    local xTlUnderShift = 0
                                    local yTlUnderShift = 0

                                    overImage, xTlOverShift, yTlOverShift = trim(
                                        overImage, 0, alphaIndex)
                                    underImage, xTlUnderShift, yTlUnderShift = trim(
                                        underImage, 0, alphaIndex)

                                    xTlOver = xTlOver + xTlOverShift
                                    yTlOver = yTlOver + yTlOverShift

                                    xTlUnder = xTlUnder + xTlUnderShift
                                    yTlUnder = yTlUnder + yTlUnderShift

                                    widthOver = overImage.width
                                    heightOver = overImage.height
                                    xBrOver = xTlOver + widthOver
                                    yBrOver = yTlOver + heightOver

                                    widthUnder = underImage.width
                                    heightUnder = underImage.height
                                    xBrUnder = xTlUnder + widthUnder
                                    yBrUnder = yTlUnder + heightUnder
                                end

                                local xTlTarget = min(xTlOver, xTlUnder)
                                local yTlTarget = min(yTlOver, yTlUnder)
                                local widthTarget = 1 + max(xBrOver, xBrUnder) - xTlTarget
                                local heightTarget = 1 + max(yBrOver, yBrUnder) - yTlTarget
                                local trgImage = Image(widthTarget, heightTarget)
                                local trgPos = Point(xTlTarget, yTlTarget)

                                trgImage:drawImage(
                                    underImage,
                                    Point(
                                        xTlUnder - xTlTarget,
                                        yTlUnder - yTlTarget))

                                local overItr = overImage:pixels()
                                for elm in overItr do
                                    local hex = elm()
                                    if eval(hex) then
                                        trgImage:drawPixel(
                                            elm.x + xTlOver - xTlTarget,
                                            elm.y + yTlOver - yTlTarget,
                                            hex)
                                    end
                                end

                                activeSprite:newCel(
                                    targetLayer, frame,
                                    trgImage, trgPos)

                            elseif overCel then
                                -- print(string.format("%d: Over detected.", frameNumber))

                                local srcImage = overCel.image
                                local srcPos = overCel.position

                                if trimCels then
                                    local imgTr, xTr, yTr = trim(srcImage, 0, alphaIndex)
                                    srcImage = imgTr
                                    srcPos = srcPos + Point(xTr, yTr)
                                end

                                activeSprite:newCel(
                                    targetLayer, frame,
                                    srcImage, srcPos)

                            elseif underCel then
                                -- print(string.format("%d: Under detected.", frameNumber))

                                local srcImage = underCel.image
                                local srcPos = underCel.position

                                if trimCels then
                                    local imgTr, xTr, yTr = trim(srcImage, 0, alphaIndex)
                                    srcImage = imgTr
                                    srcPos = srcPos + Point(xTr, yTr)
                                end

                                activeSprite:newCel(
                                    targetLayer, frame,
                                    srcImage, srcPos)
                            end
                        end

                        targetLayer.stackIndex = overIndex + 1
                        activeSprite:deleteLayer(overLayer)
                        activeSprite:deleteLayer(underLayer)
                    end)

                    AseUtilities.changePixelFormat(oldMode)
                    app.refresh()
                else
                    app.alert("There are no layers beneath this one.")
                end
            else
                app.alert("There is no active layer.")
            end
        else
            app.alert("There is no active sprite.")
        end
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