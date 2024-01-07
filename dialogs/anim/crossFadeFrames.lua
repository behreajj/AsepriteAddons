dofile("../../support/aseutilities.lua")

local facTypes <const> = { "FRAME", "TIME" }

local easeTypes <const> = {
    -- TODO: What if you want to take fr 1 as your origin and fr 4 as your dest
    -- but you want the fade to be 8 frames long?
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
    frameOrig = 1,
    frameDest = 1,
}

---@return integer
local function getFrIdx()
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return 1 end

    local docPrefs <const> = app.preferences.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local frIdx = frameUiOffset + 1

    local activeFrame <const> = site.frame
    if activeFrame then
        frIdx = activeFrame.frameNumber + frameUiOffset
    end

    return frIdx
end

local dlg <const> = Dialog { title = "Cross Fade Frames" }

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

dlg:button {
    id = "getOrig",
    label = "Get:",
    text = "&FROM",
    onclick = function()
        local frIdx <const> = getFrIdx()
        dlg:modify { id = "frameOrig", text = string.format("%d", frIdx) }
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

dlg:button {
    id = "getDest",
    label = "Get:",
    text = "&TO",
    onclick = function()
        local frIdx <const> = getFrIdx()
        dlg:modify { id = "frameDest", text = string.format("%d", frIdx) }
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
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
        local frIdxOrig <const> = args.frameOrig --[[@as integer]]
        local frIdxDest <const> = args.frameDest --[[@as integer]]

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

        local xtlComp = 0
        local ytlComp = 0
        local xbrComp = 0
        local ybrComp = 0

        local xtlDiffOrig = 0
        local ytlDiffOrig = 0
        local xtlDiffDest = 0
        local ytlDiffDest = 0

        local imageOrig = nil
        local imageDest = nil

        if srcLayer.isGroup then
            local flat0 <const>, rect0 <const> = AseUtilities.flattenGroup(
                srcLayer, frIdxOrigVerif, colorMode, colorSpace, alphaIndex,
                true, false, true, true)
            local flat1 <const>, rect1 <const> = AseUtilities.flattenGroup(
                srcLayer, frIdxDestVerif, colorMode, colorSpace, alphaIndex,
                true, false, true, true)

            imageOrig = flat0
            imageDest = flat1

            xtlComp = math.min(rect0.x, rect1.x)
            ytlComp = math.min(rect0.y, rect1.y)
            xbrComp = math.max(
                rect0.x + rect0.width - 1,
                rect1.x + rect1.width - 1)
            ybrComp = math.max(
                rect0.y + rect0.height - 1,
                rect1.y + rect1.height - 1)

            xtlDiffOrig = math.abs(xtlComp - rect0.x)
            ytlDiffOrig = math.abs(ytlComp - rect0.y)
            xtlDiffDest = math.abs(xtlComp - rect1.x)
            ytlDiffDest = math.abs(ytlComp - rect1.y)
        else
            local wSprite <const> = spriteSpec.width
            local hSprite <const> = spriteSpec.height

            local celOrig <const> = srcLayer:cel(frIdxOrigVerif)
            local xtlOrig = 0
            local ytlOrig = 0
            local xbrOrig = wSprite - 1
            local ybrOrig = hSprite - 1

            local posOrig = Point(0, 0)
            local posDest = Point(0, 0)

            if celOrig then
                local celOrigImg <const> = celOrig.image
                local wTileOrig = 1
                local hTileOrig = 1

                if srcLayer.isTilemap then
                    local tileSet <const> = srcLayer.tileset
                    if tileSet then
                        local tileGrid <const> = tileSet.grid
                        local tileDim <const> = tileGrid.tileSize
                        wTileOrig = math.max(1, math.abs(tileDim.width))
                        hTileOrig = math.max(1, math.abs(tileDim.height))
                    end
                    imageOrig = AseUtilities.tilesToImage(
                        celOrigImg, tileSet, colorMode)
                else
                    imageOrig = celOrigImg
                end

                posOrig = celOrig.position
                xtlOrig = posOrig.x
                ytlOrig = posOrig.y
                xbrOrig = xtlOrig + imageOrig.width * wTileOrig - 1
                ybrOrig = ytlOrig + imageOrig.height * hTileOrig - 1
            else
                imageOrig = Image(spriteSpec)
            end

            local celDest <const> = srcLayer:cel(frIdxDestVerif)
            local xtlDest = 0
            local ytlDest = 0
            local xbrDest = wSprite - 1
            local ybrDest = hSprite - 1

            if celDest then
                local celDestImg <const> = celDest.image
                local wTileDest = 1
                local hTileDest = 1

                if srcLayer.isTilemap then
                    local tileSet <const> = srcLayer.tileset
                    if tileSet then
                        local tileGrid <const> = tileSet.grid
                        local tileDim <const> = tileGrid.tileSize
                        wTileDest = math.max(1, math.abs(tileDim.width))
                        hTileDest = math.max(1, math.abs(tileDim.height))
                    end
                    imageDest = AseUtilities.tilesToImage(
                        celDestImg, tileSet, colorMode)
                else
                    imageDest = celDestImg
                end

                posDest = celDest.position
                xtlDest = posDest.x
                ytlDest = posDest.y
                xbrDest = xtlDest + imageDest.width * wTileDest - 1
                ybrDest = ytlDest + imageDest.height * hTileDest - 1
            else
                imageDest = Image(spriteSpec)
            end

            xtlComp = math.min(xtlOrig, xtlDest)
            ytlComp = math.min(ytlOrig, ytlDest)
            xbrComp = math.max(xbrOrig, xbrDest)
            ybrComp = math.max(ybrOrig, ybrDest)

            xtlDiffOrig = math.abs(xtlComp - posOrig.x)
            ytlDiffOrig = math.abs(ytlComp - posOrig.y)
            xtlDiffDest = math.abs(xtlComp - posDest.x)
            ytlDiffDest = math.abs(ytlComp - posDest.y)
        end

        if xtlComp >= xbrComp or ytlComp >= ybrComp then
            app.alert {
                title = "Error",
                text = "Invalid image dimensions."
            }
            return
        end

        local wComp <const> = 1 + xbrComp - xtlComp
        local hComp <const> = 1 + ybrComp - ytlComp
        local compSpec <const> = AseUtilities.createSpec(
            wComp, hComp, colorMode, colorSpace, alphaIndex)

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
            trgLayer.name = string.format("%s Tween %d %d %s",
                srcLayer.name,
                frIdxOrigVerif + frameUiOffset,
                frIdxDestVerif + frameUiOffset,
                easeType)
            trgLayer.parent = srcLayer.parent
        end)

        local blitOrig <const> = Image(compSpec)
        local blitDest <const> = Image(compSpec)

        blitOrig:drawImage(imageOrig, Point(xtlDiffOrig, ytlDiffOrig))
        blitDest:drawImage(imageDest, Point(xtlDiffDest, ytlDiffDest))

        local bytesOrig <const> = AseUtilities.getPixels(blitOrig)
        local bytesDest <const> = AseUtilities.getPixels(blitDest)
        local flatLen = wComp * hComp

        local compPoint <const> = Point(xtlComp, ytlComp)

        local eval <const> = Curve2.eval
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local mixSrLab2 <const> = Clr.mixSrLab2
        local tconcat <const> = table.concat
        local strpack <const> = string.pack
        local packZero <const> = strpack("B B B B", 0, 0, 0, 0)

        -- TODO: Should this be wrapped in a transaction?
        local j = 0
        while j < countFrames do
            local frObj <const> = frObjs[frIdxOrigVerif + j]
            local fac <const> = factors[1 + j]
            local t <const> = eval(curve, fac).y

            ---@type string[]
            local bytesComp = {}
            local k = 0
            while k < flatLen do
                local k4 <const> = k * 4

                local aOrig <const> = bytesOrig[4 + k4]
                local aDest <const> = bytesDest[4 + k4]

                local clearOrig = aOrig <= 0
                local clearDest = aDest <= 0
                if clearOrig and clearDest then
                    bytesComp[1 + k] = packZero
                else
                    local rOrig = bytesOrig[1 + k4]
                    local gOrig = bytesOrig[2 + k4]
                    local bOrig = bytesOrig[3 + k4]

                    local rDest = bytesDest[1 + k4]
                    local gDest = bytesDest[2 + k4]
                    local bDest = bytesDest[3 + k4]

                    if clearOrig then
                        rOrig = rDest
                        gOrig = gDest
                        bOrig = bDest
                    elseif clearDest then
                        rDest = rOrig
                        gDest = gOrig
                        bDest = bOrig
                    end

                    local rComp = rDest
                    local gComp = gDest
                    local bComp = bDest

                    local ao01 <const> = aOrig / 255.0
                    local ad01 <const> = aDest / 255.0
                    local ac01 <const> = (1.0 - t) * ao01 + t * ad01
                    local aComp = floor(ac01 * 255.0 + 0.5)

                    if rOrig ~= rDest
                        or gOrig ~= gDest
                        or bOrig ~= bDest then
                        local clrOrig <const> = Clr.new(
                            rOrig / 255.0,
                            gOrig / 255.0,
                            bOrig / 255.0,
                            1.0)

                        local clrDest <const> = Clr.new(
                            rDest / 255.0,
                            gDest / 255.0,
                            bDest / 255.0,
                            1.0)

                        local clrComp <const> = mixSrLab2(clrOrig, clrDest, t)
                        rComp = floor(min(max(clrComp.r, 0.0), 1.0) * 255.0 + 0.5)
                        gComp = floor(min(max(clrComp.g, 0.0), 1.0) * 255.0 + 0.5)
                        bComp = floor(min(max(clrComp.b, 0.0), 1.0) * 255.0 + 0.5)
                    end

                    bytesComp[1 + k] = strpack("B B B B", rComp, gComp, bComp, aComp)
                end

                k = k + 1
            end

            local compImage <const> = Image(compSpec)
            compImage.bytes = tconcat(bytesComp)

            activeSprite:newCel(trgLayer, frObj, compImage, compPoint)

            j = j + 1
        end

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