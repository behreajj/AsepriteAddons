dofile("../../support/aseutilities.lua")

local directOps <const> = { "BACKWARD", "BOTH", "FORWARD" }
local targets <const> = { "ACTIVE", "ALL", "RANGE", "TAG" }

local defaults <const> = {
    -- Also known as light table, ghost trail or echo in After Effects.
    -- Previous version:
    -- 67fe815aeb9f2f63c99216fab7c19971c6f6d19e
    target = "ALL",
    iterations = 3,
    maxIterations = 32,
    directions = "BACKWARD",
    useLoop = false,
    minAlpha = 64,
    maxAlpha = 128,
    useTint = true,
    preserveLight = true,
    mixTint = false,
    foreTint = Color { r = 0, g = 0, b = 255, a = 170 },
    backTint = Color { r = 255, g = 0, b = 0, a = 170 },
}

---Returns source image by reference if tint alpha is zero or less.
---@param srcImg Image
---@param tint Lab
---@param preserveLight boolean
---@return Image
local function tintImage(srcImg, tint, preserveLight)
    local tTint <const> = tint.alpha
    if tTint <= 0.0 then return srcImg end

    local uTint <const> = 1.0 - tTint
    local tl <const> = tTint * tint.l
    local ta <const> = tTint * tint.a
    local tb <const> = tTint * tint.b

    local srcBytes <const> = srcImg.bytes
    local srcSpec <const> = srcImg.spec
    local trgImg <const> = Image(srcSpec)

    ---@type table<integer, integer>
    local srcToTrg <const> = {}
    ---@type string[]
    local trgByteArr <const> = {}

    local wSrc <const> = srcSpec.width
    local hSrc <const> = srcSpec.height
    local area <const> = wSrc * hSrc

    local strsub <const> = string.sub
    local strunpack <const> = string.unpack
    local strpack <const> = string.pack
    local fromHex <const> = Rgb.fromHexAbgr32
    local toHex <const> = Rgb.toHex
    local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
    local labTosRgb <const> = ColorUtilities.srLab2TosRgb

    local i = 0
    while i < area do
        local i4 <const> = i * 4
        local srcAbgr32 <const> = strunpack("<I4", strsub(srcBytes,
            1 + i4, 4 + i4))
        local trgAbgr32 = 0
        if srcToTrg[srcAbgr32] then
            trgAbgr32 = srcToTrg[srcAbgr32]
        else
            local srcsRgb <const> = fromHex(srcAbgr32)
            if srcsRgb.a > 0.0 then
                local srcLab <const> = sRgbToLab(srcsRgb)
                local trgLab <const> = Lab.new(
                    preserveLight and srcLab.l or uTint * srcLab.l + tl,
                    uTint * srcLab.a + ta,
                    uTint * srcLab.b + tb,
                    srcLab.alpha)
                local trgsRgb <const> = labTosRgb(trgLab)
                trgAbgr32 = toHex(trgsRgb)
            end
            srcToTrg[srcAbgr32] = trgAbgr32
        end

        i = i + 1
        trgByteArr[i] = strpack("<I4", trgAbgr32)
    end

    trgImg.bytes = table.concat(trgByteArr)
    return trgImg
end

local dlg <const> = Dialog { title = "Bake Onion Skin" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "useLoop",
    label = "Loop:",
    selected = defaults.useLoop,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:slider {
    id = "iterations",
    label = "Iterations:",
    min = 1,
    max = defaults.maxIterations,
    value = defaults.iterations,
}

dlg:newrow { always = false }

dlg:slider {
    id = "minAlpha",
    label = "Min Alpha:",
    min = 0,
    max = 255,
    value = defaults.minAlpha
}

dlg:newrow { always = false }

dlg:slider {
    id = "maxAlpha",
    label = "Max Alpha:",
    min = 0,
    max = 255,
    value = defaults.maxAlpha
}

dlg:newrow { always = false }

dlg:combobox {
    id = "directions",
    label = "Direction:",
    option = defaults.direcions,
    options = directOps,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local md <const> = args.directions --[[@as string]]
        local useTint <const> = args.useTint --[[@as boolean]]
        if md == "FORWARD" then
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = false }
            dlg:modify { id = "mixTint", visible = false }
        elseif md == "BACKWARD" then
            dlg:modify { id = "foreTint", visible = false }
            dlg:modify { id = "backTint", visible = useTint }
            dlg:modify { id = "mixTint", visible = false }
        else
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = useTint }
            dlg:modify { id = "mixTint", visible = useTint }
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "useTint",
    label = "Tint:",
    selected = defaults.useTint,
    hexpand = false,
    onclick = function()
        local args <const> = dlg.data
        local md <const> = args.directions --[[@as string]]
        local useTint <const> = args.useTint --[[@as boolean]]

        dlg:modify { id = "preserveLight", visible = useTint }
        if md == "FORWARD" then
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = false }
            dlg:modify { id = "mixTint", visible = false }
        elseif md == "BACKWARD" then
            dlg:modify { id = "foreTint", visible = false }
            dlg:modify { id = "backTint", visible = useTint }
            dlg:modify { id = "mixTint", visible = false }
        else
            dlg:modify { id = "foreTint", visible = useTint }
            dlg:modify { id = "backTint", visible = useTint }
            dlg:modify { id = "mixTint", visible = useTint }
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "preserveLight",
    label = "Preserve:",
    text = "Light",
    selected = defaults.preserveLight,
    visible = defaults.useTint,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "mixTint",
    label = "Mix:",
    selected = defaults.mixTint,
    visible = defaults.useTint
        and defaults.direcions == "BOTH",
    hexpand = false,
}

dlg:newrow { always = false }

dlg:color {
    id = "backTint",
    label = "Back:",
    color = defaults.backTint,
    visible = defaults.useTint
        and (defaults.directions == "BACKWARD"
            or defaults.direcions == "BOTH")
}

dlg:newrow { always = false }

dlg:color {
    id = "foreTint",
    label = "Fore:",
    color = defaults.foreTint,
    visible = defaults.useTint
        and (defaults.directions == "FORWARD"
            or defaults.direcions == "BOTH")
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
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

        local spriteFrObjs <const> = activeSprite.frames
        local lenSpriteFrObjs <const> = #spriteFrObjs
        if lenSpriteFrObjs <= 1 then
            app.alert {
                title = "Error",
                text = "The sprite contains only one frame."
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

        if srcLayer.isBackground then
            app.alert {
                title = "Error",
                text = "Background layer cannot be the source."
            }
            return
        end

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorSpace <const> = spriteSpec.colorSpace

        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local iterations <const> = args.iterations
            or defaults.iterations --[[@as integer]]
        local directions <const> = args.directions
            or defaults.directions --[[@as string]]
        local minAlpha <const> = args.minAlpha
            or defaults.minAlpha --[[@as integer]]
        local maxAlpha <const> = args.maxAlpha
            or defaults.maxAlpha --[[@as integer]]
        local useLoop <const> = args.useLoop --[[@as boolean]]
        local useTint <const> = args.useTint --[[@as boolean]]
        local preserveLight <const> = args.preserveLight --[[@as boolean]]
        local backTint <const> = args.backTint --[[@as Color]]
        local foreTint <const> = args.foreTint --[[@as Color]]
        local mixTint <const> = args.mixTint --[[@as boolean]]

        -- Fill frames.
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target, false))
        local lenFrIdcs = #frIdcs
        if lenFrIdcs <= 0 then
            app.alert {
                title = "Error",
                text = "No frames were selected."
            }
            return
        end

        -- Find directions.
        local useBoth <const> = directions == "BOTH"
        local lookForward <const> = useBoth or directions == "FORWARD"
        local lookBackward <const> = useBoth or directions == "BACKWARD"

        -- Verify arguments.
        local minAlphaVerif <const> = math.min(minAlpha, maxAlpha)
        local maxAlphaVerif <const> = math.max(minAlpha, maxAlpha)
        local itrs <const> = math.min(iterations, lenSpriteFrObjs)
        local mixTintVerif <const> = mixTint and useBoth

        -- Cache methods used in for loop.
        local floor <const> = math.floor
        local createSpec <const> = AseUtilities.createSpec
        local flatToImage <const> = AseUtilities.flatToImage
        local transact <const> = app.transaction
        local strfmt <const> = string.format

        ---@type table<integer, table>
        local packets <const> = {}
        ---@type {xtl: integer, ytl: integer, xbr: integer, ybr: integer}[]
        local extremaBack <const> = {}
        ---@type {xtl: integer, ytl: integer, xbr: integer, ybr: integer}[]
        local extremaFore <const> = {}

        local includeLocked <const> = true
        local includeHidden <const> = not srcLayer.isVisible
        local includeTiles <const> = true
        local includeBkg <const> = false

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local srcFrIdx <const> = frIdcs[i]

            local xMnB, yMnB = 2147483647, 2147483647
            local xMxB, yMxB = -2147483648, -2147483648
            local xMnF, yMnF = 2147483647, 2147483647
            local xMxF, yMxF = -2147483648, -2147483648

            local j = 0
            while j < itrs do
                j = j + 1

                local frIdxBack = srcFrIdx - j
                local frIdxFore = srcFrIdx + j
                if useLoop then
                    -- TODO: What if by use loop, the user means local to a tag,
                    -- you'd have to make min frame, max frame, and wrap length
                    -- abstract, then set the to sprite by default.
                    frIdxBack = 1 + (frIdxBack - 1) % lenSpriteFrObjs
                    frIdxFore = 1 + (frIdxFore - 1) % lenSpriteFrObjs
                end

                if lookBackward and frIdxBack >= 1 then
                    local pack <const> = packets[frIdxBack]
                    if pack then
                        if pack.xtl < xMnB then xMnB = pack.xtl end
                        if pack.ytl < yMnB then yMnB = pack.ytl end
                        if pack.xbr > xMxB then xMxB = pack.xbr end
                        if pack.ybr > yMxB then yMxB = pack.ybr end
                    else
                        local isValid <const>, srcImg <const>, xtl <const>,
                        ytl <const>, celOpacity <const>,
                        _ <const> = flatToImage(
                            srcLayer, frIdxBack, colorMode, colorSpace,
                            alphaIndex, includeLocked, includeHidden,
                            includeTiles, includeBkg)

                        if isValid then
                            local xbr <const> = xtl + srcImg.width - 1
                            local ybr <const> = ytl + srcImg.height - 1
                            if xtl < xMnB then xMnB = xtl end
                            if ytl < yMnB then yMnB = ytl end
                            if xbr > xMxB then xMxB = xbr end
                            if ybr > yMxB then yMxB = ybr end

                            packets[frIdxBack] = {
                                xtl = xtl,
                                ytl = ytl,
                                xbr = xbr,
                                ybr = ybr,
                                srcImg = srcImg,
                                celOpacity = celOpacity,
                            }
                        end -- End flat is valid.
                    end     -- End packet exists.
                end         -- End look backward.

                if lookForward and frIdxFore <= lenSpriteFrObjs then
                    local pack <const> = packets[frIdxFore]
                    if pack then
                        if pack.xtl < xMnF then xMnF = pack.xtl end
                        if pack.ytl < yMnF then yMnF = pack.ytl end
                        if pack.xbr > xMxF then xMxF = pack.xbr end
                        if pack.ybr > yMxF then yMxF = pack.ybr end
                    else
                        local isValid <const>, srcImg <const>, xtl <const>,
                        ytl <const>, celOpacity <const>,
                        _ <const> = flatToImage(
                            srcLayer, frIdxFore, colorMode, colorSpace,
                            alphaIndex, includeLocked, includeHidden,
                            includeTiles, includeBkg)

                        if isValid then
                            local xbr <const> = xtl + srcImg.width - 1
                            local ybr <const> = ytl + srcImg.height - 1
                            if xtl < xMnF then xMnF = xtl end
                            if ytl < yMnF then yMnF = ytl end
                            if xbr > xMxF then xMxF = xbr end
                            if ybr > yMxF then yMxF = ybr end

                            packets[frIdxFore] = {
                                xtl = xtl,
                                ytl = ytl,
                                xbr = xbr,
                                ybr = ybr,
                                srcImg = srcImg,
                                celOpacity = celOpacity,
                            }
                        end -- End flat is valid.
                    end     -- End packet exists.
                end         -- End look forward.
            end             -- End iterations loop.

            extremaBack[i] = { xtl = xMnB, ytl = yMnB, xbr = xMxB, ybr = yMxB }
            extremaFore[i] = { xtl = xMnF, ytl = yMnF, xbr = xMxF, ybr = yMxF }
        end -- End chosen frames loop.

        local foreLayer = nil
        local backLayer = nil
        local onionLayer <const> = activeSprite:newGroup()

        if lookBackward then backLayer = activeSprite:newLayer() end
        if lookForward then foreLayer = activeSprite:newLayer() end

        app.transaction("Set Layer Props", function()
            if backLayer then
                backLayer.name = "Backward"
                backLayer.parent = onionLayer
            end

            if foreLayer then
                foreLayer.name = "Forward"
                foreLayer.parent = onionLayer
            end

            onionLayer.name = srcLayer.name .. " Onion"
            onionLayer.parent = srcLayer.parent
            onionLayer.stackIndex = srcLayer.stackIndex
            onionLayer.isCollapsed = true
        end)

        local toFac <const> = itrs > 1
            and 1.0 / (itrs - 1.0)
            or 1.0
        -- Full range is (itr * 2 + 1) but the plus one is canceled out by
        -- the minus one, as above.
        local toFac2 <const> = 0.5 / itrs
        local minAlpha01 <const> = minAlphaVerif / 255.0
        local maxAlpha01 <const> = maxAlphaVerif / 255.0
        local blendMode <const> = BlendMode.NORMAL

        local backClr <const> = AseUtilities.aseColorToRgb(backTint)
        local foreClr <const> = AseUtilities.aseColorToRgb(foreTint)
        local backLab <const> = ColorUtilities.sRgbToSrLab2(backClr)
        local foreLab <const> = ColorUtilities.sRgbToSrLab2(foreClr)

        -- Get frame UI offset.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local j = 0
        while j < lenFrIdcs do
            j = j + 1
            local srcFrIdx <const> = frIdcs[j]
            local uiFrIdx <const> = srcFrIdx + frameUiOffset

            if backLayer then
                transact(strfmt("Onion Back %d", uiFrIdx), function()
                    local celBounds <const> = extremaBack[j]

                    local xtlTrg <const> = celBounds.xtl
                    local ytlTrg <const> = celBounds.ytl
                    local wTrg <const> = 1 + celBounds.xbr - xtlTrg
                    local hTrg <const> = 1 + celBounds.ybr - ytlTrg

                    if wTrg > 0 and hTrg > 0 then
                        local trgImg <const> = Image(createSpec(wTrg, hTrg,
                            colorMode, colorSpace, alphaIndex))

                        local k = itrs + 1
                        while k > 1 do
                            k = k - 1

                            local frIdxBack = srcFrIdx - k
                            if useLoop then
                                frIdxBack = 1 + (frIdxBack - 1) % lenSpriteFrObjs
                            end

                            local pack <const> = packets[frIdxBack]
                            if pack then
                                local srcImg <const> = pack.srcImg
                                local writeImg = srcImg
                                if useTint then
                                    local trgLab = backLab
                                    if mixTintVerif then
                                        local tm <const> = (itrs - k) * toFac2
                                        trgLab = Lab.mix(backLab, foreLab, tm)
                                    end
                                    writeImg = tintImage(srcImg, trgLab, preserveLight)
                                end

                                local t <const> = (k - 1) * toFac
                                local a01 <const> = (pack.celOpacity / 255.0)
                                    * ((1.0 - t) * maxAlpha01 + t * minAlpha01)
                                local a8 <const> = floor(a01 * 255.0 + 0.5)
                                if a8 > 0 then
                                    trgImg:drawImage(writeImg, Point(
                                            pack.xtl - xtlTrg,
                                            pack.ytl - ytlTrg),
                                        a8, blendMode)
                                end -- End alpha is valid.
                            end     -- End packet exists.
                        end         -- End iterations loop.

                        activeSprite:newCel(backLayer, srcFrIdx, trgImg,
                            Point(xtlTrg, ytlTrg))
                    end -- End valid dimensions.
                end)    -- End transaction.
            end         -- End look backward.

            if foreLayer then
                transact(strfmt("Onion Fore %d", uiFrIdx), function()
                    local celBounds <const> = extremaFore[j]

                    local xtlTrg <const> = celBounds.xtl
                    local ytlTrg <const> = celBounds.ytl
                    local wTrg <const> = 1 + celBounds.xbr - xtlTrg
                    local hTrg <const> = 1 + celBounds.ybr - ytlTrg

                    if wTrg > 0 and hTrg > 0 then
                        local trgImg <const> = Image(createSpec(wTrg, hTrg,
                            colorMode, colorSpace, alphaIndex))

                        local k = 0
                        while k < itrs do
                            k = k + 1

                            local frIdxFore = srcFrIdx + k
                            if useLoop then
                                frIdxFore = 1 + (frIdxFore - 1) % lenSpriteFrObjs
                            end

                            local pack <const> = packets[frIdxFore]
                            if pack then
                                local srcImg <const> = pack.srcImg
                                local writeImg = srcImg
                                if useTint then
                                    local trgLab = foreLab
                                    if mixTintVerif then
                                        local tm <const> = (itrs + k) * toFac2
                                        trgLab = Lab.mix(backLab, foreLab, tm)
                                    end
                                    writeImg = tintImage(srcImg, trgLab, preserveLight)
                                end

                                local t <const> = (k - 1) * toFac
                                local a01 <const> = (pack.celOpacity / 255.0)
                                    * ((1.0 - t) * maxAlpha01 + t * minAlpha01)
                                local a8 <const> = floor(a01 * 255.0 + 0.5)
                                if a8 > 0 then
                                    trgImg:drawImage(writeImg, Point(
                                            pack.xtl - xtlTrg,
                                            pack.ytl - ytlTrg),
                                        a8, blendMode)
                                end -- End alpha is valid.
                            end     -- End packet exists.
                        end         -- End iterations loop.

                        activeSprite:newCel(foreLayer, srcFrIdx, trgImg,
                            Point(xtlTrg, ytlTrg))
                    end -- End valid dimensions.
                end)    -- End transaction.
            end         -- End look forward.
        end             -- End write frames loop.

        app.layer = srcLayer
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