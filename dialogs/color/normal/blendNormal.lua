dofile("../../../support/normalutilities.lua")

--[[
Implements Reoriented Normal Mapping from "Blending in Detail"
by Colin Barre-Brisebois and Stephen Hill
https://blog.selfshadow.com/publications/blending-in-detail/
]]

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    useZLock = true,
    delOver = "HIDE",
    delUnder = "HIDE",
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Blend Normal" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "useZLock",
    label = "Z:",
    text = "Positive",
    selected = defaults.useZLock,
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
        local acos <const> = math.acos
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local sin <const> = math.sin
        local sqrt <const> = math.sqrt

        local strbyte <const> = string.byte
        local strpack <const> = string.pack
        local tconcat <const> = table.concat

        local tilesToImage <const> = AseUtilities.tileMapToImage
        local createSpec <const> = AseUtilities.createSpec

        -- Unpack arguments.
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local useZLock <const> = args.useZLock --[[@as boolean]]
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

        -- Unpack layer opacity.
        local overLyrOpacity <const> = overLayer.opacity or 255
        local underLyrOpacity <const> = underLayer.opacity or 255
        local overLyrOpac01 <const> = overLyrOpacity / 255.0
        local underLayerOpac01 <const> = underLyrOpacity / 255.0

        -- Create new layer.
        -- Layer and cel opacity are baked in loop below.
        local compLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            compLayer.name = string.format(
                "Comp %s %s",
                overLayer.name, underLayer.name)
            -- Exception: this always sets to parent.
            compLayer.parent = parent
        end)

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

                bOpac01 = overLyrOpac01 * (bCel.opacity / 255.0)
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

                aOpac01 = underLayerOpac01 * (aCel.opacity / 255.0)
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

                local aRed, aGreen, aBlue, aAlpha = 0, 0, 0, 0 -- Under layer
                local bRed, bGreen, bBlue, bAlpha = 0, 0, 0, 0 -- Over layer
                local cRed, cGreen, cBlue, cAlpha = 0, 0, 0, 0 -- Comp layer

                local axs <const> = x - axud
                local ays <const> = y - ayud
                if ays >= 0 and ays < aHeight
                    and axs >= 0 and axs < aWidth then
                    local aIdx <const> = (ays * aWidth + axs) * abpp
                    aRed, aGreen, aBlue, aAlpha = strbyte(apx, 1 + aIdx, 4 + aIdx)
                end

                local ar01 = aRed / 255.0
                local ag01 = aGreen / 255.0
                local ab01 = aBlue / 255.0

                local anx = ar01 + ar01 - 1.0
                local any = ag01 + ag01 - 1.0
                local anz = ab01 + ab01 - 1.0
                local aSqMag3 <const> = anx * anx
                    + any * any
                    + anz * anz
                if aSqMag3 > 0.0 then
                    local magInv <const> = 1.0 / sqrt(aSqMag3)
                    anx = anx * magInv
                    any = any * magInv
                    anz = anz * magInv
                else
                    anx = 0.0
                    any = 0.0
                    anz = 1.0
                end

                ar01 = anx * 0.5 + 0.5
                ag01 = any * 0.5 + 0.5
                ab01 = anz * 0.5 + 0.5

                local bxs <const> = x - bxud
                local bys <const> = y - byud
                if bys >= 0 and bys < bHeight
                    and bxs >= 0 and bxs < bWidth then
                    local bIdx <const> = (bys * bWidth + bxs) * bbpp
                    bRed, bGreen, bBlue, bAlpha = strbyte(bpx, 1 + bIdx, 4 + bIdx)
                end

                local br01 = bRed / 255.0
                local bg01 = bGreen / 255.0
                local bb01 = bBlue / 255.0

                local bnx = br01 + br01 - 1.0
                local bny = bg01 + bg01 - 1.0
                local bnz = bb01 + bb01 - 1.0
                local bSqMag3 <const> = bnx * bnx
                    + bny * bny
                    + bnz * bnz
                if bSqMag3 > 0.0 then
                    local magInv <const> = 1.0 / sqrt(bSqMag3)
                    bnx = bnx * magInv
                    bny = bny * magInv
                    bnz = bnz * magInv
                else
                    bnx = 0.0
                    bny = 0.0
                    bnz = 1.0
                end

                br01 = bnx * 0.5 + 0.5
                bg01 = bny * 0.5 + 0.5
                bb01 = bnz * 0.5 + 0.5

                local v <const> = aOpac01 * (aAlpha / 255.0) -- Under layer
                local t <const> = bOpac01 * (bAlpha / 255.0) -- Over layer

                if t > 0.0 and v > 0.0 then
                    local tx <const> = ar01 * 2.0 - 1.0
                    local ty <const> = ag01 * 2.0 - 1.0
                    local tz <const> = ab01 * 2.0

                    local ux <const> = 1.0 - br01 * 2.0
                    local uy <const> = 1.0 - bg01 * 2.0
                    local uz <const> = bb01 * 2.0 - 1.0

                    local dottu <const> = tx * ux + ty * uy + tz * uz
                    local dx <const> = tx * dottu - ux * tz
                    local dy <const> = ty * dottu - uy * tz
                    local dz <const> = tz * dottu - uz * tz

                    local nx, ny, nz = 0.0, 0.0, 1.0
                    local sqMag3 <const> = dx * dx + dy * dy + dz * dz
                    if sqMag3 > 0.0 then
                        local magInv3 <const> = 1.0 / sqrt(sqMag3)
                        nx = dx * magInv3
                        ny = dy * magInv3
                        nz = dz * magInv3
                    end -- Valid 3D square magnitude.

                    local u <const> = 1.0 - t
                    local tuv <const> = t + u * v

                    -- Mix result by alpha of over channel.
                    local cnx, cny, cnz = 0.0, 0.0, 1.0
                    if t >= 1.0 then
                        cnx, cny, cnz = nx, ny, nz
                    else
                        local odDot <const> = min(max(
                            anx * nx + any * ny + anz * nz,
                            -0.999999), 0.999999)
                        local omega <const> = acos(odDot)
                        local omSin <const> = sin(omega)
                        local omSinInv <const> = omSin ~= 0.0 and 1.0 / omSin or 1.0
                        local oFac <const> = sin(u * omega) * omSinInv
                        local dFac <const> = sin(t * omega) * omSinInv

                        cnx = oFac * anx + dFac * nx
                        cny = oFac * any + dFac * ny
                        cnz = oFac * anz + dFac * nz

                        local cmsq <const> = cnx * cnx + cny * cny + cnz * cnz
                        if cmsq > 0.0 then
                            local cmInv <const> = 1.0 / sqrt(cmsq)
                            cnx = cnx * cmInv
                            cny = cny * cmInv
                            cnz = cnz * cmInv
                        end -- Mix magnitude is valid.
                    end     -- Over alpha is opaque.

                    if useZLock and cnz < 0.0 then
                        local sqMag2 <const> = cnx * cnx + cny * cny
                        if sqMag2 > 0.0 then
                            local magInv2 <const> = 1.0 / sqrt(sqMag2)
                            cnx = cnx * magInv2
                            cny = cny * magInv2
                            cnz = 0.0
                        end -- Valid 2D square magnitude.
                    end     -- Blue is negative.

                    cRed = min(max(floor(cnx * 127.5 + 128.0), 0), 255)
                    cGreen = min(max(floor(cny * 127.5 + 128.0), 0), 255)
                    cBlue = min(max(floor(cnz * 127.5 + 128.0), 0), 255)
                    cAlpha = min(max(floor(tuv * 255.0 + 0.5), 0), 255)
                elseif v > 0.0 then
                    -- Under layer is opaque, over is clear.

                    if useZLock and anz < 0.0 then
                        local aSqMag2 <const> = anx * anx + any * any
                        if aSqMag2 > 0.0 then
                            local magInv2 <const> = 1.0 / sqrt(aSqMag2)
                            anx = anx * magInv2
                            any = any * magInv2
                            anz = 0.0

                            ar01 = anx * 0.5 + 0.5
                            ag01 = any * 0.5 + 0.5
                            ab01 = anz * 0.5 + 0.5
                        end -- Valid 2D square magnitude.
                    end     -- Blue is negative.

                    cRed = min(max(floor(ar01 * 255.0 + 0.5), 0), 255)
                    cGreen = min(max(floor(ag01 * 255.0 + 0.5), 0), 255)
                    cBlue = min(max(floor(ab01 * 255.0 + 0.5), 0), 255)
                    cAlpha = min(max(floor(v * 255.0 + 0.5), 0), 255)
                elseif t > 0.0 then
                    -- Over layer is opaque, under is clear.

                    if useZLock and bnz < 0.0 then
                        local bSqMag2 <const> = bnx * bnx + bny * bny
                        if bSqMag2 > 0.0 then
                            local magInv2 <const> = 1.0 / sqrt(bSqMag2)
                            bnx = bnx * magInv2
                            bny = bny * magInv2
                            bnz = 0.0

                            br01 = bnx * 0.5 + 0.5
                            bg01 = bny * 0.5 + 0.5
                            bb01 = bnz * 0.5 + 0.5
                        end -- Valid 2D square magnitude.
                    end     -- Blue is negative.

                    cRed = min(max(floor(br01 * 255.0 + 0.5), 0), 255)
                    cGreen = min(max(floor(bg01 * 255.0 + 0.5), 0), 255)
                    cBlue = min(max(floor(bb01 * 255.0 + 0.5), 0), 255)
                    cAlpha = min(max(floor(t * 255.0 + 0.5), 0), 255)
                end -- End alpha check for over and under.

                j = j + 1
                cStrs[j] = strpack(
                    "B B B B",
                    cRed, cGreen, cBlue, cAlpha)
            end -- End pixels loop.

            local cImage <const> = Image(createSpec(
                cWidth, cHeight, spriteColorMode, colorSpace, alphaIndex))
            cImage.bytes = tconcat(cStrs)

            activeSprite:newCel(compLayer, frIdx, cImage, Point(cx, cy))
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