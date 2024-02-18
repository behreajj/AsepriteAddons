dofile("../../support/gradientutilities.lua")

local alphaComps <const> = { "BLEND", "MAX", "MIN", "OVER", "UNDER" }
local labComps <const> = { "AB", "CHROMA", "COLOR", "LAB", "LCH", "LIGHTNESS", "HUE" }
local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    alphaComp = "BLEND",
    labComp = "LAB",
    hueMix = "CCW",
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
    pullFocus = false
}

local dlg <const> = Dialog { title = "Blend LAB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "labComp",
    label = "Blend:",
    option = defaults.labComp,
    options = labComps,
    onchange = function()
        local args <const> = dlg.data
        local labComp <const> = args.labComp --[[@as string]]
        local isHue <const> = labComp == "HUE"
        local isColor <const> = labComp == "COLOR"
        local isLch <const> = labComp == "LCH"
        dlg:modify { id = "huePreset", visible = isHue or isColor or isLch }
    end
}

dlg:combobox {
    id = "huePreset",
    label = "Easing:",
    option = defaults.hueMix,
    options = GradientUtilities.HUE_EASING_PRESETS,
    visible = defaults.labComp == "HUE"
        or defaults.labComp == "COLOR"
        or defaults.labComp == "LCH"
}

dlg:combobox {
    id = "alphaComp",
    label = "Alpha:",
    option = defaults.alphaComp,
    options = alphaComps
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delOver",
    label = "Over:",
    text = "Mask",
    option = defaults.delOver,
    options = delOptions
}

dlg:combobox {
    id = "delUnder",
    label = "Under:",
    text = "Source",
    option = defaults.delUnder,
    options = delOptions
}

dlg:newrow { always = false }

dlg:label {
    id = "clarify",
    label = "Note:",
    text = "Select the over layer."
}

dlg:newrow { always = false }

dlg:check {
    id = "printElapsed",
    label = "Print:",
    text = "Diagnostic",
    selected = defaults.printElapsed
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local args <const> = dlg.data
        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        local startTime = 0
        local endTime = 0
        local elapsed = 0
        if printElapsed then
            startTime = os.clock()
        end

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
        local spriteColorMode <const> = spriteSpec.colorMode
        if spriteColorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local bLayer <const> = site.layer
        if not bLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        local overIndex <const> = bLayer.stackIndex
        if overIndex < 2 then
            app.alert {
                title = "Error",
                text = "There must be a layer beneath the active layer."
            }
            return
        end

        -- A parent may be a sprite or a group layer.
        -- Over and under layer should belong to same group.
        local parent <const> = bLayer.parent
        local underIndex <const> = overIndex - 1
        local aLayer <const> = parent.layers[underIndex]

        if bLayer.isGroup or aLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        if bLayer.isReference or aLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        --Unpack the rest of sprite spec.
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorSpace <const> = spriteSpec.colorSpace
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height

        -- Cache global functions used in loop.
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local strbyte <const> = string.byte
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec

        local clrNew <const> = Clr.new
        local sRgbToSrLab2 <const> = Clr.sRgbToSrLab2
        local srLab2TosRgb <const> = Clr.srLab2TosRgb
        local srLab2ToSrLch <const> = Clr.srLab2ToSrLch
        local srLchToSrLab2 <const> = Clr.srLchToSrLab2

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local labComp <const> = args.labComp
            or defaults.labComp --[[@as string]]
        local huePreset <const> = args.huePreset
            or defaults.hueMix --[[@as string]]
        local alphaComp <const> = args.alphaComp
            or defaults.alphaComp --[[@as string]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        -- print(string.format("alphaComp: %s", alphaComp))
        local useAlphaMax <const> = alphaComp == "MAX"
        local useAlphaMin <const> = alphaComp == "MIN"
        local useAlphaOver <const> = alphaComp == "OVER"
        local useAlphaUnder <const> = alphaComp == "UNDER"

        -- print(string.format("labComp: %s", labComp))
        local useLight <const> = labComp == "LIGHTNESS"
        local useAb <const> = labComp == "AB"
        -- local useAdd <const> = labComp == "ADD"
        -- local useMul <const> = labComp == "MULTIPLY"
        local useChroma <const> = labComp == "CHROMA"
        local useHue <const> = labComp == "HUE"
        local useColor <const> = labComp == "COLOR"
        local useLch <const> = useChroma or useHue or useColor
            or labComp == "LCH"

        local mixer <const> = GradientUtilities.hueEasingFuncFromPreset(huePreset)

        local overIsValidTrg <const> = true
        local underIsValidTrg <const> = (not aLayer.isBackground)

        local hideOverLayer <const> = delOverStr == "HIDE"
        local delOverLayer <const> = delOverStr == "DELETE_LAYER"
            and overIsValidTrg
        local delUnderLayer <const> = delUnderStr == "DELETE_LAYER"
            and underIsValidTrg

        local hideUnderLayer <const> = delOverStr == "HIDE"
        local delOverCels <const> = delOverStr == "DELETE_CELS"
            and overIsValidTrg
        local delUnderCels <const> = delUnderStr == "DELETE_CELS"
            and underIsValidTrg

        local overIsTile <const> = bLayer.isTilemap
        local tileSetOver = nil
        local underIsTile <const> = aLayer.isTilemap
        local tileSetUnder = nil
        if overIsTile then
            tileSetOver = bLayer.tileset
        end
        if underIsTile then
            tileSetUnder = aLayer.tileset
        end

        local frames = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Unpack layer opacity.
        local overLyrOpacity = 255
        local underLyrOpacity = 255

        if bLayer.opacity then
            overLyrOpacity = bLayer.opacity
        end
        if aLayer.opacity then
            underLyrOpacity = aLayer.opacity
        end
        local bLayerOpac01 <const> = overLyrOpacity / 255.0
        local aLayerOpac01 <const> = underLyrOpacity / 255.0

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer = activeSprite.layers[1]
        app.transaction("New Layer", function()
            compLayer = activeSprite:newLayer()
            compLayer.name = string.format("Comp %s %s %s %s",
                bLayer.name, aLayer.name, labComp, alphaComp)
            compLayer.parent = parent
        end)

        local lenFrames <const> = #frames
        app.transaction("Blend Layers", function()
            ---@type table<integer, {l: number, a: number, b: number, alpha: number}>
            local dict <const> = {}
            dict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

            local idxFrame = 0
            while idxFrame < lenFrames do
                idxFrame = idxFrame + 1
                local frame <const> = frames[idxFrame]

                local bx = 0
                local by = 0
                local bWidth = wSprite
                local bHeight = hSprite
                local bImage = nil
                local bOpac01 = 1.0

                local bCel <const> = bLayer:cel(frame)
                if bCel then
                    bImage = bCel.image
                    if overIsTile then
                        bImage = tilesToImage(
                            bImage, tileSetOver, spriteColorMode)
                    end

                    local bPos <const> = bCel.position
                    bx = bPos.x
                    by = bPos.y
                    bWidth = bImage.width
                    bHeight = bImage.height

                    bOpac01 = bLayerOpac01 * (bCel.opacity / 255.0)
                else
                    bImage = Image(spriteSpec)
                end
                local bpx <const> = bImage.bytes
                local bbpp <const> = bImage.bytesPerPixel

                local ax = 0
                local ay = 0
                local aWidth = wSprite
                local aHeight = hSprite
                local aImage = nil
                local aOpac01 = 1.0

                local aCel <const> = aLayer:cel(frame)
                if aCel then
                    aImage = aCel.image
                    if underIsTile then
                        aImage = tilesToImage(
                            aImage, tileSetUnder, spriteColorMode)
                    end

                    local aPos <const> = aCel.position
                    ax = aPos.x
                    ay = aPos.y
                    aWidth = aImage.width
                    aHeight = aImage.height

                    aOpac01 = aLayerOpac01 * (aCel.opacity / 255.0)
                else
                    aImage = Image(spriteSpec)
                end
                local apx <const> = aImage.bytes
                local abpp <const> = aImage.bytesPerPixel

                local abrx <const> = ax + aWidth - 1
                local abry <const> = ay + aHeight - 1
                local bbrx <const> = bx + bWidth - 1
                local bbry <const> = by + bHeight - 1

                -- Composite occurs, for most generous case, at union.
                local cx <const> = min(ax, bx)
                local cy <const> = min(ay, by)
                local cbrx <const> = max(abrx, bbrx)
                local cbry <const> = max(abry, bbry)
                local cWidth <const> = 1 + cbrx - cx
                local cHeight <const> = 1 + cbry - cy
                local cLen <const> = cWidth * cHeight

                -- Find the difference between the union top left corner and the
                -- top left corners of a and b.
                local axud <const> = ax - cx
                local ayud <const> = ay - cy
                local bxud <const> = bx - cx
                local byud <const> = by - cy

                ---@type string[]
                local cStrs <const> = {}
                local i = 0
                while i < cLen do
                    local x = i % cWidth
                    local y = i // cWidth

                    local aRed = 0
                    local aGreen = 0
                    local aBlue = 0
                    local aAlpha = 0

                    local axs <const> = x - axud
                    local ays <const> = y - ayud
                    if ays >= 0 and ays < aHeight
                        and axs >= 0 and axs < aWidth then
                        local aIdx <const> = (axs + ays * aWidth) * abpp
                        aRed = strbyte(apx, 1 + aIdx)
                        aGreen = strbyte(apx, 2 + aIdx)
                        aBlue = strbyte(apx, 3 + aIdx)
                        aAlpha = strbyte(apx, 4 + aIdx)
                    end

                    local bRed = 0
                    local bGreen = 0
                    local bBlue = 0
                    local bAlpha = 0

                    local bxs <const> = x - bxud
                    local bys <const> = y - byud
                    if bys >= 0 and bys < bHeight
                        and bxs >= 0 and bxs < bWidth then
                        local bIdx <const> = (bxs + bys * bWidth) * bbpp
                        bRed = strbyte(bpx, 1 + bIdx)
                        bGreen = strbyte(bpx, 2 + bIdx)
                        bBlue = strbyte(bpx, 3 + bIdx)
                        bAlpha = strbyte(bpx, 4 + bIdx)
                    end

                    local cRed = 0
                    local cGreen = 0
                    local cBlue = 0
                    local cAlpha = 0

                    local t = bOpac01 * (bAlpha / 255.0)
                    local v = aOpac01 * (aAlpha / 255.0)

                    local aInt <const> = aAlpha << 0x18
                        | aBlue << 0x10
                        | aGreen << 0x08
                        | aRed
                    local aLab = dict[aInt]
                    if not aLab then
                        local aClr <const> = clrNew(
                            aRed / 255.0,
                            aGreen / 255.0,
                            aBlue / 255.0,
                            1.0)
                        aLab = sRgbToSrLab2(aClr)
                        dict[aInt] = aLab
                    end

                    local bInt <const> = bAlpha << 0x18
                        | bBlue << 0x10
                        | bGreen << 0x08
                        | bRed
                    local bLab = dict[bInt]
                    if not bLab then
                        local bClr <const> = clrNew(
                            bRed / 255.0,
                            bGreen / 255.0,
                            bBlue / 255.0,
                            1.0)
                        bLab = sRgbToSrLab2(bClr)
                        dict[bInt] = bLab
                    end

                    if v <= 0.0 then aLab = bLab end
                    if t <= 0.0 then bLab = aLab end

                    local u <const> = 1.0 - t
                    local cl = 0.0
                    local ca = 0.0
                    local cb = 0.0

                    if useLch then
                        local aLch <const> = srLab2ToSrLch(aLab.l, aLab.a, aLab.b, 1.0)
                        local bLch <const> = srLab2ToSrLch(bLab.l, bLab.a, bLab.b, 1.0)

                        local cc = 0.0
                        local ch = 0.0
                        if useColor then
                            cl = aLch.l
                            cc = u * aLch.c + t * bLch.c
                            ch = mixer(aLch.h, bLch.h, t)
                        elseif useChroma then
                            cl = aLch.l
                            cc = u * aLch.c + t * bLch.c
                            ch = aLch.h
                        elseif useHue then
                            cl = aLch.l
                            cc = aLch.c
                            ch = mixer(aLch.h, bLch.h, t)
                        else
                            cl = u * aLab.l + t * bLab.l
                            cc = u * aLch.c + t * bLch.c
                            ch = mixer(aLch.h, bLch.h, t)
                        end

                        local cLab <const> = srLchToSrLab2(cl, cc, ch, 1.0)
                        cl = cLab.l
                        ca = cLab.a
                        cb = cLab.b
                    else
                        -- Default to LAB.
                        if useLight then
                            cl = u * aLab.l + t * bLab.l
                            ca = aLab.a
                            cb = aLab.b
                        elseif useAb then
                            cl = aLab.l
                            ca = u * aLab.a + t * bLab.a
                            cb = u * aLab.b + t * bLab.b
                            -- elseif useAdd then
                            -- This could be L only, AB only, or LAB...
                            -- cl = u * aLab.l + t * (aLab.l + bLab.l)
                            -- ca = u * aLab.a + t * (aLab.a + bLab.a)
                            -- cb = u * aLab.b + t * (aLab.b + bLab.b)
                            -- elseif useMul then
                            -- Multiply only works on light.
                            -- local prod <const> = 100.0 * ((aLab.l * 0.01) * (bLab.l * 0.01))
                            -- cl = u * aLab.l + t * prod
                            -- ca = u * aLab.a + t * bLab.a
                            -- cb = u * aLab.b + t * bLab.b
                        else
                            cl = u * aLab.l + t * bLab.l
                            ca = u * aLab.a + t * bLab.a
                            cb = u * aLab.b + t * bLab.b
                        end
                    end

                    local tuv = t + u * v
                    if useAlphaOver then
                        tuv = t
                    elseif useAlphaUnder then
                        tuv = v
                    elseif useAlphaMin then
                        tuv = min(t, v)
                    elseif useAlphaMax then
                        tuv = max(t, v)
                    end

                    local cClr <const> = srLab2TosRgb(cl, ca, cb, tuv)
                    cRed = floor(min(max(cClr.r, 0.0), 1.0) * 255.0 + 0.5)
                    cGreen = floor(min(max(cClr.g, 0.0), 1.0) * 255.0 + 0.5)
                    cBlue = floor(min(max(cClr.b, 0.0), 1.0) * 255.0 + 0.5)
                    cAlpha = floor(min(max(cClr.a, 0.0), 1.0) * 255.0 + 0.5)

                    i = i + 1
                    local cStr <const> = strpack(
                        "B B B B",
                        cRed, cGreen, cBlue, cAlpha)
                    cStrs[i] = cStr
                end

                local cImageSpec <const> = createSpec(
                    cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex)
                local cImage <const> = Image(cImageSpec)
                cImage.bytes = tconcat(cStrs)

                activeSprite:newCel(compLayer, frame, cImage, Point(cx, cy))
            end
        end)

        if hideOverLayer then
            bLayer.isVisible = false
        elseif delOverLayer then
            -- Beware: it's possible to delete all layers
            -- in a sprite with Sprite:deleteLayer.
            activeSprite:deleteLayer(bLayer)
        elseif delOverCels then
            app.transaction("Delete Cels", function()
                local idxDel0 = lenFrames + 1
                while idxDel0 > 1 do
                    idxDel0 = idxDel0 - 1
                    local frame <const> = frames[idxDel0]
                    -- API reports an error if a cel cannot be
                    -- found, so the layer needs to check that
                    -- it has a cel first.
                    local overCel <const> = bLayer:cel(frame)
                    if overCel then activeSprite:deleteCel(overCel) end
                end
            end)
        end

        if hideUnderLayer then
            aLayer.isVisible = false
        elseif delUnderLayer then
            activeSprite:deleteLayer(aLayer)
        elseif delUnderCels then
            app.transaction("Delete Cels", function()
                local idxDel1 = lenFrames + 1
                while idxDel1 > 1 do
                    idxDel1 = idxDel1 - 1
                    local frame <const> = frames[idxDel1]
                    local underCel <const> = aLayer:cel(frame)
                    if underCel then activeSprite:deleteCel(underCel) end
                end
            end)
        end

        app.layer = compLayer
        app.refresh()

        if printElapsed then
            endTime = os.clock()
            elapsed = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed)
                }
            }
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

dlg:show {
    autoscrollbars = true,
    wait = false
}