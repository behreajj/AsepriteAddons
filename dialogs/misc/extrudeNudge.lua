dofile("../../support/aseutilities.lua")

local brushOptions <const> = { "CIRCLE", "SQUARE" }
local shiftOptions <const> = { "CARDINAL", "DIAGONAL", "DIMETRIC" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults <const> = {
    amount = 1,
    shiftOption = "CARDINAL",
    brushOption = "CIRCLE",
    trimCels = true
}

local shifts <const> = {
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
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local activeFrame <const> = site.frame
    if not activeFrame then return end

    local activeLayer <const> = site.layer
    if not activeLayer then return end
    if activeLayer.isGroup then return end
    if activeLayer.isBackground then return end
    if activeLayer.isReference then return end
    if activeLayer.isTilemap then
        app.alert {
            title = "Error",
            text = "Tile maps are not supported."
        }
        return
    end

    local activeCel <const> = activeLayer:cel(activeFrame)
    if not activeCel then return end

    local srcImage = activeCel.image

    app.transaction("Extrude", function()
        local celBounds <const> = activeCel.bounds
        local xCel = celBounds.x
        local yCel = celBounds.y

        if trim then
            local trm <const>, tmx <const>, tmy <const> = AseUtilities.trimImageAlpha(
                srcImage, 0, 0)
            srcImage = trm
            xCel = xCel + tmx
            yCel = yCel + tmy
        end

        local selCurr <const>, _ <const> = AseUtilities.getSelection(activeSprite)
        local selOrigin <const> = selCurr.origin

        local selNext <const> = Selection()
        selNext:add(selCurr)
        selNext.origin = Point(
            selOrigin.x + dx,
            selOrigin.y - dy)

        local trgImage <const>, tlx <const>, tly <const> = AseUtilities.blendImage(
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
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    local activeFrame <const> = site.frame
    if not activeFrame then return end

    local activeLayer <const> = site.layer
    if not activeLayer then return end
    if activeLayer.isBackground then return end

    local activeCel <const> = activeLayer:cel(activeFrame)
    if not activeCel then return end

    local srcPos <const> = activeCel.position
    activeCel.position = Point(srcPos.x + dx, srcPos.y - dy)
    app.refresh()
end

local dlg <const> = Dialog { title = "Extrude" }

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
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local trim <const> = args.trimCels --[[@as boolean]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
        extrude(tr.up[1] * amount,
            tr.up[2] * amount, trim)
    end
}

dlg:button {
    id = "aExtrude",
    text = "&A",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local trim <const> = args.trimCels --[[@as boolean]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
        extrude(dir.left[1] * amount,
            dir.left[2] * amount, trim)
    end
}

dlg:button {
    id = "sExtrude",
    text = "&S",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local trim <const> = args.trimCels --[[@as boolean]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
        extrude(dir.down[1] * amount,
            dir.down[2] * amount, trim)
    end
}

dlg:button {
    id = "dExtrude",
    text = "&D",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local trim <const> = args.trimCels --[[@as boolean]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
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
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
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
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
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
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
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
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
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
        local args <const> = dlg.data
        local brushOption <const> = args.brushOption --[[@as string]]
        local amount <const> = args.amount --[[@as integer]]
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
        local args <const> = dlg.data
        local brushOption <const> = args.brushOption --[[@as string]]
        local amount <const> = args.amount --[[@as integer]]
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
    focus = true,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local activeLayer <const> = site.layer
        if not activeLayer then return end
        if activeLayer.isReference then return end

        local activeCel <const> = activeLayer:cel(activeFrame)
        if not activeCel then return end

        local trgSel <const> = AseUtilities.selectCel(activeCel)

        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        if selMode ~= "REPLACE" then
            local activeSel <const>, selIsValid <const> = AseUtilities.getSelection(activeSprite)

            if selMode == "INTERSECT" then
                activeSel:intersect(trgSel)
                activeSprite.selection = activeSel
            elseif selMode == "SUBTRACT" then
                activeSel:subtract(trgSel)
                activeSprite.selection = activeSel
            else
                -- Additive selection.
                -- See https://github.com/aseprite/aseprite/issues/4045 .
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

        app.refresh()
    end
}

dlg:button {
    id = "borderButton",
    text = "&BORDER",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local brushOption <const> = args.brushOption --[[@as string]]
        local amount <const> = args.amount --[[@as integer]]
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

dlg:show {
    autoscrollbars = true,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    dlgBounds.x * 2 - 16, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)