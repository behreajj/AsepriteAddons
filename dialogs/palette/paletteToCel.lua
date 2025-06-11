dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local areaTargets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local palTargets <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    areaTarget = "ACTIVE",
    palTarget = "ACTIVE",
    cvgLabRad = 175,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    printElapsed = false,
}

local dlg <const> = Dialog { title = "Palette To Cel" }

dlg:combobox {
    id = "areaTarget",
    label = "Target:",
    option = defaults.areaTarget,
    options = areaTargets,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palTarget",
    label = "Palette:",
    option = defaults.palTarget,
    options = palTargets,
    hexpand = false,
    onchange = function()
        local args <const> = dlg.data
        local palTarget <const> = args.palTarget --[[@as string]]
        dlg:modify {
            id = "palFile",
            visible = palTarget == "FILE"
        }
    end
}

dlg:newrow { always = false }

dlg:file {
    id = "palFile",
    filetypes = AseUtilities.FILE_FORMATS_PAL,
    filename = "*.*",
    basepath = app.fs.joinPath(app.fs.userConfigPath, "palettes"),
    visible = defaults.palTarget == "FILE"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgLabRad",
    label = "Radius:",
    min = 25,
    max = 242,
    value = defaults.cvgLabRad,
}

dlg:newrow { always = false }

dlg:slider {
    id = "octCapacity",
    label = "Capacity (2^n):",
    min = defaults.minCapacityBits,
    max = defaults.maxCapacityBits,
    value = defaults.octCapacityBits,
    visible = defaults.clampTo256
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

        local spriteSpec <const> = activeSprite.spec
        local colorMode <const> = spriteSpec.colorMode

        local cmRgb <const> = ColorMode.RGB
        local cmIsRgb <const> = colorMode == cmRgb
        if not cmIsRgb then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local args <const> = dlg.data
        local areaTarget <const> = args.areaTarget
            or defaults.areaTarget --[[@as string]]

        -- This needs to be done first, otherwise range will be lost.
        local isSelect <const> = areaTarget == "SELECTION"
        local frIdcs <const> = Utilities.flatArr2(
            AseUtilities.getFrames(activeSprite,
                isSelect and "ALL" or areaTarget))
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
        if isTileMap and srcLayer.tileset then
            tileSet = srcLayer.tileset
        end

        -- Cache global methods to local.
        local strfmt <const> = string.format
        local strpack <const> = string.pack
        local strsub <const> = string.sub
        local strunpack <const> = string.unpack
        local tconcat <const> = table.concat
        local transact <const> = app.transaction
        local tilesToImage <const> = AseUtilities.tileMapToImage
        local fromHex <const> = Rgb.fromHexAbgr32
        local octInsert <const> = Octree.insert
        local search <const> = Octree.queryInternal
        local sRgbToLab <const> = ColorUtilities.sRgbToSrLab2Internal
        local labHash <const> = Lab.toHexWrap64

        -- Select query radius according to color space.
        local cvgRad <const> = args.cvgLabRad
            or defaults.cvgLabRad --[[@as number]]
        local distFunc <const> = Lab.distCylindrical

        local palTarget <const> = args.palTarget
            or defaults.palTarget --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local hexesProfile <const>,
        hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palTarget, palFile, 0, 512, true)
        local lenHexesSrgb <const> = #hexesSrgb

        local octExpBits <const> = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local octCapacity = 1 << octExpBits
        local octree <const> = Octree.new(BoundsLab.srLab2(), octCapacity, 1)

        -- Convert source palette colors to points in an octree.
        -- Ignore colors with zero alpha.
        ---@type table<integer, integer>
        local ptToHexDict <const> = {}
        local h = 0
        while h < lenHexesSrgb do
            h = h + 1
            local hexSrgb <const> = hexesSrgb[h]
            if (hexSrgb & 0xff000000) ~= 0 then
                local pt <const> = sRgbToLab(fromHex(hexSrgb))
                ptToHexDict[labHash(pt)] = hexesProfile[h]
                octInsert(octree, pt)
            end
        end

        -- Create a new layer, srcLayer should not be a group,
        -- and thus have an opacity and blend mode.
        local trgLayer <const> = activeSprite:newLayer()
        app.transaction("Set Layer Props", function()
            local srcLayerName = "Layer"
            if #srcLayer.name > 0 then
                srcLayerName = srcLayer.name
            end
            trgLayer.name = string.format("%s %03d",
                srcLayerName, lenHexesSrgb)
            trgLayer.parent = AseUtilities.getTopVisibleParent(srcLayer)
            trgLayer.opacity = srcLayer.opacity or 255
            trgLayer.blendMode = srcLayer.blendMode
                or BlendMode.NORMAL
        end)

        -- Account for linked cels which may have the same image.
        ---@type table<integer, Image>
        local premadeTrgImgs <const> = {}

        -- Used in naming transactions by frame.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        local i = 0
        while i < lenFrIdcs do
            i = i + 1
            local frIdx <const> = frIdcs[i]
            local srcCel <const> = srcLayer:cel(frIdx)
            if srcCel then
                local origImg <const> = srcCel.image
                local srcImgId <const> = origImg.id
                local srcImg <const> = isTileMap
                    and tilesToImage(origImg, tileSet, cmRgb)
                    or origImg
                local trgImg = premadeTrgImgs[srcImgId]
                if not trgImg then
                    -- Get unique hexadecimal values from image.
                    -- There's no need to preserve order.
                    ---@type table<integer, integer[]>
                    local hexesUnique <const> = {}
                    local srcBytes <const> = srcImg.bytes
                    local srcSpec <const> = srcImg.spec
                    local lenSrc <const> = srcSpec.width * srcSpec.height

                    local j = 0
                    while j < lenSrc do
                        local j4 <const> = j * 4
                        local abgr32 <const> = strunpack("<I4", strsub(
                            srcBytes, 1 + j4, 4 + j4))
                        local idcs <const> = hexesUnique[abgr32]
                        if idcs then
                            idcs[#idcs + 1] = j
                        else
                            hexesUnique[abgr32] = { j }
                        end
                        j = j + 1
                    end

                    ---@type string[]
                    local trgBytesArr <const> = {}
                    for srcAbgr32, idcs in pairs(hexesUnique) do
                        local ptSrc <const> = sRgbToLab(fromHex(srcAbgr32))
                        local ptTrg <const>, _ <const> = search(
                            octree, ptSrc, cvgRad, distFunc)

                        local trgAbgr32 = 0x00000000
                        if ptTrg then
                            local hsh <const> = labHash(ptTrg)
                            if ptToHexDict[hsh] then
                                trgAbgr32 = ptToHexDict[hsh]
                            end
                        end

                        local compAbgr32 <const> = (srcAbgr32 & 0xff000000)
                            | (trgAbgr32 & 0x00ffffff)
                        local trgPack <const> = strpack("<I4", compAbgr32)

                        local lenIdcs <const> = #idcs
                        local k = 0
                        while k < lenIdcs do
                            k = k + 1
                            trgBytesArr[1 + idcs[k]] = trgPack
                        end
                    end

                    trgImg = Image(srcSpec)
                    trgImg.bytes = tconcat(trgBytesArr)
                    premadeTrgImgs[srcImgId] = trgImg
                end -- End create target image.

                transact(strfmt("PaletteToCel %d", frIdx + frameUiOffset), function()
                    local trgCel <const> = activeSprite:newCel(
                        trgLayer, frIdx, trgImg, srcCel.position)
                    trgCel.opacity = srcCel.opacity
                end)
            end -- End source cel exists.
        end     -- End frames loop.

        if removeSrcLayer then
            app.transaction("Delete Layer", function()
                activeSprite:deleteLayer(srcLayer)
            end)
        end

        app.layer = trgLayer
        app.refresh()

        local printElapsed <const> = args.printElapsed --[[@as boolean]]
        if printElapsed then
            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
            app.alert {
                title = "Diagnostic",
                text = {
                    string.format("Start: %.2f", startTime),
                    string.format("End: %.2f", endTime),
                    string.format("Elapsed: %.6f", elapsed),
                    string.format("Colors: %d", lenHexesSrgb),
                }
            }
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