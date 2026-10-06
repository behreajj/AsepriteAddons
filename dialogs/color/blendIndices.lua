local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local idxCompOptions <const> = {
    "ADD",
    "AVERAGE",
    "BIT_AND",
    "BIT_OR",
    "BIT_XOR",
    "OVER",
    "SUBTRACT",
    "UNDER",
}

local alphaCompOptions <const> = {
    "EXCLUDE",
    "INTERSECT",
    "UNION",
}

local defaults <const> = {
    -- https://github.com/aseprite/aseprite/issues/2427
    -- https://github.com/aseprite/aseprite/issues/3230

    -- TODO: Consider alpha union or intersect option.
    -- In that case, the compilation functions would
    -- be better off without cases where one color is
    -- the alpha index.
    target = "ACTIVE",
    idxComp = "OVER",
    alphaComp = "UNION",
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompAdd(uIdx, oIdx, palLength)
    return (uIdx + oIdx) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompBitAnd(uIdx, oIdx, palLength)
    return (uIdx & oIdx) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompBitOr(uIdx, oIdx, palLength)
    return (uIdx | oIdx) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompBitXor(uIdx, oIdx, palLength)
    return (uIdx ~ oIdx) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompAverage(uIdx, oIdx, palLength)
    return ((uIdx + oIdx) // 2) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompOver(uIdx, oIdx, palLength)
    return oIdx % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompSub(uIdx, oIdx, palLength)
    return (uIdx - oIdx) % palLength
end

---@param uIdx integer under index
---@param oIdx integer over index
---@param palLength integer palette length
---@return integer cl
local function idxCompUnder(uIdx, oIdx, palLength)
    return uIdx % palLength
end

local dlg <const> = Dialog { title = "Blend Indices" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "idxComp",
    label = "Index:",
    option = defaults.idxComp,
    options = idxCompOptions,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "alphaComp",
    label = "Alpha:",
    option = defaults.alphaComp,
    options = alphaCompOptions,
    hexpand = false,
}

dlg:separator { id = "sourceSep" }

dlg:combobox {
    id = "delOver",
    label = "Over:",
    text = "Mask",
    option = defaults.delOver,
    options = delOptions,
    hexpand = false,
}

dlg:combobox {
    id = "delUnder",
    label = "Under:",
    text = "Source",
    option = defaults.delUnder,
    options = delOptions,
    hexpand = false,
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
    selected = defaults.printElapsed,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local args <const> = dlg.data
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

        local overLayer <const> = site.layer
        if not overLayer then
            app.alert {
                title = "Error",
                text = "There is no active layer."
            }
            return
        end

        local overIndex <const> = overLayer.stackIndex
        if overIndex < 2 then
            app.alert {
                title = "Error",
                text = "There must be a layer beneath the active layer."
            }
            return
        end

        -- A parent may be a sprite or a group layer.
        -- Over and under layer should belong to same group.
        local parent <const> = overLayer.parent
        local underIndex <const> = overIndex - 1
        local underLayer <const> = parent.layers[underIndex]

        if overLayer.isReference or underLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        if overLayer.isGroup or underLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        --Unpack the rest of sprite spec.
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorSpace <const> = spriteSpec.colorSpace
        local wSprite <const> = spriteSpec.width
        local hSprite <const> = spriteSpec.height

        -- Cache global functions used in loop.
        local max <const> = math.max
        local min <const> = math.min
        local strbyte <const> = string.byte
        local strchar <const> = string.char
        local strfmt <const> = string.format
        local tconcat <const> = table.concat

        local createSpec <const> = AseUtilities.createSpec
        local getPalette <const> = AseUtilities.getPalette
        local tilesToImage <const> = AseUtilities.tileMapToImage

        local transact <const> = app.transaction

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local idxComp <const> = args.idxComp
            or defaults.idxComp --[[@as string]]
        local alphaComp <const> = args.alphaComp
            or defaults.alphaComp --[[@as string]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        local overIsTile <const> = overLayer.isTilemap
        local tileSetOver = nil
        local underIsTile <const> = underLayer.isTilemap
        local tileSetUnder = nil
        if overIsTile then
            tileSetOver = overLayer.tileset
        end
        if underIsTile then
            tileSetUnder = underLayer.tileset
        end

        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local palettes <const> = activeSprite.palettes

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            compLayer.name = string.format(
                "Comp %s %s %s",
                overLayer.name, underLayer.name, idxComp)
            compLayer.parent = parent
        end)

        local useUnion <const> = alphaComp == "UNION"
        local useIntersect <const> = alphaComp == "INTERSECT"
        local useExclude <const> = alphaComp == "EXCLUDE"

        local idxBlendFunc = idxCompOver
        if idxComp == "ADD" then
            idxBlendFunc = idxCompAdd
        elseif idxComp == "AVERAGE" then
            idxBlendFunc = idxCompAverage
        elseif idxComp == "BIT_AND" then
            idxBlendFunc = idxCompBitAnd
        elseif idxComp == "BIT_OR" then
            idxBlendFunc = idxCompBitOr
        elseif idxComp == "BIT_XOR" then
            idxBlendFunc = idxCompBitXor
        elseif idxComp == "SUBTRACT" then
            idxBlendFunc = idxCompSub
        elseif idxComp == "UNDER" then
            idxBlendFunc = idxCompUnder
        end

        -- Get frame UI offset.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local i = 0
        local lenFrames <const> = #frIdcs
        while i < lenFrames do
            i = i + 1
            local frIdx <const> = frIdcs[i]

            local palette <const> = getPalette(frIdx, palettes)
            local palLength <const> = #palette

            local bx = 0
            local by = 0
            local bWidth = wSprite
            local bHeight = hSprite
            local bImage = nil

            local bCel <const> = overLayer:cel(frIdx)
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
            else
                bImage = Image(spriteSpec)
            end
            local bpx <const> = bImage.bytes

            local ax = 0
            local ay = 0
            local aWidth = wSprite
            local aHeight = hSprite
            local aImage = nil

            local aCel <const> = underLayer:cel(frIdx)
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
            else
                aImage = Image(spriteSpec)
            end
            local apx <const> = aImage.bytes

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
                local x <const> = j % cWidth
                local y <const> = j // cWidth

                local aVal = alphaIndex
                local bVal = alphaIndex
                local cVal = alphaIndex

                local axs <const> = x - axud
                local ays <const> = y - ayud
                if ays >= 0 and ays < aHeight
                    and axs >= 0 and axs < aWidth then
                    aVal = strbyte(apx, ays * aWidth + axs + 1)
                end

                local bxs <const> = x - bxud
                local bys <const> = y - byud
                if bys >= 0 and bys < bHeight
                    and bxs >= 0 and bxs < bWidth then
                    bVal = strbyte(bpx, bys * bWidth + bxs + 1)
                end

                local aIsOpaque <const> = aVal ~= alphaIndex
                local bIsOpaque <const> = bVal ~= alphaIndex
                if useUnion then
                    if aIsOpaque and bIsOpaque then
                        cVal = idxBlendFunc(aVal, bVal, palLength)
                    elseif bIsOpaque then
                        cVal = bVal
                    elseif aIsOpaque then
                        cVal = aVal
                    end
                elseif useIntersect then
                    if aIsOpaque and bIsOpaque then
                        cVal = idxBlendFunc(aVal, bVal, palLength)
                    end
                elseif useExclude then
                    if aIsOpaque and bIsOpaque then
                        cVal = alphaIndex
                    elseif bIsOpaque then
                        cVal = bVal
                    elseif aIsOpaque then
                        cVal = aVal
                    end
                end -- End alpha comp block.

                j = j + 1
                cStrs[j] = strchar(cVal)
            end -- End pixels loop.

            local cImage <const> = Image(createSpec(
                cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex))
            cImage.bytes = tconcat(cStrs)

            transact(strfmt("Blend Indices %s", frIdx + frameUiOffset),
                function()
                    activeSprite:newCel(compLayer, frIdx, cImage, Point(cx, cy))
                end)
        end -- End frames loop.

        AseUtilities.hideSource(activeSprite, underLayer, frIdcs, delUnderStr)
        AseUtilities.hideSource(activeSprite, overLayer, frIdcs, delOverStr)
        app.layer = compLayer
        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        if printElapsed then
            AseUtilities.printElapsed(startTime)
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