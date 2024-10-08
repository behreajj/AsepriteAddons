dofile("../../support/aseutilities.lua")

local frameTargets <const> = { "ACTIVE", "ALL", "TAG" }
local fillOpts <const> = { "CROSS_FADE", "EMPTY", "SUSTAIN" }

local defaults <const> = {
    -- TODO: Retain range of layer and frame type.
    frameTarget = "ALL",
    isLoop = false,
    fillOpt = "SUSTAIN",
    inbetweens = 1,
    matchTime = true,
    useTint = false,
}

---Durations need to be rounded after scaling due to precision differences
---between seconds (internal) and milliseconds (UI).
---@param duration number
---@param scalar number
---@return number
---@nodiscard
local function mulRoundDur(duration, scalar)
    local durNew <const> = duration * scalar
    local durNewMs <const> = math.floor(durNew * 1000.0 + 0.5)
    return math.min(math.max(durNewMs * 0.001, 0.001), 65.535)
end

---@param activeSprite Sprite
---@param leaf Layer
---@param frIdxNewPrev integer
---@param frIdxNewNext integer
---@param frameUiOffset integer
---@param inbetweens integer
---@param useTint boolean
---@param tintColor Color
local function crossFade(
    activeSprite,
    leaf,
    frIdxNewPrev,
    frIdxNewNext,
    frameUiOffset,
    inbetweens,
    useTint,
    tintColor)
    local celNext <const> = leaf:cel(frIdxNewNext)
    local celPrev <const> = leaf:cel(frIdxNewPrev)
    if (not celNext) and (not celPrev) then return end

    local spriteSpec <const> = activeSprite.spec

    local imgNext = nil
    local opacNext = 255
    local xtlNext = 0
    local ytlNext = 0
    local zIdxNext = 0
    local imgIdNext = -1

    if celNext then
        local posNext <const> = celNext.position
        imgNext = celNext.image
        opacNext = celNext.opacity
        xtlNext = posNext.x
        ytlNext = posNext.y
        zIdxNext = celNext.zIndex
        imgIdNext = imgNext.id
    else
        imgNext = Image(spriteSpec)
    end

    -- print(string.format(
    --     "opacNext: %d, xtlNext: %d, ytlNext: %d, zIdxNext: %d",
    --     opacNext, xtlNext, ytlNext, zIdxNext))

    local imgPrev = nil
    local opacPrev = 255
    local xtlPrev = 0
    local ytlPrev = 0
    local zIdxPrev = 0
    local imgIdPrev = -1

    if celPrev then
        local posPrev <const> = celPrev.position
        imgPrev = celPrev.image
        opacPrev = celPrev.opacity
        xtlPrev = posPrev.x
        ytlPrev = posPrev.y
        zIdxPrev = celPrev.zIndex
        imgIdPrev = imgPrev.id
    else
        imgPrev = Image(spriteSpec)
    end

    -- print(string.format(
    --     "opacPrev: %d, xtlPrev: %d, ytlPrev: %d, zIdxPrev: %d",
    --     opacPrev, xtlPrev, ytlPrev, zIdxPrev))

    if imgIdNext == -1 then opacNext = opacPrev end
    if imgIdPrev == -1 then opacPrev = opacNext end

    -- Cache methods used in loops.
    local floor <const> = math.floor
    local max <const> = math.max
    local min <const> = math.min
    local strpack <const> = string.pack
    local tconcat <const> = table.concat
    local round <const> = Utilities.round
    local clrnew <const> = Clr.new
    local mixSrLab2 <const> = Clr.mixSrLab2

    local leafName <const> = leaf.name
    local trName <const> = string.format("Fade from %d to %d on %s",
        frIdxNewPrev + frameUiOffset, frIdxNewNext, leafName)
    local jToFac <const> = 1.0 / (inbetweens + 1.0)

    -- Check to see if cels are linked, and thus don't need to be blended.
    if imgIdPrev == imgIdNext then
        local posPrev <const> = Point(xtlPrev, ytlPrev)
        app.transaction(trName, function()
            local j = 0
            while j < inbetweens do
                j = j + 1
                local trgFrIdx <const> = frIdxNewPrev + j
                local trgCel <const> = activeSprite:newCel(
                    leaf, trgFrIdx, imgPrev, posPrev)
                trgCel.opacity = opacPrev

                -- zIndex is always interpolated, even for linked cels.
                local t <const> = j * jToFac
                trgCel.zIndex = round((1.0 - t) * zIdxPrev + t * zIdxNext)
                if useTint then trgCel.color = tintColor end
            end
        end)
    else
        local wPrev <const> = imgPrev.width
        local hPrev <const> = imgPrev.height
        local xbrPrev <const> = xtlPrev + wPrev - 1
        local ybrPrev <const> = ytlPrev + hPrev - 1

        local wNext <const> = imgNext.width
        local hNext <const> = imgNext.height
        local xbrNext <const> = xtlNext + wNext - 1
        local ybrNext <const> = ytlNext + hNext - 1

        local xtlComp <const> = math.min(xtlNext, xtlPrev)
        local ytlComp <const> = math.min(ytlNext, ytlPrev)
        local xbrComp <const> = math.max(xbrNext, xbrPrev)
        local ybrComp <const> = math.max(ybrNext, ybrPrev)

        -- print(string.format(
        --     "xtlComp: %d, ytlComp: %d, xbrComp: %d, ybrComp: %d",
        --     xtlComp, ytlComp, xbrComp, ybrComp))

        if xtlComp <= xbrComp and ytlComp <= ybrComp then
            -- print("valid comp space")

            local opacPrev01 <const> = opacPrev / 255.0
            local opacNext01 <const> = opacNext / 255.0

            local xtlDiffNext <const> = xtlComp - xtlNext
            local ytlDiffNext <const> = ytlComp - ytlNext
            local xtlDiffPrev <const> = xtlComp - xtlPrev
            local ytlDiffPrev <const> = ytlComp - ytlPrev

            local colorMode <const> = spriteSpec.colorMode
            local alphaIndex <const> = spriteSpec.transparentColor
            local colorSpace <const> = spriteSpec.colorSpace

            local pointComp <const> = Point(xtlComp, ytlComp)
            local wComp <const> = 1 + xbrComp - xtlComp
            local hComp <const> = 1 + ybrComp - ytlComp
            local flatLenComp <const> = wComp * hComp
            local specComp <const> = AseUtilities.createSpec(
                wComp, hComp,
                colorMode, colorSpace, alphaIndex)

            local bytesPrev <const> = AseUtilities.getPixels(imgPrev)
            local bytesNext <const> = AseUtilities.getPixels(imgNext)
            local packZero <const> = string.pack("B B B B", 0, 0, 0, 0)

            app.transaction(trName, function()
                local j = 0
                while j < inbetweens do
                    j = j + 1
                    local trgFrIdx <const> = frIdxNewPrev + j
                    local t <const> = j * jToFac
                    local u <const> = 1.0 - t

                    ---@type string[]
                    local bytesComp <const> = {}
                    local k = 0
                    while k < flatLenComp do
                        local xComp <const> = k % wComp
                        local yComp <const> = k // wComp

                        local rComp, gComp, bComp, aComp = 0, 0, 0, 0
                        local rNext, gNext, bNext, aNext = 0, 0, 0, 0
                        local rPrev, gPrev, bPrev, aPrev = 0, 0, 0, 0

                        local xNext <const> = xComp + xtlDiffNext
                        local yNext <const> = yComp + ytlDiffNext
                        if yNext >= 0 and yNext < hNext
                            and xNext >= 0 and xNext < wNext then
                            local kn4 <const> = (yNext * wNext + xNext) * 4

                            rNext = bytesNext[1 + kn4]
                            gNext = bytesNext[2 + kn4]
                            bNext = bytesNext[3 + kn4]
                            aNext = bytesNext[4 + kn4]
                        end

                        local xPrev <const> = xComp + xtlDiffPrev
                        local yPrev <const> = yComp + ytlDiffPrev
                        if yPrev >= 0 and yPrev < hPrev
                            and xPrev >= 0 and xPrev < wPrev then
                            local kp4 <const> = (yPrev * wPrev + xPrev) * 4

                            rPrev = bytesPrev[1 + kp4]
                            gPrev = bytesPrev[2 + kp4]
                            bPrev = bytesPrev[3 + kp4]
                            aPrev = bytesPrev[4 + kp4]
                        end

                        local angt0 <const> = aNext > 0
                        local apgt0 <const> = aPrev > 0
                        local packedStr = packZero
                        if angt0 or apgt0 then
                            if not angt0 then
                                rNext = rPrev
                                gNext = gPrev
                                bNext = bPrev
                            end

                            if not apgt0 then
                                rPrev = rNext
                                gPrev = gNext
                                bPrev = bNext
                            end

                            local ap01 <const> = aPrev / 255.0
                            local an01 <const> = aNext / 255.0
                            local ac01 <const> = u * ap01 + t * an01
                            aComp = floor(ac01 * 255.0 + 0.5)

                            rComp = rNext
                            gComp = gNext
                            bComp = bNext

                            if rPrev ~= rNext
                                or gPrev ~= gNext
                                or bPrev ~= bNext then
                                local clrNext <const> = clrnew(
                                    rNext / 255.0,
                                    gNext / 255.0,
                                    bNext / 255.0,
                                    1.0)

                                local clrPrev <const> = clrnew(
                                    rPrev / 255.0,
                                    gPrev / 255.0,
                                    bPrev / 255.0,
                                    1.0)

                                local clrComp <const> = mixSrLab2(clrPrev, clrNext, t)
                                rComp = floor(min(max(clrComp.r, 0.0), 1.0) * 255.0 + 0.5)
                                gComp = floor(min(max(clrComp.g, 0.0), 1.0) * 255.0 + 0.5)
                                bComp = floor(min(max(clrComp.b, 0.0), 1.0) * 255.0 + 0.5)
                            end

                            packedStr = strpack("B B B B",
                                rComp, gComp, bComp, aComp)
                        end

                        k = k + 1
                        bytesComp[k] = packedStr
                    end

                    local opacComp01 <const> = u * opacPrev01 + t * opacNext01
                    local opacComp <const> = floor(opacComp01 * 255.0 + 0.5)
                    local zIdxComp <const> = round(u * zIdxPrev + t * zIdxNext)

                    local imgComp <const> = Image(specComp)
                    imgComp.bytes = tconcat(bytesComp)

                    local trgCel <const> = activeSprite:newCel(
                        leaf, trgFrIdx, imgComp, pointComp)
                    trgCel.opacity = opacComp
                    trgCel.zIndex = zIdxComp
                    if useTint then trgCel.color = tintColor end
                end -- End inbetweens loop.
            end)
        end         -- End valid bounds check.
    end             -- End linked cels check.
end

local dlg <const> = Dialog { title = "Expand Frames" }

dlg:combobox {
    id = "frameTarget",
    label = "Target:",
    option = defaults.frameTarget,
    options = frameTargets,
    onchange = function()
        local args <const> = dlg.data
        local frameTarget <const> = args.frameTarget --[[@as string]]
        local isAll <const> = frameTarget == "ALL"
        dlg:modify { id = "isLoop", visible = isAll }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "inbetweens",
    label = "Expand:",
    min = 1,
    max = 64,
    value = defaults.inbetweens,
    focus = true
}

dlg:newrow { always = false }

dlg:combobox {
    id = "fillOpt",
    label = "Fill:",
    option = defaults.fillOpt,
    options = fillOpts,
    onchange = function()
        local args <const> = dlg.data
        local fillOpt <const> = args.fillOpt --[[@as string]]
        local frameTarget <const> = args.frameTarget --[[@as string]]
        local useTint <const> = args.useTint --[[@as boolean]]

        local isFade <const> = fillOpt == "CROSS_FADE"
        local notEmpty <const> = fillOpt ~= "EMPTY"
        local isAll <const> = frameTarget == "ALL"
        dlg:modify { id = "isLoop", visible = isFade and isAll }
        dlg:modify { id = "tilemapWarn", visible = isFade }
        dlg:modify { id = "useTint", visible = notEmpty }
        dlg:modify { id = "tintColor", visible = useTint and notEmpty }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useTint",
    label = "Tint:",
    text = "C&els",
    selected = defaults.useTint,
    visible = defaults.fillOpt ~= "EMPTY",
    onclick = function()
        local args <const> = dlg.data
        local useTint <const> = args.useTint --[[@as boolean]]
        dlg:modify { id = "tintColor", visible = useTint }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "tintColor",
    color = Color { r = 0, g = 0, b = 0, a = 180 },
    visible = defaults.fillOpt ~= "EMPTY"
        and defaults.useTint
}

dlg:newrow { always = false }

dlg:check {
    id = "matchTime",
    label = "Match:",
    text = "&Time",
    selected = defaults.matchTime
}

dlg:newrow { always = false }

dlg:check {
    id = "isLoop",
    label = "Loop:",
    text = "&Frames",
    selected = defaults.isLoop,
    visible = defaults.frameTarget == "ALL"
        and defaults.fillOpt == "CROSS_FADE"
}

dlg:newrow { always = false }

dlg:label {
    id = "tilemapWarn",
    label = "Note:",
    text = "Tile maps excluded.",
    visible = defaults.fillOpt == "CROSS_FADE"
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
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

        -- Unpack arguments.
        local args <const> = dlg.data
        local frameTarget <const> = args.frameTarget
            or defaults.frameTarget --[[@as string]]
        local isLoop <const> = args.isLoop --[[@as boolean]]
        local inbetweens <const> = args.inbetweens
            or defaults.inbetweens --[[@as integer]]
        local fillOpt <const> = args.fillOpt
            or defaults.fillOpt --[[@as string]]
        local matchTime <const> = args.matchTime --[[@as boolean]]
        local useTint <const> = args.useTint --[[@as boolean]]
        local tintColor <const> = args.tintColor --[[@as Color]]

        --Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode

        local isCrossFade <const> = fillOpt == "CROSS_FADE"
        if isCrossFade and colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local frIdcs <const> = Utilities.flatArr2(AseUtilities.getFrames(
            activeSprite, frameTarget))
        if #frIdcs <= 0 then
            app.alert {
                title = "Error",
                text = "No frames were selected."
            }
            return
        end

        -- Cross fade requires at least two frames to interpolate between,
        -- so the active target needs to append the frame to the right.
        if isCrossFade then
            local lenFrObjs <const> = #activeSprite.frames
            if lenFrObjs <= 1 then
                app.alert {
                    title = "Error",
                    text = "Sprite must have more than 1 frame."
                }
                return
            end

            if #frIdcs == 1 then
                if frIdcs[1] == lenFrObjs then
                    frIdcs[2] = lenFrObjs
                    frIdcs[1] = lenFrObjs - 1
                else
                    frIdcs[2] = frIdcs[1] + 1
                end
            end
        end

        -- Cache global methods to local.
        local max <const> = math.max
        local min <const> = math.min
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        local lenFrIdcs <const> = #frIdcs
        local oldActiveFrObj <const> = site.frame or activeSprite.frames[1]
        local oldActiveFrIdx <const> = oldActiveFrObj.frameNumber
        local newActiveFrIdx <const> = oldActiveFrIdx > frIdcs[1]
            and oldActiveFrIdx + (oldActiveFrIdx - frIdcs[1]) * inbetweens
            or oldActiveFrIdx

        -- print(string.format(
        --     "oldActiveFrIdx: %d, newActiveFrIdx: %d",
        --     oldActiveFrIdx, newActiveFrIdx))

        local isAll <const> = frameTarget == "ALL"
        local isLoopVerif <const> = isLoop and isAll

        app.transaction("Create New Frames", function()
            if isLoopVerif or (not isCrossFade) then
                -- For sustain, empty and cross fade with a loop,
                -- add extra frames to the end of the sprite.
                local idxInsert <const> = frIdcs[lenFrIdcs] + 1
                local j = 0
                while j < inbetweens do
                    j = j + 1
                    activeSprite:newEmptyFrame(idxInsert)
                end
            end

            local i = lenFrIdcs + 1
            while i > 2 do
                i = i - 1
                local frIdx <const> = frIdcs[i]
                local j = inbetweens + 1
                while j > 1 do
                    j = j - 1
                    activeSprite:newEmptyFrame(frIdx)
                end
            end
        end)

        local frObjsAfter <const> = activeSprite.frames
        if isCrossFade then
            local jToFac <const> = 1.0 / (inbetweens + 1)

            app.transaction("Cross Fade Frame Durations", function()
                local i = 0
                while i < lenFrIdcs - 1 do
                    local frIdxOldPrev <const> = frIdcs[1 + i]
                    local frIdxNewPrev <const> = frIdxOldPrev + i * inbetweens
                    local durPrev <const> = frObjsAfter[frIdxNewPrev].duration

                    local frIdxOldNext <const> = frIdcs[2 + i]
                    local frIdxNewNext <const> = frIdxOldNext + (1 + i) * inbetweens
                    local durNext <const> = frObjsAfter[frIdxNewNext].duration

                    -- print(string.format(
                    --     "frIdxPrev: %d, durPrev: %.3f, frIdxNext: %d, durNext: %.3f",
                    --     frIdxNewPrev, durPrev, frIdxNewNext, durNext))

                    local j = 0
                    while j < inbetweens do
                        j = j + 1
                        local jFac <const> = j * jToFac
                        local trgDur <const> = min(max((1.0 - jFac) * durPrev
                            + jFac * durNext, 0.001), 65.535)
                        local trgFrObj <const> = frObjsAfter[frIdxNewPrev + j]
                        trgFrObj.duration = trgDur

                        -- print(string.format(
                        --     "frIdx: %d, jFac: %.3f, trgDur: %.3f",
                        --     frIdxNewPrev + j, jFac, trgDur))
                    end

                    i = i + 1
                end

                if isLoopVerif then
                    local frIdxOldPrev <const> = frIdcs[lenFrIdcs]
                    local frIdxNewPrev <const> = frIdxOldPrev + (lenFrIdcs - 1) * inbetweens
                    local durPrev <const> = frObjsAfter[frIdxNewPrev].duration
                    local durNext <const> = frObjsAfter[1].duration

                    local j = 0
                    while j < inbetweens do
                        j = j + 1
                        local jFac <const> = j * jToFac
                        local trgDur <const> = min(max((1.0 - jFac) * durPrev
                            + jFac * durNext, 0.001), 65.535)
                        local frObj <const> = frObjsAfter[frIdxNewPrev + j]
                        frObj.duration = trgDur
                    end -- End inbetweens loop.
                end     -- End is loop check.
            end)

            if matchTime then
                local totDurOld = 0.0
                local totDurNew = 0.0

                local i = 0
                while i < lenFrIdcs do
                    local frIdxOld <const> = frIdcs[1 + i]
                    local frIdxNew <const> = frIdxOld + i * inbetweens
                    local frObjOld <const> = frObjsAfter[frIdxNew]
                    local durOld <const> = frObjOld.duration

                    totDurOld = totDurOld + durOld
                    totDurNew = totDurNew + durOld

                    if isLoopVerif or (i < lenFrIdcs - 1) then
                        local j = 0
                        while j < inbetweens do
                            j = j + 1
                            local frObjNew <const> = frObjsAfter[frIdxNew + j]
                            totDurNew = totDurNew + frObjNew.duration
                        end
                    end

                    i = i + 1
                end

                local ratio <const> = totDurNew ~= 0.0
                    and totDurOld / totDurNew
                    or 0.0

                app.transaction("Match Time", function()
                    local k = 0
                    while k < lenFrIdcs do
                        local frIdxOld <const> = frIdcs[1 + k]
                        local frIdxNew <const> = frIdxOld + k * inbetweens
                        local frObjOld <const> = frObjsAfter[frIdxNew]
                        frObjOld.duration = mulRoundDur(frObjOld.duration, ratio)

                        if isLoopVerif or (k < lenFrIdcs - 1) then
                            local j = 0
                            while j < inbetweens do
                                j = j + 1
                                local frObjNew <const> = frObjsAfter[frIdxNew + j]
                                frObjNew.duration = mulRoundDur(frObjNew.duration, ratio)
                            end
                        end

                        k = k + 1
                    end -- End of frames loop.
                end)    -- End of match time transaction.
            end         -- End of match time check.
        else
            app.transaction("Sustain Frame Durations", function()
                local durScalar <const> = matchTime
                    and 1.0 / (inbetweens + 1.0)
                    or 1.0

                local i = 0
                while i < lenFrIdcs do
                    local frIdxOld <const> = frIdcs[1 + i]
                    local frIdxNew <const> = frIdxOld + i * inbetweens
                    local trgDur <const> = mulRoundDur(
                        frObjsAfter[frIdxNew].duration, durScalar)

                    local j = 0
                    while j < inbetweens + 1 do
                        -- This includes the original frame because
                        -- sustain may scale the original's duration.
                        frObjsAfter[frIdxNew + j].duration = trgDur
                        j = j + 1
                    end

                    i = i + 1
                end
            end)
        end

        if fillOpt == "EMPTY" then
            app.frame = frObjsAfter[newActiveFrIdx]
            app.refresh()
            return
        end

        -- Exclude tile map layers from cross fading.
        local leaves <const> = AseUtilities.getLayerHierarchy(activeSprite,
            true, true, not isCrossFade, true)
        local lenLeaves <const> = #leaves

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        if isCrossFade then
            local h = 0
            while h < lenLeaves do
                h = h + 1
                local leaf <const> = leaves[h]

                local i = 0
                while i < lenFrIdcs - 1 do
                    local frIdxOldPrev <const> = frIdcs[1 + i]
                    local frIdxNewPrev <const> = frIdxOldPrev + i * inbetweens
                    local frIdxOldNext <const> = frIdcs[2 + i]
                    local frIdxNewNext <const> = frIdxOldNext + (1 + i) * inbetweens
                    crossFade(activeSprite, leaf, frIdxNewPrev, frIdxNewNext,
                        frameUiOffset, inbetweens, useTint, tintColor)

                    i = i + 1
                end

                if isLoopVerif then
                    local frIdxOldPrev <const> = frIdcs[lenFrIdcs]
                    local frIdxNewPrev <const> = frIdxOldPrev + (lenFrIdcs - 1) * inbetweens
                    crossFade(activeSprite, leaf, frIdxNewPrev, 1,
                        frameUiOffset, inbetweens, useTint, tintColor)
                end
            end
        else
            -- Default to sustain.
            local h = 0
            while h < lenLeaves do
                h = h + 1
                local leaf <const> = leaves[h]
                local leafName <const> = leaf.name

                local i = 0
                while i < lenFrIdcs do
                    i = i + 1
                    local frIdxOld <const> = frIdcs[i]
                    local frIdxNew <const> = frIdxOld + (i - 1) * inbetweens
                    local cel <const> = leaf:cel(frIdxNew)
                    if cel then
                        local srcImg <const> = cel.image
                        local srcOpacity <const> = cel.opacity
                        local srcPos <const> = cel.position
                        local srcZIndex <const> = cel.zIndex

                        transact(strfmt("Sustain %d on %s", frIdxOld + frameUiOffset, leafName), function()
                            local j = 0
                            while j < inbetweens do
                                j = j + 1
                                local trgFrIdx <const> = frIdxNew + j
                                local trgCel <const> = activeSprite:newCel(
                                    leaf, trgFrIdx, srcImg, srcPos)
                                trgCel.opacity = srcOpacity
                                trgCel.zIndex = srcZIndex
                                if useTint then trgCel.color = tintColor end
                            end
                        end)
                    end -- End cel exists check.
                end     -- End old frames loop.
            end         -- End leaves loop.
        end             -- End fill type check.

        app.frame = frObjsAfter[newActiveFrIdx]
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