dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    trimCels = false,
    delOver = "HIDE",
    delUnder = "HIDE",
    pullFocus = false
}

local dlg <const> = Dialog { title = "Layer Mask" }

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
    text = "Layer Ed&ges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delOver",
    label = "Over:",
    text = "Mask",
    option = defaults.delOver,
    options = delOptions
}

dlg:combobox {
    id = "delUnder",
    label = "Under:",
    text = "Source",
    option = defaults.delUnder,
    options = delOptions
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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local overLayer <const> = site.layer
        if not overLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        local overIndex <const> = overLayer.stackIndex
        if overIndex < 2 then
            app.alert {
                title = "Error",
                text = "There must be a layer beneath the active layer."
            }
            return
        end

        -- A parent may be a sprite or a group layer.
        -- Over and under layer should belong to same group.
        local parent <const> = overLayer.parent
        local underIndex <const> = overIndex - 1
        local underLayer <const> = parent.layers[underIndex]

        if overLayer.isGroup or underLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        if overLayer.isReference or underLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        -- Cache global functions used in loop.
        local min <const> = math.min
        local max <const> = math.max
        local getPalette <const> = AseUtilities.getPalette
        local getPixels <const> = AseUtilities.getPixels
        local setPixels <const> = AseUtilities.setPixels
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local trim <const> = AseUtilities.trimImageAlpha
        local createSpec <const> = AseUtilities.createSpec

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local trimCels <const> = args.trimCels --[[@as boolean]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorSpace <const> = spriteSpec.colorSpace

        -- For handling multiple color modes.
        local isGray <const> = colorMode == ColorMode.GRAY
        local isIdx <const> = colorMode == ColorMode.INDEXED
        local palettes <const> = activeSprite.palettes

        local overIsTile <const> = overLayer.isTilemap
        local tileSetOver = nil
        local underIsTile <const> = underLayer.isTilemap
        local tileSetUnder = nil
        if overIsTile then
            tileSetOver = overLayer.tileset
        end
        if underIsTile then
            tileSetUnder = underLayer.tileset
        end

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Unpack layer opacity.
        local overLyrOpacity = 255
        local underLyrOpacity = 255
        if overLayer.opacity then
            overLyrOpacity = overLayer.opacity
        end
        if underLayer.opacity then
            underLyrOpacity = underLayer.opacity
        end

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            compLayer.name = string.format("Comp %s %s",
                overLayer.name, underLayer.name)
            -- Exception: this always sets to parent.
            compLayer.parent = parent
            compLayer.blendMode = underLayer.blendMode
        end)

        local lenFrames <const> = #frames

        app.transaction("Layer Mask", function()
            local idxFrame = 0
            while idxFrame < lenFrames do
                idxFrame = idxFrame + 1
                local frame <const> = frames[idxFrame]
                local overCel <const> = overLayer:cel(frame)
                local underCel <const> = underLayer:cel(frame)
                if overCel and underCel then
                    local imgOver = overCel.image
                    if overIsTile then
                        imgOver = tilesToImage(
                            imgOver, tileSetOver, colorMode)
                    end

                    local posOver <const> = overCel.position
                    local xTlOver = posOver.x
                    local yTlOver = posOver.y
                    local widthOver = imgOver.width
                    local heightOver = imgOver.height

                    local imgUnder = underCel.image
                    if underIsTile then
                        imgUnder = tilesToImage(
                            imgUnder, tileSetUnder, colorMode)
                    end

                    local posUnder <const> = underCel.position
                    local xTlUnder = posUnder.x
                    local yTlUnder = posUnder.y
                    local widthUnder = imgUnder.width
                    local heightUnder = imgUnder.height

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
                        widthOver = imgOver.width
                        heightOver = imgOver.height

                        xTlUnder = xTlUnder + xTlUnderShift
                        yTlUnder = yTlUnder + yTlUnderShift
                        widthUnder = imgUnder.width
                        heightUnder = imgUnder.height
                    end

                    local xBrOver <const> = xTlOver + widthOver - 1
                    local yBrOver <const> = yTlOver + heightOver - 1

                    local xBrUnder <const> = xTlUnder + widthUnder - 1
                    local yBrUnder <const> = yTlUnder + heightUnder - 1

                    -- Find intersection of over and under.
                    local xTlTarget <const> = max(xTlOver, xTlUnder)
                    local yTlTarget <const> = max(yTlOver, yTlUnder)
                    local xBrTarget <const> = min(xBrOver, xBrUnder)
                    local yBrTarget <const> = min(yBrOver, yBrUnder)

                    -- Intersection may be empty (invalid).
                    if xBrTarget > xTlTarget and yBrTarget > yTlTarget then
                        local overCelOpacity <const> = overCel.opacity
                        local underCelOpacity <const> = underCel.opacity
                        local overCompOpacity <const> = (overLyrOpacity * overCelOpacity) // 255
                        local underCompOpacity <const> = (underLyrOpacity * underCelOpacity) // 255

                        local pxOver <const> = getPixels(imgOver)
                        local pxUnder <const> = getPixels(imgUnder)

                        ---@type integer[]
                        local pxTarget <const> = {}
                        local widthTarget <const> = 1 + xBrTarget - xTlTarget
                        local heightTarget <const> = 1 + yBrTarget - yTlTarget
                        local lenPxTarget <const> = widthTarget * heightTarget

                        if isIdx then
                            local palette <const> = getPalette(frame, palettes)

                            local i = 0
                            while i < lenPxTarget do
                                local jTarget = alphaIndex

                                local xSprite <const> = i % widthTarget + xTlTarget
                                local ySprite <const> = i // widthTarget + yTlTarget

                                local xOver <const> = xSprite - xTlOver
                                local yOver <const> = ySprite - yTlOver
                                local iOver <const> = yOver * widthOver + xOver
                                local jOver <const> = pxOver[1 + iOver]
                                if jOver ~= alphaIndex then
                                    local cOver <const> = palette:getColor(jOver)
                                    local aOver <const> = (cOver.alpha * overCompOpacity) // 255
                                    if aOver > 0 then
                                        local xUnder <const> = xSprite - xTlUnder
                                        local yUnder <const> = ySprite - yTlUnder
                                        local iUnder <const> = yUnder * widthUnder + xUnder
                                        local jUnder <const> = pxUnder[1 + iUnder]
                                        if jUnder ~= alphaIndex then
                                            local cUnder <const> = palette:getColor(jUnder)
                                            local aUnder <const> = (cUnder.alpha * underCompOpacity) // 255
                                            if aUnder > 0 then
                                                jTarget = jUnder
                                            end
                                        end
                                    end
                                end

                                i = i + 1
                                pxTarget[i] = jTarget
                            end
                        elseif isGray then
                            local i = 0
                            while i < lenPxTarget do
                                local vTarget = 0
                                local aTarget = 0

                                local xSprite <const> = i % widthTarget + xTlTarget
                                local ySprite <const> = i // widthTarget + yTlTarget

                                local xOver <const> = xSprite - xTlOver
                                local yOver <const> = ySprite - yTlOver
                                local iOver2 <const> = (yOver * widthOver + xOver) * 2
                                local aOver <const> = (pxOver[2 + iOver2] * overCompOpacity) // 255
                                if aOver > 0 then
                                    local xUnder <const> = xSprite - xTlUnder
                                    local yUnder <const> = ySprite - yTlUnder
                                    local iUnder2 <const> = (yUnder * widthUnder + xUnder) * 2
                                    local aUnder <const> = (pxUnder[2 + iUnder2] * underCompOpacity) // 255
                                    if aUnder > 0 then
                                        -- Value is assigned under layer color.
                                        vTarget = pxUnder[1 + iUnder2]
                                        aTarget = (aOver * aUnder) // 255
                                    end
                                end

                                local i2 <const> = i + i
                                pxTarget[1 + i2] = vTarget
                                pxTarget[2 + i2] = aTarget

                                i = i + 1
                            end
                        else
                            local i = 0
                            while i < lenPxTarget do
                                local rTarget = 0
                                local gTarget = 0
                                local bTarget = 0
                                local aTarget = 0

                                local xSprite <const> = i % widthTarget + xTlTarget
                                local ySprite <const> = i // widthTarget + yTlTarget

                                local xOver <const> = xSprite - xTlOver
                                local yOver <const> = ySprite - yTlOver
                                local iOver4 <const> = (yOver * widthOver + xOver) * 4
                                local aOver <const> = (pxOver[4 + iOver4] * overCompOpacity) // 255
                                if aOver > 0 then
                                    local xUnder <const> = xSprite - xTlUnder
                                    local yUnder <const> = ySprite - yTlUnder
                                    local iUnder4 <const> = (yUnder * widthUnder + xUnder) * 4
                                    local aUnder <const> = (pxUnder[4 + iUnder4] * underCompOpacity) // 255
                                    if aUnder > 0 then
                                        -- RGB are assigned under layer color.
                                        rTarget = pxUnder[1 + iUnder4]
                                        gTarget = pxUnder[2 + iUnder4]
                                        bTarget = pxUnder[3 + iUnder4]
                                        aTarget = (aOver * aUnder) // 255
                                    end
                                end

                                local i4 <const> = i * 4
                                pxTarget[1 + i4] = rTarget
                                pxTarget[2 + i4] = gTarget
                                pxTarget[3 + i4] = bTarget
                                pxTarget[4 + i4] = aTarget

                                i = i + 1
                            end
                        end

                        local trgSpec <const> = createSpec(
                            widthTarget, heightTarget,
                            colorMode, colorSpace, alphaIndex)
                        local trgImage <const> = Image(trgSpec)
                        local trgPos <const> = Point(xTlTarget, yTlTarget)
                        setPixels(trgImage, pxTarget)

                        -- Do NOT assign source cel opacity,
                        -- as that is baked into the mask.
                        activeSprite:newCel(
                            compLayer, frame,
                            trgImage, trgPos)
                    end
                end
            end
        end)

        AseUtilities.hideSource(activeSprite, underLayer, frames, delUnderStr)
        AseUtilities.hideSource(activeSprite, overLayer, frames, delOverStr)
        app.layer = compLayer
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