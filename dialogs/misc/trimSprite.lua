dofile("../../support/aseutilities.lua")

local cropTypes <const> = { "CROP", "EXPAND", "SELECTION" }

local defaults <const> = {
    cropType = "CROP",
    includeLocked = false,
    includeHidden = true,
    padding = 0,
    trimFrames = false
}

local dlg <const> = Dialog { title = "Trim Sprite" }

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
    text = "&Locked",
    focus = false,
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    focus = false,
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

dlg:check {
    id = "trimFrames",
    label = "Cull: ",
    text = "&Frames",
    focus = false,
    selected = defaults.trimFrames
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local activeSprite <const> = app.site.sprite
        if not activeSprite then
            app.alert {
                title = "Error",
                text = "There is no active sprite."
            }
            return
        end

        -- Unpack sprite spec.
        local spec <const> = activeSprite.spec
        local wSprite <const> = spec.width
        local hSprite <const> = spec.height
        local alphaMask <const> = spec.transparentColor

        -- Unpack arguments.
        local args <const> = dlg.data
        local cropType <const> = args.cropType
            or defaults.cropType --[[@as string]]
        local includeLocked <const> = args.includeLocked --[[@as boolean]]
        local includeHidden <const> = args.includeHidden --[[@as boolean]]
        local padding <const> = args.padding
            or defaults.padding --[[@as integer]]
        local trimFrames <const> = args.trimFrames --[[@as boolean]]

        local useCrop <const> = cropType == "CROP"
        local useExpand <const> = cropType == "EXPAND"
        local useSel <const> = cropType == "SELECTION"

        -- Record minimum and maximum positions.
        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        -- Test to see if there is a background layer.
        -- If so, remove it. Backgrounds in indexed color
        -- mode may contain transparency.
        local bkgLayer <const> = activeSprite.backgroundLayer
        if bkgLayer then
            if includeLocked or bkgLayer.isEditable then
                app.activeLayer = bkgLayer
                app.command.LayerFromBackground()
            else
                xMin = 0
                yMin = 0
                xMax = wSprite - 1
                yMax = hSprite - 1
            end
        end

        local sel = nil
        if useSel then
            sel = AseUtilities.getSelection(activeSprite)
        end

        local leaves <const> = AseUtilities.getLayerHierarchy(
            activeSprite,
            includeLocked, includeHidden, true, false)
        local lenLeaves <const> = #leaves
        -- TODO: Is it necessary to create frame indices here?
        local frIdcs <const> = AseUtilities.frameObjsToIdcs(activeSprite.frames)
        local cels <const> = AseUtilities.getUniqueCelsFromLeaves(
            leaves, frIdcs)
        local lenCels <const> = #cels

        -- Cache methods used in loop.
        local trimAlpha <const> = AseUtilities.trimImageAlpha
        local cropCel <const> = AseUtilities.trimCelToSprite
        local selectCel <const> = AseUtilities.trimCelToSelect
        local strfmt <const> = string.format
        local transact <const> = app.transaction

        ---@type Cel[]
        local toCull <const> = {}
        local lenToCull = 0
        local i = 0
        while i < lenCels do
            i = i + 1

            local cel <const> = cels[i]
            local celPos = cel.position
            local celImg = cel.image
            local layer <const> = cel.layer
            local layerName <const> = layer.name

            local tlx = celPos.x
            local tly = celPos.y
            local brx = tlx + celImg.width - 1
            local bry = tly + celImg.height - 1

            if layer.isTilemap then
                local tileSet <const> = layer.tileset
                local tileGrid <const> = tileSet.grid
                local tileDim <const> = tileGrid.tileSize
                local wTile <const> = tileDim.width
                local hTile <const> = tileDim.height
                brx = tlx + celImg.width * wTile - 1
                bry = tly + celImg.height * hTile - 1
            elseif useSel then
                transact(
                    strfmt("Crop %s", layerName),
                    function()
                        selectCel(cel, sel)
                    end)
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

                transact(
                    strfmt("Trim %s", layerName),
                    function()
                        cel.position = Point(tlx, tly)
                        cel.image = trimmed
                    end)
                celPos = cel.position
                celImg = cel.image

                if useCrop then
                    transact(
                        strfmt("Crop %s", layerName),
                        function()
                            cropCel(cel, activeSprite)
                        end)
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
                toCull[lenToCull] = cel
            end

            if tlx < xMin then xMin = tlx end
            if tly < yMin then yMin = tly end
            if brx > xMax then xMax = brx end
            if bry > yMax then yMax = bry end
        end

        if useSel then
            transact("Crop Canvas To Mask", function()
                activeSprite:crop(sel.bounds)
            end)
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

            transact("Crop Canvas", function()
                activeSprite:crop(
                    xMin, yMin,
                    1 + xMax - xMin,
                    1 + yMax - yMin)
            end)
        end

        if padding > 0 then
            local pad2 <const> = padding + padding
            transact("Pad Canvas", function()
                activeSprite:crop(
                    -padding, -padding,
                    activeSprite.width + pad2,
                    activeSprite.height + pad2)
            end)
        end

        -- Trim cels cannot be optional due to
        -- invalid cel boundaries.
        if lenToCull > 0 then
            transact("Delete Cels", function()
                local j = lenToCull + 1
                while j > 1 do
                    j = j - 1
                    local cel <const> = toCull[j]
                    activeSprite:deleteCel(cel)
                end
            end)
        end

        if trimFrames and #frIdcs > 1 then
            app.transaction("Cull Frames Reverse",
                function()
                    local frameEmptyRight = true
                    local m = 1 + #activeSprite.frames
                    while m > 2 and frameEmptyRight do
                        m = m - 1
                        local k = 0
                        while k < lenLeaves and frameEmptyRight do
                            k = k + 1
                            local leaf <const> = leaves[k]
                            if leaf:cel(m) then
                                frameEmptyRight = false
                            end
                        end
                        if frameEmptyRight then
                            activeSprite:deleteFrame(m)
                        end
                    end
                end)

            app.transaction("Cull Frames Forward",
                function()
                    local frameEmptyLeft = true
                    while frameEmptyLeft and #activeSprite.frames > 1 do
                        local k = 0
                        while k < lenLeaves and frameEmptyLeft do
                            k = k + 1
                            local leaf <const> = leaves[k]
                            if leaf:cel(1) then
                                frameEmptyLeft = false
                            end
                        end
                        if frameEmptyLeft then
                            activeSprite:deleteFrame(1)
                        end
                    end
                end)
        end

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