dofile("../../support/aseutilities.lua")

local frameTargetOptions <const> = { "ACTIVE", "ALL", "RANGE" }
local layerTargetOptions <const> = { "ACTIVE", "ALL", "RANGE" }
local referToOptions <const> = { "CELS", "SELECTION", "SPRITE", "SYMMETRY" }
local inOutOptions <const> = { "INSIDE", "OUTSIDE" }

local defaults <const> = {
    -- Refer to Inkscape for UI/UX.
    layerTarget = "ALL",
    includeLocked = false,
    includeHidden = false,
    includeTiles = true,
    includeBkg = false,
    frameTarget = "ACTIVE",
    referTo = "SPRITE",
    inOut = "INSIDE",
    sortCels = true,
}

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignLeftInside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return xMinEdge, srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignLeftOutside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return xMinEdge - srcBounds.width, srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignCenterHoriz(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    -- For greater granularity, make sign 0, 0.5 or 1.0 a parameter.
    -- Center on axis:
    return Utilities.round(xCenter - srcBounds.width * 0.5), srcBounds.y
    -- On left edge, body to right of axis:
    -- return Utilities.round(xCenter - srcBounds.width * 0.0), srcBounds.y
    -- On right edge, body to left of axis:
    -- return Utilities.round(xCenter - srcBounds.width * 1.0), srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignRightInside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return xMaxEdge + 1 - srcBounds.width, srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignRightOutside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return xMaxEdge + 1, srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignTopInside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, yMinEdge
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignTopOutside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, yMinEdge - srcBounds.h
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignCenterVert(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, Utilities.round(yCenter - srcBounds.height * 0.5)
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignBottomInside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, yMaxEdge + 1 - srcBounds.height
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function alignBottomOutside(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, yMaxEdge + 1
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function distrHoriz(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    if fac <= 0.0 then return xMinEdge, srcBounds.y end
    if fac >= 1.0 then return xMaxEdge + 1 - srcBounds.width, srcBounds.y end
    local u <const> = 1.0 - fac
    local wCelHalf <const> = srcBounds.width * 0.5
    local xCelCenter <const> = u * (xMinEdge + wCelHalf)
        + fac * (xMaxEdge - wCelHalf)
    local xtl <const> = Utilities.round(xCelCenter - wCelHalf)
    return xtl, srcBounds.y
end

---@param srcBounds Rectangle
---@param xMinEdge integer
---@param xCenter number
---@param xMaxEdge integer
---@param yMinEdge integer
---@param yCenter number
---@param yMaxEdge integer
---@param fac number
---@return integer
---@return integer
local function distrVert(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    if fac <= 0.0 then return srcBounds.x, yMinEdge end
    if fac >= 1.0 then return srcBounds.x, yMaxEdge + 1 - srcBounds.height end
    local u <const> = 1.0 - fac
    local hCelHalf <const> = srcBounds.height * 0.5
    local yCelCenter <const> = u * (yMinEdge + hCelHalf)
        + fac * (yMaxEdge - hCelHalf)
    local ytl <const> = Utilities.round(yCelCenter - hCelHalf)
    return srcBounds.x, ytl
end

---@param preset string
local function restackLayers(preset)
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

    local activeFrame <const> = site.frame
    if not activeFrame then
        app.alert {
            title = "Error",
            text = "There is no active frame."
        }
        return
    end

    local activeLayer <const> = site.layer
    if not activeLayer then
        app.alert {
            title = "Error",
            text = "There is no active layer."
        }
        return
    end

    local parent <const> = activeLayer.parent
    local neighbors <const> = parent.layers
    if not neighbors then return end
    local lenNeighbors = #neighbors

    ---@type Layer[]
    local filteredLayers <const> = {}
    ---@type integer[]
    local stackIndices <const> = {}
    local lenFiltered = 0
    local h = 0
    while h < lenNeighbors do
        h = h + 1
        local neighbor <const> = neighbors[h]
        if not neighbor.isBackground then
            lenFiltered = lenFiltered + 1
            filteredLayers[lenFiltered] = neighbor
            stackIndices[lenFiltered] = neighbor.stackIndex
        end
    end

    if lenFiltered < 2 then return end

    ---@param a Layer
    ---@param b Layer
    ---@return boolean
    local sortFunc = function(a, b)
        return a.stackIndex < b.stackIndex
    end

    local transactPrefix = "Stack Layers"
    if preset == "X" then
        ---@param a Layer
        ---@param b Layer
        ---@return boolean
        sortFunc = function(a, b)
            local aCel = a:cel(activeFrame)
            local bCel = b:cel(activeFrame)
            if aCel and bCel then
                local aBounds <const> = aCel.bounds
                local bBounds <const> = bCel.bounds
                local axCenter <const> = aBounds.x + aBounds.width * 0.5
                local bxCenter <const> = bBounds.x + bBounds.width * 0.5
                return axCenter < bxCenter
            end
            return a.stackIndex < b.stackIndex
        end
        transactPrefix = "Stack on X"
    elseif preset == "Y" then
        ---@param a Layer
        ---@param b Layer
        ---@return boolean
        sortFunc = function(a, b)
            local aCel = a:cel(activeFrame)
            local bCel = b:cel(activeFrame)
            if aCel and bCel then
                local aBounds <const> = aCel.bounds
                local bBounds <const> = bCel.bounds
                local ayCenter <const> = aBounds.y + aBounds.height * 0.5
                local byCenter <const> = bBounds.y + bBounds.height * 0.5
                return ayCenter < byCenter
            end
            return a.stackIndex < b.stackIndex
        end
        transactPrefix = "Stack on Y"
    elseif preset == "AREA" then
        ---@param a Layer
        ---@param b Layer
        ---@return boolean
        sortFunc = function(a, b)
            local aCel = a:cel(activeFrame)
            local bCel = b:cel(activeFrame)
            if aCel and bCel then
                local aBounds <const> = aCel.bounds
                local bBounds <const> = bCel.bounds
                local aArea <const> = aBounds.width * aBounds.height
                local bArea <const> = bBounds.width * bBounds.height
                -- Place larger cels on the bottom, smaller on the top.
                return bArea < aArea
            end
            return a.stackIndex < b.stackIndex
        end
        transactPrefix = "Stack by Area"
    elseif preset == "NAME" then
        ---@param a Layer
        ---@param b Layer
        ---@return boolean
        sortFunc = function(a, b)
            return b.name < a.name
        end
        transactPrefix = "Stack by Name"
    elseif preset == "REVERSE" then
        ---@param a Layer
        ---@param b Layer
        ---@return boolean
        sortFunc = function(a, b)
            return b.stackIndex < a.stackIndex
        end
        transactPrefix = "Reverse Layers"
    end

    table.sort(filteredLayers, sortFunc)

    app.transaction(transactPrefix, function()
        local i = 0
        while i < lenFiltered do
            i = i + 1
            local filtered <const> = filteredLayers[i]
            -- Could be nice to preserve composite order by adjusting cel
            -- zIndex, but that would mean having to deal with group leaves
            -- and linked cels not sharing zIndex property.
            -- Could find delta layer stack index, then add to each cel zIndex.
            local newStack <const> = stackIndices[i]
            filtered.stackIndex = newStack
        end
    end)

    app.layer = activeLayer
end

---@param dialog Dialog
---@param preset string
local function alignCels(dialog, preset)
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
    local wSprite <const> = spriteSpec.width
    local hSprite <const> = spriteSpec.height

    local args <const> = dialog.data
    local layerTarget <const> = args.layerTarget
        or defaults.layerTarget --[[@as string]]
    local includeLocked <const> = args.includeLocked --[[@as boolean]]
    local includeHidden <const> = args.includeHidden --[[@as boolean]]
    local includeTiles <const> = args.includeTiles --[[@as boolean]]
    local includeBkg <const> = args.includeBkg --[[@as boolean]]
    local frameTarget <const> = args.frameTarget
        or defaults.frameTarget --[[@as string]]
    local referTo <const> = args.referTo
        or defaults.referTo --[[@as boolean]]
    local inOut <const> = args.inOut
        or defaults.inOut --[[@as string]]
    local sortCels <const> = args.sortCels --[[@as boolean]]

    local docPrefs <const> = app.preferences.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local selFrames <const> = Utilities.flatArr2(AseUtilities.getFrames(
        activeSprite, frameTarget))
    local lenSelFrames = #selFrames
    if lenSelFrames < 1 then
        app.alert {
            title = "Error",
            text = "No frames were selected."
        }
        return
    end

    local filteredLayers <const> = AseUtilities.filterLayers(activeSprite,
        app.site.layer, layerTarget, includeLocked, includeHidden,
        includeTiles, includeBkg)
    local lenFilteredLayers <const> = #filteredLayers
    if lenFilteredLayers < 1 then
        app.alert {
            title = "Error",
            text = "No layers were selected."
        }
        return
    end

    local useAbsRef = referTo ~= "CELS"
    local referToMask = referTo == "SELECTION"
    local referToSym = referTo == "SYMMETRY"

    local xMinRef = 0
    local xMaxRef = wSprite - 1
    local yMinRef = 0
    local yMaxRef = hSprite - 1

    if referToMask then
        local sel <const>, isValid <const> = AseUtilities.getSelection(
            activeSprite)
        if not isValid then
            useAbsRef = false
            referToMask = false
        end
        local selBounds <const> = sel.bounds
        xMinRef = selBounds.x
        xMaxRef = xMinRef + math.max(1, math.abs(selBounds.width)) - 1
        yMinRef = selBounds.y
        yMaxRef = yMinRef + math.max(1, math.abs(selBounds.height)) - 1
    end

    if referToSym then
        local symPrefs <const> = docPrefs.symmetry
        local symMode <const> = symPrefs.mode --[[@as integer]]

        if symMode == 1 or symMode == 3 then
            local xAxis <const> = symPrefs.x_axis --[[@as number]]
            xMinRef = math.floor(xAxis)
            xMaxRef = math.ceil(xAxis)
            if xMinRef == xMaxRef then
                xMinRef = xMinRef - 1
                xMaxRef = xMaxRef + 1
            end
        end

        if symMode == 2 or symMode == 3 then
            local yAxis <const> = symPrefs.y_axis --[[@as number]]
            yMinRef = math.floor(yAxis)
            yMaxRef = math.ceil(yAxis)
            if yMinRef == yMaxRef then
                yMinRef = yMinRef - 1
                yMaxRef = yMaxRef + 1
            end
        end
    end

    local celFunc = nil
    local transactPrefix = "Transaction"
    local isOutside = (referToMask or referToSym) and inOut == "OUTSIDE"
    if preset == "LEFT" then
        if isOutside then
            celFunc = alignLeftOutside
        else
            celFunc = alignLeftInside
        end
        transactPrefix = "Align Left"
    elseif preset == "CENTER_HORIZ" then
        celFunc = alignCenterHoriz
        transactPrefix = "Align Horizontal Center"
    elseif preset == "RIGHT" then
        if isOutside then
            celFunc = alignRightOutside
        else
            celFunc = alignRightInside
        end
        transactPrefix = "Align Right"
    elseif preset == "TOP" then
        if isOutside then
            celFunc = alignTopOutside
        else
            celFunc = alignTopInside
        end
        transactPrefix = "Align Top"
    elseif preset == "CENTER_VERT" then
        celFunc = alignCenterVert
        transactPrefix = "Align Vertical Center"
    elseif preset == "DISTR_HORIZ" then
        celFunc = distrHoriz
        transactPrefix = "Distribute Horizontal"
    elseif preset == "DISTR_VERT" then
        celFunc = distrVert
        transactPrefix = "Distribute Vertical"
    else
        -- Default to bottom
        if isOutside then
            celFunc = alignBottomOutside
        else
            celFunc = alignBottomInside
        end
        transactPrefix = "Align Bottom"
    end

    ---@param a Cel left comparisand
    ---@param b Cel right comparisand
    ---@return boolean
    local orderSort = function(a, b)
        return a.layer.stackIndex < b.layer.stackIndex
    end

    local sortFunc = orderSort
    if preset == "DISTR_VERT" then
        ---@param a Cel left comparisand
        ---@param b Cel right comparisand
        ---@return boolean
        sortFunc = function(a, b)
            local aBounds <const> = a.bounds
            local bBounds <const> = b.bounds
            local ayCenter <const> = aBounds.y + aBounds.height * 0.5
            local byCenter <const> = bBounds.y + bBounds.height * 0.5
            if ayCenter == byCenter then
                return orderSort(a, b)
            end
            return ayCenter < byCenter
        end
    elseif preset == "DISTR_HORIZ" then
        ---@param a Cel left comparisand
        ---@param b Cel right comparisand
        ---@return boolean
        sortFunc = function(a, b)
            local aBounds <const> = a.bounds
            local bBounds <const> = b.bounds
            local axCenter <const> = aBounds.x + aBounds.width * 0.5
            local bxCenter <const> = bBounds.x + bBounds.width * 0.5
            if axCenter == bxCenter then
                return orderSort(a, b)
            end
            return axCenter < bxCenter
        end
    end

    local strfmt <const> = string.format
    local tsort <const> = table.sort
    local transact <const> = app.transaction

    local i = 0
    while i < lenSelFrames do
        i = i + 1
        local frIdx <const> = selFrames[i]
        local xMinEdge = 2147483647
        local xMaxEdge = -2147483648
        local yMinEdge = 2147483647
        local yMaxEdge = -2147483648

        ---@type Cel[]
        local cels <const> = {}
        local lenCels = 0
        local j = 0
        while j < lenFilteredLayers do
            j = j + 1
            local layer <const> = filteredLayers[j]
            -- Linked cels will be a problem for this, but it's better to give
            -- user the choice of multiple frames and have the same cel be
            -- rearranged multiple times.
            local cel <const> = layer:cel(frIdx)
            if cel and (not cel.image:isEmpty()) then
                lenCels = lenCels + 1
                cels[lenCels] = cel
                local bounds <const> = cel.bounds

                local xLeft <const> = bounds.x
                local yTop <const> = bounds.y
                local xRight <const> = xLeft + bounds.width - 1
                local yBottom <const> = yTop + bounds.height - 1

                if xLeft < xMinEdge then xMinEdge = xLeft end
                if xRight > xMaxEdge then xMaxEdge = xRight end
                if yTop < yMinEdge then yMinEdge = yTop end
                if yBottom > yMaxEdge then yMaxEdge = yBottom end
            end
        end

        if useAbsRef or lenCels < 2 then
            xMinEdge = xMinRef
            xMaxEdge = xMaxRef
            yMinEdge = yMinRef
            yMaxEdge = yMaxRef
        end

        if xMaxEdge > xMinEdge and yMaxEdge > yMinEdge then
            local kToFac <const> = lenCels > 1 and 1.0 / (lenCels - 1.0) or 0.0
            local facOff <const> = lenCels > 1 and 0.0 or 0.5
            local xCenter <const> = (xMinEdge + xMaxEdge) * 0.5
            local yCenter <const> = (yMinEdge + yMaxEdge) * 0.5

            if sortCels then
                tsort(cels, sortFunc)
            end

            local transactStr <const> = strfmt(
                "%s %d",
                transactPrefix, frameUiOffset + frIdx)
            transact(transactStr, function()
                local k = 0
                while k < lenCels do
                    local kFac <const> = k * kToFac + facOff
                    k = k + 1
                    local cel <const> = cels[k]
                    local srcBounds <const> = cel.bounds

                    local xtlTrg, ytlTrg = celFunc(
                        srcBounds,
                        xMinEdge, xCenter, xMaxEdge,
                        yMinEdge, yCenter, yMaxEdge, kFac)
                    cel.position = Point(xtlTrg, ytlTrg)
                end
            end)
        end
    end

    app.refresh()
end

local dlg <const> = Dialog { title = "Align Distribute" }

dlg:combobox {
    id = "layerTarget",
    label = "Layers:",
    option = defaults.layerTarget,
    options = layerTargetOptions
}

dlg:newrow { always = false }

dlg:check {
    id = "includeLocked",
    label = "Include:",
    text = "&Locked",
    selected = defaults.includeLocked
}

dlg:check {
    id = "includeHidden",
    text = "&Hidden",
    selected = defaults.includeHidden
}

dlg:newrow { always = false }

dlg:check {
    id = "includeTiles",
    text = "&Tiles",
    selected = defaults.includeTiles
}

dlg:check {
    id = "includeBkg",
    text = "&Background",
    selected = defaults.includeBkg
}

dlg:newrow { always = false }

dlg:combobox {
    id = "frameTarget",
    label = "Frames:",
    option = defaults.frameTarget,
    options = frameTargetOptions
}

dlg:newrow { always = false }

dlg:combobox {
    id = "referTo",
    label = "Anchor:",
    option = defaults.referTo,
    options = referToOptions,
    onchange = function()
        local args <const> = dlg.data
        local referTo <const> = args.referTo --[[@as string]]
        local isSel <const> = referTo == "SELECTION"
        local isSym <const> = referTo == "SYMMETRY"
        dlg:modify { id = "inOut", visible = isSel or isSym }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "inOut",
    option = defaults.inOut,
    options = inOutOptions,
    visible = defaults.referTo == "SELECTION"
        or defaults.referTo == "SYMMETRY"
}

dlg:separator { id = "alignSep", text = "Align" }

dlg:button {
    id = "alignLeftButton",
    text = "L&EFT",
    label = "X:",
    onclick = function()
        alignCels(dlg, "LEFT")
    end
}

dlg:button {
    id = "alignCenterHorizButton",
    text = "&MIDDLE",
    onclick = function()
        alignCels(dlg, "CENTER_HORIZ")
    end
}

dlg:button {
    id = "alignRightButton",
    text = "&RIGHT",
    onclick = function()
        alignCels(dlg, "RIGHT")
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "alignTopButton",
    text = "TO&P",
    label = "Y:",
    onclick = function()
        alignCels(dlg, "TOP")
    end
}

dlg:button {
    id = "alignCenterVertButton",
    text = "M&IDDLE",
    onclick = function()
        alignCels(dlg, "CENTER_VERT")
    end
}

dlg:button {
    id = "alignBottomButton",
    text = "B&OTTOM",
    onclick = function()
        alignCels(dlg, "BOTTOM")
    end
}

dlg:separator { id = "distrSep", text = "Distribute" }

dlg:button {
    id = "distrHorizButton",
    text = "&X",
    label = "Center:",
    focus = true,
    onclick = function()
        alignCels(dlg, "DISTR_HORIZ")
    end
}

dlg:button {
    id = "distrVertButton",
    text = "&Y",
    onclick = function()
        alignCels(dlg, "DISTR_VERT")
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "sortCels",
    label = "Sort:",
    text = "Position",
    selected = defaults.sortCels
}

dlg:separator { id = "distrSep", text = "Stack" }

dlg:button {
    id = "bringToFrontButton",
    label = "Active:",
    text = "FRONT",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        if not activeLayer then return end

        local layer = activeLayer
        ---@diagnostic disable-next-line: undefined-field
        while layer.parent.__name ~= "doc::Sprite"
            and layer.stackIndex == #layer.parent.layers do
            layer = layer.parent --[[@as Layer]]
        end

        app.transaction("Bring To Front", function()
            layer.stackIndex = #layer.parent.layers
        end)

        app.layer = activeLayer
    end
}

dlg:button {
    id = "sendToBackButton",
    text = "BACK",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end
        local activeLayer <const> = site.layer
        if not activeLayer then return end

        local layer = activeLayer
        ---@diagnostic disable-next-line: undefined-field
        while layer.parent.__name ~= "doc::Sprite"
            and layer.stackIndex == 1 do
            layer = layer.parent --[[@as Layer]]
        end

        app.transaction("Send To Back", function()
            layer.stackIndex = 1
        end)

        app.layer = activeLayer
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "stackxButton",
    text = "X",
    label = "Sort:",
    focus = false,
    onclick = function()
        restackLayers("X")
    end
}

dlg:button {
    id = "stackyButton",
    text = "Y",
    focus = false,
    onclick = function()
        restackLayers("Y")
    end
}

dlg:button {
    id = "stackAreaButton",
    text = "&AREA",
    focus = false,
    onclick = function()
        restackLayers("AREA")
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "stackNameButton",
    text = "NAME",
    focus = false,
    onclick = function()
        restackLayers("NAME")
    end
}

dlg:button {
    id = "stackReverseButton",
    text = "RE&VERSE",
    focus = false,
    onclick = function()
        restackLayers("REVERSE")
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "cancel",
    text = "&CANCEL",
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
    dlgBounds.x * 2 - 52, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)