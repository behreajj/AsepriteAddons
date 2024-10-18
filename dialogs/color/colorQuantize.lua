dofile("../../support/aseutilities.lua")
dofile("../../support/quantizeutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "PALETTE", "RANGE" }

local defaults <const> = {
    target = "ACTIVE",
    genPalette = false
}

local dlg <const> = Dialog { title = "Quantize RGB" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target
        local notPalette <const> = target ~= "PALETTE"
        dlg:modify { id = "genPalette", visible = notPalette }
    end
}

dlg:newrow { always = false }

QuantizeUtilities.dialogWidgets(dlg, true, true)

dlg:check {
    id = "genPalette",
    label = "Create:",
    text = "Palette",
    selected = defaults.genPalette,
    visible = defaults.target ~= "PALETTE",
    focus = false
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        -- Early returns.
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local genPalette <const> = args.genPalette --[[@as boolean]]

        local method <const> = args.method --[[@as string]]
        local rLevels <const> = args.rLevels --[[@as integer]]
        local gLevels <const> = args.gLevels --[[@as integer]]
        local bLevels <const> = args.bLevels --[[@as integer]]
        local aLevels <const> = args.aLevels --[[@as integer]]

        local rLvVrf = rLevels
        local gLvVrf = gLevels
        local bLvVrf = bLevels
        local aLvVrf = aLevels

        local aDelta = 0.0
        local bDelta = 0.0
        local gDelta = 0.0
        local rDelta = 0.0

        local aqFunc = nil
        local bqFunc = nil
        local gqFunc = nil
        local rqFunc = nil

        if method == "UNSIGNED" then
            -- print("UNSIGNED")

            aqFunc = Utilities.quantizeUnsignedInternal
            bqFunc = Utilities.quantizeUnsignedInternal
            gqFunc = Utilities.quantizeUnsignedInternal
            rqFunc = Utilities.quantizeUnsignedInternal

            aDelta = 1.0 / (aLvVrf - 1.0)
            bDelta = 1.0 / (bLvVrf - 1.0)
            gDelta = 1.0 / (gLvVrf - 1.0)
            rDelta = 1.0 / (rLvVrf - 1.0)
        else
            -- print("SIGNED")

            aqFunc = Utilities.quantizeSignedInternal
            bqFunc = Utilities.quantizeSignedInternal
            gqFunc = Utilities.quantizeSignedInternal
            rqFunc = Utilities.quantizeSignedInternal

            aLvVrf = aLvVrf - 1
            bLvVrf = bLvVrf - 1
            gLvVrf = gLvVrf - 1
            rLvVrf = rLvVrf - 1

            aDelta = 1.0 / aLvVrf
            bDelta = 1.0 / bLvVrf
            gDelta = 1.0 / gLvVrf
            rDelta = 1.0 / rLvVrf
        end

        -- print(string.format(
        --     "aLevels: %d, bLevels: %d, gLevels: %d, rLevels: %d",
        --     aLevels, bLevels, gLevels, rLevels))

        -- print(string.format(
        --     "aDelta: %.3f, bDelta: %.3f, gDelta: %.3f, rDelta: %.3f",
        --     aDelta, bDelta, gDelta, rDelta))

        local rgbColorMode <const> = ColorMode.RGB
        local floor <const> = math.floor

        if target == "PALETTE" then
            local palettes <const> = activeSprite.palettes
            local frObj <const> = site.frame or activeSprite.frames[1]
            local palette <const> = AseUtilities.getPalette(frObj, palettes)
            local lenPalette <const> = #palette

            app.transaction("Color Quantize Palette", function()
                local i = 0
                while i < lenPalette do
                    local aseColor <const> = palette:getColor(i)

                    local a <const> = aseColor.alpha
                    local b <const> = aseColor.blue
                    local g <const> = aseColor.green
                    local r <const> = aseColor.red

                    local aQtz <const> = aqFunc(a / 255.0, aLvVrf, aDelta)
                    local bQtz <const> = bqFunc(b / 255.0, bLvVrf, bDelta)
                    local gQtz <const> = gqFunc(g / 255.0, gLvVrf, gDelta)
                    local rQtz <const> = rqFunc(r / 255.0, rLvVrf, rDelta)

                    palette:setColor(i, Color {
                        r = floor(rQtz * 255.0 + 0.5),
                        g = floor(gQtz * 255.0 + 0.5),
                        b = floor(bQtz * 255.0 + 0.5),
                        a = floor(aQtz * 255.0 + 0.5)
                    })

                    i = i + 1
                end
            end)

            app.refresh()
            return
        end

        local colorMode <const> = activeSprite.colorMode
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

        if srcLayer.isGroup then
            app.alert {
                title = "Error",
                text = "Group layers are not supported."
            }
            return
        end

        -- Check for tile map support.
        local isTilemap <const> = srcLayer.isTilemap
        local tileSet = nil
        if isTilemap then
            tileSet = srcLayer.tileset
        end

        local frames <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite, target))

        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format(
                "%s Quantized R%02d G%02d B%02d A%02d",
                srcLayerName,
                rLevels, gLevels, bLevels, aLevels)
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.blendMode = srcLayer.blendMode
                or BlendMode.NORMAL
        end)

        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local transact <const> = app.transaction

        local i = 0
        local lenFrames <const> = #frames
        while i < lenFrames do
            i = i + 1
            local frIdx <const> = frames[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                local srcSpec <const> = srcImg.spec
                local areaImg <const> = srcSpec.width * srcSpec.height
                local srcBytes <const> = srcImg.bytes

                ---@type table<integer, integer>
                local srcToTrgDict <const> = {}
                ---@type string[]
                local trgBytesArr <const> = {}

                local j = 0
                while j < areaImg do
                    local j4 <const> = j * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    local trgAbgr32 = srcToTrgDict[srcAbgr32]
                    if not trgAbgr32 then
                        local a8Src <const> = (srcAbgr32 >> 0x18) & 0xff
                        local b8Src <const> = (srcAbgr32 >> 0x10) & 0xff
                        local g8Src <const> = (srcAbgr32 >> 0x08) & 0xff
                        local r8Src <const> = srcAbgr32 & 0xff

                        -- Do not cache the division in a variable
                        -- as 1.0 / 255.0. It leads to precision errors
                        -- which impact alpha during unsigned quantize.
                        local aq <const> = aqFunc(a8Src / 255.0, aLvVrf, aDelta)
                        local bq <const> = bqFunc(b8Src / 255.0, bLvVrf, bDelta)
                        local gq <const> = gqFunc(g8Src / 255.0, gLvVrf, gDelta)
                        local rq <const> = rqFunc(r8Src / 255.0, rLvVrf, rDelta)

                        local a8Trg <const> = floor(aq * 255.0 + 0.5)
                        local b8Trg <const> = floor(bq * 255.0 + 0.5)
                        local g8Trg <const> = floor(gq * 255.0 + 0.5)
                        local r8Trg <const> = floor(rq * 255.0 + 0.5)

                        trgAbgr32 = a8Trg << 0x18
                            | b8Trg << 0x10
                            | g8Trg << 0x08
                            | r8Trg
                        srcToTrgDict[srcAbgr32] = trgAbgr32
                    end

                    j = j + 1
                    trgBytesArr[j] = strpack("<I4", trgAbgr32)
                end

                local trgImg <const> = Image(srcSpec)
                trgImg.bytes = tconcat(trgBytesArr)

                transact(
                    strfmt("Color Quantize %d", frIdx + frameUiOffset),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, frIdx,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        if genPalette then
            AseUtilities.preserveForeBack()

            local palettes <const> = activeSprite.palettes
            local frObj <const> = site.frame or activeSprite.frames[1]
            local palette <const> = AseUtilities.getPalette(frObj, palettes)

            local grid <const> = Clr.gridsRgb(rLevels, gLevels, bLevels, 1.0)
            local clrToAseColor <const> = AseUtilities.clrToAseColor

            local trgLenPalette <const> = math.min(
                65535, rLevels * gLevels * bLevels)

            app.transaction("Create Palette", function()
                palette:resize(trgLenPalette)
                local k = 0
                while k < trgLenPalette do
                    palette:setColor(k, clrToAseColor(grid[1 + k]))
                    k = k + 1
                end
            end)
        end

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