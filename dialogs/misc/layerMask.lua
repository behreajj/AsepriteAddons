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

        local colorMode <const> = activeSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
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
        local tilesToImage <const> = AseUtilities.tilesToImage
        local trim <const> = AseUtilities.trimImageAlpha

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local trimCels <const> = args.trimCels --[[@as boolean]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        local overIsValidTrg <const> = true
        local underIsValidTrg <const> = (not underLayer.isBackground)

        local hideOverLayer <const> = delOverStr == "HIDE"
        local delOverLayer <const> = delOverStr == "DELETE_LAYER"
            and overIsValidTrg
        local delUnderLayer <const> = delUnderStr == "DELETE_LAYER"
            and underIsValidTrg

        local hideUnderLayer <const> = delOverStr == "HIDE"
        local delOverCels <const> = delOverStr == "DELETE_CELS"
            and overIsValidTrg
        local delUnderCels <const> = delUnderStr == "DELETE_CELS"
            and underIsValidTrg

        -- Determine how a pixel is judged to be transparent.
        local alphaIndex <const> = activeSprite.transparentColor
        local colorSpace <const> = activeSprite.colorSpace

        local overIsTile <const> = overLayer.isTilemap
        local tileSetOver = nil
        local underIsTile <const> = underLayer.isTilemap
        local tileSetUnder = nil
        if overIsTile then
            tileSetOver = overLayer.tileset --[[@as Tileset]]
        end
        if underIsTile then
            tileSetUnder = underLayer.tileset --[[@as Tileset]]
        end

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Unpack layer opacity.
        local overLyrOpacity = 255
        local underLyrOpacity = 255
        if overLayer.opacity then
            overLyrOpacity = overLayer.opacity end
        if underLayer.opacity then
            underLyrOpacity = underLayer.opacity
        end

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer = nil
        app.transaction("New Layer", function()
            compLayer = activeSprite:newLayer()
            compLayer.name = string.format("Comp.%s.%s",
                overLayer.name, underLayer.name)
            compLayer.parent = parent
            compLayer.blendMode = underLayer.blendMode
        end)

        local lenFrames <const> = #frames
        local rgbColorMode <const> = ColorMode.RGB
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
                    local xBrOver = xTlOver + widthOver
                    local yBrOver = yTlOver + heightOver

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

                        local widthTarget <const> = xBrTarget - xTlTarget
                        local heightTarget <const> = yBrTarget - yTlTarget

                        local trgSpec <const> = ImageSpec {
                            width = widthTarget,
                            height = heightTarget,
                            colorMode = rgbColorMode,
                            transparentColor = alphaIndex
                        }
                        trgSpec.colorSpace = colorSpace
                        local trgImage <const> = Image(trgSpec)
                        local trgPos <const> = Point(xTlTarget, yTlTarget)

                        local trgPxItr <const> = trgImage:pixels()
                        for pixel in trgPxItr do
                            local xSprite <const> = pixel.x + xTlTarget
                            local ySprite <const> = pixel.y + yTlTarget

                            local xOver <const> = xSprite - xTlOver
                            local yOver <const> = ySprite - yTlOver
                            local hexOver <const> = imgOver:getPixel(xOver, yOver)
                            local alphaOver = (hexOver >> 0x18) & 0xff
                            alphaOver = (alphaOver * overCompOpacity) // 255

                            if alphaOver > 0 then
                                local xUnder <const> = xSprite - xTlUnder
                                local yUnder <const> = ySprite - yTlUnder

                                -- No sign that alpha premultiply affects this.
                                local hexUnder <const> = imgUnder:getPixel(xUnder, yUnder)
                                local alphaUnder = (hexUnder >> 0x18) & 0xff
                                alphaUnder = (alphaUnder * underCompOpacity) // 255
                                local alphaComp <const> = (alphaOver * alphaUnder) // 255
                                local hexComp <const> = (alphaComp << 0x18)
                                    | (hexUnder & 0x00ffffff)
                                pixel(hexComp)
                            end
                        end

                        -- Do NOT assign source cel opacity,
                        -- as that is baked into the mask.
                        activeSprite:newCel(
                            compLayer, frame,
                            trgImage, trgPos)
                    end
                end
            end
        end)

        if hideOverLayer then
            overLayer.isVisible = false
        elseif delOverLayer then
            -- Beware: it's possible to delete all layers
            -- in a sprite with Sprite:deleteLayer.
            activeSprite:deleteLayer(overLayer)
        elseif delOverCels then
            app.transaction("Delete Cels", function()
                local idxDel0 = lenFrames + 1
                while idxDel0 > 1 do
                    idxDel0 = idxDel0 - 1
                    local frame <const> = frames[idxDel0]
                    -- API reports an error if a cel cannot be
                    -- found, so the layer needs to check that
                    -- it has a cel first.
                    local overCel <const> = overLayer:cel(frame)
                    if overCel then activeSprite:deleteCel(overCel) end
                end
            end)
        end

        if hideUnderLayer then
            underLayer.isVisible = false
        elseif delUnderLayer then
            activeSprite:deleteLayer(underLayer)
        elseif delUnderCels then
            app.transaction("Delete Cels", function()
                local idxDel1 = lenFrames + 1
                while idxDel1 > 1 do
                    idxDel1 = idxDel1 - 1
                    local frame <const> = frames[idxDel1]
                    local underCel <const> = underLayer:cel(frame)
                    if underCel then activeSprite:deleteCel(underCel) end
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
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }