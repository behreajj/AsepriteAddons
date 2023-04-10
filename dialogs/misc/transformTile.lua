dofile("../../support/aseutilities.lua")

local targets = { "TILES", "TILE_MAP" }

local defaults = {
    target = "TILES",
    inPlace = true
}

local function transformTiles(
    preset, containedTiles, inPlace,
    activeSprite, tileSet)
    local transactionName = "Transform Tiles"
    local transformFunc = nil
    if preset == "90" then
        transactionName = "Rotate Tiles 90"
        transformFunc = AseUtilities.rotateImage90
    elseif preset == "180" then
        transactionName = "Rotate Tiles 180"
        transformFunc = AseUtilities.rotateImage180
    elseif preset == "270" then
        transactionName = "Rotate Tiles 270"
        transformFunc = AseUtilities.rotateImage270
    elseif preset == "FLIP_H" then
        transactionName = "Flip Tiles H"
        transformFunc = AseUtilities.flipImageHoriz
    elseif preset == "FLIP_V" then
        transactionName = "Flip Tiles V"
        transformFunc = AseUtilities.flipImageVert
    end

    ---@type table<integer, integer>
    local srcToTrgIdcs = {}

    app.transaction(transactionName, function()
        if inPlace then
            for _, tile in pairs(containedTiles) do
                local trgImage = transformFunc(tile.image)
                tile.image = trgImage
            end
        else
            for srcIdx, srcTile in pairs(containedTiles) do
                local srcImage = srcTile.image
                if srcImage:isEmpty() then
                    srcToTrgIdcs[srcIdx] = 0
                else
                    local trgTile = activeSprite:newTile(tileSet)
                    trgTile.image = transformFunc(srcImage)
                    srcToTrgIdcs[srcIdx] = trgTile.index
                end
            end
        end
    end)

    return srcToTrgIdcs
end

local function transformCel(dialog, preset)
    local activeSprite = app.activeSprite
    if not activeSprite then return end

    local activeFrame = app.activeFrame --[[@as Frame]]
    if not activeFrame then return end

    local activeLayer = app.activeLayer
    if not activeLayer.isVisible then return end
    if not activeLayer.isEditable then return end
    if not activeLayer.isTilemap then return end
    local tileSet = activeLayer.tileset

    local activeCel = activeLayer:cel(activeFrame)
    if not activeCel then return end

    local args = dialog.data
    local target = args.target or defaults.target --[[@as string]]
    local inPlace = args.inPlace --[[@as boolean]]

    local celPos = activeCel.position
    local xtlCel = celPos.x
    local ytlCel = celPos.y

    local containedTiles = {}
    ---@type table<integer, Tile>
    if target == "TILE_MAP" then
        containedTiles = AseUtilities.getUniqueTiles(
            activeCel.image, tileSet)

        local tileGrid = tileSet.grid --[[@as Grid]]
        local tileDim = tileGrid.tileSize --[[@as Size]]
        local wTile = tileDim.width
        local hTile = tileDim.height

        local transactionName = "Transform Map"
        local transformFunc = nil
        local updateCelPos = false
        if preset == "90" then
            if wTile ~= hTile then
                app.alert {
                    title = "Error",
                    text = "Tile size is nonuniform."
                }
                return
            end
            transactionName = "Rotate Map 90"
            transformFunc = AseUtilities.rotateImage90
            updateCelPos = true
        elseif preset == "180" then
            transactionName = "Rotate Map 180"
            transformFunc = AseUtilities.rotateImage180
        elseif preset == "270" then
            if wTile ~= hTile then
                app.alert {
                    title = "Error",
                    text = "Tile size is nonuniform."
                }
                return
            end
            transactionName = "Rotate Map 270"
            transformFunc = AseUtilities.rotateImage270
            updateCelPos = true
        elseif preset == "FLIP_H" then
            transactionName = "Flip Map H"
            transformFunc = AseUtilities.flipImageHoriz
        elseif preset == "FLIP_V" then
            transactionName = "Flip Map V"
            transformFunc = AseUtilities.flipImageVert
        end

        app.transaction(transactionName, function()
            local srcMap = activeCel.image
            local trgMap = transformFunc(srcMap)

            if updateCelPos then
                local wSrcPixels = srcMap.width * wTile
                local hSrcPixels = srcMap.height * hTile
                local wSrcHalf = wSrcPixels // 2
                local hSrcHalf = hSrcPixels // 2

                local wTrgPixels = trgMap.width * wTile
                local hTrgPixels = trgMap.height * hTile
                local wTrgHalf = wTrgPixels // 2
                local hTrgHalf = hTrgPixels // 2

                activeCel.position = Point(
                    xtlCel + wSrcHalf - wTrgHalf,
                    ytlCel + hSrcHalf - hTrgHalf)
            end

            activeCel.image = trgMap
        end)
    else
        local selection = AseUtilities.getSelection(activeSprite)
        containedTiles = AseUtilities.getSelectedTiles(
            activeCel.image, tileSet, selection,
            xtlCel, ytlCel)
    end

    local srcToTrgIdcs = transformTiles(
        preset, containedTiles, inPlace,
        activeSprite, tileSet)

    if not inPlace then
        local pxTilei = app.pixelColor.tileI
        local pxTilef = app.pixelColor.tileF
        local pxTileCompose = app.pixelColor.tile
        local trgMap = activeCel.image:clone()
        local trgItr = trgMap:pixels()
        for mapEntry in trgItr do
            local tileData = mapEntry()
            local srcIdx = pxTilei(tileData)
            local srcFlags = pxTilef(tileData)
            if srcToTrgIdcs[srcIdx] then
                local trgIdx = srcToTrgIdcs[srcIdx]
                mapEntry(pxTileCompose(trgIdx, srcFlags))
            end
        end

        app.transaction("Update Map", function()
            activeCel.image = trgMap
        end)
    end

    app.refresh()
end

local dlg = Dialog { title = "Edit Tile" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:check {
    id = "inPlace",
    label = "Edit:",
    text = "In &Place",
    selected = defaults.inPlace,
}

dlg:newrow { always = false }

dlg:button {
    id = "rotate90Button",
    label = "Rotate:",
    text = "&90",
    focus = false,
    onclick = function()
        transformCel(dlg, "90")
    end
}

dlg:button {
    id = "rotate180Button",
    text = "&180",
    focus = false,
    onclick = function()
        transformCel(dlg, "180")
    end
}

dlg:button {
    id = "rotate270Button",
    text = "&270",
    focus = false,
    onclick = function()
        transformCel(dlg, "270")
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "fliphButton",
    label = "Flip:",
    text = "&H",
    focus = false,
    onclick = function()
        transformCel(dlg, "FLIP_H")
    end
}

dlg:button {
    id = "flipvButton",
    text = "&V",
    focus = false,
    onclick = function()
        transformCel(dlg, "FLIP_V")
    end
}

dlg:separator { id = "sortSep" }

dlg:button {
    id = "reorderButton",
    label = "Tile Set:",
    text = "&SORT",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local activeFrame = app.activeFrame --[[@as Frame]]
        if not activeFrame then return end

        local activeLayer = app.activeLayer
        if not activeLayer.isVisible then return end
        if not activeLayer.isEditable then return end
        if not activeLayer.isTilemap then return end
        local tileSet = activeLayer.tileset
        local lenTileSet = #tileSet

        local activeCel = activeLayer:cel(activeFrame)
        if not activeCel then return end

        -- Cache methods used in a for loop.
        local pxTilei = app.pixelColor.tileI
        local pxTilef = app.pixelColor.tileF
        local pxTileCompose = app.pixelColor.tile

        --Contains the first usage of a tile in the set
        --by the active map. Ignores index 0. Because all
        --tile maps in the layer have to be updated later,
        --not just the active map, no point in storing
        --an array of all visitations as dict value.
        ---@type table<integer, integer>
        local visited = {}

        local srcMap = activeCel.image
        local srcWidth = srcMap.width
        local srcItr = srcMap:pixels()
        for mapEntry in srcItr do
            local flatIdx = mapEntry.x + mapEntry.y * srcWidth
            local srcTsIdx = pxTilei(mapEntry())
            if srcTsIdx > 0 and srcTsIdx < lenTileSet
                and (not visited[srcTsIdx]) then
                visited[srcTsIdx] = flatIdx
            end
        end

        -- Convert dictionary to a set.
        ---@type integer[]
        local sortedTsIdcs = {}
        for srcTsIdx, _ in pairs(visited) do
            sortedTsIdcs[#sortedTsIdcs + 1] = srcTsIdx
        end

        -- Sort set according to visited flat index.
        table.sort(sortedTsIdcs, function(a, b)
            return visited[a] < visited[b]
        end)

        -- Tile set index zero is unaffected by the sort.
        -- Same with tiles in the tile set  not visited by the map.
        -- Tile set indexing begins at 0, so it goes to len - 1.
        table.insert(sortedTsIdcs, 1, 0)
        local h = 0
        while h < lenTileSet - 1 do
            h = h + 1
            if not visited[h] then
                sortedTsIdcs[#sortedTsIdcs + 1] = h
            end
        end

        -- Clone the tiles from the tile set.
        -- The blank image at 0 is included so that the
        -- array doesn't have a nil at its first index.
        -- Any other relevant data from a tile would
        -- also be cloned at this stage, e.g., user data.
        ---@type table[]
        local sortedTsPackets = {}

        -- Flip the relationship between old (unsorted) and
        -- new (sorted) indices so that other tile maps can
        -- easily be updated.
        ---@type integer[]
        local oldToNew = {}

        local i = 0
        while i < lenTileSet do
            i = i + 1
            local tsIdx = sortedTsIdcs[i]
            local tile = tileSet:tile(tsIdx)
            local packet = {
                -- color = tile.color,
                -- data = tile.data,
                image = tile.image:clone()
            }
            sortedTsPackets[i] = packet
            oldToNew[1 + sortedTsIdcs[i]] = i
        end

        -- Reassign sorted images to tile set tiles.
        app.transaction(
            "Sort Tile Set", function()
                local j = 1
                while j < lenTileSet do
                    j = j + 1
                    local tile = tileSet:tile(j - 1)
                    local packet = sortedTsPackets[j]
                    -- tile.color = packet.color
                    -- tile.data = packet.data
                    tile.image = packet.image
                end
            end)

        local frIdcs = AseUtilities.frameObjsToIdcs(
            activeSprite.frames)
        local uniqueCels = AseUtilities.getUniqueCelsFromLeaves(
            activeSprite, { activeLayer }, frIdcs, {})

        local lenUniques = #uniqueCels
        local k = 0
        while k < lenUniques do
            k = k + 1
            local uniqueCel = uniqueCels[k]
            local uniqueMap = uniqueCel.image
            local reordered = uniqueMap:clone()
            local reoItr = reordered:pixels()
            for mapEntry in reoItr do
                local rawData = mapEntry()
                local oldTsIdx = pxTilei(rawData)
                local flags = pxTilef(rawData)
                if oldTsIdx > 0 and oldTsIdx < lenTileSet then
                    local newTsIdx = oldToNew[1 + oldTsIdx] - 1
                    mapEntry(pxTileCompose(newTsIdx, flags))
                else
                    mapEntry(pxTileCompose(0, flags))
                end
            end

            local frIdx = uniqueCel.frameNumber
            app.transaction(string.format(
                "Update Map %d", frIdx), function()
                uniqueCel.image = reordered
            end)
        end

        app.refresh()
    end
}

dlg:button {
    id = "cullButton",
    text = "CUL&L",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end

        local activeLayer = app.activeLayer
        if not activeLayer.isVisible then return end
        if not activeLayer.isEditable then return end
        if not activeLayer.isTilemap then return end
        local tileSet = activeLayer.tileset
        local lenTileSet = #tileSet

        -- Cache methods used in a for loop.
        local pxTilei = app.pixelColor.tileI
        local pxTilef = app.pixelColor.tileF
        local pxTileCompose = app.pixelColor.tile

        local frIdcs = AseUtilities.frameObjsToIdcs(
            activeSprite.frames)
        local uniqueCels = AseUtilities.getUniqueCelsFromLeaves(
            activeSprite, { activeLayer }, frIdcs, {})

        ---@type table<integer, boolean>
        local visited = {}
        visited[0] = true

        local lenUniques = #uniqueCels
        local h = 0
        while h < lenUniques do
            h = h + 1
            local srcCel = uniqueCels[h]
            local srcMap = srcCel.image
            local srcItr = srcMap:pixels()
            for mapEntry in srcItr do
                local srcTsIdx = pxTilei(mapEntry())
                if srcTsIdx > 0 and srcTsIdx < lenTileSet
                    and (not visited[srcTsIdx]) then
                    visited[srcTsIdx] = true
                end
            end
        end

        local oldToNew = {}
        oldToNew[0] = 0
        local lenOldToNew = 0
        local toCull = {}
        local i = 0
        while i < lenTileSet do
            if visited[i] then
                oldToNew[i] = lenOldToNew
                lenOldToNew = lenOldToNew + 1
            else
                oldToNew[i] = 0
                toCull[#toCull + 1] = tileSet:tile(i)
            end
            i = i + 1
        end

        app.transaction("Cull Tile Set", function()
            local lenMarked = #toCull
            local j = lenMarked + 1
            while j > 1 do
                j = j - 1
                activeSprite:deleteTile(toCull[j])
            end
        end)

        local k = 0
        while k < lenUniques do
            k = k + 1
            local uniqueCel = uniqueCels[k]
            local uniqueMap = uniqueCel.image
            local reordered = uniqueMap:clone()
            local reoItr = reordered:pixels()
            for mapEntry in reoItr do
                local rawData = mapEntry()
                local oldTsIdx = pxTilei(rawData)
                local flags = pxTilef(rawData)
                if oldTsIdx > 0 and oldTsIdx < lenTileSet then
                    local newTsIdx = oldToNew[oldTsIdx]
                    mapEntry(pxTileCompose(newTsIdx, flags))
                else
                    mapEntry(pxTileCompose(0, flags))
                end
            end

            local frIdx = uniqueCel.frameNumber
            app.transaction(string.format(
                "Update Map %d", frIdx), function()
                uniqueCel.image = reordered
            end)
        end

        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }