dofile("../../support/aseutilities.lua")

local targets = { "TILES", "TILE_MAP" }

local defaults = {
    -- Wrap tile wouldn't work with map and set
    -- together. Though wrap(x,y) for tile would
    -- be wrap(x//wTile, y//hTile) for map
    -- TODO: Replace Color
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

    -- TODO: Maybe the tile map mode will take care of it?
    -- Assume that tile is changed in place until you
    -- test to see whether duplicate tiles are allowed...
    -- See activeSprite:newTile(tileSet)
    -- https://github.com/aseprite/aseprite/blob/
    -- main/src/app/script/sprite_class.cpp#L704
    app.transaction(transactionName, function()
        if inPlace then
            for _, tile in pairs(containedTiles) do
                local trgImage = transformFunc(tile.image)
                tile.image = trgImage
            end
        else
            for srcIdx, srcTile in pairs(containedTiles) do
                local trgTile = activeSprite:newTile(tileSet)
                trgTile.image = transformFunc(srcTile.image)
                srcToTrgIdcs[srcIdx] = trgTile.index
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

        app.transaction("Update Map Indices", function()
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
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }