dofile("../../../support/aseutilities.lua")

local targets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local modes <const> = { "LAB", "LCH" }

local defaults <const> = {
    target = "ACTIVE",
    mode = "LCH",
    lScale = 20.0,
    aScale = 20.0,
    bScale = 20.0,
    cScale = 20.0,
    hScale = 30.0,
    printElapsed = false,
    updateSeedOnApply = false,
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

dlg:combobox {
    id = "mode",
    label = "Space:",
    focus = false,
    option = defaults.mode,
    options = modes,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local mode <const> = args.mode --[[@as string]]
        local isLch <const> = mode == "LCH"
        local isLab <const> = mode == "LAB"
        dlg:modify { id = "cScale", visible = isLch }
        dlg:modify { id = "hScale", visible = isLch }
        dlg:modify { id = "aScale", visible = isLab }
        dlg:modify { id = "bScale", visible = isLab }
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
    id = "aScale",
    label = "A:",
    min = 0,
    max = math.floor(0.5 + Lab.SR_MAX_CHROMA),
    value = defaults.aScale,
    visible = defaults.mode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "bScale",
    label = "B:",
    min = 0,
    max = math.floor(0.5 + Lab.SR_MAX_CHROMA),
    value = defaults.bScale,
    visible = defaults.mode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cScale",
    label = "C:",
    min = 0,
    max = math.floor(0.5 + Lab.SR_MAX_CHROMA),
    value = defaults.cScale,
    visible = defaults.mode == "LCH"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hScale",
    label = "H:",
    min = 0,
    max = 180,
    value = defaults.hScale,
    visible = defaults.mode == "LCH"
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
        local startTime <const> = os.clock()

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
        local mode <const> = args.mode
            or defaults.mode --[[@as string]]
        local seed <const> = args.seed
            or os.time() --[[@as integer]]
        local lScale <const> = args.lScale
            or defaults.lScale --[[@as number]]
        local aScale <const> = args.aScale
            or defaults.aScale --[[@as number]]
        local bScale <const> = args.bScale
            or defaults.bScale --[[@as number]]
        local cScale <const> = args.cScale
            or defaults.cScale --[[@as number]]
        local hScaleDeg <const> = args.hScale
            or defaults.hScale --[[@as number]]
        local updateSeedOnApply <const> = defaults.updateSeedOnApply --[[@as boolean]]

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
        local aScale2 <const> = aScale + aScale
        local bScale2 <const> = bScale + bScale
        local cScale2 <const> = cScale + cScale
        local hScale01 <const> = hScaleDeg / 360.0
        local hScale2 <const> = hScale01 + hScale01
        local useLch <const> = mode == "LCH"

        -- Cache methods used in loops.
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local labnew <const> = Lab.new
        local labToLch <const> = Lab.toLch
        local lchToLab <const> = Lab.fromLch
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

        app.transaction("Noise", function()
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

            ---@type table<integer, Lab>
            local srcToLabDict <const> = {}

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

                    local j = 0
                    while j < area do
                        local j4 <const> = j * 4
                        local srcAbgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local trgAbgr32 = 0

                        local srcLab = srcToLabDict[srcAbgr32]
                        if not srcLab then
                            srcLab = sRgbToLab(fromHex(srcAbgr32))
                            srcToLabDict[srcAbgr32] = srcLab
                        end

                        local tSrc <const> = srcLab.alpha
                        if tSrc > 0.0 then
                            local trgLab = srcLab

                            local lRng <const> = rng() * lScale2 - lScale
                            local lSrc <const> = srcLab.l
                            local lTrg <const> = lSrc + lRng

                            if useLch then
                                local cRng <const> = rng() * cScale2 - cScale
                                local hRng <const> = rng() * hScale2 - hScale01

                                local srcLch <const> = labToLch(srcLab)
                                local cSrc <const> = srcLch.c
                                local hSrc <const> = srcLch.h

                                local cTrg <const> = cSrc + cRng
                                local hTrg <const> = hSrc + hRng

                                trgLab = lchToLab(lTrg, cTrg, hTrg, tSrc)
                            else
                                local aRng <const> = rng() * aScale2 - aScale
                                local bRng <const> = rng() * bScale2 - bScale

                                local aTrg <const> = srcLab.a + aRng
                                local bTrg <const> = srcLab.b + bRng

                                trgLab = labnew(lTrg, aTrg, bTrg, tSrc)
                            end -- End color space check.

                            trgAbgr32 = toHex(labTosRgb(trgLab))
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
        end)

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        if updateSeedOnApply then
            local newSeed <const> = math.random(-2147483648, 2147483647)
            dlg:modify { id = "seed", text = string.format("%d", newSeed) }
        end

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