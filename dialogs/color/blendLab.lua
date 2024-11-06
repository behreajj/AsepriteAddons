dofile("../../support/gradientutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local compModes <const> = { "LAB", "LCH" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local abCompOptions <const> = {
    "ADD",
    "BLEND",
    "OVER",
    "SUBTRACT",
    "UNDER"
}

local cCompOptions <const> = {
    "BLEND",
    "OVER",
    "UNDER"
}

local hCompOptions <const> = {
    "CCW",
    "CW",
    "NEAR",
    "OVER",
    "UNDER"
}

local lCompOptions <const> = {
    "ADD",
    "BLEND",
    "DIVIDE",
    "MULTIPLY",
    "OVER",
    "SUBTRACT",
    "UNDER"
}

local tCompOptions <const> = {
    "BLEND",
    "MAX",
    "MIN",
    "OVER",
    "UNDER"
}

local defaults <const> = {
    -- TODO: Is this leaking memory somewhere?
    target = "ACTIVE",
    compMode = "LAB",
    lComp = "BLEND",
    abComp = "BLEND",
    cComp = "BLEND",
    hueMix = "CCW",
    alphaComp = "BLEND",
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

---@param ua number under a
---@param ub number under b
---@param oa number over a
---@param ob number over b
---@param ut number under alpha
---@param ot number over alpha
---@return number ca
---@return number cb
local function abCompAdd(ua, ub, oa, ob, ut, ot)
    local nt <const> = 1.0 - ot
    local utgt0 <const> = ut > 0.0
    local da <const> = utgt0 and ua + oa or oa
    local db <const> = utgt0 and ub + ob or ob
    return nt * ua + ot * da,
        nt * ub + ot * db
end

---@param ua number under a
---@param ub number under b
---@param oa number over a
---@param ob number over b
---@param ut number under alpha
---@param ot number over alpha
---@return number ca
---@return number cb
local function abCompMix(ua, ub, oa, ob, ut, ot)
    local nt <const> = 1.0 - ot
    return nt * ua + ot * oa,
        nt * ub + ot * ob
end

---@param ua number under a
---@param ub number under b
---@param oa number over a
---@param ob number over b
---@param ut number under alpha
---@param ot number over alpha
---@return number ca
---@return number cb
local function abCompOver(ua, ub, oa, ob, ut, ot)
    return oa, ob
end

---@param ua number under a
---@param ub number under b
---@param oa number over a
---@param ob number over b
---@param ut number under alpha
---@param ot number over alpha
---@return number ca
---@return number cb
local function abCompSub(ua, ub, oa, ob, ut, ot)
    local nt <const> = 1.0 - ot
    local utgt0 <const> = ut > 0.0
    local da <const> = utgt0 and ua - oa or oa
    local db <const> = utgt0 and ub - ob or ob
    return nt * ua + ot * da,
        nt * ub + ot * db
end

---@param ua number under a
---@param ub number under b
---@param oa number over a
---@param ob number over b
---@param ut number under alpha
---@param ot number over alpha
---@return number ca
---@return number cb
local function abCompUnder(ua, ub, oa, ob, ut, ot)
    return ua, ub
end

---@param uc number under chroma
---@param oc number over chroma
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function cCompMix(uc, oc, ut, ot)
    return (1.0 - ot) * uc + ot * oc
end

---@param uc number under chroma
---@param oc number over chroma
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function cCompOver(uc, oc, ut, ot)
    return oc
end

---@param uc number under chroma
---@param oc number over chroma
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function cCompUnder(uc, oc, ut, ot)
    return uc
end

---@param o number origin
---@param d number destination
---@param t number factor
---@return number ch
local function hCompOver(o, d, t)
    return d
end

---@param o number origin
---@param d number destination
---@param t number factor
---@return number ch
local function hCompUnder(o, d, t)
    return o
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompAdd(ul, ol, ut, ot)
    local dl <const> = ut > 0.0 and ul + ol or ol
    return (1.0 - ot) * ul + ot * dl
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompDiv(ul, ol, ut, ot)
    local dl <const> = ut > 0.0
        and (ol ~= 0.0
            and ((ul * 0.01) / (ol * 0.01)) * 100.0
            or 0.0)
        or ol
    return (1.0 - ot) * ul + ot * dl
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompMul(ul, ol, ut, ot)
    local dl <const> = ut > 0.0
        and ((ul * 0.01) * (ol * 0.01)) * 100.0
        or ol
    return (1.0 - ot) * ul + ot * dl
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompMix(ul, ol, ut, ot)
    return (1.0 - ot) * ul + ot * ol
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompOver(ul, ol, ut, ot)
    return ol
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompSub(ul, ol, ut, ot)
    local dl <const> = ut > 0.0 and ul - ol or ol
    return (1.0 - ot) * ul + ot * dl
end

---@param ul number under light
---@param ol number over light
---@param ut number under alpha
---@param ot number over alpha
---@return number cl
local function lCompUnder(ul, ol, ut, ot)
    return ul
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
    id = "compMode",
    label = "Mode:",
    option = defaults.compMode,
    options = compModes,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local compMode <const> = args.compMode --[[@as string]]
        local isLab <const> = compMode == "LAB"
        local isLch <const> = compMode == "LCH"
        dlg:modify { id = "abComp", visible = isLab }
        dlg:modify { id = "cComp", visible = isLch }
        dlg:modify { id = "huePreset", visible = isLch }
    end
}

dlg:separator { id = "blendsSep" }

dlg:combobox {
    id = "lComp",
    label = "L:",
    option = defaults.lComp,
    options = lCompOptions,
    focus = false
}

dlg:newrow { always = false }

dlg:combobox {
    id = "abComp",
    label = "AB:",
    option = defaults.abComp,
    options = abCompOptions,
    focus = false,
    visible = defaults.compMode == "LAB"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "cComp",
    label = "C:",
    option = defaults.cComp,
    options = cCompOptions,
    focus = false,
    visible = defaults.compMode == "LCH"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "huePreset",
    label = "H:",
    option = defaults.hueMix,
    options = hCompOptions,
    visible = defaults.compMode == "LCH"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "alphaComp",
    label = "Alpha:",
    option = defaults.alphaComp,
    options = tCompOptions
}

dlg:separator { id = "sourceSep" }

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
        local startTime <const> = os.clock()

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
        local compMode <const> = args.compMode
            or defaults.compMode --[[@as string]]
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

        local lBlendFunc = lCompMix
        local abBlendFunc = abCompMix
        local cBlendFunc = cCompMix
        local hBlendFunc = GradientUtilities.lerpHueNear

        local lPreset <const> = args.lComp
            or defaults.lComp --[[@as string]]
        local cPreset <const> = args.cComp
            or defaults.cComp --[[@as string]]
        local abPreset <const> = args.abComp
            or defaults.abComp --[[@as string]]
        local hPreset <const> = args.huePreset
            or defaults.hueMix --[[@as string]]

        if lPreset == "ADD" then
            lBlendFunc = lCompAdd
        elseif lPreset == "DIVIDE" then
            lBlendFunc = lCompDiv
        elseif lPreset == "MULTIPLY" then
            lBlendFunc = lCompMul
        elseif lPreset == "OVER" then
            lBlendFunc = lCompOver
        elseif lPreset == "SUBTRACT" then
            lBlendFunc = lCompSub
        elseif lPreset == "UNDER" then
            lBlendFunc = lCompUnder
        end

        local useLch = compMode == "LCH"
        if useLch then
            if cPreset == "OVER" then
                cBlendFunc = cCompOver
            elseif cPreset == "UNDER" then
                cBlendFunc = cCompUnder
            end

            if hPreset == "OVER" then
                hBlendFunc = hCompOver
            elseif hPreset == "UNDER" then
                hBlendFunc = hCompUnder
            else
                hBlendFunc = GradientUtilities.hueEasingFuncFromPreset(hPreset)
            end
        else
            if abPreset == "ADD" then
                abBlendFunc = abCompAdd
            elseif abPreset == "OVER" then
                abBlendFunc = abCompOver
            elseif abPreset == "SUBTRACT" then
                abBlendFunc = abCompSub
            elseif abPreset == "UNDER" then
                abBlendFunc = abCompUnder
            end
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

        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        -- Unpack layer opacity.
        local overLyrOpacity <const> = bLayer.opacity or 255
        local underLyrOpacity <const> = aLayer.opacity or 255
        local bLayerOpac01 <const> = overLyrOpacity / 255.0
        local aLayerOpac01 <const> = underLyrOpacity / 255.0

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            if useLch then
                compLayer.name = string.format(
                    "Comp %s %s L %s C %s H %s T %s",
                    bLayer.name, aLayer.name,
                    lPreset, cPreset, hPreset, alphaComp)
            else
                compLayer.name = string.format(
                    "Comp %s %s L %s AB %s T %s",
                    bLayer.name, aLayer.name,
                    lPreset, abPreset, alphaComp)
            end
            -- Exception: this always sets to parent.
            compLayer.parent = parent
        end)

        ---@type table<integer, {l: number, a: number, b: number, alpha: number}>
        local dict <const> = {}
        dict[0] = { l = 0.0, a = 0.0, b = 0.0, alpha = 0.0 }

        local i = 0
        local lenFrames <const> = #frIdcs
        while i < lenFrames do
            i = i + 1
            local frIdx <const> = frIdcs[i]

            local bx = 0
            local by = 0
            local bWidth = wSprite
            local bHeight = hSprite
            local bImage = nil
            local bOpac01 = 1.0

            local bCel <const> = bLayer:cel(frIdx)
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

            local aCel <const> = aLayer:cel(frIdx)
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
            local j = 0
            while j < cLen do
                local x = j % cWidth
                local y = j // cWidth

                local aRed, aGreen, aBlue, aAlpha = 0, 0, 0, 0
                local bRed, bGreen, bBlue, bAlpha = 0, 0, 0, 0

                local axs <const> = x - axud
                local ays <const> = y - ayud
                if ays >= 0 and ays < aHeight
                    and axs >= 0 and axs < aWidth then
                    local aIdx <const> = (ays * aWidth + axs) * abpp
                    aRed, aGreen, aBlue, aAlpha = strbyte(apx, 1 + aIdx, 4 + aIdx)
                end

                local bxs <const> = x - bxud
                local bys <const> = y - byud
                if bys >= 0 and bys < bHeight
                    and bxs >= 0 and bxs < bWidth then
                    local bIdx <const> = (bys * bWidth + bxs) * bbpp
                    bRed, bGreen, bBlue, bAlpha = strbyte(bpx, 1 + bIdx, 4 + bIdx)
                end

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
                local cl, ca, cb = 0.0, 0.0, 0.0
                if tuv > 0.0 then
                    cl = lBlendFunc(aLab.l, bLab.l, v, t)

                    if useLch then
                        local aLch <const> = srLab2ToSrLch(
                            aLab.l, aLab.a, aLab.b, 1.0)
                        local bLch <const> = srLab2ToSrLch(
                            bLab.l, bLab.a, bLab.b, 1.0)
                        local cc <const> = cBlendFunc(aLch.c, bLch.c, v, t)
                        local ch <const> = hBlendFunc(aLch.h, bLch.h, t)
                        local cLab <const> = srLchToSrLab2(cl, cc, ch, 1.0)
                        ca = cLab.a
                        cb = cLab.b
                    else
                        -- Default to LAB.
                        ca, cb = abBlendFunc(
                            aLab.a, aLab.b,
                            bLab.a, bLab.b,
                            v, t)
                    end
                end

                local cClr <const> = srLab2TosRgb(cl, ca, cb, tuv)
                local cRed <const> = floor(min(max(cClr.r, 0.0), 1.0) * 255.0 + 0.5)
                local cGreen <const> = floor(min(max(cClr.g, 0.0), 1.0) * 255.0 + 0.5)
                local cBlue <const> = floor(min(max(cClr.b, 0.0), 1.0) * 255.0 + 0.5)
                local cAlpha <const> = floor(min(max(cClr.a, 0.0), 1.0) * 255.0 + 0.5)

                j = j + 1
                cStrs[j] = strpack(
                    "B B B B",
                    cRed, cGreen, cBlue, cAlpha)
            end

            local cImage <const> = Image(createSpec(
                cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex))
            cImage.bytes = tconcat(cStrs)

            activeSprite:newCel(compLayer, frIdx, cImage, Point(cx, cy))
        end
        -- end)

        AseUtilities.hideSource(activeSprite, aLayer, frIdcs, delUnderStr)
        AseUtilities.hideSource(activeSprite, bLayer, frIdcs, delOverStr)
        app.layer = compLayer
        app.refresh()

        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
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