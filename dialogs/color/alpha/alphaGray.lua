dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = { "ALPHA_TO_GRAY", "GRAY_TO_ALPHA" }
local rgbOptions <const> = { "GRAY", "COLOR", "SOURCE" }

local defaults <const> = {
    target = "ACTIVE",
    mode = "ALPHA_TO_GRAY",
    absOpaque = false,
    rgbOption = "SOURCE",
    trimCels = true,
}

local dlg <const> = Dialog { title = "Convert Alpha Gray" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "mode",
    label = "Mode:",
    option = defaults.mode,
    options = modes,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local rgbOption <const> = args.rgbOption --[[@as string]]

        local isAlphaToGray <const> = mode == "ALPHA_TO_GRAY"
        local isGrayToAlpha <const> = mode == "GRAY_TO_ALPHA"
        local isColor <const> = rgbOption == "COLOR"

        dlg:modify { id = "absOpaque", visible = isAlphaToGray }
        dlg:modify { id = "rgbOption", visible = isGrayToAlpha }
        dlg:modify { id = "maskColor", visible = isGrayToAlpha and isColor }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "absOpaque",
    label = "Include:",
    text = "&Mask",
    selected = defaults.absOpaque,
    focus = false,
    visible = defaults.mode == "ALPHA_TO_GRAY"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "rgbOption",
    label = "RGB:",
    option = defaults.rgbOption,
    options = rgbOptions,
    focus = false,
    visible = defaults.mode == "GRAY_TO_ALPHA",
    onchange = function()
        local args <const> = dlg.data
        local rgbOption <const> = args.rgbOption --[[@as string]]
        local isColor <const> = rgbOption == "COLOR"
        dlg:modify { id = "maskColor", visible = isColor }
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "maskColor",
    color = Color { r = 255, g = 255, b = 255, a = 255 },
    focus = false,
    visible = defaults.mode == "GRAY_TO_ALPHA"
        and defaults.rgbOption == "COLOR"
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
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

        -- Unpack sprite spec.
        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor

        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local absOpaque <const> = args.absOpaque --[[@as boolean]]
        local rgbOption <const> = args.rgbOption --[[@as string]]
        local maskColor <const> = args.maskColor --[[@as Color]]
        local trimCels <const> = args.trimCels --[[@as boolean]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = target == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or target))
        local lenFrIdcs <const> = #frIdcs

        local srcLayer = site.layer --[[@as Layer]]
        local removeSrcLayer = false

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
            removeSrcLayer = true
        else
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
                app.transaction("Flatten Group", function()
                    srcLayer = AseUtilities.flattenGroup(
                        activeSprite, srcLayer, frIdcs)
                    removeSrcLayer = true
                end)
            end
        end

        -- Check for tile map support.
        local isTileMap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTileMap then
            tileSet = srcLayer.tileset
        end

        local isAlphaToGray <const> = mode == "ALPHA_TO_GRAY"
        local isGrayToAlpha <const> = mode == "GRAY_TO_ALPHA"

        local absoVerif <const> = absOpaque and isAlphaToGray
        local blitToCanvas <const> = absoVerif

        local useSrcRgb <const> = rgbOption == "SOURCE"
        local useColor <const> = rgbOption == "COLOR"
        local maskBgr24 <const> = 0x00ffffff & AseUtilities.aseColorToHex(
            maskColor, ColorMode.RGB)

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local trim <const> = AseUtilities.trimImageAlpha
        local fromHex <const> = Rgb.fromHexAbgr32
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local floor <const> = math.floor
        local strbyte <const> = string.byte
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local transact <const> = app.transaction

        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            if isGrayToAlpha then
                trgLayer.name = srcLayerName .. " To Alpha"
            elseif isAlphaToGray then
                trgLayer.name = srcLayerName .. " To Gray"
            end
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
        end)

        ---@type table<integer, integer>
        local srcToTrg <const> = {}

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcImg = srcCel.image
                if isTileMap then
                    srcImg = tilesToImage(srcImg, tileSet, colorMode)
                end

                local srcPos <const> = srcCel.position
                local xtlSrc = srcPos.x
                local ytlSrc = srcPos.y

                if blitToCanvas then
                    local blit <const> = Image(spriteSpec)
                    blit:drawImage(srcImg, srcPos, 255, BlendMode.SRC)
                    srcImg = blit
                    xtlSrc = 0
                    ytlSrc = 0
                elseif trimCels then
                    local trimmed <const>,
                    xShift <const>,
                    yShift <const> = trim(srcImg, 0, alphaIndex)

                    srcImg = trimmed
                    xtlSrc = xtlSrc + xShift
                    ytlSrc = ytlSrc + yShift
                end

                local srcBytes <const> = srcImg.bytes
                local srcSpec <const> = srcImg.spec
                local wSrc <const> = srcSpec.width
                local hSrc <const> = srcSpec.height
                local area <const> = wSrc * hSrc

                ---@type string[]
                local trgByteArr <const> = {}

                if isGrayToAlpha then
                    local j = 0
                    while j < area do
                        local j4 <const> = j * 4
                        local srcAbgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local trgAbgr32 = 0

                        if srcToTrg[srcAbgr32] then
                            trgAbgr32 = srcToTrg[srcAbgr32]
                        else
                            local srcSrgb <const> = fromHex(srcAbgr32)
                            if srcSrgb.a > 0.0 then
                                local srcLab <const> = sRgbToLab(srcSrgb)
                                local l8 <const> = floor(srcLab.l * 2.55 + 0.5)
                                local trgBgr24 = 0
                                if l8 > 0 then
                                    if useSrcRgb then
                                        trgBgr24 = srcAbgr32 & 0x00ffffff
                                    elseif useColor then
                                        trgBgr24 = maskBgr24
                                    else
                                        trgBgr24 = l8 << 0x10 | l8 << 0x08 | l8
                                    end
                                end -- Light greater than zero.
                                trgAbgr32 = l8 << 0x18 | trgBgr24
                            end     -- Non zero alpha.
                        end         -- Dictionary check.

                        j = j + 1
                        trgByteArr[j] = strpack("<I4", trgAbgr32)
                    end -- End pixels loop.
                else
                    local j = 0
                    while j < area do
                        local a8 <const> = strbyte(srcBytes, 4 + j * 4)
                        local trgAbgr32 <const> = (absoVerif or a8 > 0)
                            and (0xff000000 | a8 << 0x10 | a8 << 0x08 | a8)
                            or 0
                        j = j + 1
                        trgByteArr[j] = strpack("<I4", trgAbgr32)
                    end -- End pixels loop.
                end     -- End mode block.

                local trgImg = Image(srcSpec)
                trgImg.bytes = tconcat(trgByteArr)

                local xtlTrg = xtlSrc
                local ytlTrg = ytlSrc
                if trimCels then
                    local trimmed <const>,
                    xShift <const>,
                    yShift <const> = trim(trgImg, 0, alphaIndex)

                    trgImg = trimmed
                    xtlTrg = xtlTrg + xShift
                    ytlTrg = ytlTrg + yShift
                end

                transact("Alpha Convert", function()
                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, Point(xtlTrg, ytlTrg))
                    trgCel.opacity = srcCel.opacity
                end) -- End transaction.
            end      -- End source cel exists.
        end          -- End frames loop.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

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