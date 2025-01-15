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
        local floor <const> = math.floor
        local min <const> = math.min
        local max <const> = math.max
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

                            -- TODO: light distance and ab distance should be calculated separately.
                            local dl <const> = lab.l - refLab.l
                            local da <const> = lab.a - refLab.a
                            local db <const> = lab.b - refLab.b
                            local dst <const> = sqrt(dl * dl + da * da + db * db)

                            local t <const> = min(max(dst * 0.01, 0.0), 1.0)
                            local u <const> = 1.0 - t

                            -- TODO: Should L be lerped as well? Maybe make it an option to toggle?
                            local lTrg <const> = lab.l
                            local aTrg <const> = u * da + t * lab.a
                            local bTrg <const> = u * db + t * lab.b
                            local tTrg <const> = t

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


-- dlg:button {
--     id = "execute",
--     text = "&OK",
--     onclick = function()
--         local sprite <const> = app.sprite
--         if not sprite then
--             app.alert { title = "Error", text = "No active sprite." }
--             return
--         end

--         if sprite.colorMode ~= ColorMode.RGB then
--             app.alert {
--                 title = "Error",
--                 text = "Only RGB color mode is supported."
--             }
--             return
--         end

--         local frame = app.frame
--         if not frame then
--             app.alert { title = "Error", text = "No active frame." }
--             return
--         end

--         local layer = app.layer
--         if not layer then
--             app.alert { title = "Error", text = "No active layer." }
--             return
--         end

--         if not layer.isVisible then
--             app.alert { title = "Error", text = "Layer is not visible." }
--             return
--         end

--         if not layer.isEditable then
--             app.alert { title = "Error", text = "Layer is not editable." }
--             return
--         end

--         if layer.isBackground then
--             app.alert { title = "Error", text = "Layer is background." }
--             return
--         end

--         if layer.isReference then
--             app.alert { title = "Error", text = "Layer is a reference." }
--             return
--         end

--         if layer.isTilemap then
--             app.alert { title = "Error", text = "Layer is a tile map." }
--             return
--         end

--         local cel = layer:cel(frame)
--         if not cel then
--             app.alert { title = "Error", text = "No active cel." }
--             return
--         end

--         local sourceImage = cel.image
--         local sourceBytes = sourceImage.bytes
--         local sourceSpec = sourceImage.spec
--         local sourceWidth = sourceSpec.width
--         local sourceHeight = sourceSpec.height
--         local sourceArea = sourceWidth * sourceHeight

--         local args = dlg.data
--         local refColor = args.refColor --[[@as Color]]

--         -- Cache global methods that will be used within a loop to local
--         -- variables.
--         local floor = math.floor
--         local max = math.max
--         local min = math.min
--         local sqrt = math.sqrt
--         local strbyte = string.byte
--         local strchar = string.char

--         local maxEuclDist = math.sqrt(3.0)

--         local transfer = 2.2
--         local invTransfer = 1.0 / transfer

--         local r8Ref = refColor.red
--         local g8Ref = refColor.green
--         local b8Ref = refColor.blue

--         local r01Ref = r8Ref / 255.0
--         local g01Ref = g8Ref / 255.0
--         local b01Ref = b8Ref / 255.0

--         local r01RefLinear = r01Ref ^ transfer
--         local g01RefLinear = g01Ref ^ transfer
--         local b01RefLinear = b01Ref ^ transfer

--         local targetBytesArr = {}

--         local i = 0
--         while i < sourceArea do
--             local i4 = i * 4

--             -- Unpack color as bytes from byte string.
--             local r8Src,
--             g8Src,
--             b8Src,
--             a8Src = strbyte(sourceBytes, 1 + i4, 4 + i4)

--             -- If the source color's alpha is zero,
--             -- default all channels to zero.
--             local r8Trg = 0
--             local g8Trg = 0
--             local b8Trg = 0
--             local a8Trg = 0

--             if a8Src > 0 then
--                 -- Convert from a byte in [0, 255] to a real number
--                 -- in [0.0, 1.0].
--                 local r01Src = r8Src / 255.0
--                 local g01Src = g8Src / 255.0
--                 local b01Src = b8Src / 255.0
--                 local a01Src = a8Src / 255.0

--                 -- Convert from gamma to linear.
--                 local r01SrcLinear = r01Src ^ transfer
--                 local g01SrcLinear = g01Src ^ transfer
--                 local b01SrcLinear = b01Src ^ transfer

--                 -- Subtract reference color from source color.
--                 local r01DiffLinear = r01SrcLinear - r01RefLinear
--                 local g01DiffLinear = g01SrcLinear - g01RefLinear
--                 local b01DiffLinear = b01SrcLinear - b01RefLinear

--                 -- This is Euclidean distance. Other options, such as
--                 -- Manhattan, Minkowski and Chebyshev are possible.
--                 local dist = sqrt(r01DiffLinear * r01DiffLinear
--                     + g01DiffLinear * g01DiffLinear
--                     + b01DiffLinear * b01DiffLinear)

--                 -- Normalize distance to [0.0, 1.0] so it can work as a
--                 -- percent in linear interpolation (lerp):
--                 -- (1.0 - t) * origin + t * destination .
--                 local t = dist / maxEuclDist
--                 local u = 1.0 - t

--                 -- Lerp from source color to the target. Could also use
--                 -- abs(r01SrcLinear - r01RefLinear), or take the inverse
--                 -- of either source or reference, to change result.
--                 local r01TrgLinear = t * r01SrcLinear
--                     + u * max(0.0, r01SrcLinear - r01RefLinear)
--                 local g01TrgLinear = t * g01SrcLinear
--                     + u * max(0.0, g01SrcLinear - g01RefLinear)
--                 local b01TrgLinear = t * b01SrcLinear
--                     + u * max(0.0, b01SrcLinear - b01RefLinear)

--                 -- From linear to gamma.
--                 local r01Trg = r01TrgLinear ^ invTransfer
--                 local g01Trg = g01TrgLinear ^ invTransfer
--                 local b01Trg = b01TrgLinear ^ invTransfer
--                 local a01Trg = a01Src * (t ^ invTransfer)

--                 -- From a real number in [0.0, 1.0] to a byte in [0, 255].
--                 r8Trg = floor(min(max(r01Trg, 0.0), 1.0) * 255.0 + 0.5)
--                 g8Trg = floor(min(max(g01Trg, 0.0), 1.0) * 255.0 + 0.5)
--                 b8Trg = floor(min(max(b01Trg, 0.0), 1.0) * 255.0 + 0.5)
--                 a8Trg = floor(min(max(a01Trg, 0.0), 1.0) * 255.0 + 0.5)
--             end

--             targetBytesArr[1 + i4] = strchar(r8Trg)
--             targetBytesArr[2 + i4] = strchar(g8Trg)
--             targetBytesArr[3 + i4] = strchar(b8Trg)
--             targetBytesArr[4 + i4] = strchar(a8Trg)

--             i = i + 1
--         end

--         local targetImage = Image(sourceSpec)
--         targetImage.bytes = table.concat(targetBytesArr)
--         cel.image = targetImage

--         app.refresh()
--         dlg:close()
--     end
-- }

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