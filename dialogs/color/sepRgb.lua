dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }
local delOptions = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults = {
    target = "RANGE",
    delSrc = "NONE",
    fillBase = true,
    xRed = 0.0,
    yRed = 0.0,
    xGreen = 0.0,
    yGreen = 0.0,
    xBlue = 0.0,
    yBlue = 0.0,
    opacityRed = 255,
    opacityGreen = 255,
    opacityBlue = 255,
    pullFocus = false
}

local dlg = Dialog { title = "Separate Layer RGB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:check {
    id = "fillBase",
    label = "Fill Base:",
    selected = defaults.fillBase
}

dlg:separator {
    id = "shiftSeparator",
    text = "Shift"
}

dlg:number {
    id = "xRed",
    label = "Red:",
    text = string.format("%d", defaults.xRed),
    decimals = 0
}

dlg:number {
    id = "yRed",
    text = string.format("%d", defaults.yRed),
    decimals = 0
}

dlg:newrow { always = false }

dlg:number {
    id = "xGreen",
    label = "Green:",
    text = string.format("%d", defaults.xGreen),
    decimals = 0
}

dlg:number {
    id = "yGreen",
    text = string.format("%d", defaults.yGreen),
    decimals = 0
}

dlg:newrow { always = false }

dlg:number {
    id = "xBlue",
    label = "Blue:",
    text = string.format("%d", defaults.xBlue),
    decimals = 0
}

dlg:number {
    id = "yBlue",
    text = string.format("%d", defaults.yBlue),
    decimals = 0
}

dlg:separator {
    id = "opacitySeparator",
    text = "Layer Opacity"
}

dlg:slider {
    id = "opacityRed",
    label = "Red:",
    min = 0,
    max = 255,
    value = defaults.opacityRed
}

dlg:newrow { always = false }

dlg:slider {
    id = "opacityGreen",
    label = "Green:",
    min = 0,
    max = 255,
    value = defaults.opacityGreen
}

dlg:newrow { always = false }

dlg:slider {
    id = "opacityBlue",
    label = "Blue:",
    min = 0,
    max = 255,
    value = defaults.opacityBlue
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local colorMode = activeSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local srcLayer = app.activeLayer
        if not srcLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        -- Check for tile map support.
        local layerIsTilemap = false
        local tileSet = nil
        if AseUtilities.tilesSupport() then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        local args = dlg.data
        local target = args.target or defaults.target --[[@as string]]
        local delSrcStr = args.delSrc or defaults.delSrc
        local fillBase = args.fillBase

        local xRed = args.xRed or defaults.xRed --[[@as integer]]
        local yRed = args.yRed or defaults.yRed --[[@as integer]]
        local xGreen = args.xGreen or defaults.xGreen --[[@as integer]]
        local yGreen = args.yGreen or defaults.yGreen --[[@as integer]]
        local xBlue = args.xBlue or defaults.xBlue --[[@as integer]]
        local yBlue = args.yBlue or defaults.yBlue --[[@as integer]]

        local opacityRed = args.opacityRed
            or defaults.opacityRed --[[@as integer]]
        local opacityGreen = args.opacityGreen
            or defaults.opacityGreen --[[@as integer]]
        local opacityBlue = args.opacityBlue
            or defaults.opacityBlue --[[@as integer]]

        local frames = AseUtilities.getFrames(activeSprite, target)

        local baseLyr = nil
        if fillBase then
            baseLyr = activeSprite:newLayer()
        end

        local redLyr = activeSprite:newLayer()
        local greenLyr = activeSprite:newLayer()
        local blueLyr = activeSprite:newLayer()
        local sepGroup = activeSprite:newGroup()

        if fillBase then
            baseLyr.parent = sepGroup
            baseLyr.name = "Base"
            baseLyr.color = Color { r = 32, g = 32, b = 32 }
        end

        redLyr.parent = sepGroup
        redLyr.name = "Red"
        redLyr.color = Color { r = 192, g = 0, b = 0 }
        redLyr.blendMode = BlendMode.ADDITION
        redLyr.opacity = opacityRed

        greenLyr.parent = sepGroup
        greenLyr.name = "Green"
        greenLyr.color = Color { r = 0, g = 192, b = 0 }
        greenLyr.blendMode = BlendMode.ADDITION
        greenLyr.opacity = opacityGreen

        blueLyr.parent = sepGroup
        blueLyr.name = "Blue"
        blueLyr.color = Color { r = 0, g = 0, b = 192 }
        blueLyr.blendMode = BlendMode.ADDITION
        blueLyr.opacity = opacityBlue

        sepGroup.name = srcLayer.name .. ".Separated"
        sepGroup.parent = srcLayer.parent
        sepGroup.isCollapsed = true

        -- Treat y axis as (1, 0) points up.
        local redShift = Point(xRed, -yRed)
        local greenShift = Point(xGreen, -yGreen)
        local blueShift = Point(xBlue, -yBlue)

        local rdMsk = 0xff0000ff
        local grMsk = 0xff00ff00
        local blMsk = 0xffff0000

        local max = math.max
        local min = math.min
        local tilesToImage = AseUtilities.tilesToImage

        local lenFrames = #frames
        app.transaction(function()
            local i = 0
            while i < lenFrames do i = i + 1
                local srcFrame = frames[i]
                local srcCel = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if layerIsTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, colorMode)
                    end

                    local srcImgWidth = srcImg.width
                    local srcImgHeight = srcImg.height
                    local srcPos = srcCel.position

                    local redCel = activeSprite:newCel(
                        redLyr, srcFrame, srcImg, srcPos + redShift)
                    local greenCel = activeSprite:newCel(
                        greenLyr, srcFrame, srcImg, srcPos + greenShift)
                    local blueCel = activeSprite:newCel(
                        blueLyr, srcFrame, srcImg, srcPos + blueShift)

                    local srcOpacity = srcCel.opacity
                    redCel.opacity = srcOpacity
                    greenCel.opacity = srcOpacity
                    blueCel.opacity = srcOpacity

                    local redImg = redCel.image
                    local greenImg = greenCel.image
                    local blueImg = blueCel.image

                    local rdItr = redImg:pixels()
                    local grItr = greenImg:pixels()
                    local blItr = blueImg:pixels()

                    for elm in rdItr do elm(elm() & rdMsk) end
                    for elm in grItr do elm(elm() & grMsk) end
                    for elm in blItr do elm(elm() & blMsk) end

                    if fillBase then
                        local redPos = redCel.position
                        local greenPos = greenCel.position
                        local bluePos = blueCel.position

                        local trxRed = redPos.x
                        local trxGreen = greenPos.x
                        local trxBlue = bluePos.x

                        local tryRed = redPos.y
                        local tryGreen = greenPos.y
                        local tryBlue = bluePos.y

                        local trxBase = min(trxRed, trxGreen, trxBlue)
                        local tryBase = min(tryRed, tryGreen, tryBlue)
                        local brxBase = max(trxRed, trxGreen, trxBlue) + srcImgWidth
                        local bryBase = max(tryRed, tryGreen, tryBlue) + srcImgHeight

                        local baseWidth = brxBase - trxBase
                        local baseHeight = bryBase - tryBase
                        local baseCel = activeSprite:newCel(baseLyr, srcFrame)
                        baseCel.position = Point(trxBase, tryBase)
                        baseCel.image = Image(baseWidth, baseHeight)

                        local xRedBase = trxBase - trxRed
                        local xGreenBase = trxBase - trxGreen
                        local xBlueBase = trxBase - trxBlue

                        local yRedBase = tryBase - tryRed
                        local yGreenBase = tryBase - tryGreen
                        local yBlueBase = tryBase - tryBlue

                        local baseItr = baseCel.image:pixels()
                        for elm in baseItr do
                            local x = elm.x
                            local y = elm.y
                            local placeMark = false

                            -- getPixel returns -1 when coordinates are out of
                            -- bounds. This wraps around to 4294967295
                            -- or the color white.
                            local xbTest = x + xBlueBase
                            local ybTest = y + yBlueBase
                            if xbTest > -1 and xbTest < srcImgWidth
                                and ybTest > -1 and ybTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    blueImg:getPixel(xbTest, ybTest) ~= 0
                            end

                            local xgTest = x + xGreenBase
                            local ygTest = y + yGreenBase
                            if xgTest > -1 and xgTest < srcImgWidth
                                and ygTest > -1 and ygTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    greenImg:getPixel(xgTest, ygTest) ~= 0
                            end

                            local xrTest = x + xRedBase
                            local yrTest = y + yRedBase
                            if xrTest > -1 and xrTest < srcImgWidth
                                and yrTest > -1 and yrTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    redImg:getPixel(xrTest, yrTest) ~= 0
                            end

                            if placeMark then
                                elm(0xff000000)
                            end
                        end
                    end
                end
            end
        end)

        if delSrcStr == "HIDE" then
            srcLayer.isVisible = false
        elseif (not srcLayer.isBackground) then
            if delSrcStr == "DELETE_LAYER" then
                activeSprite:deleteLayer(srcLayer)
            elseif delSrcStr == "DELETE_CELS" then
                app.transaction(function()
                    local idxDel = 0
                    while idxDel < lenFrames do
                        idxDel = idxDel + 1
                        local frame = frames[idxDel]
                        if srcLayer:cel(frame) then
                            activeSprite:deleteCel(srcLayer, frame)
                        end
                    end
                end)
            end
        end

        app.refresh()
        app.command.Refresh()
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