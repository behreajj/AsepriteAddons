dofile("../../support/aseutilities.lua")

local brushOptions = { "CIRCLE", "SQUARE" }
local shiftOptions = { "CARDINAL", "DIAGONAL", "DIMETRIC" }
local selModes = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults = {
    amount = 1,
    shiftOption = "CARDINAL",
    brushOption = "CIRCLE",
    trimCels = true
}

local shifts = {
    ortho = {
        right = { 1, 0 },
        up = { 0, 1 },
        left = { -1, 0 },
        down = { 0, -1 }
    },
    diagonal = {
        right = { 1, -1 },
        up = { 1, 1 },
        left = { -1, 1 },
        down = { -1, -1 }
    },
    dimetric = {
        right = { 2, -1 },
        up = { 2, 1 },
        left = { -2, 1 },
        down = { -2, -1 }
    }
}

---@param str string
---@return { right: integer[], up: integer[], left: integer[], down: integer[] }
local function shiftFromStr(str)
    if str == "DIAGONAL" then
        return shifts.diagonal
    elseif str == "DIMETRIC" then
        return shifts.dimetric
    end
    return shifts.ortho
end

---@param dx integer
---@param dy integer
---@param trim boolean
local function extrude(dx, dy, trim)
    local site = app.site
    local activeSprite = site.sprite
    if not activeSprite then return end
    local activeCel = site.cel
    if not activeCel then return end

    local srcImage = activeCel.image
    local srccm = srcImage.colorMode
    if srccm == ColorMode.TILEMAP then
        app.alert {
            title = "Error",
            text = "Tile maps are not supported."
        }
        return
    end

    app.transaction("Extrude", function()
        local celBounds = activeCel.bounds
        local xCel = celBounds.x
        local yCel = celBounds.y

        if trim then
            local trm, tmx, tmy = AseUtilities.trimImageAlpha(
                srcImage, 0, 0)
            srcImage = trm
            xCel = xCel + tmx
            yCel = yCel + tmy
        end

        local selCurr = AseUtilities.getSelection(activeSprite)
        local selOrigin = selCurr.origin

        local selNext = Selection()
        selNext:add(selCurr)
        selNext.origin = Point(
            selOrigin.x + dx,
            selOrigin.y - dy)

        local trgImage, tlx, tly = AseUtilities.blendImage(
            srcImage, srcImage,
            xCel, yCel, xCel + dx, yCel - dy,
            selNext, true)

        activeCel.image = trgImage
        activeCel.position = Point(tlx, tly)
        activeSprite.selection = selNext
    end)

    app.refresh()
end

---@param dx integer
---@param dy integer
local function nudgeCel(dx, dy)
    local site = app.site
    local activeSprite = site.sprite
    if not activeSprite then return end
    local activeCel = site.cel
    if not activeCel then return end
    local srcPos = activeCel.position
    activeCel.position = Point(srcPos.x + dx, srcPos.y - dy)
    app.refresh()
end

local dlg = Dialog { title = "Extrude" }

dlg:combobox {
    id = "shiftOption",
    label = "Direction:",
    option = defaults.shiftOption,
    options = shiftOptions
}

dlg:slider {
    id = "amount",
    label = "Amount:",
    min = 1,
    max = 96,
    value = defaults.amount
}

dlg:newrow { always = false }

dlg:check {
    id = "trimCels",
    label = "Trim:",
    text = "Layer Ed&ges",
    selected = defaults.trimCels
}

dlg:newrow { always = false }

dlg:button {
    id = "wExtrude",
    label = "Extrude:",
    text = "&W",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount --[[@as integer]]
        local trim = args.trimCels --[[@as boolean]]
        local shift = args.shiftOption --[[@as string]]
        local tr = shiftFromStr(shift)
        extrude(tr.up[1] * amount,
            tr.up[2] * amount, trim)
    end
}

dlg:button {
    id = "aExtrude",
    text = "&A",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount --[[@as integer]]
        local trim = args.trimCels --[[@as boolean]]
        local shift = args.shiftOption --[[@as string]]
        local dir = shiftFromStr(shift)
        extrude(dir.left[1] * amount,
            dir.left[2] * amount, trim)
    end
}

dlg:button {
    id = "sExtrude",
    text = "&S",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount --[[@as integer]]
        local trim = args.trimCels --[[@as boolean]]
        local shift = args.shiftOption --[[@as string]]
        local dir = shiftFromStr(shift)
        extrude(dir.down[1] * amount,
            dir.down[2] * amount, trim)
    end
}

dlg:button {
    id = "dExtrude",
    text = "&D",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount --[[@as integer]]
        local trim = args.trimCels --[[@as boolean]]
        local shift = args.shiftOption --[[@as string]]
        local dir = shiftFromStr(shift)
        extrude(dir.right[1] * amount,
            dir.right[2] * amount, trim)
    end
}

dlg:separator { id = "celSep", text = "Cel" }

dlg:button {
    id = "iNudge",
    label = "Nudge:",
    text = "&I",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount  --[[@as integer]]
        local shift = args.shiftOption --[[@as string]]
        local tr = shiftFromStr(shift)
        nudgeCel(
            tr.up[1] * amount,
            tr.up[2] * amount)
    end
}

dlg:button {
    id = "jNudge",
    text = "&J",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount  --[[@as integer]]
        local shift = args.shiftOption --[[@as string]]
        local tr = shiftFromStr(shift)
        nudgeCel(
            tr.left[1] * amount,
            tr.left[2] * amount)
    end
}

dlg:button {
    id = "kNudge",
    text = "&K",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount  --[[@as integer]]
        local shift = args.shiftOption --[[@as string]]
        local tr = shiftFromStr(shift)
        nudgeCel(
            tr.down[1] * amount,
            tr.down[2] * amount)
    end
}

dlg:button {
    id = "lNudge",
    text = "&L",
    focus = false,
    onclick = function()
        local args = dlg.data
        local amount = args.amount  --[[@as integer]]
        local shift = args.shiftOption --[[@as string]]
        local tr = shiftFromStr(shift)
        nudgeCel(
            tr.right[1] * amount,
            tr.right[2] * amount)
    end
}

dlg:separator { id = "maskSep", text = "Mask" }

dlg:combobox {
    id = "selMode",
    label = "Select:",
    -- option = selModes[1 + app.preferences.selection.mode],
    option = "REPLACE",
    options = selModes
}

dlg:newrow { always = false }

dlg:combobox {
    id = "brushOption",
    label = "Brush:",
    option = defaults.brushOption,
    options = brushOptions
}

dlg:newrow { always = false }

dlg:button {
    id = "expandButton",
    text = "E&XPAND",
    focus = false,
    onclick = function()
        local args = dlg.data
        local brushOption = args.brushOption --[[@as string]]
        local amount = args.amount --[[@as integer]]
        app.command.ModifySelection {
            modifier = "expand",
            brush = string.lower(brushOption),
            quantity = amount
        }
    end
}

dlg:button {
    id = "contractButton",
    text = "C&ONTRACT",
    focus = false,
    onclick = function()
        local args = dlg.data
        local brushOption = args.brushOption --[[@as string]]
        local amount = args.amount --[[@as integer]]
        app.command.ModifySelection {
            modifier = "contract",
            brush = string.lower(brushOption),
            quantity = amount
        }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "contentButton",
    text = "C&EL",
    focus = false,
    onclick = function()
        local site = app.site
        local activeSprite = site.sprite
        if not activeSprite then return end
        local activeCel = site.cel
        if not activeCel then return end

        local trgSel = AseUtilities.selectCel(
            activeCel, activeSprite.bounds)

        local args = dlg.data
        local selMode = args.selMode
            or defaults.selMode --[[@as string]]
        if selMode ~= "REPLACE" then
            local activeSel = AseUtilities.getSelection(activeSprite)

            if selMode == "INTERSECT" then
                activeSel:intersect(trgSel)
            elseif selMode == "SUBTRACT" then
                activeSel:subtract(trgSel)
            else
                -- Additive selection can be confusing when no prior
                -- selection is made and getSelection returns the cel
                -- bounds, which is cruder than trgSel. However, there
                -- could be a square selection contained by, but
                -- differently shaped than trgSel.
                activeSel:add(trgSel)
            end

            activeSprite.selection = activeSel
        else
            activeSprite.selection = trgSel
        end

        app.refresh()
    end
}

dlg:button {
    id = "borderButton",
    text = "&BORDER",
    focus = false,
    onclick = function()
        local args = dlg.data
        local brushOption = args.brushOption --[[@as string]]
        local amount = args.amount --[[@as integer]]
        app.command.ModifySelection {
            modifier = "border",
            brush = string.lower(brushOption),
            quantity = amount
        }
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