dofile("../../support/aseutilities.lua")
dofile("../../support/octree.lua")

local areaTargets <const> = { "ACTIVE", "ALL", "RANGE", "SELECTION" }
local colorSpaces <const> = { "LINEAR_RGB", "S_RGB", "SR_LAB_2" }
local palTargets <const> = { "ACTIVE", "FILE" }

local defaults <const> = {
    areaTarget = "ACTIVE",
    palTarget = "ACTIVE",
    cvgLabRad = 175,
    cvgNormRad = 120,
    octCapacityBits = 4,
    minCapacityBits = 2,
    maxCapacityBits = 16,
    printElapsed = false,
    clrSpacePreset = "LINEAR_RGB"
}

---@param preset string
---@return Bounds3
local function boundsFromPreset(preset)
    if preset == "CIE_LAB"
        or preset == "SR_LAB_2" then
        return Bounds3.lab()
    else
        return Bounds3.unitCubeUnsigned()
    end
end

---@param clr Clr
---@return Vec3
local function clrToVec3lRgb(clr)
    local lin <const> = Clr.sRgbTolRgbInternal(clr)
    return Vec3.new(lin.r, lin.g, lin.b)
end

---@param clr Clr
---@return Vec3
local function clrToVec3sRgb(clr)
    return Vec3.new(clr.r, clr.g, clr.b)
end

---@param clr Clr
---@return Vec3
local function clrToVec3SrLab2(clr)
    local lab <const> = Clr.sRgbToSrLab2(clr)
    return Vec3.new(lab.a, lab.b, lab.l)
end

---@param preset string
---@return fun(clr: Clr): Vec3
local function clrToV3FuncFromPreset(preset)
    if preset == "LINEAR_RGB" then
        return clrToVec3lRgb
    elseif preset == "SR_LAB_2" then
        return clrToVec3SrLab2
    else
        return clrToVec3sRgb
    end
end

local dlg <const> = Dialog { title = "Palette To Cel" }

dlg:combobox {
    id = "areaTarget",
    label = "Target:",
    option = defaults.areaTarget,
    options = areaTargets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "palTarget",
    label = "Palette:",
    option = defaults.palTarget,
    options = palTargets,
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
    open = true,
    visible = defaults.palTarget == "FILE"
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrSpacePreset",
    label = "Color Space:",
    option = defaults.clrSpacePreset,
    options = colorSpaces,
    onchange = function()
        local args <const> = dlg.data
        local preset <const> = args.clrSpacePreset --[[@as string]]
        local isLab <const> = preset == "CIE_LAB"
            or preset == "SR_LAB_2"
        dlg:modify {
            id = "cvgLabRad",
            visible = isLab
        }
        dlg:modify {
            id = "cvgNormRad",
            visible = not isLab
        }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgLabRad",
    label = "Radius:",
    min = 25,
    max = 242,
    value = defaults.cvgLabRad,
    visible = defaults.clrSpacePreset == "CIE_LAB"
        or defaults.clrSpacePreset == "SR_LAB_2"
}

dlg:newrow { always = false }

dlg:slider {
    id = "cvgNormRad",
    label = "Radius:",
    min = 5,
    max = 174,
    value = defaults.cvgNormRad,
    visible = defaults.clrSpacePreset ~= "CIE_LAB"
        and defaults.clrSpacePreset ~= "SR_LAB_2"
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
    selected = defaults.printElapsed
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

        -- If isSelect is true, then a new layer will be created.
        local srcLayer = site.layer --[[@as Layer]]

        if isSelect then
            AseUtilities.filterCels(activeSprite, srcLayer, frIdcs, "SELECTION")
            srcLayer = activeSprite.layers[#activeSprite.layers]
        else
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

            if srcLayer.isReference then
                app.alert {
                    title = "Error",
                    text = "Reference layers are not supported."
                }
                return
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
        local fromHex <const> = Clr.fromHexAbgr32
        local octInsert <const> = Octree.insert
        local search <const> = Octree.queryInternal
        local v3Hash <const> = Vec3.hashCode

        -- Select which conversion functions to use.
        local clrSpacePreset <const> = args.clrSpacePreset
            or defaults.clrSpacePreset --[[@as string]]
        local octBounds <const> = boundsFromPreset(clrSpacePreset)
        local clrV3Func <const> = clrToV3FuncFromPreset(clrSpacePreset)

        -- Select query radius according to color space.
        local cvgRad = 0.0
        local distFunc = Vec3.distEuclidean
        if clrSpacePreset == "CIE_LAB"
            or clrSpacePreset == "SR_LAB_2" then
            cvgRad = args.cvgLabRad
                or defaults.cvgLabRad --[[@as number]]

            -- See https://www.wikiwand.com/en/
            -- Color_difference#/Other_geometric_constructions
            distFunc = function(a, b)
                local da <const> = b.x - a.x
                local db <const> = b.y - a.y
                return math.sqrt(da * da + db * db)
                    + math.abs(b.z - a.z)
            end
        else
            cvgRad = args.cvgNormRad
                or defaults.cvgNormRad --[[@as number]]
            cvgRad = cvgRad * 0.01
        end

        local palTarget <const> = args.palTarget
            or defaults.palTarget --[[@as string]]
        local palFile <const> = args.palFile --[[@as string]]
        local hexesProfile <const>, hexesSrgb <const> = AseUtilities.asePaletteLoad(
            palTarget, palFile, 0, 512, true)
        local lenHexesSrgb <const> = #hexesSrgb

        local octExpBits <const> = args.octCapacity
            or defaults.octCapacityBits --[[@as integer]]
        local octCapacity = 1 << octExpBits
        local octree <const> = Octree.new(octBounds, octCapacity, 1)

        -- Convert source palette colors to points in an octree.
        -- Ignore colors with zero alpha.
        ---@type table<integer, integer>
        local ptToHexDict <const> = {}
        local h = 0
        while h < lenHexesSrgb do
            h = h + 1
            local hexSrgb <const> = hexesSrgb[h]
            if (hexSrgb & 0xff000000) ~= 0 then
                local pt <const> = clrV3Func(fromHex(hexSrgb))
                ptToHexDict[v3Hash(pt)] = hexesProfile[h]
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
            trgLayer.name = string.format("%s %s %03d",
                srcLayerName, clrSpacePreset, lenHexesSrgb)
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
                        local ptSrc <const> = clrV3Func(fromHex(srcAbgr32))
                        local ptTrg <const>, _ <const> = search(
                            octree, ptSrc, cvgRad, distFunc)

                        local trgAbgr32 = 0x00000000
                        if ptTrg then
                            local hsh <const> = v3Hash(ptTrg)
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

        if isSelect then
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