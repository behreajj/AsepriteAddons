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

QuantizeUtilities.dialogWidgets(dlg, true)

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
        local rLevels = args.rLevels --[[@as integer]]
        local gLevels = args.gLevels --[[@as integer]]
        local bLevels = args.bLevels --[[@as integer]]
        local aLevels = args.aLevels --[[@as integer]]

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

            aDelta = 1.0 / (aLevels - 1.0)
            bDelta = 1.0 / (bLevels - 1.0)
            gDelta = 1.0 / (gLevels - 1.0)
            rDelta = 1.0 / (rLevels - 1.0)
        else
            -- print("SIGNED")

            aqFunc = Utilities.quantizeSignedInternal
            bqFunc = Utilities.quantizeSignedInternal
            gqFunc = Utilities.quantizeSignedInternal
            rqFunc = Utilities.quantizeSignedInternal

            aLevels = aLevels - 1
            bLevels = bLevels - 1
            gLevels = gLevels - 1
            rLevels = rLevels - 1

            aDelta = 1.0 / aLevels
            bDelta = 1.0 / bLevels
            gDelta = 1.0 / gLevels
            rDelta = 1.0 / rLevels
        end

        -- print(string.format(
        --     "aLevels: %d, bLevels: %d, gLevels: %d, rLevels: %d",
        --     aLevels, bLevels, gLevels, rLevels))

        -- print(string.format(
        --     "aDelta: %.3f, bDelta: %.3f, gDelta: %.3f, rDelta: %.3f",
        --     aDelta, bDelta, gDelta, rDelta))

        local rgbColorMode <const> = ColorMode.RGB
        local floor <const> = math.floor
        local strfmt <const> = string.format
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local transact <const> = app.transaction

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

                    local aQtz <const> = aqFunc(a / 255.0, aLevels, aDelta)
                    local bQtz <const> = bqFunc(b / 255.0, bLevels, bDelta)
                    local gQtz <const> = gqFunc(g / 255.0, gLevels, gDelta)
                    local rQtz <const> = rqFunc(r / 255.0, rLevels, rDelta)

                    local a8 <const> = floor(aQtz * 255.0 + 0.5)
                    local b8 <const> = floor(bQtz * 255.0 + 0.5)
                    local g8 <const> = floor(gQtz * 255.0 + 0.5)
                    local r8 <const> = floor(rQtz * 255.0 + 0.5)

                    local aseQtz <const> = Color {
                        r = r8,
                        g = g8,
                        b = b8,
                        a = a8
                    }
                    palette:setColor(i, aseQtz)

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

        local i = 0
        local lenFrames <const> = #frames
        while i < lenFrames do
            i = i + 1
            local srcFrame <const> = frames[i]
            local srcCel <const> = srcLayer:cel(srcFrame)
            if srcCel then
                local srcImg = srcCel.image
                if isTilemap then
                    srcImg = tilesToImage(srcImg, tileSet, rgbColorMode)
                end

                -- Gather unique colors in image.
                ---@type table<integer, boolean>
                local srcDict <const> = {}
                local srcPxItr <const> = srcImg:pixels()
                for pixel in srcPxItr do
                    srcDict[pixel()] = true
                end

                -- Quantize colors, place in dictionary.
                ---@type table<integer, integer>
                local trgDict <const> = {}
                for k, _ in pairs(srcDict) do
                    local a <const> = (k >> 0x18) & 0xff
                    local b <const> = (k >> 0x10) & 0xff
                    local g <const> = (k >> 0x08) & 0xff
                    local r <const> = k & 0xff

                    -- Do not cache the division in a variable
                    -- as 1.0 / 255.0. It leads to precision errors
                    -- which impact alpha during unsigned quantize.
                    local aQtz <const> = aqFunc(a / 255.0, aLevels, aDelta)
                    local bQtz <const> = bqFunc(b / 255.0, bLevels, bDelta)
                    local gQtz <const> = gqFunc(g / 255.0, gLevels, gDelta)
                    local rQtz <const> = rqFunc(r / 255.0, rLevels, rDelta)

                    local a8 <const> = floor(aQtz * 255.0 + 0.5)
                    local b8 <const> = floor(bQtz * 255.0 + 0.5)
                    local g8 <const> = floor(gQtz * 255.0 + 0.5)
                    local r8 <const> = floor(rQtz * 255.0 + 0.5)

                    trgDict[k] = (a8 << 0x18)
                        | (b8 << 0x10)
                        | (g8 << 0x08)
                        |  r8
                end

                -- Clone image, replace color with quantized.
                local trgImg <const> = srcImg:clone()
                local trgPxItr <const> = trgImg:pixels()
                for pixel in trgPxItr do
                    pixel(trgDict[pixel()])
                end

                transact(
                    strfmt("Color Quantize %d", srcFrame + frameUiOffset),
                    function()
                        local trgCel = activeSprite:newCel(
                            trgLayer, srcFrame,
                            trgImg, srcCel.position)
                        trgCel.opacity = srcCel.opacity
                    end)
            end
        end

        if genPalette then
            local trgLenPalette <const> = math.min(
                65535, 1 + rLevels * gLevels * bLevels)
            local palettes <const> = activeSprite.palettes
            local frObj <const> = site.frame or activeSprite.frames[1]
            local palette <const> = AseUtilities.getPalette(frObj, palettes)

            local rgLevels <const> = rLevels * gLevels
            local rto8 <const> = 255.0 / (rLevels - 1.0)
            local gto8 <const> = 255.0 / (gLevels - 1.0)
            local bto8 <const> = 255.0 / (bLevels - 1.0)

            app.transaction("Create Palette", function()
                palette:resize(trgLenPalette)
                palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
                local k = 0
                while k < trgLenPalette - 1 do
                    local bx <const> = k // rgLevels
                    local m <const> = k - bx * rgLevels
                    local gx <const> = m // rLevels
                    local rx <const> = m % rLevels

                    local r8 <const> = floor(rx * rto8 + 0.5)
                    local g8 <const> = floor(gx * gto8 + 0.5)
                    local b8 <const> = floor(bx * bto8 + 0.5)

                    local c <const> = Color { r = r8, g = g8, b = b8, a = 255 }
                    palette:setColor(1 + k, c)
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