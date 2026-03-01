dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }

local defaults <const> = {
    target = "ACTIVE",
    lScale = 20.0,
    cScale = 20.0,
    hScale = 30.0,
}

local dlg <const> = Dialog { title = "Lch Noise" }

dlg:combobox {
    id = "target",
    label = "Target:",
    focus = false,
    option = defaults.target,
    options = targets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:number {
    id = "seed",
    label = "Seed:",
    text = string.format("%d", os.time()),
    decimals = 0,
    focus = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "genSeed",
    text = "&GENERATE",
    focus = false,
    onclick = function()
        local seed <const> = math.random(-2147483648, 2147483647)
        dlg:modify { id = "seed", text = string.format("%d", seed) }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lScale",
    label = "L:",
    min = 0,
    max = 100,
    value = defaults.lScale
}

dlg:newrow { always = false }

dlg:slider {
    id = "cScale",
    label = "C:",
    min = 0,
    max = math.floor(0.5 + Lab.SR_MAX_CHROMA),
    value = defaults.cScale
}

dlg:newrow { always = false }

dlg:slider {
    id = "hScale",
    label = "H:",
    min = 0,
    max = 180,
    value = defaults.hScale
}

dlg:newrow { always = false }

dlg:button {
    id = "adjustButton",
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

        local activeSpec <const> = activeSprite.spec
        local colorMode <const> = activeSpec.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]
        local seed <const> = args.seed
            or os.time() --[[@as integer]]
        local lScale <const> = args.lScale
            or defaults.lScale --[[@as number]]
        local cScale <const> = args.cScale
            or defaults.cScale --[[@as number]]
        local hScaleDeg <const> = args.hScale
            or defaults.hScale --[[@as number]]

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

        math.randomseed(seed)
        local lScale2 <const> = lScale + lScale
        local cScale2 <const> = cScale + cScale
        local hScale01 <const> = hScaleDeg / 360.0
        local hScale2 <const> = hScale01 + hScale01

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local labToLch <const> = Lab.toLch
        local lchToLab <const> = Lab.fromLchInternal
        local fromHex <const> = Rgb.fromHexAbgr32
        local toHex <const> = Rgb.toHex
        local labTosRgb <const> = ColorUtilities.srLab2TosRgb
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local max <const> = math.max
        local rng <const> = math.random
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat

        -- app.transaction("Noise", function()

        local trgLayer <const> = activeSprite:newLayer()
        local srcLayerName = "Layer"
        if #srcLayer.name > 0 then
            srcLayerName = srcLayer.name
        end
        trgLayer.name = string.format(
            "%s Noise", srcLayerName)
        trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
        trgLayer.opacity = srcLayer.opacity or 255
        -- Do not copy blend mode, it only confuses things.

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local srcImg = srcCel.image

                if isTileMap then
                    srcImg = tilesToImage(srcImg, tileSet, ColorMode.RGB)
                end

                local srcBytes <const> = srcImg.bytes
                local srcSpec <const> = srcImg.spec
                local srcWidth <const> = srcSpec.width
                local srcHeight <const> = srcSpec.height
                local area <const> = srcWidth * srcHeight

                ---@type string[]
                local trgByteArr <const> = {}

                ---@type table<integer, {l: number, c: number, h: number, a: number}>
                local srcToLchDict <const> = {}

                local j = 0
                while j < area do
                    local j4 <const> = j * 4
                    local srcAbgr32 <const> = strunpack("<I4", strsub(
                        srcBytes, 1 + j4, 4 + j4))
                    local trgAbgr32 = 0

                    local srcLch = srcToLchDict[srcAbgr32]
                    if not srcLch then
                        srcLch = labToLch(sRgbToLab(fromHex(srcAbgr32)))
                        srcToLchDict[srcAbgr32] = srcLch
                    end

                    if srcLch.a > 0.0 then
                        local lRng <const> = rng() * lScale2 - lScale
                        local cRng <const> = rng() * cScale2 - cScale
                        local hRng <const> = rng() * hScale2 - hScale01

                        local lSrc <const> = srcLch.l
                        local cSrc <const> = srcLch.c
                        local hSrc <const> = srcLch.h

                        local lTrg <const> = lSrc + lRng
                        local cTrg <const> = max(cSrc + cRng, 0.0)
                        local hTrg <const> = cTrg > 0.0
                            and hSrc + hRng
                            or ((1.0 - lTrg * 0.01) * Lab.SR_HUE_SHADOW
                                + lTrg * 0.01 * (1.0 + Lab.SR_HUE_LIGHT)
                                + hRng)

                        trgAbgr32 = toHex(labTosRgb(lchToLab(
                            lTrg,
                            cTrg,
                            hTrg,
                            srcLch.a)))
                    end -- Non zero alpha.

                    j = j + 1
                    trgByteArr[j] = strpack("<I4", trgAbgr32)
                end -- End pixels loop.

                local trgImg <const> = Image(srcSpec)
                trgImg.bytes = tconcat(trgByteArr)

                local trgCel <const> = activeSprite:newCel(
                    trgLayer, frIdx, trgImg, srcCel.position)
                trgCel.opacity = srcCel.opacity
            end -- End source cel exists.
        end     -- End frames loop.


        -- end)

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