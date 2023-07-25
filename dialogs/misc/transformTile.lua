dofile("../../support/aseutilities.lua")

local targets <const> = { "FORE_TILE", "BACK_TILE", "TILES", "TILE_MAP" }

local defaults <const> = {
    -- Built-in Image:flip method has not
    -- been adopted here due to issues with
    -- undo history.
    target = "FORE_TILE",
    inPlace = true
}

---@param flag "FORE"|"BACK"
---@param shift integer
local function cycleActive(flag, shift)
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local activeLayer <const> = site.layer
    if not activeLayer then return end

    local isTilemap <const> = activeLayer.isTilemap
    if not isTilemap then return end

    local tileset <const> = activeLayer.tileset
    local lenTileset <const> = #tileset

    local appPrefs <const> = app.preferences
    local colorBarPrefs <const> = appPrefs.color_bar

    local access = "fg_tile"
    if flag == "BACK" then
        access = "bg_tile"
    end

    local ti = colorBarPrefs[access]
    if ti > lenTileset - 1 or ti < 0 then
        colorBarPrefs[access] = 0
    else
        colorBarPrefs[access] = (ti + shift) % lenTileset
    end
end

---@param preset string
---@param containedTiles table<integer, Tile>
---@param inPlace boolean
---@param activeSprite Sprite
---@param tileSet Tileset
---@return table<integer, integer>
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
    local srcToTrgIdcs <const> = {}

    app.transaction(transactionName, function()
        if inPlace then
            for _, tile in pairs(containedTiles) do
                local trgImage <const> = transformFunc(tile.image)
                tile.image = trgImage
            end
        else
            for srcIdx, srcTile in pairs(containedTiles) do
                local srcImage <const> = srcTile.image
                if srcImage:isEmpty() then
                    srcToTrgIdcs[srcIdx] = 0
                else
                    local trgTile <const> = activeSprite:newTile(tileSet)
                    trgTile.image = transformFunc(srcImage)
                    srcToTrgIdcs[srcIdx] = trgTile.index
                end
            end
        end
    end)

    return srcToTrgIdcs
end

---@param dialog Dialog
---@param preset string
local function transformCel(dialog, preset)
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local activeFrame <const> = site.frame
    if not activeFrame then return end

    local activeLayer <const> = site.layer
    if not activeLayer then return end
    if not activeLayer.isVisible then return end
    if not activeLayer.isEditable then return end
    if not activeLayer.isTilemap then return end

    local tileSet <const> = activeLayer.tileset --[[@as Tileset]]
    local lenTileSet <const> = #tileSet

    local activeCel <const> = activeLayer:cel(activeFrame)
    if not activeCel then return end

    local args <const> = dialog.data
    local target <const> = args.target
        or defaults.target --[[@as string]]
    local inPlace <const> = args.inPlace --[[@as boolean]]

    local celPos <const> = activeCel.position
    local xtlCel <const> = celPos.x
    local ytlCel <const> = celPos.y

    local tileGrid <const> = tileSet.grid --[[@as Grid]]
    local tileDim <const> = tileGrid.tileSize --[[@as Size]]
    local wTile <const> = tileDim.width
    local hTile <const> = tileDim.height
    if wTile ~= hTile
        and (preset == "90"
            or preset == "270") then
        app.alert {
            title = "Error",
            text = "Tile size is nonuniform."
        }
        return
    end

    ---@type table<integer, Tile>
    local containedTiles = {}
    if target == "TILE_MAP" then
        containedTiles = AseUtilities.getUniqueTiles(
            activeCel.image, tileSet)
        local transactionName = "Transform Map"
        local transformFunc = nil
        local updateCelPos = false
        if preset == "90" then
            transactionName = "Rotate Map 90"
            transformFunc = AseUtilities.rotateImage90
            updateCelPos = true
        elseif preset == "180" then
            transactionName = "Rotate Map 180"
            transformFunc = AseUtilities.rotateImage180
        elseif preset == "270" then
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
            local srcMap <const> = activeCel.image
            local trgMap <const> = transformFunc(srcMap)

            if updateCelPos then
                local wSrcPixels <const> = srcMap.width * wTile
                local hSrcPixels <const> = srcMap.height * hTile
                local wSrcHalf <const> = wSrcPixels // 2
                local hSrcHalf <const> = hSrcPixels // 2

                local wTrgPixels <const> = trgMap.width * wTile
                local hTrgPixels <const> = trgMap.height * hTile
                local wTrgHalf <const> = wTrgPixels // 2
                local hTrgHalf <const> = hTrgPixels // 2

                activeCel.position = Point(
                    xtlCel + wSrcHalf - wTrgHalf,
                    ytlCel + hSrcHalf - hTrgHalf)
            end

            activeCel.image = trgMap
        end)
    elseif target == "TILES" then
        -- In theory, app.range.tiles could also be used,
        -- but atm it doesn't seem to work.

        -- A regular layer's cel bounds may be within the
        -- canvas, but after conversion to tilemap layer,
        -- it may go outside the canvas due to uniform tile
        -- size. This will lead to getSelectedTiles omitting
        -- tiles because tiles must be entirely contained.
        local selection <const> = AseUtilities.getSelection(activeSprite)
        containedTiles = AseUtilities.getSelectedTiles(
            activeCel.image, tileSet, selection,
            xtlCel, ytlCel)
    elseif target == "BACK_TILE" then
        local tileIndex <const> = app.preferences.color_bar.bg_tile
        if tileIndex > 0 and tileIndex < lenTileSet then
            containedTiles[tileIndex] = tileSet:tile(tileIndex)
        end
    else
        local tileIndex <const> = app.preferences.color_bar.fg_tile
        if tileIndex > 0 and tileIndex < lenTileSet then
            containedTiles[tileIndex] = tileSet:tile(tileIndex)
        end
    end

    local srcToTrgIdcs <const> = transformTiles(
        preset, containedTiles, inPlace,
        activeSprite, tileSet)

    if not inPlace then
        local pxTilei <const> = app.pixelColor.tileI
        local pxTilef <const> = app.pixelColor.tileF
        local pxTileCompose <const> = app.pixelColor.tile
        local trgMap <const> = activeCel.image:clone()
        local trgItr <const> = trgMap:pixels()
        for mapEntry in trgItr do
            local tileData <const> = mapEntry()
            local srcIdx <const> = pxTilei(tileData)
            local srcFlags <const> = pxTilef(tileData)
            if srcToTrgIdcs[srcIdx] then
                local trgIdx <const> = srcToTrgIdcs[srcIdx]
                mapEntry(pxTileCompose(trgIdx, srcFlags))
            end
        end

        app.transaction("Update Map", function()
            activeCel.image = trgMap
        end)

        if target == "BACK_TILE" then
            local cbPref <const> = app.preferences.color_bar
            local trgIdx <const> = srcToTrgIdcs[cbPref.bg_tile]
            if trgIdx then cbPref.bg_tile = trgIdx end
        elseif target == "FORE_TILE" then
            local cbPref <const> = app.preferences.color_bar
            local trgIdx <const> = srcToTrgIdcs[cbPref.fg_tile]
            if trgIdx then cbPref.fg_tile = trgIdx end
        end
    end

    app.refresh()
end

local dlg <const> = Dialog { title = "Edit Tile" }

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
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local activeLayer <const> = site.layer
        if not activeLayer then return end
        if not activeLayer.isVisible then return end
        if not activeLayer.isEditable then return end
        if not activeLayer.isTilemap then return end

        local tileSet <const> = activeLayer.tileset --[[@as Tileset]]
        local lenTileSet <const> = #tileSet

        local activeCel <const> = activeLayer:cel(activeFrame)
        if not activeCel then return end

        -- Cache methods used in a for loop.
        local pxTilei <const> = app.pixelColor.tileI
        local pxTilef <const> = app.pixelColor.tileF
        local pxTileCompose <const> = app.pixelColor.tile

        --Contains the first usage of a tile in the set
        --by the active map. Ignores index 0. Because all
        --tile maps in the layer have to be updated later,
        --not just the active map, no point in storing
        --an array of all visitations as dict value.
        ---@type table<integer, integer>
        local visited <const> = {}

        local srcMap <const> = activeCel.image
        local srcWidth <const> = srcMap.width
        local srcItr <const> = srcMap:pixels()
        for mapEntry in srcItr do
            local mapif <const> = mapEntry() --[[@as integer]]
            local srcTsIdx <const> = pxTilei(mapif)
            if srcTsIdx > 0 and srcTsIdx < lenTileSet
                and (not visited[srcTsIdx]) then
                local flatIdx <const> = mapEntry.x + mapEntry.y * srcWidth
                visited[srcTsIdx] = flatIdx
            end
        end

        -- Convert dictionary to a set.
        ---@type integer[]
        local sortedTsIdcs <const> = {}
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
            local tsIdx <const> = sortedTsIdcs[i]
            local tile <const> = tileSet:tile(tsIdx)
            local packet = {
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
                    local tile <const> = tileSet:tile(j - 1)
                    local packet <const> = sortedTsPackets[j]
                    -- tile.color = packet.color
                    -- tile.data = packet.data
                    tile.image = packet.image
                end
            end)

        local uniqueCels <const> = AseUtilities.getUniqueCelsFromLeaves(
            { activeLayer }, activeSprite.frames)

        local lenUniques <const> = #uniqueCels
        local k = 0
        while k < lenUniques do
            k = k + 1
            local uniqueCel <const> = uniqueCels[k]
            local uniqueMap <const> = uniqueCel.image
            local reordered <const> = uniqueMap:clone()
            local reoItr <const> = reordered:pixels()
            for mapEntry in reoItr do
                local mapif <const> = mapEntry() --[[@as integer]]
                local oldTsIdx <const> = pxTilei(mapif)
                local flags <const> = pxTilef(mapif)
                if oldTsIdx > 0 and oldTsIdx < lenTileSet then
                    local newTsIdx <const> = oldToNew[1 + oldTsIdx] - 1
                    mapEntry(pxTileCompose(newTsIdx, flags))
                else
                    mapEntry(pxTileCompose(0, flags))
                end
            end

            app.transaction("Update Map", function()
                uniqueCel.image = reordered
            end)
        end

        app.refresh()
    end
}

dlg:button {
    id = "cullButton",
    text = "C&ULL",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeLayer <const> = site.layer
        if not activeLayer then return end
        if not activeLayer.isVisible then return end
        if not activeLayer.isEditable then return end
        if not activeLayer.isTilemap then return end

        local tileSet <const> = activeLayer.tileset --[[@as Tileset]]
        local lenTileSet <const> = #tileSet

        -- Cache methods used in a for loop.
        local pxTilei <const> = app.pixelColor.tileI
        local pxTilef <const> = app.pixelColor.tileF
        local pxTileCompose <const> = app.pixelColor.tile

        local uniqueCels <const> = AseUtilities.getUniqueCelsFromLeaves(
            { activeLayer }, activeSprite.frames)

        ---@type table<integer, boolean>
        local visited <const> = {}
        visited[0] = true

        local lenUniques <const> = #uniqueCels
        local h = 0
        while h < lenUniques do
            h = h + 1
            local srcCel <const> = uniqueCels[h]
            local srcMap <const> = srcCel.image
            local srcItr <const> = srcMap:pixels()
            for mapEntry in srcItr do
                local mapif <const> = mapEntry() --[[@as integer]]
                local srcTsIdx <const> = pxTilei(mapif)
                if srcTsIdx > 0 and srcTsIdx < lenTileSet
                    and (not visited[srcTsIdx]) then
                    visited[srcTsIdx] = true
                end
            end
        end

        ---@type integer[]
        local oldToNew <const> = {}
        oldToNew[0] = 0
        local lenOldToNew = 0
        ---@type Tile[]
        local toCull <const> = {}

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
            local lenMarked <const> = #toCull
            local j = lenMarked + 1
            while j > 1 do
                j = j - 1
                activeSprite:deleteTile(toCull[j])
            end
        end)

        local k = 0
        while k < lenUniques do
            k = k + 1
            local uniqueCel <const> = uniqueCels[k]
            local uniqueMap <const> = uniqueCel.image
            local reordered <const> = uniqueMap:clone()
            local reoItr <const> = reordered:pixels()
            for mapEntry in reoItr do
                local rawData <const> = mapEntry()
                local oldTsIdx <const> = pxTilei(rawData)
                local flags <const> = pxTilef(rawData)
                if oldTsIdx > 0 and oldTsIdx < lenTileSet then
                    local newTsIdx <const> = oldToNew[oldTsIdx]
                    mapEntry(pxTileCompose(newTsIdx, flags))
                else
                    mapEntry(pxTileCompose(0, flags))
                end
            end

            app.transaction("Update Map", function()
                uniqueCel.image = reordered
            end)
        end

        app.refresh()
    end
}

dlg:separator { id = "sortSep" }

dlg:button {
    id = "nextFore",
    label = "Next:",
    text = "&FORE",
    focus = false,
    onclick = function()
        cycleActive("FORE", 1)
    end
}

dlg:button {
    id = "nextBack",
    text = "&BACK",
    focus = false,
    onclick = function()
        cycleActive("BACK", 1)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "prevFore",
    label = "Prev:",
    text = "F&ORE",
    focus = false,
    onclick = function()
        cycleActive("FORE", -1)
    end
}

dlg:button {
    id = "prevBack",
    text = "B&ACK",
    focus = false,
    onclick = function()
        cycleActive("BACK", -1)
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