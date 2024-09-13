dofile("../../support/aseutilities.lua")

local brushOptions <const> = { "CIRCLE", "SQUARE" }
local shiftOptions <const> = { "CARDINAL", "DIAGONAL", "DIMETRIC" }
local selModes <const> = { "REPLACE", "ADD", "SUBTRACT", "INTERSECT" }

local defaults <const> = {
    -- TODO: Button to select in a circle around the cursor?
    -- Maybe by brush size? Maybe modify the EXPAND command if there's
    -- no room for a new button.
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

    -- This makes undoing with Ctrl+Z tedious, but in other cases the double
    -- mask invert needed to be outside a transaction anyway.
    local selCurr <const>, _ <const> = AseUtilities.getSelection(activeSprite)
    local selNext <const> = Selection()
    selNext:add(selCurr)
    local selOrigin <const> = selCurr.origin
    selNext.origin = Point(selOrigin.x + dx, selOrigin.y - dy)
    app.transaction("Nudge Mask", function()
        activeSprite.selection = selNext
    end)
    app.refresh()

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

    local srcImg = activeCel.image

    app.transaction("Extrude Cel", function()
        local celBounds <const> = activeCel.bounds
        local xCel = celBounds.x
        local yCel = celBounds.y

        if trim then
            local trm <const>, tmx <const>, tmy <const> = AseUtilities.trimImageAlpha(
                srcImg, 0, 0)
            srcImg = trm
            xCel = xCel + tmx
            yCel = yCel + tmy
        end

        local trgImg <const>, tlx <const>, tly <const> = AseUtilities.blendImage(
            srcImg, srcImg,
            xCel, yCel, xCel + dx, yCel - dy,
            selNext, true)

        activeCel.image = trgImg
        activeCel.position = Point(tlx, tly)
    end)

    app.refresh()
end

---@param sprite Sprite
---@param trgSel Selection
---@param selMode "REPLACE"|"ADD"|"SUBTRACT"|"INTERSECT"
local function updateSel(sprite, trgSel, selMode)
    -- TODO: Generalize this to an AseUtilities method to keep
    -- consistency with colorSelect and transformTile?
    if selMode ~= "REPLACE" then
        local activeSel <const>,
        selIsValid <const> = AseUtilities.getSelection(sprite)
        if selIsValid then
            if selMode == "INTERSECT" then
                activeSel:intersect(trgSel)
            elseif selMode == "SUBTRACT" then
                activeSel:subtract(trgSel)
            else
                -- See https://github.com/aseprite/aseprite/issues/4045 .
                activeSel:add(trgSel)
            end
            sprite.selection = activeSel
        else
            sprite.selection = trgSel
        end
    else
        sprite.selection = trgSel
    end
end

local dlg <const> = Dialog { title = "Selection" }

dlg:slider {
    id = "amount",
    label = "Amount:",
    min = 1,
    max = 96,
    value = defaults.amount
}

dlg:separator { id = "extrudeSep", text = "Extrude" }

dlg:combobox {
    id = "shiftOption",
    label = "Direction:",
    option = defaults.shiftOption,
    options = shiftOptions
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
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local spec <const> = sprite.spec

        local docPrefs <const> = app.preferences.document(sprite)
        local symPrefs <const> = docPrefs.symmetry
        local symMode <const> = symPrefs.mode --[[@as integer]]

        local w = math.ceil(spec.width * 0.5)
        if symMode == 1 or symMode == 3 then
            local xAxis <const> = symPrefs.x_axis --[[@as number]]
            w = math.ceil(xAxis)
        end

        local trgSel <const> = Selection(Rectangle(
            0, 0, w, spec.height))
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
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local spec <const> = sprite.spec

        local docPrefs <const> = app.preferences.document(sprite)
        local symPrefs <const> = docPrefs.symmetry
        local symMode <const> = symPrefs.mode --[[@as integer]]

        local x = spec.width // 2
        local w = math.ceil(spec.width * 0.5)
        if symMode == 1 or symMode == 3 then
            local xAxis <const> = symPrefs.x_axis --[[@as number]]
            x = math.floor(xAxis)
            w = math.ceil(spec.width - xAxis)
        end

        local trgSel <const> = Selection(Rectangle(
            x, 0, w, spec.height))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:button {
    id = "inSquareButton",
    text = "S&QUARE",
    focus = false,
    visible = false,
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
        local x <const> = (w == short) and 0 or (w - short) // 2
        local y <const> = (h == short) and 0 or (h - short) // 2
        local trgSel <const> = Selection(Rectangle(x, y, short, short))
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
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local spec <const> = sprite.spec

        local docPrefs <const> = app.preferences.document(sprite)
        local symPrefs <const> = docPrefs.symmetry
        local symMode <const> = symPrefs.mode --[[@as integer]]

        local h = math.ceil(spec.height * 0.5)
        if symMode == 2 or symMode == 3 then
            local yAxis <const> = symPrefs.y_axis --[[@as number]]
            h = math.ceil(yAxis)
        end

        local trgSel <const> = Selection(Rectangle(
            0, 0, spec.width, h))
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
        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]
        local spec <const> = sprite.spec

        local docPrefs <const> = app.preferences.document(sprite)
        local symPrefs <const> = docPrefs.symmetry
        local symMode <const> = symPrefs.mode --[[@as integer]]

        local y = spec.height // 2
        local h = math.ceil(spec.height * 0.5)
        if symMode == 2 or symMode == 3 then
            local yAxis <const> = symPrefs.y_axis --[[@as number]]
            y = math.floor(yAxis)
            h = math.ceil(spec.height - yAxis)
        end

        local trgSel <const> = Selection(Rectangle(
            0, y, spec.width, h))
        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:button {
    id = "inCircButton",
    text = "C&IRCLE",
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
        local short <const> = math.min(w, h)
        local len <const> = short * short

        local pxRect <const> = Rectangle(0, 0, 1, 1)
        local xtl <const> = (w == short) and 0 or (w - short) // 2
        local ytl <const> = (h == short) and 0 or (h - short) // 2
        local trgSel <const> = Selection(Rectangle(xtl, ytl, short, short))

        local radius <const> = short * 0.5
        local rsq <const> = radius * radius
        local cx <const> = w // 2
        local cy <const> = h // 2

        local i = 0
        while i < len do
            local x <const> = xtl + i % short
            local y <const> = ytl + i // short
            local dx <const> = x - cx
            local dy <const> = y - cy
            if (dx * dx + dy * dy) >= rsq then
                pxRect.x = x
                pxRect.y = y
                trgSel:subtract(pxRect)
            end
            i = i + 1
        end

        updateSel(sprite, trgSel, selMode)
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "frameSelectButton",
    text = "&FRAME",
    focus = true,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local flat <const> = Image(activeSprite.spec)
        flat:drawSprite(activeSprite, activeFrame)
        local trgSel <const> = AseUtilities.selectImage(flat, 0, 0)

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
    id = "celSelectButton",
    text = "C&EL",
    focus = false,
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
    id = "cursorSelectButton",
    text = "C&URSOR",
    focus = false,
    visible = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local xMouse <const>, yMouse <const> = AseUtilities.getMouse()

        local args <const> = dlg.data
        local selMode <const> = args.selMode
            or defaults.selMode --[[@as string]]

        local trgSel <const> = Selection()

        local brush <const> = app.brush
        local brushType <const> = brush.type
        if brushType == BrushType.IMAGE then
            local brushImage <const> = brush.image
            if brushImage then
                local brushCenter <const> = brush.center
                local xBrCenter <const> = brushCenter.x
                local yBrCenter <const> = brushCenter.y

                local imgSel <const> = AseUtilities.selectImage(
                    brushImage, 0, 0, nil, activeSprite.bounds)
                imgSel.origin = Point(
                    xMouse - xBrCenter,
                    yMouse - yBrCenter)
                trgSel:add(imgSel)
            else
                trgSel:add(Rectangle(xMouse, yMouse, 1, 1))
            end
        else
            local amount <const> = args.amount
                or defaults.amount --[[@as integer]]
            local area <const> = amount * amount
            local center <const> = amount * 0.5
            local xtl <const> = xMouse - center
            local ytl <const> = yMouse - center
            local rsq <const> = center * center
            local pxRect <const> = Rectangle(0, 0, 1, 1)
            local floor <const> = math.floor

            local i = 0
            while i < area do
                local x <const> = xtl + i % amount
                local y <const> = ytl + i // amount
                local dx <const> = x - xMouse
                local dy <const> = y - yMouse
                if dx * dx + dy * dy < rsq then
                    pxRect.x = floor(x)
                    pxRect.y = floor(y)
                    trgSel:add(pxRect)
                end
                i = i + 1
            end
        end

        trgSel:intersect(activeSprite.bounds)

        app.transaction("Select Cel", function()
            updateSel(activeSprite, trgSel, selMode)
        end)
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
    dlgBounds.x * 2 - 52, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)