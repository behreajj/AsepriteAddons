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
local function shiftSel(dx, dy)
    local site <const> = app.site
    local activeSprite <const> = site.sprite
    if not activeSprite then return end

    -- This makes undoing with Ctrl+Z tedious, but in other cases the double
    -- mask invert needed to be outside a transaction anyway.
    local selCurr <const>,
    isValid <const> = AseUtilities.getSelection(activeSprite)
    if not isValid then return end

    local selNext <const> = Selection()
    selNext:add(selCurr)
    local selOrigin <const> = selCurr.origin
    selNext.origin = Point(selOrigin.x + dx, selOrigin.y - dy)
    selNext:intersect(activeSprite.bounds)
    app.transaction("Nudge Mask", function()
        activeSprite.selection = selNext
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

dlg:separator { id = "extrudeSep", text = "Translate" }

dlg:slider {
    id = "amount",
    label = "Amount:",
    min = 1,
    max = 96,
    value = defaults.amount
}

dlg:newrow { always = false }

dlg:combobox {
    id = "shiftOption",
    label = "Grid:",
    option = defaults.shiftOption,
    options = shiftOptions,
    visible = false,
    hexpand = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "wExtrude",
    text = "&W",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local tr <const> = shiftFromStr(shift)
        shiftSel(tr.up[1] * amount,
            tr.up[2] * amount)
    end
}

dlg:button {
    id = "aExtrude",
    text = "&A",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
        shiftSel(dir.left[1] * amount,
            dir.left[2] * amount)
    end
}

dlg:button {
    id = "sExtrude",
    text = "&S",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
        shiftSel(dir.down[1] * amount,
            dir.down[2] * amount)
    end
}

dlg:button {
    id = "dExtrude",
    text = "&D",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local amount <const> = args.amount --[[@as integer]]
        local shift <const> = args.shiftOption --[[@as string]]
        local dir <const> = shiftFromStr(shift)
        shiftSel(dir.right[1] * amount,
            dir.right[2] * amount)
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "toFrameButton",
    label = "To:",
    text = "FRAME",
    focus = false,
    onclick = function()
        local site <const> = app.site
        local activeSprite <const> = site.sprite
        if not activeSprite then return end

        local activeFrame <const> = site.frame
        if not activeFrame then return end

        local selCurr <const>,
        isValid <const> = AseUtilities.getSelection(activeSprite)
        if not isValid then return end

        local flat <const> = Image(activeSprite.spec)
        flat:drawSprite(activeSprite, activeFrame)

        local spriteSpec <const> = activeSprite.spec
        local alphaIndex <const> = spriteSpec.transparentColor
        local trimmed <const>,
        xtlFrame <const>,
        ytlFrame <const> = AseUtilities.trimImageAlpha(flat, 0, alphaIndex)
        local wFrame <const> = trimmed.width
        local hFrame <const> = trimmed.height

        local maskBounds <const> = selCurr.bounds
        local wMask <const> = math.max(1, math.abs(maskBounds.width))
        local hMask <const> = math.max(1, math.abs(maskBounds.height))

        selCurr.origin = Point(
            math.floor(xtlFrame + wFrame * 0.5 - wMask * 0.5),
            math.floor(ytlFrame + hFrame * 0.5 - hMask * 0.5))
        selCurr:intersect(activeSprite.bounds)
        app.transaction("Move to Frame", function()
            activeSprite.selection = selCurr
        end)
        app.refresh()
    end,
}

dlg:button {
    id = "toCelButton",
    text = "CEL",
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

        local selCurr <const>,
        isValid <const> = AseUtilities.getSelection(activeSprite)
        if not isValid then return end

        local wTile, hTile = 1, 1
        local isTileMap <const> = activeLayer.isTilemap
        if isTileMap then
            local tileSet <const> = activeLayer.tileset
            if tileSet then
                local tileSize <const> = tileSet.grid.tileSize
                wTile = math.max(1, math.abs(tileSize.width))
                hTile = math.max(1, math.abs(tileSize.height))
            end
        end

        local celPos <const> = activeCel.position
        local xtlCel <const> = celPos.x
        local ytlCel <const> = celPos.y

        local celImg <const> = activeCel.image
        local wImage <const> = celImg.width * wTile
        local hImage <const> = celImg.height * hTile

        local maskBounds <const> = selCurr.bounds
        local wMask <const> = math.max(1, math.abs(maskBounds.width))
        local hMask <const> = math.max(1, math.abs(maskBounds.height))

        selCurr.origin = Point(
            math.floor(xtlCel + wImage * 0.5 - wMask * 0.5),
            math.floor(ytlCel + hImage * 0.5 - hMask * 0.5))
        selCurr:intersect(activeSprite.bounds)
        app.transaction("Move to Cel", function()
            activeSprite.selection = selCurr
        end)
        app.refresh()
    end,
}

dlg:separator { id = "presetSep", text = "Presets" }

dlg:combobox {
    id = "selMode",
    label = "Logic:",
    -- option = selModes[1 + app.preferences.selection.mode],
    option = defaults.selMode,
    options = selModes,
    hexpand = false,
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
        if (symMode & 1) ~= 0 then
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
        if (symMode & 1) ~= 0 then
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
        if (symMode & 2) ~= 0 then
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
        if (symMode & 2) ~= 0 then
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

dlg:newrow { always = false }

dlg:button {
    id = "inCircButton",
    text = "C&IRCLE",
    focus = false,
    visible = true,
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

dlg:button {
    id = "cursorSelectButton",
    text = "C&URSOR",
    focus = false,
    visible = true,
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
        elseif brushType == BrushType.SQUARE then
            local amount <const> = args.amount
                or defaults.amount --[[@as integer]]
            local brushSize <const> = brush.size
            local brushDegrees <const> = brush.angle

            local rotNeeded <const> = brushSize > 1
                and brushDegrees % 90 ~= 0
            local diam <const> = brushSize <= 1
                and amount * 2
                or brushSize
            if rotNeeded then
                local query <const> = AseUtilities.DIMETRIC_ANGLES[brushDegrees]
                local brushRadians <const> = query
                    or (0.017453292519943 * brushDegrees)
                local cosa <const> = math.cos(brushRadians)
                local sina <const> = math.sin(brushRadians)

                local absCosa <const> = math.abs(cosa)
                local absSina <const> = math.abs(sina)
                local wAabb <const> = math.ceil(
                    diam * absSina + diam * absCosa)
                local hAabb <const> = math.ceil(
                    diam * absSina + diam * absCosa)
                local areaAabb <const> = wAabb * hAabb

                local radius <const> = diam * 0.5
                local xCenteri <const> = wAabb * 0.5
                local yCenteri <const> = hAabb * 0.5

                local pxRect <const> = Rectangle(0, 0, 1, 1)
                local floor <const> = math.floor

                local i = 0
                while i < areaAabb do
                    local x <const> = (i % wAabb) - xCenteri
                    local y <const> = (i // wAabb) - yCenteri
                    local xr <const> = -cosa * x + sina * y
                    local yr <const> = -cosa * y - sina * x
                    if yr >= -radius and yr <= radius
                        and xr >= -radius and xr <= radius then
                        pxRect.x = floor(xMouse + x)
                        pxRect.y = floor(yMouse + y)
                        trgSel:add(pxRect)
                    end
                    i = i + 1
                end
            else
                trgSel:add(Rectangle(
                    xMouse - diam // 2,
                    yMouse - diam // 2,
                    diam, diam))
            end
        else
            local amount <const> = args.amount
                or defaults.amount --[[@as integer]]
            local brushSize <const> = brush.size
            local diam <const> = brushSize <= 1
                and amount * 2
                or brushSize
            local area <const> = diam * diam
            local center <const> = diam * 0.5
            local xtl <const> = xMouse - center
            local ytl <const> = yMouse - center
            local rsq <const> = center * center
            local pxRect <const> = Rectangle(0, 0, 1, 1)
            local floor <const> = math.floor

            local i = 0
            while i < area do
                local x <const> = xtl + i % diam
                local y <const> = ytl + i // diam
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
    options = brushOptions,
    hexpand = false,
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