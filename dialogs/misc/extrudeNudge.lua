dofile("../../support/aseutilities.lua")

local brushOptions <const> = { "CIRCLE", "SQUARE" }
local shiftOptions <const> = { "CARDINAL", "DIAGONAL", "DIMETRIC" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults <const> = {
    amount = 1,
    shiftOption = "CARDINAL",
    selMode = "REPLACE",
    brushOption = "CIRCLE",
    trimCels = true,
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

local function updateSel(sprite, trgSel, selMode)
    if selMode ~= "REPLACE" then
        local activeSel <const>, selIsValid <const> = AseUtilities.getSelection(sprite)

        if selMode == "INTERSECT" then
            activeSel:intersect(trgSel)
            sprite.selection = activeSel
        elseif selMode == "SUBTRACT" then
            activeSel:subtract(trgSel)
            sprite.selection = activeSel
        else
            -- Additive selection.
            -- See https://github.com/aseprite/aseprite/issues/4045 .
            if selIsValid then
                activeSel:add(trgSel)
                sprite.selection = activeSel
            else
                sprite.selection = trgSel
            end
        end
    else
        sprite.selection = trgSel
    end
end

local dlg <const> = Dialog { title = "Selection" }

dlg:separator { id = "extrudeSep", text = "Extrude" }

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

dlg:separator { id = "presetSep", text = "Presets" }

dlg:combobox {
    id = "selMode",
    label = "Logic:",
    -- option = selModes[1 + app.preferences.selection.mode],
    option = defaults.selMode,
    options = selModes
}

dlg:newrow { always = false }

dlg:button {
    id = "leftHalfButton",
    text = "&LEFT",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local trgSel <const> = Selection(Rectangle(
            0, 0, math.ceil(spec.width / 2), spec.height))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:button {
    id = "rightHalfButton",
    text = "&RIGHT",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local trgSel <const> = Selection(Rectangle(
            spec.width // 2, 0, math.ceil(spec.width / 2), spec.height))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "topHalfButton",
    text = "&TOP",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local trgSel <const> = Selection(Rectangle(
            0, 0, spec.width, math.ceil(spec.height / 2)))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:button {
    id = "bottomHalfButton",
    text = "BOTTO&M",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local trgSel <const> = Selection(Rectangle(
            0, spec.height // 2, spec.width, math.ceil(spec.height / 2)))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "centerButton",
    text = "CENTER",
    focus = false,
    visible = false,
    onclick = function()
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local w <const> = spec.width
        local h <const> = spec.height
        local xtl <const> = math.floor(w * 0.5 - w / 6.0)
        local ytl <const> = math.floor(h * 0.5 - h / 6.0)
        local trgSel <const> = Selection(Rectangle(
            xtl, ytl, w - xtl * 2, h - ytl * 2))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}


dlg:button {
    id = "contentButton",
    text = "C&EL",
    focus = true,
    visible = true,
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

        app.transaction("Select Cel", function()
            updateSel(activeSprite, trgSel, selMode)
        end)
        app.refresh()
    end
}

dlg:button {
    id = "inSquareButton",
    text = "INS&QUARE",
    focus = false,
    visible = true,
    onclick = function()
        -- https://en.wikipedia.org/wiki/Rabatment_of_the_rectangle
        local site <const> = app.site
        local sprite <const> = site.sprite
        if not sprite then return end
        local spec <const> = sprite.spec
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local w <const> = spec.width
        local h <const> = spec.height
        local short <const> = math.min(w, h)
        local xtl <const> = (w == short) and 0 or (w - short) // 2
        local ytl <const> = (h == short) and 0 or (h - short) // 2
        local trgSel <const> = Selection(Rectangle(
            xtl, ytl, short, short))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:separator { id = "maskSep", text = "Modify" }

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
    dlgBounds.x * 2 - 32, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)