dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE" }
local delOptions <const> = { "DELETE_CELS", "DELETE_LAYER", "HIDE", "NONE" }

local defaults <const> = {
    target = "ACTIVE",
    delSrc = "NONE",
    maxUniques = 64
}

local dlg <const> = Dialog { title = "Separate Colors" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "delSrc",
    label = "Source:",
    option = defaults.delSrc,
    options = delOptions,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
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

        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))
        local lenFrIdcs <const> = #frIdcs

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace
        local alphaIndex <const> = spriteSpec.transparentColor

        local srcBpp = 4
        if colorMode == ColorMode.GRAY then
            srcBpp = 2
        elseif colorMode == ColorMode.INDEXED then
            srcBpp = 1
        end
        local packFmt <const> = "<I" .. srcBpp
        local layerNameFormat <const> = "%0" .. (srcBpp * 2) .. "x"

        local alphaIndexVerif <const> = (colorMode ~= ColorMode.INDEXED
                or (alphaIndex >= 0 and alphaIndex < 256))
            and alphaIndex or 0
        local alphaIndexPacked <const> = string.pack(
            packFmt, alphaIndexVerif)

        local lenUniques = 0
        ---@type table<integer, integer>
        local uniquesAllFrames <const> = {}
        ---@type table[]
        local packets <const> = {}

        -- Cache methods used in loop to local.
        local strpack <const> = string.pack
        local strunpack <const> = string.unpack
        local strsub <const> = string.sub
        local strfmt <const> = string.format
        local tconcat <const> = table.concat
        local transact <const> = app.transaction
        local createSpec <const> = AseUtilities.createSpec
        local tilesToImage <const> = AseUtilities.tileMapToImage

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)

            ---@type table<integer, integer[]>
            local uniquesPerFrame <const> = {}
            local wSrcImg = 0
            local xTlSrc = 0
            local yTlSrc = 0
            local celOpacity = 255

            if srcCel then
                local srcPos <const> = srcCel.position
                xTlSrc = srcPos.x
                yTlSrc = srcPos.y

                celOpacity = srcCel.opacity

                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                wSrcImg = srcImg.width
                local srcPxLen <const> = wSrcImg * srcImg.height
                local srcBytes <const> = srcImg.bytes

                local j = 0
                while j < srcPxLen do
                    local jbpp <const> = j * srcBpp
                    local pixel <const> = strunpack(packFmt,
                        strsub(srcBytes, 1 + jbpp, srcBpp + jbpp))

                    if pixel ~= alphaIndex then
                        if not uniquesAllFrames[pixel] then
                            lenUniques = lenUniques + 1
                            uniquesAllFrames[pixel] = lenUniques
                        end

                        local arr <const> = uniquesPerFrame[pixel]
                        if arr then
                            uniquesPerFrame[pixel][#arr + 1] = j
                        else
                            uniquesPerFrame[pixel] = { j }
                        end
                    end

                    j = j + 1
                end -- End pixels loop.
            end     -- End source cel check.

            packets[i] = {
                celOpacity = celOpacity,
                uniquesPerFrame = uniquesPerFrame,
                wSrcImg = wSrcImg,
                xTlSrc = xTlSrc,
                yTlSrc = yTlSrc,
            }
        end -- End frames loop.

        if lenUniques > defaults.maxUniques then
            local response <const> = app.alert {
                title = "Warning",
                text = {
                    string.format(
                        "This script will create %d layers.",
                        lenUniques),
                    "Do you wish to proceed?"
                },
                buttons = { "&YES", "&NO" }
            }

            if response == 2 then
                return
            end
        end

        local sepGroup <const> = activeSprite:newGroup()
        app.transaction("Set Group Props", function()
            sepGroup.name = srcLayer.name .. " Separated"
            sepGroup.parent = AseUtilities.getTopVisibleParent(srcLayer)
            sepGroup.isCollapsed = true

            sepGroup.blendMode = srcLayer.blendMode or BlendMode.NORMAL
            sepGroup.opacity = srcLayer.opacity or 255
        end)

        ---@type table<integer, Layer>
        local pixelLayerDict <const> = {}
        for pixel, stackIndex in pairs(uniquesAllFrames) do
            local trgLayer <const> = activeSprite:newLayer()
            pixelLayerDict[pixel] = trgLayer
            transact("Set Layer Props", function()
                trgLayer.name = strfmt(layerNameFormat, pixel)
                trgLayer.parent = sepGroup
                trgLayer.stackIndex = stackIndex

                if colorMode == ColorMode.RGB then
                    trgLayer.color = AseUtilities.hexToAseColor(
                        pixel & 0x80ffffff)
                end
            end)
        end

        local k = 0
        while k < lenFrIdcs do
            k = k + 1
            local frIdx <const> = frIdcs[k]
            local packet <const> = packets[k]

            local celOpacity <const> = packet.celOpacity
            local uniquesPerFrame <const> = packet.uniquesPerFrame
            local wSrcImg <const> = packet.wSrcImg
            local xTlSrc <const> = packet.xTlSrc
            local yTlSrc <const> = packet.yTlSrc

            for pixel, coords in pairs(uniquesPerFrame) do
                local xMin = 2147483647
                local yMin = 2147483647
                local xMax = -2147483648
                local yMax = -2147483648

                local lenCoords <const> = #coords
                local m = 0
                while m < lenCoords do
                    m = m + 1
                    local coord <const> = coords[m]
                    local xSrc <const> = coord % wSrcImg
                    local ySrc <const> = coord // wSrcImg

                    if xSrc < xMin then xMin = xSrc end
                    if ySrc < yMin then yMin = ySrc end
                    if xSrc > xMax then xMax = xSrc end
                    if ySrc > yMax then yMax = ySrc end
                end -- End coordinates loop.

                local wTrg <const> = 1 + xMax - xMin
                local hTrg <const> = 1 + yMax - yMin
                if wTrg > 0 and hTrg > 0 then
                    local pixelPacked <const> = strpack(packFmt, pixel)
                    local trgLayer <const> = pixelLayerDict[pixel]
                    local trgImg <const> = Image(createSpec(
                        wTrg, hTrg, colorMode, colorSpace, alphaIndex))

                    ---@type string[]
                    local trgByteArr <const> = {}
                    local trgPxLen <const> = wTrg * hTrg
                    local n = 0
                    while n < trgPxLen do
                        n = n + 1
                        trgByteArr[n] = alphaIndexPacked
                    end

                    local o = 0
                    while o < lenCoords do
                        o = o + 1
                        local coord <const> = coords[o]
                        local xTrg <const> = (coord % wSrcImg) - xMin
                        local yTrg <const> = (coord // wSrcImg) - yMin
                        local flat <const> = yTrg * wTrg + xTrg

                        -- Ideally, for large images, there'd be an option
                        -- to quantize the color that collected coordinates,
                        -- then here you would use the actual color from the
                        -- source image, not the quantized. Drawback is that
                        -- this could only work in RGB color mode.
                        trgByteArr[1 + flat] = pixelPacked
                    end
                    trgImg.bytes = tconcat(trgByteArr)

                    local trgPoint <const> = Point(
                        xTlSrc + xMin,
                        yTlSrc + yMin)
                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, trgPoint)
                    trgCel.opacity = celOpacity
                end -- End target size is valid.
            end     -- End pixel coordinates loop.
        end         -- End frames loop.

        AseUtilities.hideSource(
            activeSprite, srcLayer, frIdcs, delSrcStr)
        app.layer = sepGroup
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