local targets = { "ACTIVE", "ALL", "RANGE" }

local defaults = {
    target = "ALL",
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
    text = string.format("%.1f", defaults.xRed),
    decimals = 5
}

dlg:number {
    id = "yRed",
    text = string.format("%.1f", defaults.yRed),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xGreen",
    label = "Green:",
    text = string.format("%.1f", defaults.xGreen),
    decimals = 5
}

dlg:number {
    id = "yGreen",
    text = string.format("%.1f", defaults.yGreen),
    decimals = 5
}

dlg:newrow { always = false }

dlg:number {
    id = "xBlue",
    label = "Blue:",
    text = string.format("%.1f", defaults.xBlue),
    decimals = 5
}

dlg:number {
    id = "yBlue",
    text = string.format("%.1f", defaults.yBlue),
    decimals = 5
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
        if activeSprite then
            if activeSprite.colorMode == ColorMode.RGB then
                local activeLayer = app.activeLayer
                if activeLayer then
                    if not activeLayer.isGroup then
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

                        local oldActiveCel = app.activeCel
                        local cels = {}
                        if target == "ACTIVE" then
                            local activeCel = app.activeCel
                            if activeCel then
                                cels[1] = activeCel
                            end
                        elseif target == "RANGE" then
                            local appRange = app.range

                            -- TODO: Abstract this to an AseUtilities method.
                            local layerCels = activeLayer.cels
                            local layerCelsLen = #layerCels
                            for i = 1, layerCelsLen, 1 do
                                local layerCel = layerCels[i]
                                if appRange:contains(layerCel) then
                                    table.insert(cels, layerCel)
                                end
                            end
                        else
                            cels = activeLayer.cels
                        end

                        local baseLyr = activeSprite:newLayer()
                        local redLyr = activeSprite:newLayer()
                        local greenLyr = activeSprite:newLayer()
                        local blueLyr = activeSprite:newLayer()

                        baseLyr.name = "Base"
                        redLyr.name = "Red"
                        greenLyr.name = "Green"
                        blueLyr.name = "Blue"

                        baseLyr.color = Color(32, 32, 32, 255)
                        redLyr.color = Color(192, 0, 0, 255)
                        greenLyr.color = Color(0, 192, 0, 255)
                        blueLyr.color = Color(0, 0, 192, 255)

                        redLyr.blendMode = BlendMode.ADDITION
                        greenLyr.blendMode = BlendMode.ADDITION
                        blueLyr.blendMode = BlendMode.ADDITION

                        redLyr.opacity = opacityRed
                        greenLyr.opacity = opacityGreen
                        blueLyr.opacity = opacityBlue

                        local redShift = Point(xRed, yRed)
                        local greenShift = Point(xGreen, yGreen)
                        local blueShift = Point(xBlue, yBlue)

                        local rdMsk = 0xff0000ff
                        local grMsk = 0xff00ff00
                        local blMsk = 0xffff0000

                        local max = math.max
                        local min = math.min

                        local celsLen = #cels
                        app.transaction(function()
                            for i = 1, celsLen, 1 do
                                local srcCel = cels[i]
                                if srcCel then
                                    local srcImg = srcCel.image
                                    -- if srcImg then
                                    local srcImgWidth = srcImg.width
                                    local srcImgHeight = srcImg.height
                                    local srcFrame = srcCel.frame
                                    local srcPos = srcCel.position

                                    local redCel = activeSprite:newCel(
                                        redLyr, srcFrame, srcImg, srcPos + redShift)
                                    local greenCel = activeSprite:newCel(
                                        greenLyr, srcFrame, srcImg, srcPos + greenShift)
                                    local blueCel = activeSprite:newCel(
                                        blueLyr, srcFrame, srcImg, srcPos + blueShift)

                                    local redImg = redCel.image
                                    local greenImg = greenCel.image
                                    local blueImg = blueCel.image

                                    local rdItr = redImg:pixels()
                                    local grItr = greenImg:pixels()
                                    local blItr = blueImg:pixels()

                                    for elm in rdItr do elm(elm() & rdMsk) end
                                    for elm in grItr do elm(elm() & grMsk) end
                                    for elm in blItr do elm(elm() & blMsk) end

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

                                    if fillBase then
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
                                            -- bounds, which is why this is so convoluted.
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
                                    -- end
                                end
                            end
                        end)

                        app.activeLayer = activeLayer
                        app.activeCel = oldActiveCel
                        app.refresh()
                    else
                        app.alert("Group layers are not supported.")
                    end
                else
                    app.alert("There is no active layer.")
                end
            else
                app.alert("Only RGB color mode is supported.")
            end
        else
            app.alert("There is no active sprite.")
        end
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