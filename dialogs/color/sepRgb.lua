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
            tileSet = srcLayer.tileset
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

        local sepGroup <const> = activeSprite:newGroup()
        local baseLyr <const> = fillBase and activeSprite:newLayer() or nil
        local redLyr <const> = activeSprite:newLayer()
        local greenLyr <const> = activeSprite:newLayer()
        local blueLyr <const> = activeSprite:newLayer()

        app.transaction("Set Layer Props", function()
            if baseLyr then
                baseLyr.name = "Base"
                baseLyr.color = Color { r = 32, g = 32, b = 32 }
            end

            redLyr.name = "Red"
            redLyr.color = Color { r = 192, g = 0, b = 0 }
            redLyr.blendMode = BlendMode.ADDITION
            redLyr.opacity = opacityRed

            greenLyr.name = "Green"
            greenLyr.color = Color { r = 0, g = 192, b = 0 }
            greenLyr.blendMode = BlendMode.ADDITION
            greenLyr.opacity = opacityGreen

            blueLyr.name = "Blue"
            blueLyr.color = Color { r = 0, g = 0, b = 192 }
            blueLyr.blendMode = BlendMode.ADDITION
            blueLyr.opacity = opacityBlue
        end)

        app.transaction("Set Group Props", function()
            if baseLyr then
                baseLyr.parent = sepGroup
            end

            redLyr.parent = sepGroup
            greenLyr.parent = sepGroup
            blueLyr.parent = sepGroup

            sepGroup.parent = AseUtilities.getTopVisibleParent(srcLayer)
            sepGroup.isCollapsed = true
            sepGroup.name = srcLayer.name .. " Separated"
        end)

        local max <const> = math.max
        local min <const> = math.min
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec
        local tconcat <const> = table.concat
        local strbyte <const> = string.byte
        local strpack <const> = string.pack

        local baseMark <const> = string.pack("B B B B", 0, 0, 0, 255)
        local baseClear <const> = string.pack("B B B B", 0, 0, 0, 0)

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

                    local srcSpec <const> = srcImg.spec
                    local srcWidth <const> = srcSpec.width
                    local srcHeight <const> = srcSpec.height
                    local srcPxLen <const> = srcWidth * srcHeight
                    local srcBytes <const> = srcImg.bytes

                    local rImg <const> = Image(srcSpec)
                    local gImg <const> = Image(srcSpec)
                    local bImg <const> = Image(srcSpec)

                    ---@type string[]
                    local rBytesArr <const> = {}
                    ---@type string[]
                    local gBytesArr <const> = {}
                    ---@type string[]
                    local bBytesArr <const> = {}
                    ---@type integer[]
                    local aArr <const> = {}

                    local j = 0
                    while j < srcPxLen do
                        local j4 <const> = j * 4
                        local rSrc <const>,
                        gSrc <const>,
                        bSrc <const>,
                        aSrc <const> = strbyte(srcBytes, 1 + j4, 4 + j4)

                        j = j + 1
                        rBytesArr[j] = strpack("B B B B", rSrc, 0, 0, aSrc)
                        gBytesArr[j] = strpack("B B B B", 0, gSrc, 0, aSrc)
                        bBytesArr[j] = strpack("B B B B", 0, 0, bSrc, aSrc)
                        aArr[j] = aSrc
                    end

                    rImg.bytes = tconcat(rBytesArr)
                    gImg.bytes = tconcat(gBytesArr)
                    bImg.bytes = tconcat(bBytesArr)

                    local srcPos <const> = srcCel.position
                    local xSrc <const> = srcPos.x
                    local ySrc <const> = srcPos.y

                    local trxRed <const> = xSrc + xRed
                    local trxGreen <const> = xSrc + xGreen
                    local trxBlue <const> = xSrc + xBlue

                    -- Treat y axis as (1, 0) points up.
                    local tryRed <const> = ySrc - yRed
                    local tryGreen <const> = ySrc - yGreen
                    local tryBlue <const> = ySrc - yBlue

                    local redCel <const> = activeSprite:newCel(
                        redLyr, srcFrame, rImg, Point(trxRed, tryRed))
                    local greenCel <const> = activeSprite:newCel(
                        greenLyr, srcFrame, gImg, Point(trxGreen, tryGreen))
                    local blueCel <const> = activeSprite:newCel(
                        blueLyr, srcFrame, bImg, Point(trxBlue, tryBlue))

                    local srcOpacity <const> = srcCel.opacity
                    redCel.opacity = srcOpacity
                    greenCel.opacity = srcOpacity
                    blueCel.opacity = srcOpacity

                    local srcZIndex <const> = srcCel.zIndex
                    redCel.zIndex = srcZIndex
                    greenCel.zIndex = srcZIndex
                    blueCel.zIndex = srcZIndex

                    if baseLyr then
                        local trxBase <const> = min(trxRed, trxGreen, trxBlue)
                        local tryBase <const> = min(tryRed, tryGreen, tryBlue)
                        local brxBase <const> = max(trxRed, trxGreen, trxBlue)
                            + srcWidth - 1
                        local bryBase <const> = max(tryRed, tryGreen, tryBlue)
                            + srcHeight - 1

                        local baseWidth <const> = 1 + brxBase - trxBase
                        local baseHeight <const> = 1 + bryBase - tryBase
                        local basePxLen <const> = baseWidth * baseHeight

                        local xRedBase <const> = trxBase - trxRed
                        local xGreenBase <const> = trxBase - trxGreen
                        local xBlueBase <const> = trxBase - trxBlue

                        local yRedBase <const> = tryBase - tryRed
                        local yGreenBase <const> = tryBase - tryGreen
                        local yBlueBase <const> = tryBase - tryBlue

                        ---@type string[]
                        local baseBytesArr <const> = {}

                        local k = 0
                        while k < basePxLen do
                            local xBase <const> = k % baseWidth
                            local yBase <const> = k // baseWidth
                            local placeMark = false

                            local xrTest <const> = xBase + xRedBase
                            local yrTest <const> = yBase + yRedBase
                            if xrTest >= 0 and xrTest < srcWidth
                                and yrTest >= 0 and yrTest < srcHeight then
                                local rIdx <const> = xrTest + yrTest * srcWidth
                                placeMark = placeMark or aArr[1 + rIdx] > 0
                            end

                            local xgTest <const> = xBase + xGreenBase
                            local ygTest <const> = yBase + yGreenBase
                            if xgTest >= 0 and xgTest < srcWidth
                                and ygTest >= 0 and ygTest < srcHeight then
                                local gIdx <const> = xgTest + ygTest * srcWidth
                                placeMark = placeMark or aArr[1 + gIdx] > 0
                            end

                            local xbTest <const> = xBase + xBlueBase
                            local ybTest <const> = yBase + yBlueBase
                            if xbTest >= 0 and xbTest < srcWidth
                                and ybTest >= 0 and ybTest < srcHeight then
                                local bIdx <const> = xbTest + ybTest * srcWidth
                                placeMark = placeMark or aArr[1 + bIdx] > 0
                            end

                            k = k + 1
                            if placeMark then
                                baseBytesArr[k] = baseMark
                            else
                                baseBytesArr[k] = baseClear
                            end
                        end

                        local baseSpec <const> = createSpec(
                            baseWidth, baseHeight,
                            srcSpec.colorMode,
                            srcSpec.colorSpace,
                            srcSpec.transparentColor)
                        local baseImg <const> = Image(baseSpec)
                        baseImg.bytes = tconcat(baseBytesArr)
                        activeSprite:newCel(baseLyr, srcFrame, baseImg,
                            Point(trxBase, tryBase))
                    end -- End of fill base check.
                end     -- End of source cel check.
            end         -- End of frames loop.
        end)

        -- Active layer assignment triggers a timeline update.
        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.layer = sepGroup
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