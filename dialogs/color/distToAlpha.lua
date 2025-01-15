dofile("../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    -- TODO: For targets, include selection.
    -- https://community.aseprite.org/t/request-color-to-alpha-extension/24200

    target = "ACTIVE",
    delSrc = "NONE",
}

local dlg <const> = Dialog { title = "Color Dist To Alpha" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions
}

dlg:newrow { always = false }

dlg:color {
    id = "refColor",
    label = "Color:",
    color = Color(0, 0, 0, 255)
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
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

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        -- Check for tile maps.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local delSrcStr <const> = args.delSrc
            or defaults.delSrc --[[@as string]]
        local refColor <const> = args.refColor --[[@as Color]]

        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local refClr <const> = AseUtilities.aseColorToClr(refColor)
        local refLab <const> = Clr.sRgbToSrLab2(refClr)
        local refHex <const> = Clr.toHexWeb(refClr)
        local normChroma <const> = 1.0 / Clr.SR_LCH_MAX_CHROMA
        local normLab <const> = normChroma + 0.01

        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.name = string.format(
                "%s Remove %s",
                srcLayer.name, refHex)
        end)

        -- Cache functions used in loop.
        local tilesToImage <const> = AseUtilities.tileMapToImage

        local fromHex <const> = Clr.fromHexAbgr32
        local toHex <const> = Clr.toHex
        local sRgbToLab <const> = Clr.sRgbToSrLab2
        local labTosRgb <const> = Clr.srLab2TosRgb

        local abs <const> = math.abs
        local max <const> = math.max
        local min <const> = math.min
        local sqrt <const> = math.sqrt

        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack

        local tconcat <const> = table.concat

        local lenFrames <const> = #frames
        local i = 0
        while i < lenFrames do
            i = i + 1
            local srcFrame = frames[i]

            local xSrcPos = 0
            local ySrcPos = 0
            local srcImg = nil
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end
                local srcPos <const> = srcCel.position
                xSrcPos = srcPos.x
                ySrcPos = srcPos.y
            end

            if srcImg then
                local srcBytes <const> = srcImg.bytes
                local srcSpec <const> = srcImg.spec
                local lenSrc <const> = srcSpec.width * srcSpec.height

                ---@type table<integer, integer>
                local srcToTrg <const> = {}
                ---@type string[]
                local trgBytesArr <const> = {}

                local j = 0
                while j < lenSrc do
                    local j4 <const> = j * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))

                    local trgAbgr32 = 0x00000000
                    if srcToTrg[srcAbgr32] then
                        trgAbgr32 = srcToTrg[srcAbgr32]
                    else
                        if (srcAbgr32 & 0xff000000) ~= 0 then
                            local clr <const> = fromHex(srcAbgr32)
                            local lab <const> = sRgbToLab(clr)

                            local dl <const> = lab.l - refLab.l
                            local lDist <const> = abs(dl)

                            local da <const> = lab.a - refLab.a
                            local db <const> = lab.b - refLab.b
                            local abDist <const> = sqrt(da * da + db * db)

                            local labFac <const> = min(max((lDist + abDist) * normLab, 0.0), 1.0)

                            local abFac <const> = min(max(abDist * normChroma, 0.0), 1.0)
                            local abCompl <const> = 1.0 - abFac

                            -- TODO: Should L be lerped as well? Maybe make it an option to toggle?
                            local lTrg <const> = lab.l
                            local aTrg <const> = abCompl * da + abFac * lab.a
                            local bTrg <const> = abCompl * db + abFac * lab.b
                            local tTrg <const> = labFac

                            local clrTrg <const> = labTosRgb(lTrg, aTrg, bTrg, tTrg)
                            trgAbgr32 = toHex(clrTrg)
                        end

                        srcToTrg[srcAbgr32] = trgAbgr32
                    end

                    j = j + 1
                    trgBytesArr[j] = strpack("<I4", trgAbgr32)
                end

                local trgImg <const> = Image(srcSpec)
                trgImg.bytes = tconcat(trgBytesArr)

                activeSprite:newCel(
                    trgLayer, srcFrame, trgImg,
                    Point(xSrcPos, ySrcPos))
            end
        end

        -- Active layer assignment triggers a timeline update.
        AseUtilities.hideSource(activeSprite, srcLayer, frames, delSrcStr)
        app.layer = trgLayer
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