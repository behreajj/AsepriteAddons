dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
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

local dlg <const> = Dialog { title = "Separate Layer RGB" }

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

        local srcLayer <const> = site.layer
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

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset --[[@as Tileset]]
        end

        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local delSrcStr <const> = args.delSrc or defaults.delSrc --[[@as string]]
        local fillBase <const> = args.fillBase --[[@as boolean]]

        local xRed <const> = args.xRed or defaults.xRed --[[@as integer]]
        local yRed <const> = args.yRed or defaults.yRed --[[@as integer]]
        local xGreen <const> = args.xGreen or defaults.xGreen --[[@as integer]]
        local yGreen <const> = args.yGreen or defaults.yGreen --[[@as integer]]
        local xBlue <const> = args.xBlue or defaults.xBlue --[[@as integer]]
        local yBlue <const> = args.yBlue or defaults.yBlue --[[@as integer]]

        local opacityRed <const> = args.opacityRed
            or defaults.opacityRed --[[@as integer]]
        local opacityGreen <const> = args.opacityGreen
            or defaults.opacityGreen --[[@as integer]]
        local opacityBlue <const> = args.opacityBlue
            or defaults.opacityBlue --[[@as integer]]

        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local sepGroup = nil
        local baseLyr = nil
        local redLyr = nil
        local greenLyr = nil
        local blueLyr = nil

        if fillBase then
            app.transaction("Base Layer", function()
                baseLyr = activeSprite:newLayer()
                baseLyr.name = "Base"
                baseLyr.color = Color { r = 32, g = 32, b = 32 }
            end)
        end

        app.transaction("Red Layer", function()
            redLyr = activeSprite:newLayer()
            redLyr.name = "Red"
            redLyr.color = Color { r = 192, g = 0, b = 0 }
            redLyr.blendMode = BlendMode.ADDITION
            redLyr.opacity = opacityRed
        end)

        app.transaction("Green Layer", function()
            greenLyr = activeSprite:newLayer()
            greenLyr.name = "Green"
            greenLyr.color = Color { r = 0, g = 192, b = 0 }
            greenLyr.blendMode = BlendMode.ADDITION
            greenLyr.opacity = opacityGreen
        end)

        app.transaction("Blue Layer", function()
            blueLyr = activeSprite:newLayer()
            blueLyr.name = "Blue"
            blueLyr.color = Color { r = 0, g = 0, b = 192 }
            blueLyr.blendMode = BlendMode.ADDITION
            blueLyr.opacity = opacityBlue
        end)

        app.transaction("New Group", function()
            -- Avoid setting the stackIndex as much as possible.
            sepGroup = activeSprite:newGroup()

            if fillBase then
                baseLyr.parent = sepGroup
            end
            redLyr.parent = sepGroup
            greenLyr.parent = sepGroup
            blueLyr.parent = sepGroup

            local srcParent <const> = srcLayer.parent
            sepGroup.parent = srcParent
            sepGroup.isCollapsed = true
            sepGroup.name = srcLayer.name .. ".Separated"
        end)

        local rdMsk <const> = 0xff0000ff
        local grMsk <const> = 0xff00ff00
        local blMsk <const> = 0xffff0000

        local max <const> = math.max
        local min <const> = math.min
        local tilesToImage <const> = AseUtilities.tilesToImage

        local lenFrames <const> = #frames
        app.transaction("Separate RGB", function()
            local i = 0
            while i < lenFrames do
                i = i + 1
                local srcFrame <const> = frames[i]
                local srcCel <const> = srcLayer:cel(srcFrame)
                if srcCel then
                    local srcImg = srcCel.image
                    if isTilemap then
                        srcImg = tilesToImage(srcImg, tileSet, colorMode)
                    end

                    local srcImgWidth <const> = srcImg.width
                    local srcImgHeight <const> = srcImg.height
                    local srcPos <const> = srcCel.position
                    local xSrc <const> = srcPos.x
                    local ySrc <const> = srcPos.y

                    -- Treat y axis as (1, 0) points up.
                    local redPos <const> = Point(xSrc + xRed, ySrc - yRed)
                    local greenPos <const> = Point(xSrc + xGreen, ySrc - yGreen)
                    local bluePos <const> = Point(xSrc + xBlue, ySrc - yBlue)

                    local redCel <const> = activeSprite:newCel(
                        redLyr, srcFrame, srcImg, redPos)
                    local greenCel <const> = activeSprite:newCel(
                        greenLyr, srcFrame, srcImg, greenPos)
                    local blueCel <const> = activeSprite:newCel(
                        blueLyr, srcFrame, srcImg, bluePos)

                    local srcOpacity <const> = srcCel.opacity
                    redCel.opacity = srcOpacity
                    greenCel.opacity = srcOpacity
                    blueCel.opacity = srcOpacity

                    local redImg <const> = redCel.image
                    local greenImg <const> = greenCel.image
                    local blueImg <const> = blueCel.image

                    local rdItr <const> = redImg:pixels()
                    local grItr <const> = greenImg:pixels()
                    local blItr <const> = blueImg:pixels()

                    for pixel in rdItr do pixel(pixel() & rdMsk) end
                    for pixel in grItr do pixel(pixel() & grMsk) end
                    for pixel in blItr do pixel(pixel() & blMsk) end

                    if fillBase then
                        local trxRed <const> = redPos.x
                        local trxGreen <const> = greenPos.x
                        local trxBlue <const> = bluePos.x

                        local tryRed <const> = redPos.y
                        local tryGreen <const> = greenPos.y
                        local tryBlue <const> = bluePos.y

                        -- Technically, bottom right should subtract 1, but since
                        -- this will be added again to find wxh for base, it's omitted.
                        local trxBase <const> = min(trxRed, trxGreen, trxBlue)
                        local tryBase <const> = min(tryRed, tryGreen, tryBlue)
                        local brxBase <const> = max(trxRed, trxGreen, trxBlue) + srcImgWidth
                        local bryBase <const> = max(tryRed, tryGreen, tryBlue) + srcImgHeight

                        local baseWidth <const> = brxBase - trxBase
                        local baseHeight <const> = bryBase - tryBase
                        local baseCel <const> = activeSprite:newCel(baseLyr, srcFrame)
                        baseCel.position = Point(trxBase, tryBase)
                        baseCel.image = Image(baseWidth, baseHeight)

                        local xRedBase <const> = trxBase - trxRed
                        local xGreenBase <const> = trxBase - trxGreen
                        local xBlueBase <const> = trxBase - trxBlue

                        local yRedBase <const> = tryBase - tryRed
                        local yGreenBase <const> = tryBase - tryGreen
                        local yBlueBase <const> = tryBase - tryBlue

                        local baseItr <const> = baseCel.image:pixels()
                        for pixel in baseItr do
                            local x <const> = pixel.x
                            local y <const> = pixel.y
                            local placeMark = false

                            -- getPixel returns -1 when coordinates are out of
                            -- bounds. This wraps around to 4294967295
                            -- or the color white.
                            local xbTest <const> = x + xBlueBase
                            local ybTest <const> = y + yBlueBase
                            if xbTest > -1 and xbTest < srcImgWidth
                                and ybTest > -1 and ybTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    blueImg:getPixel(xbTest, ybTest) ~= 0
                            end

                            local xgTest <const> = x + xGreenBase
                            local ygTest <const> = y + yGreenBase
                            if xgTest > -1 and xgTest < srcImgWidth
                                and ygTest > -1 and ygTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    greenImg:getPixel(xgTest, ygTest) ~= 0
                            end

                            local xrTest <const> = x + xRedBase
                            local yrTest <const> = y + yRedBase
                            if xrTest > -1 and xrTest < srcImgWidth
                                and yrTest > -1 and yrTest < srcImgHeight then
                                placeMark = placeMark or 0xff000000 &
                                    redImg:getPixel(xrTest, yrTest) ~= 0
                            end

                            if placeMark then
                                pixel(0xff000000)
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
                app.transaction("Delete Cels", function()
                    local idxDel = lenFrames + 1
                    while idxDel > 1 do
                        idxDel = idxDel - 1
                        local frame <const> = frames[idxDel]
                        local cel <const> = srcLayer:cel(frame)
                        if cel then activeSprite:deleteCel(cel) end
                    end
                end)
            end
        end

        -- Active layer assignment triggers a timeline update.
        app.activeLayer = sepGroup
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