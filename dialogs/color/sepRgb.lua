dofile("../../support/aseutilities.lua")

local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "RANGE",
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

        -- Tile map layers may be present in 1.3 beta.
        local layerIsTilemap = false
        local tileSet = nil
        local version = app.version
        if version.major >= 1 and version.minor >= 3 then
            layerIsTilemap = srcLayer.isTilemap
            if layerIsTilemap then
                tileSet = srcLayer.tileset
            end
        end

        local args = dlg.data
        local target = args.target or defaults.target
        local fillBase = args.fillBase

        local xRed = args.xRed or defaults.xRed
        local yRed = args.yRed or defaults.yRed
        local xGreen = args.xGreen or defaults.xGreen
        local yGreen = args.yGreen or defaults.yGreen
        local xBlue = args.xBlue or defaults.xBlue
        local yBlue = args.yBlue or defaults.yBlue

        local opacityRed = args.opacityRed or defaults.opacityRed
        local opacityGreen = args.opacityGreen or defaults.opacityGreen
        local opacityBlue = args.opacityBlue or defaults.opacityBlue

        local frames = AseUtilities.getFrames(activeSprite, target)
        local activeParent = srcLayer.parent

        local baseLyr = nil
        if fillBase then
            baseLyr = activeSprite:newLayer()
            baseLyr.parent = activeParent
            baseLyr.name = "Base"
            baseLyr.color = Color(32, 32, 32, 255)
        end

        local redLyr = activeSprite:newLayer()
        local greenLyr = activeSprite:newLayer()
        local blueLyr = activeSprite:newLayer()

        redLyr.parent = activeParent
        greenLyr.parent = activeParent
        blueLyr.parent = activeParent

        redLyr.name = "Red"
        greenLyr.name = "Green"
        blueLyr.name = "Blue"

        redLyr.color = Color(192, 0, 0, 255)
        greenLyr.color = Color(0, 192, 0, 255)
        blueLyr.color = Color(0, 0, 192, 255)

        redLyr.blendMode = BlendMode.ADDITION
        greenLyr.blendMode = BlendMode.ADDITION
        blueLyr.blendMode = BlendMode.ADDITION

        redLyr.opacity = opacityRed
        greenLyr.opacity = opacityGreen
        blueLyr.opacity = opacityBlue

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

        local framesLen = #frames
        app.transaction(function()
            local i = 0
            while i < framesLen do i = i + 1
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
                            -- bounds. However, this wraps around to 4294967295
                            -- or the color white.
                            local xbTest = x + xBlueBase
                            local ybTest = y + yBlueBase
                            if xbTest > -1 and xbTest < srcImgWidth
                                and ybTest > -1 and ybTest < srcImgHeight then
                                local bHex = blueImg:getPixel(xbTest, ybTest)
                                placeMark = placeMark or bHex & 0xff000000 ~= 0
                            end

                            local xgTest = x + xGreenBase
                            local ygTest = y + yGreenBase
                            if xgTest > -1 and xgTest < srcImgWidth
                                and ygTest > -1 and ygTest < srcImgHeight then
                                local gHex = greenImg:getPixel(xgTest, ygTest)
                                placeMark = placeMark or gHex & 0xff000000 ~= 0
                            end

                            local xrTest = x + xRedBase
                            local yrTest = y + yRedBase
                            if xrTest > -1 and xrTest < srcImgWidth
                                and yrTest > -1 and yrTest < srcImgHeight then
                                local rHex = redImg:getPixel(xrTest, yrTest)
                                placeMark = placeMark or rHex & 0xff000000 ~= 0
                            end

                            if placeMark then
                                elm(0xff000000)
                            end
                        end
                    end
                end
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