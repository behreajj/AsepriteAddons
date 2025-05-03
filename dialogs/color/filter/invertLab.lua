dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }

local defaults <const> = {
    target = "ACTIVE",
    lInvert = 100,
    aInvert = 100,
    bInvert = 100,
    tInvert = 0,
    ignoreSrcMask = false,
    fixZeroAlpha = true,
    useTrim = false,
}

local dlg <const> = Dialog { title = "Invert Lab" }

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:slider {
    id = "lInvert",
    label = "L:",
    focus = false,
    min = 0,
    max = 100,
    value = defaults.lInvert
}

dlg:newrow { always = false }

dlg:slider {
    id = "aInvert",
    label = "A:",
    focus = false,
    min = 0,
    max = 100,
    value = defaults.aInvert
}

dlg:newrow { always = false }

dlg:slider {
    id = "bInvert",
    label = "B:",
    focus = false,
    min = 0,
    max = 100,
    value = defaults.bInvert
}

dlg:newrow { always = false }

dlg:slider {
    id = "tInvert",
    label = "Alpha:",
    focus = false,
    min = 0,
    max = 100,
    value = defaults.tInvert,
}

dlg:newrow { always = false }

dlg:check {
    id = "ignoreSrcMask",
    text = "Ignore Mask",
    selected = defaults.ignoreSrcMask,
}

dlg:check {
    id = "fixZeroAlpha",
    text = "Fix Zero",
    selected = defaults.fixZeroAlpha,
}

dlg:newrow { always = false }

dlg:check {
    id = "useTrim",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.useTrim,
    visible = true,
    focus = false
}

dlg:newrow { always = false }

dlg:button {
    id = "adjustButton",
    text = "&OK",
    focus = true,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
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
        local lInverti <const> = args.lInvert
            or defaults.lInvert --[[@as integer]]
        local aInverti <const> = args.aInvert
            or defaults.aInvert --[[@as integer]]
        local bInverti <const> = args.bInvert
            or defaults.bInvert --[[@as integer]]
        local tInverti <const> = args.tInvert
            or defaults.tInvert --[[@as integer]]
        local fixZeroAlpha <const> = args.fixZeroAlpha --[[@as boolean]]
        local ignoreSrcMask <const> = args.ignoreSrcMask --[[@as boolean]]
        local useTrim <const> = args.useTrim --[[@as boolean]]

        if lInverti == 0
            and aInverti == 0
            and bInverti == 0
            and tInverti == 0 then
            return
        end

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrIdcs <const> = #frIdcs

        local srcLayer = site.layer --[[@as Layer]]
        local removeSrcLayer = false

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
            removeSrcLayer = true
        else
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

            if srcLayer.isGroup then
                app.transaction("Flatten Group", function()
                    srcLayer = AseUtilities.flattenGroup(
                        activeSprite, srcLayer, frIdcs)
                    removeSrcLayer = true
                end)
            end
        end

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        local lInv <const> = lInverti * 0.01
        local aInv <const> = aInverti * 0.01
        local bInv <const> = bInverti * 0.01
        local tInv <const> = tInverti * 0.01

        local lInv100 <const> = lInv * 100.0
        local lInv2 <const> = lInv + lInv
        local aInv2 <const> = aInv + aInv
        local bInv2 <const> = bInv + bInv
        local tInv2 <const> = tInv + tInv

        local blitToCanvas <const> = tInverti > 0 or ignoreSrcMask
        local changeSrcZero <const> = not ignoreSrcMask
        local changeTrgZero <const> = not fixZeroAlpha

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local trimImageAlpha <const> = AseUtilities.trimImageAlpha
        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local labnew <const> = Lab.new
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat

        app.transaction("Invert Layer", function()
            local trgLayer <const> = activeSprite:newLayer()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s Inverted", srcLayerName)
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            -- Do not copy blend mode, it only confuses things.

            ---@type table<integer, integer>
            local srcToTrg <const> = {}

            local i = 0
            while i < lenFrIdcs do
                i = i + 1
                local frIdx <const> = frIdcs[i]
                local srcCel <const> = srcLayer:cel(frIdx)
                if srcCel then
                    local srcImg = srcCel.image

                    if isTileMap then
                        srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                    end

                    local srcPos <const> = srcCel.position
                    local xtlSrc = srcPos.x
                    local ytlSrc = srcPos.y

                    if blitToCanvas then
                        local blit <const> = Image(activeSpec)
                        blit:drawImage(srcImg, srcPos, 255, BlendMode.SRC)
                        srcImg = blit
                        xtlSrc = 0
                        ytlSrc = 0
                    end

                    local srcBytes <const> = srcImg.bytes
                    local srcSpec <const> = srcImg.spec
                    local wSrc <const> = srcSpec.width
                    local hSrc <const> = srcSpec.height
                    local area <const> = wSrc * hSrc

                    ---@type string[]
                    local trgByteArr <const> = {}

                    local j = 0
                    while j < area do
                        local j4 <const> = j * 4
                        local srcAbgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local trgAbgr32 = 0

                        if srcToTrg[srcAbgr32] then
                            trgAbgr32 = srcToTrg[srcAbgr32]
                        else
                            local srcSrgb <const> = fromHex(srcAbgr32)
                            local tSrc <const> = srcSrgb.a
                            if changeSrcZero or tSrc > 0.0 then
                                -- (1 - t) * a + t * (1 - a)
                                -- a - ta + t - ta
                                -- a + t - 2ta
                                local tTrg <const> = tSrc + tInv - tInv2 * tSrc

                                if changeTrgZero or tTrg > 0.0 then
                                    local srcLab <const> = sRgbToLab(srcSrgb)
                                    local lSrc <const> = srcLab.l
                                    local aSrc <const> = srcLab.a
                                    local bSrc <const> = srcLab.b

                                    -- (1 - t) * l + t * (100 - l)
                                    -- l - tl + t100 - tl
                                    -- l + t100 - 2tl
                                    local lTrg <const> = lSrc + lInv100 - lInv2 * lSrc

                                    -- (1 - t) * a + t * -a
                                    -- a - ta - ta
                                    -- a - 2ta
                                    local aTrg <const> = aSrc - aInv2 * aSrc
                                    local bTrg <const> = bSrc - bInv2 * bSrc
                                    local trg <const> = labnew(lTrg, aTrg, bTrg, tTrg)

                                    trgAbgr32 = toHex(labTosRgb(trg))
                                end
                            end
                            srcToTrg[srcAbgr32] = trgAbgr32
                        end

                        j = j + 1
                        trgByteArr[j] = strpack("<I4", trgAbgr32)
                    end -- End pixels loop.

                    local trgImg = Image(srcSpec)
                    trgImg.bytes = tconcat(trgByteArr)

                    local xtlTrg = xtlSrc
                    local ytlTrg = ytlSrc
                    if useTrim then
                        local alphaIndex <const> = srcSpec.transparentColor
                        local trimmed <const>,
                        xtlTrm <const>,
                        ytlTrm <const> = trimImageAlpha(trgImg, 0, alphaIndex)
                        xtlTrg = xtlTrg + xtlTrm
                        ytlTrg = ytlTrg + ytlTrm
                        trgImg = trimmed
                    end

                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, Point(xtlTrg, ytlTrg))
                    trgCel.opacity = srcCel.opacity
                end -- End source cel exists.
            end     -- End frames loop.

            app.layer = trgLayer
        end) -- End transaction.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
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