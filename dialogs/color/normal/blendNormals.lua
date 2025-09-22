--[[
    https://community.aseprite.org/t/normal-map-from-height-blending-normal-maps/13046
    https://blog.selfshadow.com/publications/blending-in-detail/
]]

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local tCompOptions <const> = {
    "BLEND",
    "MAX",
    "MIN",
    "MULTIPLY",
    "OVER",
    "UNDER",
}

local defaults <const> = {
    target = "ACTIVE",
    alphaComp = "BLEND",
    zLock = true,
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Blend Normals" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "alphaComp",
    label = "Alpha:",
    option = defaults.alphaComp,
    options = tCompOptions,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "zLock",
    label = "Z Lock:",
    selected = defaults.zLock,
    focus = false,
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

        if bLayer.isReference or aLayer.isReference then
            app.alert {
                title = "Error",
                text = "Reference layers are not supported."
            }
            return
        end

        if bLayer.isGroup or aLayer.isGroup then
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
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local strbyte <const> = string.byte
        local strchar <const> = string.char
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local alphaComp <const> = args.alphaComp
            or defaults.alphaComp --[[@as string]]
        local zLock <const> = args.zLock --[[@as boolean]]
        local delOverStr <const> = args.delOver
            or defaults.delOver --[[@as string]]
        local delUnderStr <const> = args.delUnder
            or defaults.delUnder --[[@as string]]

        -- print(string.format("alphaComp: %s", alphaComp))
        local useAlphaMax <const> = alphaComp == "MAX"
        local useAlphaMin <const> = alphaComp == "MIN"
        local useAlphaMul <const> = alphaComp == "MULTIPLY"
        local useAlphaOver <const> = alphaComp == "OVER"
        local useAlphaUnder <const> = alphaComp == "UNDER"

        local overIsTile <const> = bLayer.isTilemap
        local tileSetOver = nil
        if overIsTile then
            tileSetOver = bLayer.tileset
        end

        local underIsTile <const> = aLayer.isTilemap
        local tileSetUnder = nil
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
                "Blend %s %s",
                bLayer.name, aLayer.name)
            -- Exception: this always sets to parent.
            compLayer.parent = parent
        end)

        local lenFrames <const> = #frIdcs
        local i = 0
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

                local t <const> = bOpac01 * (bAlpha / 255.0)
                local v <const> = aOpac01 * (aAlpha / 255.0)

                if v <= 0.0 then
                    aRed, aGreen, aBlue = 127.5, 127.5, 255
                end
                if t <= 0.0 then
                    bRed, bGreen, bBlue = 127.5, 127.5, 255
                end

                local u <const> = 1.0 - t
                local tuv = t + u * v
                if useAlphaOver then
                    tuv = t
                elseif useAlphaUnder then
                    tuv = v
                elseif useAlphaMax then
                    tuv = max(t, v)
                elseif useAlphaMin then
                    tuv = min(t, v)
                elseif useAlphaMul then
                    tuv = t * v
                end

                local rTrg, gTrg, bTrg, aTrg = 0, 0, 0, 0
                if tuv > 0.0 then
                    local tx <const> = (aRed / 255.0) * 2.0 - 1.0
                    local ty <const> = (aGreen / 255.0) * 2.0 - 1.0
                    local tz <const> = (aBlue / 255.0) * 2.0

                    local ux <const> = 1.0 - (bRed / 255.0) * 2.0
                    local uy <const> = 1.0 - (bGreen / 255.0) * 2.0
                    local uz <const> = (bBlue / 255.0) * 2.0 - 1.0

                    local dottu <const> = tx * ux + ty * uy + tz * uz
                    local dx <const> = tx * dottu - ux * tz
                    local dy <const> = ty * dottu - uy * tz
                    local dz <const> = tz * dottu - uz * tz

                    local nx, ny, nz = 0.0, 0.0, 0.0
                    if zLock and dz < 0.0 then
                        local sqMag2 <const> = dx * dx + dy * dy
                        if sqMag2 > 0.0 then
                            local mInv <const> = 1.0 / math.sqrt(sqMag2)
                            nx = dx * mInv
                            ny = dy * mInv
                        end
                    else
                        local sqMag3 <const> = dx * dx + dy * dy + dz * dz
                        if sqMag3 > 0.0 then
                            local mInv <const> = 1.0 / math.sqrt(sqMag3)
                            nx = dx * mInv
                            ny = dy * mInv
                            nz = dz * mInv
                        end
                    end -- End z lock check.

                    rTrg = floor(nx * 127.5 + 128.0)
                    gTrg = floor(ny * 127.5 + 128.0)
                    bTrg = floor(nz * 127.5 + 128.0)
                    aTrg = floor(tuv * 255.0 + 0.5)
                end -- End alpha greater than zero.

                cStrs[1 + j] = strpack("B B B B", rTrg, gTrg, bTrg, aTrg)
                j = j + 1
            end -- End composite loop.

            local cImage <const> = Image(createSpec(
                cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex))
            cImage.bytes = tconcat(cStrs)

            activeSprite:newCel(compLayer, frIdx, cImage, Point(cx, cy))
        end -- End frames loop.

        AseUtilities.hideSource(activeSprite, aLayer, frIdcs, delUnderStr)
        AseUtilities.hideSource(activeSprite, bLayer, frIdcs, delOverStr)
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