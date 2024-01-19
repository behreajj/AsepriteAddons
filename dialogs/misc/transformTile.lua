dofile("../../support/aseutilities.lua")

local targets <const> = { "FORE_TILE", "BACK_TILE", "TILES", "TILE_MAP" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults <const> = {
    -- Built-in Image:flip method has not been adopted here due to issues with
    -- undo history.
    target = "FORE_TILE",
    useXFlip = false,
    useYFlip = false,
    useDFlip = false,
    useNFlip = false,
    rangeStr = "",
    strExample = "4,6:9,13",
    inPlace = true
}

local function selectWithMode(activeSprite, trgSel, selMode)
    if selMode ~= "REPLACE" then
        local activeSel <const>,
        selIsValid <const> = AseUtilities.getSelection(activeSprite)
        if selMode == "INTERSECT" then
            activeSel:intersect(trgSel)
            activeSprite.selection = activeSel
        elseif selMode == "SUBTRACT" then
            activeSel:subtract(trgSel)
            activeSprite.selection = activeSel
        else
            -- Additive selection.
            if selIsValid then
                activeSel:add(trgSel)
                activeSprite.selection = activeSel
            else
                activeSprite.selection = trgSel
            end
        end
    else
        activeSprite.selection = trgSel
    end
end

---@param target "FORE_TILE"|"BACK_TILE"
---@param shift integer
local function cycleActive(target, shift)
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local activeLayer <const> = site.layer
    if not activeLayer then return end
    if not activeLayer.isTilemap then return end

    local tileSet <const> = activeLayer.tileset
    if not tileSet then return end
    local lenTileSet <const> = #tileSet

    local access <const> = target == "BACK_TILE" and "bg_tile" or "fg_tile"
    local colorBarPrefs <const> = app.preferences.color_bar
    local tifCurr <const> = colorBarPrefs[access]
    local tiCurr <const> = app.pixelColor.tileI(tifCurr)
    if tiCurr > lenTileSet - 1 or tiCurr < 0 then
        colorBarPrefs[access] = 0
    else
        local tfCurr <const> = app.pixelColor.tileF(tifCurr)
        local tiNext <const> = (tiCurr + shift) % lenTileSet
        colorBarPrefs[access] = app.pixelColor.tile(tiNext, tfCurr)
    end
    app.refresh()
end

---@param flag integer
---@return integer
local function flipFlagX(flag)
    return flag ~ 0x80000000
end

---@param flag integer
---@return integer
local function flipFlagY(flag)
    return flag ~ 0x40000000
end

---@param flag integer
---@return integer
local function rotateFlag90Ccw(flag)
    -- Pattern:
    -- 0x00000000, 0x60000000, 0xc0000000, 0xa0000000
    -- 0x20000000, 0x40000000, 0xe0000000, 0x80000000

    if flag == 0x20000000 then     -- D to Y
        return 0x40000000
    elseif flag == 0x40000000 then -- Y to XYD
        return 0xe0000000
    elseif flag == 0x60000000 then -- YD to XY
        return 0xc0000000
    elseif flag == 0x80000000 then -- X to D
        return 0x20000000
    elseif flag == 0xc0000000 then -- XY to XD
        return 0xa0000000
    elseif flag == 0xa0000000 then -- XD to 0
        return 0x00000000
    elseif flag == 0xe0000000 then -- XYD to X
        return 0x80000000
    end                            -- 0 to YD
    return 0x60000000
end

---@param flag integer
---@return integer
local function rotateFlag180(flag)
    if flag == 0x20000000 then     -- D to XYD
        return 0xe0000000
    elseif flag == 0x40000000 then -- Y to X
        return 0x80000000
    elseif flag == 0x60000000 then -- YD to XD
        return 0xa0000000
    elseif flag == 0x80000000 then -- X to Y
        return 0x40000000
    elseif flag == 0xc0000000 then -- XY to 0
        return 0x00000000
    elseif flag == 0xa0000000 then -- XD to YD
        return 0x60000000
    elseif flag == 0xe0000000 then -- XYD to D
        return 0x20000000
    end                            -- 0 to XY
    return 0xc0000000
end

---@param flag integer
---@return integer
local function rotateFlag270Ccw(flag)
    -- Pattern:
    -- 0x00000000, 0xa0000000, 0xc0000000, 0x60000000
    -- 0x20000000, 0x80000000, 0xe0000000, 0x40000000

    if flag == 0x20000000 then     -- D to X
        return 0x80000000
    elseif flag == 0x40000000 then -- Y to D
        return 0x20000000
    elseif flag == 0x60000000 then -- YD to 0
        return 0x00000000
    elseif flag == 0x80000000 then -- X to XYD
        return 0xe0000000
    elseif flag == 0xc0000000 then -- XY to YD
        return 0x60000000
    elseif flag == 0xa0000000 then -- XD to XY
        return 0xc0000000
    elseif flag == 0xe0000000 then -- XYD to Y
        return 0x40000000
    end                            -- 0 to XD
    return 0xa0000000
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
    ---@type fun(source: Image): Image
    local transformFunc = function(source) return source end
    local transactionName = "Transform Tiles"

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
        transformFunc = AseUtilities.flipImageX
    elseif preset == "FLIP_V" then
        transactionName = "Flip Tiles V"
        transformFunc = AseUtilities.flipImageY
    end

    ---@type table<integer, integer>
    local srcToTrgIdcs <const> = {}

    app.transaction(transactionName, function()
        if inPlace then
            for _, tile in pairs(containedTiles) do
                tile.image = transformFunc(tile.image)
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
    if not activeLayer.isTilemap then return end

    local activeCel <const> = activeLayer:cel(activeFrame)
    if not activeCel then return end

    local tileSet <const> = activeLayer.tileset
    if not tileSet then return end

    local args <const> = dialog.data
    local target <const> = args.target or defaults.target --[[@as string]]
    local inPlace <const> = args.inPlace --[[@as boolean]]

    local celPos <const> = activeCel.position
    local xtlCel <const> = celPos.x
    local ytlCel <const> = celPos.y

    local lenTileSet <const> = #tileSet
    local tileGrid <const> = tileSet.grid
    local tileDim <const> = tileGrid.tileSize
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

    -- Cache tile map functions.
    local pixelColor <const> = app.pixelColor
    local pxTilei <const> = pixelColor.tileI
    local pxTilef <const> = pixelColor.tileF
    local pxTileCompose <const> = pixelColor.tile

    -- Decide on meta transform function.
    ---@type fun(flag: integer): integer
    local flgTrFunc = function(flag) return flag end
    if preset == "90" then
        flgTrFunc = rotateFlag90Ccw
    elseif preset == "180" then
        flgTrFunc = rotateFlag180
    elseif preset == "270" then
        flgTrFunc = rotateFlag270Ccw
    elseif preset == "FLIP_H" then
        flgTrFunc = flipFlagX
    elseif preset == "FLIP_V" then
        flgTrFunc = flipFlagY
    end

    if target == "FORE_TILE" or target == "BACK_TILE" then
        local access <const> = target == "BACK_TILE" and "bg_tile" or "fg_tile"

        local colorBarPrefs <const> = app.preferences.color_bar
        local tifCurr <const> = colorBarPrefs[access]
        local tiCurr <const> = pxTilei(tifCurr)
        if tiCurr > lenTileSet - 1 or tiCurr < 0 then
            colorBarPrefs[access] = 0
        else
            local tfCurr <const> = pxTilef(tifCurr)
            local tfNext <const> = flgTrFunc(tfCurr)
            colorBarPrefs[access] = pxTileCompose(tiCurr, tfNext)
        end
        app.refresh()
        return
    end

    if not activeLayer.isVisible then return end
    if not activeLayer.isEditable then return end

    if target == "TILE_MAP" then
        ---@type fun(source: Image): Image
        local mapTrFunc = function(source) return source end
        local transactionName = "Transform Map"
        local updateCelPos = false

        if preset == "90" then
            transactionName = "Rotate Map 90"
            mapTrFunc = AseUtilities.rotateImage90
            updateCelPos = true
        elseif preset == "180" then
            transactionName = "Rotate Map 180"
            mapTrFunc = AseUtilities.rotateImage180
        elseif preset == "270" then
            transactionName = "Rotate Map 270"
            mapTrFunc = AseUtilities.rotateImage270
            updateCelPos = true
        elseif preset == "FLIP_H" then
            transactionName = "Flip Map H"
            mapTrFunc = AseUtilities.flipImageX
        elseif preset == "FLIP_V" then
            transactionName = "Flip Map V"
            mapTrFunc = AseUtilities.flipImageY
        end

        app.transaction(transactionName, function()
            local srcMap <const> = activeCel.image
            local trgMap <const> = mapTrFunc(srcMap)

            local trgItr <const> = trgMap:pixels()
            for mapEntry in trgItr do
                local mapif <const> = mapEntry() --[[@as integer]]
                local i <const> = pxTilei(mapif)
                local meta <const> = pxTilef(mapif)
                local trMeta <const> = flgTrFunc(meta)
                mapEntry(pxTileCompose(i, trMeta))
            end

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

        app.refresh()
        return
    end

    -- In theory, app.range.tiles could also be used, but it doesn't seem
    -- to work.

    -- A regular layer's cel bounds may be within the canvas, but after
    -- conversion to tilemap layer, it may go outside the canvas due to
    -- uniform tile size. This will lead to getSelectedTiles omitting tiles
    -- because tiles must be entirely contained.
    local selection <const>, _ <const> = AseUtilities.getSelection(activeSprite)
    local containedTiles <const> = AseUtilities.getSelectedTiles(
        activeCel.image, tileSet, selection,
        xtlCel, ytlCel)

    local srcToTrgIdcs <const> = transformTiles(
        preset, containedTiles, inPlace,
        activeSprite, tileSet)

    if not inPlace then
        local trgMap <const> = activeCel.image:clone()
        local trgItr <const> = trgMap:pixels()
        for mapEntry in trgItr do
            local tileData <const> = mapEntry()
            local srcIdx <const> = pxTilei(tileData)
            if srcToTrgIdcs[srcIdx] then
                local trgIdx <const> = srcToTrgIdcs[srcIdx]
                local srcFlags <const> = pxTilef(tileData)
                mapEntry(pxTileCompose(trgIdx, srcFlags))
            end
        end

        app.transaction("Update Map", function()
            activeCel.image = trgMap
        end)
    end

    app.refresh()
end

local dlg <const> = Dialog { title = "Edit Tile" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets,
    onchange = function()
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]

        local isTiles <const> = target == "TILES"
        local isTileMap <const> = target == "TILE_MAP"
        local isRange <const> = isTileMap or isTiles

        dlg:modify { id = "inPlace", visible = isTiles }
        dlg:modify { id = "selMode", visible = not isTiles }
        dlg:modify { id = "useXFlip", visible = not isTiles }
        dlg:modify { id = "useYFlip", visible = not isTiles }
        dlg:modify { id = "useDFlip", visible = not isTiles }
        dlg:modify { id = "useNFlip", visible = not isTiles }
        dlg:modify { id = "rangeStr", visible = isRange }
        dlg:modify { id = "strExample", visible = false }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "inPlace",
    label = "Edit:",
    text = "In &Place",
    selected = defaults.inPlace,
    visible = defaults.target == "TILES"
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

dlg:separator { id = "selectSep" }

dlg:combobox {
    id = "selMode",
    label = "Logic:",
    -- option = selModes[1 + app.preferences.selection.mode],
    option = "REPLACE",
    options = selModes,
    visible = defaults.target ~= "TILES"
}

-- dlg:newrow { always = false }

dlg:check {
    id = "useXFlip",
    label = "Flips:",
    text = "&X",
    selected = defaults.useXFlip,
    visible = defaults.target ~= "TILES"
}

dlg:check {
    id = "useYFlip",
    text = "&Y",
    selected = defaults.useYFlip,
    visible = defaults.target ~= "TILES"
}

dlg:check {
    id = "useDFlip",
    text = "&D",
    selected = defaults.useDFlip,
    visible = defaults.target ~= "TILES"
}

dlg:newrow { always = false }

dlg:check {
    id = "useNFlip",
    text = "&Invert",
    selected = defaults.useNFlip,
    visible = defaults.target ~= "TILES"
}

dlg:newrow { always = false }

dlg:entry {
    id = "rangeStr",
    label = "Indices:",
    text = defaults.rangeStr,
    focus = false,
    visible = defaults.frameTarget == "MANUAL",
    onchange = function()
        dlg:modify { id = "strExample", visible = true }
    end
}

dlg:newrow { always = false }

dlg:label {
    id = "strExample",
    label = "Example:",
    text = defaults.strExample,
    visible = false
}

dlg:newrow { always = false }

dlg:button {
    id = "selectButton",
    label = "Select:",
    text = "&TARGET",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeLayer <const> = site.layer
        if not activeLayer then return end
        if not activeLayer.isTilemap then return end

        local tileSet <const> = activeLayer.tileset
        if not tileSet then return end
        local lenTileSet <const> = #tileSet

        local args <const> = dlg.data
        local target <const> = args.target
            or defaults.target --[[@as string]]

        local colorBarPrefs <const> = app.preferences.color_bar

        local selIndices = {}
        if target == "FORE_TILE" then
            local tifFore <const> = colorBarPrefs["fg_tile"]
            local tiFore = app.pixelColor.tileI(tifFore)
            if tiFore > lenTileSet - 1 or tiFore < 0 then
                tiFore = 0
            end
            selIndices[1] = tiFore
        elseif target == "BACK_TILE" then
            local tifBack <const> = colorBarPrefs["bg_tile"]
            local tiBack = app.pixelColor.tileI(tifBack)
            if tiBack > lenTileSet - 1 or tiBack < 0 then
                tiBack = 0
            end
            selIndices[1] = tiBack
        else
            -- Default to "TILE_MAP" or "TILES"
            local rangeStr <const> = args.rangeStr
                or defaults.rangeStr --[[@as string]]
            local baseIndex <const> = tileSet.baseIndex
            -- Prase range was designed for frames,
            -- in [1, len], not tiles in [0, len - 1].
            selIndices = Utilities.parseRangeStringUnique(
                rangeStr, lenTileSet - 1, baseIndex - 1)
            -- print(table.concat(selIndices, ", "))
        end

        if target == "TILES" then
            app.range:clear()
            app.range.tiles = selIndices
        else
            local activeFrame <const> = site.frame
            if not activeFrame then return end

            local activeCel <const> = activeLayer:cel(activeFrame)
            if not activeCel then return end

            local lenSelIndices <const> = #selIndices
            if lenSelIndices < 1 then return end

            local useXFlip <const> = args.useXFlip --[[@as boolean]]
            local useYFlip <const> = args.useYFlip --[[@as boolean]]
            local useDFlip <const> = args.useDFlip --[[@as boolean]]
            local useNFlip <const> = args.useNFlip --[[@as boolean]]

            local flipMask = 0x0
            if useXFlip then flipMask = flipMask | 0x80000000 end
            if useYFlip then flipMask = flipMask | 0x40000000 end
            if useDFlip then flipMask = flipMask | 0x20000000 end

            local eval = function(flag) return flag ~= 0 end
            if flipMask == 0x0 then
                flipMask = 0x1fffffff
            elseif useNFlip then
                eval = function(flag) return flag == 0 end
            end

            local celPos <const> = activeCel.position
            local xTopLeft <const> = celPos.x
            local yTopLeft <const> = celPos.y

            local tileGrid <const> = tileSet.grid
            local tileSize <const> = tileGrid.tileSize
            local wTile <const> = tileSize.width
            local hTile <const> = tileSize.height

            local trgSel <const> = Selection()
            local selRect <const> = Rectangle(0, 0, wTile, hTile)

            -- Cache methods used in loop.
            local pxTilei <const> = app.pixelColor.tileI

            local tileMap <const> = activeCel.image
            local mapItr <const> = tileMap:pixels()
            for mapEntry in mapItr do
                local mapif <const> = mapEntry() --[[@as integer]]
                local flag <const> = flipMask & mapif

                if eval(flag) then
                    local idx <const> = pxTilei(mapif)
                    local found = false
                    local k = 0
                    while (not found) and k < lenSelIndices do
                        k = k + 1
                        found = idx == selIndices[k]
                    end

                    if found then
                        selRect.x = xTopLeft + mapEntry.x * wTile
                        selRect.y = yTopLeft + mapEntry.y * hTile
                        trgSel:add(selRect)
                    end
                end
            end

            local selMode <const> = args.selMode
                or defaults.selMode --[[@as string]]
            app.transaction("Select Tiles", function()
                selectWithMode(activeSprite, trgSel, selMode)
            end)
        end

        app.refresh()
    end
}

dlg:button {
    id = "dupesButton",
    text = "D&UPES",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeLayer <const> = site.layer
        if not activeLayer then return end
        if not activeLayer.isTilemap then return end

        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local activeCel <const> = activeLayer:cel(activeFrame)
        if not activeCel then return end

        local celPos <const> = activeCel.position
        local xTopLeft <const> = celPos.x
        local yTopLeft <const> = celPos.y

        local tileSet <const> = activeLayer.tileset
        if not tileSet then return end
        local tileGrid <const> = tileSet.grid
        local tileSize <const> = tileGrid.tileSize
        local wTile <const> = tileSize.width
        local hTile <const> = tileSize.height

        local trgSel <const> = Selection()
        local selRect <const> = Rectangle(0, 0, wTile, hTile)

        -- Cache methods used in loop.
        local pxTilei <const> = app.pixelColor.tileI

        ---@type table<integer, boolean>
        local visited <const> = {}
        local tileMap <const> = activeCel.image
        local mapItr <const> = tileMap:pixels()
        for mapEntry in mapItr do
            local mapif <const> = mapEntry() --[[@as integer]]
            local index = pxTilei(mapif)
            if index ~= 0 and visited[index] then
                selRect.x = xTopLeft + mapEntry.x * wTile
                selRect.y = yTopLeft + mapEntry.y * hTile
                trgSel:add(selRect)
            end
            visited[index] = true
        end

        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        app.transaction("Select Tiles", function()
            selectWithMode(activeSprite, trgSel, selMode)
        end)

        app.refresh()
    end
}

dlg:separator { id = "sortSep" }

dlg:button {
    id = "reorderButton",
    label = "Tile Set:",
    text = "SO&RT",
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

        local activeCel <const> = activeLayer:cel(activeFrame)
        if not activeCel then return end

        local tileSet <const> = activeLayer.tileset
        if not tileSet then return end

        local spriteSpec <const> = activeSprite.spec
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorMode <const> = spriteSpec.colorMode
        local colorSpace <const> = spriteSpec.colorSpace

        local lenTileSet <const> = #tileSet
        local tileSize <const> = tileSet.grid.tileSize
        local wTile <const> = math.max(1, math.abs(tileSize.width))
        local hTile <const> = math.max(1, math.abs(tileSize.height))

        -- Cache methods used in a for loop.
        local pixelColor <const> = app.pixelColor
        local pxTilei <const> = pixelColor.tileI
        local pxTilef <const> = pixelColor.tileF
        local pxTileCompose <const> = pixelColor.tile
        local createSpec <const> = AseUtilities.createSpec

        -- Contains the first usage of a tile in the set by the active map.
        -- Ignores index 0. Because all tile maps in the layer have to be
        -- updated later, not just the active map, no point in storing an array
        -- of all visitations as dict value.
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
        -- Same with tiles in the tile set not visited by the map.
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
        -- The blank image at 0 is included so that the array doesn't have a
        -- nil at its first index. Any other relevant data from a tile would
        -- also be cloned at this stage, e.g., user data.
        ---@type {image: Image, color: Color, data: string}[]
        local sortedTsPackets = {}

        -- Flip the relationship between old (unsorted) and new (sorted)
        -- indices so that other tile maps can easily be updated.
        ---@type integer[]
        local oldToNew = {}

        local i = 0
        while i < lenTileSet do
            i = i + 1
            local tsIdx <const> = sortedTsIdcs[i]
            local tile <const> = tileSet:tile(tsIdx)

            local packet = nil
            if tile then
                packet = {
                    color = tile.color,
                    data = tile.data,
                    image = tile.image:clone()
                }
            else
                packet = {
                    color = Color { r = 0, g = 0, b = 0, a = 0 },
                    data = "",
                    image = Image(createSpec(
                        wTile, hTile,
                        colorMode, colorSpace, alphaIndex))
                }
            end

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
                    if tile then
                        local packet <const> = sortedTsPackets[j]
                        tile.color = packet.color
                        tile.data = packet.data
                        tile.image = packet.image
                    end
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

dlg:separator { id = "sortSep" }

dlg:button {
    id = "nextFore",
    label = "Next:",
    text = "&FORE",
    focus = true,
    onclick = function()
        cycleActive("FORE_TILE", 1)
    end
}

dlg:button {
    id = "nextBack",
    text = "&BACK",
    focus = false,
    onclick = function()
        cycleActive("BACK_TILE", 1)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "prevFore",
    label = "Prev:",
    text = "F&ORE",
    focus = false,
    onclick = function()
        cycleActive("FORE_TILE", -1)
    end
}

dlg:button {
    id = "prevBack",
    text = "B&ACK",
    focus = false,
    onclick = function()
        cycleActive("BACK_TILE", -1)
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

dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    dlgBounds.x * 2 - 32, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)