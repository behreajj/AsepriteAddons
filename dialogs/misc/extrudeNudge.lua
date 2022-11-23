dofile("../../support/aseutilities.lua")

local shiftOptions = { "CARDINAL", "DIAGONAL", "DIMETRIC" }
local brushOptions = { "CIRCLE", "SQUARE" }

local defaults = {
    amount = 1,
    shiftOption = "CARDINAL",
    brushOption = "CIRCLE"
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

local function shiftFromStr(str)
    if str == "DIAGONAL" then
        return shifts.diagonal
    elseif str == "DIMETRIC" then
        return shifts.dimetric
    end
    return shifts.ortho
end

local function blendImages(a, b, xOff, yOff, xCel, yCel, selection)
    local aSpec = a.spec
    local tSpec = ImageSpec {
        width = aSpec.width + math.abs(xOff),
        height = aSpec.height + math.abs(yOff),
        colorMode = aSpec.colorMode,
        transparentColor = aSpec.transparentColor
    }
    tSpec.colorSpace = aSpec.colorSpace
    local target = Image(tSpec)

    -- getPixel must be bounds checked; otherwise it
    -- returns white when pixel coordinates are out of bounds.
    local aw = a.width
    local ah = a.height
    local bw = b.width
    local bh = b.height

    -- Top left corner, i.e., cel position, must be adjusted
    -- if the shift number is negative.
    local tlx = 0
    local tly = 0
    if xOff < 0 then tlx = xOff end
    if yOff > 0 then tly = -yOff end

    local blendHexes = AseUtilities.blendHexes
    local pixels = target:pixels()
    for elm in pixels do
        local xpx = elm.x
        local ypx = elm.y
        local aHex = 0x0
        local bHex = 0x0

        local ax = xpx + tlx
        local ay = ypx + tly
        if ay > -1 and ay < ah
            and ax > -1 and ax < aw then
            aHex = a:getPixel(ax, ay)
        end

        local xSample = xpx + xCel + tlx
        local ySample = ypx + yCel + tly
        if (selection:contains(xSample, ySample)) then
            local bx = ax - xOff
            local by = ay + yOff
            if by > -1 and by < bh
                and bx > -1 and bx < bw then
                bHex = b:getPixel(bx, by)
            end
        end

        elm(blendHexes(aHex, bHex))

    end

    return target, tlx, tly
end

local function extrude(dx, dy)
    local activeSprite = app.activeSprite
    if not activeSprite then return end
    local activeCel = app.activeCel
    if not activeCel then return end

    local srcImage = activeCel.image
    if srcImage.colorMode ~= ColorMode.RGB then
        app.alert {
            title = "Error",
            text = "Only RGB color mode is supported."
        }
        return
    end

    local srcPos = activeCel.position
    local xCel = srcPos.x
    local yCel = srcPos.y

    app.transaction(function()
        local sel = AseUtilities.getSelection(activeSprite)
        local selOrigin = sel.origin
        local xSel = selOrigin.x
        local ySel = selOrigin.y

        local selShifted = Selection()
        selShifted:add(sel)
        selShifted.origin = Point(xSel + dx, ySel - dy)

        -- Try sample selection as a union
        -- of both its previous and next area.
        sel:add(selShifted)

        -- Assign the new image and move the cel.
        local trgImage, tlx, tly = blendImages(
            srcImage, srcImage, dx, dy,
            xCel, yCel, sel)
        activeCel.image = trgImage
        activeCel.position = Point(xCel + tlx, yCel + tly)

        -- Move the selection to match the cel.
        activeSprite.selection = selShifted
    end)

    app.refresh()
end

local function nudgeCel(dx, dy)
    local activeSprite = app.activeSprite
    if not activeSprite then return end
    local activeCel = app.activeCel
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

dlg:button {
    id = "wExtrude",
    label = "Extrude:",
    text = "&W",
    focus = false,
    onclick = function()
        local args = dlg.data
        local shift = args.shiftOption
        local amount = args.amount
        local tr = shiftFromStr(shift)
        extrude(
            tr.up[1] * amount,
            tr.up[2] * amount)
    end
}

dlg:button {
    id = "aExtrude",
    text = "&A",
    focus = false,
    onclick = function()
        local args = dlg.data
        local shift = args.shiftOption
        local amount = args.amount
        local tr = shiftFromStr(shift)
        extrude(
            tr.left[1] * amount,
            tr.left[2] * amount)
    end
}

dlg:button {
    id = "sExtrude",
    text = "&S",
    focus = false,
    onclick = function()
        local args = dlg.data
        local shift = args.shiftOption
        local amount = args.amount
        local tr = shiftFromStr(shift)
        extrude(
            tr.down[1] * amount,
            tr.down[2] * amount)
    end
}

dlg:button {
    id = "dExtrude",
    text = "&D",
    focus = false,
    onclick = function()
        local args = dlg.data
        local shift = args.shiftOption
        local amount = args.amount
        local tr = shiftFromStr(shift)
        extrude(
            tr.right[1] * amount,
            tr.right[2] * amount)
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
        local shift = args.shiftOption
        local amount = args.amount
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
        local shift = args.shiftOption
        local amount = args.amount
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
        local shift = args.shiftOption
        local amount = args.amount
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
        local shift = args.shiftOption
        local amount = args.amount
        local tr = shiftFromStr(shift)
        nudgeCel(
            tr.right[1] * amount,
            tr.right[2] * amount)
    end
}

dlg:newrow { always = false }

dlg:separator { id = "maskSep", text = "Mask" }

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
        app.command.ModifySelection {
            modifier = "expand",
            brush = dlg.data.brushOption:lower(),
            quantity = dlg.data.amount
        }
    end
}

dlg:button {
    id = "contractButton",
    text = "C&ONTRACT",
    focus = false,
    onclick = function()
        app.command.ModifySelection {
            modifier = "contract",
            brush = dlg.data.brushOption:lower(),
            quantity = dlg.data.amount
        }
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "contentButton",
    text = "C&EL",
    focus = false,
    onclick = function()
        local activeSprite = app.activeSprite
        if not activeSprite then return end
        local activeCel = app.activeCel
        if not activeCel then return end

        local selMode = app.preferences.selection.mode
        local celImage = activeCel.image
        local celBounds = activeCel.bounds
        local trgSel = Selection()
        trgSel:add(celBounds)

        if celImage.colorMode == ColorMode.RGB then
            local celPos = activeCel.position
            local xCel = celPos.x
            local yCel = celPos.y

            local pixels = celImage:pixels()
            for pixel in pixels do
                if pixel() & 0xff000000 == 0 then
                    trgSel:subtract(
                        Rectangle(pixel.x + xCel,
                            pixel.y + yCel, 1, 1))
                end
            end
        end

        trgSel:intersect(activeSprite.bounds)

        if selMode ~= 0 then
            local activeSel = AseUtilities.getSelection(activeSprite)

            if selMode == 3 then
                activeSel:intersect(trgSel)
            elseif selMode == 2 then
                activeSel:subtract(trgSel)
            else
                -- Additive selection can be confusing when no prior
                -- selection was made and getSelection returns the cel
                -- bounds, which is cruder than trgSel. However, there
                -- could be a square selection contained by, but
                -- differently shaped than trgSel.
                -- if activeSel.bounds:contains(trgSel.bounds) then
                --     activeSel = trgSel
                -- else
                --     activeSel:add(trgSel)
                -- end
                activeSel:add(trgSel)
            end

            activeSprite.selection = activeSel
        else
            activeSprite.selection = trgSel
        end

        app.command.Refresh()
        app.refresh()
    end
}

dlg:button {
    id = "borderButton",
    text = "&BORDER",
    focus = false,
    onclick = function()
        app.command.ModifySelection {
            modifier = "border",
            brush = dlg.data.brushOption:lower(),
            quantity = dlg.data.amount
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