dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local idxCompOptions <const> = {
    "ADD",
    "BLEND",
    "OVER",
    "SUBTRACT",
    "UNDER"
}

local defaults <const> = {
    -- TODO: Should comp functions account
    -- for whether the layer is a background?
    target = "ACTIVE",
    idxComp = "OVER",
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

---@param u integer under index
---@param o integer over index
---@param t number mix factor
---@param alphaIndex integer alpha index
---@param lenPal integer length palette
---@return integer
local function compAdd(u, o, t, alphaIndex, lenPal)
    if o == alphaIndex then return u end
    if u == alphaIndex then return o end
    local y = u + o
    if y == alphaIndex then y = y + 1 end
    return y % lenPal
end

---@param u integer under index
---@param o integer over index
---@param t number mix factor
---@param alphaIndex integer alpha index
---@param lenPal integer length palette
---@return integer
local function compBlend(u, o, t, alphaIndex, lenPal)
    if o == alphaIndex then return u end
    if u == alphaIndex then return o end
    local x <const> = (1.0 - t) * u + t * o
    local y = Utilities.round(x)
    if y == alphaIndex then y = y + 1 end
    return y % lenPal
end

---@param u integer under index
---@param o integer over index
---@param t number mix factor
---@param alphaIndex integer alpha index
---@param lenPal integer length palette
---@return integer
local function compOver(u, o, t, alphaIndex, lenPal)
    if o == alphaIndex then return u end
    return o
end

---@param u integer under index
---@param o integer over index
---@param t number mix factor
---@param alphaIndex integer alpha index
---@param lenPal integer length palette
---@return integer
local function compSub(u, o, t, alphaIndex, lenPal)
    if o == alphaIndex then return u end
    if u == alphaIndex then return o end
    local y = u - o
    if y == alphaIndex then y = y - 1 end
    return y % lenPal
end

---@param u integer under index
---@param o integer over index
---@param t number mix factor
---@param alphaIndex integer alpha index
---@param lenPal integer length palette
---@return integer
local function compUnder(u, o, t, alphaIndex, lenPal)
    if u == alphaIndex then return o end
    return u
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
    id = "idxComp",
    label = "Mode:",
    option = defaults.idxComp,
    options = idxCompOptions,
    focus = false
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
        if spriteColorMode ~= ColorMode.INDEXED then
            app.alert {
                title = "Error",
                text = "Only indexed color mode is supported."
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

        local spritePalettes <const> = activeSprite.palettes
        local alphaIndexVerif <const> = (alphaIndex >= 0 and alphaIndex < 256) and
            alphaIndex or 0

        -- Cache global functions used in loop.
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local strbyte <const> = string.byte
        local strchar <const> = string.char
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec
        local getPalette <const> = AseUtilities.getPalette

        local clrNew <const> = Clr.new
        local sRgbToSrLab2 <const> = Clr.sRgbToSrLab2
        local srLab2TosRgb <const> = Clr.srLab2TosRgb
        local srLab2ToSrLch <const> = Clr.srLab2ToSrLch
        local srLchToSrLab2 <const> = Clr.srLchToSrLab2

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local idxComp <const> = args.idxComp
            or defaults.idxComp --[[@as string]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        local idxBlendFunc = compOver
        if idxComp == "ADD" then
            idxBlendFunc = compAdd
        elseif idxComp == "BLEND" then
            idxBlendFunc = compBlend
        elseif idxComp == "SUBTRACT" then
            idxBlendFunc = compSub
        elseif idxComp == "UNDER" then
            idxBlendFunc = compUnder
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
            compLayer.name = string.format(
                "Comp %s %s %s",
                bLayer.name, aLayer.name, idxComp)

            -- Exception: this always sets to parent.
            compLayer.parent = parent
        end)

        local i = 0
        local lenFrames <const> = #frIdcs
        while i < lenFrames do
            i = i + 1
            local frIdx <const> = frIdcs[i]

            local palette <const> = getPalette(frIdx, spritePalettes)
            local lenPalette <const> = #palette

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

                local aIdx = alphaIndexVerif
                local bIdx = alphaIndexVerif

                local axs <const> = x - axud
                local ays <const> = y - ayud
                if ays >= 0 and ays < aHeight
                    and axs >= 0 and axs < aWidth then
                    aIdx = strbyte(apx, 1 + (ays * aWidth + axs) * abpp)
                end

                local bxs <const> = x - bxud
                local bys <const> = y - byud
                if bys >= 0 and bys < bHeight
                    and bxs >= 0 and bxs < bWidth then
                    bIdx = strbyte(bpx, 1 + (bys * bWidth + bxs) * bbpp)
                end

                local cIdx <const> = idxBlendFunc(aIdx, bIdx, bOpac01, alphaIndex, lenPalette)

                j = j + 1
                cStrs[j] = strchar(cIdx)

                -- TODO: Implement
            end

            local cImage <const> = Image(createSpec(
                cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex))
            cImage.bytes = tconcat(cStrs)

            activeSprite:newCel(compLayer, frIdx, cImage, Point(cx, cy))
        end

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