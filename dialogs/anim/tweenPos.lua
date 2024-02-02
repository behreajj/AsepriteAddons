dofile("../../support/aseutilities.lua")

local facTypes <const> = { "FRAME", "TIME" }

-- TODO: Replace with a bezier graph where the end points cannot be moved?
local easeTypes <const> = {
    "CIRC_IN",
    "CIRC_OUT",
    "EASE",
    "EASE_IN",
    "EASE_IN_OUT",
    "EASE_OUT",
    "LINEAR"
}

local defaults <const> = {
    facType = "FRAME",
    easeType = "EASE",
    trimCel = true,

    frameOrig = 1,
    xPosOrig = 0.0,
    yPosOrig = 0.0,

    frameDest = 1,
    xPosDest = 0.0,
    yPosDest = 0.0,
}

---@return integer
---@return number
---@return number
local function getCelPosAtFrame()
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return 1, 0.0, 0.0 end

    local docPrefs <const> = app.preferences.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local xCenter = activeSprite.width * 0.5
    local yCenter = activeSprite.height * 0.5
    local frIdx = frameUiOffset + 1

    local activeFrame <const> = site.frame
    if activeFrame then
        frIdx = activeFrame.frameNumber + frameUiOffset
    end

    local activeLayer <const> = site.layer
    if activeLayer then
        if (not activeLayer.isReference) and (not activeLayer.isGroup) then
            if activeFrame then
                local activeCel <const> = activeLayer:cel(activeFrame)
                if activeCel then
                    local celPos <const> = activeCel.position
                    local xtl <const> = celPos.x
                    local ytl <const> = celPos.y
                    local wTile = 1
                    local hTile = 1

                    if activeLayer.isTilemap then
                        local tileSet <const> = activeLayer.tileset
                        if tileSet then
                            local tileGrid <const> = tileSet.grid
                            local tileDim <const> = tileGrid.tileSize
                            wTile = math.max(1, math.abs(tileDim.width))
                            hTile = math.max(1, math.abs(tileDim.height))
                        end
                    end

                    local celImage <const> = activeCel.image
                    xCenter = xtl + (celImage.width * wTile) * 0.5
                    yCenter = ytl + (celImage.height * hTile) * 0.5
                end
            end
        end
    end

    return frIdx, xCenter, yCenter
end

local dlg <const> = Dialog { title = "Tween Cel Position" }

dlg:combobox {
    id = "facType",
    label = "Factor:",
    option = defaults.facType,
    options = facTypes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "easeType",
    label = "Easing:",
    option = defaults.easeType,
    options = easeTypes
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCel",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCel,
    visible = false
}

dlg:separator {
    id = "origSeparator",
    text = "Origin"
}

dlg:number {
    id = "frameOrig",
    label = "Frame:",
    text = string.format("%d", defaults.frameOrig),
    decimals = 0
}

dlg:newrow { always = false }

dlg:number {
    id = "xPosOrig",
    label = "Position:",
    text = string.format("%.1f", defaults.xPosOrig),
    decimals = 1
}

dlg:number {
    id = "yPosOrig",
    text = string.format("%.1f", defaults.yPosOrig),
    decimals = 1
}

dlg:newrow { always = false }

dlg:button {
    id = "getOrig",
    label = "Get:",
    text = "&FROM",
    onclick = function()
        local frIdx <const>, xc <const>, yc <const> = getCelPosAtFrame()
        dlg:modify { id = "frameOrig", text = string.format("%d", frIdx) }
        dlg:modify { id = "xPosOrig", text = string.format("%.1f", xc) }
        dlg:modify { id = "yPosOrig", text = string.format("%.1f", yc) }
    end
}

dlg:separator {
    id = "destSeparator",
    text = "Destination"
}

dlg:number {
    id = "frameDest",
    label = "Frame:",
    text = string.format("%d", defaults.frameDest),
    decimals = 0
}

dlg:newrow { always = false }

dlg:number {
    id = "xPosDest",
    label = "Position:",
    text = string.format("%.1f", defaults.xPosDest),
    decimals = 1
}

dlg:number {
    id = "yPosDest",
    text = string.format("%.1f", defaults.yPosDest),
    decimals = 1
}

dlg:newrow { always = false }

dlg:button {
    id = "getDest",
    label = "Get:",
    text = "&TO",
    onclick = function()
        local frIdx <const>, xc <const>, yc <const> = getCelPosAtFrame()
        dlg:modify { id = "frameDest", text = string.format("%d", frIdx) }
        dlg:modify { id = "xPosDest", text = string.format("%.1f", xc) }
        dlg:modify { id = "yPosDest", text = string.format("%.1f", yc) }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
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

        local srcFrame <const> = site.frame
        if not srcFrame then
            app.alert {
                title = "Error",
                text = "There is no active frame."
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

        if srcLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        local args <const> = dlg.data
        local facType <const> = args.facType --[[@as string]]
        local easeType <const> = args.easeType --[[@as string]]
        local trimCel <const> = args.trimCel --[[@as boolean]]
        local frIdxOrig <const> = args.frameOrig --[[@as integer]]
        local xPosOrig <const> = args.xPosOrig --[[@as number]]
        local yPosOrig <const> = args.yPosOrig --[[@as number]]
        local frIdxDest <const> = args.frameDest --[[@as integer]]
        local xPosDest <const> = args.xPosDest --[[@as number]]
        local yPosDest <const> = args.yPosDest --[[@as number]]

        local frObjs <const> = activeSprite.frames
        local lenFrames <const> = #frObjs
        if lenFrames <= 1 then
            app.alert {
                title = "Error",
                text = "The sprite has too few frames."
            }
            return
        end

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local frIdxOrigVerif <const> = math.min(math.max(
            frIdxOrig - frameUiOffset, 1), lenFrames)
        local frIdxDestVerif <const> = math.min(math.max(
            frIdxDest - frameUiOffset, 1), lenFrames)

        if frIdxOrigVerif == frIdxDestVerif then
            app.alert {
                title = "Error",
                text = "Origin and destination frames are the same."
            }
            return
        end

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        local srcImg = nil
        if srcLayer.isGroup then
            local flatImg <const>, _ = AseUtilities.flattenGroup(
                srcLayer, srcFrame, colorMode, colorSpace, alphaIndex,
                true, false, true, true)
            srcImg = flatImg
        else
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local celImg <const> = srcCel.image
                if srcLayer.isTilemap then
                    local tileSet <const> = srcLayer.tileset
                    srcImg = AseUtilities.tileMapToImage(
                        celImg, tileSet, colorMode)
                else
                    srcImg = celImg
                end
            end
        end

        if not srcImg then
            app.alert {
                title = "Error",
                text = "There is no source image."
            }
            return
        end

        if srcImg:isEmpty() then
            app.alert {
                title = "Error",
                text = "Source image is empty."
            }
            return
        end

        if srcLayer.isBackground then
            app.command.SwitchColors()
            local aseBkg <const> = app.fgColor
            local bkgHex <const> = AseUtilities.aseColorToHex(aseBkg, colorMode)
            app.command.SwitchColors()

            local cleared <const> = srcImg:clone()
            local clearedItr <const> = cleared:pixels()
            for pixel in clearedItr do
                if pixel() == bkgHex then pixel(alphaIndex) end
            end
            srcImg = cleared
        end

        if trimCel then
            local trimmed <const>, _, _ = AseUtilities.trimImageAlpha(
                srcImg, 0, alphaIndex)
            srcImg = trimmed
        end

        ---@type number[]
        local factors <const> = {}
        local countFrames <const> = 1 + math.abs(frIdxDestVerif - frIdxOrigVerif)

        if facType == "TIME" then
            ---@type number[]
            local timeStamps <const> = {}
            local totalDuration = 0

            local h = 0
            while h < countFrames do
                local frObj <const> = frObjs[frIdxOrigVerif + h]
                timeStamps[1 + h] = totalDuration
                totalDuration = totalDuration + frObj.duration
                h = h + 1
            end

            local timeToFac = 0.0
            local finalDuration <const> = timeStamps[countFrames]
            if finalDuration and finalDuration ~= 0.0 then
                timeToFac = 1.0 / finalDuration
            end

            local i = 0
            while i < countFrames do
                i = i + 1
                factors[i] = timeStamps[i] * timeToFac
            end
        else
            -- Default to using frames.
            local iToFac <const> = 1.0 / (countFrames - 1)
            local i = 0
            while i < countFrames do
                local iFac <const> = i * iToFac
                i = i + 1
                factors[i] = iFac
            end
        end

        -- Set animation curve. Default to linear.
        local curve = Curve2.animLinear()
        if easeType == "EASE" then
            curve = Curve2.animEase()
        elseif easeType == "EASE_IN" then
            curve = Curve2.animEaseIn()
        elseif easeType == "EASE_IN_OUT" then
            curve = Curve2.animEaseInOut()
        elseif easeType == "EASE_OUT" then
            curve = Curve2.animEaseOut()
        elseif easeType == "CIRC_IN" then
            curve = Curve2.animCircIn()
        elseif easeType == "CIRC_OUT" then
            curve = Curve2.animCircOut()
        end

        local trgLayer = nil
        app.transaction("New Layer", function()
            trgLayer = activeSprite:newLayer()
            trgLayer.name = string.format("%s Tween %d %s",
                srcLayer.name, srcFrame.frameNumber + frameUiOffset, easeType)
            trgLayer.parent = srcLayer.parent
        end)

        local wImgHalf <const> = srcImg.width * 0.5
        local hImgHalf <const> = srcImg.height * 0.5
        local round <const> = Utilities.round
        local eval <const> = Curve2.eval

        app.transaction("Tween Cel Position", function()
            local j = 0
            while j < countFrames do
                local frObj <const> = frObjs[frIdxOrigVerif + j]
                local fac <const> = factors[1 + j]
                local t <const> = eval(curve, fac).y
                local u <const> = 1.0 - t

                local xCenter <const> = u * xPosOrig + t * xPosDest
                local yCenter <const> = u * yPosOrig + t * yPosDest
                local xtl <const> = xCenter - wImgHalf
                local ytl <const> = yCenter - hImgHalf
                local xtlInt <const> = round(xtl)
                local ytlInt <const> = round(ytl)
                local trgPoint <const> = Point(xtlInt, ytlInt)

                activeSprite:newCel(trgLayer, frObj, srcImg, trgPoint)
                j = j + 1
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

dlg:show {
    autoscrollbars = true,
    wait = false
}