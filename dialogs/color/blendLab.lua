dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }
local alphaComps <const> = { "BLEND", "MAX", "MIN", "OVER", "UNDER" }
local labComps <const> = {
    "L",
    "AB",
    "LAB",

    "C",
    "H",
    "CH",
    "LCH",

    "ADD",
    "SUBTRACT",
    "MULTIPLY",
    "DIVIDE",
    "SCREEN"
}

local defaults <const> = {
    target = "ACTIVE",
    alphaComp = "BLEND",
    labComp = "LAB",
    hueMix = "CCW",
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendLab(aLab, bLab, t, u)
    return u * aLab.l + t * bLab.l,
        u * aLab.a + t * bLab.a,
        u * aLab.b + t * bLab.b
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendL(aLab, bLab, t, u)
    return u * aLab.l + t * bLab.l,
        aLab.a,
        aLab.b
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendAb(aLab, bLab, t, u)
    return aLab.l,
        u * aLab.a + t * bLab.a,
        u * aLab.b + t * bLab.b
end

---@param aLch { l: number, c: number, h: number, a: number }
---@param bLch { l: number, c: number, h: number, a: number }
---@param t number
---@param u number
---@param mixer fun(o: number, d: number, t: number): number
---@return number cl
---@return number cc
---@return number ch
local function blendLch(aLch, bLch, t, u, mixer)
    return u * aLch.l + t * bLch.l,
        u * aLch.c + t * bLch.c,
        mixer(aLch.h, bLch.h, t)
end

---@param aLch { l: number, c: number, h: number, a: number }
---@param bLch { l: number, c: number, h: number, a: number }
---@param t number
---@param u number
---@param mixer fun(o: number, d: number, t: number): number
---@return number cl
---@return number cc
---@return number ch
local function blendC(aLch, bLch, t, u, mixer)
    return aLch.l,
        u * aLch.c + t * bLch.c,
        aLch.h
end

---@param aLch { l: number, c: number, h: number, a: number }
---@param bLch { l: number, c: number, h: number, a: number }
---@param t number
---@param u number
---@param mixer fun(o: number, d: number, t: number): number
---@return number cl
---@return number cc
---@return number ch
local function blendH(aLch, bLch, t, u, mixer)
    return aLch.l,
        aLch.c,
        mixer(aLch.h, bLch.h, t)
end

---@param aLch { l: number, c: number, h: number, a: number }
---@param bLch { l: number, c: number, h: number, a: number }
---@param t number
---@param u number
---@param mixer fun(o: number, d: number, t: number): number
---@return number cl
---@return number cc
---@return number ch
local function blendCH(aLch, bLch, t, u, mixer)
    return aLch.l,
        u * aLch.c + t * bLch.c,
        mixer(aLch.h, bLch.h, t)
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendAdd(aLab, bLab, t, u)
    local dl <const> = aLab.l + bLab.l
    local da <const> = (aLab.a + bLab.a) * 0.5
    local db <const> = (aLab.b + bLab.b) * 0.5
    return u * aLab.l + t * dl,
        u * aLab.a + t * da,
        u * aLab.b + t * db
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendSubtract(aLab, bLab, t, u)
    local dl <const> = aLab.l - bLab.l
    local da <const> = (aLab.a - bLab.a) * 0.5
    local db <const> = (aLab.b - bLab.b) * 0.5
    return u * aLab.l + t * dl,
        u * aLab.a + t * da,
        u * aLab.b + t * db
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendMultiply(aLab, bLab, t, u)
    local dl <const> = ((aLab.l * 0.01) * (bLab.l * 0.01)) * 100.0
    local da <const> = (aLab.a + bLab.a) * 0.5
    local db <const> = (aLab.b + bLab.b) * 0.5
    return u * aLab.l + t * dl,
        u * aLab.a + t * da,
        u * aLab.b + t * db
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendDivide(aLab, bLab, t, u)
    local dl = 0.0
    local den <const> = bLab.l * 0.01
    if den ~= 0.0 then dl = ((aLab.l * 0.01) / den) * 100.0 end
    local da <const> = (aLab.a - bLab.a) * 0.5
    local db <const> = (aLab.b - bLab.b) * 0.5
    return u * aLab.l + t * dl,
        u * aLab.a + t * da,
        u * aLab.b + t * db
end

---@param aLab { l: number, a: number, b: number, alpha: number }
---@param bLab { l: number, a: number, b: number, alpha: number }
---@param t number
---@param u number
---@return number cl
---@return number ca
---@return number cb
local function blendScreen(aLab, bLab, t, u)
    local dl <const> = 100.0 - ((1.0 - aLab.l * 0.01)
        * (1.0 - bLab.l * 0.01)) * 100.0
    local da <const> = (aLab.a + bLab.a) * 0.5
    local db <const> = (aLab.b + bLab.b) * 0.5
    return u * aLab.l + t * dl,
        u * aLab.a + t * da,
        u * aLab.b + t * db
end

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
        local isHue <const> = labComp == "H"
        local isColor <const> = labComp == "CH"
        local isLch <const> = labComp == "LCH"
        dlg:modify { id = "huePreset", visible = isHue or isColor or isLch }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "huePreset",
    label = "Easing:",
    option = defaults.hueMix,
    options = GradientUtilities.HUE_EASING_PRESETS,
    visible = defaults.labComp == "H"
        or defaults.labComp == "CH"
        or defaults.labComp == "LCH"
}

dlg:newrow { always = false }

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
    focus = true,
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
        local useLch = false
        local hueMix <const> = GradientUtilities.hueEasingFuncFromPreset(huePreset)
        local blendFuncLab = blendLab
        local blendFuncLch = blendLch
        if labComp == "L" or labComp == "LIGHTNESS" then
            blendFuncLab = blendL
        elseif labComp == "AB" then
            blendFuncLab = blendAb
        elseif labComp == "LCH" then
            blendFuncLch = blendLch
            useLch = true
        elseif labComp == "C" or labComp == "CHROMA" then
            blendFuncLch = blendC
            useLch = true
        elseif labComp == "H" or labComp == "HUE" then
            blendFuncLch = blendH
            useLch = true
        elseif labComp == "CH" or labComp == "COLOR" then
            blendFuncLch = blendCH
            useLch = true
        elseif labComp == "ADD" then
            blendFuncLab = blendAdd
        elseif labComp == "SUBTRACT" then
            blendFuncLab = blendSubtract
        elseif labComp == "MULTIPLY" then
            blendFuncLab = blendMultiply
        elseif labComp == "DIVIDE" then
            blendFuncLab = blendDivide
        elseif labComp == "SCREEN" then
            blendFuncLab = blendScreen
        end

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
        local overLyrOpacity <const> = bLayer.opacity or 255
        local underLyrOpacity <const> = aLayer.opacity or 255
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
                        aRed, aGreen, aBlue, aAlpha = strbyte(apx, 1 + aIdx, 4 + aIdx)
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
                        bRed, bGreen, bBlue, bAlpha = strbyte(bpx, 1 + bIdx, 4 + bIdx)
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

                    -- Timeline overlays display colors that are transparent,
                    -- but have non-zero RGB channels.
                    if tuv > 0.0 then
                        if useLch then
                            local aLch <const> = srLab2ToSrLch(
                                aLab.l, aLab.a, aLab.b, 1.0)
                            local bLch <const> = srLab2ToSrLch(
                                bLab.l, bLab.a, bLab.b, 1.0)

                            local cc = 0.0
                            local ch = 0.0
                            cl, cc, ch = blendFuncLch(aLch, bLch, t, u, hueMix)

                            local cLab <const> = srLchToSrLab2(cl, cc, ch, 1.0)
                            ca = cLab.a
                            cb = cLab.b
                        else
                            -- Default to LAB.
                            cl, ca, cb = blendFuncLab(aLab, bLab, t, u)
                        end
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

        AseUtilities.hideSource(activeSprite, aLayer, frames, delUnderStr)
        AseUtilities.hideSource(activeSprite, bLayer, frames, delOverStr)
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