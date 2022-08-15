dofile("../../support/aseutilities.lua")

local cropTypes = { "CROP", "EXPAND", "SELECTION" }

local defaults = {
    cropType = "CROP",
    includeHidden = true,
    includeLocked = false,
    padding = 0,
    pullFocus = false
}

local function appendLeaves(layer, array, includeLocked, includeHidden)
    if (includeHidden or layer.isVisible)
        and (includeLocked or layer.isEditable)
        and (not layer.isBackground) then
        if layer.isGroup then
            local childLayers = layer.layers
            local lenChildLayers = #childLayers
            local i = 0
            while i < lenChildLayers do
                i = i + 1
                local childLayer = childLayers[i]
                appendLeaves(childLayer, array)
            end
        else
            table.insert(array, layer)
        end
    end
end

local dlg = Dialog { title = "Trim Sprite" }

dlg:combobox {
    id = "cropType",
    label = "Mode:",
    option = defaults.cropType,
    options = cropTypes
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "Locked",
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "Hidden",
    selected = defaults.includeHidden
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Version
        local version = app.version
        local checkTilemaps = version.major >= 1
            and version.minor >= 3

        -- Unpack sprite spec.
        local spec = activeSprite.spec
        local wSprite = spec.width
        local hSprite = spec.height
        local alphaMask = spec.transparentColor

        -- Unpack arguments.
        local args = dlg.data
        local cropType = args.cropType or defaults.cropType
        local includeHidden = args.includeHidden
        local includeLocked = args.includeLocked
        local padding = args.padding or defaults.padding

        local useCrop = cropType == "CROP"
        local useExpand = cropType == "EXPAND"
        local useSel = cropType == "SELECTION"

        -- Record minimum and maximum positions.
        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        -- Test to see if there is a background layer.
        -- If so, remove it. Backgrounds in indexed color
        -- mode may contain transparency.
        local bkgLayer = activeSprite.backgroundLayer
        if bkgLayer then
            local bkgUnlocked = bkgLayer.isEditable
            if bkgUnlocked then
                app.activeLayer = bkgLayer
                app.command.LayerFromBackground()
            else
                xMin = 0
                yMin = 0
                xMax = wSprite - 1
                yMax = hSprite - 1
            end
        end

        -- Get leaf layers, which could contain
        -- a cel. The cel could have either tile
        -- map data or a regular image.
        local topLayers = activeSprite.layers
        local lenTopLayers = #topLayers
        local leaves = {}
        local g = 0
        while g < lenTopLayers do g = g + 1
            appendLeaves(topLayers[g], leaves,
                includeLocked, includeHidden)
        end

        -- Get selection.
        -- Do this regardless of cropType, as selection
        -- bug may impact result either way.
        local sel = AseUtilities.getSelection(activeSprite)

        -- Cache methods used in loop.
        local trimAlpha = AseUtilities.trimImageAlpha
        local cropCel = AseUtilities.trimCelToSprite
        local selectCel = AseUtilities.trimCelToSelect

        local toCull = {}
        local lenToCull = 0
        local lenLeaves = #leaves
        local frames = activeSprite.frames
        local lenFrames = #frames
        local h = 0
        while h < lenLeaves do h = h + 1
            local leaf = leaves[h]

            -- Tile maps measure in tiles, not pixels.
            local isTilemap = false
            local wTile = 0
            local hTile = 0
            if checkTilemaps then
                isTilemap = leaf.isTilemap
                if isTilemap then
                    local tileSet = leaf.tileset
                    local tileGrid = tileSet.grid
                    local tileDim = tileGrid.tileSize
                    wTile = tileDim.width
                    hTile = tileDim.height
                end
            end

            -- Problem: linked cels will count multiple times.
            local i = 0
            while i < lenFrames do i = i + 1
                local frame = frames[i]
                local cel = leaf:cel(frames[i])
                if cel then
                    local celPos = cel.position
                    local celImg = cel.image

                    local tlx = celPos.x
                    local tly = celPos.y
                    local brx = tlx + celImg.width - 1
                    local bry = tly + celImg.height - 1

                    if isTilemap then
                        brx = tlx + celImg.width * wTile - 1
                        bry = tly + celImg.height * hTile - 1
                    elseif useSel then
                        selectCel(cel, sel)
                        celPos = cel.position
                        tlx = celPos.x
                        tly = celPos.y
                        celImg = cel.image
                        brx = tlx + celImg.width - 1
                        bry = tly + celImg.height - 1
                    else
                        local xTrm = 0
                        local yTrm = 0
                        local trimmed = nil
                        trimmed, xTrm, yTrm = trimAlpha(celImg, 0, alphaMask)

                        tlx = tlx + xTrm
                        tly = tly + yTrm
                        brx = tlx + trimmed.width - 1
                        bry = tly + trimmed.height - 1

                        cel.position = Point(tlx, tly)
                        cel.image = trimmed
                        celPos = cel.position
                        celImg = cel.image

                        if useCrop then
                            cropCel(cel, activeSprite)
                            celPos = cel.position
                            tlx = celPos.x
                            tly = celPos.y
                            celImg = cel.image
                            brx = tlx + celImg.width - 1
                            bry = tly + celImg.height - 1
                        end
                    end

                    if celImg:isEmpty() then
                        lenToCull = lenToCull + 1
                        toCull[lenToCull] = { layer = leaf, frame = frame }
                    end

                    if tlx < xMin then xMin = tlx end
                    if tly < yMin then yMin = tly end
                    if brx > xMax then xMax = brx end
                    if bry > yMax then yMax = bry end
                end
            end
        end

        if useSel then
            activeSprite:crop(sel.bounds)
        elseif xMax > xMin and yMax > yMin then
            if not useExpand then
                if xMin < 0 then xMin = 0 end
                if yMin < 0 then yMin = 0 end
                if xMax > wSprite - 1 then
                    xMax = wSprite - 1
                end
                if yMax > hSprite - 1 then
                    yMax = hSprite - 1
                end
            end

            activeSprite:crop(
                xMin, yMin,
                1 + xMax - xMin,
                1 + yMax - yMin)
        end

        if padding > 0 then
            local pad2 = padding + padding
            activeSprite:crop(
                -padding, -padding,
                activeSprite.width + pad2,
                activeSprite.height + pad2)
        end

        app.transaction(function()
            local k = 0
            while k < lenToCull do k = k + 1
                local packet = toCull[k]
                activeSprite:deleteCel(
                    packet.layer, packet.frame)
            end
        end)

        app.command.FitScreen()
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

dlg:show { wait = false }