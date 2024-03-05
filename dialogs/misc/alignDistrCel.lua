dofile("../../support/aseutilities.lua")

local frameTargetOptions <const> = { "ACTIVE", "ALL", "RANGE" }
local layerTargetOptions <const> = { "ALL", "RANGE" }

local defaults <const> = {
    -- For full range of options, such as layer filter toggles and frame range,
    -- see layersExport.
    layerTarget = "ALL",
    includeLocked = false,
    includeHidden = false,
    includeTiles = true,
    includeBkg = false,
    frameTarget = "ACTIVE",
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
local function alignLeft(
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
local function alignCenterHoriz(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return math.floor(0.5 + xCenter - srcBounds.width * 0.5), srcBounds.y
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
local function alignRight(
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
local function alignTop(
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
local function alignCenterVert(
    srcBounds,
    xMinEdge, xCenter, xMaxEdge,
    yMinEdge, yCenter, yMaxEdge, fac)
    return srcBounds.x, math.floor(0.5 + yCenter - srcBounds.height * 0.5)
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
local function alignBottom(
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
    local xtl <const> = math.floor(0.5 + xCelCenter - wCelHalf)
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
    local ytl <const> = math.floor(0.5 + yCelCenter - hCelHalf)
    return srcBounds.x, ytl
end

---@param dialog Dialog
---@param preset "LEFT"|"CENTER_HORIZ"|"RIGHT"|"TOP"|"CENTER_VERT"|"BOTTOM"|"DISTR_HORIZ"|"DISTR_VERT"
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
    local frameTarget <const> = args.frameTarget
        or defaults.frameTarget --[[@as string]]
    local layerTarget <const> = args.layerTarget
        or defaults.layerTarget --[[@as string]]
    local includeLocked <const> = args.includeLocked --[[@as boolean]]
    local includeHidden <const> = args.includeHidden --[[@as boolean]]
    local includeTiles <const> = args.includeTiles --[[@as boolean]]
    local includeBkg <const> = args.includeBkg --[[@as boolean]]

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
    if lenFilteredLayers < 2 then
        app.alert {
            title = "Error",
            text = "At least 2 layers must be selected."
        }
        return
    end

    app.transaction("Commit Mask", function()
        app.command.InvertMask()
        app.command.InvertMask()
    end)

    local docPrefs <const> = app.preferences.document(activeSprite)
    local tlPrefs <const> = docPrefs.timeline
    local frameUiOffset <const> = tlPrefs.first_frame - 1 --[[@as integer]]

    local celFunc = nil
    if preset == "LEFT" then
        celFunc = alignLeft
    elseif preset == "CENTER_HORIZ" then
        celFunc = alignCenterHoriz
    elseif preset == "RIGHT" then
        celFunc = alignRight
    elseif preset == "TOP" then
        celFunc = alignTop
    elseif preset == "CENTER_VERT" then
        celFunc = alignCenterVert
    elseif preset == "DISTR_HORIZ" then
        celFunc = distrHoriz
    elseif preset == "DISTR_VERT" then
        celFunc = distrVert
    else
        -- Default to bottom
        celFunc = alignBottom
    end

    local transactPrefix = "Align"
    if preset == "DISTR_HORIZ"
        or preset == "DISTR_VERT" then
        transactPrefix = "Distribute"
    end

    local sortFunc = nil
    if preset == "DISTR_VERT"
        or preset == "CENTER_VERT"
        or preset == "TOP"
        or preset == "BOTTOM" then
        sortFunc = function(a, b)
            local aBounds <const> = a.bounds
            local bBounds <const> = b.bounds
            local ayCenter <const> = aBounds.y + aBounds.height * 0.5
            local byCenter <const> = bBounds.y + bBounds.height * 0.5
            return ayCenter < byCenter
        end
    else
        -- Default to horizontal.
        sortFunc = function(a, b)
            local aBounds <const> = a.bounds
            local bBounds <const> = b.bounds
            local axCenter <const> = aBounds.x + aBounds.width * 0.5
            local bxCenter <const> = bBounds.x + bBounds.width * 0.5
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
        local xMinEdge = wSprite
        local xMaxEdge = 0
        local yMinEdge = hSprite
        local yMaxEdge = 0
        -- local xMinEdge = 2147483647
        -- local xMaxEdge = -2147483648
        -- local yMinEdge = 2147483647
        -- local yMaxEdge = -2147483648

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
            if cel then
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

        local kToFac <const> = 1.0 / (lenCels - 1.0)
        local xCenter <const> = (xMinEdge + xMaxEdge) * 0.5
        local yCenter <const> = (yMinEdge + yMaxEdge) * 0.5

        tsort(cels, sortFunc)

        local transactStr <const> = strfmt(
            "%s %s %d",
            transactPrefix, preset, frameUiOffset + frIdx)
        transact(transactStr, function()
            local k = 0
            while k < lenCels do
                local kFac <const> = k * kToFac
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
    text = "&TOP",
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
    text = "&BOTTOM",
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