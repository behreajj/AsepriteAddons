dofile("../../support/aseutilities.lua")

local wRectSet = 0
local hRectSet = 0
if app.sprite then
    wRectSet = app.sprite.width
    hRectSet = app.sprite.height
else
    local appPrefs <const> = app.preferences
    if appPrefs then
        local newFilePrefs <const> = appPrefs.new_file
        if newFilePrefs then
            local wCand <const> = newFilePrefs.width
            if wCand and wCand > 0 then
                wRectSet = wCand
            end

            local hCand <const> = newFilePrefs.height
            if hCand and hCand > 0 then
                hRectSet = hCand
            end
        end
    end
end

local cropTypes <const> = {
    "CROP",
    "EDGES",
    -- "EXPAND",
    "RECTANGLE",
    "SELECTION"
}

local defaults <const> = {
    cropType = "SELECTION",

    leftEdge = 0,
    topEdge = 0,
    rightEdge = 0,
    bottomEdge = 0,

    xtlRect = 0,
    ytlRect = 0,

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
    options = cropTypes,
    onchange = function()
        local args <const> = dlg.data
        local cropType <const> = args.cropType
        local isEdges <const> = cropType == "EDGES"
        local isRect <const> = cropType == "RECTANGLE"
        dlg:modify { id = "leftEdge", visible = isEdges }
        dlg:modify { id = "topEdge", visible = isEdges }
        dlg:modify { id = "rightEdge", visible = isEdges }
        dlg:modify { id = "bottomEdge", visible = isEdges }

        dlg:modify { id = "xtlRect", visible = isRect }
        dlg:modify { id = "ytlRect", visible = isRect }
        dlg:modify { id = "wRect", visible = isRect }
        dlg:modify { id = "hRect", visible = isRect }

        dlg:modify { id = "rectAlignTl", visible = isRect }
        dlg:modify { id = "rectAlignTc", visible = isRect }
        dlg:modify { id = "rectAlignTr", visible = isRect }

        dlg:modify { id = "rectAlignCl", visible = isRect }
        dlg:modify { id = "rectAlignC", visible = isRect }
        dlg:modify { id = "rectAlignCr", visible = isRect }

        dlg:modify { id = "rectAlignBl", visible = isRect }
        dlg:modify { id = "rectAlignBc", visible = isRect }
        dlg:modify { id = "rectAlignBr", visible = isRect }

        -- dlg:modify { id = "setSelection", visible = isRect }

        dlg:modify { id = "padding", visible = (not isEdges) and (not isRect) }
    end
}

dlg:newrow { always = false }

dlg:number {
    id = "leftEdge",
    label = "Top Left:",
    text = string.format("%d", defaults.leftEdge),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "EDGES"
}

dlg:number {
    id = "topEdge",
    text = string.format("%d", defaults.topEdge),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "EDGES"
}

dlg:newrow { always = false }

dlg:number {
    id = "rightEdge",
    label = "Bottom Right:",
    text = string.format("%d", defaults.rightEdge),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "EDGES"
}

dlg:number {
    id = "bottomEdge",
    text = string.format("%d", defaults.bottomEdge),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "EDGES"
}

dlg:newrow { always = false }

dlg:number {
    id = "xtlRect",
    label = "Top Left:",
    text = string.format("%d", defaults.xtlRect),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:number {
    id = "ytlRect",
    text = string.format("%d", defaults.ytlRect),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:newrow { always = false }

dlg:number {
    id = "wRect",
    label = "Size:",
    text = string.format("%d", wRectSet),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:number {
    id = "hRect",
    text = string.format("%d", hRectSet),
    decimals = 0,
    focus = false,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:newrow { always = false }

dlg:button {
    id = "rectAlignTl",
    label = "Align:",
    text = "TL",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        dlg:modify { id = "xtlRect", text = string.format("%d", 0) }
        dlg:modify { id = "ytlRect", text = string.format("%d", 0) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignTc",
    text = "TC",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local xtlRect <const> = math.floor((wSprite - wRect) * 0.5)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", 0) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignTr",
    text = "TR",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local xtlRect <const> = (wSprite - 1) - (wRect - 1)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", 0) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:newrow { always = false }

dlg:button {
    id = "rectAlignCl",
    text = "CL",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local hRect <const> = args.hRect --[[@as integer]]
        local hSprite <const> = activeSprite.height
        local ytlRect <const> = math.floor((hSprite - hRect) * 0.5)
        dlg:modify { id = "xtlRect", text = string.format("%d", 0) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignC",
    text = "C",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local hRect <const> = args.hRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local hSprite <const> = activeSprite.height
        local xtlRect <const> = math.floor((wSprite - wRect) * 0.5)
        local ytlRect <const> = math.floor((hSprite - hRect) * 0.5)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignCr",
    text = "CR",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local hRect <const> = args.hRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local hSprite <const> = activeSprite.height
        local xtlRect <const> = (wSprite - 1) - (wRect - 1)
        local ytlRect <const> = math.floor((hSprite - hRect) * 0.5)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:newrow { always = false }

dlg:button {
    id = "rectAlignBl",
    text = "BL",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local hRect <const> = args.hRect --[[@as integer]]
        local hSprite <const> = activeSprite.height
        local ytlRect <const> = (hSprite - 1) - (hRect - 1)
        dlg:modify { id = "xtlRect", text = string.format("%d", 0) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignBc",
    text = "BC",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local hRect <const> = args.hRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local hSprite <const> = activeSprite.height
        local xtlRect <const> = math.floor((wSprite - wRect) * 0.5)
        local ytlRect <const> = (hSprite - 1) - (hRect - 1)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:button {
    id = "rectAlignBr",
    text = "BR",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end
        local args <const> = dlg.data
        local wRect <const> = args.wRect --[[@as integer]]
        local hRect <const> = args.hRect --[[@as integer]]
        local wSprite <const> = activeSprite.width
        local hSprite <const> = activeSprite.height
        local xtlRect <const> = (wSprite - 1) - (wRect - 1)
        local ytlRect <const> = (hSprite - 1) - (hRect - 1)
        dlg:modify { id = "xtlRect", text = string.format("%d", xtlRect) }
        dlg:modify { id = "ytlRect", text = string.format("%d", ytlRect) }
    end,
    visible = defaults.cropType == "RECTANGLE"
}

dlg:newrow { always = false }

dlg:button {
    id = "setSelection",
    label = "Set:",
    text = "MASK",
    focus = false,
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then return end

        local args <const> = dlg.data
        local xtlRect <const> = args.xtlRect --[[@as integer]]
        local ytlRect <const> = args.ytlRect --[[@as integer]]
        local wRect <const> = args.wRect --[[@as integer]]
        local hRect <const> = args.hRect --[[@as integer]]

        local selRect <const> = Rectangle(xtlRect, ytlRect, wRect, hRect)
        local intRect <const> = selRect:intersect(activeSprite.bounds)
        if not intRect.isEmpty then
            activeSprite.selection = Selection(intRect)
            app.refresh()
        end
    end,
    -- visible = defaults.cropType == "RECTANGLE"
    visible = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = defaults.padding,
    visible = defaults.cropType ~= "EDGES"
        and defaults.cropType ~= "RECT"
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked,
    focus = false,
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden,
    focus = false,
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
        local alphaIndex <const> = spec.transparentColor

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
        local useEdges <const> = cropType == "EDGES"
        local useRect <const> = cropType == "RECTANGLE"
        local useExpand <const> = cropType == "EXPAND"
        local useSel <const> = cropType == "SELECTION"

        -- Record minimum and maximum positions.
        local xMin = 2147483647
        local yMin = 2147483647
        local xMax = -2147483648
        local yMax = -2147483648

        if activeSprite.backgroundLayer then
            xMin = 0
            yMin = 0
            xMax = wSprite - 1
            yMax = hSprite - 1
        end

        -- Test to see if there is a background layer.
        -- If so, remove it. Backgrounds in indexed color
        -- mode may contain transparency.
        app.transaction("Background to Layer", function()
            AseUtilities.bkgToLayer(activeSprite, includeLocked)
        end)

        local sel = nil
        local isValid = false
        if useSel then
            sel, isValid = AseUtilities.getSelection(activeSprite)
        elseif useEdges then
            local leftEdge <const> = args.leftEdge
                or defaults.leftEdge --[[@as integer]]
            local topEdge <const> = args.topEdge
                or defaults.topEdge --[[@as integer]]
            local rightEdge <const> = args.rightEdge
                or defaults.rightEdge --[[@as integer]]
            local bottomEdge <const> = args.bottomEdge
                or defaults.bottomEdge --[[@as integer]]

            -- The sign for edges is reversed to match Aseprite convention.
            sel = Selection(Rectangle(
                -leftEdge, -topEdge,
                wSprite + (rightEdge + leftEdge),
                hSprite + (bottomEdge + topEdge)))
            isValid = not sel.isEmpty
        elseif useRect then
            local xtlRect <const> = args.xtlRect
                or defaults.xtlRect --[[@as integer]]
            local ytlRect <const> = args.ytlRect
                or defaults.ytlRect --[[@as integer]]
            local wRect <const> = args.wRect
                or wRectSet --[[@as integer]]
            local hRect <const> = args.hRect
                or hRectSet --[[@as integer]]

            sel = Selection(Rectangle(xtlRect, ytlRect, wRect, hRect))
            isValid = not sel.isEmpty
        end

        local leaves <const> = AseUtilities.getLayerHierarchy(
            activeSprite,
            includeLocked, includeHidden, true, false)
        local lenLeaves <const> = #leaves
        local frIdcs <const> = AseUtilities.frameObjsToIdcs(activeSprite.frames)
        local cels <const> = AseUtilities.getUniqueCelsFromLeaves(
            leaves, frIdcs)
        local lenCels <const> = #cels

        -- Used in naming transactions by frame.
        local docPrefs <const> = app.preferences.document(activeSprite)
        local tlPrefs <const> = docPrefs.timeline
        local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

        -- Cache methods used in loop.
        local selectCel <const> = AseUtilities.trimCelToSelect
        local cropCel <const> = AseUtilities.trimCelToSprite
        local trimImage <const> = AseUtilities.trimImageAlpha
        local trimMap <const> = AseUtilities.trimMapAlpha
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
            local isTilemap <const> = layer.isTilemap

            local frObj <const> = cel.frame
            local frIdx <const> = frObj and frObj.frameNumber or 1

            local wTile = 1
            local hTile = 1
            if isTilemap then
                local tileSet <const> = layer.tileset
                if tileSet then
                    local tileDim <const> = tileSet.grid.tileSize
                    wTile = tileDim.width
                    hTile = tileDim.height
                end
            end

            local tlx = celPos.x
            local tly = celPos.y
            local brx = tlx + wTile * celImg.width - 1
            local bry = tly + hTile * celImg.height - 1

            if sel and (not isTilemap) then
                transact(strfmt("Crop %d %s", frIdx + frameUiOffset, layerName),
                    function() selectCel(cel, sel) end)
                celPos = cel.position
                tlx = celPos.x
                tly = celPos.y
                celImg = cel.image
                brx = tlx + celImg.width - 1
                bry = tly + celImg.height - 1
            else
                local xTrm = 0
                local yTrm = 0
                local trimmed = celImg

                if isTilemap then
                    trimmed, xTrm, yTrm = trimMap(
                        celImg, alphaIndex, wTile, hTile)
                else
                    trimmed, xTrm, yTrm = trimImage(celImg, 0, alphaIndex)
                end

                tlx = tlx + xTrm
                tly = tly + yTrm
                brx = tlx + wTile * trimmed.width - 1
                bry = tly + hTile * trimmed.height - 1

                transact(
                    strfmt("Trim %d %s", frIdx + frameUiOffset, layerName),
                    function()
                        cel.position = Point(tlx, tly)
                        cel.image = trimmed
                    end)
                celPos = cel.position
                celImg = cel.image

                if useCrop and (not isTilemap) then
                    transact(strfmt("Crop %d %s", frIdx + frameUiOffset,
                        layerName), function()
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

        if sel then
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
                local wCrop <const> = 1 + xMax - xMin
                local hCrop <const> = 1 + yMax - yMin

                sel, isValid = AseUtilities.getSelection(activeSprite)
                if isValid then
                    sel:intersect(Rectangle(xMin, yMin, wCrop, hCrop))
                    activeSprite.selection = sel
                end

                activeSprite:crop(xMin, yMin, wCrop, hCrop)
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

        -- Trim cels cannot be optional due to invalid cel boundaries.
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
            app.transaction("Cull Frames Reverse", function()
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

            app.transaction("Cull Frames Forward", function()
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

        app.layer = activeSprite.layers[#activeSprite.layers]
        app.refresh()

        if app.preferences.editor.auto_fit then
            app.command.FitScreen()
        else
            app.command.Zoom {
                action = "set",
                focus = "center",
                percentage = 100.0
            }
            app.command.ScrollCenter()
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