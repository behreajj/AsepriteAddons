local targets <const> = { "ALL", "AFTER", "BEFORE" }
local fillOpts <const> = { "CROSS_FADE", "EMPTY", "SUSTAIN" }

local defaults <const> = {
    target = "ALL",
    isLoop = false,
    fillOpt = "SUSTAIN",
    inbetweens = 1
}

local dlg <const> = Dialog { title = "Expand Frames" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]
        local isAll <const> = target == "ALL"
        dlg:modify { id = "isLoop", visible = isAll }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "isLoop",
    label = "Loop:",
    selected = defaults.isLoop,
    visible = defaults.target == "ALL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "inbetweens",
    label = "Expand:",
    min = 1,
    max = 64,
    value = defaults.inbetweens
}

dlg:newrow { always = false }

dlg:combobox {
    id = "fillOpt",
    label = "Fill:",
    option = defaults.fillOpt,
    options = fillOpts,
    onchange = function()
        local args <const> = dlg.data
        local fillOpt <const> = args.fillOpt
        local notEmpty <const> = fillOpt ~= "EMPTY"
        dlg:modify { id = "tilemapWarn", visible = notEmpty }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "tilemapWarn",
    label = "Note:",
    text = "Tile maps excluded.",
    visible = defaults.fillOpt ~= "EMPTY"
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

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local isLoop <const> = args.isLoop --[[@as boolean]]
        local inbetweens <const> = args.inbetweens
            or defaults.inbetweens --[[@as integer]]
        local fillOpt <const> = args.fillOpt
            or defaults.fillOpt --[[@as string]]

        local isAll <const> = target == "ALL"
        local isLoopVerif <const> = isLoop and isAll
        local frObjsBefore <const> = activeSprite.frames
        local lenFrObjsBefore <const> = #frObjsBefore

        local oldActFrObj <const> = app.frame --[[@as Frame]]
        local oldActFrIdx = 1
        if oldActFrObj then
            oldActFrIdx = oldActFrObj.frameNumber
        end

        ---@type integer[]
        local frIdcs = {}
        if target == "BEFORE" then
            if not oldActFrObj then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            if oldActFrObj.frameNumber <= 1 then
                app.alert {
                    title = "Error",
                    text = "There is no prior frame."
                }
                return
            end

            frIdcs[1] = oldActFrIdx - 1
            frIdcs[2] = oldActFrIdx
        elseif target == "AFTER" then
            if not oldActFrObj then
                app.alert {
                    title = "Error",
                    text = "There is no active frame."
                }
                return
            end

            if oldActFrObj.frameNumber >= lenFrObjsBefore then
                app.alert {
                    title = "Error",
                    text = "There is no next frame."
                }
                return
            end

            frIdcs[1] = oldActFrIdx
            frIdcs[2] = oldActFrIdx + 1
        else
            frIdcs = AseUtilities.frameObjsToIdcs(frObjsBefore)
        end

        ---@type table<integer, integer>
        local frIdxDict <const> = {}
        local jToFac <const> = 1.0 / (inbetweens + 1.0)
        local lenChosenFrames = #frIdcs

        app.transaction("Create New Frames", function()
            local i = lenChosenFrames + 1
            while i > 2 do
                i = i - 1

                local frIdxNext <const> = frIdcs[i]
                local frObjNext <const> = frObjsBefore[frIdxNext]

                local frIdxPrev <const> = frIdcs[i - 1]
                local frObjPrev <const> = frObjsBefore[frIdxPrev]

                frIdxDict[frIdxPrev] = frIdxPrev
                frIdxDict[frIdxNext] = frIdxNext + inbetweens * (i - 1)

                local durNext <const> = frObjNext.duration
                local durPrev <const> = frObjPrev.duration

                local j = inbetweens + 1
                while j > 1 do
                    j = j - 1
                    local jFac <const> = j * jToFac
                    local dur <const> = (1.0 - jFac) * durPrev + jFac * durNext
                    -- print(string.format("%.3f: %.3f", jFac, dur))
                    local btwn <const> = activeSprite:newEmptyFrame(frIdxNext)
                    btwn.duration = dur
                end
            end

            if isLoopVerif then
                local durPrev <const> = activeSprite.frames[#activeSprite.frames].duration
                local durNext <const> = activeSprite.frames[1].duration

                local j = 0
                while j < inbetweens do
                    j = j + 1
                    local jFac <const> = j * jToFac
                    local dur <const> = (1.0 - jFac) * durPrev + jFac * durNext
                    local btwn <const> = activeSprite:newEmptyFrame()
                    btwn.duration = dur
                end

                lenChosenFrames = lenChosenFrames + 1
                frIdcs[#frIdcs + 1] = 1
            end
        end)

        if fillOpt ~= "EMPTY" then
            local useCross <const> = fillOpt == "CROSS_FADE"
            local useSustain <const> = fillOpt == "SUSTAIN"
            local tlHidden <const> = not app.preferences.general.visible_timeline
            if tlHidden then
                app.command.Timeline { open = true }
            end

            local spriteSpec <const> = activeSprite.spec
            local colorMode <const> = spriteSpec.colorMode
            if useCross and colorMode ~= ColorMode.RGB then
                app.alert {
                    title = "Error",
                    text = "Only RGB color mode is supported."
                }
                return
            end

            local floor <const> = math.floor
            local max <const> = math.max
            local min <const> = math.min
            local tconcat <const> = table.concat
            local strpack <const> = string.pack
            local strfmt <const> = string.format
            local round <const> = Utilities.round
            local createSpec <const> = AseUtilities.createSpec
            local getPixels <const> = AseUtilities.getPixels
            local clrnew <const> = Clr.new
            local mixSrLab2 <const> = Clr.mixSrLab2
            local transact <const> = app.transaction

            local packZero <const> = strpack("B B B B", 0, 0, 0, 0)
            local colorSpace <const> = spriteSpec.colorSpace
            local alphaIndex <const> = spriteSpec.transparentColor

            local leaves = AseUtilities.getLayerHierarchy(activeSprite,
                true, true, false, true)
            local lenLeaves = #leaves
            local h = 0
            while h < lenLeaves do
                h = h + 1
                local leaf <const> = leaves[h]

                local i = lenChosenFrames + 1
                while i > 2 do
                    i = i - 1

                    local frIdxNextBefore <const> = frIdcs[i]
                    local frIdxNextAfter <const> = frIdxDict[frIdxNextBefore]
                    local celNext <const> = leaf:cel(frIdxNextAfter)

                    -- print(strfmt("frIdxNext: %d, %d", frIdxNextBefore, frIdxNextAfter))

                    local frIdxPrevBefore <const> = frIdcs[i - 1]
                    local frIdxPrevAfter <const> = frIdxDict[frIdxPrevBefore]
                    local celPrev <const> = leaf:cel(frIdxPrevAfter)

                    -- print(strfmt("frIdxPrev: %d, %d", frIdxPrevBefore, frIdxPrevAfter))

                    if celNext and celPrev then
                        local imgNext <const> = celNext.image
                        local idNext <const> = imgNext.id

                        local imgPrev <const> = celPrev.image
                        local idPrev <const> = imgPrev.id

                        -- print(strfmt("idNext: %d, idPrev: %d", idNext, idPrev))

                        if useSustain or idNext == idPrev then
                            local opacPrev <const> = celPrev.opacity
                            local posPrev <const> = celPrev.position
                            local zIdxPrev <const> = celPrev.zIndex

                            transact(strfmt("Sustain %d to %d",
                                frIdxPrevAfter + frameUiOffset,
                                frIdxNextAfter + frameUiOffset), function()
                                local j = frIdxPrevAfter
                                while j < frIdxNextAfter - 1 do
                                    j = j + 1
                                    local celSust <const> = activeSprite:newCel(
                                        leaf, j, imgPrev, posPrev)
                                    celSust.opacity = opacPrev
                                    celSust.zIndex = zIdxPrev
                                end
                            end)
                        else
                            local wNext <const> = imgNext.width
                            local hNext <const> = imgNext.height
                            local bytesNext <const> = getPixels(imgNext)

                            local posNext <const> = celNext.position
                            local xtlNext <const> = posNext.x
                            local ytlNext <const> = posNext.y
                            local xbrNext <const> = xtlNext + wNext - 1
                            local ybrNext <const> = ytlNext + hNext - 1

                            local wPrev <const> = imgPrev.width
                            local hPrev <const> = imgPrev.height
                            local bytesPrev <const> = getPixels(imgPrev)

                            local posPrev <const> = celPrev.position
                            local xtlPrev <const> = posPrev.x
                            local ytlPrev <const> = posPrev.y
                            local xbrPrev <const> = xtlPrev + wPrev - 1
                            local ybrPrev <const> = ytlPrev + hPrev - 1

                            local xtlComp <const> = min(xtlNext, xtlPrev)
                            local ytlComp <const> = min(ytlNext, ytlPrev)
                            local xbrComp <const> = max(xbrNext, xbrPrev)
                            local ybrComp <const> = max(ybrNext, ybrPrev)

                            if xtlComp < xbrComp and ytlComp < ybrComp then
                                local xtlDiffNext <const> = xtlComp - xtlNext
                                local ytlDiffNext <const> = ytlComp - ytlNext
                                local xtlDiffPrev <const> = xtlComp - xtlPrev
                                local ytlDiffPrev <const> = ytlComp - ytlPrev

                                local pointComp <const> = Point(xtlComp, ytlComp)
                                local wComp <const> = 1 + xbrComp - xtlComp
                                local hComp <const> = 1 + ybrComp - ytlComp
                                local flatLenComp <const> = wComp * hComp
                                local specComp <const> = createSpec(
                                    wComp, hComp,
                                    colorMode, colorSpace, alphaIndex)

                                local opacNext01 <const> = celNext.opacity / 255.0
                                local opacPrev01 <const> = celPrev.opacity / 255.0

                                local zIdxNext <const> = celNext.zIndex
                                local zIdxPrev <const> = celPrev.zIndex

                                transact(strfmt("Cross Fade %d to %d",
                                    frIdxPrevAfter, frIdxNextAfter), function()
                                    local j = inbetweens + 1
                                    while j > 1 do
                                        j = j - 1

                                        local t <const> = j * jToFac
                                        -- t = t * t * (3.0 - (t + t))
                                        local u <const> = 1.0 - t

                                        ---@type string[]
                                        local bytesComp <const> = {}
                                        local k = 0
                                        while k < flatLenComp do
                                            local xComp <const> = k % wComp
                                            local yComp <const> = k // wComp

                                            local rComp = 0
                                            local gComp = 0
                                            local bComp = 0
                                            local aComp = 0

                                            local rNext = 0
                                            local gNext = 0
                                            local bNext = 0
                                            local aNext = 0

                                            local xNext <const> = xComp + xtlDiffNext
                                            local yNext <const> = yComp + ytlDiffNext
                                            if yNext >= 0 and yNext < hNext
                                                and xNext >= 0 and xNext < wNext then
                                                local kNext <const> = yNext * wNext + xNext
                                                local kn4 <const> = kNext * 4

                                                rNext = bytesNext[1 + kn4]
                                                gNext = bytesNext[2 + kn4]
                                                bNext = bytesNext[3 + kn4]
                                                aNext = bytesNext[4 + kn4]
                                            end

                                            local rPrev = 0
                                            local gPrev = 0
                                            local bPrev = 0
                                            local aPrev = 0

                                            local xPrev <const> = xComp + xtlDiffPrev
                                            local yPrev <const> = yComp + ytlDiffPrev
                                            if yPrev >= 0 and yPrev < hPrev
                                                and xPrev >= 0 and xPrev < wPrev then
                                                local kPrev <const> = yPrev * wPrev + xPrev
                                                local kp4 <const> = kPrev * 4

                                                rPrev = bytesPrev[1 + kp4]
                                                gPrev = bytesPrev[2 + kp4]
                                                bPrev = bytesPrev[3 + kp4]
                                                aPrev = bytesPrev[4 + kp4]
                                            end

                                            local opacNext <const> = aNext > 0
                                            local opacPrev <const> = aPrev > 0
                                            local packedStr = packZero
                                            if opacNext or opacPrev then
                                                if not opacNext then
                                                    rNext = rPrev
                                                    gNext = gPrev
                                                    bNext = bPrev
                                                end

                                                if not opacPrev then
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

                                        local imageComp <const> = Image(specComp)
                                        imageComp.bytes = tconcat(bytesComp)

                                        local opacComp01 <const> = u * opacPrev01 + t * opacNext01
                                        local opacComp <const> = floor(opacComp01 * 255.0 + 0.5)
                                        local zIdxComp <const> = round(u * zIdxPrev + t * zIdxNext)

                                        local frIdxComp <const> = frIdxPrevAfter + j
                                        local celComp <const> = activeSprite:newCel(
                                            leaf, frIdxComp, imageComp, pointComp)
                                        celComp.opacity = opacComp
                                        celComp.zIndex = zIdxComp
                                    end -- End inbetweens loop.
                                end)    -- End cross fades transaction.
                            end         -- Check valid composite bounds.
                        end             -- End equal image IDs check.
                    end                 -- End previous and next cel exist.
                end                     -- End chosen frames loop.

                if isAll and useSustain and isLoopVerif then
                    -- In loop case, the first frame will be appended to the
                    -- chosen frames, so the last sprite frame is one less.
                    local lastIdx <const> = lenChosenFrames - 1
                    local frIdxPrevBefore <const> = frIdcs[lastIdx]
                    local frIdxPrevAfter <const> = frIdxDict[frIdxPrevBefore]
                    local frIdxNextAfter <const> = #activeSprite.frames

                    local celPrev <const> = leaf:cel(frIdxPrevAfter)
                    if celPrev then
                        local imgPrev <const> = celPrev.image
                        local opacPrev <const> = celPrev.opacity
                        local posPrev <const> = celPrev.position
                        local zIdxPrev <const> = celPrev.zIndex

                        transact(strfmt("Sustain %d to %d",
                            frIdxPrevAfter + frameUiOffset,
                            frIdxNextAfter + frameUiOffset), function()
                            local j = frIdxPrevAfter
                            while j < frIdxNextAfter do
                                j = j + 1
                                local celSust <const> = activeSprite:newCel(
                                    leaf, j, imgPrev, posPrev)
                                celSust.opacity = opacPrev
                                celSust.zIndex = zIdxPrev
                            end
                        end)
                    end
                end -- End sustain link check.
            end     -- End leaf layers loop.

            app.range:clear()
            if tlHidden then
                app.command.Timeline { close = true }
            end
        end

        local frObjsAfter <const> = activeSprite.frames
        if oldActFrObj then
            app.frame = frObjsAfter[frIdxDict[oldActFrIdx]]
        else
            app.frame = frObjsAfter[1]
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